#!/bin/bash
# Cập nhật hệ thống
yum update -y

# Cài đặt Apache Web Server (httpd)
yum install -y httpd

# Khởi chạy dịch vụ Apache và thiết lập tự khởi động cùng hệ thống
systemctl start httpd
systemctl enable httpd

# Lấy thông tin metadata của EC2 để hiển thị động trên web (IMDSv2)
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Tạo trang HTML hiển thị đẹp mắt
cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Terraform Web Server</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            text-align: center;
            padding: 50px;
            margin: 0;
            height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            flex-direction: column;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 40px;
            box-shadow: 0 8px 32px 0 rgba(0, 0, 0, 0.3);
            border: 1px solid rgba(255, 255, 255, 0.2);
            max-width: 600px;
        }
        h1 {
            font-size: 2.5em;
            margin-bottom: 20px;
            text-transform: uppercase;
            letter-spacing: 2px;
        }
        p {
            font-size: 1.2em;
            line-height: 1.6;
            margin: 10px 0;
        }
        .highlight {
            color: #4fc3f7;
            font-weight: bold;
        }
        .footer {
            margin-top: 30px;
            font-size: 0.9em;
            opacity: 0.7;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Deploy Web App thành công!</h1>
        <p>Hạ tầng của bạn được quản lý tự động hoàn toàn bằng <span class="highlight">Terraform (IaC)</span>.</p>
        <p><strong>Instance ID:</strong> <span class="highlight">$INSTANCE_ID</span></p>
        <p><strong>Availability Zone:</strong> <span class="highlight">$AZ</span></p>
        <div class="footer">
            <p>© 2026 DevOps Mentor Project | AWS ap-southeast-1</p>
        </div>
    </div>
</body>
</html>
EOF
