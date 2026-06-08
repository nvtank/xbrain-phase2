output "db_instance_endpoint" {
  value       = aws_db_instance.mysql.endpoint
  description = "Địa chỉ Endpoint kết nối database (dưới dạng host:port)"
}

output "db_instance_address" {
  value       = aws_db_instance.mysql.address
  description = "Địa chỉ Host DNS của Database"
}

output "db_instance_name" {
  value       = aws_db_instance.mysql.db_name
  description = "Tên Database mặc định"
}
