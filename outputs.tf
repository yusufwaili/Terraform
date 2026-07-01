output "bucket_name" {
  value = aws_s3_bucket.lb_logs.bucket
}

output "instance_ips" {
  value = { for k, inst in aws_instance.yusuf-test : k => inst.public_ip }
}