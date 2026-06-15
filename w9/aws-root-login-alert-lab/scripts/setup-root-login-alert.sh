#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-east-1}"
PREFIX="${PREFIX:-root-login-alert}"
EMAIL="${EMAIL:-}"

if [[ -z "$EMAIL" ]]; then
  echo "ERROR: Missing EMAIL. Example:"
  echo "EMAIL='your-email@gmail.com' ./scripts/setup-root-login-alert.sh"
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

TRAIL_NAME="${PREFIX}-trail"
LOG_GROUP="/aws/cloudtrail/${PREFIX}"
ROLE_NAME="${PREFIX}-cloudtrail-cwlogs-role"
BUCKET="${PREFIX}-${ACCOUNT_ID}-${REGION}"
TOPIC_NAME="${PREFIX}-sns-topic"
FILTER_NAME="RootAccountLoginFilter"
METRIC_NAMESPACE="Security"
METRIC_NAME="RootAccountLoginCount"
ALARM_NAME="RootAccountLoginAlarm"

mkdir -p .generated

cat > .generated/lab.env <<ENV
export REGION="${REGION}"
export PREFIX="${PREFIX}"
export ACCOUNT_ID="${ACCOUNT_ID}"
export TRAIL_NAME="${TRAIL_NAME}"
export LOG_GROUP="${LOG_GROUP}"
export ROLE_NAME="${ROLE_NAME}"
export BUCKET="${BUCKET}"
export TOPIC_NAME="${TOPIC_NAME}"
export FILTER_NAME="${FILTER_NAME}"
export METRIC_NAMESPACE="${METRIC_NAMESPACE}"
export METRIC_NAME="${METRIC_NAME}"
export ALARM_NAME="${ALARM_NAME}"
ENV

printf "\n==> Account: %s\n" "$ACCOUNT_ID"
printf "==> Region : %s\n" "$REGION"
printf "==> Email  : %s\n\n" "$EMAIL"

printf "==> Creating S3 bucket: %s\n" "$BUCKET"

if [[ "$REGION" == "us-east-1" ]]; then
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" 2>/dev/null || true
else
  aws s3api create-bucket \
    --bucket "$BUCKET" \
    --region "$REGION" \
    --create-bucket-configuration LocationConstraint="$REGION" 2>/dev/null || true
fi

aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

cat > .generated/bucket-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailAclCheck",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:GetBucketAcl",
      "Resource": "arn:aws:s3:::${BUCKET}"
    },
    {
      "Sid": "AWSCloudTrailWrite",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${BUCKET}/AWSLogs/${ACCOUNT_ID}/*",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      }
    }
  ]
}
JSON

aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy file://.generated/bucket-policy.json

printf "==> Creating CloudWatch Log Group: %s\n" "$LOG_GROUP"

aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" 2>/dev/null || true

LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --region "$REGION" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}'].arn | [0]" \
  --output text)

# LOG_GROUP_ARN="${LOG_GROUP_ARN%:\*}"

printf "==> Creating IAM Role: %s\n" "$ROLE_NAME"

cat > .generated/assume-role-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudtrail.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
JSON

aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file://.generated/assume-role-policy.json 2>/dev/null || true

cat > .generated/cloudtrail-cwlogs-policy.json <<JSON
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSCloudTrailCreateLogStream",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream"
      ],
      "Resource": [
        "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}:log-stream:${ACCOUNT_ID}_CloudTrail_*"
      ]
    },
    {
      "Sid": "AWSCloudTrailPutLogEvents",
      "Effect": "Allow",
      "Action": [
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:${REGION}:${ACCOUNT_ID}:log-group:${LOG_GROUP}:log-stream:${ACCOUNT_ID}_CloudTrail_*"
      ]
    }
  ]
}
JSON

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "CloudTrailCloudWatchLogsPolicy" \
  --policy-document file://.generated/cloudtrail-cwlogs-policy.json

ROLE_ARN=$(aws iam get-role \
  --role-name "$ROLE_NAME" \
  --query "Role.Arn" \
  --output text)

echo "export ROLE_ARN=\"${ROLE_ARN}\"" >> .generated/lab.env
echo "export LOG_GROUP_ARN=\"${LOG_GROUP_ARN}\"" >> .generated/lab.env

sleep 10

printf "==> Creating or updating CloudTrail: %s\n" "$TRAIL_NAME"

if aws cloudtrail describe-trails \
  --trail-name-list "$TRAIL_NAME" \
  --region "$REGION" \
  --query "trailList[0].Name" \
  --output text 2>/dev/null | grep -q "$TRAIL_NAME"; then
  aws cloudtrail update-trail \
    --name "$TRAIL_NAME" \
    --s3-bucket-name "$BUCKET" \
    --is-multi-region-trail \
    --include-global-service-events \
    --cloud-watch-logs-log-group-arn "$LOG_GROUP_ARN" \
    --cloud-watch-logs-role-arn "$ROLE_ARN" \
    --region "$REGION"
else
  aws cloudtrail create-trail \
    --name "$TRAIL_NAME" \
    --s3-bucket-name "$BUCKET" \
    --is-multi-region-trail \
    --include-global-service-events \
    --enable-log-file-validation \
    --cloud-watch-logs-log-group-arn "$LOG_GROUP_ARN" \
    --cloud-watch-logs-role-arn "$ROLE_ARN" \
    --region "$REGION"
fi

aws cloudtrail start-logging \
  --name "$TRAIL_NAME" \
  --region "$REGION"

printf "==> Creating SNS topic and email subscription\n"

TOPIC_ARN=$(aws sns create-topic \
  --name "$TOPIC_NAME" \
  --region "$REGION" \
  --query "TopicArn" \
  --output text)

echo "export TOPIC_ARN=\"${TOPIC_ARN}\"" >> .generated/lab.env

aws sns subscribe \
  --topic-arn "$TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$EMAIL" \
  --region "$REGION" >/dev/null

printf "==> Creating metric filter: %s\n" "$FILTER_NAME"

aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern '{ $.userIdentity.type = "Root" && $.eventType != "AwsServiceEvent" }' \
  --metric-transformations metricName="$METRIC_NAME",metricNamespace="$METRIC_NAMESPACE",metricValue=1 \
  --region "$REGION"

printf "==> Creating CloudWatch alarm: %s\n" "$ALARM_NAME"

aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Alert when AWS Root account is used" \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --statistic Sum \
  --period 300 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching \
  --alarm-actions "$TOPIC_ARN" \
  --region "$REGION"

cat <<SUMMARY

DONE.

Next steps:
1. Open your email and click "Confirm subscription" from AWS Notifications.
2. Run: ./scripts/status.sh
3. Test safely without root login: ./scripts/test-alarm.sh
4. Add screenshots to evidence/ and push repo to GitHub.

SUMMARY
