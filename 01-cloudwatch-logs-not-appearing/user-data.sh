#!/bin/bash
set -euxo pipefail

dnf install -y amazon-cloudwatch-agent

mkdir -p /opt/cloudwatch-lab01
mkdir -p /var/log/cloudwatch-lab01

cat > /opt/cloudwatch-lab01/app.sh <<'APP'
#!/bin/bash

LOG_FILE="/var/log/cloudwatch-lab01/app.log"

while true; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$TIMESTAMP INFO CloudWatch Lab01 application is running" >> "$LOG_FILE"
  sleep 10
done
APP

chmod +x /opt/cloudwatch-lab01/app.sh

cat > /etc/systemd/system/cloudwatch-lab01-app.service <<'SERVICE'
[Unit]
Description=CloudWatch Lab01 Application Log Generator
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/cloudwatch-lab01/app.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now cloudwatch-lab01-app.service
