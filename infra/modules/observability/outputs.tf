output "dashboard_url" {
  description = "Direct link to the CloudWatch dashboard in the AWS console"
  value       = "https://${data.aws_region.current.name}.console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS topic ARN that receives alarm notifications"
  value       = aws_sns_topic.alerts.arn
}

output "alarm_name" {
  description = "CPU high-watermark alarm name"
  value       = aws_cloudwatch_metric_alarm.cpu_high.alarm_name
}

output "app_log_group_name" {
  description = "CloudWatch Logs group name for application logs"
  value       = aws_cloudwatch_log_group.app.name
}
