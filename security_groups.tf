# Security groups and their ingress/egress rules for the app instances, the
# load balancer, and the (SSM-superseded) EC2 Instance Connect endpoint.

# --- App instances -----------------------------------------------------------

resource "aws_security_group" "app_sg" {
  name        = "test-app-sg"
  description = "Controls access to the app EC2 instances"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name        = "test-app-sg"
    Environment = "production"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_lb" {
  description                  = "Controls traffic flow from app subnet to lb subnet"
  security_group_id            = aws_security_group.app_sg.id
  referenced_security_group_id = aws_security_group.lb_sg.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_all_outbound" {
  security_group_id = aws_security_group.app_sg.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- Load balancer -----------------------------------------------------------

resource "aws_security_group" "lb_sg" {
  name        = "test-lb-sg"
  description = "Controls access to the test Load Balancer"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "lb_http" {
  security_group_id = aws_security_group.lb_sg.id
  description       = "Allow HTTP to LB from anywhere"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "lb_https" {
  security_group_id = aws_security_group.lb_sg.id
  description       = "Allow HTTPS from anywhere"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "lb_all_outbound" {
  security_group_id = aws_security_group.lb_sg.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}