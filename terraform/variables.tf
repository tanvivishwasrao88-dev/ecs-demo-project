variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix used on all resources"
  type        = string
  default     = "ecs-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (2 AZs, ECS tasks + ALB live here tonight)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "container_port" {
  description = "Port the app container listens on"
  type        = number
  default     = 8080
}

variable "container_image" {
  description = "Full ECR image URI (account.dkr.ecr.region.amazonaws.com/repo:tag). Set via -var or tfvars after first Jenkins build."
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Number of Fargate tasks to run"
  type        = number
  default     = 2
}
