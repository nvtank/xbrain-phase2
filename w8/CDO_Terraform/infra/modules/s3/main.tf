# 1. Tạo S3 Bucket cho static assets
resource "aws_s3_bucket" "static_assets" {
  bucket        = var.bucket_name
  force_destroy = true # Cho phép xóa bucket khi chạy destroy kể cả khi đang chứa file (dùng cho môi trường Lab)

  tags = {
    Name        = "${var.project_name}-static-assets"
    Environment = "dev"
  }
}

# 2. Cấu hình Ownership Controls
resource "aws_s3_bucket_ownership_controls" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# 3. Chặn hoàn toàn truy cập public không an toàn vào bucket
# Để bảo mật tối đa, assets nên được phân phối qua CloudFront hoặc được truy cập qua signed URL
resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 4. Kích hoạt mã hóa phía máy chủ (Server-side encryption)
resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
