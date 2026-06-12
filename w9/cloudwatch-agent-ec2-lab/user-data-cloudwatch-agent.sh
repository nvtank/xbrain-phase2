#!/bin/bash
set -euxo pipefail

# User Data tự động cài CloudWatch Agent trên EC2.
# Lưu ý: EC2 vẫn cần IAM Role có policy CloudWatchAgentServerPolicy.

if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  exit 1
fi

case "${ID:-}" in
  amzn)
    if command -v dnf >/dev/null 2>&1; then
      dnf install -y amazon-cloudwatch-agent
    else
      yum install -y amazon-cloudwatch-agent
    fi
    ;;
  ubuntu|debian)
    apt-get update -y
    apt-get install -y wget
    wget -O /tmp/amazon-cloudwatch-agent.deb https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i /tmp/amazon-cloudwatch-agent.deb
    ;;
  *)
    echo "Unsupported OS: ${ID:-unknown}"
    exit 1
    ;;
esac

cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<'JSON'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "ImageId": "${aws:ImageId}",
      "InstanceType": "${aws:InstanceType}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": ["used_percent"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "swap": {
        "measurement": ["swap_used_percent"],
        "metrics_collection_interval": 60
      },
      "cpu": {
        "measurement": ["cpu_usage_idle", "cpu_usage_user", "cpu_usage_system"],
        "metrics_collection_interval": 60,
        "totalcpu": true
      },
      "net": {
        "measurement": ["bytes_sent", "bytes_recv"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    }
  }
}
JSON

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json

systemctl enable amazon-cloudwatch-agent
systemctl status amazon-cloudwatch-agent --no-pager || true
