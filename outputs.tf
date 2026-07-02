output "bucket_name" {
  value = aws_s3_bucket.lb_logs.bucket
}

output "instance_ips" {
  value = { for k, inst in aws_instance.yusuf-test : k => inst.public_ip }
}
output "alb_dns_name" {
  description = "Public DNS of the load balancer — curl this to test"
  value       = aws_lb.test.dns_name
}

output "instance_ids" {
  description = "Instance IDs keyed by name (for aws ssm start-session)"
  value       = { for k, v in aws_instance.yusuf-test : k => v.id }
}

output "target_group_arn" {
  description = "App target group ARN (for describe-target-health)"
  value       = aws_lb_target_group.app.arn
}

output "vpc_id" {
  value = aws_vpc.main.id
}