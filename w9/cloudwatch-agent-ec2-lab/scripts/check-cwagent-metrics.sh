#!/usr/bin/env bash
set -euo pipefail

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI not found. Install AWS CLI or check metrics in AWS Console."
  exit 1
fi

echo "==> Getting region..."
REGION="${AWS_DEFAULT_REGION:-}"
if [ -z "$REGION" ]; then
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)
  REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/dynamic/instance-identity/document \
    | grep region \
    | awk -F\" '{print $4}' || true)
fi

if [ -z "$REGION" ]; then
  echo "Cannot determine region. Set AWS_DEFAULT_REGION first."
  echo "Example: export AWS_DEFAULT_REGION=ap-southeast-1"
  exit 1
fi

echo "Region: $REGION"

echo "==> Listing CWAgent metrics..."
aws cloudwatch list-metrics \
  --namespace CWAgent \
  --region "$REGION" \
  --max-items 20 \
  --query 'Metrics[].{MetricName:MetricName,Dimensions:Dimensions}' \
  --output table
