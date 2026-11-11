# Lab 02 — CloudWatch Agent Not Running

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch Agent startup failure caused by an invalid JSON configuration file.

We deploy an Amazon Linux 2023 EC2 instance inside a custom AWS VPC and configure a Bash application that continuously generates log events.

The application writes its logs to:

`/var/log/cloudwatch-lab02/app.log`

We install the Amazon CloudWatch Agent to collect these logs and send them to Amazon CloudWatch Logs.

However, we intentionally create an invalid CloudWatch Agent JSON configuration by removing a comma between two properties.

When we attempt to start the CloudWatch Agent, the configuration fails validation and the agent cannot start successfully.

The application continues generating local logs, but those events are not forwarded to CloudWatch.

We investigate the problem using Linux systemd, journalctl, JSON validation, CloudWatch Agent status commands, agent logs, and AWS CLI.

After identifying the configuration syntax error, we correct the JSON file, reload the CloudWatch Agent, and verify that application logs appear in CloudWatch.

Finally, we remove all temporary AWS resources to avoid unnecessary charges.

**Troubleshooting Workflow:**

Infrastructure Setup → Application Deployment → CloudWatch Agent Installation → Invalid JSON Configuration → Agent Startup Failure → Linux Investigation → Root Cause Analysis → Configuration Remediation → Agent Recovery → Log Delivery Verification → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-002 |
| Difficulty | Beginner |
| AWS Region | `us-east-1` |
| AWS Services | CloudWatch Logs, EC2, IAM, VPC, Systems Manager |
| Local Environment | WSL Ubuntu |
| Operating System | Amazon Linux 2023 |
| Instance Type | `t3.micro` |
| VPC CIDR | `10.65.0.0/16` |
| Public Subnet | `10.65.1.0/24` |
| Application | Bash Log Generator |
| Application Service | `cloudwatch-lab02-app` |
| Local Log File | `/var/log/cloudwatch-lab02/app.log` |
| CloudWatch Agent | Amazon CloudWatch Agent |
| Log Group | `/aws/labs/cloudwatch/02/application` |
| Log Stream | EC2 Instance ID |
| Log Retention | 1 day |
| IAM Policies | AmazonSSMManagedInstanceCore, CloudWatchAgentServerPolicy |
| Fault Injection | Invalid CloudWatch Agent JSON |
| Expected Failure | CloudWatch Agent cannot start |
| Root Cause | Missing comma in JSON configuration |
| Remediation | Correct JSON and reload agent |
| Expected Recovery | Agent running and logs delivered |
| Verification | AWS CLI, systemctl, journalctl, Python JSON validation |

---

## 2. Production Incident Scenario

### Incident Description

A company runs an application on Amazon EC2 and uses the CloudWatch Agent to collect application logs.

The CloudWatch Agent sends the logs to CloudWatch Logs so the operations team can monitor the application and investigate problems.

During a monitoring configuration update, an engineer modifies the CloudWatch Agent JSON configuration.

A syntax mistake is accidentally introduced into the configuration file.

After the configuration is applied, the CloudWatch Agent fails to start.

The application continues working and generates logs locally, but the logs stop appearing in CloudWatch.

The Cloud Engineer must investigate the failure.

During troubleshooting, the engineer discovers that the CloudWatch Agent configuration contains invalid JSON syntax.

The IAM permissions, EC2 networking, and application service are functioning correctly.

The engineer corrects the JSON, validates the configuration, restarts the agent, and verifies that log collection resumes.

### Incident Symptoms

- EC2 instance is running.
- Application service is active.
- Local application logs are being generated.
- IAM permissions are correct.
- CloudWatch log group exists.
- CloudWatch Agent configuration is invalid.
- Agent configuration loading fails.
- CloudWatch Agent is not running.
- CloudWatch log events do not appear.
- JSON validation returns a parsing error.

### Business Impact

- Application logs are not delivered to central monitoring.
- Operations teams lose visibility into application behavior.
- Application errors may go undetected.
- Security investigations may lack centralized log evidence.
- CloudWatch Logs Insights cannot analyze missing events.
- Monitoring dashboards and alerting systems may receive incomplete telemetry.

### Objective

Identify why the CloudWatch Agent fails to start, correct the configuration syntax error, and verify that application log collection resumes without redeploying the application.

---

## 3. AWS Architecture

### Infrastructure Architecture

```text
                       AWS Region
                        us-east-1
                            |
                            v
                        Amazon VPC
                      10.65.0.0/16
                            |
                            v
                       Public Subnet
                      10.65.1.0/24
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
                    Agent Configuration
                            |
                            v
                     CloudWatch Logs
                            |
                            v
                         Log Group
           /aws/labs/cloudwatch/02/application
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
Reads broken-agent.json
       |
       v
Invalid JSON Syntax
       |
       v
Configuration Loading Failure
       |
       v
Agent Cannot Start
       |
       v
CloudWatch Logs Not Updated
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
Reads Corrected JSON
       |
       v
Configuration Validation Passed
       |
       v
Agent Running
       |
       v
CloudWatch Logs API
       |
       v
CloudWatch Log Group
       |
       v
Application Log Events Available
```

### Network Configuration

| Component | Configuration |
|---|---|
| VPC | `10.65.0.0/16` |
| Public Subnet | `10.65.1.0/24` |
| Internet Gateway | Attached |
| Default Route | `0.0.0.0/0` |
| EC2 Operating System | Amazon Linux 2023 |
| EC2 Public IP | Assigned |
| Inbound SSH | Not allowed |
| EC2 Management | AWS Systems Manager |
| CloudWatch Logs Access | Outbound HTTPS |
| Log Collection | CloudWatch Agent |

No inbound SSH or HTTP security group rules are required.

---

## 4. Understanding CloudWatch Agent

### What Is the CloudWatch Agent?

The Amazon CloudWatch Agent is software that collects logs and system-level metrics from supported servers.

It can collect information such as:

- Application logs
- Operating-system logs
- Memory utilization
- Filesystem utilization
- CPU metrics
- Selected process metrics

### Why Is the CloudWatch Agent Important?

CloudWatch Agent helps engineers collect monitoring data that is not automatically available through native EC2 monitoring.

It is commonly used for centralized logging and infrastructure observability.

### What Is the Agent Configuration File?

The configuration file defines what information the CloudWatch Agent collects and where that information is published.

For example:

```json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/application.log",
            "log_group_name": "/aws/application",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

### What Is JSON?

JSON stands for JavaScript Object Notation.

It is a structured format used to store configuration data.

JSON requires correct syntax, including:

- Quotation marks around property names.
- Colons between property names and values.
- Commas between properties.
- Properly matched brackets and braces.

### What Happens When JSON Is Invalid?

An application that expects valid JSON may fail to parse the configuration file.

For CloudWatch Agent, a malformed configuration can prevent the agent from loading its settings and starting correctly.

### What Is systemd?

systemd is a Linux service management system.

It can start, stop, restart, and inspect services.

Example:

```bash
sudo systemctl status amazon-cloudwatch-agent
```

### What Is journalctl?

`journalctl` displays logs collected by the systemd journal.

It is useful for investigating Linux service startup problems.

### What Is amazon-cloudwatch-agent-ctl?

It is a control utility used to manage the CloudWatch Agent.

It can load configuration files, start or stop the agent, and report its status.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- EC2 permissions
- IAM permissions
- VPC permissions
- CloudWatch Logs permissions
- Systems Manager access
- Python 3 for JSON validation
- Git and GitHub

### Security Rules

- Use a dedicated lab VPC.
- Do not modify production CloudWatch Agent configurations.
- Use IAM roles instead of static credentials.
- Do not expose SSH unnecessarily.
- Do not commit AWS credentials.
- Do not publish confidential application logs.
- Confirm resource ownership before cleanup.
- Delete temporary infrastructure after testing.

### Cost Considerations

Potential charges include:

- EC2 instance usage
- EBS storage
- Public IPv4 address
- CloudWatch Logs ingestion
- CloudWatch Logs storage

The lab uses a one-day log retention policy to reduce unnecessary storage.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab02"

export VPC_CIDR="10.65.0.0/16"
export SUBNET_CIDR="10.65.1.0/24"

export EC2_ROLE_NAME="cloudwatch-lab02-ec2-role"
export PROFILE_NAME="cloudwatch-lab02-instance-profile"

export SG_NAME="cloudwatch-lab02-sg"

export LOG_GROUP="/aws/labs/cloudwatch/02/application"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$VPC_CIDR"
echo "$LOG_GROUP"
```

Keep the WSL terminal open to preserve AWS resource identifiers.

---

## 7. Create VPC and Networking

### Step 1 — Create VPC

```bash
export VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications \
  "ResourceType=vpc,Tags=[{Key=Name,Value=cloudwatch-lab02-vpc},{Key=Project,Value=$PROJECT_TAG}]" \
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
  "ResourceType=subnet,Tags=[{Key=Name,Value=cloudwatch-lab02-public},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region "$AWS_REGION")
```

### Step 5 — Create Internet Gateway

```bash
export IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications \
  "ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudwatch-lab02-igw},{Key=Project,Value=$PROJECT_TAG}]" \
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
  "ResourceType=route-table,Tags=[{Key=Name,Value=cloudwatch-lab02-rt},{Key=Project,Value=$PROJECT_TAG}]" \
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

## 8. Configure Security Group and IAM

### Step 1 — Create Security Group

```bash
export SG_ID=$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "CloudWatch Lab02 no inbound access" \
  --vpc-id "$VPC_ID" \
  --tag-specifications \
  "ResourceType=security-group,Tags=[{Key=Name,Value=$SG_NAME},{Key=Project,Value=$PROJECT_TAG}]" \
  --query GroupId \
  --output text \
  --region "$AWS_REGION")
```

No inbound security group permissions are necessary.

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

### Step 4 — Attach Systems Manager Policy

```bash
aws iam attach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

### Step 5 — Attach CloudWatch Agent Policy

```bash
aws iam attach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

Unlike Lab 01, both IAM policies are attached before fault injection.

### Step 6 — Verify IAM Permissions

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

### Step 7 — Create Instance Profile

```bash
aws iam create-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --tags Key=Project,Value="$PROJECT_TAG"

aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$EC2_ROLE_NAME"
```

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

Expected: the correct log group with one-day retention.

---

## 10. Deploy EC2 Application

### Step 1 — Create User Data

Save as `user-data.sh`:

```bash
#!/bin/bash
set -euxo pipefail

dnf install -y amazon-cloudwatch-agent python3

mkdir -p /opt/cloudwatch-lab02
mkdir -p /var/log/cloudwatch-lab02

cat > /opt/cloudwatch-lab02/app.sh <<'APP'
#!/bin/bash

LOG_FILE="/var/log/cloudwatch-lab02/app.log"

while true; do
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO Lab02 application running" \
    >> "$LOG_FILE"
  sleep 10
done
APP

chmod +x /opt/cloudwatch-lab02/app.sh

cat > /etc/systemd/system/cloudwatch-lab02-app.service <<'SERVICE'
[Unit]
Description=CloudWatch Lab02 Log Generator
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /opt/cloudwatch-lab02/app.sh
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now cloudwatch-lab02-app.service
```

### Step 2 — Retrieve Amazon Linux AMI

```bash
export AMI_ID=$(aws ssm get-parameter \
  --name "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64" \
  --query Parameter.Value \
  --output text \
  --region "$AWS_REGION")
```

### Step 3 — Launch EC2

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
  "ResourceType=instance,Tags=[{Key=Name,Value=cloudwatch-lab02-ec2},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Instances[0].InstanceId' \
  --output text \
  --region "$AWS_REGION")

echo "$INSTANCE_ID"
```

### Step 4 — Wait for EC2

```bash
aws ec2 wait instance-running \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"

aws ec2 wait instance-status-ok \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 5 — Connect Using Systems Manager

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 6 — Verify Application Service

Inside EC2:

```bash
sudo systemctl status cloudwatch-lab02-app --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 7 — Verify Local Application Logs

```bash
sudo tail -n 10 /var/log/cloudwatch-lab02/app.log
```

Expected example:

```text
2026-11-10T18:30:00Z INFO Lab02 application running
2026-11-10T18:30:10Z INFO Lab02 application running
2026-11-10T18:30:20Z INFO Lab02 application running
```

Actual timestamps depend on when the lab is performed.

---

## 11. Fault Injection — Invalid CloudWatch Agent Configuration

### Step 1 — Stop CloudWatch Agent

Inside EC2:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a stop
```

### Step 2 — Create Broken Agent Configuration

Save as `/opt/cloudwatch-lab02/broken-agent.json`:

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
            "file_path": "/var/log/cloudwatch-lab02/app.log"
            "log_group_name": "/aws/labs/cloudwatch/02/application",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

### Intentional Misconfiguration

The following properties have no comma between them:

```text
"file_path": "/var/log/cloudwatch-lab02/app.log"
"log_group_name": "/aws/labs/cloudwatch/02/application"
```

JSON requires a comma between object properties.

The missing comma makes the configuration invalid.

### Step 3 — Validate Broken JSON

```bash
python3 -m json.tool \
  /opt/cloudwatch-lab02/broken-agent.json
```

Expected error:

```text
Expecting ',' delimiter
```

### Step 4 — Attempt to Start CloudWatch Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/cloudwatch-lab02/broken-agent.json
```

Expected: configuration loading fails.

The exact error depends on the installed agent version.

### Step 5 — Inspect Agent Status

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Expected: agent is not running.

### Step 6 — Inspect systemd Service

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
```

Expected: inactive, failed, or not running.

### Step 7 — Inspect systemd Journal

```bash
sudo journalctl \
  -u amazon-cloudwatch-agent \
  -n 60 \
  --no-pager
```

### Step 8 — Inspect Configuration Validation Log

```bash
sudo cat \
  /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
```

The file may contain configuration validation errors.

If malformed JSON was rejected before the agent generated a validation log, use the Python JSON parser error as the primary evidence.

### Step 9 — Inspect Agent Logs

```bash
sudo tail -n 80 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

If the file does not exist, the agent may not have initialized successfully.

### Step 10 — Verify Application Still Runs

```bash
sudo systemctl is-active cloudwatch-lab02-app
```

Expected:

```text
active
```

### Step 11 — Verify Local Logs

```bash
sudo tail -n 5 /var/log/cloudwatch-lab02/app.log
```

Expected: new log messages.

### Fault Injection Summary

| Component | Expected Result |
|---|---|
| EC2 Instance | Running |
| Application | Active |
| Local Logs | Present |
| IAM Permissions | Correct |
| CloudWatch Agent JSON | Invalid |
| JSON Parser | Error |
| Agent Configuration Loading | Failed |
| Agent Service | Not running |
| CloudWatch Logs | No new application events |

---

## 12. Investigate Missing CloudWatch Logs

### Step 1 — Verify Log Group

From WSL:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}']" \
  --output json \
  --region "$AWS_REGION"
```

### Step 2 — Inspect Log Streams

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output json \
  --region "$AWS_REGION"
```

Expected: no log stream if the agent has never started successfully.

### Step 3 — Search Application Logs

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"Lab02 application running"' \
  --output json \
  --region "$AWS_REGION"
```

Expected: no matching events.

### Step 4 — Verify IAM Permissions

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

This helps rule out missing IAM permissions as the intended cause.

### Step 5 — Save IAM Evidence

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json \
  > lab02-iam-policies.json
```

### Step 6 — Save Log Stream Evidence

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output json \
  --region "$AWS_REGION" \
  > lab02-before-streams.json
```

### Step 7 — Save Missing Event Evidence

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"Lab02 application running"' \
  --output json \
  --region "$AWS_REGION" \
  > lab02-before-events.json
```

### Investigation Matrix

| Investigation | Expected Finding |
|---|---|
| Application Service | Healthy |
| Local Log File | Exists |
| Local Log Events | Present |
| IAM Permissions | Correct |
| Agent JSON | Invalid |
| Agent Startup | Failed |
| CloudWatch Log Group | Exists |
| CloudWatch Log Stream | Missing |
| Root Cause | Configuration syntax error |

---

## 13. Root Cause Analysis

### Root Cause

The CloudWatch Agent failed to start because its JSON configuration file contained invalid syntax.

A comma was missing between the `file_path` and `log_group_name` properties.

When the CloudWatch Agent attempted to load the configuration, JSON parsing failed.

Because the configuration could not be loaded, the agent could not start successfully or collect application logs.

The application remained healthy and continued writing to its local log file.

The IAM role had the required permissions, so IAM authorization was not the cause.

### Root Cause Flow

```text
CloudWatch Agent
       |
       v
Reads broken-agent.json
       |
       v
Missing Comma
       |
       v
JSON Parsing Failure
       |
       v
Configuration Loading Fails
       |
       v
Agent Not Running
       |
       v
Local Logs Not Collected
       |
       v
CloudWatch Logs Missing
```

### Five Whys

1. **Why were the application logs missing?** The CloudWatch Agent was not collecting them.
2. **Why wasn't the agent collecting logs?** The agent was not running.
3. **Why wasn't the agent running?** Its configuration failed to load.
4. **Why did the configuration fail?** The JSON syntax was invalid.
5. **How was the issue resolved?** The JSON error was corrected, and the agent configuration was reloaded.

### Root Cause Summary

| Component | Finding |
|---|---|
| AWS Service | CloudWatch Logs |
| Incident | INC-CW-002 |
| EC2 Instance | Healthy |
| Application | Healthy |
| Local Logs | Working |
| IAM Permissions | Correct |
| Agent Configuration | Invalid |
| Agent Startup | Failed |
| Root Cause | Missing JSON comma |
| Remediation | Correct configuration |
| Application Redeployment | Not required |

---

## 14. Remediation — Correct the Agent Configuration

### Step 1 — Create Corrected JSON

Inside EC2, save as `/opt/cloudwatch-lab02/cloudwatch-agent.json`:

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
            "file_path": "/var/log/cloudwatch-lab02/app.log",
            "log_group_name": "/aws/labs/cloudwatch/02/application",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
```

### Step 2 — Identify the Correction

Before:

```text
"file_path": "/var/log/cloudwatch-lab02/app.log"
"log_group_name": "/aws/labs/cloudwatch/02/application"
```

After:

```text
"file_path": "/var/log/cloudwatch-lab02/app.log",
"log_group_name": "/aws/labs/cloudwatch/02/application"
```

The missing comma was added.

### Step 3 — Validate JSON

```bash
python3 -m json.tool \
  /opt/cloudwatch-lab02/cloudwatch-agent.json
```

Expected: valid, formatted JSON output.

### Step 4 — Reload CloudWatch Agent Configuration

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/cloudwatch-lab02/cloudwatch-agent.json
```

### Step 5 — Verify Agent Status

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

Additional output fields may appear.

### Step 6 — Verify systemd

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 7 — Inspect Validation Log

```bash
sudo cat \
  /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
```

Expected: no fatal configuration validation errors.

### Step 8 — Inspect Agent Logs

```bash
sudo tail -n 50 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

Expected: no recurring startup or authorization errors.

### Step 9 — Generate Recovery Event

```bash
MARKER="LAB02-RECOVERY-$(date -u +%Y%m%dT%H%M%SZ)"

echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) INFO $MARKER Agent recovered" \
  | sudo tee -a /var/log/cloudwatch-lab02/app.log

echo "$MARKER"
```

### Step 10 — Verify Local Event

```bash
sudo tail -n 10 /var/log/cloudwatch-lab02/app.log
```

Expected: the unique recovery marker appears.

---

## 15. Verify CloudWatch Log Delivery

### Step 1 — Inspect Log Streams

From WSL:

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output table \
  --region "$AWS_REGION"
```

Expected: a log stream named after the EC2 instance ID.

### Step 2 — Retrieve Log Events

```bash
aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$INSTANCE_ID" \
  --start-from-head \
  --query 'events[].message' \
  --output text \
  --region "$AWS_REGION"
```

Expected:

```text
2026-11-10T18:45:00Z INFO Lab02 application running
2026-11-10T18:45:10Z INFO Lab02 application running
2026-11-10T18:45:20Z INFO Lab02 application running
```

Actual timestamps will vary.

### Step 3 — Filter Application Events

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"Lab02 application running"' \
  --query 'events[].message' \
  --output table \
  --region "$AWS_REGION"
```

Expected: application log messages.

### Step 4 — Verify Recovery Marker

If you copied your recovery marker:

```bash
export RECOVERY_MARKER="PASTE_RECOVERY_MARKER_HERE"
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

### Step 5 — Save Log Stream Evidence

```bash
aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --output json \
  --region "$AWS_REGION" \
  > lab02-after-streams.json
```

### Step 6 — Save Log Event Evidence

```bash
aws logs filter-log-events \
  --log-group-name "$LOG_GROUP" \
  --filter-pattern '"Lab02 application running"' \
  --output json \
  --region "$AWS_REGION" \
  > lab02-after-events.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| EC2 Instance | Running | Running |
| Application Service | Active | Active |
| Local Application Logs | Present | Present |
| IAM Permissions | Correct | Correct |
| Agent JSON | Invalid | Valid |
| JSON Validation | Failed | Passed |
| Agent Configuration Loading | Failed | Successful |
| CloudWatch Agent | Stopped | Running |
| CloudWatch Log Stream | Missing | Created |
| Application Log Events | Missing | Available |
| Recovery Marker | Not delivered | Delivered |
| Incident | Active | Resolved |

### Final Verification Criteria

The incident is resolved when:

1. The application remains active.
2. The corrected JSON passes validation.
3. The CloudWatch Agent loads its configuration successfully.
4. The agent service reports running.
5. The CloudWatch log stream exists.
6. Application log events appear in CloudWatch.
7. The unique recovery marker can be retrieved successfully.

---

## 16. Production Troubleshooting Best Practices

### CloudWatch Agent Troubleshooting Checklist

1. Verify the EC2 instance is running.
2. Verify the application is healthy.
3. Confirm the local log file exists.
4. Check CloudWatch Agent installation.
5. Inspect the agent's service status.
6. Review systemd journal messages.
7. Inspect CloudWatch Agent logs.
8. Review configuration validation errors.
9. Validate JSON syntax.
10. Verify CloudWatch Agent configuration settings.
11. Confirm the log file path.
12. Verify AWS Region.
13. Inspect the EC2 IAM role.
14. Confirm CloudWatch publishing permissions.
15. Verify access to CloudWatch Logs endpoints.
16. Correct the configuration.
17. Reload the agent.
18. Verify the service is running.
19. Generate a test log event.
20. Confirm the event appears in CloudWatch.

### Common Agent Problems

| Symptom | Possible Cause |
|---|---|
| Agent cannot start | Invalid configuration |
| JSON validation error | Missing comma, brace, or quotation mark |
| Agent stops unexpectedly | Service or configuration issue |
| Agent running but no logs | File path, IAM, or network issue |
| Configuration changes ignored | Configuration not reloaded |
| AccessDeniedException | Missing IAM permissions |
| Wrong log group | Incorrect destination configuration |
| Logs appear in wrong Region | Agent Region mismatch |
| Log file not found | Incorrect path |
| Agent validation fails | Unsupported or invalid settings |

### Prevention

- Store CloudWatch Agent configurations in Git.
- Use JSON syntax validation in CI/CD.
- Review monitoring changes before deployment.
- Test configurations on nonproduction instances.
- Keep known-good configurations for rollback.
- Verify agent health after updates.
- Monitor telemetry delivery.
- Use IAM roles with least-privilege permissions.
- Document monitoring configuration changes.

**Important:** Valid JSON does not guarantee a working agent. The configuration must also satisfy the CloudWatch Agent's supported settings, and actual log delivery must be verified.

---

## 17. Operational and Security Recommendations

### Monitoring Reliability

CloudWatch Agent failures can create monitoring blind spots even when applications remain healthy.

Production monitoring should include checks for both the agent's health and the arrival of expected telemetry.

### Least Privilege

Use IAM instance roles instead of static AWS credentials.

Grant only the permissions required to publish metrics and logs.

### Log Retention

Configure appropriate log retention policies according to business, operational, and compliance requirements.

### Configuration Management

Manage CloudWatch Agent configurations as code.

Apply configuration validation before changes are deployed.

### Incident Response

When the CloudWatch Agent fails, engineers should investigate the application, operating system, IAM permissions, network connectivity, and agent configuration rather than assuming the failure belongs to only one layer.

---

## 18. AWS Resource Cleanup

**Warning:** Verify that all resource IDs belong to Lab 02 before deleting anything.

### Step 1 — Stop Application and Agent

Connect to EC2:

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Inside EC2:

```bash
sudo systemctl stop cloudwatch-lab02-app
sudo systemctl stop amazon-cloudwatch-agent
```

Verify:

```bash
sudo systemctl is-active cloudwatch-lab02-app
sudo systemctl is-active amazon-cloudwatch-agent
```

Expected: inactive.

Exit:

```bash
exit
```

### Step 2 — Verify Log Group Ownership

From WSL:

```bash
export LOG_GROUP_ARN=$(aws logs describe-log-groups \
  --log-group-name-prefix "$LOG_GROUP" \
  --query "logGroups[?logGroupName=='${LOG_GROUP}'].arn | [0]" \
  --output text \
  --region "$AWS_REGION")

aws logs list-tags-for-resource \
  --resource-arn "$LOG_GROUP_ARN" \
  --region "$AWS_REGION"
```

Confirm the Lab 02 project tag.

### Step 3 — Delete Log Group

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

### Step 5 — Verify EC2 Root Volume

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings' \
  --output json \
  --region "$AWS_REGION"
```

Confirm the root EBS volume has `DeleteOnTermination=true`.

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

Confirm the Lab 02 tag.

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

### Step 12 — Verify Network Interfaces

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status}' \
  --output table \
  --region "$AWS_REGION"
```

Wait until the EC2 network interface is removed.

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

Also verify that the EC2 instance, EBS volume, CloudWatch log group, IAM role, and instance profile have been removed.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Log Group | Deleted |
| CloudWatch Log Streams | Deleted |
| CloudWatch Log Events | Deleted |
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

### Q1. What is the CloudWatch Agent?

The CloudWatch Agent collects logs and supported system metrics from EC2 instances and other servers.

### Q2. Why might the CloudWatch Agent fail to start?

Common causes include invalid configuration files, missing configuration, unsupported settings, and service initialization problems.

### Q3. Where can you inspect CloudWatch Agent configuration errors?

A common location is:

```text
/opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
```

### Q4. How do you check CloudWatch Agent status?

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

### Q5. What does `fetch-config` do?

It loads a CloudWatch Agent configuration from a specified source and can start the agent using that configuration.

### Q6. What is systemd?

A Linux service manager that controls and monitors system services.

### Q7. What is journalctl?

A Linux command used to inspect logs maintained by the systemd journal.

### Q8. Can an application generate logs while the CloudWatch Agent is stopped?

Yes. Local application logging and centralized log forwarding are separate processes.

### Q9. What is the difference between Lab 01 and Lab 02?

In Lab 01, the CloudWatch Agent was running but lacked IAM permissions to publish logs.

In Lab 02, IAM permissions were correct, but invalid JSON prevented the CloudWatch Agent from starting.

### Q10. How can you validate JSON before applying an agent configuration?

```bash
python3 -m json.tool cloudwatch-agent.json
```

This checks JSON syntax but does not replace CloudWatch Agent configuration validation.

### Q11. How can you prevent CloudWatch Agent configuration failures?

Use version-controlled configurations, code reviews, automated JSON validation, and tests before deploying configuration changes.

### Q12. How would you explain this lab in an interview?

I deployed an Amazon Linux EC2 instance running a Bash application that continuously generated local log events.

I installed the CloudWatch Agent and configured IAM permissions for CloudWatch Logs.

I intentionally introduced a JSON syntax error into the CloudWatch Agent configuration.

The application continued running, but the CloudWatch Agent could not start successfully.

I investigated the failure using systemctl, journalctl, Python JSON validation, agent logs, and AWS CLI.

I identified the invalid JSON configuration as the root cause.

I corrected the syntax error, reloaded the agent, and verified that the agent was running.

Finally, I confirmed that application log events appeared in CloudWatch Logs and removed the temporary AWS resources.

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
│   ├── README.md
│   ├── ec2-trust-policy.json
│   ├── user-data.sh
│   ├── broken-agent.json
│   ├── cloudwatch-agent.json
│   ├── lab02-iam-policies.json
│   ├── lab02-before-streams.json
│   ├── lab02-before-events.json
│   ├── lab02-after-streams.json
│   └── lab02-after-events.json
│
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
| `README.md` | Complete troubleshooting documentation |
| `ec2-trust-policy.json` | EC2 IAM trust policy |
| `user-data.sh` | Installs agent and starts the application |
| `broken-agent.json` | Intentionally invalid agent configuration |
| `cloudwatch-agent.json` | Corrected agent configuration |
| `lab02-iam-policies.json` | Verifies correct IAM policies |
| `lab02-before-streams.json` | Captures missing log streams |
| `lab02-before-events.json` | Captures missing log events |
| `lab02-after-streams.json` | Captures created log stream |
| `lab02-after-events.json` | Captures delivered log events |

### Evidence Guidelines

Save actual AWS CLI and Linux command outputs as evidence.

The JSON configuration files are initially created on EC2, so copies should be saved locally before the instance is terminated.

Do not fabricate evidence or publish sensitive information.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how a simple JSON syntax error can prevent the CloudWatch Agent from starting and interrupt centralized log collection.

We created a custom AWS VPC and deployed an Amazon Linux EC2 instance.

We configured a Bash application to generate log events continuously.

We installed the CloudWatch Agent and attached the required IAM permissions.

However, we intentionally created an invalid JSON configuration file.

When the agent attempted to load this configuration, parsing failed.

The agent could not start successfully, even though the application continued producing logs locally.

We investigated the problem using Linux service commands, agent status tools, configuration validation, systemd journals, and AWS CLI.

We identified the missing comma in the JSON file as the root cause.

After correcting the configuration, we successfully reloaded the agent and verified that application logs appeared in CloudWatch.

The exercise showed that application health and monitoring health must be checked separately.

**Key Lesson:** CloudWatch Agent startup failures should be investigated by checking configuration syntax, agent validation results, Linux service status, and agent logs before making unnecessary changes to IAM or network infrastructure.

### Skills Demonstrated

- Amazon CloudWatch Agent
- CloudWatch Logs
- CloudWatch log groups
- CloudWatch log streams
- JSON configuration
- JSON syntax troubleshooting
- Amazon EC2
- Amazon VPC
- AWS IAM
- IAM instance profiles
- AWS Systems Manager
- Linux Bash
- Linux systemd
- Linux journalctl
- Linux application logging
- Python JSON validation
- AWS CLI v2
- Monitoring incident investigation
- Root cause analysis
- Agent recovery verification
- Log ingestion verification
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-002 |
| Scenario | CloudWatch Agent Not Running |
| EC2 Application | Running |
| Local Application Logs | Present |
| IAM Permissions | Correct |
| Initial Agent Configuration | Invalid |
| JSON Validation Before Fix | Failed |
| Agent Startup Before Fix | Failed |
| Root Cause | Missing comma in JSON |
| Remediation | Correct JSON and reload agent |
| JSON Validation After Fix | Passed |
| Agent Status After Fix | Running |
| Log Stream After Fix | Created |
| CloudWatch Log Events | Successfully delivered |
| Recovery Marker | Visible in CloudWatch |
| Cleanup | Temporary AWS resources removed |
| Incident Status | Resolved after verification |

**Key Takeaway:** Reliable AWS monitoring depends on both correct infrastructure permissions and valid monitoring agent configurations. Even a small syntax error can stop telemetry collection, so configuration validation and recovery verification should be part of every monitoring deployment.

---

## Official AWS Documentation

- [Amazon CloudWatch Agent Troubleshooting](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/troubleshooting-CloudWatch-Agent.html)
- [CloudWatch Agent Configuration File Details](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
- [Creating a CloudWatch Agent Configuration File](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file.html)
- [Installing the CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [AWS CLI CloudWatch Logs Reference](https://docs.aws.amazon.com/cli/latest/reference/logs/)