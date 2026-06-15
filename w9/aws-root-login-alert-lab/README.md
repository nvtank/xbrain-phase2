# AWS Root Account Login Alert Lab

Bai lab: **Alert on AWS Root Account Login**

Muc tieu:

```text
AWS Root Login
   ↓
CloudTrail
   ↓
CloudWatch Logs
   ↓
Metric Filter
   ↓
CloudWatch Alarm
   ↓
SNS Email Alert
```

Repo nay dung **AWS CLI + Bash script** de tao toan bo ha tang giam sat root account login.

---

## 1. Yeu cau truoc khi chay

May terminal can co:

```bash
aws --version
aws sts get-caller-identity
```

IAM user/role dang dung can co quyen tao cac dich vu sau:

* CloudTrail
* CloudWatch Logs
* CloudWatch Alarm
* SNS
* S3
* IAM Role/Policy

> Khong commit AWS Access Key, Secret Key hoac thong tin nhay cam vao GitHub.

---

## 2. Cach chay lab

Clone repo:

```bash
git clone <YOUR_REPO_URL>
cd aws-root-login-alert-lab
chmod +x scripts/*.sh
```

Chay setup:

```bash
EMAIL="your-email@gmail.com" ./scripts/setup-root-login-alert.sh
```

Mac dinh script dung region:

```text
us-east-1
```

Chay voi region cu the:

```bash
REGION="us-east-1" EMAIL="your-email@gmail.com" ./scripts/setup-root-login-alert.sh
```

Sau khi chay xong, vao email va bam:

```text
Confirm subscription
```

---

## 3. Cac tai nguyen duoc tao

Script se tao:

| Thanh phan           | Ten mac dinh                              |
| -------------------- | ----------------------------------------- |
| S3 Bucket            | `root-login-alert-<account-id>-us-east-1` |
| CloudTrail           | `root-login-alert-trail`                  |
| CloudWatch Log Group | `/aws/cloudtrail/root-login-alert`        |
| Metric Filter        | `RootAccountLoginFilter`                  |
| Metric Namespace     | `Security`                                |
| Metric Name          | `RootAccountLoginCount`                   |
| CloudWatch Alarm     | `RootAccountLoginAlarm`                   |
| SNS Topic            | `root-login-alert-sns-topic`              |
| IAM Role             | `root-login-alert-cloudtrail-cwlogs-role` |

---

## 4. Filter bat su kien root login

CloudWatch Logs Metric Filter dung pattern:

```text
{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }
```

Y nghia:

* `userIdentity.type = "Root"`: bat su kien phat sinh tu root account.
* `eventType != "AwsServiceEvent"`: bo qua event do AWS service tu tao.

---

## 5. Test alarm khong can dang nhap root that

Sau khi da confirm email SNS, chay:

```bash
./scripts/test-alarm.sh
```

Script nay gui thu metric:

```text
Security / RootAccountLoginCount = 1
```

Sau khoang 1-5 phut, CloudWatch Alarm se chuyen sang `ALARM` va SNS gui email.

Kiem tra trang thai:

```bash
./scripts/status.sh
```

---

## 6. Test dung bang root login

Trong truong hop can test that:

1. Bat MFA cho root account.
2. Dang nhap AWS Console bang root account mot lan.
3. Logout ngay.
4. Cho CloudTrail day event sang CloudWatch Logs.
5. Kiem tra alarm va email alert.

Khong nen dung root account thuong xuyen.

---

## 7. Evidence can chup de nop

Luu anh vao thu muc `evidence/`:

```text
evidence/
├── 01-cloudtrail-logging-on.png
├── 02-cloudwatch-log-group.png
├── 03-metric-filter-root-login.png
├── 04-cloudwatch-alarm.png
├── 05-sns-subscription-confirmed.png
├── 06-email-alert.png
└── 07-terminal-status.png
```

---

## 8. Xoa tai nguyen sau khi demo

```bash
./scripts/destroy.sh
```

Lenh nay se xoa cac tai nguyen do lab tao ra de tranh phat sinh chi phi.

---

## 9. Cau truc repo

```text
aws-root-login-alert-lab/
├── README.md
├── scripts/
│   ├── setup-root-login-alert.sh
│   ├── test-alarm.sh
│   ├── status.sh
│   └── destroy.sh
├── iam/
│   ├── assume-role-policy.json
│   └── cloudtrail-cwlogs-policy-template.json
├── cloudwatch/
│   └── metric-filter-pattern.txt
└── evidence/
    └── .gitkeep
```
