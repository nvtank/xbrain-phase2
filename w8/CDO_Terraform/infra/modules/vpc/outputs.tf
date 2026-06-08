output "vpc_id" {
  value       = aws_vpc.main.id
  description = "ID của VPC được tạo ra"
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "Danh sách ID của các Public Subnets"
}

output "private_subnet_ids" {
  value       = aws_subnet.private[*].id
  description = "Danh sách ID của các Private Subnets"
}
