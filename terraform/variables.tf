variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "iac-project"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "admin_ip_cidr" {
  description = "Your public IP in CIDR form (x.x.x.x/32) allowed to SSH"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.admin_ip_cidr))
    error_message = "admin_ip_cidr must be valid CIDR notation, e.g. 41.90.1.2/32."
  }

  validation {
    condition     = var.admin_ip_cidr != "0.0.0.0/0"
    error_message = "Refusing to open SSH to the entire internet."
  }
}

variable "public_key_path" {
  description = "Path to the local SSH public key uploaded to AWS"
  type        = string
  default     = "~/.ssh/iac-project.pub"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of web servers to create"
  type        = number
  default     = 2
}
