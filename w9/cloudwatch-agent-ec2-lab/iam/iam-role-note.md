# IAM Role cho CloudWatch Agent

EC2 cần được attach IAM Role có managed policy:

```text
CloudWatchAgentServerPolicy
```

Cách làm trên AWS Console:

1. Vào IAM → Roles → Create role.
2. Trusted entity type: AWS service.
3. Use case: EC2.
4. Attach policy: `CloudWatchAgentServerPolicy`.
5. Đặt tên ví dụ: `EC2CloudWatchAgentRole`.
6. Vào EC2 → Instances → chọn instance.
7. Actions → Security → Modify IAM role.
8. Chọn role `EC2CloudWatchAgentRole`.
9. Save.

Kiểm tra trong terminal EC2:

```bash
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/
```

Nếu lệnh trả ra tên role thì EC2 đã có IAM Role.
