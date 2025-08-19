variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "desenvolvimento"
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "domain_name" {
  description = "Domain name for WordPress"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 3
}

variable "desired_instances" {
  description = "Desired number of instances"
  type        = number
  default     = 1
}

variable "cpu_threshold_scale_up" {
  description = "CPU threshold to scale up instances"
  type        = number
  default     = 75
}

variable "cpu_threshold_scale_down" {
  description = "CPU threshold to scale down instances"
  type        = number
  default     = 25
}

variable "owner" {
  description = "Resource owner"
  type        = string
  default     = "DevOps"
}

variable "enable_multi_az_rds" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}