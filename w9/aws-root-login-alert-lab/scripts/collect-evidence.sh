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
BUCKET="${BUCKET:-}"
METRIC_NAMESPACE="${METRIC_NAMESPACE:-Security}"
METRIC_NAME="${METRIC_NAME:-RootAccountLoginCount}"

mkdir -p evidence

run_capture() {
  local output_file="$1"
  local status
  shift

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    set +e
    "$@" 2>&1
    status=$?
    set -e
    if [[ "$status" -ne 0 ]]; then
      printf '\nCommand failed with exit code %s.\n' "$status"
    fi
  } > "evidence/${output_file}"
}

{
  printf "AWS Root Account Login Alert Lab Evidence\n"
  printf "Generated at: "
  date -u +"%Y-%m-%dT%H:%M:%SZ"
  printf "Region: %s\n" "$REGION"
  printf "Trail: %s\n" "$TRAIL_NAME"
  printf "Log group: %s\n" "$LOG_GROUP"
  printf "Metric filter: %s\n" "$FILTER_NAME"
  printf "Alarm: %s\n" "$ALARM_NAME"
  if [[ -n "$BUCKET" ]]; then
    printf "S3 bucket: %s\n" "$BUCKET"
  fi
  if [[ -n "$TOPIC_ARN" ]]; then
    printf "SNS topic: %s\n" "$TOPIC_ARN"
  fi
} > evidence/00-evidence-summary.txt

run_capture 01-caller-identity.json \
  aws sts get-caller-identity --output json

run_capture 02-cloudtrail-status.json \
  aws cloudtrail get-trail-status \
    --name "$TRAIL_NAME" \
    --region "$REGION" \
    --output json

run_capture 03-cloudwatch-log-group.json \
  aws logs describe-log-groups \
    --log-group-name-prefix "$LOG_GROUP" \
    --region "$REGION" \
    --output json

run_capture 04-metric-filter.json \
  aws logs describe-metric-filters \
    --log-group-name "$LOG_GROUP" \
    --filter-name-prefix "$FILTER_NAME" \
    --region "$REGION" \
    --output json

run_capture 05-cloudwatch-alarm.json \
  aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --region "$REGION" \
    --output json

if [[ -n "$TOPIC_ARN" ]]; then
  run_capture 06-sns-subscription.json \
    aws sns list-subscriptions-by-topic \
      --topic-arn "$TOPIC_ARN" \
      --region "$REGION" \
      --output json
fi

run_capture 07-terminal-status.txt \
  ./scripts/status.sh

printf "Evidence files saved in evidence/.\n"
