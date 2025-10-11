variable "aws_region" {
  description = "AWS region for demo deployment"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for demo"
  type        = string
  default     = "t3.medium"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB"
  type        = number
  default     = 30
}

variable "vpc_id" {
  description = "VPC ID where demo will be deployed (REQUIRED)"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for demo instance (REQUIRED)"
  type        = string
}

variable "allowed_cidrs" {
  description = "CIDR blocks allowed to access demo (use 0.0.0.0/0 for public)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "sirius_repo_url" {
  description = "SiriusScan repository URL to clone"
  type        = string
  default     = "https://github.com/SiriusScan/Sirius.git"
}

variable "demo_branch" {
  description = "Branch to checkout for demo"
  type        = string
  default     = "demo"
}

variable "public_key" {
  description = "Public SSH key for demo instance access (leave empty to disable SSH)"
  type        = string
  default     = ""
}

variable "ssh_allowed_cidrs" {
  description = "CIDR blocks allowed for SSH access (defaults to allowed_cidrs if not specified)"
  type        = list(string)
  default     = []
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "SiriusDemo"
    Environment = "demo"
    ManagedBy   = "Terraform"
    Owner       = "OpenSecurity"
    TTL         = "Demo"
  }
}

