terraform {
  required_version = "~> 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project_name}-${var.environment}-vpc" }
}

# Public subnet

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = false # public IPs assigned per-instance, not subnet-wide

  tags = { Name = "${var.project_name}-${var.environment}-public-subnet" }
}

# Internet gateway + routing

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project_name}-${var.environment}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project_name}-${var.environment}-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group: Instance A
# Outbound 443 for SSM/CloudWatch; outbound 80 to VPC CIDR for the reject demo.

resource "aws_security_group" "instance_a" {
  name        = "${var.project_name}-${var.environment}-instance-a-sg"
  description = "Instance A: HTTPS out for SSM/CW; port-80 out to VPC for flow-log reject demo"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-${var.environment}-instance-a-sg" }
}

# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_vpc_security_group_egress_rule" "a_https" {
  security_group_id = aws_security_group.instance_a.id
  description       = "HTTPS outbound for SSM Session Manager and CloudWatch agent"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "a_probe_b" {
  security_group_id = aws_security_group.instance_a.id
  description       = "HTTP outbound to VPC only - probes Instance B to generate REJECT flow log entries"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.vpc_cidr
}

# Security group: Instance B
# Intentionally has NO inbound rules. Any traffic from Instance A hits this SG
# and gets REJECT-logged in VPC Flow Logs.

resource "aws_security_group" "instance_b" {
  name        = "${var.project_name}-${var.environment}-instance-b-sg"
  description = "Instance B: isolated - no inbound rules; traffic from A is REJECTED (flow log demo)"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-${var.environment}-instance-b-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "nginx_80" {
  security_group_id           = aws_security_group.instance_b.id
  description                 = "Allow HTTP from Instance A"
  ip_protocol                 = "tcp"
  from_port                   = 80
  to_port                     = 80
  reference_security_group_id = aws_security_group.instance_a.id
}

# tfsec:ignore:aws-ec2-no-public-egress-sgr
resource "aws_vpc_security_group_egress_rule" "b_https" {
  security_group_id = aws_security_group.instance_b.id
  description       = "HTTPS outbound for SSM Session Manager"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

# VPC Flow Logs > CloudWatch Logs

# tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc-flow-logs/${var.project_name}-${var.environment}"
  retention_in_days = var.flow_logs_retention_days

  tags = { Name = "${var.project_name}-${var.environment}-flow-logs" }
}

resource "aws_iam_role" "flow_logs" {
  name = "${var.project_name}-${var.environment}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "${var.project_name}-${var.environment}-flow-logs-policy"
  role = aws_iam_role.flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = [
        "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.flow_logs.id}",
        "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.flow_logs.id}:*"
      ]
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  iam_role_arn         = aws_iam_role.flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs.arn

  tags = { Name = "${var.project_name}-${var.environment}-flow-log" }
}
