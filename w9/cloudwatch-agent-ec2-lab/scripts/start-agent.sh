#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_SRC="$REPO_ROOT/configs/basic-config.json"
CONFIG_DST="/opt/aws/amazon-cloudwatch-agent/bin/config.json"
AGENT_CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

if [ ! -f "$CONFIG_SRC" ]; then
  echo "Config file not found: $CONFIG_SRC"
  exit 1
fi

if [ ! -x "$AGENT_CTL" ]; then
  echo "CloudWatch Agent control binary not found. Run scripts/install-cloudwatch-agent.sh first."
  exit 1
fi

echo "==> Copying config to $CONFIG_DST"
sudo cp "$CONFIG_SRC" "$CONFIG_DST"

echo "==> Starting CloudWatch Agent with config..."
sudo "$AGENT_CTL" \
  -a fetch-config \
  -m ec2 \
  -s \
  -c "file:$CONFIG_DST"

echo "==> Enabling service on boot..."
sudo systemctl enable amazon-cloudwatch-agent || true

echo "CloudWatch Agent started."
