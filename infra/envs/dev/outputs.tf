output "instance_a_id" {
  description = "Instance A (CW agent host) EC2 ID"
  value       = module.compute.instance_a_id
}

output "instance_b_id" {
  description = "Instance B (isolated target) EC2 ID"
  value       = module.compute.instance_b_id
}

output "instance_a_private_ip" {
  description = "Instance A private IP"
  value       = module.compute.instance_a_private_ip
}

output "instance_b_private_ip" {
  description = "Instance B private IP"
  value       = module.compute.instance_b_private_ip
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.observability.dashboard_url
}

output "flow_logs_log_group" {
  description = "CloudWatch Logs group for VPC flow logs"
  value       = module.networking.flow_logs_log_group_name
}

output "app_log_group" {
  description = "CloudWatch Logs group for Instance A app logs"
  value       = local.app_log_group_name
}

output "alarm_name" {
  description = "CPU high-watermark alarm name"
  value       = module.observability.alarm_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = module.observability.sns_topic_arn
}
