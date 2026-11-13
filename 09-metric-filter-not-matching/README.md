# Lab 09 — CloudWatch Logs Metric Filter Not Matching

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch Logs metric filter that fails to generate custom metric datapoints because its filter pattern does not match the application's JSON log format.

We create a CloudWatch Logs log group and log stream to simulate a payment API that generates structured application logs.

The application produces several log levels, including `INFO`, `WARN`, and `ERROR`.

The Cloud Security team wants to monitor application errors automatically using a CloudWatch Logs metric filter.

The metric filter should detect each `ERROR` log and publish a custom CloudWatch metric named `ApplicationErrorCount`.

However, we intentionally configure the filter with the incorrect JSON field:

`{ $.severity = "ERROR" }`

The application actually uses:

`"level": "ERROR"`

Because the field names do not match, the metric filter fails to identify the application's error events.

Although error logs are successfully stored in CloudWatch Logs, the custom error metric has no datapoints.

We investigate the issue using AWS CLI, CloudWatch Logs filter patterns, JSON log inspection, `TestMetricFilter`, metric filter configuration, and CloudWatch metric queries.

After identifying the incorrect JSON property, we update the filter pattern to:

`{ $.level = "ERROR" }`

We then publish fresh application logs and verify that matching error events generate custom CloudWatch metric datapoints.

Finally, we delete the temporary metric filter and CloudWatch Logs resources.

**Troubleshooting Workflow:**

Log Group Creation → JSON Application Logs → Incorrect Metric Filter → Log Ingestion → Missing Custom Metric → Filter Pattern Testing → Root Cause Analysis → Filter Pattern Correction → Fresh Log Ingestion → Metric Verification → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-009 |
| Difficulty | Intermediate |
| AWS Region | `us-east-1` |
| AWS Services | Amazon CloudWatch Logs, CloudWatch Metrics |
| Local Environment | WSL Ubuntu |
| Interface | AWS CLI v2 |
| Programming Language | Python 3 |
| Scripting Language | Bash |
| Log Group | `/cloudwatch-lab09/payment-api` |
| Log Stream | `application-logs` |
| Metric Filter | `payment-api-error-filter` |
| Metric Namespace | `CloudWatchLab09/Application` |
| Metric Name | `ApplicationErrorCount` |
| Metric Unit | Count |
| Metric Value | 1 per matching event |
| Log Format | JSON |
| Log Retention | 7 days |
| Incorrect Filter | `{ $.severity = "ERROR" }` |
| Correct Filter | `{ $.level = "ERROR" }` |
| Fault Injection | Incorrect JSON field name |
| Expected Failure | No custom metric datapoints |
| Root Cause | Metric filter pattern mismatch |
| Remediation | Update metric filter pattern |
| Verification | TestMetricFilter, GetMetricStatistics, GetMetricData |
| Cleanup | Delete metric filter and log group |

### Lab Objectives

- Understand CloudWatch Logs metric filters.
- Create log groups and log streams.
- Generate structured JSON application logs.
- Publish logs using AWS CLI.
- Configure custom CloudWatch metric transformations.
- Reproduce a filter pattern mismatch.
- Investigate why metric datapoints are missing.
- Test filter patterns using AWS CLI.
- Identify JSON property mismatches.
- Correct a broken metric filter.
- Verify new matching log events generate metrics.
- Understand nonretroactive metric filtering.
- Document before-and-after troubleshooting evidence.
- Remove temporary AWS resources.

---

## 2. Production Incident Scenario

### Incident Description

A company operates a payment processing API that generates structured JSON application logs.

The Cloud Operations and Security teams use Amazon CloudWatch Logs to collect application events and monitor service reliability.

The application produces normal informational messages, performance warnings, and error events.

The security team wants to track the number of application errors using a custom CloudWatch metric.

A CloudWatch Logs metric filter is configured to detect error messages and publish the `ApplicationErrorCount` metric.

The custom metric is intended to support operational dashboards and CloudWatch alarms.

However, engineers discover that the custom error metric contains no datapoints.

The application's log group contains multiple `ERROR` events, and those events can be retrieved successfully.

A Cloud Engineer investigates the metric filter configuration and discovers that it uses the JSON field `severity`.

The application logs use the field `level`.

Because the property names differ, the filter never matches the intended log events.

The engineer tests the original filter pattern using `TestMetricFilter` and confirms that it returns zero matches.

The engineer then tests the correct JSON property and confirms that it matches the application's error events.

After updating the metric filter, the engineer publishes fresh application logs and verifies that custom CloudWatch metric datapoints are generated.

### Incident Symptoms

- CloudWatch log group exists.
- Log stream exists.
- JSON logs are ingested successfully.
- Application errors are visible in CloudWatch Logs.
- Metric filter exists.
- Metric filter configuration is syntactically valid.
- Metric filter searches for an incorrect JSON property.
- TestMetricFilter returns zero matches.
- Custom CloudWatch error metric has no datapoints.
- Monitoring dashboards may not display application error counts.
- Error-based CloudWatch alarms may lack metric data.

### Business Impact

- Application errors may not be detected automatically.
- Error-count monitoring becomes unreliable.
- CloudWatch alarms may not trigger when intended.
- Security monitoring may miss important error patterns.
- Incident detection can be delayed.
- Application dashboards may display incomplete operational data.
- Engineers may incorrectly assume the application is generating no errors.

### Objective

Identify why the CloudWatch Logs metric filter does not recognize application error events, correct the filter pattern, and verify successful custom metric publication.

---

## 3. AWS Architecture

### Monitoring Architecture

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
               /cloudwatch-lab09/payment-api
                            |
                            v
                         Log Stream
                      application-logs
                            |
                            v
                       Metric Filter
                  payment-api-error-filter
                            |
                            v
                     Filter Evaluation
                            |
                            v
                     Metric Transformation
                            |
                            v
                    CloudWatch Custom Metric
                    ApplicationErrorCount
```

### Architecture Before Remediation

```text
Payment API Application
          |
          v
Structured JSON Logs
          |
          v
{
  "level": "ERROR",
  "service": "payment-api"
}
          |
          v
CloudWatch Logs
          |
          v
Metric Filter
          |
          v
{ $.severity = "ERROR" }
          |
          v
JSON Field Not Found
          |
          v
No Matching Events
          |
          v
No Metric Datapoints
          |
          v
Application Error Monitoring Missing
```

### Architecture After Remediation

```text
Payment API Application
          |
          v
Structured JSON Logs
          |
          v
{
  "level": "ERROR",
  "service": "payment-api"
}
          |
          v
CloudWatch Logs
          |
          v
Metric Filter
          |
          v
{ $.level = "ERROR" }
          |
          v
Matching ERROR Events
          |
          v
Metric Transformation
          |
          v
ApplicationErrorCount
          |
          v
CloudWatch Metric Datapoints
```

### Architecture Components

| Component | Purpose |
|---|---|
| WSL Ubuntu | Local environment for AWS CLI |
| Python Log Generator | Generates structured application logs |
| CloudWatch Logs | Collects and stores log events |
| Log Group | Organizes application logs |
| Log Stream | Contains application log events |
| Metric Filter | Evaluates incoming logs against a pattern |
| Metric Transformation | Converts matches into numerical metrics |
| CloudWatch Metrics | Stores custom application error counts |
| AWS CLI | Investigates and remediates the issue |

No EC2 instances, VPCs, SNS topics, or new IAM roles are required.

---

## 4. Understanding CloudWatch Logs Metric Filters

### What Is a CloudWatch Logs Metric Filter?

A CloudWatch Logs metric filter examines incoming log events and publishes numerical CloudWatch metric datapoints when those events match a configured pattern.

Metric filters allow engineers to convert application and security log activity into measurable metrics.

Examples include:

- Application errors
- Authentication failures
- Access denied events
- HTTP 500 responses
- Database connection failures
- Suspicious application activity

### What Is a Filter Pattern?

A filter pattern defines the conditions used to select matching log events.

For structured JSON logs, the pattern can inspect specific JSON fields.

Example:

`{ $.level = "ERROR" }`

This selects JSON log messages whose `level` property has the value `ERROR`.

### What Is a JSON Property Selector?

A JSON property selector identifies a field inside a structured JSON log message.

For example:

```json
{
  "level": "ERROR",
  "service": "payment-api"
}
```

The selector `$.level` refers to the `level` property.

The selector `$.service` refers to the `service` property.

### Why Is Exact Field Matching Important?

The filter must reference the JSON fields actually produced by the application.

In this lab:

| Property | Value |
|---|---|
| Actual log field | `level` |
| Incorrect filter field | `severity` |
| Correct filter field | `level` |

### What Is a Metric Transformation?

A metric transformation specifies how a matching log event becomes a CloudWatch metric.

This lab uses:

```json
{
  "metricName": "ApplicationErrorCount",
  "metricNamespace": "CloudWatchLab09/Application",
  "metricValue": "1",
  "unit": "Count"
}
```

Each matching log event contributes a value of 1.

### What Is TestMetricFilter?

`TestMetricFilter` evaluates a filter pattern against sample log messages.

It helps engineers validate patterns before deploying them.

It does not create CloudWatch metric datapoints.

### Are Metric Filters Retroactive?

No.

Metric filters process newly ingested log events.

Correcting a metric filter does not automatically generate metric datapoints from historical logs.

### What Is a Custom Metric Namespace?

A namespace organizes related CloudWatch metrics.

This lab uses:

`CloudWatchLab09/Application`

### What Is the Sum Statistic?

The Sum statistic calculates the total metric value over an evaluation period.

If two matching error events each contribute 1, the expected total is 2, assuming both contributions appear in the queried period and no duplicate processing occurs.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- Python 3
- CloudWatch Logs permissions
- CloudWatch metric retrieval permissions
- Git and GitHub

### Required AWS API Permissions

```text
logs:CreateLogGroup
logs:CreateLogStream
logs:PutLogEvents
logs:DescribeLogGroups
logs:DescribeLogStreams
logs:FilterLogEvents
logs:GetLogEvents
logs:PutRetentionPolicy
logs:PutMetricFilter
logs:DescribeMetricFilters
logs:TestMetricFilter
logs:DeleteMetricFilter
logs:DeleteLogGroup
logs:ListTagsForResource
cloudwatch:ListMetrics
cloudwatch:GetMetricStatistics
cloudwatch:GetMetricData
```

### Security Rules

- Use disposable AWS resources.
- Do not modify production log groups.
- Use simulated payment API logs.
- Do not include real financial information.
- Do not publish credentials or secrets.
- Verify resource ownership before deletion.
- Review evidence before committing it.
- Delete temporary AWS resources after testing.

### Cost Considerations

Potential AWS charges include:

- CloudWatch Logs ingestion
- CloudWatch Logs storage
- Custom CloudWatch metrics

The lab publishes only a small number of synthetic log events.

No EC2 or VPC resources are required.

---

## 6. Prepare WSL Ubuntu

### Step 1 — Verify AWS CLI

```bash
aws --version
aws sts get-caller-identity
```

### Step 2 — Configure Variables

```bash
export AWS_REGION="us-east-1"
export AWS_PAGER=""

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab09"

export LOG_GROUP="/cloudwatch-lab09/payment-api"
export LOG_STREAM="application-logs"

export FILTER_NAME="payment-api-error-filter"

export METRIC_NAMESPACE="CloudWatchLab09/Application"
export METRIC_NAME="ApplicationErrorCount"

export WRONG_PATTERN='{ $.severity = "ERROR" }'
export CORRECT_PATTERN='{ $.level = "ERROR" }'
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$LOG_GROUP"
echo "$LOG_STREAM"
echo "$FILTER_NAME"
echo "$METRIC_NAMESPACE"
echo "$METRIC_NAME"
```

---

## 7. Create CloudWatch Logs Infrastructure

### Step 1 — Create Log Group

```bash
aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --tags "Project=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

### Step 2 — Configure Log Retention

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 7 \
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
  --query "logGroups[?logGroupName=='$LOG_GROUP'].{Name:logGroupName,Retention:retentionInDays}" \
  --output table \
  --region "$AWS_REGION"
```

Expected retention: 7 days.

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

## 8. Create Incorrect Metric Filter

### Step 1 — Create Metric Transformation

Save as `metric-transformation.json`:

```json
[
  {
    "metricName": "ApplicationErrorCount",
    "metricNamespace": "CloudWatchLab09/Application",
    "metricValue": "1",
    "unit": "Count"
  }
]
```

### Step 2 — Create Misconfigured Metric Filter

```bash
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$WRONG_PATTERN" \
  --metric-transformations file://metric-transformation.json \
  --region "$AWS_REGION"
```

The filter uses:

`{ $.severity = "ERROR" }`

This is syntactically valid but does not match the application's intended JSON property.

### Step 3 — Verify Metric Filter

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  --region "$AWS_REGION"
```

### Step 4 — Inspect Filter Pattern

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --query 'metricFilters[].{Name:filterName,Pattern:filterPattern}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

`{ $.severity = "ERROR" }`

### Step 5 — Save Filter Evidence

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab09-before-filter.json
```

---

## 9. Generate Structured JSON Application Logs

### Step 1 — Create Python Log Generator

Save as `generate-logs.py`:

```python
#!/usr/bin/env python3

import json
import sys
import time

phase = sys.argv[1] if len(sys.argv) > 1 else "before"

messages = [
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "application_started",
        "phase": phase
    },
    {
        "level": "ERROR",
        "service": "payment-api",
        "event": "payment_timeout",
        "phase": phase
    },
    {
        "level": "WARN",
        "service": "payment-api",
        "event": "slow_response",
        "phase": phase
    },
    {
        "level": "ERROR",
        "service": "payment-api",
        "event": "database_connection_failed",
        "phase": phase
    },
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "request_completed",
        "phase": phase
    }
]

base_timestamp = int(time.time() * 1000)

events = []

for index, message in enumerate(messages):
    events.append({
        "timestamp": base_timestamp + index,
        "message": json.dumps(message)
    })

with open(f"{phase}-log-events.json", "w") as file:
    json.dump(events, file, indent=2)

with open(f"{phase}-test-messages.json", "w") as file:
    json.dump(
        [event["message"] for event in events],
        file,
        indent=2
    )

print(f"Generated {len(events)} events for phase: {phase}")
print("Expected ERROR matches: 2")
```

### Step 2 — Generate Initial Test Logs

```bash
python3 generate-logs.py before
```

Expected:

```text
Generated 5 events for phase: before
Expected ERROR matches: 2
```

### Step 3 — Inspect Generated Logs

```bash
cat before-log-events.json
```

### Example Error Log

```json
{
  "level": "ERROR",
  "service": "payment-api",
  "event": "payment_timeout",
  "phase": "before"
}
```

### Test Log Summary

| Log Level | Count |
|---|---|
| INFO | 2 |
| WARN | 1 |
| ERROR | 2 |
| Total | 5 |

---

## 10. Publish Application Logs

### Step 1 — Publish Logs

```bash
aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events file://before-log-events.json \
  --region "$AWS_REGION"
```

### Step 2 — Retrieve Log Events

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --start-from-head \
  --output json \
  --region "$AWS_REGION"
```

Expected: all five application events are available.

### Step 3 — Search for ERROR Events

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "$CORRECT_PATTERN" \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: two matching error messages.

### Step 4 — Verify Log Ingestion

| Component | Expected Result |
|---|---|
| Log Group | Available |
| Log Stream | Available |
| JSON Logs | Ingested |
| INFO Events | 2 |
| WARN Events | 1 |
| ERROR Events | 2 |
| CloudWatch Logs Retrieval | Working |

The application is generating error logs correctly.

The problem is with the metric filter.

---

## 11. Investigate Missing Metric Datapoints

### Step 1 — Test Incorrect Filter Pattern

```bash
aws logs test-metric-filter \
  --filter-pattern "$WRONG_PATTERN" \
  --log-event-messages file://before-test-messages.json \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
{
  "matches": []
}
```

### Step 2 — Verify Filter Configuration

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --query 'metricFilters[].{Name:filterName,Pattern:filterPattern}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: the incorrect `severity` property.

### Step 3 — Search for Custom Metric

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --region "$AWS_REGION"
```

Expected for a fresh lab without any matching events:

```json
{
  "Metrics": []
}
```

### Step 4 — Configure Time Range

```bash
export START_TIME=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 5 — Retrieve Metric Statistics

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --region "$AWS_REGION"
```

Expected:

```json
{
  "Label": "ApplicationErrorCount",
  "Datapoints": []
}
```

### Step 6 — Save Broken Filter Test

```bash
aws logs test-metric-filter \
  --filter-pattern "$WRONG_PATTERN" \
  --log-event-messages file://before-test-messages.json \
  --output json \
  --region "$AWS_REGION" \
  > lab09-before-filter-test.json
```

### Step 7 — Save Missing Metric Evidence

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab09-before-metric.json
```

### Step 8 — Save Missing Datapoint Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --region "$AWS_REGION" \
  > lab09-before-metric-data.json
```

### Investigation Matrix

| Investigation | Expected Finding |
|---|---|
| Log Ingestion | Working |
| JSON Logs | Available |
| Error Events | Present |
| Metric Filter | Exists |
| Filter Syntax | Valid |
| Filter Property | Incorrect |
| TestMetricFilter | Zero matches |
| Custom Metric | Missing |
| Metric Datapoints | None |
| Root Cause | Filter pattern mismatch |

---

## 12. Root Cause Analysis

### Root Cause

The CloudWatch Logs metric filter used an incorrect JSON property selector.

The application's JSON logs contained the field:

`level`

However, the metric filter searched for:

`severity`

The configured filter pattern was:

`{ $.severity = "ERROR" }`

Since the application log messages did not contain the expected `severity` property, the filter did not match any error events.

The CloudWatch Logs ingestion pipeline was working correctly.

The application generated error events successfully.

The metric filter existed and was syntactically valid.

However, its logic did not match the application's JSON schema.

Consequently, no metric datapoints were published.

### Root Cause Flow

```text
Payment API
       |
       v
JSON Application Logs
       |
       v
"level": "ERROR"
       |
       v
CloudWatch Logs
       |
       v
Metric Filter
       |
       v
{ $.severity = "ERROR" }
       |
       v
Incorrect JSON Property
       |
       v
Zero Matching Events
       |
       v
No Metric Transformation
       |
       v
ApplicationErrorCount Missing
```

### Five Whys

1. **Why was the custom metric missing?** The metric filter did not publish matching datapoints.
2. **Why were no datapoints published?** The filter pattern matched zero application logs.
3. **Why did the pattern match zero events?** It referenced `severity` instead of `level`.
4. **Why was the mismatch not detected?** The filter was not validated against representative application logs.
5. **How was the issue resolved?** The pattern was corrected and fresh matching logs were ingested.

### Root Cause Summary

| Component | Finding |
|---|---|
| Incident | INC-CW-009 |
| AWS Services | CloudWatch Logs, CloudWatch Metrics |
| Log Ingestion | Healthy |
| Error Logs | Available |
| Metric Filter | Misconfigured |
| Incorrect Property | severity |
| Correct Property | level |
| Initial Pattern Matches | 0 |
| Root Cause | JSON field mismatch |
| Remediation | Update filter pattern |
| Expected Recovery | Metric datapoints generated |

**Key Lesson:** A CloudWatch Logs metric filter can be created successfully but still fail to publish metrics when its pattern does not match the actual application log schema.

---

## 13. Remediation — Correct the Metric Filter

### Step 1 — Test Correct Pattern

```bash
aws logs test-metric-filter \
  --filter-pattern "$CORRECT_PATTERN" \
  --log-event-messages file://before-test-messages.json \
  --output json \
  --region "$AWS_REGION"
```

Expected: two matches.

### Step 2 — Count Matches

```bash
aws logs test-metric-filter \
  --filter-pattern "$CORRECT_PATTERN" \
  --log-event-messages file://before-test-messages.json \
  --query 'length(matches)' \
  --output text \
  --region "$AWS_REGION"
```

Expected:

```text
2
```

### Step 3 — Update Metric Filter

```bash
aws logs put-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME" \
  --filter-pattern "$CORRECT_PATTERN" \
  --metric-transformations file://metric-transformation.json \
  --region "$AWS_REGION"
```

### Step 4 — Verify Corrected Pattern

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --filter-name-prefix "$FILTER_NAME" \
  --query 'metricFilters[].{Name:filterName,Pattern:filterPattern}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

`{ $.level = "ERROR" }`

### Step 5 — Save Corrected Filter Evidence

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --filter-name-prefix "$FILTER_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab09-after-filter.json
```

### Remediation Summary

| Component | Before | After |
|---|---|---|
| Log Ingestion | Working | Working |
| JSON Format | Correct | Correct |
| Filter Property | severity | level |
| Filter Test | Zero matches | Two matches |
| Metric Filter | Incorrect | Corrected |
| Metric Publishing | Missing | Ready for new events |

---

## 14. Publish Fresh Logs After Remediation

### Why Fresh Logs Are Required

CloudWatch Logs metric filters process newly ingested log events.

Updating the filter does not automatically convert historical log events into custom metric datapoints.

We therefore generate new error logs after remediation.

### Step 1 — Generate Fresh Logs

```bash
python3 generate-logs.py after
```

Expected:

```text
Generated 5 events for phase: after
Expected ERROR matches: 2
```

### Step 2 — Inspect Fresh Logs

```bash
cat after-log-events.json
```

### Step 3 — Publish Fresh Logs

```bash
aws logs put-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --log-events file://after-log-events.json \
  --region "$AWS_REGION"
```

### Step 4 — Verify Error Events

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "$CORRECT_PATTERN" \
  --query 'events[].message' \
  --output json \
  --region "$AWS_REGION"
```

Expected: four matching error messages in the log group if both batches were ingested successfully.

The two events ingested before remediation do not retroactively create datapoints for the corrected filter.

### Step 5 — Confirm Metric Discovery

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --region "$AWS_REGION"
```

Expected after discovery updates:

```json
{
  "Metrics": [
    {
      "Namespace": "CloudWatchLab09/Application",
      "MetricName": "ApplicationErrorCount",
      "Dimensions": []
    }
  ]
}
```

A new custom metric can take several minutes to appear in metric discovery results.

---

## 15. Verify Custom Metric Recovery

### Step 1 — Refresh Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 2 — Retrieve Metric Statistics

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --region "$AWS_REGION"
```

Expected: numerical metric datapoints.

For two matching events published within the same one-minute period, the expected Sum is 2.

Actual values can vary with event timestamps, aggregation periods, and duplicate ingestion.

### Step 3 — Create Metric Query

Save as `metric-query.json`:

```json
[
  {
    "Id": "application_errors",
    "MetricStat": {
      "Metric": {
        "Namespace": "CloudWatchLab09/Application",
        "MetricName": "ApplicationErrorCount"
      },
      "Period": 60,
      "Stat": "Sum"
    },
    "ReturnData": true
  }
]
```

### Step 4 — Retrieve Metric Data

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://metric-query.json \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --region "$AWS_REGION"
```

Expected: numerical values for `ApplicationErrorCount`.

### Step 5 — Save Metric Evidence

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab09-after-metric.json
```

### Step 6 — Save Metric Datapoints

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://metric-query.json \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --output json \
  --region "$AWS_REGION" \
  > lab09-after-metric-data.json
```

### Step 7 — Save Corrected Pattern Test

```bash
aws logs test-metric-filter \
  --filter-pattern "$CORRECT_PATTERN" \
  --log-event-messages file://after-test-messages.json \
  --output json \
  --region "$AWS_REGION" \
  > lab09-after-filter-test.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| CloudWatch Logs | Working | Working |
| JSON Log Ingestion | Working | Working |
| ERROR Events | Available | Available |
| Filter Pattern | Incorrect | Corrected |
| JSON Property | severity | level |
| TestMetricFilter Matches | 0 | 2 |
| Custom Metric | Missing | Published |
| Metric Datapoints | None | Available |
| Error Monitoring | Not functioning | Functioning |
| Incident | Active | Resolved after verification |

### Final Verification Criteria

The incident is resolved when:

1. CloudWatch Logs contains the expected application error events.
2. The metric filter references the correct JSON property.
3. TestMetricFilter reports two matches for the sample events.
4. The updated metric filter is saved.
5. Fresh error logs are successfully ingested.
6. CloudWatch publishes custom error-count datapoints.
7. The metric can be retrieved using AWS CLI.
8. Before-and-after evidence is documented.

---

## 16. Understanding Metric Filter Limitations

### Metric Filters Are Not Retroactive

Metric filters process incoming log events.

Existing log events are not automatically reprocessed after a filter change.

### Metrics May Not Appear Immediately

CloudWatch metric discovery may take several minutes.

The correct metric should be verified using both metric discovery and datapoint retrieval.

### Metric Dimensions Affect Cost

Custom metric dimensions can create additional distinct metric series.

Using high-cardinality fields such as unique request IDs or user identifiers can significantly increase the number of custom metrics.

### Filter Matching Depends on Log Structure

A pattern configured for JSON logs must match the JSON schema used by the application.

Different applications may use fields such as:

- `level`
- `severity`
- `logLevel`
- `status`
- `errorType`

Engineers should validate the actual log structure before creating metric filters.

### Metric Filter Counts Are Not Always Exactly Once

CloudWatch Logs metric filtering uses managed log processing.

Duplicate processing can occasionally occur, so metric counts should be interpreted according to the application's monitoring requirements.

### Missing Zero-Valued Datapoints

Our metric transformation does not define a default value.

Therefore, nonmatching events do not generate zero-valued datapoints.

This means periods without matching events may have no metric data rather than a numerical zero.

---

## 17. Production Troubleshooting Best Practices

### Metric Filter Troubleshooting Checklist

1. Verify the CloudWatch log group exists.
2. Verify the log stream exists.
3. Confirm application logs are being ingested.
4. Retrieve representative log messages.
5. Verify the JSON structure.
6. Inspect the metric filter configuration.
7. Confirm the filter pattern.
8. Compare JSON property names.
9. Verify expected values and capitalization.
10. Test the pattern using TestMetricFilter.
11. Check the metric transformation.
12. Verify the metric namespace.
13. Verify the metric name.
14. Query the custom metric.
15. Identify the root cause.
16. Correct the filter pattern.
17. Test the corrected filter.
18. Publish fresh log events.
19. Verify numerical datapoints.
20. Document the troubleshooting evidence.

### Common Metric Filter Problems

| Symptom | Possible Cause |
|---|---|
| No metric datapoints | Filter pattern mismatch |
| Error logs exist but metric missing | Wrong JSON property |
| Filter test returns zero matches | Incorrect field or value |
| Filter creation fails | Invalid syntax or IAM permissions |
| Metric not discoverable | No matching events or discovery delay |
| Historical logs don't generate metrics | Filter not retroactive |
| Unexpected metric count | Duplicate delivery or matching logic |
| Metric appears in wrong namespace | Incorrect transformation |
| Missing zero values | No default metric value |
| Too many custom metrics | High-cardinality dimensions |

### Production Recommendations

- Use consistent structured logging.
- Maintain documented JSON schemas.
- Validate metric filters before deployment.
- Test filters against representative log messages.
- Manage metric filters through Infrastructure as Code.
- Avoid unnecessary high-cardinality dimensions.
- Monitor critical security and application events.
- Verify metric publication after configuration changes.
- Create CloudWatch alarms only after validating the corresponding metrics.
- Review application logging changes for potential impacts on metric filters.

### Security Monitoring Examples

Metric filters can support monitoring for:

- Repeated authentication failures
- Authorization errors
- Suspicious application requests
- Access denied events
- Application exceptions
- Failed security checks
- Unexpected administrative activity

The filter must always match the actual log format.

---

## 18. AWS Resource Cleanup

**Warning:** Verify the log group belongs to Lab 09 before deleting it.

### Step 1 — Retrieve Log Group ARN

```bash
export LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='$LOG_GROUP'].arn | [0]" \
  --output text \
  --region "$AWS_REGION")
```

### Step 2 — Verify Resource Tags

```bash
aws logs list-tags-for-resource \
  --resource-arn "$LOG_GROUP_ARN" \
  --region "$AWS_REGION"
```

Confirm:

`Project=CloudWatch-Troubleshooting-Lab09`

### Step 3 — Delete Metric Filter

```bash
aws logs delete-metric-filter \
  --log-group-name "$LOG_GROUP" \
  --filter-name "$FILTER_NAME" \
  --region "$AWS_REGION"
```

### Step 4 — Verify Filter Deletion

```bash
aws logs describe-metric-filters \
  --log-group-name "$LOG_GROUP" \
  --filter-name-prefix "$FILTER_NAME" \
  --query 'metricFilters' \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[]
```

### Step 5 — Delete Log Group

```bash
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$AWS_REGION"
```

Deleting the log group also deletes its log streams and stored log events.

### Step 6 — Verify Log Group Deletion

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

### CloudWatch Metric Cleanup

CloudWatch does not provide an API to delete an individual custom metric series.

After deleting the metric filter and log group, no new metric datapoints should be generated by this lab.

Previously published metric data remains subject to CloudWatch retention policies.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| Metric Filter | Deleted |
| Log Group | Deleted |
| Log Stream | Deleted with log group |
| Test Log Events | Deleted with log group |
| New Metric Publishing | Stopped |
| Historical Custom Metric | Expires normally |
| EC2 Instances | None created |
| VPC Resources | None created |
| IAM Roles | None created |

---

## 19. Interview Questions and Answers

### Q1. What is a CloudWatch Logs metric filter?

A metric filter evaluates incoming log events and publishes numerical CloudWatch metrics when the events match its configured pattern.

### Q2. What caused this lab's metric filter failure?

The filter searched for the JSON field `severity`, but the application logs used `level`.

### Q3. Which AWS CLI command tests a metric filter?

`aws logs test-metric-filter`.

### Q4. Which command creates or updates a metric filter?

`aws logs put-metric-filter`.

### Q5. What is a metric transformation?

A configuration that defines the metric name, namespace, and numerical value generated when a log event matches.

### Q6. Are metric filters retroactive?

No. Metric filters process newly ingested log events.

### Q7. What does metricValue=1 mean?

Each matching event contributes a numerical value of 1.

### Q8. What is the difference between FilterLogEvents and a metric filter?

`FilterLogEvents` searches stored log events.

A metric filter evaluates incoming log events and generates metrics.

### Q9. Why might a custom metric remain missing after correcting the filter?

No fresh matching events may have been ingested, or CloudWatch metric discovery may not have updated yet.

### Q10. What are metric dimensions?

Name/value pairs used to identify specific CloudWatch metric series.

### Q11. Why should high-cardinality dimensions be avoided?

They can create large numbers of custom metric series, increasing cost and operational complexity.

### Q12. Can CloudWatch metric filters help with security monitoring?

Yes. They can convert authentication failures, access denials, and other security-relevant log events into metrics.

### Q13. Does successful metric filter creation guarantee correct monitoring?

No. A syntactically valid filter may not match the actual application log format.

### Q14. How would you explain this lab in an interview?

I created a CloudWatch Logs log group and published structured JSON application logs using Python and AWS CLI.

I intentionally configured a metric filter with an incorrect JSON field name.

Although the application error logs were successfully ingested into CloudWatch Logs, the custom error-count metric had no datapoints.

I investigated the filter configuration, compared the JSON log structure against the filter pattern, and used TestMetricFilter to reproduce the issue.

I discovered that the filter searched for `severity`, while the application logs used `level`.

I corrected the filter pattern and verified that it matched the expected error events.

After publishing fresh application error logs, I confirmed that the metric filter generated custom CloudWatch datapoints.

Finally, I saved the before-and-after evidence and deleted the temporary AWS resources.

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
│   ├── README.md
│   ├── generate-logs.py
│   ├── metric-transformation.json
│   ├── metric-query.json
│   ├── before-log-events.json
│   ├── before-test-messages.json
│   ├── after-log-events.json
│   ├── after-test-messages.json
│   ├── lab09-before-filter.json
│   ├── lab09-before-filter-test.json
│   ├── lab09-before-metric.json
│   ├── lab09-before-metric-data.json
│   ├── lab09-after-filter.json
│   ├── lab09-after-filter-test.json
│   ├── lab09-after-metric.json
│   └── lab09-after-metric-data.json
│
└── 10-cloudwatch-logs-insights-investigation/
```

### File Descriptions

| File | Purpose |
|---|---|
| `README.md` | Complete troubleshooting documentation |
| `generate-logs.py` | Generates structured application logs |
| `metric-transformation.json` | Defines metric transformation |
| `metric-query.json` | Defines GetMetricData query |
| `before-log-events.json` | Initial test log events |
| `before-test-messages.json` | Sample messages for filter testing |
| `after-log-events.json` | Fresh logs after remediation |
| `after-test-messages.json` | Corrected pattern test messages |
| `lab09-before-filter.json` | Initial metric filter configuration |
| `lab09-before-filter-test.json` | Incorrect pattern test evidence |
| `lab09-before-metric.json` | Missing metric discovery evidence |
| `lab09-before-metric-data.json` | Missing metric datapoint evidence |
| `lab09-after-filter.json` | Corrected filter configuration |
| `lab09-after-filter-test.json` | Corrected pattern test evidence |
| `lab09-after-metric.json` | Successful custom metric discovery |
| `lab09-after-metric-data.json` | Custom metric datapoints after remediation |

### Evidence Guidelines

Evidence files should contain actual AWS CLI responses.

Do not fabricate metric values, timestamps, filter matches, or AWS API results.

Review evidence before publishing it to GitHub.

Do not include AWS credentials, tokens, passwords, or real customer information.

### Suggested Git Ignore Entries

```gitignore
__pycache__/
*.pyc
.venv/
.env
```

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how an incorrectly configured CloudWatch Logs metric filter can prevent custom metrics from being published, even when application logs are being ingested correctly.

We created a CloudWatch Logs log group and log stream.

We developed a Python script to generate structured JSON application logs containing informational messages, warnings, and errors.

We created a metric transformation that publishes the `ApplicationErrorCount` custom metric.

However, we intentionally configured the metric filter with the incorrect JSON property `severity`.

The application logs used the property `level`.

Because the pattern did not match the log structure, the filter generated no custom metric datapoints.

We investigated the issue using AWS CLI and confirmed that error logs existed in CloudWatch Logs.

We used TestMetricFilter to demonstrate that the incorrect pattern matched zero events.

After comparing the filter against the JSON structure, we identified the property mismatch as the root cause.

We updated the filter pattern and confirmed that it matched the expected error events.

We then published fresh logs because CloudWatch Logs metric filters do not retroactively generate metrics from historical events.

Finally, we verified the custom metric using CloudWatch metric queries and removed the temporary resources.

**Key Lesson:** Effective metric filter troubleshooting requires validating the actual application log format, testing filter patterns, inspecting metric transformations, and confirming that new matching log events generate numerical CloudWatch datapoints.

### Skills Demonstrated

- Amazon CloudWatch Logs
- Amazon CloudWatch Metrics
- CloudWatch metric filters
- JSON filter patterns
- Structured application logging
- CloudWatch log groups
- CloudWatch log streams
- Metric transformations
- Custom metric namespaces
- Application error monitoring
- TestMetricFilter
- PutMetricFilter
- DescribeMetricFilters
- PutLogEvents
- GetLogEvents
- FilterLogEvents
- ListMetrics
- GetMetricStatistics
- GetMetricData
- Python 3
- JSON processing
- AWS CLI v2
- Linux Bash
- Root cause analysis
- Monitoring configuration remediation
- Metric verification
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-009 |
| Scenario | CloudWatch Logs Metric Filter Not Matching |
| Log Group | `/cloudwatch-lab09/payment-api` |
| Log Stream | `application-logs` |
| Log Format | JSON |
| Log Ingestion | Working |
| Initial Filter | `{ $.severity = "ERROR" }` |
| Correct Filter | `{ $.level = "ERROR" }` |
| Initial Matches | 0 |
| Corrected Test Matches | 2 |
| Root Cause | JSON property mismatch |
| Remediation | Update metric filter |
| Custom Metric | ApplicationErrorCount |
| Metric Namespace | CloudWatchLab09/Application |
| New Error Datapoints | Published after remediation |
| Resource Cleanup | Metric filter and log group deleted |
| Incident Status | Resolved after verification |

**Key Takeaway:** CloudWatch Logs metric filters provide an effective way to convert application and security logs into operational metrics. However, their reliability depends on matching the real log schema. Engineers should test filter patterns before deployment, verify metric generation with fresh events, and maintain consistent structured logging across applications.

---

## Official AWS Documentation

- [Amazon CloudWatch Logs — Creating Metrics from Log Events](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/MonitoringLogData.html)
- [CloudWatch Logs — Filter and Pattern Syntax](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [CloudWatch Logs — JSON Filter Patterns](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/matching-terms-json-log-events.html)
- [AWS CLI — PutMetricFilter](https://docs.aws.amazon.com/cli/latest/reference/logs/put-metric-filter.html)
- [AWS CLI — TestMetricFilter](https://docs.aws.amazon.com/cli/latest/reference/logs/test-metric-filter.html)
- [AWS CLI — DescribeMetricFilters](https://docs.aws.amazon.com/cli/latest/reference/logs/describe-metric-filters.html)
- [AWS CLI — GetMetricData](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-data.html)
- [AWS CLI — DeleteMetricFilter](https://docs.aws.amazon.com/cli/latest/reference/logs/delete-metric-filter.html)