variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch both EC2 instances into"
  type        = string
}

variable "security_group_a_id" {
  description = "Security group ID for Instance A (CW agent host)"
  type        = string
}

variable "security_group_b_id" {
  description = "Security group ID for Instance B (isolated target)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for both instances"
  type        = string
  default     = "t3.micro"
}

variable "app_log_group_name" {
  description = "CloudWatch Logs group name that the CW agent on Instance A will ship logs to"
  type        = string
}
