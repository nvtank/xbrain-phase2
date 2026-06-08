variable "project_name" {
  type        = string
  description = "Tên của dự án"
}

variable "vpc_id" {
  type        = string
  description = "ID của VPC nơi chứa Security Group của EC2"
}

variable "public_subnet_id" {
  type        = string
  description = "ID của Public Subnet để deploy EC2 Web Server"
}

variable "instance_type" {
  type        = string
  description = "Instance type của EC2 (Free Tier nên dùng t2.micro hoặc t3.micro)"
  default     = "t2.micro"
}

variable "key_name" {
  type        = string
  description = "Tên của SSH Key Pair đã tồn tại trên AWS để truy cập EC2"
}

variable "my_ip" {
  type        = string
  description = "Địa chỉ IP cá nhân của bạn (CIDR format) để mở cổng SSH (Ví dụ: 203.0.113.50/32). Mặc định 0.0.0.0/0 để dễ demo."
  default     = "0.0.0.0/0"
}
