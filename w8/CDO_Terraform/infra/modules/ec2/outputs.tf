output "instance_id" {
  value       = aws_instance.web.id
  description = "ID của EC2 Web Server"
}

output "public_ip" {
  value       = aws_instance.web.public_ip
  description = "Địa chỉ IP Public của Web Server để truy cập qua trình duyệt"
}

output "web_sg_id" {
  value       = aws_security_group.web_sg.id
  description = "ID Security Group của EC2 Web Server (dùng làm nguồn Inbound cho RDS)"
}
