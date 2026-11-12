#!/bin/bash

set -u

AWS_REGION="us-east-1"
NAMESPACE="CloudWatchLab06/API"
METRIC_NAME="ResponseLatency"
ENVIRONMENT="Production"

LATENCY=900

# 30 samples, one every 10 seconds
for i in $(seq 1 30); do

  echo "Publishing sample $i: ${LATENCY}ms"

  if ! aws cloudwatch put-metric-data \
    --namespace "$NAMESPACE" \
    --metric-data \
      "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$ENVIRONMENT}],Value=$LATENCY,Unit=Milliseconds" \
    --region "$AWS_REGION"; then
    echo "Metric publishing failed"
    exit 1
  fi

  sleep 10

done

echo "Metric publisher finished"
