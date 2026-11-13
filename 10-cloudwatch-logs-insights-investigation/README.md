# Lab 10 — CloudWatch Logs Insights Investigation

## Overview

This lab demonstrates how to investigate a production-style application incident using Amazon CloudWatch Logs Insights, AWS CLI, Python, and Bash.

We simulate a payment API application that normally processes requests successfully with low response latency.

During the simulated incident, the application begins experiencing high latency, database connection timeouts, and HTTP 503 errors.

The Cloud Operations team must investigate the incident and determine what caused the application failures.

Instead of manually reviewing individual log messages, we use CloudWatch Logs Insights to search, filter, aggregate, and analyze structured JSON application logs.

The simulated incident includes three stages:

1. **Baseline:** The payment API operates normally.
2. **Incident:** A configuration change reduces the database connection pool from 20 to 2, resulting in database connection exhaustion.
3. **Recovery:** The database connection pool is restored to 20, and normal application behavior resumes.

We generate 72 structured log events using Python and upload them to Amazon CloudWatch Logs using AWS CLI.

We then execute nine CloudWatch Logs Insights queries to investigate application errors, HTTP status codes, response latency, error codes, configuration changes, and recovery.

To make the investigation repeatable, we create a Bash script that automatically submits Logs Insights queries, checks execution status, and saves the results as JSON evidence.

After correlating the application failures with the configuration-change logs, we identify the simulated database connection pool misconfiguration as the root cause.

We verify that the recovery logs show successful requests and normal latency.

Finally, we document the investigation findings and delete the temporary CloudWatch Logs infrastructure.

**Troubleshooting Workflow:**

Production Incident Simulation → Structured Log Generation → CloudWatch Logs Ingestion → Logs Insights Queries → Error Investigation → Latency Analysis → Configuration Change Correlation → Root Cause Analysis → Recovery Verification → Incident Documentation → AWS Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-010 |
| Difficulty | Intermediate to Advanced |
| AWS Region | `us-east-1` |
| AWS Service | Amazon CloudWatch Logs |
| Investigation Tool | CloudWatch Logs Insights |
| Query Language | CloudWatch Logs Insights QL |
| Local Environment | WSL Ubuntu |
| Interface | AWS CLI v2 |
| Programming Language | Python 3 |
| Automation Language | Bash |
| Log Group | `/cloudwatch-lab10/payment-api` |
| Log Stream | `application-logs` |
| Log Class | Standard |
| Retention | 7 days |
| Application | Simulated Payment API |
| Endpoint | `/api/payments` |
| Log Format | JSON |
| Total Log Events | 72 |
| Baseline Requests | 20 |
| Incident Requests | 30 |
| Failed Requests | 12 |
| Recovery Requests | 20 |
| Failure HTTP Status | 503 |
| Error Code | `DB_POOL_EXHAUSTED` |
| Initial Database Pool Limit | 20 |
| Incorrect Pool Limit | 2 |
| Restored Pool Limit | 20 |
| Root Cause | Database connection pool misconfiguration |
| Investigation APIs | StartQuery, GetQueryResults |
| Remediation | Simulated restoration of pool limit |
| Verification | Logs Insights query results |
| Cleanup | Delete temporary log group |

### Lab Objectives

- Understand production incident investigations using application logs.
- Create a CloudWatch Logs log group and log stream.
- Generate structured JSON application logs using Python.
- Simulate healthy, failing, and recovered application behavior.
- Ingest application logs using AWS CLI.
- Learn CloudWatch Logs Insights query syntax.
- Search application error events.
- Calculate HTTP failure counts.
- Analyze average, maximum, and p95 response latency.
- Identify error codes and failing components.
- Investigate configuration changes.
- Analyze incident timelines.
- Correlate changes with application failures.
- Verify application recovery.
- Automate Logs Insights queries using Bash.
- Save investigation evidence.
- Document a root cause analysis.
- Clean up temporary AWS resources.

---

## 2. Production Incident Scenario

### Incident Description

A financial technology company operates a payment API that processes customer transactions.

The application normally responds quickly and returns successful HTTP 200 responses.

The Cloud Operations team uses Amazon CloudWatch Logs to monitor API activity, application performance, and errors.

During an incident, customers begin experiencing slow payment processing and failed transactions.

The payment API starts returning HTTP 503 errors.

Engineers also observe database connection timeout messages.

The application logs are available in CloudWatch Logs, but the exact cause of the failures is not immediately clear.

A Cloud Engineer is assigned to investigate the incident.

The engineer must determine:

- When the incident started.
- How many requests failed.
- Which HTTP status codes increased.
- Which application component generated errors.
- Whether response latency increased.
- Whether a configuration change occurred.
- Whether the application recovered afterward.

The engineer uses CloudWatch Logs Insights to analyze structured JSON log events.

The investigation reveals that the database connection pool limit was reduced from 20 to 2 connections.

Following this configuration change, the application experienced database connection exhaustion, HTTP 503 responses, and increased latency.

The simulated recovery phase shows that the connection pool limit was restored to 20.

Subsequent requests completed successfully with lower response latency.

### Incident Symptoms

- Increased API response latency.
- HTTP 503 responses.
- Database connection timeout messages.
- Payment request failures.
- `DB_POOL_EXHAUSTED` error codes.
- Increased number of application ERROR events.
- Reduced database connection pool capacity.
- Configuration changes near the incident start.
- Recovery after restoration of the connection pool configuration.

### Business Impact

- Customers may experience failed payment requests.
- Payment processing may be delayed.
- Application performance may degrade.
- Service-level objectives may be violated.
- Incident response teams require reliable evidence to identify the cause.
- Incorrect configuration changes can affect application availability.
- Slow root cause identification can extend an outage.

### Objective

Use CloudWatch Logs Insights to investigate a simulated payment API incident, identify the failing component and configuration change, and verify recovery using structured log evidence.

### Simulation Boundary

This lab uses a synthetic incident dataset.

We do not create a real payment API, Amazon RDS database, or database connection pool.

The configuration changes and application failures are simulated in JSON logs.

CloudWatch Logs Insights performs real AWS-side queries against those uploaded events.

---

## 3. AWS Architecture

### CloudWatch Logs Investigation Architecture

```text
                        WSL Ubuntu
                             |
                             v
                    Python Incident Generator
                             |
                             v
                   Structured JSON Log Events
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
              /cloudwatch-lab10/payment-api
                             |
                             v
                         Log Stream
                      application-logs
                             |
                             v
                    CloudWatch Logs Insights
                             |
                             v
                    StartQuery / GetQueryResults
                             |
            +----------------+----------------+
            |                |                |
            v                v                v
       HTTP Errors      Latency Analysis   Configuration
            |                |              Changes
            +----------------+----------------+
                             |
                             v
                       Error Correlation
                             |
                             v
                       Root Cause Analysis
                             |
                             v
                      Recovery Verification
```

### Architecture Before Incident

```text
Payment API
      |
      v
Database Connection Pool
      |
      v
Pool Limit = 20
      |
      v
Connections Available
      |
      v
Payment Requests Successful
      |
      v
HTTP 200
      |
      v
Normal Response Latency
```

### Architecture During Incident

```text
Payment API
      |
      v
Configuration Change
      |
      v
Database Pool Limit: 20 -> 2
      |
      v
Insufficient Connection Capacity
      |
      v
Database Connection Pool Exhaustion
      |
      v
Database Connection Timeout
      |
      v
DB_POOL_EXHAUSTED
      |
      v
HTTP 503 Errors
      |
      v
High API Response Latency
```

### Architecture After Simulated Remediation

```text
Payment API
      |
      v
Database Pool Configuration Restored
      |
      v
Pool Limit: 2 -> 20
      |
      v
Connections Available
      |
      v
Payment Requests Successful
      |
      v
HTTP 200
      |
      v
Normal Response Latency
```

### Architecture Components

| Component | Purpose |
|---|---|
| WSL Ubuntu | Local AWS CLI environment |
| Python Incident Generator | Creates structured incident logs |
| AWS CLI | Uploads logs and executes queries |
| CloudWatch Log Group | Stores payment API logs |
| CloudWatch Log Stream | Contains the simulated application events |
| CloudWatch Logs Insights | Searches and analyzes log data |
| StartQuery | Submits log analysis queries |
| GetQueryResults | Retrieves query status and results |
| Bash Query Runner | Automates query execution |
| JSON Evidence Files | Preserve investigation outputs |
| Incident Findings | Documents the root cause and recovery |

---

## 4. Understanding CloudWatch Logs Insights

### What Is CloudWatch Logs Insights?

Amazon CloudWatch Logs Insights is a managed log analytics capability used to investigate log data.

Engineers can search, filter, group, and analyze large collections of log events.

CloudWatch Logs Insights is commonly used for:

- Production troubleshooting
- Application error investigation
- API latency analysis
- Security event investigation
- Incident response
- Infrastructure monitoring
- Root cause analysis

### What Is Logs Insights QL?

CloudWatch Logs Insights QL is a query language designed to analyze CloudWatch log events.

It supports commands for extracting, filtering, aggregating, and sorting log data.

### Common Query Commands

| Command | Purpose |
|---|---|
| `fields` | Select fields |
| `filter` | Select matching events |
| `stats` | Aggregate data |
| `sort` | Sort query results |
| `limit` | Limit returned records |
| `parse` | Extract fields from log messages |
| `bin` | Group events into time intervals |
| `ispresent` | Check whether a field exists |
| `pct` | Calculate percentiles |

### Example — Search Error Logs

```sql
fields @timestamp, level, error_code
| filter level = "ERROR"
| sort @timestamp desc
| limit 20
```

### Example — Count HTTP Errors

```sql
fields status
| filter status >= 500
| stats count(*) as errors by status
```

### Example — Average Latency

```sql
fields latency_ms
| filter ispresent(latency_ms)
| stats avg(latency_ms) as average_latency
```

### Example — p95 Latency

```sql
fields latency_ms
| filter ispresent(latency_ms)
| stats pct(latency_ms, 95) as p95_latency
```

### What Is p95 Latency?

p95 latency represents the approximate response-time value at or below which 95% of measured requests fall.

It helps engineers understand slower requests that might be hidden by the average.

### What Is StartQuery?

`StartQuery` submits a Logs Insights query.

It returns a query ID that identifies the query execution.

### What Is GetQueryResults?

`GetQueryResults` retrieves the current status and results of a submitted query.

A result is complete when its status is `Complete`.

### Common Query States

| Status | Meaning |
|---|---|
| Scheduled | Waiting to execute |
| Running | Query is processing |
| Complete | Query finished successfully |
| Failed | Query failed |
| Cancelled | Query was cancelled |
| Timeout | Query exceeded its execution limit |

### Why Use Structured JSON Logs?

Structured JSON logs make incident investigation easier.

Fields such as `status`, `latency_ms`, `error_code`, and `component` can be queried directly.

This reduces the need to parse unstructured text messages.

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

### AWS Permissions

The AWS CLI identity requires permissions for operations including:

```text
logs:CreateLogGroup
logs:CreateLogStream
logs:PutLogEvents
logs:PutRetentionPolicy
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:GetLogEvents
logs:FilterLogEvents
logs:StartQuery
logs:GetQueryResults
logs:StopQuery
logs:DescribeQueries
logs:ListTagsForResource
logs:DeleteLogGroup
```

### Security Rules

- Use synthetic log data only.
- Do not include real payment information.
- Do not store credentials in JSON logs.
- Do not upload private customer information.
- Use a dedicated disposable log group.
- Restrict investigation to the required AWS Region.
- Use narrow query time windows.
- Verify resource ownership before deletion.
- Review evidence before publishing it to GitHub.

### Cost Considerations

CloudWatch Logs ingestion, storage, and Logs Insights queries may incur AWS charges.

Logs Insights query costs depend on the amount of data scanned.

This lab uses only 72 synthetic log events and one dedicated log group.

No EC2, RDS, VPC, or public IPv4 resources are required.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab10"

export LOG_GROUP="/cloudwatch-lab10/payment-api"
export LOG_STREAM="application-logs"

export RETENTION_DAYS="7"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$LOG_GROUP"
echo "$LOG_STREAM"
echo "$RETENTION_DAYS"
```

### Step 4 — Create Local Directories

```bash
mkdir -p queries evidence
```

These directories store Logs Insights queries and actual AWS query results.

---

## 7. Create CloudWatch Logs Infrastructure

### Step 1 — Create Log Group

```bash
aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --log-group-class STANDARD \
  --tags "Project=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

### Step 2 — Configure Seven-Day Retention

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days "$RETENTION_DAYS" \
  --region "$AWS_REGION"
```

### Step 3 — Create Log Stream

```bash
aws logs create-log-stream \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --region "$AWS_REGION"
```

### Step 4 — Verify Log Group

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,Class:logGroupClass,Retention:retentionInDays}" \
  --output table \
  --region "$AWS_REGION"
```

Expected:

```text
Log Group: /cloudwatch-lab10/payment-api
Log Class: STANDARD
Retention: 7
```

### Step 5 — Verify Log Stream

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --query 'logStreams[].logStreamName' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

`application-logs`

---

## 8. Generate Simulated Production Incident Logs

### Incident Dataset

The dataset represents three stages of a payment API incident.

| Phase | Description | Requests |
|---|---|---:|
| Baseline | Normal application behavior | 20 |
| Incident | Database pool exhaustion | 30 |
| Recovery | Restored database pool | 20 |

There are also two configuration-change events.

### Step 1 — Create Python Incident Generator

Save as `generate-incident-logs.py`:

```python
#!/usr/bin/env python3

import json
import time

NOW = int(time.time() * 1000)

events = []

def add_event(timestamp, **fields):
    events.append({
        "timestamp": timestamp,
        "message": json.dumps(fields, separators=(",", ":"))
    })


# PHASE 1 — NORMAL BASELINE

base = NOW - (12 * 60 * 1000)

for i in range(20):
    add_event(
        base + i * 1000,
        level="INFO",
        service="payment-api",
        phase="baseline",
        endpoint="/api/payments",
        status=200,
        latency_ms=110 + (i % 8) * 12,
        event="request_completed",
        request_id=f"baseline-{i:03d}",
        db_pool_limit=20
    )


# PHASE 2 — INCIDENT

incident = NOW - (7 * 60 * 1000)

add_event(
    incident,
    level="WARN",
    service="payment-api",
    phase="incident",
    event="config_change",
    component="database_pool",
    old_pool_limit=20,
    new_pool_limit=2,
    change_id="CHG-LAB10-001",
    message="Database connection pool reduced"
)

for i in range(12):
    add_event(
        incident + (i + 1) * 1000,
        level="INFO",
        service="payment-api",
        phase="incident",
        endpoint="/api/payments",
        status=200,
        latency_ms=300 + (i % 6) * 35,
        event="request_completed",
        request_id=f"incident-ok-{i:03d}",
        db_pool_limit=2
    )

for i in range(12):
    add_event(
        incident + (i + 13) * 1000,
        level="ERROR",
        service="payment-api",
        phase="incident",
        endpoint="/api/payments",
        status=503,
        latency_ms=1400 + (i % 6) * 120,
        event="payment_failed",
        request_id=f"incident-fail-{i:03d}",
        error_code="DB_POOL_EXHAUSTED",
        component="database_pool",
        db_pool_limit=2,
        message="Database connection timeout"
    )

for i in range(6):
    add_event(
        incident + (i + 25) * 1000,
        level="WARN",
        service="payment-api",
        phase="incident",
        endpoint="/api/payments",
        status=200,
        latency_ms=800 + i * 70,
        event="slow_request",
        request_id=f"incident-slow-{i:03d}",
        db_pool_limit=2
    )


# PHASE 3 — RECOVERY

recovery = NOW - (2 * 60 * 1000)

add_event(
    recovery,
    level="INFO",
    service="payment-api",
    phase="recovery",
    event="config_change",
    component="database_pool",
    old_pool_limit=2,
    new_pool_limit=20,
    change_id="CHG-LAB10-002",
    message="Database connection pool restored"
)

for i in range(20):
    add_event(
        recovery + (i + 1) * 1000,
        level="INFO",
        service="payment-api",
        phase="recovery",
        endpoint="/api/payments",
        status=200,
        latency_ms=105 + (i % 7) * 13,
        event="request_completed",
        request_id=f"recovery-{i:03d}",
        db_pool_limit=20
    )


events.sort(key=lambda x: x["timestamp"])

with open("incident-log-events.json", "w") as file:
    json.dump(events, file, indent=2)

summary = {
    "total_events": len(events),
    "baseline_requests": 20,
    "incident_requests": 30,
    "incident_failed_requests": 12,
    "recovery_requests": 20,
    "config_changes": 2,
    "simulated_root_cause": "database_pool_limit_reduced",
    "initial_pool_limit": 20,
    "incorrect_pool_limit": 2,
    "restored_pool_limit": 20
}

with open("incident-expected-results.json", "w") as file:
    json.dump(summary, file, indent=2)

print("Generated", len(events), "log events")
print("Baseline: 20 successful requests")
print("Incident: 30 requests, 12 failures")
print("Recovery: 20 successful requests")
print("Configuration changes: 2")
```

### Step 2 — Generate the Logs

```bash
python3 generate-incident-logs.py
```

Expected:

```text
Generated 72 log events
Baseline: 20 successful requests
Incident: 30 requests, 12 failures
Recovery: 20 successful requests
Configuration changes: 2
```

### Step 3 — Inspect Generated Logs

```bash
head -n 35 incident-log-events.json
```

### Step 4 — Inspect Expected Results

```bash
cat incident-expected-results.json
```

### Dataset Summary

| Category | Count |
|---|---:|
| Baseline successful requests | 20 |
| Incident successful requests | 12 |
| Incident failed requests | 12 |
| Incident slow requests | 6 |
| Recovery successful requests | 20 |
| Configuration-change events | 2 |
| Total events | 72 |

The expected-results file represents the intended synthetic dataset, not independently verified AWS results.

---

## 9. Publish and Verify Application Logs

### Step 1 — Publish Generated Events

```bash
aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events file://incident-log-events.json \
  --region "$AWS_REGION"
```

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

### Step 3 — Search for ERROR Events

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '{ $.level = "ERROR" }' \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: 12 error events.

### Step 4 — Save Ingestion Evidence

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --query 'events[].{Timestamp:timestamp,Message:message}' \
  --output json \
  --region "$AWS_REGION" \
  > lab10-ingested-events.json
```

### Ingestion Verification

| Component | Expected Result |
|---|---|
| Log Group | Available |
| Log Stream | Available |
| JSON Logs | Ingested |
| Total Events | 72 |
| ERROR Events | 12 |
| Log Retrieval | Working |
| Logs Insights Ready | Yes |

---

## 10. CloudWatch Logs Insights Query Collection

This lab uses nine Logs Insights queries.

Each query answers a specific investigation question.

### Query 01 — Recent Application Logs

**File:** `queries/01-recent-logs.cwli`

```sql
fields @timestamp, level, phase, event, status, latency_ms
| sort @timestamp desc
| limit 30
```

**Purpose:** Inspect recent application activity and verify that log fields are available.

### Query 02 — Application Errors

**File:** `queries/02-application-errors.cwli`

```sql
fields @timestamp, level, error_code, component, request_id, status, latency_ms
| filter level = "ERROR"
| sort @timestamp asc
| limit 50
```

**Purpose:** Identify failed requests, error codes, and the affected application component.

Expected: 12 error records.

### Query 03 — HTTP Failure Count

**File:** `queries/03-http-failures.cwli`

```sql
fields @timestamp, phase, endpoint, status
| filter status >= 500
| stats count(*) as failed_requests by phase, status
| sort failed_requests desc
```

**Purpose:** Count HTTP 5xx failures and identify the incident phase containing them.

Expected:

| Phase | Status | Failed Requests |
|---|---|---:|
| incident | 503 | 12 |

### Query 04 — Latency Analysis

**File:** `queries/04-latency-analysis.cwli`

```sql
fields phase, status, latency_ms
| filter ispresent(latency_ms)
| stats
    count(*) as requests,
    avg(latency_ms) as average_latency_ms,
    max(latency_ms) as maximum_latency_ms,
    pct(latency_ms, 95) as p95_latency_ms
  by phase
| sort average_latency_ms desc
```

**Purpose:** Compare latency across baseline, incident, and recovery phases.

Expected: incident latency is substantially higher than normal latency.

### Query 05 — Error Root Cause

**File:** `queries/05-error-root-cause.cwli`

```sql
fields @timestamp, error_code, component, status
| filter level = "ERROR"
| stats count(*) as occurrences by error_code, component
| sort occurrences desc
```

**Purpose:** Identify the dominant error and failing component.

Expected:

```text
error_code = DB_POOL_EXHAUSTED
component = database_pool
occurrences = 12
```

### Query 06 — Configuration Changes

**File:** `queries/06-configuration-changes.cwli`

```sql
fields
    @timestamp,
    phase,
    change_id,
    component,
    old_pool_limit,
    new_pool_limit,
    message
| filter event = "config_change"
| sort @timestamp asc
```

**Purpose:** Identify configuration changes occurring near the incident.

Expected:

| Change ID | Old Limit | New Limit |
|---|---:|---:|
| CHG-LAB10-001 | 20 | 2 |
| CHG-LAB10-002 | 2 | 20 |

### Query 07 — Error Timeline

**File:** `queries/07-error-timeline.cwli`

```sql
fields @timestamp, level, status
| filter status >= 500
| stats count(*) as errors by bin(1m)
| sort bin(1m) asc
```

**Purpose:** Identify the time period in which HTTP 5xx errors occurred.

Expected: errors concentrated during the simulated incident interval.

### Query 08 — Recovery Verification

**File:** `queries/08-recovery-verification.cwli`

```sql
fields phase, status, latency_ms
| filter phase = "recovery" and ispresent(status)
| stats
    count(*) as total_requests,
    avg(latency_ms) as average_latency_ms,
    max(latency_ms) as maximum_latency_ms
  by status
| sort status asc
```

**Purpose:** Verify that application requests became successful after recovery.

Expected:

```text
status = 200
total_requests = 20
```

### Query 09 — Complete Incident Summary

**File:** `queries/09-incident-summary.cwli`

```sql
fields phase, status, latency_ms
| filter ispresent(status)
| stats
    count(*) as total_requests,
    avg(latency_ms) as average_latency_ms,
    max(latency_ms) as max_latency_ms
  by phase, status
| sort phase asc, status asc
```

**Purpose:** Summarize HTTP response status and latency across all three phases.

### Query Collection Summary

| Query | Investigation Goal |
|---|---|
| 01 | Inspect recent application logs |
| 02 | Identify application errors |
| 03 | Count HTTP failures |
| 04 | Analyze latency |
| 05 | Identify failing components |
| 06 | Investigate configuration changes |
| 07 | Identify incident timeline |
| 08 | Verify recovery |
| 09 | Compare incident phases |

---

## 11. Execute CloudWatch Logs Insights Queries

### Step 1 — Configure Query Time Range

```bash
export QUERY_START=$(date -u -d '20 minutes ago' +%s)

export QUERY_END=$(date -u -d '1 minute from now' +%s)
```

The generated events are timestamped approximately 12, 7, and 2 minutes before the generator ran.

If significant time has passed, expand the query window so it includes those timestamps.

### Step 2 — Submit Query 01

```bash
export QUERY_ID=$(aws logs start-query \
  --log-group-name "$LOG_GROUP" \
  --start-time "$QUERY_START" \
  --end-time "$QUERY_END" \
  --query-string "$(cat queries/01-recent-logs.cwli)" \
  --query-language CWLI \
  --query queryId \
  --output text \
  --region "$AWS_REGION")
```

### Step 3 — Verify Query ID

```bash
echo "$QUERY_ID"
```

Expected: a CloudWatch Logs Insights query ID.

### Step 4 — Inspect Query Status

```bash
aws logs get-query-results \
  --query-id "$QUERY_ID" \
  --query 'status' \
  --output text \
  --region "$AWS_REGION"
```

Expected eventually:

`Complete`

### Step 5 — Retrieve Query Results

```bash
aws logs get-query-results \
  --query-id "$QUERY_ID" \
  --output json \
  --region "$AWS_REGION"
```

### Step 6 — Save Query Evidence

After the query reaches `Complete`:

```bash
aws logs get-query-results \
  --query-id "$QUERY_ID" \
  --output json \
  --region "$AWS_REGION" \
  > evidence/01-recent-logs.json
```

### Important Query Behavior

Logs Insights queries execute asynchronously.

A successful `StartQuery` response means the query was accepted for execution.

It does not mean the query has completed.

Only results from a completed query should be treated as final investigation evidence.

---

## 12. Automate Logs Insights Queries Using Bash

Instead of manually running each query, we create a Bash script that submits queries and saves their results.

### Step 1 — Create Query Runner

Save as `run-insights-query.sh`:

```bash
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
```

### Step 2 — Make the Script Executable

```bash
chmod +x run-insights-query.sh
```

### Step 3 — Run One Query

```bash
./run-insights-query.sh queries/01-recent-logs.cwli
```

Expected:

```text
Query complete.
Evidence: evidence/01-recent-logs.json
```

### Step 4 — Run All Queries

```bash
for query in queries/*.cwli; do
  echo "Running $query"
  ./run-insights-query.sh "$query"
done
```

### Step 5 — Verify Evidence Files

```bash
ls -lh evidence/
```

Expected query files:

```text
01-recent-logs.json
02-application-errors.json
03-http-failures.json
04-latency-analysis.json
05-error-root-cause.json
06-configuration-changes.json
07-error-timeline.json
08-recovery-verification.json
09-incident-summary.json
```

### Step 6 — Inspect JSON Evidence

```bash
python3 -m json.tool evidence/05-error-root-cause.json
```

```bash
python3 -m json.tool evidence/06-configuration-changes.json
```

### Query Window Limitation

The sample Bash runner uses a rolling 30-minute query window.

If the dataset is older than that window, the queries may return empty results even though ingestion succeeded.

For durable incident investigations, use a fixed start and end time that covers the incident rather than relying on a moving window.

---

## 13. Investigate Application Errors and HTTP Failures

### Step 1 — Inspect Application Errors

```bash
python3 -m json.tool evidence/02-application-errors.json
```

Expected findings:

```text
level = ERROR
status = 503
error_code = DB_POOL_EXHAUSTED
component = database_pool
```

### Step 2 — Inspect HTTP Failure Counts

```bash
python3 -m json.tool evidence/03-http-failures.json
```

Expected:

| Phase | HTTP Status | Count |
|---|---|---:|
| Incident | 503 | 12 |

### Step 3 — Calculate Failure Rate

The synthetic dataset contains:

```text
Incident Requests = 30
Failed Requests = 12
```

Therefore:

```text
Failure Rate = (12 / 30) × 100

Failure Rate = 40%
```

### Investigation Findings

| Metric | Expected Finding |
|---|---|
| Affected Application | Payment API |
| Endpoint | /api/payments |
| Failed Requests | 12 |
| Incident Requests | 30 |
| Failure Rate | 40% |
| HTTP Status | 503 |
| Error Code | DB_POOL_EXHAUSTED |
| Component | database_pool |

### Why This Matters

A 40% failure rate would represent a serious availability issue for a payment API.

Cloud Engineers need to determine whether the failures originate from application code, database connectivity, infrastructure capacity, or recent configuration changes.

The Logs Insights results provide evidence that helps narrow the investigation.

---

## 14. Investigate Response Latency and Error Timeline

### Step 1 — Inspect Latency Results

```bash
python3 -m json.tool evidence/04-latency-analysis.json
```

Expected latency trend:

| Phase | Expected Average Latency |
|---|---:|
| Baseline | Approximately 147 ms |
| Incident | Approximately 1,030 ms |
| Recovery | Approximately 142 ms |

These expected values are derived from the synthetic generator. The Logs Insights results should be used to verify the actual AWS-side aggregation.

### Step 2 — Inspect Maximum Latency

The incident dataset includes failed requests with latency reaching 2,000 milliseconds.

The baseline and recovery phases have substantially lower maximum values.

### Step 3 — Inspect p95 Latency

The query calculates:

```sql
pct(latency_ms, 95)
```

This helps determine how severely slower requests were affected.

### Step 4 — Inspect Error Timeline

```bash
python3 -m json.tool evidence/07-error-timeline.json
```

Expected: HTTP 503 failures are concentrated during the incident phase.

### Step 5 — Correlate Error Timing

The simulated incident starts approximately seven minutes before dataset generation.

The high-latency and error events occur after the configuration-change record.

The recovery phase begins approximately two minutes before dataset generation.

### Investigation Findings

| Investigation | Expected Result |
|---|---|
| Baseline Latency | Low |
| Incident Latency | High |
| Recovery Latency | Low |
| HTTP 503 Errors | Incident phase |
| Error Timing | Correlated with configuration change |
| Application Recovery | Visible in recovery logs |

---

## 15. Investigate Database Connection Pool and Root Cause

### Step 1 — Inspect Root Cause Query

```bash
python3 -m json.tool evidence/05-error-root-cause.json
```

Expected:

```text
error_code = DB_POOL_EXHAUSTED
component = database_pool
occurrences = 12
```

### Step 2 — Inspect Configuration Changes

```bash
python3 -m json.tool evidence/06-configuration-changes.json
```

Expected:

| Change ID | Old Pool Limit | New Pool Limit |
|---|---:|---:|
| CHG-LAB10-001 | 20 | 2 |
| CHG-LAB10-002 | 2 | 20 |

### Step 3 — Correlate Findings

The evidence shows three related events:

1. The database connection pool limit was reduced.
2. Database connection exhaustion and HTTP 503 errors appeared during the incident.
3. Errors disappeared after the pool limit was restored.

### Root Cause

The simulated incident was caused by an incorrect database connection pool configuration.

The normal connection pool size was 20.

A configuration change reduced the limit to 2.

The simulated application workload required more connection capacity than the reduced pool could provide.

This resulted in database connection timeouts and failed payment requests.

### Root Cause Flow

```text
Configuration Change
          |
          v
Database Pool Limit: 20 -> 2
          |
          v
Insufficient Available Connections
          |
          v
Connection Pool Exhaustion
          |
          v
Database Connection Timeouts
          |
          v
DB_POOL_EXHAUSTED Errors
          |
          v
HTTP 503 Responses
          |
          v
High API Latency
          |
          v
Payment API Incident
```

### Five Whys

1. **Why were payment requests failing?** Database connection timeouts caused HTTP 503 errors.
2. **Why were database connections timing out?** The connection pool was exhausted.
3. **Why was the pool exhausted?** Its configured capacity was reduced from 20 to 2.
4. **Why did the reduced capacity cause failures?** The simulated workload required more concurrent connections.
5. **How can similar incidents be prevented?** Validate configuration changes and monitor database connection pool utilization.

### Root Cause Summary

| Component | Finding |
|---|---|
| Incident | INC-CW-010 |
| Application | Payment API |
| HTTP Failure | 503 |
| Error Code | DB_POOL_EXHAUSTED |
| Failed Requests | 12 |
| Failure Rate | 40% |
| Root Cause | Database pool misconfiguration |
| Incorrect Pool Limit | 2 |
| Original Pool Limit | 20 |
| Remediation | Restore validated configuration |

### Production Investigation Considerations

In a real environment, log correlation is strong evidence but may not be sufficient by itself to prove causation.

Engineers should also inspect:

- Actual application configuration.
- Deployment records.
- Database connection metrics.
- Connection pool utilization.
- Database maximum connection limits.
- Application error rates.
- Changes made during the incident window.

This lab's root cause is known because the incident dataset was intentionally generated to simulate that failure.

---

## 16. Remediation and Recovery Verification

### Simulated Remediation

The incident dataset includes a configuration-change record that restores the database connection pool limit from 2 to 20.

No real database configuration is modified in this lab.

### Step 1 — Inspect Recovery Evidence

```bash
python3 -m json.tool evidence/08-recovery-verification.json
```

Expected:

```text
phase = recovery
status = 200
total_requests = 20
```

### Step 2 — Inspect Incident Summary

```bash
python3 -m json.tool evidence/09-incident-summary.json
```

Expected:

| Phase | HTTP Status | Requests |
|---|---|---:|
| Baseline | 200 | 20 |
| Incident | 200 | 18 |
| Incident | 503 | 12 |
| Recovery | 200 | 20 |

### Step 3 — Compare Performance

| Metric | Incident | Recovery |
|---|---|---|
| Database Pool Limit | 2 | 20 |
| Failed Requests | 12 | 0 |
| HTTP 503 Responses | Present | Absent |
| Average Latency | High | Normal |
| Error Code | DB_POOL_EXHAUSTED | None |
| Application Behavior | Degraded | Healthy in simulation |

### Step 4 — Document Incident Findings

Save as `incident-findings.md`:

```markdown
# INC-CW-010 — Payment API Incident Findings

## Summary

A simulated payment API incident caused increased latency
and HTTP 503 failures.

## Evidence

- 20 successful baseline requests
- 30 requests during the incident
- 12 HTTP 503 failures
- 40% simulated failure rate
- DB_POOL_EXHAUSTED error messages
- Connection pool limit changed from 20 to 2
- Configuration restored from 2 to 20
- 20 successful recovery requests

## Root Cause

Database connection pool limit reduced from 20 to 2.

## Remediation

Restore the validated database connection pool configuration.

## Verification

CloudWatch Logs Insights queries show normal latency
and successful responses after the simulated restoration.

## Prevention

- Validate application configuration changes
- Monitor database pool utilization
- Test application performance after deployments
- Review database connection capacity
- Maintain deployment rollback procedures
```

### Production Remediation Recommendations

In a real database connection pool incident:

1. Verify actual database connection utilization.
2. Inspect application pool settings.
3. Review recent configuration changes.
4. Restore a previously validated configuration if appropriate.
5. Confirm the database supports the intended connection capacity.
6. Monitor failed requests and application latency.
7. Review database health.
8. Validate recovery using live traffic.
9. Document the incident.
10. Implement preventive monitoring.

Increasing the pool size without verifying database capacity can create additional operational problems.

### Final Recovery Criteria

The simulated incident is considered recovered when the evidence shows:

- The pool limit restored from 2 to 20.
- No HTTP 503 errors in the recovery phase.
- Twenty successful recovery requests.
- Normal average response latency.
- No database pool exhaustion errors in the recovery phase.
- Actual Logs Insights results support the findings.

---

## 17. Production Troubleshooting Best Practices

### Logs Insights Investigation Checklist

1. Identify the affected application.
2. Identify the AWS Region.
3. Select the relevant log groups.
4. Determine the incident time window.
5. Verify logs are available.
6. Inspect recent log events.
7. Search application errors.
8. Identify HTTP failure codes.
9. Count failed requests.
10. Analyze average response latency.
11. Inspect maximum and p95 latency.
12. Group errors by component.
13. Identify configuration changes.
14. Correlate timestamps.
15. Determine the likely root cause.
16. Review available remediation options.
17. Verify post-remediation metrics.
18. Save actual query evidence.
19. Document the incident.
20. Remove temporary test resources.

### Common Logs Insights Problems

| Symptom | Possible Cause |
|---|---|
| Query returns no results | Wrong time range |
| No results from expected logs | Wrong log group |
| JSON fields missing | Parsing or log format problem |
| Query fails | Invalid query syntax |
| Query remains Running | Processing delay |
| Query times out | Query scope or complexity |
| Unexpected error count | Missing or duplicate events |
| High query costs | Excessive scanned data |
| Root cause unclear | Insufficient correlated evidence |
| Recovery cannot be confirmed | Missing post-incident data |

### Cost Optimization

- Query only necessary log groups.
- Use narrow time windows.
- Avoid unnecessary repeated large queries.
- Limit output when exploring raw events.
- Aggregate logs using `stats` where useful.
- Review query statistics.
- Store frequently used queries for future investigations.

### Security Recommendations

- Avoid logging credentials and tokens.
- Protect sensitive application data.
- Use least-privilege IAM permissions.
- Restrict production log access.
- Apply appropriate log retention.
- Review log access and management activity.
- Use structured logging consistently.
- Document security-relevant investigation findings.

### Operational Recommendations

- Maintain reusable Logs Insights queries.
- Track deployment and configuration changes.
- Monitor application error rates.
- Monitor database connection pool utilization.
- Validate rollback procedures.
- Compare application behavior before and after remediation.
- Preserve evidence for incident reviews.

---

## 18. AWS Resource Cleanup

**Warning:** Delete only the disposable Lab 10 log group. Deleting a log group permanently removes its log streams and stored events.

### Step 1 — Retrieve Log Group ARN

```bash
export LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].arn | [0]" \
  --output text \
  --region "$AWS_REGION")
```

### Step 2 — Verify Resource Ownership

```bash
aws logs list-tags-for-resource \
  --resource-arn "$LOG_GROUP_ARN" \
  --region "$AWS_REGION"
```

Confirm:

`Project=CloudWatch-Troubleshooting-Lab10`

### Step 3 — Save Final Log Group Evidence

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP']" \
  --output json \
  --region "$AWS_REGION" \
  > evidence/lab10-final-log-group.json
```

### Step 4 — Inspect Query Execution Status

```bash
aws logs describe-queries \
  --log-group-name "$LOG_GROUP" \
  --region "$AWS_REGION"
```

Verify that all lab queries are complete.

### Step 5 — Stop an Active Query if Necessary

```bash
aws logs stop-query \
  --query-id YOUR_QUERY_ID \
  --region "$AWS_REGION"
```

Replace `YOUR_QUERY_ID` with an actual active query ID.

Do not run the placeholder unchanged.

### Step 6 — Delete Log Group

```bash
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$AWS_REGION"
```

### Step 7 — Verify Deletion

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
| Application Log Stream | Deleted with log group |
| Simulated Log Events | Deleted with log group |
| Active Logs Insights Queries | None |
| EC2 Instances | None created |
| RDS Databases | None created |
| VPC Resources | None created |
| IAM Roles | None created |

---

## 19. Interview Questions and Answers

### Q1. What is Amazon CloudWatch Logs Insights?

A managed log analytics capability used to search, filter, aggregate, and investigate log events.

### Q2. What is CloudWatch Logs Insights QL?

A query language used to analyze log data stored in CloudWatch Logs.

### Q3. What does the fields command do?

It selects the fields included in query output.

### Q4. What does filter do?

It selects log events that match specified conditions.

### Q5. What does stats do?

It aggregates log data using functions such as count, average, maximum, and percentiles.

### Q6. What does bin(1m) do?

It groups timestamps into one-minute intervals for time-based analysis.

### Q7. What does pct(latency_ms, 95) calculate?

The approximate 95th percentile of the latency values.

### Q8. What does StartQuery do?

It submits a Logs Insights query and returns a query ID.

### Q9. What does GetQueryResults do?

It retrieves a query's status and available results.

### Q10. Why should engineers wait for query status Complete?

A running query may return only partial results.

Complete indicates that the query has finished successfully.

### Q11. What is the difference between GetLogEvents and Logs Insights?

GetLogEvents retrieves events from a particular log stream.

Logs Insights supports advanced searching, filtering, aggregation, and analysis across selected log groups.

### Q12. Why are structured JSON logs useful?

They allow engineers to query fields such as HTTP status, latency, error code, and component directly.

### Q13. How do you investigate HTTP 5xx errors?

Use a query filtering `status >= 500` and count matching events.

### Q14. How do you identify when an incident started?

Analyze error events over time using timestamps and time-bin aggregation.

### Q15. How can Logs Insights help with root cause analysis?

It allows engineers to correlate errors, application components, configuration changes, and recovery events.

### Q16. What caused this lab's simulated incident?

The database connection pool limit was reduced from 20 to 2, resulting in simulated connection exhaustion.

### Q17. How many payment requests failed?

Twelve of the thirty incident-phase requests, representing a 40% simulated failure rate.

### Q18. How was recovery verified?

The recovery dataset showed the connection pool restored to 20, followed by twenty successful requests with normal latency.

### Q19. How can query costs be controlled?

Use narrow time ranges, select only relevant log groups, and avoid unnecessary scans.

### Q20. How would you explain this lab in an interview?

I created a production-style payment API incident simulation and uploaded structured JSON application logs to Amazon CloudWatch Logs.

The dataset included normal requests, database connection timeouts, HTTP 503 errors, high latency, configuration changes, and recovery events.

I used CloudWatch Logs Insights queries to investigate error logs, failed requests, response latency, error codes, and incident timestamps.

I identified twelve HTTP 503 failures and a simulated 40% failure rate during the incident.

The investigation showed that the errors were associated with database connection pool exhaustion.

I correlated the failures with a configuration-change event showing that the pool limit had been reduced from 20 to 2.

The recovery logs showed that the connection pool was restored to 20 and normal application responses resumed.

I also developed a Bash script to automate the Logs Insights queries and save the results as evidence.

Finally, I documented the root cause and removed the temporary AWS resources.

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
│   └── README.md
│
├── 09-metric-filter-not-matching/
│   └── README.md
│
└── 10-cloudwatch-logs-insights-investigation/
    │
    ├── README.md
    ├── generate-incident-logs.py
    ├── run-insights-query.sh
    ├── incident-log-events.json
    ├── incident-expected-results.json
    ├── incident-findings.md
    ├── lab10-ingested-events.json
    │
    ├── queries/
    │   ├── 01-recent-logs.cwli
    │   ├── 02-application-errors.cwli
    │   ├── 03-http-failures.cwli
    │   ├── 04-latency-analysis.cwli
    │   ├── 05-error-root-cause.cwli
    │   ├── 06-configuration-changes.cwli
    │   ├── 07-error-timeline.cwli
    │   ├── 08-recovery-verification.cwli
    │   └── 09-incident-summary.cwli
    │
    └── evidence/
        ├── 01-recent-logs.json
        ├── 02-application-errors.json
        ├── 03-http-failures.json
        ├── 04-latency-analysis.json
        ├── 05-error-root-cause.json
        ├── 06-configuration-changes.json
        ├── 07-error-timeline.json
        ├── 08-recovery-verification.json
        ├── 09-incident-summary.json
        └── lab10-final-log-group.json
```

### File Descriptions

| File | Purpose |
|---|---|
| `README.md` | Complete incident documentation |
| `generate-incident-logs.py` | Generates the synthetic incident dataset |
| `run-insights-query.sh` | Automates Logs Insights execution |
| `incident-log-events.json` | Contains generated JSON log events |
| `incident-expected-results.json` | Describes expected synthetic results |
| `incident-findings.md` | Documents investigation findings |
| `lab10-ingested-events.json` | Confirms successful log ingestion |
| `queries/*.cwli` | Reusable Logs Insights queries |
| `evidence/*.json` | Actual completed query results |
| `lab10-final-log-group.json` | Final log group configuration |

### Evidence Guidelines

Evidence files should contain actual AWS CLI and Logs Insights responses.

Do not fabricate query results, metric values, timestamps, or incident findings.

The expected-results JSON is reference data produced by the simulator and must not be presented as independently verified CloudWatch evidence.

Review evidence for AWS account IDs and any sensitive information before publishing.

### Suggested Git Ignore Entries

```gitignore
__pycache__/
*.pyc
.venv/
.env
*.pid
```

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how CloudWatch Logs Insights can be used to investigate production-style application incidents.

We created a CloudWatch Logs log group and log stream to store structured application logs.

We developed a Python script that generated a simulated payment API incident.

The dataset included normal requests, database connection timeouts, HTTP 503 responses, latency spikes, configuration changes, and recovery events.

We ingested the log events into CloudWatch Logs using AWS CLI.

We then created nine Logs Insights queries to investigate different aspects of the incident.

The queries helped identify application errors, calculate failed request counts, analyze response latency, identify the failing database component, and correlate failures with configuration changes.

The dataset showed twelve failed requests out of thirty incident requests.

The simulated failure rate was 40%.

The error logs contained `DB_POOL_EXHAUSTED`, indicating database connection pool exhaustion.

The configuration-change logs showed that the pool size had been reduced from 20 to 2.

The simulated recovery logs showed that the pool size was restored to 20 and the application returned to normal behavior.

To improve repeatability, we created a Bash script that automatically submitted Logs Insights queries and saved their results.

Finally, we documented the root cause, remediation, verification, and prevention recommendations, then deleted the temporary AWS resources.

**Key Lesson:** Production troubleshooting requires more than finding individual error messages. Engineers must analyze trends, correlate events, inspect configuration changes, establish an evidence-supported root cause, and verify recovery.

### Skills Demonstrated

- Amazon CloudWatch Logs
- CloudWatch Logs Insights
- Logs Insights QL
- Structured JSON logging
- Python log generation
- Bash automation
- AWS CLI v2
- StartQuery
- GetQueryResults
- StopQuery
- DescribeQueries
- Log event filtering
- HTTP error investigation
- API latency analysis
- Average latency calculations
- Maximum latency analysis
- p95 percentile analysis
- Time-series log analysis
- Error aggregation
- Configuration-change correlation
- Database connection pool troubleshooting concepts
- Production incident investigation
- Root cause analysis
- Recovery verification
- Incident documentation
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-010 |
| Scenario | CloudWatch Logs Insights Investigation |
| Application | Simulated Payment API |
| Log Group | `/cloudwatch-lab10/payment-api` |
| Log Stream | `application-logs` |
| Log Format | JSON |
| Total Events | 72 |
| Baseline Requests | 20 |
| Incident Requests | 30 |
| Failed Requests | 12 |
| Failure Rate | 40% |
| HTTP Error | 503 |
| Error Code | DB_POOL_EXHAUSTED |
| Root Cause | Database pool limit reduced |
| Incorrect Pool Limit | 2 |
| Restored Pool Limit | 20 |
| Recovery Requests | 20 successful |
| Logs Insights Queries | 9 |
| Bash Automation | Query runner created |
| Evidence | Saved from completed AWS queries |
| Cleanup | Temporary log group deleted |
| Incident Status | Resolved in simulation; verified through query evidence |

**Key Takeaway:** CloudWatch Logs Insights is a valuable troubleshooting tool for Cloud Engineers and Cloud Security Engineers. It allows engineers to investigate application failures using structured evidence, identify operational patterns, correlate changes with incidents, and verify recovery. These skills are directly applicable to real cloud operations, production support, incident response, and cloud infrastructure engineering.

---

## Official AWS Documentation

- [Amazon CloudWatch Logs Insights Overview](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)
- [CloudWatch Logs Insights QL Query Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_QuerySyntax.html)
- [CloudWatch Logs — Discovered Fields](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/CWL_AnalyzeLogData-discoverable-fields.html)
- [AWS CLI — StartQuery](https://docs.aws.amazon.com/cli/latest/reference/logs/start-query.html)
- [AWS CLI — GetQueryResults](https://docs.aws.amazon.com/cli/latest/reference/logs/get-query-results.html)
- [AWS CLI — DescribeQueries](https://docs.aws.amazon.com/cli/latest/reference/logs/describe-queries.html)
- [AWS CLI — StopQuery](https://docs.aws.amazon.com/cli/latest/reference/logs/stop-query.html)
- [AWS CLI — PutLogEvents](https://docs.aws.amazon.com/cli/latest/reference/logs/put-log-events.html)
- [AWS CLI — DeleteLogGroup](https://docs.aws.amazon.com/cli/latest/reference/logs/delete-log-group.html)