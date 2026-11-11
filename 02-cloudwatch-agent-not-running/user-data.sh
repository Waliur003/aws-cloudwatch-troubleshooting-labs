#!/bin/bash
set -euxo pipefail

dnf install -y amazon-cloudwatch-agent python3

mkdir -p /opt/cloudwatch-lab02
mkdir -p /var/log/cloudwatch-lab02

cat > /opt/cloudwatch-lab02/app.sh <<'APP'
#!/bin/bash

LOG_FILE="/var/log/cloudwatch-lab02/app.log"

while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO Lab02 application running" \
    >> "$LOG_FILE"
  sleep 10
done
APP

chmod +x /opt/cloudwatch-lab02/app.sh

cat > /etc/systemd/system/cloudwatch-lab02-app.service <<'SERVICE'
[Unit]
Description=CloudWatch Lab02 Log Generator
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/cloudwatch-lab02/app.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now cloudwatch-lab02-app.service
