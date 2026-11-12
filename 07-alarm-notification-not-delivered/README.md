# Lab 07 — CloudWatch Alarm Notification Not Delivered

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch alarm that enters the `ALARM` state but fails to deliver email notifications through Amazon Simple Notification Service (SNS).

We create a custom CloudWatch metric named `ResponseLatency` to simulate API response latency.

The metric is published under the namespace `CloudWatchLab07/API`, with the dimension `Environment=Lab07`.

We configure a CloudWatch alarm to detect when average API latency exceeds 500 milliseconds.

The alarm uses an Amazon SNS topic to send email notifications to the operations team.

However, we intentionally leave the SNS email subscription in the `PendingConfirmation` state.

When we publish latency datapoints of 900 milliseconds, the CloudWatch alarm successfully enters `ALARM`.

Although the alarm is functioning and its SNS action is enabled, the notification is not delivered to the unconfirmed email subscriber.

We investigate the issue using AWS CLI, CloudWatch alarm state history, alarm action history, SNS topic attributes, subscription status, and direct SNS publishing tests.

After identifying the pending email subscription as the root cause, we confirm the subscription and verify that it becomes active.

We then publish a direct SNS test message to validate email delivery.

Finally, we generate a fresh CloudWatch alarm transition and verify the complete notification path from CloudWatch to SNS to the subscriber's email inbox.

After testing, we remove the temporary alarm, SNS subscription, and SNS topic.

**Troubleshooting Workflow:**

Custom Metric Creation → SNS Topic Creation → Unconfirmed Subscription → CloudWatch Alarm Configuration → ALARM State → Notification Not Delivered → AWS CLI Investigation → Root Cause Analysis → Subscription Confirmation → SNS Delivery Test → Fresh Alarm Transition → Notification Verification → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-007 |
| Difficulty | Intermediate |
| AWS Region | `us-east-1` |
| AWS Services | Amazon CloudWatch, Amazon SNS |
| Local Environment | WSL Ubuntu |
| Interface | AWS CLI v2 |
| Scripting Language | Bash |
| Metric Namespace | `CloudWatchLab07/API` |
| Metric Name | `ResponseLatency` |
| Metric Dimension | `Environment=Lab07` |
| Metric Unit | Milliseconds |
| Simulated High Latency | 900 ms |
| Simulated Normal Latency | 150 ms |
| Alarm Threshold | 500 ms |
| Alarm Name | `cloudwatch-lab07-latency-alarm` |
| SNS Topic Name | `cloudwatch-lab07-alerts` |
| SNS Topic Type | Standard |
| SNS Subscription Protocol | Email |
| Statistic | Average |
| Evaluation Period | 60 seconds |
| Evaluation Periods | 1 |
| Datapoints to Alarm | 1 |
| Comparison Operator | GreaterThanThreshold |
| Missing Data Treatment | missing |
| Alarm Actions | Enabled |
| Fault Injection | SNS email subscription not confirmed |
| Expected Failure | Alarm enters ALARM but subscriber receives no notification |
| Root Cause | PendingConfirmation subscription |
| Remediation | Confirm SNS subscription |
| Verification | SNS direct test and new ALARM transition |

---

## 2. Production Incident Scenario

### Incident Description

A company operates a payment API and monitors its performance using Amazon CloudWatch.

The company's Cloud Operations team configures a CloudWatch alarm to detect high API response latency.

When the average response time exceeds 500 milliseconds, CloudWatch should enter the `ALARM` state and send a notification to the on-call engineer through Amazon SNS.

During a performance incident, API response latency increases to approximately 900 milliseconds.

CloudWatch correctly detects the threshold breach and changes the alarm state to `ALARM`.

However, the on-call engineer does not receive the expected notification email.

The Cloud Engineer begins investigating the alerting system.

The engineer verifies that the application metric is published successfully, the alarm threshold is correct, the alarm actions are enabled, and the configured SNS topic exists.

The CloudWatch alarm action history is inspected to determine whether the SNS notification action was executed.

Further investigation reveals that the SNS email subscription is still in the `PendingConfirmation` state.

Because the subscription was never confirmed, SNS cannot deliver normal notification messages to the intended email endpoint.

The engineer confirms the subscription, tests direct SNS delivery, and creates a fresh CloudWatch alarm state transition.

The notification path is then verified again.

### Incident Symptoms

- CloudWatch custom metrics are publishing successfully.
- API latency exceeds the configured threshold.
- CloudWatch alarm enters `ALARM`.
- Alarm actions are enabled.
- The correct SNS topic is configured.
- SNS topic exists.
- Email subscription exists.
- Subscription is in `PendingConfirmation`.
- No CloudWatch alarm notification reaches the subscriber through the pending subscription.
- The original SNS confirmation request may be present in the mailbox.
- Confirming the subscription alone does not replay the earlier alarm notification.

### Business Impact

- On-call engineers may miss critical infrastructure alerts.
- Application performance incidents may remain unnoticed.
- Incident response may be delayed.
- Customer-facing service issues may last longer.
- Monitoring dashboards may show alarms that are not communicated to responders.
- Operational teams may incorrectly assume that a CloudWatch `ALARM` state guarantees notification delivery.
- Alerting reliability is reduced.

### Objective

Determine why an alarm that correctly enters `ALARM` fails to deliver its email notification, restore the SNS subscription, and verify the complete CloudWatch-to-SNS notification path.

---

## 3. AWS Architecture

### Monitoring and Notification Architecture

```text
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
                       CloudWatch Alarm
                           |
                           v
                  Latency Threshold > 500ms
                           |
                           v
                       ALARM State
                           |
                           v
                    AlarmActions Enabled
                           |
                           v
                       SNS Topic
                 cloudwatch-lab07-alerts
                           |
                           v
                     Email Subscription
                           |
                           v
                     On-Call Engineer
```

### Architecture Before Remediation

```text
Bash Metric Publisher
          |
          v
ResponseLatency = 900ms
          |
          v
CloudWatch Alarm
          |
          v
Threshold Breached
          |
          v
ALARM State
          |
          v
SNS Alarm Action
          |
          v
Amazon SNS Topic
          |
          v
Email Subscription
          |
          v
PendingConfirmation
          |
          v
Notification Not Delivered
```

### Architecture After Remediation

```text
Bash Metric Publisher
          |
          v
ResponseLatency = 900ms
          |
          v
CloudWatch Alarm
          |
          v
New ALARM State Transition
          |
          v
SNS Alarm Action
          |
          v
Amazon SNS Topic
          |
          v
Confirmed Email Subscription
          |
          v
SNS Notification Delivery
          |
          v
On-Call Engineer Inbox
```

### Architecture Components

| Component | Purpose |
|---|---|
| WSL Ubuntu | Runs AWS CLI and Bash scripts |
| Bash Metric Publisher | Generates synthetic latency datapoints |
| CloudWatch Metrics | Stores response latency |
| CloudWatch Alarm | Detects high latency |
| AlarmActions | Identifies the SNS notification topic |
| Amazon SNS Topic | Receives and distributes notification messages |
| SNS Email Subscription | Connects the topic to an email recipient |
| Subscription Confirmation | Activates delivery to the recipient |
| Alarm History | Records CloudWatch state transitions and actions |

No EC2 instance or VPC infrastructure is required.

---

## 4. Understanding CloudWatch Alarm Notifications

### What Is Amazon CloudWatch?

Amazon CloudWatch is a monitoring and observability service that collects metrics, logs, and operational information.

CloudWatch alarms can monitor metrics and execute configured actions when alarm states change.

### What Is Amazon SNS?

Amazon Simple Notification Service is a managed messaging service that uses a publish-subscribe model.

SNS topics distribute messages to subscribed endpoints.

Supported delivery protocols include email, HTTPS, Amazon SQS, AWS Lambda, and other supported integrations.

### What Is an SNS Topic?

An SNS topic is a communication channel where messages are published.

This lab creates:

`cloudwatch-lab07-alerts`

### What Is an SNS Subscription?

A subscription connects an SNS topic to an endpoint.

In this lab, the endpoint is an email address controlled by the person performing the exercise.

### What Is PendingConfirmation?

`PendingConfirmation` indicates that the endpoint has not completed the required confirmation process.

For an email subscription, SNS sends a confirmation request to the recipient.

The recipient must confirm the subscription before ordinary SNS notifications can be delivered.

### What Is a Confirmed Subscription?

A confirmed subscription has completed the required verification process and is active for message delivery.

When listing subscriptions, a confirmed subscription normally shows a full subscription ARN rather than `PendingConfirmation`.

### What Is AlarmActions?

`AlarmActions` identifies the actions CloudWatch should execute when an alarm enters the `ALARM` state.

In this lab, it contains the ARN of the SNS topic.

### What Is ActionsEnabled?

`ActionsEnabled` determines whether the alarm can execute configured actions.

The value must be `true` for the alarm to perform its configured SNS notification action.

### Does an ALARM State Guarantee Email Delivery?

No.

An alarm state indicates the outcome of CloudWatch metric evaluation.

Notification delivery is a separate process.

An alarm can enter `ALARM` even when its notification action fails or its downstream email subscription is unconfirmed.

### Does SNS Publish Success Guarantee Delivery?

No.

A successful SNS publish request indicates that SNS accepted the message.

It does not necessarily prove that the subscriber received an email.

### Does Subscription Confirmation Replay Previous Messages?

No.

Confirming an email subscription does not automatically replay earlier CloudWatch alarm notifications.

A new alarm transition is normally needed to generate another standard alarm notification.

### Why Is This Important?

Cloud Engineers must verify the entire alerting pipeline rather than stopping after confirming the CloudWatch alarm state.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- CloudWatch metric publishing permissions
- CloudWatch alarm management permissions
- SNS topic creation permissions
- SNS subscription management permissions
- SNS publishing permissions
- An accessible email inbox
- Git and GitHub

### Security Rules

- Use a dedicated lab SNS topic.
- Do not modify production alarms or topics.
- Use a test email address you control.
- Do not subscribe another person without permission.
- Do not store private email addresses in GitHub.
- Do not commit AWS credentials.
- Use synthetic monitoring data.
- Review AWS CLI evidence before publishing.
- Verify ownership before deleting resources.
- Clean up SNS and CloudWatch resources after testing.

### Cost Considerations

Potential charges include:

- CloudWatch custom metrics
- CloudWatch alarm usage
- Amazon SNS requests and applicable delivery charges

No EC2 instances, EBS volumes, or VPC resources are required.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab07"

export NAMESPACE="CloudWatchLab07/API"
export METRIC_NAME="ResponseLatency"
export ENVIRONMENT="Lab07"

export ALARM_NAME="cloudwatch-lab07-latency-alarm"
export SNS_TOPIC_NAME="cloudwatch-lab07-alerts"

export THRESHOLD="500"
export HIGH_LATENCY="900"
export NORMAL_LATENCY="150"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$NAMESPACE"
echo "$METRIC_NAME"
echo "$ALARM_NAME"
echo "$SNS_TOPIC_NAME"
```

### Step 4 — Configure Test Email Address

```bash
read -rp "Enter your test notification email: " SNS_EMAIL
```

Verify:

```bash
echo "$SNS_EMAIL"
```

Use an email address you control.

Do not hardcode the email address in the public repository.

---

## 7. Create Amazon SNS Topic

### Step 1 — Create SNS Topic

```bash
export SNS_TOPIC_ARN=$(aws sns create-topic \
  --name "$SNS_TOPIC_NAME" \
  --tags "Key=Project,Value=$PROJECT_TAG" \
  --query TopicArn \
  --output text \
  --region "$AWS_REGION")

echo "$SNS_TOPIC_ARN"
```

Expected ARN format:

```text
arn:aws:sns:us-east-1:ACCOUNT_ID:cloudwatch-lab07-alerts
```

### Step 2 — Verify SNS Topic Attributes

```bash
aws sns get-topic-attributes \
  --topic-arn "$SNS_TOPIC_ARN" \
  --region "$AWS_REGION"
```

This displays attributes associated with the SNS topic.

### Step 3 — Verify Topic Tags

```bash
aws sns list-tags-for-resource \
  --resource-arn "$SNS_TOPIC_ARN" \
  --region "$AWS_REGION"
```

Expected project tag:

`Project=CloudWatch-Troubleshooting-Lab07`

### Step 4 — Verify Topic ARN

```bash
echo "$SNS_TOPIC_ARN"
```

Save the ARN in the existing terminal environment because it will be used in the CloudWatch alarm configuration.

---

## 8. Fault Injection — Unconfirmed SNS Subscription

### Step 1 — Create Email Subscription

```bash
aws sns subscribe \
  --topic-arn "$SNS_TOPIC_ARN" \
  --protocol email \
  --notification-endpoint "$SNS_EMAIL" \
  --region "$AWS_REGION"
```

Expected response:

```json
{
  "SubscriptionArn": "pending confirmation"
}
```

The actual subscription status may be displayed with different capitalization depending on the AWS API response.

### Step 2 — Leave Subscription Unconfirmed

SNS sends a confirmation request to the specified mailbox.

Do not confirm the subscription during fault injection.

This is the intentional misconfiguration.

### Step 3 — List Subscriptions

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --output json \
  --region "$AWS_REGION"
```

Expected: one email subscription with a pending confirmation status.

### Step 4 — Inspect Subscription Status

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Subscriptions[].{Protocol:Protocol,Status:SubscriptionArn}' \
  --output table \
  --region "$AWS_REGION"
```

Expected:

```text
Protocol: email
Status: PendingConfirmation
```

### Step 5 — Save Initial Subscription Evidence

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Subscriptions[].{Protocol:Protocol,Status:SubscriptionArn}' \
  --output json \
  --region "$AWS_REGION" \
  > lab07-before-subscription.json
```

This command avoids including the subscriber's email endpoint in the saved evidence.

### Fault Injection Summary

| Component | Expected Finding |
|---|---|
| SNS Topic | Created |
| SNS Subscription | Created |
| Protocol | Email |
| Subscriber Confirmation | Not completed |
| Subscription Status | PendingConfirmation |
| Normal Email Delivery | Not active |
| Root Cause Introduced | Unconfirmed subscription |

---

## 9. Create Bash Metric Publisher

### Step 1 — Create Publisher Script

Save as `publish-latency.sh`:

```bash
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
```

### Step 2 — Make Script Executable

```bash
chmod +x publish-latency.sh
```

### Step 3 — Verify Script

```bash
cat publish-latency.sh
```

### Step 4 — Start High-Latency Publishing

```bash
nohup bash ./publish-latency.sh 900 30 \
  > lab07-high-latency.log 2>&1 &

echo $! > lab07-publisher.pid
```

The publisher sends 30 synthetic 900-millisecond latency samples, approximately one every ten seconds.

### Step 5 — Verify Publisher Process

```bash
ps -p "$(cat lab07-publisher.pid)" -o pid,stat,cmd
```

### Step 6 — Inspect Publisher Logs

```bash
tail -n 10 lab07-high-latency.log
```

Expected example:

```text
Publishing sample 1/30: 900ms
Publishing sample 2/30: 900ms
```

If the publisher finishes before alarm verification, restart it when needed.

---

## 10. Verify Custom Metric Publication

### Step 1 — Discover Custom Metric

```bash
aws cloudwatch list-metrics \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --region "$AWS_REGION"
```

Expected: the `ResponseLatency` metric becomes discoverable.

New custom metrics may take several minutes to appear in metric discovery results.

### Step 2 — Configure Query Time Range

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

Expected: datapoints with an average of 900 milliseconds for periods containing only the simulated high-latency samples.

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
  > lab07-metric-data.json
```

### Expected Findings

| Component | Expected Result |
|---|---|
| Namespace | CloudWatchLab07/API |
| Metric | ResponseLatency |
| Dimension | Environment=Lab07 |
| Metric Publishing | Working |
| High Latency | 900 ms |
| Threshold | 500 ms |
| Metric Datapoints | Available |

---

## 11. Create CloudWatch Alarm with SNS Action

### Step 1 — Create CloudWatch Alarm

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name "$ALARM_NAME" \
  --alarm-description "Lab07 - API latency notification test" \
  --namespace "$NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=Environment,Value=$ENVIRONMENT" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 1 \
  --datapoints-to-alarm 1 \
  --threshold "$THRESHOLD" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data missing \
  --alarm-actions "$SNS_TOPIC_ARN" \
  --actions-enabled \
  --tags "Key=Project,Value=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

### Step 2 — Verify Alarm Configuration

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{Name:AlarmName,ActionsEnabled:ActionsEnabled,AlarmActions:AlarmActions,State:StateValue}' \
  --output json \
  --region "$AWS_REGION"
```

Expected:

- The alarm exists.
- `ActionsEnabled` is `true`.
- The SNS topic ARN is present.
- The alarm references the correct metric.

### Step 3 — Monitor Alarm State

```bash
for attempt in $(seq 1 18); do

  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "ALARM" ]; then
    echo "CloudWatch alarm triggered"
    break
  fi

  sleep 10

done
```

Expected: the alarm transitions to `ALARM` after evaluating high-latency datapoints.

### Step 4 — Verify Alarm State

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{State:StateValue,Reason:StateReason}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: `ALARM`.

### Step 5 — Check Subscriber Mailbox

Do not confirm the subscription yet.

The original SNS subscription confirmation request may be visible.

However, normal CloudWatch alarm notifications are not delivered through an unconfirmed subscription.

### Step 6 — Verify Subscription Remains Pending

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Subscriptions[].{Protocol:Protocol,Status:SubscriptionArn}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: `PendingConfirmation`.

---

## 12. Investigate Notification Delivery

### Check 1 — Verify Alarm State History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --max-records 10 \
  --output table \
  --region "$AWS_REGION"
```

Look for a state transition into `ALARM`.

### Check 2 — Inspect Alarm Action History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type Action \
  --max-records 10 \
  --output json \
  --region "$AWS_REGION"
```

Inspect whether CloudWatch attempted or successfully executed the SNS alarm action.

A successful CloudWatch-to-SNS action does not prove email delivery.

### Check 3 — Verify Alarm Actions

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --query 'MetricAlarms[].{State:StateValue,ActionsEnabled:ActionsEnabled,AlarmActions:AlarmActions,Threshold:Threshold}' \
  --output json \
  --region "$AWS_REGION"
```

Verify:

- The alarm is in `ALARM`.
- The alarm action is enabled.
- The SNS topic ARN is correct.
- The threshold is correct.

### Check 4 — Inspect SNS Topic Attributes

```bash
aws sns get-topic-attributes \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Attributes.{TopicArn:TopicArn,SubscriptionsConfirmed:SubscriptionsConfirmed,SubscriptionsPending:SubscriptionsPending}' \
  --output table \
  --region "$AWS_REGION"
```

Expected for a fresh topic:

```text
SubscriptionsConfirmed: 0
SubscriptionsPending: 1
```

### Check 5 — Verify Subscription Status

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Subscriptions[].{Protocol:Protocol,Status:SubscriptionArn}' \
  --output json \
  --region "$AWS_REGION"
```

Expected: `PendingConfirmation`.

### Check 6 — Verify Topic Ownership

```bash
aws sns list-tags-for-resource \
  --resource-arn "$SNS_TOPIC_ARN" \
  --region "$AWS_REGION"
```

Confirm that the topic belongs to Lab 07.

### Investigation Matrix

| Investigation | Expected Finding |
|---|---|
| CloudWatch Metric | Available |
| Metric Publishing | Working |
| Alarm Threshold | Correct |
| Alarm State | ALARM |
| Alarm Actions | Enabled |
| SNS Topic | Exists |
| Topic ARN | Correct |
| Subscription Protocol | Email |
| Confirmed Subscribers | 0 |
| Pending Subscribers | 1 |
| Subscription Status | PendingConfirmation |
| Notification Delivery | Not active for pending endpoint |
| Root Cause | Unconfirmed SNS subscription |

---

## 13. Capture Before-Remediation Evidence

### Step 1 — Save Alarm Configuration

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab07-before-alarm.json
```

### Step 2 — Save Alarm State History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --output json \
  --region "$AWS_REGION" \
  > lab07-before-state-history.json
```

### Step 3 — Save Alarm Action History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type Action \
  --output json \
  --region "$AWS_REGION" \
  > lab07-before-action-history.json
```

### Step 4 — Save SNS Topic Subscriber Counts

```bash
aws sns get-topic-attributes \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Attributes.{SubscriptionsConfirmed:SubscriptionsConfirmed,SubscriptionsPending:SubscriptionsPending}' \
  --output json \
  --region "$AWS_REGION" \
  > lab07-before-sns-attributes.json
```

### Evidence Summary

| Evidence File | Purpose |
|---|---|
| lab07-metric-data.json | Confirms metric publishing |
| lab07-before-subscription.json | Confirms pending email subscription |
| lab07-before-alarm.json | Shows alarm state and action configuration |
| lab07-before-state-history.json | Records initial alarm transitions |
| lab07-before-action-history.json | Records alarm action execution |
| lab07-before-sns-attributes.json | Shows confirmed and pending subscriber counts |

Do not fabricate AWS results.

Evidence should come from actual AWS CLI responses.

---

## 14. Root Cause Analysis

### Root Cause

The CloudWatch alarm successfully detected high API response latency and entered the `ALARM` state.

The alarm was correctly configured to send notifications to an Amazon SNS topic.

However, the intended email subscription was still in `PendingConfirmation`.

Because the endpoint had not confirmed the SNS subscription, it was not active for regular SNS email delivery.

Consequently, the on-call engineer could not receive the CloudWatch alarm notification through that pending subscription.

The incident was not caused by missing metric data, an incorrect alarm threshold, or a disabled alarm action.

The failure occurred downstream of CloudWatch, at the SNS subscription layer.

### Root Cause Flow

```text
API Latency = 900 ms
          |
          v
CloudWatch Metric Published
          |
          v
CloudWatch Alarm
          |
          v
Threshold Breached
          |
          v
ALARM State
          |
          v
AlarmActions Enabled
          |
          v
SNS Notification Action
          |
          v
Amazon SNS Topic
          |
          v
Email Subscription
          |
          v
PendingConfirmation
          |
          v
Email Notification Not Delivered
```

### Five Whys

1. **Why was the notification not delivered?** The SNS email endpoint was not an active subscriber.
2. **Why was the subscriber inactive?** Its confirmation had not been completed.
3. **Why did the topic have no confirmed email recipient?** The confirmation link was not accepted.
4. **Why didn't the alarm's ALARM state guarantee delivery?** Alarm evaluation and email delivery are separate systems.
5. **How was the issue resolved?** The subscription was confirmed and the notification path was tested again.

### Root Cause Summary

| Component | Finding |
|---|---|
| Incident | INC-CW-007 |
| AWS Services | CloudWatch, SNS |
| Metric Publishing | Working |
| Alarm Evaluation | Working |
| Alarm State | ALARM |
| Alarm Actions | Enabled |
| SNS Topic | Available |
| SNS Subscription | PendingConfirmation |
| Email Delivery | Unavailable to pending subscriber |
| Root Cause | Unconfirmed SNS email subscription |
| Remediation | Confirm subscription |
| Final Verification | Direct SNS test and fresh ALARM transition |

**Key Lesson:** An alarm entering `ALARM` does not guarantee an email notification reaches its intended recipient. Engineers must verify the downstream SNS subscription and delivery path.

---

## 15. Remediation — Confirm SNS Subscription

### Step 1 — Open Confirmation Email

Open the mailbox specified during SNS subscription creation.

Locate the Amazon SNS subscription confirmation request.

Check the spam or junk folder if necessary.

### Step 2 — Confirm Subscription

Use the confirmation link in the SNS email.

Only confirm subscriptions that you intentionally created and recognize.

### Step 3 — Verify Subscription ARN

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Subscriptions[].{Protocol:Protocol,SubscriptionArn:SubscriptionArn}' \
  --output table \
  --region "$AWS_REGION"
```

Expected: the subscription displays a complete ARN instead of `PendingConfirmation`.

### Step 4 — Verify Subscriber Counts

```bash
aws sns get-topic-attributes \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Attributes.{Confirmed:SubscriptionsConfirmed,Pending:SubscriptionsPending}' \
  --output table \
  --region "$AWS_REGION"
```

Expected for one subscription:

```text
Confirmed: 1
Pending: 0
```

### Step 5 — Save Corrected SNS Evidence

```bash
aws sns get-topic-attributes \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Attributes.{Confirmed:SubscriptionsConfirmed,Pending:SubscriptionsPending}' \
  --output json \
  --region "$AWS_REGION" \
  > lab07-after-sns-attributes.json
```

### Step 6 — Publish Direct SNS Test Message

```bash
aws sns publish \
  --topic-arn "$SNS_TOPIC_ARN" \
  --subject "CloudWatch Lab07 SNS Delivery Test" \
  --message "This is a test message to verify that the SNS email subscription is confirmed." \
  --region "$AWS_REGION"
```

Expected: SNS returns a message identifier.

### Step 7 — Verify Test Email

Check the subscriber's email inbox.

Confirm receipt of the direct SNS test message.

A successful SNS publish response alone does not prove that the email reached the mailbox.

### Remediation Summary

| Component | Before | After |
|---|---|---|
| SNS Topic | Available | Available |
| Subscription Status | PendingConfirmation | Confirmed |
| Confirmed Subscribers | 0 | 1 |
| Pending Subscribers | 1 | 0 |
| Direct SNS Publishing | Topic can accept messages | Topic can accept messages |
| Direct Email Delivery | Not available to pending subscriber | Verified if received |
| Notification Path | Incomplete | Ready for alarm retest |

---

## 16. Verify CloudWatch Alarm Notification Recovery

### Why a Fresh Alarm Transition Is Required

CloudWatch normally executes standard SNS alarm actions when the alarm transitions into the `ALARM` state.

If the alarm is already in `ALARM`, confirming an SNS subscription does not automatically replay the previous notification.

We therefore return the alarm to `OK` and generate a new threshold breach.

### Step 1 — Stop High-Latency Publisher

```bash
if [ -f lab07-publisher.pid ]; then
  kill "$(cat lab07-publisher.pid)" 2>/dev/null || true
  rm -f lab07-publisher.pid
fi
```

Verify:

```bash
pgrep -af 'publish-latency.sh' || true
```

### Step 2 — Start Normal-Latency Publishing

```bash
nohup bash ./publish-latency.sh 150 30 \
  > lab07-normal-latency.log 2>&1 &

echo $! > lab07-publisher.pid
```

The publisher now sends 150-millisecond samples.

### Step 3 — Monitor Alarm Return to OK

```bash
for attempt in $(seq 1 24); do

  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "OK" ]; then
    echo "Alarm returned to OK"
    break
  fi

  sleep 10

done
```

Expected: the alarm enters `OK` after evaluating normal latency data.

### Step 4 — Stop Normal Publisher

```bash
if [ -f lab07-publisher.pid ]; then
  kill "$(cat lab07-publisher.pid)" 2>/dev/null || true
  rm -f lab07-publisher.pid
fi
```

### Step 5 — Publish High Latency Again

```bash
nohup bash ./publish-latency.sh 900 30 \
  > lab07-recovery-high-latency.log 2>&1 &

echo $! > lab07-publisher.pid
```

### Step 6 — Monitor New ALARM Transition

```bash
for attempt in $(seq 1 24); do

  STATE=$(aws cloudwatch describe-alarms \
    --alarm-names "$ALARM_NAME" \
    --query 'MetricAlarms[0].StateValue' \
    --output text \
    --region "$AWS_REGION")

  echo "Check $attempt: $STATE"

  if [ "$STATE" = "ALARM" ]; then
    echo "New ALARM transition detected"
    break
  fi

  sleep 10

done
```

Expected: the alarm returns to `ALARM` after evaluating high latency.

### Step 7 — Verify Alarm Email

Check the email inbox.

Look for a CloudWatch alarm notification delivered through the SNS topic.

Verify that it identifies the intended alarm and the transition to `ALARM`.

### Step 8 — Inspect Alarm Action History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type Action \
  --max-records 10 \
  --output table \
  --region "$AWS_REGION"
```

Look for the notification action associated with the new state transition.

### Step 9 — Save Corrected Alarm Evidence

```bash
aws cloudwatch describe-alarms \
  --alarm-names "$ALARM_NAME" \
  --output json \
  --region "$AWS_REGION" \
  > lab07-after-alarm.json
```

### Step 10 — Save Updated State History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type StateUpdate \
  --output json \
  --region "$AWS_REGION" \
  > lab07-after-state-history.json
```

### Step 11 — Save Updated Action History

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name "$ALARM_NAME" \
  --history-item-type Action \
  --output json \
  --region "$AWS_REGION" \
  > lab07-after-action-history.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| Metric Publishing | Working | Working |
| Alarm Threshold | Correct | Correct |
| CloudWatch Alarm | Enters ALARM | Enters ALARM |
| Alarm Actions | Enabled | Enabled |
| SNS Topic | Available | Available |
| Email Subscription | PendingConfirmation | Confirmed |
| Direct SNS Test | Not deliverable to pending subscriber | Email received if verified |
| Alarm Email | Not delivered | Delivered if verified |
| Root Cause | Unconfirmed subscription | Corrected |
| Incident | Active | Resolved after delivery verification |

### Final Verification Criteria

The incident is resolved when:

1. The CloudWatch alarm evaluates high latency successfully.
2. Alarm actions are enabled.
3. The correct SNS topic ARN is configured.
4. The email subscription is confirmed.
5. SNS shows a confirmed subscriber.
6. A direct SNS test email is received.
7. The CloudWatch alarm transitions from `OK` into `ALARM` again.
8. Alarm action history shows the new notification attempt or successful action.
9. The CloudWatch alarm email is received.
10. The corrected configuration and evidence are documented.

---

## 17. Production Troubleshooting Best Practices

### Notification Troubleshooting Checklist

1. Verify the CloudWatch metric exists.
2. Confirm the metric is publishing recent datapoints.
3. Check that the alarm enters `ALARM`.
4. Inspect the alarm state reason.
5. Review state history.
6. Verify `ActionsEnabled=true`.
7. Inspect the configured `AlarmActions`.
8. Verify the SNS topic ARN.
9. Confirm the SNS topic exists.
10. Review the SNS topic policy when necessary.
11. List topic subscriptions.
12. Check subscription confirmation status.
13. Verify the recipient endpoint.
14. Inspect alarm action history.
15. Send a direct SNS test message.
16. Confirm direct email delivery.
17. Generate a fresh alarm state transition.
18. Verify the alarm notification is received.
19. Document the root cause.
20. Remove temporary test resources.

### Common Notification Delivery Problems

| Symptom | Possible Cause |
|---|---|
| Alarm enters ALARM but no email | Unconfirmed SNS subscription |
| Alarm action is missing | AlarmActions not configured |
| Alarm action is disabled | ActionsEnabled is false |
| CloudWatch action fails | SNS topic policy or access issue |
| Topic has zero confirmed subscribers | No active email endpoints |
| Direct SNS message arrives, alarm message does not | Alarm action or state transition issue |
| Subscription confirmed but email missing | Mail filtering or delivery issue |
| Notification doesn't repeat | Alarm remains in the same state |
| Wrong person receives alerts | Incorrect SNS endpoint |
| Alarm notification goes to another topic | Incorrect topic ARN |

### Production Recommendations

- Confirm SNS subscriptions during setup.
- Validate notification destinations before deployment.
- Test alarm state transitions after configuration changes.
- Verify email delivery instead of relying only on CloudWatch state.
- Keep SNS topics and subscription endpoints documented.
- Review CloudWatch alarm action history during incidents.
- Monitor notification delivery failures where supported.
- Use Infrastructure as Code for SNS and CloudWatch resources.
- Review alarm notification changes through pull requests.
- Avoid relying on a single untested notification channel for critical alerts.

---

## 18. AWS Resource Cleanup

**Warning:** Verify that resources belong to Lab 07 before deleting them.

### Step 1 — Stop Metric Publisher

```bash
if [ -f lab07-publisher.pid ]; then
  kill "$(cat lab07-publisher.pid)" 2>/dev/null || true
  rm -f lab07-publisher.pid
fi
```

### Step 2 — Verify Publisher Processes

```bash
pgrep -af 'publish-latency.sh' || true
```

Inspect and stop any remaining lab publisher.

### Step 3 — Retrieve AWS Account ID

```bash
export ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account \
  --output text)
```

### Step 4 — Construct CloudWatch Alarm ARN

```bash
export ALARM_ARN="arn:aws:cloudwatch:$AWS_REGION:$ACCOUNT_ID:alarm:$ALARM_NAME"
```

### Step 5 — Verify Alarm Tags

```bash
aws cloudwatch list-tags-for-resource \
  --resource-arn "$ALARM_ARN" \
  --region "$AWS_REGION"
```

Confirm:

`Project=CloudWatch-Troubleshooting-Lab07`

### Step 6 — Delete CloudWatch Alarm

```bash
aws cloudwatch delete-alarms \
  --alarm-names "$ALARM_NAME" \
  --region "$AWS_REGION"
```

### Step 7 — Verify Alarm Deletion

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

### Step 8 — Inspect SNS Subscriptions

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query 'Subscriptions[].{Protocol:Protocol,SubscriptionArn:SubscriptionArn}' \
  --output table \
  --region "$AWS_REGION"
```

### Step 9 — Retrieve Confirmed Subscription ARN

```bash
export SUBSCRIPTION_ARN=$(aws sns list-subscriptions-by-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --query "Subscriptions[?Protocol=='email'].SubscriptionArn | [0]" \
  --output text \
  --region "$AWS_REGION")

echo "$SUBSCRIPTION_ARN"
```

Confirm that the subscription ARN belongs to the email subscription you created for Lab 07.

### Step 10 — Delete SNS Subscription

Only execute this after verifying the subscription ARN:

```bash
aws sns unsubscribe \
  --subscription-arn "$SUBSCRIPTION_ARN" \
  --region "$AWS_REGION"
```

### Step 11 — Verify SNS Topic Ownership

```bash
aws sns list-tags-for-resource \
  --resource-arn "$SNS_TOPIC_ARN" \
  --region "$AWS_REGION"
```

Confirm the Lab 07 project tag.

### Step 12 — Delete SNS Topic

```bash
aws sns delete-topic \
  --topic-arn "$SNS_TOPIC_ARN" \
  --region "$AWS_REGION"
```

### Step 13 — Verify SNS Topic Deletion

```bash
aws sns list-topics \
  --query "Topics[?TopicArn=='${SNS_TOPIC_ARN}']" \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[]
```

### CloudWatch Metric Cleanup

CloudWatch does not provide a direct API for deleting individual custom metric series.

After the Bash publisher stops, the lab no longer generates new datapoints.

Previously published metric data remains subject to CloudWatch retention policies.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Alarm | Deleted |
| SNS Subscription | Deleted |
| SNS Topic | Deleted |
| Bash Metric Publisher | Stopped |
| New Metric Publishing | Stopped |
| Historical Metric Data | Expires normally |
| EC2 Instances | None created |
| VPC Resources | None created |
| IAM Roles | None created |

---

## 19. Interview Questions and Answers

### Q1. Why might a CloudWatch alarm enter ALARM without sending an email?

Possible causes include a missing alarm action, disabled actions, an incorrect SNS topic, an unconfirmed subscription, topic permissions, or downstream email delivery problems.

### Q2. What caused this lab's notification failure?

The SNS email subscription remained in `PendingConfirmation`.

### Q3. What is Amazon SNS?

Amazon Simple Notification Service is a managed messaging service used to publish messages to subscribed endpoints.

### Q4. What is an SNS topic?

A communication channel that receives messages and distributes them to subscribers.

### Q5. What is an SNS subscription?

A connection between an SNS topic and a destination endpoint.

### Q6. What does PendingConfirmation mean?

The endpoint has not completed the confirmation process required to activate the subscription.

### Q7. How do you check SNS subscription status?

```bash
aws sns list-subscriptions-by-topic \
  --topic-arn YOUR_TOPIC_ARN
```

### Q8. What is AlarmActions?

The list of actions CloudWatch should execute when an alarm enters the `ALARM` state.

### Q9. What does ActionsEnabled mean?

It determines whether the alarm's configured actions are allowed to execute.

### Q10. Does confirming an SNS subscription resend an earlier CloudWatch alarm notification?

No. A fresh alarm state transition is normally required.

### Q11. How do you inspect CloudWatch alarm action history?

```bash
aws cloudwatch describe-alarm-history \
  --alarm-name YOUR_ALARM_NAME \
  --history-item-type Action
```

### Q12. Does an SNS MessageId prove that an email was delivered?

No. It confirms that SNS accepted the message for publishing.

Actual email receipt must be verified separately.

### Q13. How do you isolate an SNS problem from a CloudWatch alarm problem?

Send a direct test message to the SNS topic.

If that message is received, investigate the CloudWatch alarm action and state transition separately.

### Q14. Why might a CloudWatch alarm not send another notification while remaining in ALARM?

Standard SNS alarm actions are normally triggered by alarm state transitions rather than repeated continuously while the state remains unchanged.

### Q15. How would you explain this lab in an interview?

I created a CloudWatch alarm to monitor simulated API response latency and configured an Amazon SNS topic for email notifications.

I intentionally left the SNS email subscription in the `PendingConfirmation` state.

When the simulated latency exceeded the alarm threshold, CloudWatch entered the `ALARM` state, but the expected email notification was not delivered.

I investigated the alarm state, action history, SNS topic attributes, and subscription status using AWS CLI.

I identified the unconfirmed email subscription as the root cause.

I confirmed the subscription and verified that SNS recognized an active subscriber.

I then published a direct SNS test message to verify email delivery.

After that, I generated a fresh CloudWatch alarm transition and verified the notification path again.

Finally, I removed the temporary CloudWatch and SNS resources and documented the troubleshooting process.

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
│   ├── README.md
│   ├── publish-latency.sh
│   ├── lab07-metric-data.json
│   ├── lab07-before-subscription.json
│   ├── lab07-before-alarm.json
│   ├── lab07-before-state-history.json
│   ├── lab07-before-action-history.json
│   ├── lab07-before-sns-attributes.json
│   ├── lab07-after-sns-attributes.json
│   ├── lab07-after-alarm.json
│   ├── lab07-after-state-history.json
│   └── lab07-after-action-history.json
│
├── 08-cloudwatch-logs-retention-misconfiguration/
├── 09-metric-filter-not-matching/
└── 10-cloudwatch-logs-insights-investigation/
```

### File Descriptions

| File | Purpose |
|---|---|
| `README.md` | Complete troubleshooting documentation |
| `publish-latency.sh` | Publishes synthetic API latency metrics |
| `lab07-metric-data.json` | Confirms metric publishing |
| `lab07-before-subscription.json` | Captures pending subscription status |
| `lab07-before-alarm.json` | Captures initial alarm configuration and state |
| `lab07-before-state-history.json` | Captures initial alarm state changes |
| `lab07-before-action-history.json` | Captures alarm action execution |
| `lab07-before-sns-attributes.json` | Captures initial SNS subscriber counts |
| `lab07-after-sns-attributes.json` | Captures confirmed subscription counts |
| `lab07-after-alarm.json` | Captures alarm state after remediation |
| `lab07-after-state-history.json` | Captures new alarm transitions |
| `lab07-after-action-history.json` | Captures notification action history after remediation |

### Temporary Local Files

```text
lab07-publisher.pid
lab07-high-latency.log
lab07-normal-latency.log
lab07-recovery-high-latency.log
```

Do not commit `.pid` files.

Publisher logs may be retained as optional evidence after reviewing their contents.

### Evidence Guidelines

All JSON evidence files should contain actual AWS CLI results.

Do not fabricate alarm states, notification results, SNS subscription status, or timestamps.

Review saved files for email addresses, AWS account identifiers, and sensitive information before publishing them.

### Suggested Git Ignore Entries

```gitignore
*.pid
*.log
__pycache__/
.venv/
```

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how a CloudWatch alarm can detect an operational problem correctly while the notification system fails to inform the intended recipient.

We created a custom CloudWatch metric named `ResponseLatency`.

We published synthetic high-latency datapoints using Bash and AWS CLI.

We configured a CloudWatch alarm to enter `ALARM` when average latency exceeded 500 milliseconds.

We also created an Amazon SNS topic and an email subscription.

However, we intentionally left the email subscription in the `PendingConfirmation` state.

When latency exceeded the threshold, the CloudWatch alarm entered `ALARM`.

The alarm action was enabled, and the SNS topic was configured.

However, the unconfirmed email subscription was not active for regular notification delivery.

We investigated the issue using CloudWatch alarm configuration, state history, alarm action history, SNS topic attributes, and subscription status.

We identified the pending subscription as the root cause.

After confirming the email subscription, we performed a direct SNS publishing test.

We then generated a fresh CloudWatch alarm transition to test the complete notification path.

Finally, we stopped the metric publisher and removed the temporary CloudWatch and SNS resources.

**Key Lesson:** Successful CloudWatch alarm evaluation does not guarantee successful notification delivery. Cloud Engineers must troubleshoot monitoring and alert delivery as separate components and verify the complete path from metric generation to the intended recipient.

### Skills Demonstrated

- Amazon CloudWatch
- Amazon SNS
- CloudWatch custom metrics
- CloudWatch alarm states
- CloudWatch alarm actions
- CloudWatch alarm state history
- CloudWatch alarm action history
- SNS topics
- SNS subscriptions
- SNS email confirmation
- PendingConfirmation troubleshooting
- SNS direct publishing tests
- Metric thresholds
- Metric namespaces
- Metric dimensions
- CloudWatch PutMetricData
- CloudWatch PutMetricAlarm
- CloudWatch DescribeAlarms
- CloudWatch DescribeAlarmHistory
- SNS CreateTopic
- SNS Subscribe
- SNS Publish
- SNS ListSubscriptionsByTopic
- SNS GetTopicAttributes
- AWS CLI v2
- Linux Bash
- Background process management
- Root cause analysis
- Monitoring notification troubleshooting
- Alarm transition verification
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-007 |
| Scenario | Alarm Notification Not Delivered |
| Metric | ResponseLatency |
| Metric Namespace | CloudWatchLab07/API |
| Metric Dimension | Environment=Lab07 |
| Alarm Threshold | 500 ms |
| Simulated High Latency | 900 ms |
| CloudWatch Alarm | ALARM |
| Alarm Actions | Enabled |
| SNS Topic | cloudwatch-lab07-alerts |
| Initial Subscription | PendingConfirmation |
| Root Cause | Unconfirmed SNS email subscription |
| Remediation | Confirm subscription |
| Corrected Subscription | Confirmed |
| Direct SNS Email | Verified if received |
| Fresh Alarm Transition | Verified if observed |
| Alarm Notification Email | Verified if received |
| Resource Cleanup | Temporary alarm and SNS resources removed |
| Incident Status | Resolved after delivery verification |

**Key Takeaway:** Reliable monitoring requires more than accurate metrics and correctly configured alarms. Engineers must also verify notification endpoints, SNS subscriptions, action execution, and actual recipient delivery. Testing the full monitoring and notification pipeline helps prevent missed alerts during production incidents.

---

## Official AWS Documentation

- [Amazon CloudWatch — Alarm Actions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/alarm-actions.html)
- [Amazon SNS — Email Notifications](https://docs.aws.amazon.com/sns/latest/dg/sns-email-notifications.html)
- [AWS CLI — SNS Subscribe](https://docs.aws.amazon.com/cli/latest/reference/sns/subscribe.html)
- [AWS CLI — List Subscriptions by Topic](https://docs.aws.amazon.com/cli/latest/reference/sns/list-subscriptions-by-topic.html)
- [AWS CLI — SNS Publish](https://docs.aws.amazon.com/cli/latest/reference/sns/publish.html)
- [AWS CLI — Describe Alarm History](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/describe-alarm-history.html)
- [AWS CLI — Put Metric Alarm](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html)
- [AWS re:Post — Troubleshooting SNS Email Notifications](https://repost.aws/knowledge-center/sns-topic-email-notifications)