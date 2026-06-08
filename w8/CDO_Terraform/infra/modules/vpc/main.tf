# 1. Tạo VPC chính
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Cho phép gán DNS tên miền của AWS cho các instances
  enable_dns_support   = true # Bật hỗ trợ phân giải DNS trong VPC

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# 2. Tạo Internet Gateway để cho phép VPC kết nối hai chiều với Internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# 3. Tạo các Public Subnets (Dùng vòng lặp count)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Tự động cấp phát Public IP cho EC2 nằm trong subnet này

  tags = {
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# 4. Tạo các Private Subnets (Dùng vòng lặp count)
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false # Tuyệt đối KHÔNG tự động cấp phát Public IP ở private subnet

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# 5. Tạo Route Table cho Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Cấu hình Route gửi mọi traffic ra ngoài Internet (0.0.0.0/0) qua Internet Gateway
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# 6. Tạo Route Table cho Private Subnets (Không có route đi ra Internet Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# 7. Liên kết (Association) Route Table Public với các Public Subnets tương ứng
resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 8. Liên kết Route Table Private với các Private Subnets tương ứng
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
