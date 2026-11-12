# AWS CloudWatch Troubleshooting Labs

## Overview

This repository contains 10 hands-on Amazon CloudWatch troubleshooting labs designed to develop practical AWS Cloud Engineering, Cloud Operations, DevOps, and Cloud Security Engineering skills.

The labs simulate monitoring and observability problems that engineers may encounter in real AWS production environments.

Each lab focuses on identifying an issue, investigating its root cause using AWS CLI and Linux tools, implementing a solution, verifying recovery, and documenting the troubleshooting process.

The repository covers CloudWatch Logs, the CloudWatch Agent, EC2 metrics, custom metrics, alarms, SNS notifications, log retention, metric filters, and CloudWatch Logs Insights.

The goal is to learn how to troubleshoot AWS monitoring failures rather than simply configure CloudWatch resources.

**Troubleshooting Workflow:**

Infrastructure Setup → Fault Injection → Incident Detection → Investigation → Root Cause Analysis → Remediation → Verification → AWS Cleanup

---

## 1. Learning Objectives

After completing these labs, I will be able to:

- Troubleshoot missing CloudWatch log events.
- Investigate CloudWatch Agent installation and configuration problems.
- Diagnose missing EC2 metrics.
- Publish and investigate CloudWatch custom metrics.
- Troubleshoot CloudWatch alarm state transitions.
- Identify alarm threshold and evaluation misconfigurations.
- Investigate failed alarm notifications through Amazon SNS.
- Configure and troubleshoot CloudWatch Logs retention.
- Diagnose CloudWatch Logs metric filter patterns.
- Use CloudWatch Logs Insights to investigate application and infrastructure incidents.
- Use AWS CLI to inspect monitoring resources.
- Perform Linux service and log troubleshooting.
- Apply monitoring security and least-privilege principles.
- Document production-style incidents and remediation steps.

---

## 2. Technologies Used

| **Technology**           | **Purpose**                                   |
| ------------------------ | --------------------------------------------- |
| Amazon CloudWatch        | Monitoring and observability                  |
| CloudWatch Logs          | Centralized log collection and investigation  |
| CloudWatch Agent         | Collecting logs and OS-level metrics          |
| CloudWatch Metrics       | Monitoring infrastructure and applications    |
| CloudWatch Alarms        | Detecting metric conditions                   |
| CloudWatch Logs Insights | Querying and analyzing logs                   |
| Amazon EC2               | Simulated monitored infrastructure            |
| Amazon SNS               | Alarm notifications                           |
| AWS IAM                  | Monitoring permissions and instance roles     |
| AWS Systems Manager      | EC2 management and troubleshooting            |
| AWS CLI v2               | Resource management and investigation         |
| Linux                    | Operating system troubleshooting              |
| Bash                     | Automation and troubleshooting commands       |
| Python                   | Custom metric generation and testing          |
| JSON                     | CloudWatch Agent and monitoring configuration |
| Git and GitHub           | Version control and documentation             |

---

## 3. Repository Structure

```
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
    └── README.md

```

Each lab folder will contain its own README, supporting configuration files, scripts, and sanitized troubleshooting evidence as needed.

Individual lab documentation will be added after completing the practical troubleshooting exercise.

---

## 4. Troubleshooting Lab Roadmap

| **Lab** | **Troubleshooting Scenario**               | **Difficulty**        |
| ------- | ------------------------------------------ | --------------------- |
| 01      | CloudWatch Logs Not Appearing              | Beginner              |
| 02      | CloudWatch Agent Not Running               | Beginner              |
| 03      | EC2 Metrics Missing                        | Beginner–Intermediate |
| 04      | Custom Metric Not Publishing               | Intermediate          |
| 05      | Alarm Stuck in Insufficient Data           | Intermediate          |
| 06      | Alarm Threshold Misconfiguration           | Intermediate          |
| 07      | Alarm Notification Not Delivered           | Intermediate          |
| 08      | CloudWatch Logs Retention Misconfiguration | Intermediate          |
| 09      | Metric Filter Not Matching                 | Intermediate–Advanced |
| 10      | CloudWatch Logs Insights Investigation     | Advanced              |

---

## 5. Lab Descriptions

### Lab 01 — CloudWatch Logs Not Appearing

**Scenario:** An EC2 application generates logs locally, but the expected events are not appearing in CloudWatch Logs.

**Troubleshooting Focus:**

- CloudWatch log groups and streams.
- Log collection configuration.
- CloudWatch Agent permissions.
- IAM instance roles.
- Log ingestion errors.
- Verifying log delivery.

**Expected Outcome:** Local application logs become visible in the intended CloudWatch log group.

### Lab 02 — CloudWatch Agent Not Running

**Scenario:** A CloudWatch Agent service fails to start or stops unexpectedly.

**Troubleshooting Focus:**

- CloudWatch Agent installation.
- systemd service status.
- Agent configuration files.
- JSON configuration errors.
- Agent logs.
- Restarting and verifying the agent.

**Expected Outcome:** The CloudWatch Agent runs successfully and resumes configured telemetry collection.

### Lab 03 — EC2 Metrics Missing

**Scenario:** An engineer cannot find expected EC2 monitoring metrics.

**Troubleshooting Focus:**

- EC2 native metrics versus agent metrics.
- AWS namespaces.
- Metric dimensions.
- CloudWatch Agent configuration.
- Agent permissions.
- Metric collection intervals.
- AWS Region selection.

**Expected Outcome:** The intended EC2 and operating-system metrics are correctly identified and available for monitoring.

### Lab 04 — Custom Metric Not Publishing

**Scenario:** A Python application attempts to publish a custom metric, but the metric does not appear in CloudWatch.

**Troubleshooting Focus:**

- `PutMetricData`.
- IAM permissions.
- Metric namespaces.
- Metric names.
- Dimensions.
- Timestamps.
- AWS Region.
- Metric retrieval using AWS CLI.

**Expected Outcome:** Custom metric data is successfully published and verified.

### Lab 05 — Alarm Stuck in Insufficient Data

**Scenario:** A CloudWatch alarm remains in `INSUFFICIENT_DATA` even though monitoring has been configured.

**Troubleshooting Focus:**

- Alarm state evaluation.
- Missing metric data.
- Evaluation periods.
- Datapoints to alarm.
- Missing-data treatment.
- Metric dimensions.
- Period configuration.

**Expected Outcome:** The alarm receives valid datapoints and transitions according to its configured evaluation rules.

**Quick Investigation Checklist:**

1. Confirm the AWS Region, metric namespace, metric name, and every dimension match the alarm configuration.
2. Check whether the metric has recent datapoints in the alarm evaluation window.
3. Verify that the metric period and statistic are appropriate for the data being published.
4. Review `EvaluationPeriods`, `DatapointsToAlarm`, and `TreatMissingData` rather than assuming missing data always means a failed agent.
5. Inspect alarm state history to distinguish missing telemetry from a threshold or configuration issue.
6. After correcting the root cause, wait for enough new datapoints and verify the alarm evaluates normally.

**Useful Read-Only Commands:**

```bash
aws cloudwatch describe-alarms --alarm-names "ALARM_NAME" --region "AWS_REGION"
aws cloudwatch describe-alarm-history --alarm-name "ALARM_NAME" --region "AWS_REGION"
aws cloudwatch list-metrics --namespace "METRIC_NAMESPACE" --region "AWS_REGION"
```

Replace the quoted placeholders with the actual alarm, Region, and metric namespace. For detailed data validation, use `aws cloudwatch get-metric-data` with the exact metric dimensions and appropriate start/end times.

### Lab 06 — Alarm Threshold Misconfiguration

**Scenario:** A CloudWatch alarm does not enter the expected state because its threshold or comparison operator is incorrect.

**Troubleshooting Focus:**

- Alarm thresholds.
- Comparison operators.
- Evaluation periods.
- Alarm state history.
- Metric statistics.
- Correcting alarm definitions.
- Testing state transitions.

**Expected Outcome:** The alarm correctly evaluates the intended metric condition.

### Lab 07 — Alarm Notification Not Delivered

**Scenario:** A CloudWatch alarm enters `ALARM`, but the expected SNS notification is not received.

**Troubleshooting Focus:**

- CloudWatch alarm actions.
- Amazon SNS topics.
- SNS subscriptions.
- Subscription confirmation.
- SNS access policies.
- Delivery troubleshooting.
- Alarm history.

**Expected Outcome:** The alarm notification path is correctly configured and notification delivery is verified.

### Lab 08 — CloudWatch Logs Retention Misconfiguration

**Scenario:** CloudWatch Logs is configured with an unintended retention period.

**Troubleshooting Focus:**

- Log retention settings.
- Retention configuration.
- Cost implications.
- Log group properties.
- `PutRetentionPolicy`.
- Retention verification.
- Operational policies.

**Expected Outcome:** The log group uses the intended retention period.

### Lab 09 — Metric Filter Not Matching

**Scenario:** A CloudWatch Logs metric filter does not match the intended application log events.

**Troubleshooting Focus:**

- Metric filter syntax.
- Structured and unstructured logs.
- Filter pattern matching.
- `TestMetricFilter`.
- Metric transformations.
- Log ingestion.
- Verifying generated metrics.

**Expected Outcome:** New matching log events generate the intended CloudWatch metric data.

### Lab 10 — CloudWatch Logs Insights Investigation

**Scenario:** A production application generates errors, but engineers need to identify failure patterns and affected requests across large volumes of log data.

**Troubleshooting Focus:**

- CloudWatch Logs Insights.
- Query syntax.
- Field extraction.
- Filtering error events.
- Sorting by timestamp.
- Aggregating error counts.
- Identifying incident patterns.
- Building an evidence-based root cause analysis.

**Expected Outcome:** CloudWatch Logs Insights identifies relevant application errors and supports the incident investigation.

---

## 6. AWS Monitoring Architecture

```
                      AWS Infrastructure
                              |
                  ------------------------
                  |                      |
                  v                      v
             Amazon EC2             Applications
                  |                      |
                  v                      v
           CloudWatch Agent          Custom Metrics
                  |                      |
                  v                      v
            Logs and Metrics      PutMetricData API
                  |                      |
                  ------------------------
                              |
                              v
                       Amazon CloudWatch
                              |
             ---------------------------------
             |               |               |
             v               v               v
        CloudWatch Logs   CloudWatch      CloudWatch
                           Metrics          Alarms
             |               |               |
             v               v               v
        Logs Insights     Monitoring       Amazon SNS
             |               |               |
             v               v               v
        Log Analysis      Dashboards      Notifications
             |               |               |
             ---------------------------------
                              |
                              v
                    Incident Investigation
                              |
                              v
                      Root Cause Analysis
                              |
                              v
                          Remediation

```

This architecture demonstrates how AWS monitoring components work together to support operational visibility and incident response.

---

## 7. Troubleshooting Methodology

Each lab follows a consistent investigation process.

### Step 1 — Understand the Incident

Identify the reported symptoms, affected resources, and expected monitoring behavior.

### Step 2 — Reproduce the Problem

Create an intentional misconfiguration or failure in a disposable AWS environment.

### Step 3 — Collect Evidence

Use AWS CLI, Linux commands, logs, metrics, and resource configuration to investigate the issue.

### Step 4 — Identify the Root Cause

Determine the specific configuration, permission, process, or monitoring problem responsible for the failure.

### Step 5 — Implement Remediation

Correct the root cause without introducing unnecessary changes.

### Step 6 — Verify Recovery

Confirm that monitoring data, log events, alarm states, or notifications behave as expected.

### Step 7 — Clean Up

Delete temporary AWS resources to avoid unnecessary charges.

### Step 8 — Document the Incident

Record the incident symptoms, investigation, root cause, remediation, verification, and lessons learned.

---

## 8. AWS CLI Commands Used

### CloudWatch Logs

```
aws logs describe-log-groups
aws logs describe-log-streams
aws logs filter-log-events
aws logs get-log-events
aws logs put-retention-policy
```

### CloudWatch Metrics

```
aws cloudwatch list-metrics
aws cloudwatch get-metric-statistics
aws cloudwatch get-metric-data
aws cloudwatch put-metric-data
```

### CloudWatch Alarms

```
aws cloudwatch describe-alarms
aws cloudwatch describe-alarm-history
aws cloudwatch put-metric-alarm
aws cloudwatch delete-alarms
```

### CloudWatch Metric Filters

```
aws logs describe-metric-filters
aws logs test-metric-filter
aws logs put-metric-filter
```

### CloudWatch Logs Insights

```
aws logs start-query
aws logs get-query-results
aws logs stop-query
```

### Amazon SNS

```
aws sns list-topics
aws sns list-subscriptions
aws sns get-topic-attributes
aws sns publish
```

### EC2 and Systems Manager

```
aws ec2 describe-instances
aws ec2 describe-instance-status
aws ssm start-session
```

Commands shown here are reference examples. Each lab provides complete arguments and resource-specific configurations.

---

## 9. Linux Troubleshooting Commands

### Check CloudWatch Agent Status

```
sudo systemctl status amazon-cloudwatch-agent
```

### Inspect Agent Logs

```
sudo tail -n 50 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Inspect Service Logs

```
sudo journalctl -u amazon-cloudwatch-agent --no-pager
```

### Check Agent Processes

```
ps aux | grep amazon-cloudwatch-agent
```

### Check Local Application Logs

```
sudo tail -n 50 /var/log/myapp/application.log
```

### Search for Errors

```
grep -i "error" /var/log/myapp/application.log
```

### Inspect System Resources

```
free -h
df -h
top
```

These commands help determine whether a monitoring problem originates in AWS configuration, Linux services, or the application itself.

---

## 10. Monitoring and Observability Concepts

### Metrics

Metrics are numerical measurements collected over time.

Examples:

- CPU utilization
- Memory usage
- Disk usage
- Network traffic
- Application error counts
- Request latency

### Logs

Logs contain records of application and system events.

They provide information about errors, access requests, authentication events, and application behavior.

### Alarms

CloudWatch alarms evaluate metric data against configured conditions.

An alarm can transition between:

- `OK`
- `ALARM`
- `INSUFFICIENT_DATA`

### Log Groups

Log groups organize related log streams.

### Log Streams

Log streams contain sequences of log events from a particular source.

### Namespaces

Namespaces organize CloudWatch metrics.

Common examples:

```
AWS/EC2
AWS/RDS
AWS/ApplicationELB
CWAgent
Custom/Application

```

### Dimensions

Dimensions identify specific metric series.

Examples:

```
InstanceId
AutoScalingGroupName
Environment
ApplicationName

```

A metric with the correct namespace and name but different dimensions is a different metric series.

### Alarm Investigation: Fast Decision Guide

| **Observation** | **What to Check First** | **Likely Next Action** |
| --- | --- | --- |
| Alarm shows `INSUFFICIENT_DATA` | Recent datapoints, dimensions, period, and missing-data treatment | Correct telemetry or evaluation settings and verify new datapoints |
| Alarm remains `OK` during a known problem | Statistic, threshold, comparison operator, and evaluation periods | Correct the alarm definition and test with valid metric data |
| Alarm reaches `ALARM`, but no message arrives | Alarm actions, SNS topic, subscription confirmation, and delivery status | Repair the notification path and test delivery |
| Metric is visible but alarm uses no data | Namespace, dimensions, Region, and selected metric statistic | Make the alarm reference the intended metric series |

Treat this table as a starting point, not a substitute for examining CloudWatch alarm history and underlying metric data.

---

## 11. CloudWatch Agent vs. Native EC2 Metrics

| **Feature**                | **Native EC2 Metrics** | **CloudWatch Agent**       |
| -------------------------- | ---------------------- | -------------------------- |
| CPU Utilization            | Yes                    | Additional CPU metrics     |
| Network Traffic            | Yes                    | Additional network metrics |
| Memory Usage               | No by default          | Yes                        |
| Filesystem Usage           | No by default          | Yes                        |
| Application Logs           | No                     | Yes                        |
| Agent Installation         | Not required           | Required                   |
| Custom OS-Level Monitoring | Limited                | Supported                  |

The CloudWatch Agent allows engineers to collect operating-system and application telemetry beyond default EC2 metrics.

---

## 12. Security Best Practices

- Use IAM roles instead of static AWS credentials.
- Apply least-privilege monitoring permissions.
- Avoid publishing sensitive application data in logs.
- Use encryption for monitoring data.
- Configure appropriate log retention.
- Protect SNS notification topics and subscriptions.
- Restrict access to monitoring configurations.
- Review CloudWatch Agent permissions.
- Monitor unexpected changes to alarm configurations.
- Use dedicated monitoring resources in disposable labs.
- Remove unused metrics, alarms, and log groups after testing.

---

## 13. Cost Management

CloudWatch features can incur charges depending on usage.

Potential cost sources include:

- Log ingestion
- Log storage
- Custom metrics
- CloudWatch alarms
- Logs Insights queries
- EC2 instances
- EBS storage
- Public IPv4 addresses
- SNS messages and deliveries

Some CloudWatch log groups retain data indefinitely unless a retention policy applies.

Each lab includes cleanup instructions to prevent unnecessary resource charges.

---

## 14. Expected Evidence

Each completed lab may contain sanitized evidence such as:

```
evidence/
├── before-configuration.json
├── after-configuration.json
├── error-output.txt
├── verification-output.txt
└── screenshots/

```

Evidence should demonstrate:

1. The original problem.
2. Investigation commands and findings.
3. The identified root cause.
4. The corrected configuration.
5. Successful verification.

Do not publish AWS credentials, sensitive log contents, or confidential infrastructure information.

---

## 15. Skills Demonstrated

This repository demonstrates practical knowledge of:

- Amazon CloudWatch
- CloudWatch Logs
- CloudWatch Agent
- CloudWatch Metrics
- CloudWatch Alarms
- CloudWatch Logs Insights
- CloudWatch Metric Filters
- Amazon SNS
- AWS IAM
- Amazon EC2
- AWS Systems Manager
- Linux troubleshooting
- Bash
- Python
- AWS CLI
- Monitoring configuration
- Incident response
- Root cause analysis
- Observability
- Cloud operations
- AWS security best practices

---

## 16. Career Relevance

These labs focus on troubleshooting responsibilities relevant to several AWS infrastructure roles.

**Cloud Engineer:** Monitoring infrastructure health, investigating missing telemetry, and verifying operational visibility.

**Cloud Operations Engineer:** Diagnosing log collection failures, alarm states, and monitoring issues.

**DevOps Engineer:** Supporting application observability, custom metrics, and automated alerting.

**Cloud Security Engineer:** Investigating monitoring gaps, log retention policies, permissions, alert delivery, and security-related logging failures.

**Site Reliability Engineer:** Using metrics, alarms, and structured log investigation to diagnose and reduce production incidents.

---

## 17. Documentation Standard

Each lab README will document:

1. Overview and incident information.
2. Production incident scenario.
3. AWS architecture.
4. Learning objectives.
5. Required infrastructure.
6. AWS CLI preparation.
7. Resource deployment.
8. Intentional fault injection.
9. Symptoms and observed errors.
10. AWS CLI investigation.
11. Linux troubleshooting.
12. Root cause analysis.
13. Remediation.
14. Recovery verification.
15. Before-and-after comparison.
16. Security and operational recommendations.
17. AWS resource cleanup.
18. Interview questions.
19. Repository files and evidence.
20. Lessons learned.
21. Final outcome.

This consistent format makes the repository useful for practical learning and technical interview preparation.

---

## 18. Learning Approach

The labs are organized from easier to more advanced troubleshooting scenarios.

Each lab is performed using real AWS resources, AWS CLI commands, and Linux tools.

The practical exercise comes first.

The lab README and Git commands are added after completing the exercise.

This approach builds both hands-on troubleshooting ability and a documented GitHub portfolio.

---

## 19. Official AWS Documentation

- [Amazon CloudWatch Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/)
- [CloudWatch Logs Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [CloudWatch Agent Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [CloudWatch Alarms Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [CloudWatch Logs Insights Documentation](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/AnalyzingLogData.html)
- [AWS CLI CloudWatch Reference](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/)
- [AWS CLI CloudWatch Logs Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/)

---

## 20. Repository Goals

The goals of this repository are to:

- Build practical AWS monitoring knowledge.
- Learn systematic troubleshooting.
- Understand CloudWatch configuration and operational failures.
- Improve AWS CLI and Linux skills.
- Practice incident investigation and remediation.
- Develop cloud security monitoring knowledge.
- Create documented, reproducible troubleshooting projects.
- Prepare for Cloud Engineering and Cloud Security Engineering interviews.

---

## 21. Final Objective

By completing these 10 troubleshooting labs, I aim to understand how to diagnose and resolve common Amazon CloudWatch monitoring failures.

The repository demonstrates practical experience with centralized logging, monitoring agents, infrastructure metrics, custom telemetry, alarms, notification delivery, retention policies, metric filters, and log analysis.

**Key Takeaway:** Effective cloud monitoring requires more than enabling CloudWatch. Engineers must understand the full telemetry pipeline, identify failures in data collection and alerting, investigate the root cause, and verify that monitoring continues to work correctly after remediation.