terraform {
  required_version = "~> 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# AMI: latest Amazon Linux 2023 x86_64

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Shared IAM role for both instances (SSM + CW agent)

resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# Instance B: isolated target (created first — A's userdata needs its IP)

# tfsec:ignore:aws-ec2-no-public-ip-in-subnet
resource "aws_instance" "instance_b" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_b_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true # needed for SSM without VPC endpoints
  monitoring                  = true
  user_data_replace_on_change = true

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  user_data = file("${path.module}/templates/userdata_b.sh.tpl")

  tags = { Name = "${var.project_name}-${var.environment}-instance-b" }
}

# Instance A: CW agent + app logs + probe
# Depends implicitly on instance_b (its private_ip is injected into userdata).

# tfsec:ignore:aws-ec2-no-public-ip-in-subnet
resource "aws_instance" "instance_a" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_a_id]
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  associate_public_ip_address = true # needed for SSM without VPC endpoints
  monitoring                  = true

  metadata_options {
    http_tokens   = "required" # IMDSv2
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted = true
  }

  user_data = templatefile("${path.module}/templates/userdata_a.sh.tpl", {
    app_log_group         = var.app_log_group_name
    instance_b_private_ip = aws_instance.instance_b.private_ip
  })

  tags = { Name = "${var.project_name}-${var.environment}-instance-a" }
}
