# Lab 01 — CloudWatch Logs Not Appearing

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch Logs ingestion failure caused by missing IAM permissions on an EC2 instance.

We deploy an Amazon Linux 2023 EC2 instance inside a custom AWS VPC and configure a Bash application that continuously generates log events.

The application writes its logs to a local Linux file:

`/var/log/cloudwatch-lab01/app.log`

We install and configure the Amazon CloudWatch Agent to collect this file and publish its contents to a CloudWatch log group.

However, we intentionally configure the EC2 instance role with Systems Manager permissions only, without granting the necessary CloudWatch Logs permissions.

As a result, the application generates logs locally and the CloudWatch Agent runs, but the log events do not appear in CloudWatch.

We investigate the problem using AWS CLI, IAM role inspection, CloudWatch Agent logs, Linux systemd, and CloudWatch Logs APIs.

After identifying the missing IAM permissions, we attach the required CloudWatch Agent policy and verify that application log events are successfully delivered.

Finally, we remove the temporary AWS resources to avoid unnecessary charges.

**Troubleshooting Workflow:**

Infrastructure Setup → Application Log Generation → CloudWatch Agent Configuration → Missing IAM Permissions → Log Ingestion Failure → Investigation → Root Cause Analysis → IAM Remediation → Log Delivery Verification → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-001 |
| Difficulty | Beginner |
| AWS Region | `us-east-1` |
| AWS Services | CloudWatch Logs, EC2, IAM, VPC, Systems Manager |
| Local Environment | WSL Ubuntu |
| Operating System | Amazon Linux 2023 |
| Instance Type | `t3.micro` |
| VPC CIDR | `10.64.0.0/16` |
| Public Subnet | `10.64.1.0/24` |
| Application | Bash Log Generator |
| Application Service | `cloudwatch-lab01-app` |
| Log File | `/var/log/cloudwatch-lab01/app.log` |
| CloudWatch Agent | Amazon CloudWatch Agent |
| Log Group | `/aws/labs/cloudwatch/01/application` |
| Log Stream | EC2 Instance ID |
| Log Retention | 1 day |
| Initial IAM Policy | AmazonSSMManagedInstanceCore |
| Missing Permissions | CloudWatch Logs publishing |
| Fault Injection | Missing CloudWatch Agent IAM policy |
| Expected Failure | Logs do not appear in CloudWatch |
| Remediation | Attach CloudWatchAgentServerPolicy |
| Expected Recovery | Application logs appear in CloudWatch |
| Verification | AWS CLI, systemctl, journalctl, CloudWatch Agent logs |

---

## 2. Production Incident Scenario

### Incident Description

A company operates an application on an Amazon EC2 instance.

The application generates operational logs containing timestamps and application status messages.

The company uses Amazon CloudWatch Logs to centralize application logs for monitoring, troubleshooting, and incident investigation.

However, engineers notice that the application's log group is empty.

The application itself is running normally, and log events are present in the local Linux log file.

The CloudWatch Agent is installed and configured to collect the correct file.

Despite this, CloudWatch does not receive the events.

A Cloud Engineer is assigned to investigate the missing logs.

During troubleshooting, the engineer discovers that the EC2 instance profile is associated with an IAM role that only has Systems Manager permissions.

The role does not have permission to create CloudWatch log streams or publish log events.

Consequently, the CloudWatch Agent receives authorization errors when attempting to deliver the logs.

### Incident Symptoms

- EC2 instance is running.
- Application service is active.
- Local log file contains events.
- New log messages are continuously generated.
- CloudWatch Agent is installed.
- CloudWatch Agent service is running.
- Agent configuration references the correct log file.
- CloudWatch log group exists.
- CloudWatch log stream is missing or empty.
- Agent logs contain authorization errors.
- EC2 IAM role lacks CloudWatch Logs permissions.

### Business Impact

- Application errors are not centrally collected.
- Operations teams lose visibility into application behavior.
- Incident investigations become more difficult.
- Security monitoring may have incomplete evidence.
- CloudWatch Logs Insights cannot analyze missing events.
- Engineers may incorrectly assume the application is not producing logs.

### Objective

Identify why application logs are not being delivered to CloudWatch, correct the IAM permissions, and verify successful log ingestion without redeploying the application.

---

## 3. AWS Architecture

### Infrastructure Architecture

```text
                       AWS Region
                        us-east-1
                            |
                            v
                        Amazon VPC
                      10.64.0.0/16
                            |
                            v
                       Public Subnet
                      10.64.1.0/24
                            |
                            v
                       EC2 Instance
                    Amazon Linux 2023
                            |
                            v
                      Bash Application
                            |
                            v
                         app.log
                            |
                            v
                     CloudWatch Agent
                            |
                            v
                        IAM Role
                            |
                            v
                     CloudWatch Logs
                            |
                            v
                         Log Group
           /aws/labs/cloudwatch/01/application
                            |
                            v
                         Log Stream
                        Instance ID
                            |
                            v
                        Log Events
```

### Architecture Before Remediation

```text
EC2 Application
       |
       v
Local Application Logs
       |
       v
CloudWatch Agent
       |
       v
Attempts PutLogEvents
       |
       v
EC2 IAM Role
       |
       v
Missing CloudWatch Logs Permissions
       |
       v
AccessDeniedException
       |
       v
Log Delivery Failure
       |
       v
CloudWatch Logs Empty
```

### Architecture After Remediation

```text
EC2 Application
       |
       v
Local Application Logs
       |
       v
CloudWatch Agent
       |
       v
EC2 IAM Role
       |
       v
CloudWatchAgentServerPolicy
       |
       v
CreateLogStream / PutLogEvents
       |
       v
CloudWatch Logs
       |
       v
Application Events Available
```

### Network Configuration

| Component | Configuration |
|---|---|
| VPC | `10.64.0.0/16` |
| Public Subnet | `10.64.1.0/24` |
| Internet Gateway | Attached |
| Default Route | `0.0.0.0/0` |
| EC2 | Amazon Linux 2023 |
| EC2 Public IP | Assigned |
| Inbound SSH | Not allowed |
| EC2 Management | Systems Manager |
| CloudWatch Logs Access | Outbound HTTPS |
| Log Collection | CloudWatch Agent |

The instance uses outbound HTTPS connectivity to reach AWS service endpoints.

No inbound HTTP or SSH rules are required for this lab.

---

## 4. Understanding CloudWatch Logs

### What Is Amazon CloudWatch Logs?

Amazon CloudWatch Logs is an AWS service that stores, monitors, and analyzes log data generated by applications and infrastructure.

It allows engineers to centralize logs rather than accessing individual servers to investigate application behavior.

### What Is a Log Group?

A log group is a collection of log streams that share monitoring and retention settings.

This lab uses:

```text
/aws/labs/cloudwatch/01/application
```

### What Is a Log Stream?

A log stream contains a sequence of log events from a particular source.

In this lab, the log stream name is the EC2 instance ID.

### What Is a Log Event?

A log event is an individual log message associated with a timestamp.

Example:

```text
2026-11-10T15:00:00Z INFO CloudWatch Lab01 application is running
```

### What Is the CloudWatch Agent?

The CloudWatch Agent is software that collects logs and supported system metrics from servers.

It can collect information such as:

- Application logs
- Operating-system logs
- Memory utilization
- Disk utilization
- Selected process metrics
- Additional infrastructure metrics

### Does EC2 Automatically Send Application Logs?

No.

Amazon EC2 publishes certain native infrastructure metrics, but arbitrary application log files are not automatically uploaded to CloudWatch Logs.

A log collection mechanism must be configured.

### What Are the Main CloudWatch Logs IAM Permissions?

| IAM Permission | Purpose |
|---|---|
| `logs:CreateLogGroup` | Creates a log group when needed |
| `logs:CreateLogStream` | Creates a destination log stream |
| `logs:PutLogEvents` | Publishes log events |
| `logs:DescribeLogStreams` | Retrieves log stream information |
| `logs:DescribeLogGroups` | Retrieves log group information |

Not every workload needs every action. Permissions should be scoped to the operations and resources the agent actually requires.

### Why Can the Agent Run Without Delivering Logs?

The CloudWatch Agent is a local Linux service.

Its operating-system process can run successfully even when AWS rejects its API requests.

Therefore:

**Agent Running does not automatically mean Log Delivery Working.**

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- EC2 permissions
- VPC permissions
- IAM permissions
- CloudWatch Logs permissions
- Systems Manager access
- Git and GitHub

### Security Rules

- Use disposable lab infrastructure.
- Do not modify production IAM roles.
- Do not expose SSH to the internet.
- Use Systems Manager for EC2 access.
- Use an instance profile instead of static credentials.
- Do not commit AWS credentials.
- Avoid including sensitive application data in logs.
- Review evidence before uploading it to GitHub.
- Delete temporary AWS resources after testing.

### Cost Considerations

This lab can incur charges for:

- EC2 instance usage
- EBS storage
- Public IPv4 address
- CloudWatch Logs ingestion
- CloudWatch Logs storage

A one-day retention policy limits how long ingested log events remain stored.

Deleting the log group during cleanup removes its remaining events.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab01"

export VPC_CIDR="10.64.0.0/16"
export SUBNET_CIDR="10.64.1.0/24"

export EC2_ROLE_NAME="cloudwatch-lab01-ec2-role"
export PROFILE_NAME="cloudwatch-lab01-instance-profile"

export SG_NAME="cloudwatch-lab01-sg"

export LOG_GROUP="/aws/labs/cloudwatch/01/application"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$VPC_CIDR"
echo "$LOG_GROUP"
```

Keep the original WSL terminal open to preserve AWS resource identifiers.

---

## 7. Create VPC and Networking

### Step 1 — Create VPC

```bash
export VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications \
  "ResourceType=vpc,Tags=[{Key=Name,Value=cloudwatch-lab01-vpc},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Vpc.VpcId' \
  --output text \
  --region "$AWS_REGION")

echo "$VPC_ID"
```

### Step 2 — Enable DNS Support

```bash
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-support \
  --region "$AWS_REGION"

aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames \
  --region "$AWS_REGION"
```

### Step 3 — Select Availability Zone

```bash
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters "Name=instance-type,Values=t3.micro" \
  --query 'InstanceTypeOfferings[].Location' \
  --output table \
  --region "$AWS_REGION"
```

Choose a supported Availability Zone:

```bash
export AZ="us-east-1a"
```

### Step 4 — Create Public Subnet

```bash
export SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR" \
  --availability-zone "$AZ" \
  --tag-specifications \
  "ResourceType=subnet,Tags=[{Key=Name,Value=cloudwatch-lab01-public},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region "$AWS_REGION")
```

### Step 5 — Create Internet Gateway

```bash
export IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications \
  "ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudwatch-lab01-igw},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'InternetGateway.InternetGatewayId' \
  --output text \
  --region "$AWS_REGION")

aws ec2 attach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION"
```

### Step 6 — Create Route Table

```bash
export RT_ID=$(aws ec2 create-route-table \
  --vpc-id "$VPC_ID" \
  --tag-specifications \
  "ResourceType=route-table,Tags=[{Key=Name,Value=cloudwatch-lab01-public-rt},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'RouteTable.RouteTableId' \
  --output text \
  --region "$AWS_REGION")
```

### Step 7 — Add Internet Route

```bash
aws ec2 create-route \
  --route-table-id "$RT_ID" \
  --destination-cidr-block 0.0.0.0/0 \
  --gateway-id "$IGW_ID" \
  --region "$AWS_REGION"
```

### Step 8 — Associate Subnet

```bash
export RT_ASSOC_ID=$(aws ec2 associate-route-table \
  --route-table-id "$RT_ID" \
  --subnet-id "$SUBNET_ID" \
  --query AssociationId \
  --output text \
  --region "$AWS_REGION")
```

---

## 8. Create Security Group and IAM Resources

### Step 1 — Create Security Group

```bash
export SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "CloudWatch Lab01 EC2 no inbound access" \
  --vpc-id "$VPC_ID" \
  --tag-specifications \
  "ResourceType=security-group,Tags=[{Key=Name,Value=$SG_NAME},{Key=Project,Value=$PROJECT_TAG}]" \
  --query GroupId \
  --output text \
  --region "$AWS_REGION")

echo "$SG_ID"
```

No inbound rules are needed.

### Step 2 — Create IAM Trust Policy

Save as `ec2-trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

### Step 3 — Create IAM Role

```bash
aws iam create-role \
  --role-name "$EC2_ROLE_NAME" \
  --assume-role-policy-document file://ec2-trust-policy.json \
  --tags Key=Project,Value="$PROJECT_TAG"
```

### Step 4 — Attach Systems Manager Permissions

```bash
aws iam attach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

Do not attach CloudWatchAgentServerPolicy yet.

This missing policy is the intentional fault.

### Step 5 — Create Instance Profile

```bash
aws iam create-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --tags Key=Project,Value="$PROJECT_TAG"

aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$EC2_ROLE_NAME"
```

### Step 6 — Verify IAM Policies

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output table
```

Expected:

```text
AmazonSSMManagedInstanceCore
```

The CloudWatch Agent publishing permissions are intentionally missing.

---

## 9. Create CloudWatch Log Group

### Step 1 — Create Log Group

```bash
aws logs create-log-group \
  --log-group-name "$LOG_GROUP" \
  --tags "Project=$PROJECT_TAG" \
  --region "$AWS_REGION"
```

### Step 2 — Configure Retention

```bash
aws logs put-retention-policy \
  --log-group-name "$LOG_GROUP" \
  --retention-in-days 1 \
  --region "$AWS_REGION"
```

### Step 3 — Verify Log Group

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}'].{Name:logGroupName,Retention:retentionInDays}" \
  --output table \
  --region "$AWS_REGION"
```

Expected:

```text
Log Group: /aws/labs/cloudwatch/01/application
Retention: 1
```

The log group exists, but the application log stream has not been created yet.

---

## 10. Deploy EC2 Application

### Step 1 — Create Log Generator

Save as `app-log-generator.sh`:

```bash
#!/bin/bash

LOG_DIR="/var/log/cloudwatch-lab01"
LOG_FILE="$LOG_DIR/app.log"

mkdir -p "$LOG_DIR"

while true; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  echo "$TIMESTAMP INFO CloudWatch Lab01 application is running" \
    >> "$LOG_FILE"

  sleep 10
done
```

### Step 2 — Create EC2 User Data

Save as `user-data.sh`:

```bash
#!/bin/bash
set -euxo pipefail

dnf install -y amazon-cloudwatch-agent

mkdir -p /opt/cloudwatch-lab01
mkdir -p /var/log/cloudwatch-lab01

cat > /opt/cloudwatch-lab01/app.sh <<'APP'
#!/bin/bash

LOG_FILE="/var/log/cloudwatch-lab01/app.log"

while true; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  echo "$TIMESTAMP INFO CloudWatch Lab01 application is running" >> "$LOG_FILE"
  sleep 10
done
APP

chmod +x /opt/cloudwatch-lab01/app.sh

cat > /etc/systemd/system/cloudwatch-lab01-app.service <<'SERVICE'
[Unit]
Description=CloudWatch Lab01 Application Log Generator
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/cloudwatch-lab01/app.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now cloudwatch-lab01-app.service
```

The user data embeds the log generator directly so EC2 can initialize without downloading files from GitHub.

### Step 3 — Retrieve Amazon Linux AMI

```bash
export AMI_ID=$(aws ssm get-parameter \
  --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION")
```

### Step 4 — Launch EC2

```bash
export INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type t3.micro \
  --subnet-id "$SUBNET_ID" \
  --security-group-ids "$SG_ID" \
  --associate-public-ip-address \
  --iam-instance-profile "Name=$PROFILE_NAME" \
  --user-data file://user-data.sh \
  --metadata-options "HttpTokens=required,HttpEndpoint=enabled" \
  --tag-specifications \
  "ResourceType=instance,Tags=[{Key=Name,Value=cloudwatch-lab01-ec2},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$AWS_REGION")

echo "$INSTANCE_ID"
```

### Step 5 — Wait for EC2

```bash
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"

aws ec2 wait instance-status-ok \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 6 — Connect Through Systems Manager

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 7 — Verify Application Service

Inside EC2:

```bash
sudo systemctl status cloudwatch-lab01-app --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 8 — Verify Local Logs

```bash
sudo tail -n 10 /var/log/cloudwatch-lab01/app.log
```

Expected example:

```text
2026-11-10T15:00:00Z INFO CloudWatch Lab01 application is running
2026-11-10T15:00:10Z INFO CloudWatch Lab01 application is running
2026-11-10T15:00:20Z INFO CloudWatch Lab01 application is running
```

The actual timestamps depend on when you run the lab.

### Step 9 — Verify Continuous Logging

```bash
sudo tail -f /var/log/cloudwatch-lab01/app.log
```

Expected: a new event approximately every 10 seconds.

Press `Ctrl+C` to stop following the log file.

---

## 11. Configure CloudWatch Agent

### Step 1 — Create Agent Configuration

Inside EC2, save as `/opt/cloudwatch-lab01/cloudwatch-agent.json`:

```json
{
  "agent": {
    "region": "us-east-1",
    "debug": true
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cloudwatch-lab01/app.log",
            "log_group_name": "/aws/labs/cloudwatch/01/application",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

### Agent Configuration Explanation

| Field | Purpose |
|---|---|
| `region` | AWS destination Region |
| `debug` | Enables additional agent troubleshooting information |
| `file_path` | Local Linux log file |
| `log_group_name` | CloudWatch Logs destination |
| `log_stream_name` | EC2 instance ID |
| `timezone` | UTC timestamp interpretation |

### Step 2 — Start CloudWatch Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/cloudwatch-lab01/cloudwatch-agent.json
```

### Step 3 — Verify Agent Status

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Expected:

```json
{
  "status": "running"
}
```

Additional fields may appear.

### Step 4 — Verify systemd Service

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
```

Expected:

```text
Active: active (running)
```

At this stage, the agent is running locally but lacks the IAM permissions required to publish application logs.

---

## 12. Fault Injection — Logs Not Appearing

### Step 1 — Inspect Agent Logs

Inside EC2:

```bash
sudo tail -n 80 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

Look for:

```text
AccessDeniedException
```

Possible denied actions include:

```text
logs:CreateLogStream
logs:PutLogEvents
```

The exact error depends on the operation the CloudWatch Agent attempts.

### Step 2 — Search for Authorization Errors

```bash
sudo grep -iE \
  "AccessDenied|not authorized|CreateLogStream|PutLogEvents|permission" \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log \
  | tail -n 30
```

Expected: authorization-related messages.

### Step 3 — Verify Configuration Validation

```bash
sudo cat \
  /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
```

Expected: no fatal JSON configuration errors.

### Step 4 — Confirm Application Logs Still Exist

```bash
sudo tail -n 5 /var/log/cloudwatch-lab01/app.log
```

Expected: recent log events.

### Step 5 — Verify Agent Is Running

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Expected: running.

### Step 6 — Exit EC2

```bash
exit
```

### Expected Failure Matrix

| Investigation | Expected Result |
|---|---|
| EC2 Instance | Running |
| Application Service | Active |
| Local Log File | Exists |
| New Local Events | Present |
| CloudWatch Agent | Running |
| Agent JSON | Valid |
| IAM CloudWatch Permissions | Missing |
| CloudWatch Log Group | Exists |
| Log Stream | Missing or empty |
| CloudWatch Log Events | Not delivered |
| Agent Error | Authorization failure |

---

## 13. Troubleshooting Investigation Using AWS CLI

### Check 1 — Verify Log Group

From WSL:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}']" \
  --output json \
  --region "$AWS_REGION"
```

### Check 2 — Inspect Log Streams

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output json \
  --region "$AWS_REGION"
```

Expected: no successfully populated application log stream.

### Check 3 — Search Application Events

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"CloudWatch Lab01 application"' \
  --output json \
  --region "$AWS_REGION"
```

Expected: no matching events.

### Check 4 — Verify Instance Profile

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --output text \
  --region "$AWS_REGION"
```

### Check 5 — Verify IAM Role Policies

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output table
```

Expected:

```text
AmazonSSMManagedInstanceCore
```

The role lacks CloudWatchAgentServerPolicy.

### Check 6 — Inspect AWS-Managed Agent Policy

```bash
aws iam get-policy \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy \
  --output json
```

### Check 7 — Save IAM Evidence

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json \
  > lab01-before-iam.json
```

### Check 8 — Save Log Stream Evidence

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output json \
  --region "$AWS_REGION" \
  > lab01-before-streams.json
```

### Check 9 — Save Missing Log Evidence

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"CloudWatch Lab01 application"' \
  --output json \
  --region "$AWS_REGION" \
  > lab01-before-events.json
```

### Investigation Summary

| Component | Finding |
|---|---|
| Application | Healthy |
| Local Logs | Present |
| CloudWatch Agent | Running |
| Log Group | Exists |
| Log Collection Path | Correct |
| CloudWatch Logs Permissions | Missing |
| Root Cause | IAM authorization failure |

---

## 14. Root Cause Analysis

### Root Cause

The EC2 instance profile was associated with an IAM role that had Systems Manager permissions but lacked the permissions required to publish application logs to CloudWatch.

The application itself was functioning normally and generating log events.

The CloudWatch Agent was installed and running with a valid log collection configuration.

However, when the agent attempted to create a log stream or publish log events, AWS rejected the request because the IAM role lacked the necessary permissions.

### Root Cause Flow

```text
EC2 Application
       |
       v
Local app.log File
       |
       v
CloudWatch Agent
       |
       v
CloudWatch Logs API Request
       |
       v
IAM Authorization Evaluation
       |
       v
Required Permission Missing
       |
       v
AccessDeniedException
       |
       v
Log Delivery Failure
```

### Five Whys

1. **Why were the logs missing?** CloudWatch was not receiving application events.
2. **Why were the events not delivered?** The CloudWatch Agent's API requests were denied.
3. **Why were the API requests denied?** The EC2 IAM role lacked CloudWatch Logs permissions.
4. **Why did local logging continue?** Local file writing does not require AWS CloudWatch authorization.
5. **How was the problem resolved?** The necessary CloudWatch Agent permissions were attached to the IAM role.

### Root Cause Summary

| Component | Finding |
|---|---|
| AWS Service | CloudWatch Logs |
| Incident | INC-CW-001 |
| Application | Healthy |
| Local Logging | Working |
| CloudWatch Agent | Running |
| Agent Configuration | Valid |
| Log Group | Exists |
| IAM Logs Permissions | Missing |
| Root Cause | Access denied by IAM |
| Remediation | Attach CloudWatchAgentServerPolicy |
| Application Redeployment | Not required |

---

## 15. Remediation — Fix IAM Permissions

### Step 1 — Attach CloudWatch Agent Policy

From WSL:

```bash
aws iam attach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### Step 2 — Verify IAM Policies

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output table
```

Expected:

```text
AmazonSSMManagedInstanceCore
CloudWatchAgentServerPolicy
```

### Step 3 — Connect to EC2

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 4 — Restart CloudWatch Agent

Inside EC2:

```bash
sudo systemctl restart amazon-cloudwatch-agent
```

### Step 5 — Verify Agent Status

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Expected: running.

### Step 6 — Inspect Agent Logs

```bash
sudo tail -n 60 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

The authorization error should stop recurring after IAM permissions propagate and the agent retries delivery.

### Step 7 — Generate Recovery Event

```bash
MARKER="LAB01-RECOVERY-$(date -u +%Y%m%dT%H%M%SZ)"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO $MARKER Log delivery restored" \
  | sudo tee -a /var/log/cloudwatch-lab01/app.log

echo "$MARKER"
```

### Step 8 — Verify the Local Event

```bash
sudo tail -n 10 /var/log/cloudwatch-lab01/app.log
```

Expected: the recovery marker appears.

Exit EC2:

```bash
exit
```

---

## 16. Final Verification

### Step 1 — Verify Log Stream

From WSL:

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output table \
  --region "$AWS_REGION"
```

Expected: a log stream named after the EC2 instance ID.

### Step 2 — Retrieve CloudWatch Log Events

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$INSTANCE_ID" \
  --start-from-head \
  --query 'events[].message' \
  --output text \
  --region "$AWS_REGION"
```

Expected: application events.

### Step 3 — Search Application Logs

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"CloudWatch Lab01 application"' \
  --query 'events[].message' \
  --output table \
  --region "$AWS_REGION"
```

Expected: recent application messages.

### Step 4 — Search Recovery Marker

If the marker is available:

```bash
export RECOVERY_MARKER="PASTE_YOUR_MARKER_HERE"
```

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern "\"$RECOVERY_MARKER\"" \
  --query 'events[].message' \
  --output text \
  --region "$AWS_REGION"
```

Expected: the unique recovery event.

### Step 5 — Save IAM Recovery Evidence

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json \
  > lab01-after-iam.json
```

### Step 6 — Save Log Stream Recovery Evidence

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output json \
  --region "$AWS_REGION" \
  > lab01-after-streams.json
```

### Step 7 — Save Log Event Recovery Evidence

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"CloudWatch Lab01 application"' \
  --output json \
  --region "$AWS_REGION" \
  > lab01-after-events.json
```

### Before and After Comparison

| Check | Before Remediation | After Remediation |
|---|---|---|
| Application Service | Running | Running |
| Local Log File | Present | Present |
| CloudWatch Agent | Running | Running |
| Agent Configuration | Valid | Valid |
| Log Group | Exists | Exists |
| IAM Permissions | Missing | Granted |
| Authorization Errors | Present | Resolved |
| Log Stream | Missing or empty | Created |
| CloudWatch Log Events | Not available | Available |
| Recovery Marker | Not published | Published |
| Incident | Active | Resolved |

### Final Verification Criteria

The incident is resolved when:

1. The EC2 application is running.
2. The local log file contains current events.
3. The CloudWatch Agent is running.
4. The IAM role has the necessary publishing permissions.
5. The CloudWatch log stream exists.
6. CloudWatch contains application log messages.
7. The unique recovery event can be retrieved successfully.

---

## 17. Production Best Practices

### CloudWatch Logs Troubleshooting Checklist

1. Verify EC2 is running.
2. Verify the application is producing logs.
3. Verify the local log file exists.
4. Inspect file ownership and permissions.
5. Verify CloudWatch Agent installation.
6. Verify the CloudWatch Agent service is running.
7. Inspect CloudWatch Agent configuration.
8. Verify the configured log file path.
9. Verify the AWS Region.
10. Inspect CloudWatch Agent logs.
11. Check configuration validation errors.
12. Verify EC2 instance profile.
13. Inspect IAM role permissions.
14. Verify the log group exists.
15. Check log streams and events.
16. Confirm network access to AWS service endpoints.
17. Correct the root cause.
18. Generate a new test event.
19. Verify CloudWatch receives the event.
20. Document the incident.

### Common CloudWatch Logs Problems

| Symptom | Possible Cause |
|---|---|
| No log group | Wrong Region or missing log group |
| No log stream | Agent, IAM, or collection problem |
| No log events | Permissions or ingestion failure |
| AccessDeniedException | Missing IAM permissions |
| Agent stopped | Service failure |
| Agent running but no events | IAM, file path, or network issue |
| Invalid configuration | Incorrect JSON |
| Wrong application logs | Incorrect file path |
| Events delayed | Agent retries or buffering |
| Old events missing | Retention or collection issue |

### Security Recommendations

- Prefer IAM roles over static AWS credentials.
- Use least-privilege logging permissions.
- Scope production IAM access to required log groups.
- Do not expose management ports unnecessarily.
- Avoid logging secrets, tokens, or passwords.
- Configure appropriate log retention.
- Monitor log delivery failures.
- Protect log groups using IAM policies.
- Review CloudWatch Agent configurations.
- Use encryption where required by security policy.
- Document log collection dependencies.

### Monitoring Recommendations

Production applications should have monitoring that detects missing telemetry.

Examples include monitoring application event volume, agent health, and expected log delivery.

Missing logs should be treated as a potential observability failure even if the application continues working.

---

## 18. AWS Resource Cleanup

**Warning:** These commands delete the temporary Lab 01 resources. Verify resource IDs and ownership before execution.

### Step 1 — Stop Application and Agent

Connect to EC2:

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Inside EC2:

```bash
sudo systemctl stop cloudwatch-lab01-app

sudo systemctl stop amazon-cloudwatch-agent
```

Verify:

```bash
sudo systemctl is-active cloudwatch-lab01-app

sudo systemctl is-active amazon-cloudwatch-agent
```

Expected: inactive.

Exit:

```bash
exit
```

### Step 2 — Verify Log Group Ownership

```bash
aws logs list-tags-for-resource \
  --resource-arn "$(aws logs describe-log-groups \
    --log-group-name-prefix "$LOG_GROUP" \
    --query "logGroups[?logGroupName=='${LOG_GROUP}'].arn | [0]" \
    --output text \
    --region "$AWS_REGION")" \
  --region "$AWS_REGION"
```

Confirm the `Project` tag identifies Lab 01.

### Step 3 — Delete CloudWatch Log Group

```bash
aws logs delete-log-group \
  --log-group-name "$LOG_GROUP" \
  --region "$AWS_REGION"
```

### Step 4 — Verify Log Group Deletion

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}']" \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[]
```

### Step 5 — Verify Root EBS Volume

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings' \
  --output json \
  --region "$AWS_REGION"
```

Confirm `DeleteOnTermination=true`.

### Step 6 — Terminate EC2

```bash
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"

aws ec2 wait instance-terminated \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 7 — Verify IAM Role Ownership

```bash
aws iam list-role-tags \
  --role-name "$EC2_ROLE_NAME"
```

Confirm the Lab 01 project tag.

### Step 8 — Detach CloudWatch Agent Policy

```bash
aws iam detach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### Step 9 — Detach Systems Manager Policy

```bash
aws iam detach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

### Step 10 — Delete Instance Profile

```bash
aws iam remove-role-from-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$EC2_ROLE_NAME"

aws iam delete-instance-profile \
  --instance-profile-name "$PROFILE_NAME"
```

### Step 11 — Delete IAM Role

```bash
aws iam delete-role \
  --role-name "$EC2_ROLE_NAME"
```

### Step 12 — Verify Network Interface Removal

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status}' \
  --output table \
  --region "$AWS_REGION"
```

Wait until EC2 network interfaces are removed.

### Step 13 — Delete Security Group

```bash
aws ec2 delete-security-group \
  --group-id "$SG_ID" \
  --region "$AWS_REGION"
```

### Step 14 — Disassociate Route Table

```bash
aws ec2 disassociate-route-table \
  --association-id "$RT_ASSOC_ID" \
  --region "$AWS_REGION"
```

### Step 15 — Delete Route Table

```bash
aws ec2 delete-route-table \
  --route-table-id "$RT_ID" \
  --region "$AWS_REGION"
```

### Step 16 — Delete Subnet

```bash
aws ec2 delete-subnet \
  --subnet-id "$SUBNET_ID" \
  --region "$AWS_REGION"
```

### Step 17 — Detach Internet Gateway

```bash
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION"
```

### Step 18 — Delete Internet Gateway

```bash
aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --region "$AWS_REGION"
```

### Step 19 — Delete VPC

```bash
aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION"
```

### Step 20 — Verify Final Cleanup

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Project,Values=$PROJECT_TAG" \
  --query 'Vpcs[].VpcId' \
  --output json \
  --region "$AWS_REGION"
```

Expected:

```json
[]
```

Also verify the CloudWatch log group is deleted, the EC2 instance is terminated, the EBS volume is removed, and IAM resources no longer exist.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Log Group | Deleted |
| CloudWatch Log Streams | Deleted with log group |
| Application Log Events | Deleted with log group |
| EC2 Instance | Terminated |
| Root EBS Volume | Deleted |
| IAM Role | Deleted |
| Instance Profile | Deleted |
| Security Group | Deleted |
| Route Table | Deleted |
| Public Subnet | Deleted |
| Internet Gateway | Deleted |
| Lab VPC | Deleted |
| Default VPC | Unchanged |

---

## 19. Interview Questions and Answers

### Q1. What is Amazon CloudWatch Logs?

A service that collects, stores, and analyzes application and infrastructure log events.

### Q2. Why might application logs not appear in CloudWatch?

Common reasons include missing IAM permissions, CloudWatch Agent failures, incorrect file paths, invalid configuration, and network connectivity problems.

### Q3. Does an EC2 instance automatically send application logs to CloudWatch?

No. An appropriate log collection mechanism must be configured.

### Q4. Can a CloudWatch Agent run without publishing logs?

Yes. The agent may be running locally while CloudWatch API requests fail.

### Q5. Which IAM policy is commonly used for CloudWatch Agent?

`CloudWatchAgentServerPolicy`.

### Q6. Which IAM permissions are important for sending logs?

`logs:CreateLogStream` and `logs:PutLogEvents` are key permissions. Other actions may be needed depending on the configuration.

### Q7. How do you check CloudWatch Agent status?

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

### Q8. Where are CloudWatch Agent logs located on Linux?

A common path is:

```text
/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Q9. How do you inspect CloudWatch log streams?

```bash
aws logs describe-log-streams \
  --log-group-name YOUR_LOG_GROUP
```

### Q10. How do you retrieve log events using AWS CLI?

```bash
aws logs get-log-events \
  --log-group-name YOUR_LOG_GROUP \
  --log-stream-name YOUR_LOG_STREAM
```

### Q11. Why is log retention important?

It helps control storage duration, operational requirements, and CloudWatch Logs costs.

### Q12. How would you explain this lab in an interview?

I deployed an Amazon Linux EC2 instance running a Bash application that continuously generated local log events.

I configured the CloudWatch Agent to collect the application log file and publish the events to CloudWatch Logs.

However, I intentionally omitted CloudWatch Logs permissions from the EC2 IAM role.

The application and CloudWatch Agent were running, but no log events appeared in the CloudWatch log group.

I investigated the CloudWatch Agent logs, application log file, IAM instance profile, role policies, log streams, and CloudWatch API responses.

I identified missing IAM permissions as the root cause.

I attached CloudWatchAgentServerPolicy, restarted the agent, and verified that CloudWatch successfully received application log events.

Finally, I deleted the temporary AWS resources and documented the troubleshooting process.

---

## 20. Repository Structure

```text
aws-cloudwatch-troubleshooting-labs/
│
├── README.md
│
├── 01-cloudwatch-logs-not-appearing/
│   ├── README.md
│   ├── ec2-trust-policy.json
│   ├── app-log-generator.sh
│   ├── user-data.sh
│   ├── cloudwatch-agent.json
│   ├── lab01-before-iam.json
│   ├── lab01-before-streams.json
│   ├── lab01-before-events.json
│   ├── lab01-after-iam.json
│   ├── lab01-after-streams.json
│   └── lab01-after-events.json
│
├── 02-cloudwatch-agent-not-running/
├── 03-ec2-metrics-missing/
├── 04-custom-metric-not-publishing/
├── 05-alarm-insufficient-data/
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
| `ec2-trust-policy.json` | EC2 IAM trust policy |
| `app-log-generator.sh` | Generates application log events |
| `user-data.sh` | Installs the agent and starts the application |
| `cloudwatch-agent.json` | Configures CloudWatch log collection |
| `lab01-before-iam.json` | Captures initial IAM role policies |
| `lab01-before-streams.json` | Captures missing or empty log streams |
| `lab01-before-events.json` | Captures missing application events |
| `lab01-after-iam.json` | Captures corrected IAM permissions |
| `lab01-after-streams.json` | Captures the created log stream |
| `lab01-after-events.json` | Captures delivered application log events |

The CloudWatch Agent configuration is initially created inside EC2. Save a copy in this folder to keep the lab reproducible.

Evidence files must be generated from actual AWS CLI output.

Review the files before publishing them to GitHub.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how missing IAM permissions can prevent CloudWatch Logs ingestion even when an application and CloudWatch Agent are running correctly.

We created a custom AWS VPC and deployed an Amazon Linux EC2 instance.

We configured a Bash application that continuously wrote log events to a local Linux file.

We installed and configured the CloudWatch Agent to collect those events and publish them to a CloudWatch log group.

However, we intentionally configured the EC2 IAM role without CloudWatch Logs permissions.

As a result, the agent was unable to publish log events.

We investigated the issue using Linux service status, application log files, CloudWatch Agent logs, IAM policies, log streams, and AWS CLI.

We confirmed that the application was healthy and that the CloudWatch Agent configuration was valid.

We identified the missing CloudWatch Logs permissions as the root cause.

After attaching the CloudWatchAgentServerPolicy to the EC2 role, the CloudWatch Agent successfully delivered application events.

We verified recovery by retrieving the log messages from CloudWatch Logs.

**Key Lesson:** A running application and CloudWatch Agent do not guarantee successful log ingestion. Always inspect IAM permissions, agent logs, collection settings, and CloudWatch log streams when investigating missing logs.

### Skills Demonstrated

- Amazon CloudWatch Logs
- CloudWatch Agent installation
- CloudWatch Agent configuration
- CloudWatch log groups
- CloudWatch log streams
- CloudWatch log events
- AWS IAM roles
- IAM instance profiles
- CloudWatchAgentServerPolicy
- Amazon EC2
- AWS Systems Manager
- Amazon VPC
- Linux Bash scripting
- Linux systemd
- Linux application logging
- Linux journalctl
- AWS CLI v2
- AccessDenied troubleshooting
- Root cause analysis
- Monitoring remediation
- Recovery verification
- Log retention
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-001 |
| Scenario | CloudWatch Logs Not Appearing |
| EC2 Application | Running |
| Local Application Logs | Present |
| CloudWatch Agent | Running |
| Initial IAM Permissions | Insufficient |
| Original Failure | Logs not delivered |
| Root Cause | Missing CloudWatch Logs permissions |
| Remediation | Attach CloudWatchAgentServerPolicy |
| Application Redeployment | Not required |
| Log Stream After Fix | Created |
| Log Events After Fix | Successfully delivered |
| Recovery Marker | Visible in CloudWatch |
| Cleanup | Temporary AWS resources removed |
| Incident Status | Resolved after verification |

**Key Takeaway:** Successful AWS log monitoring requires a complete logging pipeline. Engineers must verify application log generation, CloudWatch Agent health, IAM authorization, network access, and CloudWatch ingestion rather than assuming a running agent means monitoring is functioning correctly.

---

## Official AWS Documentation

- [Amazon CloudWatch Logs](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/)
- [Installing the CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [CloudWatch Agent Configuration](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
- [CloudWatchAgentServerPolicy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/CloudWatchAgentServerPolicy.html)
- [AWS CLI CloudWatch Logs](https://docs.aws.amazon.com/cli/latest/reference/logs/)