provider "aws" {
  region  = "us-east-1"
}

locals {
  instances = {
    web  = { instance_type = "t2.micro" }
    web2 = { instance_type = "t2.micro" }
    db   = { instance_type = "t2.micro" }
  }
}

resource "aws_instance" "yusuf-test" {
  for_each      = local.instances
  ami           = "ami-0f9f41a981329c67b"
  instance_type = each.value.instance_type
  tags          = { Name = each.key }
}

resource "aws_s3_bucket" "bucket" {
  bucket = "yusufwaili-hcp-testing-bucket"
}

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