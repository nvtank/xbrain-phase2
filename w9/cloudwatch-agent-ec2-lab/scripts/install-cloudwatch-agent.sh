#!/usr/bin/env bash
set -euo pipefail

echo "==> Detecting OS..."
if [ -f /etc/os-release ]; then
  . /etc/os-release
  echo "OS: ${PRETTY_NAME:-$ID}"
else
  echo "Cannot detect OS. /etc/os-release not found."
  exit 1
fi

echo "==> Installing Amazon CloudWatch Agent..."
case "${ID:-}" in
  amzn)
    if command -v dnf >/dev/null 2>&1; then
      sudo dnf install -y amazon-cloudwatch-agent
    else
      sudo yum install -y amazon-cloudwatch-agent
    fi
    ;;
  ubuntu|debian)
    sudo apt-get update -y
    sudo apt-get install -y wget
    TMP_DEB="/tmp/amazon-cloudwatch-agent.deb"
    wget -O "$TMP_DEB" https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    sudo dpkg -i "$TMP_DEB"
    ;;
  rhel|centos|rocky|almalinux)
    sudo yum install -y amazon-cloudwatch-agent
    ;;
  *)
    echo "Unsupported OS: ${ID:-unknown}"
    echo "Please install CloudWatch Agent manually for your distribution."
    exit 1
    ;;
esac

echo "==> Checking agent binary..."
if [ -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
  echo "CloudWatch Agent installed successfully."
else
  echo "CloudWatch Agent binary not found."
  exit 1
fi
