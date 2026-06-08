# Output tên S3 Bucket chứa remote state để dùng cho cấu hình backend sau này
output "s3_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "Tên của S3 Bucket dùng làm remote state backend"
}

# Output tên DynamoDB Table dùng để khóa state
output "dynamodb_table_name" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "Tên của DynamoDB Table dùng để khóa trạng thái"
}
