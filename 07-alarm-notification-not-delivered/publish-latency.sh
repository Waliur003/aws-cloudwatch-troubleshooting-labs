#!/bin/bash

set -euo pipefail

AWS_REGION="us-east-1"
NAMESPACE="CloudWatchLab07/API"
METRIC_NAME="ResponseLatency"
ENVIRONMENT="Lab07"

LATENCY="${1:-900}"
SAMPLES="${2:-30}"

for i in $(seq 1 "$SAMPLES"); do
  echo "Publishing sample $i/$SAMPLES: ${LATENCY}ms"

  aws cloudwatch put-metric-data \
    --namespace "$NAMESPACE" \
    --metric-data \
      "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$ENVIRONMENT}],Value=$LATENCY,Unit=Milliseconds" \
    --region "$AWS_REGION"

  sleep 10
done

echo "Metric publishing completed"
