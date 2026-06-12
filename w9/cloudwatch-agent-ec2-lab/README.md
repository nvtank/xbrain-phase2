# Installing the CloudWatch Agent on EC2

Mục tiêu của bài:

- Cài **Amazon CloudWatch Agent** trên EC2.
- Gắn IAM Role có policy **CloudWatchAgentServerPolicy** cho EC2.
- Cấu hình agent thu thập metric RAM, disk, swap, CPU, network.
- Start agent bằng terminal.
- Kiểm tra trạng thái agent.
- Xác nhận metric xuất hiện trong CloudWatch namespace **CWAgent**.

---

## 1. Cấu trúc repo

```text
cloudwatch-agent-ec2-lab/
├── README.md
├── user-data-cloudwatch-agent.sh
├── configs/
│   └── basic-config.json
├── iam/
│   └── iam-role-note.md
├── scripts/
│   ├── install-cloudwatch-agent.sh
│   ├── start-agent.sh
│   ├── status-agent.sh
│   └── check-cwagent-metrics.sh
└── evidence/
    └── .gitkeep
```

---

## 2. Yêu cầu trước khi làm

EC2 cần có:

- Amazon Linux 2 / Amazon Linux 2023 / Ubuntu.
- SSH terminal vào EC2.
- IAM Role đã gắn vào EC2.
- IAM Role có policy: `CloudWatchAgentServerPolicy`.
- AWS region đã cấu hình hoặc có thể lấy từ EC2 metadata.

Kiểm tra EC2 có IAM Role chưa:

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Nếu lệnh trên không trả ra tên role, bạn cần vào AWS Console để attach IAM Role cho EC2.

---

## 3. Cách chạy nhanh

SSH vào EC2, sau đó clone repo này:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/cloudwatch-agent-ec2-lab.git
cd cloudwatch-agent-ec2-lab
```

Cấp quyền chạy script:

```bash
chmod +x scripts/*.sh
```

Cài CloudWatch Agent:

```bash
./scripts/install-cloudwatch-agent.sh
```

Start agent với file config có sẵn:

```bash
./scripts/start-agent.sh
```

Kiểm tra trạng thái:

```bash
./scripts/status-agent.sh
```

Kiểm tra metric CWAgent:

```bash
./scripts/check-cwagent-metrics.sh
```

---

## 4. Cài CloudWatch Agent thủ công bằng terminal

### Bước 1: Kiểm tra hệ điều hành

```bash
cat /etc/os-release
```

### Bước 2: Cài agent

Với Amazon Linux:

```bash
sudo yum install -y amazon-cloudwatch-agent
```

Nếu dùng Amazon Linux 2023 và `yum` không chạy, dùng:

```bash
sudo dnf install -y amazon-cloudwatch-agent
```

Với Ubuntu:

```bash
wget https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb
```

### Bước 3: Tạo file cấu hình

Repo đã có file:

```text
configs/basic-config.json
```

Copy file này vào thư mục CloudWatch Agent:

```bash
sudo cp configs/basic-config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json
```

### Bước 4: Start agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
```

Bật tự chạy khi reboot:

```bash
sudo systemctl enable amazon-cloudwatch-agent
```

### Bước 5: Kiểm tra trạng thái

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Hoặc:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

Xem log nếu lỗi:

```bash
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

---

## 5. Kiểm tra trên AWS Console

Vào:

```text
CloudWatch → Metrics → All metrics → CWAgent
```

Nếu thấy các metric như bên dưới là thành công:

```text
mem_used_percent
disk_used_percent
swap_used_percent
cpu_usage_idle
cpu_usage_user
net_bytes_recv
net_bytes_sent
```

---

## 6. Evidence cần chụp để nộp bài

Lưu ảnh vào thư mục `evidence/`:

```text
evidence/
├── 01-iam-role-cloudwatch-agent-policy.png
├── 02-install-agent-success.png
├── 03-config-json.png
├── 04-agent-status-running.png
├── 05-cwagent-metrics.png
└── 06-cloudwatch-dashboard-or-metric-graph.png
```

Gợi ý ảnh cần chụp:

1. EC2 có IAM Role và policy `CloudWatchAgentServerPolicy`.
2. Terminal cài `amazon-cloudwatch-agent` thành công.
3. File `config.json` đã được tạo/copy.
4. Lệnh status hiển thị agent đang `running`.
5. AWS Console có namespace `CWAgent`.
6. CloudWatch metric graph hiển thị RAM hoặc disk.

---

## 7. Lỗi thường gặp

### Lỗi 1: Agent không gửi metric

Kiểm tra IAM Role:

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Nếu không có role, cần attach IAM Role vào EC2.

### Lỗi 2: Không thấy metric CWAgent

Đợi 2–5 phút rồi refresh lại CloudWatch Metrics.

Kiểm tra log:

```bash
sudo tail -n 100 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Lỗi 3: Ubuntu thiếu package wget

```bash
sudo apt update
sudo apt install -y wget
```

### Lỗi 4: Không có quyền chạy script

```bash
chmod +x scripts/*.sh
```

---

## 8. Kết luận

Sau khi hoàn thành bài này, EC2 đã cài và chạy CloudWatch Agent. CloudWatch có thể nhận thêm metric hệ thống như RAM, disk, swap, CPU chi tiết và network thông qua namespace `CWAgent`.
