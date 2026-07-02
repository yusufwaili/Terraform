locals {
  instances = {
    web  = { instance_type = "t2.micro", az = "us-east-1a" }
    web2 = { instance_type = "t2.micro", az = "us-east-1b" }
    db   = { instance_type = "t2.micro", az = "us-east-1a" }
  }
}