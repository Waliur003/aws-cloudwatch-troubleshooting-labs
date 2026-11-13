#!/bin/bash
set -euo pipefail

AWS_REGION="us-east-1"
LOG_GROUP="/cloudwatch-lab08/payment-api"
EXPECTED_RETENTION=14

RESULT=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].[retentionInDays,retentionPolicyName]" \
  --output json \
  --region "$AWS_REGION")

export RESULT
export EXPECTED_RETENTION

python3 - <<'PY'
import json
import os
import sys

results = json.loads(os.environ["RESULT"])
expected = int(os.environ["EXPECTED_RETENTION"])

if len(results) != 1:
    print("FAIL: Expected exactly one log group")
    sys.exit(1)

retention, account_policy = results[0]

if account_policy:
    print(f"INFO: Account-level policy applies: {account_policy}")

if retention == expected:
    print(f"PASS: Effective retention is {expected} days")
else:
    print(
        f"FAIL: Expected {expected} days, "
        f"found {retention if retention is not None else 'Never Expire'}"
    )
    sys.exit(1)
PY