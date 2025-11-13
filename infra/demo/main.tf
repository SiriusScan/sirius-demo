terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for remote state management
  backend "s3" {
    bucket         = "sirius-demo-tfstate-463192224457"
    key            = "demo/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "sirius-demo-tflock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Data source to get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# SSH Key Pair (conditional on public_key being provided)
resource "aws_key_pair" "demo" {
  count      = var.public_key != "" ? 1 : 0
  key_name   = "sirius-demo-key"
  public_key = var.public_key

  tags = {
    Name = "sirius-demo-key"
  }
}

# Security Group for demo instance
resource "aws_security_group" "demo" {
  name_prefix = "sirius-demo-sg-"
  description = "Security group for SiriusScan demo environment"
  vpc_id      = var.vpc_id

  # HTTP access to UI
  ingress {
    description = "UI Access"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # HTTP access to API
  ingress {
    description = "API Access"
    from_port   = 9001
    to_port     = 9001
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # Optional: HTTP/HTTPS for future ALB
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # SSH access (conditional on public_key being provided)
  dynamic "ingress" {
    for_each = var.public_key != "" ? [1] : []
    content {
      description = "SSH Access"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = length(var.ssh_allowed_cidrs) > 0 ? var.ssh_allowed_cidrs : var.allowed_cidrs
    }
  }

  # Allow all outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sirius-demo-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# IAM role for EC2 instance (for SSM access)
resource "aws_iam_role" "demo_instance" {
  name_prefix = "sirius-demo-instance-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "sirius-demo-instance-role"
  }
}

# Attach SSM managed policy for Session Manager access
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.demo_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy for logging
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.demo_instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Instance profile
resource "aws_iam_instance_profile" "demo" {
  name_prefix = "sirius-demo-instance-profile-"
  role        = aws_iam_role.demo_instance.name

  tags = {
    Name = "sirius-demo-instance-profile"
  }
}

# Elastic IP for demo (static IP that persists across instance recreations)
resource "aws_eip" "demo" {
  domain = "vpc"

  tags = {
    Name = "sirius-demo-eip"
  }

  # Prevent accidental deletion of static IP
  lifecycle {
    prevent_destroy       = false # Set to true in production to fully protect
    create_before_destroy = true
  }
}

# EC2 Instance for demo
resource "aws_instance" "demo" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  vpc_security_group_ids = [aws_security_group.demo.id]
  iam_instance_profile   = aws_iam_instance_profile.demo.name

  # SSH key pair (conditional)
  key_name = var.public_key != "" ? aws_key_pair.demo[0].key_name : null

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  user_data = templatefile("${path.module}/user_data.sh", {
    sirius_repo_url = var.sirius_repo_url
    demo_branch     = var.demo_branch
    elastic_ip      = aws_eip.demo.public_ip
  })

  # Ensure instance is replaced when user data changes
  user_data_replace_on_change = true

  tags = {
    Name = "sirius-demo"
  }
}

# Associate EIP with instance
resource "aws_eip_association" "demo" {
  instance_id   = aws_instance.demo.id
  allocation_id = aws_eip.demo.id
}

