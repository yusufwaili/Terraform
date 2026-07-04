# IAM (SSM), EC2 instances, S3 (LB access logs), and the load balancer.

# --- IAM: SSM instance profile ----------------------------------------------

resource "aws_iam_role" "ssm" {
  name = "test-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "test-ssm-profile"
  role = aws_iam_role.ssm.name
}

# --- EC2 instances -----------------------------------------------------------

resource "aws_instance" "yusuf-test" {
  for_each               = local.instances
  ami                    = "ami-0f9f41a981329c67b"
  instance_type          = each.value.instance_type
  subnet_id              = local.private_subnet_by_az[each.value.az] # was aws_subnet.private[each.value.az].id
  vpc_security_group_ids = [aws_security_group.app_sg.id]

  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  user_data_replace_on_change = true

  tags = { Name = each.key }
}

# AMI lookup for the HashiCorp base Ubuntu 24.04 images. Currently unused —
# the instances above pin a hardcoded AMI.
data "aws_ami" "hc-base-ubuntu-2404" {
  for_each = toset(["amd64", "arm64"])

  filter {
    name   = "name"
    values = [format("hc-base-ubuntu-2404-%s-*", each.value)]
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  most_recent = true
  owners      = ["888995627335"] # ami-prod account
}

# Fail the run if any instances are in a stopped state.
check "aws_instances_stopped" {
  data "aws_instances" "example" {
    instance_state_names = ["stopped"]
  }

  assert {
    condition     = length(data.aws_instances.example.ids) == 0
    error_message = format("Found stopped instances! Instance IDs: %s", join(", ", data.aws_instances.example.ids))
  }
}

# --- S3: load balancer access logs ------------------------------------------

data "aws_caller_identity" "current" {}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket" "lb_logs" {
  bucket = "yusufwaili-hcp-testing-bucket-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_policy" "lb_logs" {
  bucket = aws_s3_bucket.lb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = data.aws_elb_service_account.main.arn }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.lb_logs.arn}/test-lb/AWSLogs/*"
    }]
  })
}

# --- Load balancer -----------------------------------------------------------

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = module.vpc.public_subnets # was [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.lb_logs.id
    prefix  = "test-lb"
    enabled = true
  }

  depends_on = [aws_s3_bucket_policy.lb_logs]

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_target_group" "app" {
  name     = "test-app-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id 

  health_check {
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Environment = "production"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_target_group_attachment" "app" {
  for_each = {
    for name, instance in aws_instance.yusuf-test : name => instance
    if name != "db"
  }

  target_group_arn = aws_lb_target_group.app.arn
  target_id        = each.value.id
  port             = 8080
}