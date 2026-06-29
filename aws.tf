provider "aws" {
  region  = "us-east-1"
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

resource "aws_s3_bucket" "bucket" {
  bucket = "hcp-testing-bucket"
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