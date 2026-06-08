# 1. Tìm AMI mới nhất của Amazon Linux 2 bằng Data Source
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 2. Tạo Security Group cho EC2 Web Server
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Security group cho phep HTTP va SSH vao EC2"
  vpc_id      = var.vpc_id

  # Rule Inbound: Cho phép truy cập cổng 80 (HTTP) từ bất kỳ đâu trên internet
  ingress {
    description = "Cho phep HTTP tu Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Rule Inbound: Cho phép SSH (cổng 22) từ IP của Admin để quản trị hệ thống
  ingress {
    description = "Cho phep SSH tu IP Admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  # Rule Outbound: Cho phép máy chủ đi ra ngoài internet tải cập nhật, cài đặt package
  egress {
    description = "Cho phep moi traffic di ra"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 tương đương với tất cả các protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# 3. Tạo EC2 Instance làm Web Server
resource "aws_instance" "web" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = var.instance_type
  subnet_id              = var.public_subnet_id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = var.key_name

  # Truyền script cài đặt Apache Web Server thông qua user_data
  user_data = file("${path.module}/user-data.sh")

  # Yêu cầu bật IMDSv2 để nâng cao tính bảo mật khi truy cập EC2 metadata
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Bắt buộc dùng IMDSv2 (token-based)
    http_put_response_hop_limit = 1
  }

  # Đảm bảo Instance có public IP
  associate_public_ip_address = true

  tags = {
    Name = "${var.project_name}-web-server"
  }
}
