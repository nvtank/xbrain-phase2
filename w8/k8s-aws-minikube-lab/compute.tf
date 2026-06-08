data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "minikube" {
  depends_on = [
    aws_route_table_association.public
  ]


  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated.key_name
  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/user-data.sh", {
    app_node_port = var.app_node_port
    page_title    = var.page_title
  })

  user_data_replace_on_change = true

  root_block_device {
    volume_size = 25
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.project_name}-ec2-minikube"
  }
}

