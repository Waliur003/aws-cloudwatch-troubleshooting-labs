# Lab 06 — CloudWatch Alarm Threshold Misconfiguration

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch alarm that fails to detect high API response latency because its configured threshold is incorrect.

We create a custom CloudWatch metric named `ResponseLatency` to simulate an application's API response time.

The company's performance requirement states that average API latency should remain below 500 milliseconds.

However, we intentionally configure the CloudWatch alarm with a threshold of 2,000 milliseconds.

We use a Bash script and AWS CLI to publish repeated latency datapoints of 900 milliseconds.

Although 900 milliseconds violates the application's intended performance threshold, the CloudWatch alarm remains in the `OK` state because the configured alarm threshold is too high.

We investigate the issue using AWS CLI, CloudWatch metric statistics, alarm state history, threshold configuration, evaluation periods, comparison operators, and missing-data treatment.

After identifying the incorrect threshold, we update the CloudWatch alarm to use the correct value of 500 milliseconds.

We continue publishing high-latency datapoints and verify that the alarm transitions from `OK` to `ALARM`.

We also perform an optional recovery test by publishing normal latency values and confirming that the alarm returns to `OK`.

Finally, we stop the test publishers and delete the temporary CloudWatch alarm to avoid unnecessary AWS charges.

**Troubleshooting Workflow:**

Custom Metric Creation → Bash Metric Publisher → Incorrect Alarm Threshold → Missed High-Latency Detection → CloudWatch Investigation → Root Cause Analysis → Threshold Correction → ALARM Verification → Optional Recovery Test → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-006 |
| Difficulty | Intermediate |
| AWS Region | `us-east-1` |
| AWS Service | Amazon CloudWatch |
| Local Environment | WSL Ubuntu |
| Interface | AWS CLI v2 |
| Scripting Language | Bash |
| Metric Namespace | `CloudWatchLab06/API` |
| Metric Name | `ResponseLatency` |
| Metric Dimension | `Environment=Production` |
| Metric Unit | Milliseconds |
| Simulated High Latency | 900 ms |
| Simulated Normal Latency | 150 ms |
| Required Threshold | 500 ms |
| Incorrect Threshold | 2,000 ms |
| Alarm Name | `cloudwatch-lab06-latency-alarm` |
| Statistic | Average |
| Period | 60 seconds |
| Evaluation Periods | 1 |
| Datapoints to Alarm | 1 |
| Comparison Operator | GreaterThanThreshold |
| Missing Data Treatment | missing |
| Fault Injection | Incorrect alarm threshold |
| Expected Failure | Alarm remains OK during high latency |
| Root Cause | Threshold does not match performance requirement |
| Remediation | Change threshold from 2,000 ms to 500 ms |
| Expected Recovery | Alarm transitions to ALARM |
| Verification | DescribeAlarms, DescribeAlarmHistory, GetMetricStatistics |

---

## 2. Production Incident Scenario

### Incident Description

A company operates a payment API that handles customer transactions.

The Cloud Operations team monitors API response latency using Amazon CloudWatch.

The company requires average API latency to remain below 500 milliseconds.

A CloudWatch alarm is configured to detect performance degradation and notify engineers when latency exceeds the acceptable limit.

However, the API begins experiencing an average response time of 900 milliseconds.

Although this violates the company's performance requirement, the CloudWatch alarm continues reporting `OK`.

The operations team investigates and discovers that the alarm was mistakenly configured with a threshold of 2,000 milliseconds instead of 500 milliseconds.

Because the measured latency is below the incorrect threshold, CloudWatch evaluates the metric as nonbreaching.

A Cloud Engineer is assigned to investigate the monitoring failure.

The engineer verifies the metric data, namespace, dimensions, alarm statistic, comparison operator, evaluation periods, and configured threshold.

After identifying the incorrect threshold, the engineer updates the alarm and verifies that it detects high latency correctly.

### Incident Symptoms

- API latency metrics are published successfully.
- The custom CloudWatch metric is available.
- Metric namespace is correct.
- Metric dimensions are correct.
- Metric values indicate high latency.
- Actual latency is approximately 900 milliseconds.
- Required performance threshold is 500 milliseconds.
- Alarm threshold is incorrectly set to 2,000 milliseconds.
- Alarm remains in `OK` after evaluating high latency.
- No alarm notification would be triggered by this condition.
- The monitoring system gives an incorrect impression of application health.

### Business Impact

- Application performance degradation may go undetected.
- Customers may experience slow API responses.
- Operations teams may not receive timely alerts.
- Incident detection may be delayed.
- Monitoring dashboards can create a false sense of health.
- Service-level objectives may be violated without an alarm.
- Engineers may overlook performance problems because CloudWatch reports `OK`.

### Objective

Identify why the CloudWatch alarm is not detecting high API latency, correct its threshold, and verify that the alarm transitions to `ALARM` when latency violates the company's performance requirement.

---

## 3. AWS Architecture

### Monitoring Architecture

```text
                       AWS Region
                        us-east-1
                            |
                            v
                     WSL Ubuntu
                            |
                            v
                   Bash Metric Publisher
                            |
                            v
                     AWS CLI v2
                            |
                            v
                     PutMetricData
                            |
                            v
                     Amazon CloudWatch
                            |
                            v
                       Custom Metric
                      ResponseLatency
                            |
                            v
                        Namespace
                    CloudWatchLab06/API
                            |
                            v
                         Dimension
                   Environment=Production
                            |
                            v
                     CloudWatch Alarm
                            |
                            v
                    Threshold Evaluation
                            |
                            v
                OK / ALARM / INSUFFICIENT_DATA
```

### Architecture Before Remediation

```text
Bash Metric Publisher
          |
          v
ResponseLatency = 900 ms
          |
          v
CloudWatch Custom Metric
          |
          v
CloudWatch Alarm
          |
          v
Configured Threshold = 2000 ms
          |
          v
Comparison: 900 > 2000?
          |
          v
         NO
          |
          v
Alarm State = OK
          |
          v
Performance Issue Not Detected
```

### Architecture After Remediation

```text
Bash Metric Publisher
          |
          v
ResponseLatency = 900 ms
          |
          v
CloudWatch Custom Metric
          |
          v
CloudWatch Alarm
          |
          v
Correct Threshold = 500 ms
          |
          v
Comparison: 900 > 500?
          |
          v
         YES
          |
          v
Alarm State = ALARM
          |
          v
Performance Issue Detected
```

### Architecture Components

| Component | Purpose |
|---|---|
| WSL Ubuntu | Executes Bash and AWS CLI |
| Bash Metric Publisher | Generates synthetic API latency |
| PutMetricData | Publishes custom latency metrics |
| CloudWatch Metrics | Stores latency datapoints |
| CloudWatch Alarm | Evaluates latency against the threshold |
| Alarm History | Records state transitions and configuration changes |
| AWS CLI | Investigates and remediates the incident |

No EC2 instances, IAM roles, VPCs, or networking resources are required.

---

## 4. Understanding CloudWatch Alarm Thresholds

### What Is a CloudWatch Alarm?

A CloudWatch alarm evaluates metric data against a configured condition.

An alarm can detect operational problems such as:

- High CPU utilization
- High API latency
- Increased application errors
- Database performance problems
- Low available storage
- Failed infrastructure health checks

### What Is an Alarm Threshold?

A threshold is a numerical value used to determine whether a metric is breaching.

For example:

```text
Metric: ResponseLatency
Threshold: 500 milliseconds
Comparison: GreaterThanThreshold
```

The alarm should detect evaluated latency greater than 500 milliseconds.

### What Is GreaterThanThreshold?

`GreaterThanThreshold` means that the evaluated metric must exceed the configured threshold.

Example:

```text
Latency = 900 ms
Threshold = 500 ms

900 > 500

Result: Breaching
```

### What Is a CloudWatch Statistic?

CloudWatch statistics aggregate metric datapoints over a selected period.

Common statistics:

| Statistic | Meaning |
|---|---|
| Average | Mean value during the period |
| Maximum | Highest value during the period |
| Minimum | Lowest value during the period |
| Sum | Total of the datapoint values |
| SampleCount | Number of samples |

This lab uses `Average`.

### What Is an Evaluation Period?

An evaluation period determines the time interval used to aggregate and evaluate metric data.

This lab uses a period of 60 seconds.

### What Is EvaluationPeriods?

`EvaluationPeriods` specifies the number of periods considered for alarm evaluation.

This lab uses:

`EvaluationPeriods=1`

### What Is DatapointsToAlarm?

`DatapointsToAlarm` specifies how many breaching datapoints are required within the evaluation periods.

This lab uses:

`DatapointsToAlarm=1`

### What Is an M-out-of-N Alarm?

An M-out-of-N alarm requires a configured number of breaching datapoints within a larger evaluation window.

For example:

```text
DatapointsToAlarm = 2
EvaluationPeriods = 3
```

This means two of the three evaluation periods must be breaching for the alarm condition.

### What Is TreatMissingData?

This setting determines how missing metric data is handled when CloudWatch needs to account for missing datapoints.

Common settings include:

- missing
- notBreaching
- breaching
- ignore

This lab uses `missing` so a complete absence of usable data can produce `INSUFFICIENT_DATA`.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- CloudWatch PutMetricData permissions
- CloudWatch alarm management permissions
- CloudWatch metric retrieval permissions
- Git and GitHub

### Security Rules

- Use dedicated lab metrics and alarms.
- Do not modify production alarms.
- Use synthetic latency values only.
- Do not configure production notification actions.
- Verify alarm ownership before deletion.
- Review evidence before publishing.
- Stop metric publishers after testing.
- Delete the temporary CloudWatch alarm.

### Cost Considerations

Potential charges include:

- CloudWatch custom metrics
- CloudWatch metric alarms

The lab does not require EC2, EBS, public IPv4 addresses, or VPC infrastructure.

The metric publishers should be stopped after testing to avoid unnecessary metric publication.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab06"

export NAMESPACE="CloudWatchLab06/API"
export METRIC_NAME="ResponseLatency"

export ALARM_NAME="cloudwatch-lab06-latency-alarm"

export ENVIRONMENT="Production"

export WRONG_THRESHOLD="2000"
export CORRECT_THRESHOLD="500"

export TEST_LATENCY="900"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$NAMESPACE"
echo "$METRIC_NAME"
echo "$ALARM_NAME"
echo "$WRONG_THRESHOLD"
echo "$CORRECT_THRESHOLD"
```

All commands are executed from WSL Ubuntu.

---

## 7. Create High-Latency Metric Publisher

### Step 1 — Create Bash Script

Save as `publish-high-latency.sh`:

```bash
#!/bin/bash

set -u

AWS_REGION="us-east-1"
NAMESPACE="CloudWatchLab06/API"
METRIC_NAME="ResponseLatency"
ENVIRONMENT="Production"

LATENCY=900

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
```

### Step 2 — Make Script Executable

```bash
chmod +x publish-high-latency.sh
```

### Step 3 — Verify Script

```bash
cat publish-high-latency.sh
```

### Step 4 — Start Publisher

```bash
nohup bash ./publish-high-latency.sh \
  > lab06-publisher.log 2>&1 &

echo $! > lab06-publisher.pid
```

### Step 5 — Verify Running Process

```bash
ps -p "$(cat lab06-publisher.pid)" -o pid,stat,cmd
```

### Step 6 — Inspect Publisher Logs

```bash
tail -n 10 lab06-publisher.log
```

Expected example:

```text
Publishing sample 1: 900ms
Publishing sample 2: 900ms
Publishing sample 3: 900ms
```

The script attempts to publish 30 synthetic latency samples, approximately one every ten seconds.

If the publisher finishes before alarm verification, restart it with the same command.

---

## 8. Verify Custom Metric Publication

### Step 1 — List the Metric

```bash
aws cloudwatch list-metrics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --region "$AWS_REGION"
```

Expected: the custom metric becomes discoverable after CloudWatch updates its metric discovery results.

### Step 2 — Configure Time Range

```bash
export START_TIME=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)

export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 3 — Retrieve Metric Statistics

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: datapoints with an average of approximately 900 milliseconds.

Because all test samples have the same value, a one-minute period containing only these samples should have an average of 900 milliseconds.

### Step 4 — Save Metric Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab06-metric-data.json
```

### Expected Findings

| Check | Expected Result |
|---|---|
| Metric Namespace | CloudWatchLab06/API |
| Metric Name | ResponseLatency |
| Dimension | Environment=Production |
| Metric Publishing | Working |
| Simulated Latency | 900 ms |
| Custom Metric Datapoints | Available |

---

## 9. Fault Injection — Incorrect Alarm Threshold

### Step 1 — Create Misconfigured Alarm

We intentionally configure the CloudWatch alarm with a threshold of 2,000 milliseconds.

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Lab06 - Incorrect latency threshold of 2000ms" \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold "$WRONG_THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data missing \
  --no-actions-enabled \
  --tags "Key=Project,Value=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

### Step 2 — Verify Alarm Configuration

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold}' \
  --output table \
  --region "$AWS_REGION"
```

Expected threshold:

```text
2000
```

### Step 3 — Monitor Alarm State

```bash
for attempt in $(seq 1 18); do

  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "OK" ]; then
    echo "Fault reproduced: alarm is OK despite 900ms latency"
    break
  fi

  sleep 10

done
```

Expected after metric evaluation:

```text
OK
Fault reproduced: alarm is OK despite 900ms latency
```

A new alarm may initially show `INSUFFICIENT_DATA` until sufficient metric data is available.

### Step 4 — Verify Incorrect Threshold

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Threshold:Threshold,Operator:ComparisonOperator,State:StateValue}' \
  --output table \
  --region "$AWS_REGION"
```

### Why the Alarm Remains OK

The configured threshold is:

`2000 ms`

The simulated latency is:

`900 ms`

CloudWatch evaluates:

`900 > 2000`

The result is false.

Therefore, the alarm remains in `OK` after evaluating the nonbreaching datapoint.

However, the required performance threshold is 500 milliseconds.

According to the business requirement:

`900 > 500`

The latency is unacceptable.

### Fault Injection Summary

| Component | Expected Result |
|---|---|
| Metric Publisher | Running |
| Metric Publishing | Working |
| Namespace | Correct |
| Dimensions | Correct |
| Actual Latency | 900 ms |
| Required Threshold | 500 ms |
| Configured Threshold | 2,000 ms |
| Comparison Operator | GreaterThanThreshold |
| Alarm State | OK |
| Performance Issue | Not detected |

---

## 10. Investigate Alarm Configuration

### Step 1 — Inspect Alarm State Reason

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{State:StateValue,Reason:StateReason,Updated:StateUpdatedTimestamp}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: the state reason indicates that the evaluated datapoints are not breaching the configured threshold.

### Step 2 — Inspect Alarm History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-records 10 \
  --output table \
  --region "$AWS_REGION"
```

Review state changes and evaluation information.

### Step 3 — Inspect Threshold

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Threshold:Threshold,Operator:ComparisonOperator,Metric:MetricName}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

```text
Threshold: 2000
Operator: GreaterThanThreshold
Metric: ResponseLatency
```

### Step 4 — Inspect Metric Dimensions

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[0].Dimensions' \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[
  {
    "Name": "Environment",
    "Value": "Production"
  }
]
```

The dimensions are correct.

### Step 5 — Inspect Evaluation Settings

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Period:Period,EvaluationPeriods:EvaluationPeriods,DatapointsToAlarm:DatapointsToAlarm,TreatMissingData:TreatMissingData}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

| Property | Value |
|---|---|
| Period | 60 |
| EvaluationPeriods | 1 |
| DatapointsToAlarm | 1 |
| TreatMissingData | missing |

### Step 6 — Verify Current Metric Data

```bash
export START_TIME=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: recent 900-millisecond datapoints.

### Step 7 — Verify Publisher

```bash
ps -p "$(cat lab06-publisher.pid)" -o pid,stat,cmd
```

If the publisher finished, restart it:

```bash
nohup bash ./publish-high-latency.sh \
  > lab06-publisher.log 2>&1 &

echo $! > lab06-publisher.pid
```

### Investigation Matrix

| Investigation | Expected Finding |
|---|---|
| Custom Metric | Available |
| Metric Namespace | Correct |
| Metric Dimensions | Correct |
| Metric Publishing | Working |
| Average Latency | 900 ms |
| Statistic | Average |
| Evaluation Period | 60 seconds |
| Comparison Operator | Correct |
| Threshold | Incorrect |
| Alarm State | OK |
| Root Cause | Threshold too high |

---

## 11. Capture Before-Remediation Evidence

### Step 1 — Save Alarm Configuration

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab06-before-alarm.json
```

### Step 2 — Save Alarm History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab06-before-history.json
```

### Step 3 — Save Metric Data

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab06-before-metric-data.json
```

### Evidence Summary

| Evidence File | Purpose |
|---|---|
| lab06-metric-data.json | Confirms custom metric publication |
| lab06-before-alarm.json | Captures incorrect threshold |
| lab06-before-history.json | Captures alarm state history |
| lab06-before-metric-data.json | Confirms high latency during the incident |

Evidence files should contain actual AWS CLI responses.

---

## 12. Root Cause Analysis

### Root Cause

The CloudWatch alarm failed to detect high API response latency because it was configured with an incorrect threshold.

The company's required performance limit was 500 milliseconds.

However, the alarm was configured with a threshold of 2,000 milliseconds.

When the application published latency datapoints of 900 milliseconds, CloudWatch evaluated those values against the configured threshold.

Since 900 milliseconds was below 2,000 milliseconds, the alarm remained in the `OK` state.

The namespace, dimensions, metric publishing, statistic, and comparison operator were correct.

The incorrect threshold was the primary cause.

### Root Cause Flow

```text
API Response Latency
          |
          v
Metric Value = 900 ms
          |
          v
CloudWatch Metric Published
          |
          v
CloudWatch Alarm Evaluation
          |
          v
Configured Threshold = 2000 ms
          |
          v
900 > 2000?
          |
          v
         NO
          |
          v
Alarm State = OK
          |
          v
Performance Issue Not Detected
```

### Five Whys

1. **Why did the alarm not trigger?** The evaluated metric did not exceed the configured threshold.
2. **Why was the configured threshold too high?** It was set to 2,000 milliseconds.
3. **Why was 2,000 milliseconds incorrect?** The required performance threshold was 500 milliseconds.
4. **Why was the mistake not detected?** The alarm configuration had not been validated against the intended performance requirement.
5. **How was the issue resolved?** The threshold was corrected to 500 milliseconds and the alarm was tested with breaching datapoints.

### Root Cause Summary

| Component | Finding |
|---|---|
| AWS Service | Amazon CloudWatch |
| Incident | INC-CW-006 |
| Metric Publishing | Working |
| Namespace | Correct |
| Dimensions | Correct |
| Statistic | Average |
| Simulated Latency | 900 ms |
| Required Threshold | 500 ms |
| Configured Threshold | 2,000 ms |
| Alarm State Before | OK |
| Root Cause | Threshold misconfiguration |
| Remediation | Correct threshold |
| Expected State After | ALARM |

**Key Lesson:** A CloudWatch alarm can appear healthy while failing to detect an actual performance issue if its threshold does not match the application's operational requirements.

---

## 13. Remediation — Correct Alarm Threshold

### Step 1 — Update CloudWatch Alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Lab06 - Correct latency threshold of 500ms" \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold "$CORRECT_THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data missing \
  --no-actions-enabled \
  --region "$AWS_REGION"
```

This updates the existing alarm.

In production, preserve all intended alarm actions and evaluation settings when updating its configuration.

### Step 2 — Verify Corrected Threshold

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,Threshold:Threshold,State:StateValue}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

```text
Threshold: 500
```

The alarm may remain in its previous state until CloudWatch evaluates the updated configuration.

### Step 3 — Publish Fresh High Latency

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$ENVIRONMENT}],Value=900,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

### Step 4 — Monitor Alarm Recovery

```bash
for attempt in $(seq 1 18); do

  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "ALARM" ]; then
    echo "SUCCESS: High latency detected"
    break
  fi

  sleep 10

done
```

Expected after successful evaluation:

```text
ALARM
SUCCESS: High latency detected
```

If the alarm does not transition, verify that recent metric datapoints are available and the high-latency publisher is still running.

### Step 5 — Inspect Alarm State Reason

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{State:StateValue,Reason:StateReason,Threshold:Threshold}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: `ALARM`, with a state reason indicating that the evaluated latency exceeds 500 milliseconds.

---

## 14. Verify Alarm Recovery

### Step 1 — Inspect Alarm State

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Threshold:Threshold}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

```text
Alarm State: ALARM
Threshold: 500
```

### Step 2 — Inspect State History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-records 10 \
  --output table \
  --region "$AWS_REGION"
```

Look for the transition from `OK` to `ALARM`.

### Step 3 — Save Corrected Alarm Evidence

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab06-after-alarm.json
```

### Step 4 — Save Updated History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab06-after-history.json
```

### Step 5 — Refresh Metric Time Range

```bash
export START_TIME=$(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ)

export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 6 — Save Recovery Metric Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab06-after-metric-data.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| Metric Publisher | Working | Working |
| Namespace | Correct | Correct |
| Dimensions | Correct | Correct |
| API Latency | 900 ms | 900 ms |
| Required Limit | 500 ms | 500 ms |
| Configured Threshold | 2,000 ms | 500 ms |
| Statistic | Average | Average |
| Comparison Operator | GreaterThanThreshold | GreaterThanThreshold |
| Alarm State | OK | ALARM |
| High Latency Detected | No | Yes |
| Incident | Active | Resolved |

### Final Verification Criteria

The incident is resolved when:

1. The custom metric publishes successfully.
2. The metric contains recent high-latency datapoints.
3. The alarm namespace and dimensions match the metric.
4. The alarm threshold is corrected to 500 milliseconds.
5. The alarm evaluates 900-millisecond latency as breaching.
6. The alarm transitions to `ALARM`.
7. Alarm history records the state transition.
8. The corrected configuration and metric data are saved as evidence.

---

## 15. Optional Recovery Test — Return Alarm to OK

This optional exercise verifies that the alarm can recover when the simulated API latency returns to normal.

### Step 1 — Stop High-Latency Publisher

```bash
if [ -f lab06-publisher.pid ]; then
  kill "$(cat lab06-publisher.pid)" 2>/dev/null || true
  rm -f lab06-publisher.pid
fi
```

Verify that the publisher has stopped.

### Step 2 — Create Normal-Latency Publisher

Save as `publish-normal-latency.sh`:

```bash
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
```

### Step 3 — Start Normal-Latency Publisher

```bash
chmod +x publish-normal-latency.sh

nohup bash ./publish-normal-latency.sh \
  > lab06-normal-publisher.log 2>&1 &

echo $! > lab06-normal-publisher.pid
```

### Step 4 — Monitor Alarm Recovery

```bash
for attempt in $(seq 1 24); do

  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "OK" ]; then
    echo "SUCCESS: Latency recovered"
    break
  fi

  sleep 10

done
```

Expected: `OK` after CloudWatch evaluates a normal-latency period.

### Why Might Recovery Take Time?

CloudWatch may still be evaluating an earlier period containing 900-millisecond datapoints.

The alarm can return to `OK` after a recent evaluated period contains nonbreaching data.

After all publishers stop, the alarm may eventually return to `INSUFFICIENT_DATA` because no new datapoints are being published.

This is expected with `TreatMissingData=missing`.

---

## 16. Production Troubleshooting Best Practices

### Alarm Threshold Troubleshooting Checklist

1. Verify the alarm exists.
2. Inspect the alarm's current state.
3. Review the alarm state reason.
4. Inspect alarm history.
5. Verify metric publishing.
6. Confirm the AWS Region.
7. Check the metric namespace.
8. Verify the metric name.
9. Compare metric dimensions.
10. Retrieve actual datapoints.
11. Inspect the configured threshold.
12. Compare the threshold with business requirements.
13. Verify the comparison operator.
14. Check the statistic.
15. Inspect evaluation periods.
16. Review DatapointsToAlarm.
17. Check missing-data treatment.
18. Correct the threshold.
19. Publish controlled test datapoints.
20. Verify the alarm transitions correctly.

### Common Alarm Threshold Problems

| Symptom | Possible Cause |
|---|---|
| High latency but alarm OK | Threshold too high |
| Alarm always ALARM | Threshold too low |
| Unexpected alarm state | Wrong comparison operator |
| Short spikes not detected | Average instead of Maximum |
| Alarm triggers too frequently | Evaluation too sensitive |
| Alarm detection delayed | Long evaluation window |
| Alarm has no data | Namespace or dimension mismatch |
| Alarm intermittently changes state | Sparse metric publishing |
| No alarm notification | Notification configuration issue |
| Metric values unexpected | Incorrect units or statistic |

### Prevention

- Define thresholds from documented performance requirements.
- Validate alarm thresholds before production deployment.
- Manage alarms through Infrastructure as Code.
- Use peer review for monitoring changes.
- Test alarms with controlled metric values.
- Verify both breaching and nonbreaching behavior.
- Document alarm evaluation settings.
- Monitor metric availability.
- Review alarms when application performance requirements change.
- Avoid interpreting `OK` as proof that every business requirement is satisfied.

---

## 17. Operational and Security Recommendations

### Service-Level Objectives

Alarm thresholds should reflect meaningful performance objectives.

For example, an API may require response latency below a defined limit for a specified proportion of requests.

### Statistic Selection

Different statistics detect different performance problems.

`Average` is useful for overall performance trends.

`Maximum` can identify large individual spikes.

Percentile statistics may be more appropriate when monitoring user-experienced latency distributions.

### Evaluation Sensitivity

An alarm configured with one evaluation period and one datapoint to alarm can respond quickly, but it may also be sensitive to short spikes.

Production systems may use M-out-of-N evaluation to reduce unnecessary notifications.

### Monitoring as Code

Use Terraform, CloudFormation, or another controlled deployment mechanism to maintain CloudWatch alarm configurations.

### Change Validation

After changing an alarm, verify that it responds to both breaching and nonbreaching test data.

A successful configuration update alone does not prove that an alarm behaves correctly.

### Security

Use appropriately scoped IAM permissions for CloudWatch configuration changes.

Avoid enabling real notification or remediation actions during synthetic tests unless the test explicitly requires them.

---

## 18. AWS Resource Cleanup

**Warning:** Verify the temporary alarm and local publisher processes before deleting resources.

### Step 1 — Stop High-Latency Publisher

```bash
if [ -f lab06-publisher.pid ]; then
  kill "$(cat lab06-publisher.pid)" 2>/dev/null || true
  rm -f lab06-publisher.pid
fi
```

### Step 2 — Stop Normal-Latency Publisher

```bash
if [ -f lab06-normal-publisher.pid ]; then
  kill "$(cat lab06-normal-publisher.pid)" 2>/dev/null || true
  rm -f lab06-normal-publisher.pid
fi
```

### Step 3 — Verify Publishing Processes

```bash
pgrep -af 'publish-high-latency.sh|publish-normal-latency.sh' || true
```

If any publisher remains, inspect its PID and stop the process.

### Step 4 — Retrieve AWS Account ID

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)
```

### Step 5 — Construct Alarm ARN

```bash
export ALARM_ARN="arn:aws:cloudwatch:$AWS_REGION:$ACCOUNT_ID:alarm:$ALARM_NAME"
```

### Step 6 — Verify Alarm Tags

```bash
aws cloudwatch list-tags-for-resource \
  --resource-arn "$ALARM_ARN" \
  --region "$AWS_REGION"
```

Confirm:

`Project=CloudWatch-Troubleshooting-Lab06`

### Step 7 — Delete CloudWatch Alarm

```bash
aws cloudwatch delete-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$AWS_REGION"
```

### Step 8 — Verify Alarm Deletion

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms' \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[]
```

### Step 9 — Understand Metric Retention

CloudWatch does not provide an API to delete individual metric series.

After the Bash publishers stop, no new datapoints should be generated by this lab.

Historical metric data remains subject to CloudWatch's retention periods.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Alarm | Deleted |
| High-Latency Publisher | Stopped |
| Normal-Latency Publisher | Stopped |
| New Metric Publishing | Stopped |
| Historical Metric Data | Expires normally |
| EC2 Instances Created | None |
| VPC Resources Created | None |
| IAM Roles Created | None |
| Alarm Notifications | Disabled during lab |

---

## 19. Interview Questions and Answers

### Q1. What is a CloudWatch alarm threshold?

A numerical value used to determine whether an evaluated metric breaches a specified condition.

### Q2. What caused this lab's incident?

The alarm threshold was set to 2,000 milliseconds even though the required performance limit was 500 milliseconds.

### Q3. Why did the alarm remain OK during high latency?

The 900-millisecond latency datapoints were below the incorrectly configured 2,000-millisecond threshold.

### Q4. What does GreaterThanThreshold mean?

The evaluated metric must be greater than the configured threshold to be considered breaching.

### Q5. What is the difference between Average and Maximum?

Average calculates the mean value over a period.

Maximum returns the highest value recorded during that period.

### Q6. What is EvaluationPeriods?

The number of periods CloudWatch considers when evaluating an alarm.

### Q7. What is DatapointsToAlarm?

The number of breaching datapoints required within the evaluation periods.

### Q8. What is an M-out-of-N alarm?

An alarm that requires a defined number of breaching datapoints within a larger evaluation window.

### Q9. How do you inspect an alarm threshold?

```bash
aws cloudwatch describe-alarms \
  --alarm-names YOUR_ALARM_NAME \
  --query 'MetricAlarms[].Threshold'
```

### Q10. How can you test alarm functionality?

Publish controlled metric datapoints, inspect the alarm state, and review alarm history.

### Q11. Can a CloudWatch alarm show OK while the application is experiencing problems?

Yes. An incorrect threshold, statistic, or other alarm configuration can prevent the alarm from identifying a real operational problem.

### Q12. Why should alarm thresholds be reviewed against business requirements?

Because the alarm's technical configuration must reflect the performance or reliability conditions that the organization intends to monitor.

### Q13. What is the difference between Lab 05 and Lab 06?

Lab 05 investigates an alarm with missing matching datapoints due to incorrect metric dimensions.

Lab 06 investigates an alarm that receives valid datapoints but evaluates them against an incorrect threshold.

### Q14. How would you explain this lab in an interview?

I created a custom CloudWatch metric to simulate API response latency.

I used a Bash script and AWS CLI to continuously publish latency datapoints of 900 milliseconds.

The company's performance requirement was 500 milliseconds, but I intentionally configured the CloudWatch alarm with a threshold of 2,000 milliseconds.

Although the latency violated the performance requirement, the alarm remained in the `OK` state.

I investigated the alarm configuration, state reason, metric statistics, comparison operator, evaluation periods, and alarm history.

I identified the incorrect threshold as the root cause.

I updated the threshold to 500 milliseconds and continued publishing high-latency datapoints.

After CloudWatch evaluated the corrected configuration, the alarm transitioned to `ALARM`.

I also tested recovery using normal latency values and then deleted the temporary CloudWatch resources.

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
│   ├── README.md
│   ├── publish-high-latency.sh
│   ├── publish-normal-latency.sh
│   ├── lab06-metric-data.json
│   ├── lab06-before-alarm.json
│   ├── lab06-before-history.json
│   ├── lab06-before-metric-data.json
│   ├── lab06-after-alarm.json
│   ├── lab06-after-history.json
│   └── lab06-after-metric-data.json
│
├── 07-alarm-notification-not-delivered/
├── 08-cloudwatch-logs-retention-misconfiguration/
├── 09-metric-filter-not-matching/
└── 10-cloudwatch-logs-insights-investigation/
```

### File Descriptions

| File | Purpose |
|---|---|
| `README.md` | Complete troubleshooting documentation |
| `publish-high-latency.sh` | Publishes synthetic 900 ms latency |
| `publish-normal-latency.sh` | Publishes synthetic 150 ms latency |
| `lab06-metric-data.json` | Initial metric verification |
| `lab06-before-alarm.json` | Captures incorrect threshold and initial state |
| `lab06-before-history.json` | Captures alarm history before remediation |
| `lab06-before-metric-data.json` | Captures high latency during the incident |
| `lab06-after-alarm.json` | Captures corrected alarm configuration and state |
| `lab06-after-history.json` | Captures alarm state transition |
| `lab06-after-metric-data.json` | Confirms metric data after remediation |

### Local Temporary Files

The following may be generated during testing:

```text
lab06-publisher.log
lab06-publisher.pid
lab06-normal-publisher.log
lab06-normal-publisher.pid
```

Do not commit temporary PID files to GitHub.

Publisher logs may be retained as optional evidence after reviewing them.

### Evidence Guidelines

Evidence should come from actual AWS CLI outputs.

Do not fabricate alarm states, timestamps, or metric values.

If the expected `OK` or `ALARM` transition was not observed, document the actual result and troubleshooting performed rather than reporting an unverified success.

Review evidence for AWS account identifiers before publishing it.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how an incorrect CloudWatch alarm threshold can prevent the detection of a real application performance problem.

We created a custom CloudWatch metric named `ResponseLatency`.

We used a Bash script to publish synthetic API latency datapoints of 900 milliseconds.

The company's intended performance threshold was 500 milliseconds.

However, we intentionally configured the CloudWatch alarm with a threshold of 2,000 milliseconds.

Although the metric was publishing successfully, the alarm remained in the `OK` state because the evaluated latency was below the incorrectly configured threshold.

We investigated the problem using AWS CLI to inspect the alarm threshold, state reason, history, metric statistics, comparison operator, evaluation periods, and dimensions.

We confirmed that the metric publishing configuration was correct.

We identified the alarm threshold as the root cause.

After updating the threshold to 500 milliseconds, we continued publishing high-latency datapoints and verified the expected `ALARM` transition.

We also included an optional test to confirm the alarm can return to `OK` when latency becomes normal.

Finally, we stopped the Bash publishers and deleted the temporary CloudWatch alarm.

**Key Lesson:** An alarm reporting `OK` does not always mean an application is healthy. Engineers must verify that alarm thresholds, statistics, comparison operators, and evaluation settings match the actual performance and reliability requirements.

### Skills Demonstrated

- Amazon CloudWatch
- CloudWatch custom metrics
- CloudWatch alarm configuration
- CloudWatch alarm thresholds
- CloudWatch alarm states
- Alarm state history
- CloudWatch PutMetricData
- CloudWatch PutMetricAlarm
- CloudWatch DescribeAlarms
- CloudWatch DescribeAlarmHistory
- CloudWatch GetMetricStatistics
- Metric namespaces
- Metric dimensions
- Average statistics
- Comparison operators
- Evaluation periods
- DatapointsToAlarm
- Missing-data treatment
- Bash scripting
- Background process management
- AWS CLI v2
- Root cause analysis
- Monitoring configuration remediation
- Alarm verification
- Resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-006 |
| Scenario | Alarm Threshold Misconfiguration |
| Custom Metric | ResponseLatency |
| Metric Namespace | CloudWatchLab06/API |
| Metric Dimension | Environment=Production |
| Simulated High Latency | 900 ms |
| Required Threshold | 500 ms |
| Incorrect Threshold | 2,000 ms |
| Initial Alarm State | OK |
| Root Cause | Threshold too high |
| Remediation | Correct threshold to 500 ms |
| Corrected Alarm State | ALARM |
| Optional Recovery State | OK |
| Metric Publishing | Verified |
| Alarm Deletion | Completed during cleanup |
| Historical Metric Data | Retained until normal expiration |
| Incident Status | Resolved after verification |

**Key Takeaway:** CloudWatch alarm reliability depends on configuring thresholds that match operational requirements. A correctly published metric can still produce ineffective monitoring if the alarm uses an incorrect threshold. Engineers should test alarm behavior using controlled breaching and nonbreaching datapoints before relying on alarms in production.

---

## Official AWS Documentation

- [Amazon CloudWatch Alarm Evaluation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-evaluation.html)
- [AWS CLI — PutMetricAlarm](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html)
- [AWS CLI — DescribeAlarms](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarms.html)
- [AWS CLI — DescribeAlarmHistory](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarm-history.html)
- [AWS CLI — GetMetricStatistics](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-statistics.html)
- [AWS — Publishing Custom Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html)