locals {
  instances = {
    web  = { instance_type = "t2.micro", az = "us-east-1a" }
    web2 = { instance_type = "t2.micro", az = "us-east-1b" }
    db   = { instance_type = "t2.micro", az = "us-east-1a" }
  }

  private_subnet_by_az = zipmap(module.vpc.azs, module.vpc.private_subnets)
}