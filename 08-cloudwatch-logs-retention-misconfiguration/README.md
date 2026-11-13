# Lab 08 — CloudWatch Logs Retention Misconfiguration

## Overview

This lab demonstrates how to investigate and fix an Amazon CloudWatch Logs retention misconfiguration.

CloudWatch Logs is used to collect, store, and analyze application logs. Log retention determines how long CloudWatch keeps log events before they become eligible for deletion.

By default, a CloudWatch Logs log group retains events indefinitely unless a retention policy is configured or an applicable account-level policy overrides that behavior.

In this lab, we simulate a payment API that publishes structured JSON logs to Amazon CloudWatch Logs.

The company's log management requirement is to retain application logs for **14 days**.

However, we intentionally create the CloudWatch log group without configuring a retention policy.

As a result, the log group is configured for indefinite retention instead of the required 14 days, assuming no account-level retention policy applies.

Although the application logs are being ingested correctly, the retention configuration is incorrect.

We investigate the problem using AWS CLI, inspect the log group configuration, verify log ingestion, and identify the missing retention policy.

After identifying the root cause, we configure 14-day retention using the `PutRetentionPolicy` API.

We verify the updated configuration and confirm that recent application logs remain accessible.

We also create a Bash auditing script to detect incorrect retention settings automatically.

Finally, we delete the temporary CloudWatch Logs resources.

**Troubleshooting Workflow:**

Log Group Creation → Log Stream Creation → JSON Log Ingestion → Retention Investigation → Missing Retention Policy → Root Cause Analysis → 14-Day Retention Configuration → Verification → Automated Retention Audit → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-008 |
| Difficulty | Intermediate |
| AWS Service | Amazon CloudWatch Logs |
| AWS Region | `us-east-1` |
| Local Environment | WSL Ubuntu |
| Interface | AWS CLI v2 |
| Scripting Languages | Bash, Python 3 |
| Log Group | `/cloudwatch-lab08/payment-api` |
| Log Stream | `application-logs` |
| Application | Simulated Payment API |
| Log Format | JSON |
| Initial Retention | Not configured |
| Intended Fault | Indefinite retention |
| Required Retention | 14 days |
| Root Cause | Missing log group retention policy |
| Remediation | `PutRetentionPolicy` |
| Verification | `DescribeLogGroups`, `GetLogEvents` |
| Additional Validation | Bash retention audit |
| Cleanup | Delete temporary log group |

### Lab Objectives

- Understand CloudWatch Logs retention policies.
- Create CloudWatch log groups and log streams using AWS CLI.
- Publish structured JSON application logs.
- Diagnose missing retention configurations.
- Understand indefinite log retention.
- Investigate storage and governance implications.
- Configure a 14-day retention policy.
- Verify effective retention settings.
- Understand account-level retention policies.
- Validate log ingestion after remediation.
- Create an automated Bash retention audit.
- Safely delete temporary CloudWatch Logs resources.

---

## 2. Production Incident Scenario

### Incident Description

A company operates a payment processing API that generates application logs.

The Cloud Operations team uses Amazon CloudWatch Logs to collect API activity, application errors, and operational events.

The company's internal data retention requirement states that application logs should be retained for 14 days.

However, during a routine cloud infrastructure audit, an engineer discovers that a CloudWatch log group was created without a retention policy.

The log group is receiving application logs successfully.

The team can retrieve the logs, search for application errors, and investigate incidents.

However, the retention configuration is missing.

Without an applicable retention policy, CloudWatch retains log events indefinitely.

This can cause unnecessary storage costs and may violate the company's internal log lifecycle requirements.

A Cloud Engineer is assigned to investigate the log group configuration.

The engineer verifies the log group, log stream, application log events, and retention settings.

After identifying the missing retention policy, the engineer configures 14-day retention and confirms that the change is applied.

The engineer also implements an automated audit to detect future retention misconfigurations.

### Incident Symptoms

- CloudWatch log group exists.
- CloudWatch log stream exists.
- Application logs are being ingested.
- Log events are searchable.
- Application error logs are available.
- Required retention is 14 days.
- Log group retention is not configured.
- No applicable account-level policy enforces the expected retention.
- Log events may remain stored longer than required.
- Storage usage can increase as logs accumulate.
- Log lifecycle configuration does not meet the company's requirement.

### Business Impact

- Unnecessary log storage costs.
- Increased long-term data retention.
- Potential violations of internal data governance policies.
- Greater exposure from keeping obsolete operational data.
- Inconsistent retention settings between environments.
- Additional manual work during infrastructure audits.
- Poor lifecycle management across CloudWatch log groups.

### Objective

Identify why the CloudWatch log group does not have the required retention period, configure 14-day retention, verify the effective policy, and implement a repeatable retention audit.

---

## 3. AWS Architecture

### CloudWatch Logs Architecture

```text
                    WSL Ubuntu
                         |
                         v
                 Python Log Generator
                         |
                         v
                 Structured JSON Logs
                         |
                         v
                      AWS CLI
                         |
                         v
                   PutLogEvents
                         |
                         v
                Amazon CloudWatch Logs
                         |
                         v
                      Log Group
              /cloudwatch-lab08/payment-api
                         |
                         v
                     Log Stream
                   application-logs
                         |
                         v
                    Log Retention
                         |
                         v
                CloudWatch Log Lifecycle
```

### Architecture Before Remediation

```text
Payment API Application
          |
          v
Structured JSON Log Events
          |
          v
CloudWatch Logs
          |
          v
Log Group Created
          |
          v
Retention Policy Omitted
          |
          v
Indefinite Retention
          |
          v
Logs Accumulate Over Time
          |
          v
Potential Storage Cost Growth
          |
          v
Data Governance Risk
```

### Architecture After Remediation

```text
Payment API Application
          |
          v
Structured JSON Log Events
          |
          v
CloudWatch Logs
          |
          v
Log Group
          |
          v
Retention Policy = 14 Days
          |
          v
Log Lifecycle Management
          |
          v
Expired Events Marked for Deletion
          |
          v
CloudWatch Deletes Expired Data
```

### Architecture Components

| Component | Purpose |
|---|---|
| WSL Ubuntu | Local troubleshooting environment |
| Python 3 | Generates structured application logs |
| AWS CLI | Interacts with CloudWatch Logs |
| CloudWatch Log Group | Organizes application logs and retention |
| CloudWatch Log Stream | Stores the sequence of application log events |
| PutLogEvents | Publishes log events |
| GetLogEvents | Retrieves log events |
| FilterLogEvents | Searches matching log events |
| DescribeLogGroups | Inspects log group configuration |
| PutRetentionPolicy | Configures log retention |
| Bash Audit Script | Detects incorrect retention settings |

This lab does not require Amazon EC2, VPC networking, or new IAM roles.

---

## 4. Understanding CloudWatch Logs Retention

### What Is Amazon CloudWatch Logs?

Amazon CloudWatch Logs is an AWS service used to collect, store, search, and analyze log events from applications and infrastructure.

Examples of log sources include:

- Amazon EC2 applications
- AWS Lambda
- Amazon ECS
- Amazon EKS
- Amazon API Gateway
- Application servers
- Security monitoring systems
- Operating system logs

### What Is a Log Group?

A log group organizes related log streams.

It provides configuration settings such as:

- Log retention
- Encryption
- Log class
- Tags
- Access and management settings

This lab uses:

`/cloudwatch-lab08/payment-api`

### What Is a Log Stream?

A log stream contains a sequence of log events generated by a specific source.

This lab uses:

`application-logs`

### What Is a Log Event?

A log event contains:

- A timestamp
- A message

Example:

```json
{
  "timestamp": 1760000000000,
  "message": "{\"level\":\"ERROR\",\"service\":\"payment-api\",\"event\":\"payment_timeout\"}"
}
```

The timestamp above is illustrative.

### What Is a Retention Policy?

A retention policy determines how long CloudWatch keeps log events before they become eligible for expiration.

Examples of supported retention periods include:

| Retention | Example Use |
|---|---|
| 1 day | Temporary development logs |
| 3 days | Short-term debugging |
| 7 days | Development application logs |
| 14 days | This lab's application logs |
| 30 days | General operational logs |
| 90 days | Longer operational investigation |
| 365 days | Long-term retention requirements |

Retention requirements vary by organization and applicable policies.

### What Is the Default Retention?

When no applicable retention policy exists, CloudWatch Logs retains events indefinitely.

A log group's `retentionInDays` field is generally absent when no explicit retention setting exists.

### What Is PutRetentionPolicy?

`PutRetentionPolicy` configures the retention period for a CloudWatch log group.

Example:

```bash
aws logs put-retention-policy \
  --log-group-name "/cloudwatch-lab08/payment-api" \
  --retention-in-days 14
```

### What Happens When Logs Expire?

CloudWatch marks log events for deletion after they exceed the applicable retention period.

Expired events are generally physically removed within 72 hours, although deletion can take longer.

### What Is an Account-Level Retention Policy?

CloudWatch Logs can support account-level retention policies.

When an applicable account-level policy overrides the log group's setting, engineers must inspect the effective configuration rather than assuming the log group setting alone determines retention.

### Why Does Retention Matter?

Correct retention management helps organizations:

- Control log storage costs.
- Reduce unnecessary data retention.
- Maintain consistent operational policies.
- Support security and governance requirements.
- Prevent accidental indefinite storage of application logs.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- Python 3
- CloudWatch Logs permissions
- Git and GitHub

### Required AWS API Permissions

The AWS identity needs authorization for operations such as:

```text
logs:CreateLogGroup
logs:CreateLogStream
logs:PutLogEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:GetLogEvents
logs:FilterLogEvents
logs:PutRetentionPolicy
logs:DeleteLogGroup
logs:ListTagsForResource
```

### Security Rules

- Use a dedicated disposable log group.
- Do not modify production log retention settings.
- Do not publish real payment information.
- Use synthetic application logs only.
- Avoid including passwords or secrets in log messages.
- Verify resource ownership before deletion.
- Review evidence before committing it.
- Delete temporary lab resources after testing.

### Cost Considerations

CloudWatch Logs may incur charges for log ingestion and storage.

The lab generates only a small number of short JSON log events.

No EC2 instances, EBS volumes, or public IPv4 addresses are required.

---

## 6. Prepare WSL Ubuntu

### Step 1 — Verify AWS CLI

```bash
aws --version
aws sts get-caller-identity
```

### Step 2 — Configure Environment Variables

```bash
export AWS_REGION="us-east-1"
export AWS_PAGER=""

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab08"

export LOG_GROUP="/cloudwatch-lab08/payment-api"
export LOG_STREAM="application-logs"

export REQUIRED_RETENTION="14"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$LOG_GROUP"
echo "$LOG_STREAM"
echo "$REQUIRED_RETENTION"
```

All AWS CLI commands use the `us-east-1` Region.

---

## 7. Create CloudWatch Log Group

### Step 1 — Create the Log Group

```bash
aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --tags "Project=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

We intentionally do not configure a retention policy.

This introduces the lab fault.

### Step 2 — Verify Log Group Creation

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION"
```

Expected: the log group exists.

### Step 3 — Check Retention Configuration

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,Retention:retentionInDays,Policy:retentionPolicyName,StoredBytes:storedBytes}" \
  --output json \
  --region "$AWS_REGION"
```

For a new log group without an applicable account-level retention policy, the retention value should be unset.

### Step 4 — Save Initial Configuration

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION" \
  > lab08-before-log-group.json
```

### Initial Configuration Summary

| Setting | Expected Result |
|---|---|
| Log Group | Created |
| Log Stream | Not yet created |
| Retention Policy | Not configured |
| Required Retention | 14 days |
| Intended Fault | Present |

---

## 8. Create Log Stream and Generate Application Logs

### Step 1 — Create Log Stream

```bash
aws logs create-log-stream \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --region "$AWS_REGION"
```

### Step 2 — Verify Log Stream

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --query 'logStreams[].{Name:logStreamName,StoredBytes:storedBytes}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: `application-logs`.

### Step 3 — Create Python Log Generator

Save as `generate-test-logs.py`:

```python
#!/usr/bin/env python3

import json
import time

messages = [
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "application_started",
        "environment": "lab08"
    },
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "request_received",
        "endpoint": "/payments"
    },
    {
        "level": "WARN",
        "service": "payment-api",
        "event": "slow_response",
        "latency_ms": 750
    },
    {
        "level": "ERROR",
        "service": "payment-api",
        "event": "payment_timeout",
        "request_id": "lab08-demo-001"
    },
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "request_completed",
        "status": 200
    }
]

base_timestamp = int(time.time() * 1000)

events = []

for index, message in enumerate(messages):
    events.append({
        "timestamp": base_timestamp + index,
        "message": json.dumps(message)
    })

with open("test-log-events.json", "w") as file:
    json.dump(events, file, indent=2)

print("Generated", len(events), "test log events")
```

### Step 4 — Generate Test Logs

```bash
python3 generate-test-logs.py
```

Expected:

```text
Generated 5 test log events
```

### Step 5 — Inspect Generated Logs

```bash
cat test-log-events.json
```

The file contains five structured JSON log events with ordered timestamps.

---

## 9. Publish and Verify CloudWatch Logs

### Step 1 — Publish Test Log Events

```bash
aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events file://test-log-events.json \
  --region "$AWS_REGION"
```

Expected: the API request succeeds.

### Step 2 — Retrieve Log Events

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --query 'events[].{Timestamp:timestamp,Message:message}' \
  --output json \
  --region "$AWS_REGION"
```

Expected: five synthetic application logs.

### Step 3 — Search for Application Errors

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern 'ERROR' \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: the payment timeout error message.

### Step 4 — Save Ingestion Evidence

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --query 'events[].{Timestamp:timestamp,Message:message}' \
  --output json \
  --region "$AWS_REGION" \
  > lab08-ingested-events.json
```

### Expected Findings

| Component | Expected Result |
|---|---|
| Log Group | Exists |
| Log Stream | Exists |
| JSON Logs | Generated |
| PutLogEvents | Successful |
| GetLogEvents | Returns events |
| Error Filtering | Working |
| Log Ingestion | Healthy |

The incident does not involve a log ingestion failure.

---

## 10. Fault Injection — Retention Misconfiguration

### Step 1 — Inspect Retention Again

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,Retention:retentionInDays,Policy:retentionPolicyName}" \
  --output json \
  --region "$AWS_REGION"
```

Expected for the intended fault:

```json
[
  {
    "Name": "/cloudwatch-lab08/payment-api",
    "Retention": null,
    "Policy": null
  }
]
```

This is an illustrative response. Account-level retention policies can change the effective result.

### Step 2 — Verify Log Ingestion Is Working

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern 'ERROR' \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: application error logs remain accessible.

### Step 3 — Inspect Stored Bytes

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,StoredBytes:storedBytes}" \
  --output table \
  --region "$AWS_REGION"
```

The stored byte count may not update immediately after ingestion.

### Step 4 — Compare Required and Actual Retention

| Requirement | Actual Configuration |
|---|---|
| Retain logs for 14 days | No group retention configured |
| Automatically expire old logs | Not enforced by group setting |
| Control long-term log storage | Potentially ineffective |
| Meet internal retention requirement | Not satisfied |

### Step 5 — Capture Misconfiguration Evidence

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION" \
  > lab08-before-retention.json
```

### Fault Injection Summary

| Component | Expected Finding |
|---|---|
| Log Group | Healthy |
| Log Stream | Healthy |
| Log Ingestion | Working |
| Log Retrieval | Working |
| Required Retention | 14 days |
| Group Retention | Unset |
| Root Cause | Missing retention policy |
| Incident | Active |

---

## 11. Investigate Retention and Storage Implications

### Investigation 1 — Confirm Log Group Configuration

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION"
```

Inspect the `retentionInDays` field.

### Investigation 2 — Check Account-Level Policy Information

Inspect whether the log group reports an applicable account-level retention policy.

If `retentionPolicyName` is populated, investigate the effective retention behavior before making changes.

The absence of an explicit group policy alone does not establish indefinite retention when an account-level override applies.

### Investigation 3 — Verify Log Events

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --region "$AWS_REGION"
```

### Investigation 4 — Search for Errors

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern 'ERROR' \
  --region "$AWS_REGION"
```

### Investigation 5 — Review Stored Data

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,StoredBytes:storedBytes}" \
  --output table \
  --region "$AWS_REGION"
```

### Storage Impact Example

Assume an application generates 100 GB of logs per day.

| Retention | Approximate Accumulated Log Volume |
|---|---|
| 14 days | 1,400 GB |
| 30 days | 3,000 GB |
| 90 days | 9,000 GB |
| 365 days | 36,500 GB |

These values are illustrative raw log volumes, not actual CloudWatch billing estimates. They exclude compression, storage-class behavior, and other billing factors.

### Investigation Summary

| Investigation | Expected Finding |
|---|---|
| Application Logs | Available |
| CloudWatch Log Group | Exists |
| CloudWatch Log Stream | Exists |
| Log Ingestion | Successful |
| Required Retention | 14 days |
| Actual Retention | Unset |
| Account-Level Override | None for intended fault |
| Storage Lifecycle | Incorrect |
| Root Cause | Missing retention policy |

---

## 12. Root Cause Analysis

### Root Cause

The CloudWatch Logs log group was created without an explicit retention policy.

The company requires application logs to be retained for 14 days.

However, the log group did not have the required retention setting.

When no applicable account-level policy overrides this configuration, CloudWatch Logs retains the log events indefinitely by default.

The application was still able to publish logs successfully.

The incident was caused by log lifecycle configuration, not by log ingestion or application health.

### Root Cause Flow

```text
Payment API Logs
          |
          v
CloudWatch Logs
          |
          v
Log Group Created
          |
          v
Retention Setting Omitted
          |
          v
No Automatic Expiration
          |
          v
Logs Retained Indefinitely
          |
          v
Unnecessary Long-Term Storage
          |
          v
Potential Cost and Governance Impact
```

### Five Whys

1. **Why are logs being retained longer than required?** The effective log retention configuration does not enforce 14 days.
2. **Why is the retention setting missing?** It was omitted during log group creation.
3. **Why doesn't CloudWatch automatically expire the logs?** Indefinite retention is the default when no applicable policy exists.
4. **Why was the configuration error overlooked?** Log retention was not validated during setup.
5. **How was the issue resolved?** Configure the required retention policy and verify its effective value.

### Root Cause Summary

| Component | Finding |
|---|---|
| Incident | INC-CW-008 |
| AWS Service | CloudWatch Logs |
| Log Ingestion | Healthy |
| Log Retrieval | Healthy |
| Retention Requirement | 14 days |
| Initial Group Retention | Unset |
| Root Cause | Retention policy omitted |
| Remediation | PutRetentionPolicy |
| Expected Recovery | 14-day retention |
| Application Redeployment | Not required |

**Key Lesson:** Correct log ingestion does not guarantee that log retention and lifecycle requirements are being enforced.

---

## 13. Remediation — Configure 14-Day Log Retention

### Step 1 — Apply Retention Policy

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days "$REQUIRED_RETENTION" \
  --region "$AWS_REGION"
```

Expected: successful completion.

### Step 2 — Verify Retention

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,Retention:retentionInDays,Policy:retentionPolicyName}" \
  --output table \
  --region "$AWS_REGION"
```

Expected, if no account-level policy overrides the setting:

```text
Retention: 14
```

### Step 3 — Inspect Full Configuration

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION"
```

Expected configuration includes:

```json
{
  "logGroupName": "/cloudwatch-lab08/payment-api",
  "retentionInDays": 14
}
```

The response above is an illustrative excerpt.

### Step 4 — Save Corrected Configuration

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION" \
  > lab08-after-retention.json
```

### Before and After Comparison

| Configuration | Before Remediation | After Remediation |
|---|---|---|
| Log Group | Exists | Exists |
| Log Stream | Exists | Exists |
| Log Ingestion | Working | Working |
| Log Retrieval | Working | Working |
| Retention | Unset | 14 days |
| Log Lifecycle | Indefinite by default | 14-day retention |
| Root Cause | Active | Corrected |
| Application Redeployment | Not required | Not required |

---

## 14. Verify Log Ingestion After Remediation

### Step 1 — Retrieve Recent Log Events

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --query 'events[].{Timestamp:timestamp,Message:message}' \
  --output json \
  --region "$AWS_REGION"
```

Expected: recent application logs remain available.

### Step 2 — Search Error Logs

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern 'ERROR' \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: the simulated payment timeout error.

### Step 3 — Generate a Fresh Verification Event

```bash
export NOW_MS=$(date +%s%3N)
```

Create `verification-event.json`:

```bash
printf '[{"timestamp":%s,"message":"{\\"level\\":\\"INFO\\",\\"event\\":\\"retention_policy_verified\\",\\"service\\":\\"payment-api\\"}"}]\n' \
  "$NOW_MS" > verification-event.json
```

### Step 4 — Publish Verification Event

```bash
aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events file://verification-event.json \
  --region "$AWS_REGION"
```

### Step 5 — Retrieve Verification Event

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"retention_policy_verified"' \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: the newly published verification event.

### Step 6 — Save Final Log Evidence

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --query 'events[].{Timestamp:timestamp,Message:message}' \
  --output json \
  --region "$AWS_REGION" \
  > lab08-after-events.json
```

### Verification Summary

| Check | Expected Result |
|---|---|
| Retention Setting | 14 days |
| Recent Logs | Available |
| Error Search | Working |
| New Log Ingestion | Working |
| Application Redeployment | Not required |
| Incident | Resolved after verification |

---

## 15. Understanding Log Expiration Behavior

### How CloudWatch Log Expiration Works

When a log event reaches the applicable retention age, CloudWatch marks it for deletion.

The event is no longer available for normal retrieval after expiration processing.

Physical deletion generally occurs within 72 hours, although it may take longer.

### Log Lifecycle

```text
Log Event Generated
        |
        v
PutLogEvents
        |
        v
CloudWatch Logs Storage
        |
        v
14-Day Retention Reached
        |
        v
Event Marked for Deletion
        |
        v
Excluded From Archival Storage Billing
        |
        v
Physical Deletion
```

### Can Old Log Events Be Used to Test Expiration Immediately?

Not reliably.

CloudWatch Logs rejects new log events older than 14 days.

Events older than the log group's current retention period are also rejected.

Therefore, this lab verifies the retention configuration rather than claiming to observe a full 14-day expiration process in a short exercise.

### Does Changing Retention Delete All Existing Logs?

No.

Recent log events within the configured retention period remain available.

Older events that exceed the retention period become eligible for expiration.

### Why Is This Important for Cloud Security?

A retention policy supports data lifecycle requirements and reduces unnecessary long-term exposure of application information.

Retention periods should be chosen according to organizational requirements, investigation needs, and any applicable legal or regulatory obligations.

---

## 16. Automated Retention Audit Using Bash

This section adds a reusable auditing workflow.

The audit checks whether the expected retention period is configured.

### Step 1 — Create Audit Script

Save as `audit-retention.sh`:

```bash
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
```

### Step 2 — Make Script Executable

```bash
chmod +x audit-retention.sh
```

### Step 3 — Run the Audit

```bash
./audit-retention.sh
```

Expected when the effective retention is 14 days:

```text
PASS: Effective retention is 14 days
```

### Step 4 — Test Audit Failure

Temporarily configure 30-day retention:

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 30 \
  --region "$AWS_REGION"
```

Run:

```bash
./audit-retention.sh
```

Expected when no account-level policy overrides the log-group setting:

```text
FAIL: Expected 14 days, found 30
```

### Step 5 — Restore Required Retention

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 14 \
  --region "$AWS_REGION"
```

### Step 6 — Verify the Audit Passes Again

```bash
./audit-retention.sh
```

Expected:

```text
PASS: Effective retention is 14 days
```

### Why Automate Retention Audits?

An automated check can identify misconfigured log groups before they accumulate unnecessary data.

In production, similar logic can be integrated with:

- AWS Config
- AWS Lambda
- EventBridge
- GitHub Actions
- Terraform validation workflows
- Security compliance reporting

### Production Improvement

For larger AWS environments, auditing should cover every relevant log group across required accounts and Regions.

The basic script in this lab only audits one designated log group.

---

## 17. Production Troubleshooting Best Practices

### Log Retention Troubleshooting Checklist

1. Identify the affected log group.
2. Verify the AWS Region.
3. Confirm the log group exists.
4. Inspect its retention configuration.
5. Check applicable account-level retention policies.
6. Verify log ingestion.
7. Inspect log streams.
8. Retrieve recent log events.
9. Search for relevant application errors.
10. Review stored data information.
11. Compare retention with company requirements.
12. Identify the root cause.
13. Configure the required retention policy.
14. Verify the effective retention.
15. Confirm recent logs remain accessible.
16. Publish a new verification event.
17. Validate ingestion after remediation.
18. Run an automated retention audit.
19. Document evidence.
20. Delete temporary lab resources.

### Common CloudWatch Logs Retention Problems

| Symptom | Possible Cause |
|---|---|
| Logs retained indefinitely | Retention not configured |
| Logs disappear too early | Retention too short |
| Retention differs from expectation | Account-level policy |
| Retention update fails | Missing IAM permission |
| Log group missing | Wrong Region or log group name |
| Stored bytes not updating immediately | Reporting delay |
| Old logs are no longer searchable | Retention expiration |
| Logs not appearing | Ingestion or stream issue |
| Logs stored longer than needed | Missing lifecycle governance |
| Log retention changes unexpectedly | Manual or automated configuration change |

### Production Recommendations

- Configure retention explicitly during log group creation.
- Use consistent retention standards.
- Avoid indefinite retention unless justified.
- Manage retention settings through Infrastructure as Code.
- Audit retention configuration regularly.
- Monitor the creation of new log groups.
- Review account-level retention policies.
- Protect sensitive data in application logs.
- Validate retention after changes.
- Document the approved lifecycle requirement for every important log category.

---

## 18. AWS Resource Cleanup

**Warning:** Only delete the disposable Lab 08 log group. Deleting a CloudWatch log group permanently removes its log streams and stored events.

### Step 1 — Verify Resource Ownership

Retrieve the log group ARN:

```bash
export LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].arn | [0]" \
  --output text \
  --region "$AWS_REGION")
```

Inspect tags:

```bash
aws logs list-tags-for-resource \
  --resource-arn "$LOG_GROUP_ARN" \
  --region "$AWS_REGION"
```

Confirm:

`Project=CloudWatch-Troubleshooting-Lab08`

### Step 2 — Save Final Configuration

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION" \
  > lab08-final-configuration.json
```

### Step 3 — Delete Log Group

```bash
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$AWS_REGION"
```

Deleting the log group also deletes its log streams and log events.

### Step 4 — Verify Deletion

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[]
```

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Log Group | Deleted |
| CloudWatch Log Stream | Deleted with log group |
| Test Log Events | Deleted with log group |
| Retention Setting | Removed with log group |
| EC2 Instances | None created |
| VPC Resources | None created |
| IAM Roles | None created |

---

## 19. Interview Questions and Answers

### Q1. What is the default retention period for a CloudWatch Logs log group?

By default, logs are retained indefinitely unless an applicable retention policy is configured.

### Q2. What caused this lab's incident?

The log group was created without the required 14-day retention policy.

### Q3. How do you check log retention using AWS CLI?

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/your/log/group"
```

### Q4. How do you configure 14-day retention?

```bash
aws logs put-retention-policy \
  --log-group-name "/your/log/group" \
  --retention-in-days 14
```

### Q5. What is the difference between a log group and a log stream?

A log group organizes related logs and their configuration.

A log stream contains individual log events from a source.

### Q6. What does PutLogEvents do?

It publishes log events to a CloudWatch Logs log stream.

### Q7. Does CloudWatch immediately remove expired logs?

Not necessarily. Events are marked for deletion and are generally physically removed within 72 hours.

### Q8. Does a retention policy stop new logs from being ingested?

No. Retention controls how long events are stored, not whether new events are accepted.

### Q9. Can different log groups have different retention periods?

Yes, subject to applicable account-level policies and organizational requirements.

### Q10. Can account-level retention policies override log group settings?

Yes. Account-level retention policies can take precedence when applicable.

### Q11. Why is indefinite retention potentially problematic?

It can increase storage costs and result in keeping information longer than an organization requires.

### Q12. How can engineers automatically detect incorrect retention?

They can use Bash, Python, AWS Config, Lambda, or Infrastructure as Code validation to audit log group retention.

### Q13. Why is log retention important for Cloud Security Engineers?

It supports data governance, reduces unnecessary storage of operational information, and helps organizations meet approved log lifecycle requirements.

### Q14. How would you explain this lab in an interview?

I created a CloudWatch Logs log group and published structured application logs using AWS CLI.

I intentionally left the retention configuration unset.

The logs were being ingested and retrieved successfully, but the log group did not have the required 14-day retention period.

I investigated the log group's configuration using AWS CLI and identified the missing retention policy as the root cause.

I used `PutRetentionPolicy` to configure 14-day retention and verified the updated setting with `DescribeLogGroups`.

I also confirmed that recent application logs remained accessible and that new log events could still be published.

Finally, I developed a Bash auditing script to detect incorrect retention configurations and deleted the temporary AWS resources.

---

## 20. Repository Structure

```text
aws-cloudwatch-troubleshooting-labs/
│
├── README.md
│
├── 01-cloudwatch-logs-not-appearing/
│   └── README.md
│
├── 02-cloudwatch-agent-not-running/
│   └── README.md
│
├── 03-ec2-metrics-missing/
│   └── README.md
│
├── 04-custom-metric-not-publishing/
│   └── README.md
│
├── 05-alarm-insufficient-data/
│   └── README.md
│
├── 06-alarm-threshold-misconfiguration/
│   └── README.md
│
├── 07-alarm-notification-not-delivered/
│   └── README.md
│
├── 08-cloudwatch-logs-retention-misconfiguration/
│   ├── README.md
│   ├── generate-test-logs.py
│   ├── audit-retention.sh
│   ├── test-log-events.json
│   ├── verification-event.json
│   ├── lab08-before-log-group.json
│   ├── lab08-ingested-events.json
│   ├── lab08-before-retention.json
│   ├── lab08-after-retention.json
│   ├── lab08-after-events.json
│   └── lab08-final-configuration.json
│
├── 09-metric-filter-not-matching/
└── 10-cloudwatch-logs-insights-investigation/
```

### File Descriptions

| File | Purpose |
|---|---|
| `README.md` | Complete troubleshooting documentation |
| `generate-test-logs.py` | Generates synthetic JSON logs |
| `audit-retention.sh` | Audits log group retention |
| `test-log-events.json` | Generated test log events |
| `verification-event.json` | Log event used after remediation |
| `lab08-before-log-group.json` | Initial log group configuration |
| `lab08-ingested-events.json` | Confirms successful log ingestion |
| `lab08-before-retention.json` | Captures incorrect retention |
| `lab08-after-retention.json` | Captures corrected retention |
| `lab08-after-events.json` | Confirms logs remain accessible |
| `lab08-final-configuration.json` | Final log group configuration before cleanup |

### Evidence Guidelines

All evidence files should contain actual AWS CLI results.

Do not fabricate retention settings, log events, timestamps, or verification outcomes.

Review the JSON evidence before publishing it to GitHub.

Do not include passwords, access keys, tokens, or real customer information.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how a CloudWatch Logs retention misconfiguration can create unnecessary long-term log storage even when application logging works correctly.

We created a CloudWatch Logs log group and log stream.

We developed a Python script to generate structured JSON application logs.

We published the logs using AWS CLI and verified that they could be retrieved successfully.

However, we intentionally created the log group without a retention policy.

The company's requirement was to retain application logs for 14 days.

Without an applicable account-level policy, the missing retention configuration would cause CloudWatch to retain the logs indefinitely.

We investigated the log group using AWS CLI and identified the missing retention setting as the root cause.

We then configured 14-day retention using `PutRetentionPolicy`.

After remediation, we verified that the log group reported the required retention period.

We also confirmed that recent log events remained accessible and that log ingestion continued working.

To improve operational reliability, we created a Bash auditing script that detects retention configurations that do not match the expected value.

Finally, we deleted the temporary CloudWatch Logs resources.

**Key Lesson:** CloudWatch Logs troubleshooting is not limited to investigating missing or delayed log ingestion. Engineers must also validate log retention, lifecycle management, storage costs, and governance requirements.

### Skills Demonstrated

- Amazon CloudWatch Logs
- CloudWatch log groups
- CloudWatch log streams
- CloudWatch log events
- CloudWatch Logs retention policies
- CloudWatch Logs lifecycle management
- AWS CLI v2
- Linux Bash
- Python 3
- JSON log generation
- Structured application logging
- CloudWatch PutLogEvents
- CloudWatch GetLogEvents
- CloudWatch FilterLogEvents
- CloudWatch DescribeLogGroups
- CloudWatch DescribeLogStreams
- CloudWatch PutRetentionPolicy
- Log retention auditing
- Automated compliance checks
- Log storage investigation
- Account-level policy awareness
- Root cause analysis
- Cloud monitoring remediation
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-008 |
| Scenario | CloudWatch Logs Retention Misconfiguration |
| Log Group | `/cloudwatch-lab08/payment-api` |
| Log Stream | `application-logs` |
| Log Format | JSON |
| Log Ingestion | Successful |
| Initial Retention | Unset |
| Required Retention | 14 days |
| Root Cause | Missing retention policy |
| Remediation | PutRetentionPolicy |
| Corrected Retention | 14 days |
| Recent Log Retrieval | Working |
| New Log Ingestion | Working |
| Automated Retention Audit | Passes after correction |
| Resource Cleanup | Temporary log group deleted |
| Incident Status | Resolved after verification |

**Key Takeaway:** Reliable cloud observability requires both successful log collection and correct log lifecycle management. Engineers should configure retention policies explicitly, validate effective settings, and automate audits to detect misconfigurations before they create operational, cost, or governance problems.

---

## Official AWS Documentation

- [Amazon CloudWatch Logs — Working with Log Groups and Streams](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/Working-with-log-groups-and-streams.html)
- [AWS CLI — CreateLogGroup](https://docs.aws.amazon.com/cli/latest/reference/logs/create-log-group.html)
- [AWS CLI — PutLogEvents](https://docs.aws.amazon.com/cli/latest/reference/logs/put-log-events.html)
- [AWS CLI — GetLogEvents](https://docs.aws.amazon.com/cli/latest/reference/logs/get-log-events.html)
- [AWS CLI — FilterLogEvents](https://docs.aws.amazon.com/cli/latest/reference/logs/filter-log-events.html)
- [AWS CLI — DescribeLogGroups](https://docs.aws.amazon.com/cli/latest/reference/logs/describe-log-groups.html)
- [AWS CLI — PutRetentionPolicy](https://docs.aws.amazon.com/cli/latest/reference/logs/put-retention-policy.html)
- [AWS CLI — DeleteLogGroup](https://docs.aws.amazon.com/cli/latest/reference/logs/delete-log-group.html)