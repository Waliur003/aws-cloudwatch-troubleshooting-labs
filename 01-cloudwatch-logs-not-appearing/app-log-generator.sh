#!/bin/bash

LOG_DIR="/var/log/cloudwatch-lab01"
LOG_FILE="$LOG_DIR/app.log"

mkdir -p "$LOG_DIR"

while true; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "$TIMESTAMP INFO CloudWatch Lab01 application is running" \
    >> "$LOG_FILE"

  sleep 10
done
