# Thiết lập provider AWS với region ap-southeast-1 (Singapore)
provider "aws" {
  region = "ap-southeast-1"
}

# Tạo một chuỗi ngẫu nhiên để đảm bảo tên S3 Bucket là duy nhất trên toàn cầu
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# 1. Tạo S3 Bucket để lưu trữ file terraform.tfstate
resource "aws_s3_bucket" "terraform_state" {
  bucket        = "cdo-terraform-state-${random_id.bucket_suffix.hex}"
  force_destroy = true # Cho phép xóa bucket khi chạy destroy kể cả khi đang có file bên trong (chỉ dùng cho môi trường học tập)

  tags = {
    Name        = "Terraform State Storage"
    Environment = "Bootstrap"
  }
}

# Kích hoạt Versioning cho S3 Bucket
# Điều này giúp lưu lại lịch sử thay đổi của file state, cho phép khôi phục khi file state bị hỏng
resource "aws_s3_bucket_versioning" "enabled" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cấu hình mã hóa phía máy chủ (Server-Side Encryption) cho S3 Bucket
# Giúp mã hóa nội dung file state khi lưu trữ trên AWS (bảo mật các thông tin secrets trong state)
resource "aws_s3_bucket_server_side_encryption_configuration" "default" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Chặn hoàn toàn mọi truy cập công cộng (Public Access) vào S3 bucket
# Đảm bảo file state chứa nhiều thông tin nhạy cảm không bị lộ ra ngoài internet
resource "aws_s3_bucket_public_access_block" "public_block" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. Tạo DynamoDB Table để thực hiện State Locking (khóa trạng thái)
# Giúp ngăn chặn 2 người chạy 'terraform apply' cùng một lúc gây xung đột dữ liệu state
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "cdo-terraform-locks"
  billing_mode = "PAY_PER_REQUEST" # Tiết kiệm chi phí, chỉ trả tiền khi có request đọc/ghi
  hash_key     = "LockID"         # Bắt buộc phải đặt tên khóa chính là LockID (kiểu dữ liệu String) để Terraform nhận diện

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "Bootstrap"
  }
}
