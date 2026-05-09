variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "instance_a_id" {
  description = "EC2 Instance A ID — used in dashboard widgets and the CPU alarm dimension"
  type        = string
}

variable "alarm_email" {
  description = "Email address for CloudWatch alarm SNS notifications"
  type        = string
}

variable "app_log_group_name" {
  description = "CloudWatch Logs group name for application logs shipped by the CW agent"
  type        = string
}

variable "flow_logs_log_group_name" {
  description = "CloudWatch Logs group name for VPC flow logs (shown in dashboard text)"
  type        = string
}

variable "cpu_alarm_threshold" {
  description = "CPU utilization % that triggers the high-CPU alarm"
  type        = number
  default     = 60
}

variable "log_retention_days" {
  description = "Days to retain app logs in CloudWatch Logs"
  type        = number
  default     = 14
}
