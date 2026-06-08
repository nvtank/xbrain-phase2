variable "project_name" {
  type        = string
  description = "Tên của dự án, dùng để đặt prefix cho các tài nguyên"
  default     = "cdo-web-app"
}

variable "vpc_cidr" {
  type        = string
  description = "Dải CIDR của VPC chính"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Danh sách dải CIDR cho các Public Subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Danh sách dải CIDR cho các Private Subnets"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Danh sách các Availability Zones sẽ sử dụng"
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}
