output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID của VPC vừa triển khai"
}

output "web_public_ip" {
  value       = module.ec2.public_ip
  description = "Truy cập địa chỉ này bằng trình duyệt: http://<web_public_ip>"
}

output "rds_endpoint" {
  value       = module.rds.db_instance_endpoint
  description = "Endpoint để kết nối với RDS Database"
}

output "s3_assets_bucket" {
  value       = module.s3.bucket_id
  description = "Tên S3 Bucket lưu trữ Static Assets"
}
