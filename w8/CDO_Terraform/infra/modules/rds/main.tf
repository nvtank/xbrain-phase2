# 1. Tạo DB Subnet Group từ các Private Subnets
# RDS yêu cầu tối thiểu 2 subnets nằm ở 2 Availability Zones khác nhau để khởi tạo DB Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name        = "${var.project_name}-rds-subnet-group"
  description = "Nhom cac private subnets cho RDS Database"
  subnet_ids  = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-rds-subnet-group"
  }
}

# 2. Tạo Security Group cho RDS Database
resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Chi cho phep traffic MySQL tu Web Server EC2"
  vpc_id      = var.vpc_id

  # Rule Inbound: Chỉ cho phép cổng 3306 (MySQL) từ Security Group của Web Server EC2
  # Đây là cơ chế bảo mật quan trọng nhất, ngăn chặn các nguồn lực bên ngoài tấn công DB
  ingress {
    description     = "Cho phep ket noi MySQL tu EC2 SG"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.web_sg_id] # Tham chiếu trực tiếp đến SG của EC2 thay vì dải IP
  }

  # Rule Outbound: Cho phép RDS giao tiếp ngược lại với EC2 (stateful sẽ tự xử lý, nhưng thiết lập egress cho chuẩn)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# 3. Tạo RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  identifier           = "${var.project_name}-db"
  engine               = "mysql"
  engine_version       = "8.0" # Sử dụng MySQL phiên bản 8.0
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  storage_type         = "gp2"
  db_name              = var.db_name
  username             = var.db_user
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  # Đảm bảo không cho phép truy cập từ Internet bên ngoài
  publicly_accessible = false

  # Tối ưu hóa chi phí và thời gian triển khai cho môi trường Test/Lab
  multi_az            = false # Chạy Single-AZ để tiết kiệm chi phí
  skip_final_snapshot = true  # Không tạo snapshot khi chạy terraform destroy (tránh tốn tiền lưu trữ)

  tags = {
    Name = "${var.project_name}-mysql-db"
  }
}
