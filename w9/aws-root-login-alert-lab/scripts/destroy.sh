#!/usr/bin/env bash
set -euo pipefail

if [[ -f .generated/lab.env ]]; then
  # shellcheck disable=SC1091
  source .generated/lab.env
fi

REGION="${REGION:-us-east-1}"
PREFIX="${PREFIX:-root-login-alert}"
ACCOUNT_ID="${ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
TRAIL_NAME="${TRAIL_NAME:-${PREFIX}-trail}"
LOG_GROUP="${LOG_GROUP:-/aws/cloudtrail/${PREFIX}}"
ROLE_NAME="${ROLE_NAME:-${PREFIX}-cloudtrail-cwlogs-role}"
BUCKET="${BUCKET:-${PREFIX}-${ACCOUNT_ID}-${REGION}}"
TOPIC_ARN="${TOPIC_ARN:-}"
FILTER_NAME="${FILTER_NAME:-RootAccountLoginFilter}"
ALARM_NAME="${ALARM_NAME:-RootAccountLoginAlarm}"

read -r -p "This will delete lab resources. Continue? [y/N] " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Cancelled."
  exit 0
fi

printf "==> Deleting CloudWatch alarm\n"

aws cloudwatch delete-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$REGION" 2>/dev/null || true

printf "==> Deleting metric filter\n"

aws logs delete-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME" \
  --region "$REGION" 2>/dev/null || true

printf "==> Stopping and deleting CloudTrail\n"

aws cloudtrail stop-logging \
  --name "$TRAIL_NAME" \
  --region "$REGION" 2>/dev/null || true

aws cloudtrail delete-trail \
  --name "$TRAIL_NAME" \
  --region "$REGION" 2>/dev/null || true

printf "==> Deleting CloudWatch log group\n"

aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$REGION" 2>/dev/null || true

if [[ -n "$TOPIC_ARN" ]]; then
  printf "==> Deleting SNS topic\n"

  aws sns delete-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION" 2>/dev/null || true
fi

printf "==> Deleting IAM role policy and role\n"

aws iam delete-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "CloudTrailCloudWatchLogsPolicy" 2>/dev/null || true

aws iam delete-role \
  --role-name "$ROLE_NAME" 2>/dev/null || true

printf "==> Emptying and deleting S3 bucket: %s\n" "$BUCKET"

aws s3 rm "s3://${BUCKET}" --recursive 2>/dev/null || true

aws s3api delete-bucket \
  --bucket "$BUCKET" \
  --region "$REGION" 2>/dev/null || true

printf "==> Done.\n"
