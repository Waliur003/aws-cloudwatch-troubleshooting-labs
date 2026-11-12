# Lab 05 — CloudWatch Alarm Stuck in INSUFFICIENT_DATA

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch alarm that remains in the `INSUFFICIENT_DATA` state because its configured metric dimensions do not match the dimensions of the published metric.

We create a custom CloudWatch metric named `ResponseLatency` to simulate API response times.

The application metric is published under the namespace `CloudWatchLab05/API` with the dimension `Environment=Production`.

However, we intentionally create a CloudWatch alarm that monitors the same namespace and metric name but uses the incorrect dimension `Environment=Staging`.

Because CloudWatch treats each dimension combination as a separate metric identity, the alarm cannot find matching datapoints.

The alarm remains in `INSUFFICIENT_DATA` even though the application metric is being published successfully.

We investigate the problem using AWS CLI, CloudWatch alarm state history, metric queries, dimensions, evaluation periods, and missing-data settings.

After identifying the dimension mismatch, we update the alarm configuration and publish a fresh metric datapoint.

We then verify that the alarm can evaluate the correct metric and transition to `OK`.

Finally, we delete the temporary CloudWatch alarm to avoid unnecessary charges.

**Troubleshooting Workflow:**

Custom Metric Creation → Metric Publication → Incorrect Alarm Configuration → INSUFFICIENT_DATA → Alarm Investigation → Dimension Comparison → Root Cause Analysis → Alarm Remediation → State Verification → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-005 |
| Difficulty | Intermediate |
| AWS Region | `us-east-1` |
| AWS Service | Amazon CloudWatch |
| Local Environment | WSL Ubuntu |
| Interface | AWS CLI v2 |
| Metric Namespace | `CloudWatchLab05/API` |
| Metric Name | `ResponseLatency` |
| Metric Unit | Milliseconds |
| Published Dimension | `Environment=Production` |
| Incorrect Alarm Dimension | `Environment=Staging` |
| Alarm Name | `cloudwatch-lab05-latency-alarm` |
| Statistic | Average |
| Period | 60 seconds |
| Evaluation Periods | 1 |
| Datapoints to Alarm | 1 |
| Threshold | 500 milliseconds |
| Comparison Operator | GreaterThanThreshold |
| Missing Data Treatment | missing |
| Initial Alarm State | INSUFFICIENT_DATA |
| Fault Injection | Incorrect metric dimension |
| Root Cause | Metric identity mismatch |
| Remediation | Correct alarm dimensions |
| Expected Recovery | Alarm transitions to OK |
| Verification | DescribeAlarms, DescribeAlarmHistory, GetMetricStatistics |

---

## 2. Production Incident Scenario

### Incident Description

A company operates an API service and uses Amazon CloudWatch to monitor application response latency.

The operations team publishes custom latency metrics to CloudWatch and configures an alarm to detect unusually slow API responses.

The application publishes a metric named `ResponseLatency` under the namespace `CloudWatchLab05/API`.

The metric uses the dimension `Environment=Production` because it represents the production environment.

The CloudWatch alarm is supposed to monitor these production latency values and enter `ALARM` when the average latency exceeds 500 milliseconds.

However, the alarm remains in `INSUFFICIENT_DATA`.

The application is healthy, and metric publication is working.

A Cloud Engineer investigates the alarm configuration and discovers that it uses `Environment=Staging` instead of `Environment=Production`.

Because no datapoints are published for the Staging dimension, the alarm cannot evaluate the intended metric.

The engineer corrects the alarm dimensions and verifies that it receives valid datapoints.

### Incident Symptoms

- Custom metric publishing succeeds.
- Production latency datapoints are available.
- CloudWatch metric namespace is correct.
- CloudWatch metric name is correct.
- Alarm exists.
- Alarm configuration uses the wrong dimension.
- Alarm remains in `INSUFFICIENT_DATA`.
- Alarm history indicates insufficient matching data.
- Queries using the Staging dimension return no datapoints.
- Queries using the Production dimension return valid datapoints.

### Business Impact

- Production API latency is not monitored correctly.
- Performance degradation may go undetected.
- Monitoring dashboards may show incomplete information.
- CloudWatch alarm notifications may not trigger when expected.
- Engineers may incorrectly assume metric publishing has stopped.
- Incident detection becomes less reliable.
- Incorrect monitoring configurations can create operational blind spots.

### Objective

Identify why the CloudWatch alarm cannot evaluate the published metric, correct the dimension mismatch, and verify that the alarm transitions to the expected state.

---

## 3. AWS Architecture

### Monitoring Architecture

```text
                    Application Monitoring
                              |
                              v
                     AWS CLI Metric Publisher
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
                       CloudWatch Namespace
                       CloudWatchLab05/API
                              |
                              v
                           Dimension
                     Environment=Production
                              |
                              v
                        CloudWatch Alarm
                              |
                              v
                        Alarm Evaluation
                              |
                              v
                      OK / ALARM / INSUFFICIENT_DATA
```

### Architecture Before Remediation

```text
AWS CLI Metric Publisher
          |
          v
ResponseLatency
          |
          v
Environment=Production
          |
          v
Metric Datapoints Available
          |
          v
CloudWatch Alarm
          |
          v
Environment=Staging
          |
          v
Dimension Mismatch
          |
          v
No Matching Datapoints
          |
          v
INSUFFICIENT_DATA
```

### Architecture After Remediation

```text
AWS CLI Metric Publisher
          |
          v
ResponseLatency
          |
          v
Environment=Production
          |
          v
CloudWatch Alarm
          |
          v
Environment=Production
          |
          v
Matching Metric Datapoints
          |
          v
Alarm Evaluation
          |
          v
Average Latency < 500 ms
          |
          v
OK
```

### Architecture Components

| Component | Purpose |
|---|---|
| AWS CLI | Publishes metrics and investigates alarms |
| CloudWatch Metrics | Stores API response latency datapoints |
| CloudWatch Namespace | Organizes the custom metric |
| Metric Dimensions | Identifies the monitored environment |
| CloudWatch Alarm | Evaluates latency against a threshold |
| Alarm History | Records alarm configuration and state changes |
| CloudWatch API | Retrieves metrics and alarm information |

This lab does not require EC2, VPC, IAM role creation, or networking resources.

---

## 4. Understanding CloudWatch Alarm States

### What Is a CloudWatch Alarm?

A CloudWatch alarm monitors a metric or metric expression and evaluates whether it meets a configured condition.

For example, an alarm can detect when API latency exceeds 500 milliseconds.

### What Are the Three Alarm States?

| State | Meaning |
|---|---|
| OK | The evaluated metric does not satisfy the alarm condition |
| ALARM | The evaluated metric satisfies the alarm condition |
| INSUFFICIENT_DATA | CloudWatch does not have enough information to evaluate the alarm |

### What Is INSUFFICIENT_DATA?

`INSUFFICIENT_DATA` indicates that the alarm does not currently have enough usable information to determine whether the condition is breaching.

Possible causes include:

- New alarm initialization
- Missing metric datapoints
- Incorrect metric namespace
- Incorrect metric name
- Incorrect metric dimensions
- Stopped metric publishing
- Evaluation period mismatch
- Sparse metric reporting
- Missing-data configuration

### What Is a Metric Dimension?

A dimension is a name/value pair used to identify a metric series.

Example:

`Environment=Production`

A metric with `Environment=Production` is different from one with `Environment=Staging`.

### What Is an Evaluation Period?

An evaluation period is a time interval used when CloudWatch evaluates metric data.

Our alarm uses a 60-second period.

### What Are EvaluationPeriods?

`EvaluationPeriods` specifies the number of periods considered when evaluating the alarm.

This lab uses:

`EvaluationPeriods=1`

### What Is DatapointsToAlarm?

`DatapointsToAlarm` defines how many breaching datapoints are required within the evaluation periods.

This lab uses:

`DatapointsToAlarm=1`

### What Is a Threshold?

A threshold is the configured value used to determine whether a metric is breaching.

This lab uses:

`500 milliseconds`

### What Is GreaterThanThreshold?

The alarm enters `ALARM` when the evaluated metric is greater than the configured threshold, subject to evaluation and missing-data rules.

### What Is TreatMissingData?

This setting controls how missing datapoints are treated when CloudWatch needs to account for missing data during evaluation.

Common settings:

| Setting | Behavior |
|---|---|
| missing | Entirely missing data can cause INSUFFICIENT_DATA |
| notBreaching | Treats missing data as nonbreaching when required |
| breaching | Treats missing data as breaching when required |
| ignore | Retains the current alarm state when applicable |

Changing missing-data treatment does not correct an incorrect metric identity.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- CloudWatch metric publishing permissions
- CloudWatch alarm management permissions
- CloudWatch metric retrieval permissions
- Git and GitHub

### Security Rules

- Use dedicated lab metric names and namespaces.
- Do not modify production alarms.
- Do not configure real notification actions.
- Use synthetic metric values only.
- Verify alarm ownership before deletion.
- Review evidence before publishing it.
- Delete temporary alarms after testing.

### Cost Considerations

This lab can incur charges for:

- Custom CloudWatch metrics
- CloudWatch alarms

No EC2 instances, EBS volumes, VPCs, or public IPv4 addresses are required.

Metric data may remain available according to CloudWatch retention policies after the alarm is deleted.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab05"

export NAMESPACE="CloudWatchLab05/API"
export METRIC_NAME="ResponseLatency"

export ALARM_NAME="cloudwatch-lab05-latency-alarm"

export CORRECT_ENV="Production"
export WRONG_ENV="Staging"

export THRESHOLD="500"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$NAMESPACE"
echo "$METRIC_NAME"
echo "$ALARM_NAME"
echo "$CORRECT_ENV"
echo "$WRONG_ENV"
```

All commands are performed from WSL Ubuntu.

---

## 7. Publish Custom CloudWatch Metrics

### Step 1 — Understand the Metric Values

We simulate normal API response times:

| Value | Meaning |
|---|---|
| 120 ms | Normal API response |
| 160 ms | Normal API response |
| 210 ms | Normal API response |

All three values are below the 500-millisecond alarm threshold.

### Step 2 — Publish First Datapoint

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$CORRECT_ENV}],Value=120,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

Expected: successful command without output.

### Step 3 — Publish Second Datapoint

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$CORRECT_ENV}],Value=160,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

### Step 4 — Publish Third Datapoint

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$CORRECT_ENV}],Value=210,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

### Step 5 — Verify Metric Discovery

```bash
aws cloudwatch list-metrics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$CORRECT_ENV" \
  --region "$AWS_REGION"
```

Expected: the `ResponseLatency` metric becomes discoverable with the `Production` dimension.

New metrics may take several minutes to appear in `list-metrics`.

### Step 6 — Configure Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 7 — Retrieve Metric Statistics

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$CORRECT_ENV" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: numerical latency datapoints.

If all three datapoints fall within the same one-minute period, their average is approximately 163.33 milliseconds.

### Step 8 — Save Metric Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$CORRECT_ENV" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab05-metric-production.json
```

---

## 8. Fault Injection — Create Incorrect CloudWatch Alarm

### Step 1 — Create Alarm

We intentionally configure the alarm to monitor the wrong dimension.

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Lab05 - Incorrect Environment dimension" \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$WRONG_ENV" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold "$THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data missing \
  --no-actions-enabled \
  --tags "Key=Project,Value=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

### Intentional Misconfiguration

Published metric:

`Environment=Production`

Alarm configuration:

`Environment=Staging`

Because the dimension values differ, the alarm monitors a separate metric identity.

### Step 2 — Verify Alarm Creation

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Metric:MetricName,Namespace:Namespace}' \
  --output table \
  --region "$AWS_REGION"
```

Expected after evaluation:

`INSUFFICIENT_DATA`

### Step 3 — Inspect Alarm Configuration

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION"
```

Verify that the dimensions contain:

```json
[
  {
    "Name": "Environment",
    "Value": "Staging"
  }
]
```

### Step 4 — Confirm Initial Failure

The alarm should remain in `INSUFFICIENT_DATA` because no datapoints are published for its configured dimension.

### Fault Injection Summary

| Component | Expected Result |
|---|---|
| Metric Publisher | Working |
| Custom Metric | Available |
| Namespace | Correct |
| Metric Name | Correct |
| Published Dimension | Production |
| Alarm Dimension | Staging |
| Alarm Threshold | 500 ms |
| Missing Data Treatment | missing |
| Alarm State | INSUFFICIENT_DATA |

---

## 9. Investigate CloudWatch Alarm State

### Step 1 — Inspect Current Alarm State

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{State:StateValue,Reason:StateReason,Updated:StateUpdatedTimestamp}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: `INSUFFICIENT_DATA`.

### Step 2 — Inspect Alarm History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-records 10 \
  --query 'AlarmHistoryItems[].{Time:Timestamp,Summary:HistorySummary}' \
  --output table \
  --region "$AWS_REGION"
```

The output may contain state evaluation information or transitions.

### Step 3 — Inspect Alarm Dimensions

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
    "Value": "Staging"
  }
]
```

### Step 4 — Inspect Published Metric Dimensions

```bash
aws cloudwatch list-metrics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --output json \
  --region "$AWS_REGION"
```

Expected: a metric with `Environment=Production`.

### Dimension Comparison

| Property | Published Metric | Alarm |
|---|---|---|
| Namespace | CloudWatchLab05/API | CloudWatchLab05/API |
| Metric Name | ResponseLatency | ResponseLatency |
| Dimension Name | Environment | Environment |
| Dimension Value | Production | Staging |
| Data Available | Yes | No |

The dimension mismatch explains the missing alarm datapoints.

---

## 10. Investigate Metric Datapoints

### Step 1 — Refresh Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 2 — Query Incorrect Dimension

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$WRONG_ENV" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected:

```json
{
  "Label": "ResponseLatency",
  "Datapoints": []
}
```

### Step 3 — Query Correct Dimension

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$CORRECT_ENV" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: numerical datapoints.

### Step 4 — Inspect Alarm Evaluation Settings

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Period:Period,EvaluationPeriods:EvaluationPeriods,DatapointsToAlarm:DatapointsToAlarm,TreatMissingData:TreatMissingData,Threshold:Threshold,Operator:ComparisonOperator}' \
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
| Threshold | 500 |
| ComparisonOperator | GreaterThanThreshold |

The evaluation settings are appropriate for this lab.

The dimension mismatch is the root cause.

---

## 11. Capture Before-Remediation Evidence

### Step 1 — Save Alarm Configuration

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab05-before-alarm.json
```

### Step 2 — Save Alarm History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab05-before-history.json
```

### Step 3 — Save Missing Staging Datapoints

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$WRONG_ENV" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab05-before-staging-data.json
```

### Evidence Summary

| Evidence File | Purpose |
|---|---|
| lab05-metric-production.json | Proves metric publication |
| lab05-before-alarm.json | Captures incorrect alarm configuration |
| lab05-before-history.json | Captures alarm state history |
| lab05-before-staging-data.json | Shows missing datapoints for the wrong dimension |

These files should contain actual AWS CLI outputs from the lab.

---

## 12. Root Cause Analysis

### Root Cause

The CloudWatch alarm was configured with a dimension that did not match the published metric.

The publisher sent `ResponseLatency` datapoints using:

`Environment=Production`

However, the alarm monitored:

`Environment=Staging`

CloudWatch treats these as separate metric identities.

Because the Staging metric had no datapoints, the alarm could not evaluate the intended API response latency.

The alarm used `TreatMissingData=missing`, so a completely missing evaluation window could result in `INSUFFICIENT_DATA`.

### Root Cause Flow

```text
Custom Metric Publisher
          |
          v
ResponseLatency
          |
          v
Environment=Production
          |
          v
Metric Datapoints Published
          |
          v
CloudWatch Alarm
          |
          v
Environment=Staging
          |
          v
Metric Identity Mismatch
          |
          v
No Matching Datapoints
          |
          v
INSUFFICIENT_DATA
```

### Five Whys

1. **Why was the alarm in INSUFFICIENT_DATA?** It did not receive enough matching metric data.
2. **Why did it not receive matching data?** Its dimension value was incorrect.
3. **Why was the dimension incorrect?** The alarm monitored Staging instead of Production.
4. **Why does that matter?** Dimensions identify separate CloudWatch metric series.
5. **How was the issue resolved?** The alarm was updated to monitor Production.

### Root Cause Summary

| Component | Finding |
|---|---|
| AWS Service | CloudWatch |
| Incident | INC-CW-005 |
| Metric Publication | Working |
| Namespace | Correct |
| Metric Name | Correct |
| Metric Dimensions | Production |
| Alarm Dimensions | Staging |
| Alarm State | INSUFFICIENT_DATA |
| Root Cause | Dimension mismatch |
| Remediation | Update alarm dimensions |
| Infrastructure Redeployment | Not required |

**Key Lesson:** A CloudWatch alarm can remain in `INSUFFICIENT_DATA` even when a metric is being published, if the alarm references a different metric identity.

---

## 13. Remediation — Correct Alarm Dimensions

### Step 1 — Update CloudWatch Alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Lab05 - Correct Production response latency alarm" \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$CORRECT_ENV" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold "$THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data missing \
  --no-actions-enabled \
  --region "$AWS_REGION"
```

This updates the existing alarm.

In production, ensure all required configuration fields and alarm actions are preserved when updating an alarm.

### Step 2 — Verify Corrected Dimensions

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

### Step 3 — Publish Fresh Metric Data

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$CORRECT_ENV}],Value=180,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

The new datapoint is below the 500-millisecond threshold.

### Step 4 — Monitor Alarm Recovery

```bash
for attempt in $(seq 1 12); do
  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "OK" ]; then
    echo "Alarm recovered successfully"
    break
  fi

  sleep 10
done
```

Expected after successful evaluation:

```text
OK
Alarm recovered successfully
```

CloudWatch may need time to ingest and evaluate recent metric data.

If the alarm remains in `INSUFFICIENT_DATA`, publish another fresh normal datapoint and check the metric's timestamps.

---

## 14. Verify Alarm Recovery

### Step 1 — Inspect Alarm State

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,State:StateValue,Reason:StateReason}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: `OK` after a valid normal datapoint is evaluated.

### Step 2 — Inspect State History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-records 10 \
  --output table \
  --region "$AWS_REGION"
```

Look for the transition to `OK`.

### Step 3 — Save Corrected Alarm Evidence

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab05-after-alarm.json
```

### Step 4 — Save Updated Alarm History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab05-after-history.json
```

### Step 5 — Refresh Metric Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 6 — Save Recovery Metric Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$CORRECT_ENV" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab05-after-metric-data.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| Metric Publisher | Working | Working |
| Metric Namespace | Correct | Correct |
| Metric Name | Correct | Correct |
| Published Dimension | Production | Production |
| Alarm Dimension | Staging | Production |
| Matching Datapoints | No | Yes |
| Alarm State | INSUFFICIENT_DATA | OK |
| Root Cause | Dimension mismatch | Corrected |
| Incident | Active | Resolved |

### Final Verification Criteria

The incident is resolved when:

1. Production latency metrics are available.
2. The alarm references `Environment=Production`.
3. CloudWatch retrieves matching datapoints.
4. The alarm evaluates the correct metric.
5. The alarm enters `OK` after evaluating normal latency data.
6. The corrected alarm configuration is saved.
7. Alarm state history records the recovery.

---

## 15. Understanding Missing Data Treatment

CloudWatch provides several ways to handle missing metric datapoints during alarm evaluation.

| Setting | Behavior |
|---|---|
| missing | Can produce INSUFFICIENT_DATA when all required data is absent |
| notBreaching | Treats missing datapoints as nonbreaching when needed |
| breaching | Treats missing datapoints as breaching when needed |
| ignore | Retains the previous state when applicable |

### Why We Used missing

We want the alarm to clearly indicate that monitoring data is unavailable.

If we changed the configuration to `notBreaching`, the alarm could report `OK` even though the expected metric was missing.

This would hide the underlying monitoring problem.

### Important Production Lesson

Changing missing-data treatment does not fix a broken metric collection pipeline or a dimension mismatch.

Always identify the reason the alarm lacks data before modifying its evaluation behavior.

CloudWatch also evaluates available real datapoints where possible, so missing-data settings are applied according to its evaluation logic rather than acting as unconditional state assignments.

---

## 16. Optional Alarm Transition Test

This additional exercise checks whether the corrected alarm can detect high latency.

### Step 1 — Publish High Latency

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$CORRECT_ENV}],Value=900,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

The value is above the 500-millisecond threshold.

### Step 2 — Inspect Alarm State

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{State:StateValue,Reason:StateReason}' \
  --output table \
  --region "$AWS_REGION"
```

An `ALARM` state is possible if the evaluated one-minute average exceeds 500 milliseconds.

If low-latency datapoints were published during the same period, the average might remain below the threshold.

### Step 3 — Publish Normal Latency

```bash
aws cloudwatch put-metric-data \
  --namespace "$NAMESPACE" \
  --metric-data \
    "MetricName=$METRIC_NAME,Dimensions=[{Name=Environment,Value=$CORRECT_ENV}],Value=150,Unit=Milliseconds" \
  --region "$AWS_REGION"
```

The alarm can return to `OK` when the evaluated data is below the threshold.

After manual metric publishing stops, the alarm may eventually return to `INSUFFICIENT_DATA` because no new datapoints arrive.

This is expected behavior for a sparse metric using `TreatMissingData=missing`.

---

## 17. Production Troubleshooting Best Practices

### CloudWatch Alarm Troubleshooting Checklist

1. Verify the CloudWatch alarm exists.
2. Inspect the current alarm state.
3. Read the alarm state reason.
4. Review alarm state history.
5. Verify the AWS Region.
6. Check the metric namespace.
7. Check the metric name.
8. Compare metric and alarm dimensions.
9. Verify metric datapoints are being published.
10. Retrieve datapoints directly.
11. Check the alarm statistic.
12. Verify the period.
13. Verify evaluation periods.
14. Check DatapointsToAlarm.
15. Review missing-data treatment.
16. Identify the root cause.
17. Correct the alarm configuration.
18. Publish fresh test data.
19. Verify the alarm's state.
20. Document remediation and evidence.

### Common INSUFFICIENT_DATA Problems

| Symptom | Possible Cause |
|---|---|
| New alarm shows INSUFFICIENT_DATA | Initial evaluation |
| Alarm remains in INSUFFICIENT_DATA | No matching datapoints |
| Metric exists but alarm has no data | Wrong dimensions |
| Metric not found | Incorrect namespace |
| Metric stopped publishing | Application or agent issue |
| Alarm uses unexpected statistic | Configuration mismatch |
| Alarm has insufficient recent data | Sparse publishing |
| Alarm not responding to new data | Period or evaluation settings |
| Metric published in another Region | Region mismatch |
| Alarm state seems incorrect | Missing-data treatment |

### Production Recommendations

- Use consistent metric dimensions.
- Manage alarms through Infrastructure as Code.
- Review alarm configuration changes.
- Validate metric identities before creating alarms.
- Monitor the availability of telemetry.
- Avoid masking missing data without understanding the impact.
- Use meaningful alarm descriptions.
- Document alarm thresholds and operational expectations.
- Verify alarm behavior after deployment.
- Test monitoring changes before production rollout.

---

## 18. AWS Resource Cleanup

**Warning:** Verify that the alarm belongs to Lab 05 before deleting it.

### Step 1 — Retrieve AWS Account ID

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)
```

### Step 2 — Construct Alarm ARN

```bash
export ALARM_ARN="arn:aws:cloudwatch:$AWS_REGION:$ACCOUNT_ID:alarm:$ALARM_NAME"
```

### Step 3 — Verify Alarm Tags

```bash
aws cloudwatch list-tags-for-resource \
  --resource-arn "$ALARM_ARN" \
  --region "$AWS_REGION"
```

Confirm:

`Project=CloudWatch-Troubleshooting-Lab05`

### Step 4 — Delete CloudWatch Alarm

```bash
aws cloudwatch delete-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$AWS_REGION"
```

### Step 5 — Verify Alarm Deletion

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

### Step 6 — Verify Metric Publishing Has Stopped

The lab used one-time AWS CLI `PutMetricData` commands.

No continuous publisher, EC2 instance, or scheduled job was created.

No additional metric publishing process needs to be stopped.

### CloudWatch Metric Cleanup

CloudWatch does not provide a direct API to delete an individual metric series.

Previously published metric datapoints remain according to CloudWatch retention policies.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Alarm | Deleted |
| Alarm Notifications | None configured |
| Continuous Metric Publisher | None |
| New Metric Publishing | Stopped |
| Historical Metric Data | Expires normally |
| EC2 Instances Created | None |
| VPC Resources Created | None |
| IAM Roles Created | None |

---

## 19. Interview Questions and Answers

### Q1. What are the three main CloudWatch alarm states?

`OK`, `ALARM`, and `INSUFFICIENT_DATA`.

### Q2. What does INSUFFICIENT_DATA mean?

CloudWatch does not have enough usable information to evaluate the alarm's condition.

### Q3. Why might an alarm remain in INSUFFICIENT_DATA?

Possible causes include missing datapoints, wrong dimensions, incorrect namespace, stopped publishing, or evaluation configuration problems.

### Q4. What caused this lab's incident?

The metric used `Environment=Production`, but the alarm monitored `Environment=Staging`.

### Q5. What identifies a CloudWatch metric?

Namespace, metric name, and the complete dimension set.

### Q6. What does EvaluationPeriods mean?

The number of periods used when evaluating the alarm.

### Q7. What does DatapointsToAlarm mean?

The number of breaching datapoints required within the evaluation periods.

### Q8. What is TreatMissingData?

A setting that controls how missing datapoints are handled when CloudWatch needs to account for missing data during alarm evaluation.

### Q9. Can changing missing-data treatment fix a dimension mismatch?

No. The alarm must reference the correct metric identity.

### Q10. How can you inspect alarm history?

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name YOUR_ALARM_NAME
```

### Q11. What does put-metric-alarm do?

It creates a new CloudWatch metric alarm or updates an existing alarm using the supplied configuration.

### Q12. Why is it important to publish fresh datapoints after correcting the alarm?

CloudWatch alarms evaluate recent periods. Fresh datapoints help confirm that the corrected alarm receives and evaluates current monitoring data.

### Q13. Why might an alarm return to INSUFFICIENT_DATA after a successful test?

The metric publisher may have stopped sending data, leaving no recent datapoints for evaluation.

### Q14. How would you explain this lab in an interview?

I created a custom CloudWatch metric to simulate API response latency.

I published the metric using the `Environment=Production` dimension.

I intentionally configured a CloudWatch alarm to monitor `Environment=Staging`.

The metric was publishing correctly, but the alarm remained in `INSUFFICIENT_DATA`.

I investigated the alarm state, history, configuration, metric dimensions, and datapoints using AWS CLI.

I identified the dimension mismatch as the root cause.

I updated the alarm to monitor the correct Production metric, published a fresh datapoint, and verified that the alarm entered the `OK` state.

Finally, I deleted the temporary alarm and documented the troubleshooting process.

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
│   ├── README.md
│   ├── lab05-metric-production.json
│   ├── lab05-before-alarm.json
│   ├── lab05-before-history.json
│   ├── lab05-before-staging-data.json
│   ├── lab05-after-alarm.json
│   ├── lab05-after-history.json
│   └── lab05-after-metric-data.json
│
├── 06-alarm-threshold-misconfiguration/
├── 07-alarm-notification-not-delivered/
├── 08-cloudwatch-logs-retention-misconfiguration/
├── 09-metric-filter-not-matching/
└── 10-cloudwatch-logs-insights-investigation/
```

### File Descriptions

| File | Purpose |
|---|---|
| `README.md` | Complete incident documentation |
| `lab05-metric-production.json` | Confirms published Production latency metrics |
| `lab05-before-alarm.json` | Captures incorrect alarm configuration |
| `lab05-before-history.json` | Captures alarm history before remediation |
| `lab05-before-staging-data.json` | Demonstrates missing Staging datapoints |
| `lab05-after-alarm.json` | Captures corrected alarm configuration |
| `lab05-after-history.json` | Captures alarm recovery history |
| `lab05-after-metric-data.json` | Confirms corrected metric data |

### Evidence Guidelines

Evidence files should contain actual AWS CLI responses.

Do not fabricate alarm states, timestamps, or metric values.

Review files for AWS account IDs and other infrastructure identifiers before publishing them.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how a CloudWatch alarm can remain in `INSUFFICIENT_DATA` even though the required application metric is being published successfully.

We created a custom CloudWatch metric named `ResponseLatency` to simulate API response times.

The metric was published under the namespace `CloudWatchLab05/API` using the dimension `Environment=Production`.

We then intentionally created a CloudWatch alarm with the incorrect dimension `Environment=Staging`.

Because CloudWatch treats different dimension values as separate metric identities, the alarm could not retrieve matching datapoints.

The alarm remained in `INSUFFICIENT_DATA`.

We investigated the issue using AWS CLI commands to inspect alarm state, alarm history, metric dimensions, evaluation periods, and missing-data treatment.

We compared the published metric against the alarm configuration and identified the dimension mismatch as the root cause.

After updating the alarm to monitor the correct Production dimension, we published a fresh latency datapoint and verified that the alarm could evaluate the metric.

Finally, we deleted the temporary alarm.

**Key Lesson:** A CloudWatch alarm cannot evaluate a metric correctly unless its namespace, metric name, dimensions, and relevant evaluation configuration match the intended monitoring data.

### Skills Demonstrated

- Amazon CloudWatch
- CloudWatch custom metrics
- CloudWatch metric namespaces
- CloudWatch metric dimensions
- CloudWatch alarms
- Alarm state troubleshooting
- INSUFFICIENT_DATA investigation
- CloudWatch alarm history
- Alarm thresholds
- Evaluation periods
- DatapointsToAlarm
- TreatMissingData
- CloudWatch PutMetricData
- CloudWatch PutMetricAlarm
- CloudWatch DescribeAlarms
- CloudWatch DescribeAlarmHistory
- CloudWatch GetMetricStatistics
- AWS CLI v2
- Linux Bash
- Root cause analysis
- Monitoring configuration remediation
- Alarm verification
- CloudWatch resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-005 |
| Scenario | Alarm Stuck in INSUFFICIENT_DATA |
| Custom Metric | ResponseLatency |
| Metric Namespace | CloudWatchLab05/API |
| Published Dimension | Environment=Production |
| Initial Alarm Dimension | Environment=Staging |
| Initial Alarm State | INSUFFICIENT_DATA |
| Root Cause | Metric dimension mismatch |
| Remediation | Correct alarm dimensions |
| Updated Alarm Dimension | Environment=Production |
| Recovery Datapoints | Successfully evaluated |
| Expected Alarm State | OK |
| Alarm Deletion | Completed during cleanup |
| Historical Metric Data | Retained until normal expiration |
| Incident Status | Resolved after verification |

**Key Takeaway:** Effective CloudWatch alarm troubleshooting requires understanding metric identities, dimensions, alarm evaluation, and missing-data behavior. Changing the alarm state is not enough; engineers must fix the monitoring configuration and verify that real datapoints are being evaluated.

---

## Official AWS Documentation

- [Amazon CloudWatch Alarm Evaluation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-evaluation.html)
- [AWS CLI — PutMetricAlarm](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html)
- [AWS CLI — DescribeAlarms](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarms.html)
- [AWS CLI — DescribeAlarmHistory](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarm-history.html)
- [AWS CLI — GetMetricStatistics](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-statistics.html)
- [AWS re:Post — Alarm in INSUFFICIENT_DATA](https://repost.aws/knowledge-center/cloudwatch-alarm-insufficient-data-state)