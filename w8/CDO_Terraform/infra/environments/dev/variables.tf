variable "aws_region" {
  type        = string
  description = "AWS Region triển khai hạ tầng"
  default     = "ap-southeast-1"
}

variable "project_name" {
  type        = string
  description = "Tên của dự án"
  default     = "cdo-web-app"
}

variable "key_name" {
  type        = string
  description = "Tên SSH Key Pair để kết nối EC2 (Tự tạo trên AWS Console trước)"
}

variable "my_ip" {
  type        = string
  description = "Địa chỉ IP cá nhân của bạn (CIDR format) để mở cổng SSH (Ví dụ: 113.190.233.45/32)"
  default     = "0.0.0.0/0"
}

variable "db_name" {
  type        = string
  description = "Tên Database khởi tạo"
  default     = "webappdb"
}

variable "db_user" {
  type        = string
  description = "Tên tài khoản quản trị Database"
  default     = "dbadmin"
}

variable "db_password" {
  type        = string
  description = "Mật khẩu quản trị Database (sẽ định nghĩa trong file terraform.tfvars)"
  sensitive   = true
}
