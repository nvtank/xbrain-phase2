variable "project_name" {
  description = "Project name used for resource names"
  type        = string
  default     = "k8s-minikube-lab"
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for Minikube node"
  type        = string
  default     = "t3.small"
}

variable "app_node_port" {
  description = "Kubernetes NodePort exposed on EC2 and forwarded by ALB"
  type        = number
  default     = 30080

  validation {
    condition     = var.app_node_port >= 30000 && var.app_node_port <= 32767
    error_message = "NodePort must be between 30000 and 32767."
  }
}

variable "my_ip_cidr" {
  description = "Your public IP CIDR for SSH access. Example: 1.2.3.4/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "page_title" {
  description = "Title displayed by the nginx page"
  type        = string
  default     = "Kubernetes on AWS with Terraform, EC2, Minikube and ALB"
}
