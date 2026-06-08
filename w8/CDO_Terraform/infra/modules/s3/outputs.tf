output "bucket_id" {
  value       = aws_s3_bucket.static_assets.id
  description = "Tên (ID) của S3 Bucket chứa assets"
}

output "bucket_arn" {
  value       = aws_s3_bucket.static_assets.arn
  description = "Amazon Resource Name (ARN) của S3 Bucket"
}

output "bucket_domain_name" {
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
  description = "Tên miền khu vực của S3 Bucket"
}
