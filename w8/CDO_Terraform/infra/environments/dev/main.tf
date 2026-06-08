# 1. Sinh chuỗi ngẫu nhiên đảm bảo tên S3 Bucket lưu static assets không trùng lặp toàn cầu
resource "random_id" "s3_suffix" {
  byte_length = 4
}

# 2. Triệu gọi VPC Module
module "vpc" {
  source       = "../../modules/vpc"
  project_name = var.project_name
  vpc_cidr     = "10.0.0.0/16"
}

# 3. Triệu gọi S3 Module lưu static assets
module "s3" {
  source       = "../../modules/s3"
  project_name = var.project_name
  bucket_name  = "cdo-static-assets-${random_id.s3_suffix.hex}"
}

# 4. Triệu gọi EC2 Module (Web Server trong Public Subnet)
module "ec2" {
  source           = "../../modules/ec2"
  project_name     = var.project_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_ids[0] # Lấy ID của Public Subnet đầu tiên
  key_name         = var.key_name
  my_ip            = var.my_ip
  instance_type    = "t2.micro" # Tiết kiệm chi phí
}

# 5. Triệu gọi RDS Module (MySQL trong Private Subnet)
module "rds" {
  source             = "../../modules/rds"
  project_name       = var.project_name
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids # Truyền danh sách 2 private subnets
  web_sg_id          = module.ec2.web_sg_id          # Gán ID Security Group của EC2 để mở DB
  db_name            = var.db_name
  db_user            = var.db_user
  db_password        = var.db_password
  instance_class     = "db.t3.micro" # Tiết kiệm chi phí
}
