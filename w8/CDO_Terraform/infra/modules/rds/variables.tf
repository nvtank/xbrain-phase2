variable "project_name" {
  type        = string
  description = "Tên của dự án"
}

variable "vpc_id" {
  type        = string
  description = "ID của VPC"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Danh sách ID các Private Subnets để tạo DB Subnet Group"
}

variable "web_sg_id" {
  type        = string
  description = "ID Security Group của EC2 Web Server để cho phép truy cập DB"
}

variable "db_name" {
  type        = string
  description = "Tên Database khởi tạo mặc định"
  default     = "mydb"
}

variable "db_user" {
  type        = string
  description = "Tên tài khoản quản trị Database (Master Username)"
  default     = "admin"
}

variable "db_password" {
  type        = string
  description = "Mật khẩu quản trị Database (Master Password)"
  sensitive   = true # Bật thuộc tính sensitive để ẩn mật khẩu khi chạy terraform apply/plan
}

variable "instance_class" {
  type        = string
  description = "Loại máy chủ cho RDS (Free tier hỗ trợ db.t3.micro hoặc db.t4g.micro)"
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Dung lượng lưu trữ mặc định (GB)"
  default     = 20
}
