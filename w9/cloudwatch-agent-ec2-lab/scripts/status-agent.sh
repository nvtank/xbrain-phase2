#!/usr/bin/env bash
set -euo pipefail

AGENT_CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

if [ ! -x "$AGENT_CTL" ]; then
  echo "CloudWatch Agent control binary not found."
  exit 1
fi

echo "==> CloudWatch Agent status:"
sudo "$AGENT_CTL" -m ec2 -a status || true

echo

echo "==> systemctl status:"
sudo systemctl status amazon-cloudwatch-agent --no-pager || true

echo

echo "==> Last 50 log lines:"
sudo tail -n 50 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log || true
