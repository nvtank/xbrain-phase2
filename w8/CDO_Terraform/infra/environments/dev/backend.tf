# Cấu hình lưu trữ trạng thái từ xa (Remote State Backend)
# LƯU Ý: Terraform không cho phép dùng biến (variables) trong block backend.
# Bạn phải thay thế giá trị "bucket" bằng tên S3 bucket thực tế được in ra ở output của Bước 1 (backend-bootstrap).

terraform {
  backend "s3" {
    bucket         = "cdo-terraform-state-PLACEHOLDER" # Thay bằng S3 bucket name của bạn (ví dụ: cdo-terraform-state-a1b2c3d4)
    key            = "dev/terraform.tfstate"           # Đường dẫn lưu file state bên trong S3 bucket
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "cdo-terraform-locks"             # Tên DynamoDB Table dùng để khóa state
  }
}
