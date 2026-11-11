#!/bin/bash
set -euxo pipefail

dnf install -y amazon-cloudwatch-agent python3

mkdir -p /opt/cloudwatch-lab03

echo "CloudWatch Lab03 EC2 Metrics Troubleshooting" \
  > /opt/cloudwatch-lab03/README.txt
