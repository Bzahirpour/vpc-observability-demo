terraform {
  required_version = "~> 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_region" "current" {}

# App log group
# Created here so Terraform manages the retention policy; the CW agent on
# Instance A ships to this group name (passed in via userdata).

# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "app" {
  name              = var.app_log_group_name
  retention_in_days = var.log_retention_days

  tags = { Name = "${var.project_name}-${var.environment}-app-logs" }
}

# SNS topic + email subscriptio

# tfsec:ignore:aws-sns-enable-topic-encryption
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-${var.environment}-alerts"

  tags = { Name = "${var.project_name}-${var.environment}-alerts" }
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# CloudWatch alarm: CPU > threshold for 2 consecutive minutes

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_alarm_threshold
  alarm_description   = "CPU > ${var.cpu_alarm_threshold}% for 2 consecutive minutes on Instance A"
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = var.instance_a_id
  }

  alarm_actions             = [aws_sns_topic.alerts.arn]
  ok_actions                = [aws_sns_topic.alerts.arn]
  insufficient_data_actions = []
}

# CloudWatch Dashboard

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      # Context banner
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 2
        properties = {
          markdown = "## VPC Observability Demo — `${var.environment}`\n**Instance A** (CW Agent): ships memory/disk metrics + structured app logs every 60 s. **Instance B** (isolated): no inbound SG rules — traffic from A generates **action=REJECT** in VPC Flow Logs (`${var.flow_logs_log_group_name}`)."
        }
      },
      # CPU (native EC2 metric — no agent needed)
      {
        type   = "metric"
        x      = 0
        y      = 2
        width  = 12
        height = 6
        properties = {
          title   = "CPU Utilization — Instance A"
          region  = data.aws_region.current.id
          view    = "timeSeries"
          stacked = false
          stat    = "Average"
          period  = 60
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.instance_a_id]
          ]
          annotations = {
            horizontal = [{
              label = "Alarm threshold"
              value = var.cpu_alarm_threshold
              color = "#ff6961"
            }]
          }
        }
      },
      # Memory (CW agent custom metric)
      {
        type   = "metric"
        x      = 12
        y      = 2
        width  = 12
        height = 6
        properties = {
          title   = "Memory Used % — Instance A (CW Agent)"
          region  = data.aws_region.current.id
          view    = "timeSeries"
          stacked = false
          stat    = "Average"
          period  = 60
          metrics = [
            ["CWAgent", "mem_used_percent", "InstanceId", var.instance_a_id]
          ]
        }
      },
      # Disk (CW agent — SEARCH handles unknown device/fstype at deploy time)
      {
        type   = "metric"
        x      = 0
        y      = 8
        width  = 12
        height = 6
        properties = {
          title   = "Disk Used % — Instance A root volume (CW Agent)"
          region  = data.aws_region.current.id
          view    = "timeSeries"
          stacked = false
          stat    = "Average"
          period  = 60
          metrics = [
            [{
              expression = "SEARCH('{CWAgent,InstanceId,device,fstype,path} InstanceId=\"${var.instance_a_id}\" MetricName=\"disk_used_percent\" path=\"/\"', 'Average', 60)"
              id         = "disk"
              label      = "Disk used %"
            }]
          ]
        }
      },
      # Network I/O
      {
        type   = "metric"
        x      = 12
        y      = 8
        width  = 12
        height = 6
        properties = {
          title   = "Network I/O — Instance A"
          region  = data.aws_region.current.id
          view    = "timeSeries"
          stacked = false
          stat    = "Average"
          period  = 60
          metrics = [
            ["AWS/EC2", "NetworkIn", "InstanceId", var.instance_a_id, { label = "Network In (bytes)" }],
            ["AWS/EC2", "NetworkOut", "InstanceId", var.instance_a_id, { label = "Network Out (bytes)" }]
          ]
        }
      },
      # Alarm status widget
      {
        type   = "alarm"
        x      = 0
        y      = 14
        width  = 24
        height = 2
        properties = {
          title  = "Alarms"
          alarms = [aws_cloudwatch_metric_alarm.cpu_high.arn]
        }
      },
      # App logs (Logs Insights)
      {
        type   = "log"
        x      = 0
        y      = 16
        width  = 24
        height = 6
        properties = {
          title  = "App Logs — Instance A (structured JSON, last 50 lines)"
          region = data.aws_region.current.id
          view   = "table"
          query  = "SOURCE '${var.app_log_group_name}' | fields @timestamp, @message | sort @timestamp desc | limit 50"
        }
      }
    ]
  })
}
