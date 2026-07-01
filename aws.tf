provider "aws" {
  region  = "us-east-1"
}

//subnets

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "main-vpc"
    Environment = "production"
  }
}

variable "public_subnet_cidrs" {
  default = {
    "us-east-1a" = "10.0.1.0/24"
    "us-east-1b" = "10.0.2.0/24"
  }
}

variable "private_subnet_cidrs" {
  default = {
    "us-east-1a" = "10.0.10.0/24"
    "us-east-1b" = "10.0.11.0/24"
  }
}

resource "aws_subnet" "private" {
  for_each          = var.private_subnet_cidrs
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "private-subnet-${each.key}"
  }
}

resource "aws_subnet" "public" {
  for_each                = var.public_subnet_cidrs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${each.key}"
  }
}

//NAT Gateway

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public["us-east-1a"].id

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

//AWS ECS Instances

locals {
  instances = {
    web  = { instance_type = "t2.micro", az = "us-east-1a" }
    web2 = { instance_type = "t2.micro", az = "us-east-1b" }
    db   = { instance_type = "t2.micro", az = "us-east-1a" }
  }
}

resource "aws_instance" "yusuf-test" {
  for_each                = local.instances
  ami                     = "ami-0f9f41a981329c67b"
  instance_type           = each.value.instance_type
  subnet_id               = aws_subnet.private[each.value.az].id
  vpc_security_group_ids  = [aws_security_group.app_sg.id]
  tags                    = { Name = each.key }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y ec2-instance-connect
  EOF
}

//S3 Bucket

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "lb_logs" {
  bucket = "yusufwaili-hcp-testing-bucket-${data.aws_caller_identity.current.account_id}"
}

data "aws_elb_service_account" "main" {}

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

//ECS Instance Check

check "aws_instances_stopped" {
  data "aws_instances" "example" {
    instance_state_names = ["stopped"]
  }
  assert {
    condition     = length(data.aws_instances.example.ids) == 0
    error_message = format("Found stopped instances! Instance IDs: %s", join(", ", data.aws_instances.example.ids))
  }
}

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

//ec2 endpoint

resource "aws_ec2_instance_connect_endpoint" "main" {
  subnet_id          = aws_subnet.private["us-east-1a"].id
  security_group_ids = [aws_security_group.eice_sg.id]

  tags = {
    Name = "test-eice"
  }
}

//security group definitions

resource "aws_security_group" "app_sg" {
  name        = "test-app-sg"
  description = "Controls access to the app EC2 instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "test-app-sg"
    Environment = "production"
  }
}

resource "aws_security_group" "eice_sg" {
  name        = "test-eice-sg"
  description = "Controls access from the EC2 Instance Connect Endpoint to private instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "test-eice-sg"
    Environment = "production"
  }
}

resource "aws_vpc_security_group_egress_rule" "eice_to_app_ssh" {
  security_group_id            = aws_security_group.eice_sg.id
  referenced_security_group_id = aws_security_group.app_sg.id
  from_port = 22
  to_port   = 22
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_eice" {
  security_group_id            = aws_security_group.app_sg.id
  referenced_security_group_id = aws_security_group.eice_sg.id
  from_port = 22
  to_port   = 22
  ip_protocol = "tcp"
}

resource "aws_security_group" "lb_sg" {
  name = "test-lb-sg"
  description  = "Controls access to the test Load Balancer"
  vpc_id = aws_vpc.main.id
}

resource "aws_vpc_security_group_egress_rule" "app_all_outbound" {
  security_group_id = aws_security_group.app_sg.id
  description        = "Allow all outbound traffic"
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "lb_http" {
  security_group_id = aws_security_group.lb_sg.id
  description        = "Allow HTTP to LB from anywhere"
  from_port          = 80
  to_port            = 80
  ip_protocol        = "tcp"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "lb_https" {
  security_group_id = aws_security_group.lb_sg.id
  description        = "Allow HTTPS from anywhere"
  from_port          = 443
  to_port            = 443
  ip_protocol        = "tcp"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lb_all_outbound" {
  security_group_id = aws_security_group.lb_sg.id
  description        = "Allow all outbound traffic"
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "app_from_lb" {
  description = "Controls traffic flow from app subnet to lb subnet"
  security_group_id           = aws_security_group.app_sg.id
  referenced_security_group_id = aws_security_group.lb_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

//load balancer

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

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
  vpc_id   = aws_vpc.main.id

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
  port              = 8080
}