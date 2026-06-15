#!/usr/bin/env bash
set -euo pipefail

if [[ -f .generated/lab.env ]]; then
  # shellcheck disable=SC1091
  source .generated/lab.env
fi

REGION="${REGION:-us-east-1}"
TRAIL_NAME="${TRAIL_NAME:-root-login-alert-trail}"
LOG_GROUP="${LOG_GROUP:-/aws/cloudtrail/root-login-alert}"
FILTER_NAME="${FILTER_NAME:-RootAccountLoginFilter}"
ALARM_NAME="${ALARM_NAME:-RootAccountLoginAlarm}"
TOPIC_ARN="${TOPIC_ARN:-}"

printf "\n==> CloudTrail status\n"

aws cloudtrail get-trail-status \
  --name "$TRAIL_NAME" \
  --region "$REGION" \
  --query "{IsLogging:IsLogging,LatestDeliveryTime:LatestDeliveryTime,LatestCloudWatchLogsDeliveryTime:LatestCloudWatchLogsDeliveryTime}"

printf "\n==> Metric filter\n"

aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --filter-name-prefix "$FILTER_NAME" \
  --region "$REGION" \
  --query "metricFilters[].{Name:filterName,Pattern:filterPattern,Metric:metricTransformations[0].metricName,Namespace:metricTransformations[0].metricNamespace}"

printf "\n==> Alarm status\n"

aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$REGION" \
  --query "MetricAlarms[0].{Name:AlarmName,State:StateValue,Reason:StateReason}"

if [[ -n "$TOPIC_ARN" ]]; then
  printf "\n==> SNS subscription\n"

  aws sns list-subscriptions-by-topic \
    --topic-arn "$TOPIC_ARN" \
    --region "$REGION" \
    --query "Subscriptions[].{Endpoint:Endpoint,Status:SubscriptionArn,Protocol:Protocol}"
fi
