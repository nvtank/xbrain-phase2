# Evidence - Amazon Macie Sensitive Data Detection Lab

## 1. Lab Objective

Mục tiêu của bài lab là phát hiện dữ liệu nhạy cảm trong Amazon S3 bằng Amazon Macie và gửi cảnh báo qua email.

Flow triển khai:

```txt
S3 Bucket -> Amazon Macie -> Macie Finding -> EventBridge Rule -> SNS Topic -> Email Notification
```

## 2. Environment Information

| Item | Value |
| --- | --- |
| AWS Region | `ap-southeast-1` |
| AWS Account ID | `995310839463` |
| S3 Bucket | `macie-sensitive-lab-995310839463-ap-southeast-1` |
| SNS Topic | `macie-sensitive-alerts` |
| EventBridge Rule | `macie-findings-to-sns` |
| Email Endpoint | `tuannguyen.120910@gmail.com` |

## 3. S3 Bucket Sample Files

Em đã tạo S3 bucket và upload các file mẫu để Amazon Macie quét dữ liệu nhạy cảm.

### Evidence

```txt
2026-06-19 15:22:53        163 aws-key-sample.txt
2026-06-19 15:22:53        112 customer-info.txt
```

### Explanation

Bucket chứa 2 file mẫu:

| File | Purpose |
| --- | --- |
| `customer-info.txt` | Chứa dữ liệu cá nhân giả để Macie phát hiện |
| `aws-key-sample.txt` | Chứa sample credential giả dùng cho kiểm thử |

## 4. Amazon Macie Enabled

Amazon Macie đã được bật trong region `ap-southeast-1`.

### Evidence

```json
{
  "createdAt": "2026-06-19T08:23:01.962000+00:00",
  "findingPublishingFrequency": "FIFTEEN_MINUTES",
  "serviceRole": "arn:aws:iam::995310839463:role/aws-service-role/macie.amazonaws.com/AWSServiceRoleForAmazonMacie",
  "status": "ENABLED",
  "updatedAt": "2026-06-19T08:23:01.962000+00:00"
}
```

### Result

Macie session status là `ENABLED`, nghĩa là Amazon Macie đã sẵn sàng để quét S3 bucket và tạo finding.

## 5. SNS Email Subscription

SNS topic đã được tạo và email subscription đã được confirm thành công.

### Evidence

```txt
+-----------------------------+--------------------------------------------------------------------------------------------------------+
|          Endpoint           |                                                Status                                                  |
+-----------------------------+--------------------------------------------------------------------------------------------------------+
|  tuannguyen.120910@gmail.com|  arn:aws:sns:ap-southeast-1:995310839463:macie-sensitive-alerts:a29dcd85-5ac8-47a4-ae7e-14f0bdee71ef   |
|  email-cua-ban@gmail.com    |  PendingConfirmation                                                                                   |
+-----------------------------+--------------------------------------------------------------------------------------------------------+
```

### Result

Email chính `tuannguyen.120910@gmail.com` đã được confirm thành công vì status đã là SNS subscription ARN thật, không còn `PendingConfirmation`.

Dòng `email-cua-ban@gmail.com` là subscription nhầm ban đầu và không ảnh hưởng đến kết quả lab.

## 6. EventBridge Rule

EventBridge rule đã được tạo để bắt event từ Amazon Macie.

### Evidence

```json
{
  "Name": "macie-findings-to-sns",
  "Arn": "arn:aws:events:ap-southeast-1:995310839463:rule/macie-findings-to-sns",
  "EventPattern": "{\n  \"source\": [\"aws.macie\"],\n  \"detail-type\": [\"Macie Finding\"]\n}\n",
  "State": "ENABLED",
  "EventBusName": "default",
  "CreatedBy": "995310839463"
}
```

### Event Pattern

```json
{
  "source": ["aws.macie"],
  "detail-type": ["Macie Finding"]
}
```

### Explanation

Rule này sẽ bắt các event có:

| Field | Value |
| --- | --- |
| `source` | `aws.macie` |
| `detail-type` | `Macie Finding` |

Khi Amazon Macie tạo finding, event sẽ được gửi vào EventBridge và match với rule này.

## 7. EventBridge Target

SNS topic đã được gắn làm target cho EventBridge rule.

### Evidence

```json
{
  "Targets": [
    {
      "Id": "1",
      "Arn": "arn:aws:sns:ap-southeast-1:995310839463:macie-sensitive-alerts"
    }
  ]
}
```

### Result

EventBridge rule `macie-findings-to-sns` sẽ gửi Macie Finding event đến SNS topic `macie-sensitive-alerts`.

## 8. Amazon Macie Finding

Amazon Macie đã phát hiện dữ liệu nhạy cảm trong file `customer-info.txt`.

### Evidence

```txt
-----------------------------------------------------------------
|                          GetFindings                          |
+----------+----------------------------------------------------+
|  bucket  |  macie-sensitive-lab-995310839463-ap-southeast-1   |
|  object  |  customer-info.txt                                 |
|  severity|  Low                                               |
|  type    |  SensitiveData:S3Object/Personal                   |
+----------+----------------------------------------------------+
```

### Finding Summary

| Field | Value |
| --- | --- |
| Finding Type | `SensitiveData:S3Object/Personal` |
| Severity | `Low` |
| Bucket | `macie-sensitive-lab-995310839463-ap-southeast-1` |
| Object | `customer-info.txt` |

### Explanation

Macie đã phát hiện object `customer-info.txt` có chứa dữ liệu cá nhân. Finding type là `SensitiveData:S3Object/Personal`.

## 9. Email Notification Evidence

SNS đã gửi email alert thành công đến địa chỉ `tuannguyen.120910@gmail.com`.

### Email Summary

| Field | Value |
| --- | --- |
| Sender | `AWS Notifications <no-reply@sns.amazonaws.com>` |
| Subject | `AWS Notification Message` |
| Source | `aws.macie` |
| Detail Type | `Macie Finding` |
| Region | `ap-southeast-1` |
| Finding Type | `SensitiveData:S3Object/Personal` |
| Severity | `Low` |
| Bucket | `macie-sensitive-lab-995310839463-ap-southeast-1` |
| Object | `customer-info.txt` |

### Important Email Content

```json
{
  "detail-type": "Macie Finding",
  "source": "aws.macie",
  "account": "995310839463",
  "region": "ap-southeast-1",
  "detail": {
    "type": "SensitiveData:S3Object/Personal",
    "title": "The S3 object contains personal information",
    "severity": {
      "score": 1,
      "description": "Low"
    },
    "resourcesAffected": {
      "s3Bucket": {
        "name": "macie-sensitive-lab-995310839463-ap-southeast-1"
      },
      "s3Object": {
        "key": "customer-info.txt",
        "path": "macie-sensitive-lab-995310839463-ap-southeast-1/customer-info.txt"
      }
    },
    "classificationDetails": {
      "result": {
        "status": {
          "code": "COMPLETE"
        },
        "sensitiveData": [
          {
            "category": "PERSONAL_INFORMATION",
            "totalCount": 2,
            "detections": [
              {
                "type": "PHONE_NUMBER",
                "count": 1
              },
              {
                "type": "NAME",
                "count": 1
              }
            ]
          }
        ]
      }
    }
  }
}
```

### Result

Email alert đã chứng minh luồng notification hoạt động thành công:

```txt
Macie Finding -> EventBridge -> SNS -> Email
```

## 10. Final Result

Bài lab đã hoàn thành thành công.

### Completed Checklist

| Requirement | Status |
| --- | --- |
| Create S3 bucket | Done |
| Upload sample sensitive data files | Done |
| Enable Amazon Macie | Done |
| Create Macie sensitive data discovery job | Done |
| Detect sensitive data in S3 object | Done |
| Create EventBridge rule for Macie Finding | Done |
| Send finding to SNS topic | Done |
| Confirm email subscription | Done |
| Receive email notification | Done |

## 11. Short Explanation for Presentation

Em đã tạo một S3 bucket chứa file mẫu có dữ liệu cá nhân giả. Sau đó em bật Amazon Macie và tạo sensitive data discovery job để quét bucket này. Macie đã phát hiện object `customer-info.txt` có chứa thông tin cá nhân như tên và số điện thoại, sau đó tạo finding với type `SensitiveData:S3Object/Personal`.

Finding này được gửi qua EventBridge rule có pattern `source = aws.macie` và `detail-type = Macie Finding`. EventBridge tiếp tục route event sang SNS topic, và SNS gửi email alert thành công về địa chỉ email của em. Như vậy flow `S3 -> Macie -> EventBridge -> SNS -> Email` đã hoạt động đúng.
