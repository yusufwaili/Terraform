provider "aws" {
  region  = "us-east-1"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "yusufwaili-hcp-testing-bucket"
}

output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "instance_ips" {
  value = aws_instance.yusuf-test.*.public_ip
}

resource "aws_instance" "yusuf-test" {
  ami           = "ami-0f9f41a981329c67b"
  instance_type = "t2.micro"
}

check "aws_instances_stopped" {
  data "aws_instances" "example" {
    instance_state_names = "stopped"
  }
  assert {
    condition     = length(data.aws_instances.example) > 0
    error_message = format("Found Instances have stopped! Instance ID’s: %s", data.aws_instances.example.ids)
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