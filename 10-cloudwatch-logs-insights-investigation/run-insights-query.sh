#!/bin/bash

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
LOG_GROUP="${LOG_GROUP:-/cloudwatch-lab10/payment-api}"

QUERY_FILE="${1:?Usage: ./run-insights-query.sh QUERY_FILE}"

if [[ ! -f "$QUERY_FILE" ]]; then
  echo "ERROR: Query file not found: $QUERY_FILE"
  exit 1
fi

mkdir -p evidence

QUERY_NAME=$(basename "$QUERY_FILE" .cwli)

START_TIME=$(date -u -d '30 minutes ago' +%s)
END_TIME=$(date -u -d '1 minute from now' +%s)

echo "Log Group: $LOG_GROUP"
echo "Query File: $QUERY_FILE"
echo "Submitting query..."

QUERY_ID=$(aws logs start-query \
  --log-group-name "$LOG_GROUP" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string "$(cat "$QUERY_FILE")" \
  --query-language CWLI \
  --query queryId \
  --output text \
  --region "$AWS_REGION")

echo "Query ID: $QUERY_ID"

STATUS="Scheduled"

for attempt in $(seq 1 30); do

  STATUS=$(aws logs get-query-results \
    --query-id "$QUERY_ID" \
    --query status \
    --output text \
    --region "$AWS_REGION")

  echo "Attempt $attempt: $STATUS"

  if [[ "$STATUS" == "Complete" ]]; then
    break
  fi

  if [[ "$STATUS" == "Failed" || \
        "$STATUS" == "Cancelled" || \
        "$STATUS" == "Timeout" || \
        "$STATUS" == "Unknown" ]]; then
    echo "ERROR: Query ended with status $STATUS"
    exit 1
  fi

  sleep 2
done

if [[ "$STATUS" != "Complete" ]]; then
  echo "Query did not finish during polling."

  aws logs stop-query \
    --query-id "$QUERY_ID" \
    --region "$AWS_REGION" >/dev/null || true

  exit 1
fi

OUTPUT_FILE="evidence/${QUERY_NAME}.json"

aws logs get-query-results \
  --query-id "$QUERY_ID" \
  --output json \
  --region "$AWS_REGION" \
  > "$OUTPUT_FILE"

echo "Query complete."
echo "Evidence: $OUTPUT_FILE"
