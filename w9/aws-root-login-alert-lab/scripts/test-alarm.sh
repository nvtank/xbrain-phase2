#!/usr/bin/env bash
set -euo pipefail

if [[ -f .generated/lab.env ]]; then
  # shellcheck disable=SC1091
  source .generated/lab.env
fi

REGION="${REGION:-us-east-1}"
METRIC_NAMESPACE="${METRIC_NAMESPACE:-Security}"
METRIC_NAME="${METRIC_NAME:-RootAccountLoginCount}"
ALARM_NAME="${ALARM_NAME:-RootAccountLoginAlarm}"

printf "==> Sending test metric: %s/%s = 1\n" "$METRIC_NAMESPACE" "$METRIC_NAME"

aws cloudwatch put-metric-data \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --value 1 \
  --region "$REGION"

cat <<MSG

Test metric sent.
CloudWatch Alarm may need 1-5 minutes to enter ALARM state.

Run:
  ./scripts/status.sh

MSG
