#!/bin/bash

for i in $(seq 1 12); do
  aws cloudwatch put-metric-data \
    --namespace "CloudWatchLab06/API" \
    --metric-data \
      "MetricName=ResponseLatency,Dimensions=[{Name=Environment,Value=Production}],Value=150,Unit=Milliseconds" \
    --region us-east-1 || exit 1

  echo "Published normal latency sample $i"
  sleep 10
done
