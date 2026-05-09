output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_a_id" {
  description = "Security group ID for Instance A (CW agent host)"
  value       = aws_security_group.instance_a.id
}

output "security_group_b_id" {
  description = "Security group ID for Instance B (isolated target)"
  value       = aws_security_group.instance_b.id
}

output "flow_logs_log_group_name" {
  description = "CloudWatch Logs group name for VPC flow logs"
  value       = aws_cloudwatch_log_group.flow_logs.name
}
