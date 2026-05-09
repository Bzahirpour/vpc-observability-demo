variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Project name — used as a prefix for all resource names"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "alarm_email" {
  description = "Email address that receives CloudWatch alarm SNS notifications"
  type        = string
}
