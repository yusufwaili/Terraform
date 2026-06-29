provider "aws" {
  region  = "us-east-1"
}

resource "aws_s3_bucket" "bucket" {
  bucket = "yusufwaili-hcp-testing-bucket"
}

output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}


resource "aws_instance" "yusuf-test" {
  ami           = "ami-0f9f41a981329c67b"
  instance_type = "t2.micro"
}

output "instance_ips" {
  value = aws_instance.yusuf-test.*.public_ip
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