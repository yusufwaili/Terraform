output "bucket_name" {
  value = aws_s3_bucket.bucket.bucket
}

output "instance_ips" {
  value = { for k, inst in aws_instance.yusuf-test : k => inst.public_ip }
}