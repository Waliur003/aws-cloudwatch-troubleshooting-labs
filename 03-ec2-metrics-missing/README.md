# Lab 03 — EC2 Metrics Missing

## Overview

This lab demonstrates how to troubleshoot missing Amazon EC2 memory metrics in Amazon CloudWatch caused by an incorrect CloudWatch Agent namespace configuration.

We deploy an Amazon Linux 2023 EC2 instance inside a custom AWS VPC and install the Amazon CloudWatch Agent to collect operating-system memory utilization.

Amazon EC2 automatically publishes native infrastructure metrics such as CPU utilization and network traffic to the `AWS/EC2` namespace.

However, memory utilization is not included in the standard native EC2 metrics.

To monitor memory usage, we configure the CloudWatch Agent to collect and publish the `mem_used_percent` metric.

We intentionally configure the agent to publish memory metrics to the wrong CloudWatch namespace:

`CWAgent-Lab03-Wrong`

The monitoring team expects the metric under:

`CWAgent`

As a result, the CloudWatch Agent runs successfully and publishes memory utilization, but the expected metric query returns no datapoints.

We investigate the issue using AWS CLI, Linux commands, IAM policies, CloudWatch Agent configuration, metric namespaces, dimensions, and CloudWatch metric APIs.

After identifying the incorrect namespace, we update the agent configuration, restart metric collection, and verify that memory utilization appears under the correct namespace.

Finally, we remove the temporary AWS resources.

**Troubleshooting Workflow:**

Infrastructure Setup → EC2 Deployment → Native Metric Verification → CloudWatch Agent Installation → Wrong Namespace Configuration → Missing Expected Metric → AWS CLI Investigation → Root Cause Analysis → Namespace Remediation → Metric Recovery → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-003 |
| Difficulty | Beginner–Intermediate |
| AWS Region | `us-east-1` |
| AWS Services | CloudWatch, EC2, IAM, VPC, Systems Manager |
| Local Environment | WSL Ubuntu |
| Operating System | Amazon Linux 2023 |
| EC2 Instance Type | `t3.micro` |
| VPC CIDR | `10.66.0.0/16` |
| Public Subnet | `10.66.1.0/24` |
| Native EC2 Namespace | `AWS/EC2` |
| Expected Agent Namespace | `CWAgent` |
| Incorrect Namespace | `CWAgent-Lab03-Wrong` |
| Native Metric | `CPUUtilization` |
| Agent Metric | `mem_used_percent` |
| Metric Dimension | `InstanceId` |
| Collection Interval | 60 seconds |
| Monitoring Agent | Amazon CloudWatch Agent |
| IAM Policies | AmazonSSMManagedInstanceCore, CloudWatchAgentServerPolicy |
| Fault Injection | Wrong CloudWatch metrics namespace |
| Expected Failure | Memory metric missing from expected namespace |
| Root Cause | Incorrect agent namespace configuration |
| Remediation | Correct namespace and reload agent |
| Verification | list-metrics, get-metric-statistics, get-metric-data |

---

## 2. Production Incident Scenario

### Incident Description

A company operates multiple EC2 instances in AWS and uses Amazon CloudWatch to monitor infrastructure performance.

The Cloud Operations team maintains a monitoring dashboard containing CPU utilization, memory utilization, and other operating-system metrics.

During routine monitoring, an engineer notices that CPU utilization is visible, but memory utilization is missing for one EC2 instance.

The EC2 instance is running normally.

AWS native monitoring is publishing CPU utilization to CloudWatch.

The CloudWatch Agent is installed and running, and its IAM role contains the necessary permissions.

However, the monitoring dashboard cannot retrieve the expected memory utilization metric.

The Cloud Engineer investigates the CloudWatch Agent configuration and discovers that the memory metric is being published to an incorrect namespace.

Instead of publishing to `CWAgent`, the agent publishes to `CWAgent-Lab03-Wrong`.

The metric itself is being collected successfully, but the dashboard searches the wrong metric identity.

The engineer must correct the agent configuration and verify successful metric publication under the intended namespace.

### Incident Symptoms

- EC2 instance is running.
- Native EC2 CPU metrics are available.
- Memory utilization is available inside Linux.
- CloudWatch Agent is installed.
- CloudWatch Agent is running.
- IAM permissions are correct.
- Metric collection is configured.
- Memory metric is missing under `CWAgent`.
- Memory metric exists under `CWAgent-Lab03-Wrong`.
- CloudWatch metric queries return no datapoints for the expected namespace.
- Monitoring dashboards cannot display the intended memory metric.

### Business Impact

- Operations teams cannot monitor EC2 memory utilization correctly.
- Memory-related performance issues may go undetected.
- CloudWatch dashboards show incomplete monitoring information.
- Memory alarms may remain in `INSUFFICIENT_DATA`.
- Engineers may incorrectly assume the agent is not collecting metrics.
- Infrastructure monitoring becomes unreliable.
- Troubleshooting takes longer when metric namespaces and dimensions are not verified.

### Objective

Identify why the expected EC2 memory utilization metric is missing, determine where the agent is publishing it, correct the namespace, and verify successful memory metric collection without redeploying the EC2 instance.

---

## 3. AWS Architecture

### Infrastructure Architecture

```text
                       AWS Region
                        us-east-1
                            |
                            v
                        Amazon VPC
                      10.66.0.0/16
                            |
                            v
                       Public Subnet
                      10.66.1.0/24
                            |
                            v
                       EC2 Instance
                    Amazon Linux 2023
                            |
                 -----------------------
                 |                     |
                 v                     v
           Native Monitoring     CloudWatch Agent
                 |                     |
                 v                     v
           CPUUtilization       mem_used_percent
                 |                     |
                 v                     v
              AWS/EC2            Custom Namespace
                 |                     |
                 -----------------------
                            |
                            v
                     Amazon CloudWatch
                            |
                            v
                       Metric Queries
                            |
                            v
                     Monitoring Dashboard
```

### Architecture Before Remediation

```text
EC2 Instance
      |
      v
Linux Memory Statistics
      |
      v
CloudWatch Agent
      |
      v
Memory Metric Collection
      |
      v
Wrong Namespace Configured
      |
      v
CWAgent-Lab03-Wrong
      |
      v
Metric Successfully Published
      |
      v
Dashboard Queries CWAgent
      |
      v
No Matching Metric Data
      |
      v
Memory Metrics Missing
```

### Architecture After Remediation

```text
EC2 Instance
      |
      v
Linux Memory Statistics
      |
      v
CloudWatch Agent
      |
      v
Correct Namespace Configuration
      |
      v
CWAgent
      |
      v
mem_used_percent
      |
      v
InstanceId Dimension
      |
      v
CloudWatch Metric Datapoints
      |
      v
Monitoring Query Successful
```

### Network Configuration

| Component | Configuration |
|---|---|
| VPC | `10.66.0.0/16` |
| Public Subnet | `10.66.1.0/24` |
| Internet Gateway | Attached |
| Default Route | `0.0.0.0/0` |
| EC2 Operating System | Amazon Linux 2023 |
| EC2 Public IP | Assigned |
| Inbound SSH | Not required |
| EC2 Management | Systems Manager |
| CloudWatch Connectivity | Outbound HTTPS |
| Agent Metrics Destination | CloudWatch |

No inbound SSH or HTTP access is required.

---

## 4. Understanding EC2 and CloudWatch Metrics

### What Is Amazon CloudWatch?

Amazon CloudWatch is an AWS monitoring and observability service.

It collects and stores metrics and logs from AWS resources and applications.

Engineers use CloudWatch to monitor infrastructure performance, configure alarms, build dashboards, and investigate operational problems.

### What Is a CloudWatch Metric?

A metric is a numerical measurement recorded over time.

Examples include:

- CPU utilization
- Memory utilization
- Network traffic
- Disk usage
- Application request counts
- Application error rates

### What Are Native EC2 Metrics?

Amazon EC2 publishes infrastructure metrics to CloudWatch without requiring the CloudWatch Agent.

Examples:

| Metric | Namespace |
|---|---|
| CPUUtilization | AWS/EC2 |
| NetworkIn | AWS/EC2 |
| NetworkOut | AWS/EC2 |
| StatusCheckFailed | AWS/EC2 |
| DiskReadBytes | AWS/EC2 |
| DiskWriteBytes | AWS/EC2 |

### Does EC2 Automatically Publish Memory Utilization?

No.

Standard EC2 monitoring does not publish operating-system memory utilization.

To monitor Linux memory usage, engineers generally install the CloudWatch Agent or another metric collection tool.

### What Is the CloudWatch Agent?

The CloudWatch Agent collects additional system metrics and logs from supported servers.

Examples of agent-collected metrics:

```text
mem_used_percent
disk_used_percent
cpu_usage_user
cpu_usage_system
swap_used_percent
```

The available metrics depend on the agent configuration and operating system.

### What Is a Namespace?

A namespace is a logical container used to organize CloudWatch metrics.

Examples:

```text
AWS/EC2
AWS/RDS
AWS/ApplicationELB
CWAgent
Custom/Application
```

The default namespace for CloudWatch Agent metrics is `CWAgent`, unless another namespace is configured.

### What Is a Metric Dimension?

Dimensions identify a particular metric series.

Example:

```text
Namespace: CWAgent
MetricName: mem_used_percent
Dimension: InstanceId
Value: i-0123456789abcdef0
```

### What Identifies a CloudWatch Metric?

A CloudWatch metric is identified by its namespace, metric name, and complete set of dimensions.

```text
Namespace
    +
MetricName
    +
Dimensions
```

A metric published under one namespace will not automatically appear when another namespace is queried.

### What Is the Difference Between list-metrics and get-metric-data?

| Command | Purpose |
|---|---|
| `list-metrics` | Discovers metric identities |
| `get-metric-statistics` | Retrieves metric statistics |
| `get-metric-data` | Retrieves metric datapoints using metric queries |

A newly published custom metric may take several minutes to appear in `list-metrics`.

Metric retrieval can sometimes succeed before the metric appears in discovery results.

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
- CloudWatch permissions
- Systems Manager access
- Python 3 for JSON validation
- Git and GitHub

### Security Rules

- Use a dedicated disposable VPC.
- Do not modify production monitoring configurations.
- Use IAM roles instead of static credentials.
- Do not expose unnecessary inbound ports.
- Use Systems Manager for EC2 access.
- Avoid committing confidential infrastructure data.
- Review monitoring evidence before publishing.
- Verify resource ownership before deletion.
- Clean up temporary AWS resources after testing.

### Cost Considerations

Possible charges include:

- EC2 instance usage
- EBS storage
- Public IPv4 address
- CloudWatch custom metrics

CloudWatch Agent metrics are treated as custom metrics.

Stopping publication prevents new datapoints from being sent, although historical metric data may remain available according to CloudWatch retention policies.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab03"

export VPC_CIDR="10.66.0.0/16"
export SUBNET_CIDR="10.66.1.0/24"

export EC2_ROLE_NAME="cloudwatch-lab03-ec2-role"
export PROFILE_NAME="cloudwatch-lab03-instance-profile"

export SG_NAME="cloudwatch-lab03-sg"

export EXPECTED_NAMESPACE="CWAgent"
export WRONG_NAMESPACE="CWAgent-Lab03-Wrong"
export METRIC_NAME="mem_used_percent"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$VPC_CIDR"
echo "$EXPECTED_NAMESPACE"
echo "$WRONG_NAMESPACE"
```

Keep the WSL terminal open to preserve resource identifiers.

---

## 7. Create VPC and Networking

### Step 1 — Create VPC

```bash
export VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications \
  "ResourceType=vpc,Tags=[{Key=Name,Value=cloudwatch-lab03-vpc},{Key=Project,Value=$PROJECT_TAG}]" \
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

Change the Availability Zone if necessary.

### Step 4 — Create Public Subnet

```bash
export SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id "$VPC_ID" \
  --cidr-block "$SUBNET_CIDR" \
  --availability-zone "$AZ" \
  --tag-specifications \
  "ResourceType=subnet,Tags=[{Key=Name,Value=cloudwatch-lab03-public},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region "$AWS_REGION")
```

### Step 5 — Create Internet Gateway

```bash
export IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications \
  "ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudwatch-lab03-igw},{Key=Project,Value=$PROJECT_TAG}]" \
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
  "ResourceType=route-table,Tags=[{Key=Name,Value=cloudwatch-lab03-rt},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'RouteTable.RouteTableId' \
  --output text \
  --region "$AWS_REGION")
```

### Step 7 — Create Default Route

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
  --description "CloudWatch Lab03 metrics troubleshooting" \
  --vpc-id "$VPC_ID" \
  --tag-specifications \
  "ResourceType=security-group,Tags=[{Key=Name,Value=$SG_NAME},{Key=Project,Value=$PROJECT_TAG}]" \
  --query GroupId \
  --output text \
  --region "$AWS_REGION")
```

No inbound access is required.

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

### Step 6 — Verify Policies

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

Both policies are attached before introducing the fault.

### Step 7 — Create Instance Profile

```bash
aws iam create-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --tags Key=Project,Value="$PROJECT_TAG"

aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$EC2_ROLE_NAME"
```

Allow IAM changes to propagate before launching EC2.

---

## 9. Deploy EC2 Instance

### Step 1 — Create User Data

Save as `user-data.sh`:

```bash
#!/bin/bash
set -euxo pipefail

dnf install -y amazon-cloudwatch-agent python3

mkdir -p /opt/cloudwatch-lab03

echo "CloudWatch Lab03 EC2 Metrics Troubleshooting" \
  > /opt/cloudwatch-lab03/README.txt
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
  "ResourceType=instance,Tags=[{Key=Name,Value=cloudwatch-lab03-ec2},{Key=Project,Value=$PROJECT_TAG}]" \
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

### Step 5 — Connect Through Systems Manager

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 6 — Inspect Linux Memory

Inside EC2:

```bash
free -h
```

```bash
cat /proc/meminfo | head -n 10
```

Linux memory information should be available.

### Step 7 — Verify CloudWatch Agent Installation

```bash
rpm -q amazon-cloudwatch-agent
```

If necessary:

```bash
sudo dnf install -y amazon-cloudwatch-agent
```

Exit EC2:

```bash
exit
```

---

## 10. Verify Native EC2 Metrics

### Step 1 — List CPU Metrics

From WSL:

```bash
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Expected: the EC2 CPU utilization metric becomes available after CloudWatch receives the instance's native monitoring data.

### Step 2 — Configure Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 3 — Retrieve CPU Statistics

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 300 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: CPU utilization datapoints once native monitoring begins reporting.

Basic EC2 monitoring commonly publishes metrics at five-minute intervals.

### Step 4 — Search for Native Memory Metric

```bash
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --metric-name mem_used_percent \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Expected: no matching native memory metric.

### Finding

Native EC2 CPU metrics and CloudWatch Agent memory metrics are separate monitoring mechanisms.

Memory utilization must be collected using the CloudWatch Agent or another custom monitoring solution.

---

## 11. Fault Injection — Wrong CloudWatch Namespace

### Step 1 — Connect to EC2

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 2 — Create Broken Agent Configuration

Inside EC2, save as `/opt/cloudwatch-lab03/broken-agent.json`:

```json
{
  "agent": {
    "region": "us-east-1",
    "metrics_collection_interval": 60,
    "debug": true
  },
  "metrics": {
    "namespace": "CWAgent-Lab03-Wrong",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

### Intentional Misconfiguration

The incorrect field is:

```json
"namespace": "CWAgent-Lab03-Wrong"
```

The intended configuration is:

```json
"namespace": "CWAgent"
```

The JSON is syntactically valid.

This is important because the agent should run successfully and publish metrics to the wrong destination.

### Step 3 — Validate JSON

```bash
python3 -m json.tool \
  /opt/cloudwatch-lab03/broken-agent.json
```

Expected: valid JSON output.

### Step 4 — Start CloudWatch Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/cloudwatch-lab03/broken-agent.json
```

### Step 5 — Verify Agent Status

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Expected: running.

### Step 6 — Verify systemd

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 7 — Inspect Agent Logs

```bash
sudo tail -n 60 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

Expected: agent starts collecting and publishing metrics without recurring permission or configuration errors.

### Step 8 — Verify Wrong Namespace

```bash
grep -n '"namespace"' \
  /opt/cloudwatch-lab03/broken-agent.json
```

Expected:

```text
"namespace": "CWAgent-Lab03-Wrong"
```

Exit EC2:

```bash
exit
```

### Fault Injection Summary

| Component | Expected State |
|---|---|
| EC2 | Running |
| IAM Permissions | Correct |
| CloudWatch Agent | Running |
| Agent Configuration | Valid JSON |
| Memory Collection | Enabled |
| Metric Name | Correct |
| InstanceId Dimension | Correct |
| Published Namespace | Incorrect |
| Expected Metric Query | No datapoints |

---

## 12. Reproduce Missing Memory Metrics

### Step 1 — Query Expected Namespace

From WSL:

```bash
aws cloudwatch list-metrics \
  --namespace "$EXPECTED_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Expected: no matching metric for the new instance under `CWAgent`.

### Step 2 — Query Wrong Namespace

```bash
aws cloudwatch list-metrics \
  --namespace "$WRONG_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Expected after metric discovery:

```json
{
  "Metrics": [
    {
      "Namespace": "CWAgent-Lab03-Wrong",
      "MetricName": "mem_used_percent",
      "Dimensions": [
        {
          "Name": "InstanceId",
          "Value": "i-xxxxxxxxxxxxxxxxx"
        }
      ]
    }
  ]
}
```

The instance ID will be different in your environment.

New metrics may take several minutes to appear in `list-metrics`.

### Step 3 — Refresh Query Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 4 — Retrieve Wrong-Namespace Datapoints

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$WRONG_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: numerical memory utilization datapoints.

The values depend on the instance's actual memory usage.

### Step 5 — Retrieve Expected-Namespace Datapoints

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$EXPECTED_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected:

```json
{
  "Label": "mem_used_percent",
  "Datapoints": []
}
```

### Step 6 — Save Wrong-Namespace Evidence

```bash
aws cloudwatch list-metrics \
  --namespace "$WRONG_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION" \
  > lab03-before-wrong-namespace.json
```

### Step 7 — Save Expected-Namespace Evidence

```bash
aws cloudwatch list-metrics \
  --namespace "$EXPECTED_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION" \
  > lab03-before-expected-namespace.json
```

### Step 8 — Save Metric Data Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$WRONG_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION" \
  > lab03-before-metric-data.json
```

### Expected Results

| Query | Expected Result |
|---|---|
| AWS/EC2 CPUUtilization | Datapoints available |
| AWS/EC2 mem_used_percent | Not available by default |
| CWAgent mem_used_percent | Missing |
| CWAgent-Lab03-Wrong mem_used_percent | Available |
| CloudWatch Agent Status | Running |
| Root Cause | Wrong namespace |

---

## 13. Troubleshooting Investigation Using AWS CLI

### Check 1 — Verify EC2 Status

```bash
aws ec2 describe-instance-status \
  --instance-ids "$INSTANCE_ID" \
  --include-all-instances \
  --region "$AWS_REGION"
```

Expected: running instance with passing status checks.

### Check 2 — Verify IAM Permissions

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

### Check 3 — Verify Native CPU Metric

```bash
aws cloudwatch list-metrics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Check 4 — Search for Memory Metric Across Namespaces

```bash
aws cloudwatch list-metrics \
  --metric-name mem_used_percent \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --query 'Metrics[].{Namespace:Namespace,MetricName:MetricName,Dimensions:Dimensions}' \
  --output json \
  --region "$AWS_REGION"
```

This command is particularly useful because it searches for the metric without specifying a namespace.

Expected: the metric is discovered under `CWAgent-Lab03-Wrong`.

### Check 5 — Inspect Agent Configuration

Connect to EC2:

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Inside EC2:

```bash
sudo cat /opt/cloudwatch-lab03/broken-agent.json
```

Inspect:

```json
"namespace": "CWAgent-Lab03-Wrong"
```

### Check 6 — Inspect Agent Logs

```bash
sudo tail -n 50 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

Verify the agent is not reporting recurring metric publishing errors.

### Check 7 — Verify Local Memory Information

```bash
free -h
```

```bash
cat /proc/meminfo | head -n 10
```

Exit EC2:

```bash
exit
```

### Investigation Matrix

| Investigation | Expected Finding |
|---|---|
| EC2 Instance | Healthy |
| Native CPU Monitoring | Available |
| Linux Memory Information | Available |
| IAM Permissions | Correct |
| CloudWatch Agent | Running |
| Agent JSON | Valid |
| Metric Collection | Working |
| Memory Metric Name | Correct |
| Memory Metric Dimension | Correct |
| Published Namespace | Wrong |
| Expected Namespace | CWAgent |
| Root Cause | Namespace misconfiguration |

---

## 14. Root Cause Analysis

### Root Cause

The CloudWatch Agent successfully collected and published Linux memory utilization.

However, its configuration defined the incorrect namespace:

`CWAgent-Lab03-Wrong`

The operations monitoring query expected the metric under:

`CWAgent`

Because CloudWatch treats namespaces as separate metric identities, the query could not retrieve the memory datapoints.

The problem was not caused by EC2 instance health, IAM permissions, or CloudWatch Agent startup failure.

The metric was published successfully, but under an unexpected namespace.

### Root Cause Flow

```text
EC2 Instance
       |
       v
Linux Memory Statistics
       |
       v
CloudWatch Agent
       |
       v
Collects mem_used_percent
       |
       v
Incorrect Namespace
       |
       v
CWAgent-Lab03-Wrong
       |
       v
Metric Published Successfully
       |
       v
Dashboard Queries CWAgent
       |
       v
No Matching Datapoints
       |
       v
Memory Metrics Missing
```

### Five Whys

1. **Why was the memory metric missing?** The expected CloudWatch query returned no datapoints.
2. **Why did the query return no datapoints?** It searched the `CWAgent` namespace.
3. **Why wasn't the metric in that namespace?** The CloudWatch Agent was configured to publish it elsewhere.
4. **Why was the agent still running?** The configuration was syntactically valid and supported.
5. **How was the issue resolved?** The namespace was corrected and the agent configuration was reloaded.

### Root Cause Summary

| Component | Finding |
|---|---|
| AWS Service | Amazon CloudWatch |
| Incident | INC-CW-003 |
| EC2 Instance | Healthy |
| IAM Permissions | Correct |
| CloudWatch Agent | Running |
| Linux Memory Collection | Working |
| Metric Publishing | Working |
| Namespace | Incorrect |
| Root Cause | Wrong metrics namespace |
| Remediation | Correct namespace |
| EC2 Redeployment | Not required |

**Important Lesson:** A metric missing from a dashboard does not necessarily mean the data is not being collected. The metric may exist under another namespace, dimension combination, or AWS Region.

---

## 15. Remediation — Correct the Metrics Namespace

### Step 1 — Connect to EC2

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 2 — Create Corrected Configuration

Inside EC2, save as `/opt/cloudwatch-lab03/cloudwatch-agent.json`:

```json
{
  "agent": {
    "region": "us-east-1",
    "metrics_collection_interval": 60,
    "debug": true
  },
  "metrics": {
    "namespace": "CWAgent",
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
```

### Step 3 — Compare Configurations

Before:

```json
"namespace": "CWAgent-Lab03-Wrong"
```

After:

```json
"namespace": "CWAgent"
```

No IAM or network changes are required.

### Step 4 — Validate JSON

```bash
python3 -m json.tool \
  /opt/cloudwatch-lab03/cloudwatch-agent.json
```

Expected: valid JSON output.

### Step 5 — Reload CloudWatch Agent

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/cloudwatch-lab03/cloudwatch-agent.json
```

### Step 6 — Verify Agent Status

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a status
```

Expected: running.

### Step 7 — Verify systemd

```bash
sudo systemctl status amazon-cloudwatch-agent --no-pager
```

Expected:

```text
Active: active (running)
```

### Step 8 — Inspect Agent Logs

```bash
sudo tail -n 60 \
  /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

Expected: no recurring configuration or metric publishing errors.

### Step 9 — Verify Correct Namespace

```bash
grep -n '"namespace"' \
  /opt/cloudwatch-lab03/cloudwatch-agent.json
```

Expected:

```text
"namespace": "CWAgent"
```

Exit EC2:

```bash
exit
```

---

## 16. Final Verification

### Step 1 — Verify Metric Under Correct Namespace

From WSL:

```bash
aws cloudwatch list-metrics \
  --namespace CWAgent \
  --metric-name mem_used_percent \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Expected: the memory utilization metric appears under `CWAgent` after metric discovery updates.

### Step 2 — Refresh Query Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 3 — Retrieve Memory Datapoints

```bash
aws cloudwatch get-metric-statistics \
  --namespace CWAgent \
  --metric-name mem_used_percent \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Average \
  --region "$AWS_REGION"
```

Expected: new numerical memory utilization datapoints.

### Step 4 — Create Metric Query File

Save as `metric-query.json` in WSL:

```json
[
  {
    "Id": "memory_usage",
    "MetricStat": {
      "Metric": {
        "Namespace": "CWAgent",
        "MetricName": "mem_used_percent",
        "Dimensions": [
          {
            "Name": "InstanceId",
            "Value": "REPLACE_WITH_YOUR_INSTANCE_ID"
          }
        ]
      },
      "Period": 60,
      "Stat": "Average"
    },
    "ReturnData": true
  }
]
```

Replace `REPLACE_WITH_YOUR_INSTANCE_ID` with the actual EC2 instance ID.

Alternatively, generate the JSON using your existing `$INSTANCE_ID` variable.

### Step 5 — Retrieve Metric Data

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://metric-query.json \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --region "$AWS_REGION"
```

Expected: at least one valid memory metric datapoint after publishing begins.

### Step 6 — Save Corrected Metric Evidence

```bash
aws cloudwatch list-metrics \
  --namespace CWAgent \
  --metric-name mem_used_percent \
  --dimensions "Name=InstanceId,Value=$INSTANCE_ID" \
  --region "$AWS_REGION" \
  > lab03-after-metric.json
```

### Step 7 — Save Metric Data Evidence

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://metric-query.json \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --region "$AWS_REGION" \
  > lab03-after-metric-data.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| EC2 Instance | Running | Running |
| IAM Permissions | Correct | Correct |
| CloudWatch Agent | Running | Running |
| Native CPU Metric | Available | Available |
| Memory Collection | Enabled | Enabled |
| Metric Name | Correct | Correct |
| InstanceId Dimension | Correct | Correct |
| Metrics Namespace | Incorrect | Correct |
| Memory Metric in CWAgent | Missing | Available |
| New Memory Datapoints | Wrong namespace | CWAgent |
| Monitoring Query | No data | Data available |
| Incident | Active | Resolved |

### Final Verification Criteria

The incident is resolved when:

1. The EC2 instance is healthy.
2. The CloudWatch Agent is running.
3. The configuration uses the intended `CWAgent` namespace.
4. The `mem_used_percent` metric appears under `CWAgent`.
5. The metric has the correct `InstanceId` dimension.
6. `get-metric-statistics` or `get-metric-data` returns new datapoints.
7. The monitoring query can retrieve memory utilization successfully.

The historical metric series in the incorrect namespace may remain visible after remediation. The corrected configuration prevents further publication to that namespace.

---

## 17. Production Troubleshooting Best Practices

### Missing Metrics Troubleshooting Checklist

1. Verify EC2 instance health.
2. Check the AWS Region.
3. Identify whether the metric is native or agent-collected.
4. Verify the metric namespace.
5. Verify the metric name.
6. Inspect metric dimensions.
7. Check the metric time range.
8. Verify the CloudWatch Agent is installed.
9. Inspect CloudWatch Agent status.
10. Review the agent configuration.
11. Verify IAM permissions.
12. Check agent logs for errors.
13. Confirm metric collection intervals.
14. Search for the metric across namespaces.
15. Retrieve metric datapoints directly.
16. Correct the configuration.
17. Reload the CloudWatch Agent.
18. Confirm successful publishing.
19. Verify monitoring dashboard queries.
20. Document the root cause and recovery.

### Common CloudWatch Metric Problems

| Symptom | Possible Cause |
|---|---|
| CPU metric missing | Wrong Region, instance ID, or monitoring window |
| Memory metric missing | CloudWatch Agent not installed or configured |
| Agent running but metric missing | Namespace or dimensions mismatch |
| Metric exists but no datapoints | Incorrect time range or dimensions |
| AccessDenied error | Missing `cloudwatch:PutMetricData` permission |
| Metric in wrong namespace | Incorrect agent configuration |
| New metric not immediately visible | Metric discovery delay |
| Memory collection stopped | CloudWatch Agent stopped |
| Disk metric missing | Incorrect disk collection settings |
| Dashboard shows no data | Query does not match metric identity |

### Security Recommendations

- Use IAM roles for CloudWatch Agent authentication.
- Grant only the metric publishing permissions required.
- Avoid static AWS credentials.
- Use Systems Manager instead of exposing SSH.
- Store agent configurations in version control.
- Review monitoring changes before production deployment.
- Limit unnecessary high-cardinality custom metrics.
- Monitor unexpected telemetry gaps.
- Apply resource tags consistently.
- Remove unused monitoring resources after testing.

### Monitoring Recommendations

Production systems should distinguish between:

**Monitoring pipeline failure:** The application or agent fails to publish telemetry.

**Monitoring query failure:** Telemetry is published, but dashboards and alarms query the wrong metric identity.

This lab demonstrates the second situation.

---

## 18. AWS Resource Cleanup

**Warning:** Verify that all resources belong to Lab 03 before deleting anything.

### Step 1 — Stop CloudWatch Agent

Connect to EC2:

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

Inside EC2:

```bash
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -m ec2 \
  -a stop
```

Verify:

```bash
sudo systemctl is-active amazon-cloudwatch-agent
```

Expected: inactive.

Exit:

```bash
exit
```

### Step 2 — Verify Root EBS Volume

From WSL:

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings' \
  --output json \
  --region "$AWS_REGION"
```

Confirm the root volume has `DeleteOnTermination=true`.

### Step 3 — Terminate EC2

```bash
aws ec2 terminate-instances \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"

aws ec2 wait instance-terminated \
  --instance-ids "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 4 — Verify IAM Role Ownership

```bash
aws iam list-role-tags \
  --role-name "$EC2_ROLE_NAME"
```

Confirm the role belongs to Lab 03.

### Step 5 — Detach CloudWatch Agent Policy

```bash
aws iam detach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
```

### Step 6 — Detach Systems Manager Policy

```bash
aws iam detach-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
```

### Step 7 — Delete Instance Profile

```bash
aws iam remove-role-from-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$EC2_ROLE_NAME"

aws iam delete-instance-profile \
  --instance-profile-name "$PROFILE_NAME"
```

### Step 8 — Delete IAM Role

```bash
aws iam delete-role \
  --role-name "$EC2_ROLE_NAME"
```

### Step 9 — Verify Network Interface Removal

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'NetworkInterfaces[].{ID:NetworkInterfaceId,Status:Status}' \
  --output table \
  --region "$AWS_REGION"
```

Wait until the instance network interface is removed.

### Step 10 — Delete Security Group

```bash
aws ec2 delete-security-group \
  --group-id "$SG_ID" \
  --region "$AWS_REGION"
```

### Step 11 — Disassociate Route Table

```bash
aws ec2 disassociate-route-table \
  --association-id "$RT_ASSOC_ID" \
  --region "$AWS_REGION"
```

### Step 12 — Delete Route Table

```bash
aws ec2 delete-route-table \
  --route-table-id "$RT_ID" \
  --region "$AWS_REGION"
```

### Step 13 — Delete Subnet

```bash
aws ec2 delete-subnet \
  --subnet-id "$SUBNET_ID" \
  --region "$AWS_REGION"
```

### Step 14 — Detach Internet Gateway

```bash
aws ec2 detach-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION"
```

### Step 15 — Delete Internet Gateway

```bash
aws ec2 delete-internet-gateway \
  --internet-gateway-id "$IGW_ID" \
  --region "$AWS_REGION"
```

### Step 16 — Delete VPC

```bash
aws ec2 delete-vpc \
  --vpc-id "$VPC_ID" \
  --region "$AWS_REGION"
```

### Step 17 — Verify Final Cleanup

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

Also verify that the EC2 instance, EBS volume, IAM role, and instance profile are removed.

### CloudWatch Metrics Cleanup Note

CloudWatch does not provide a direct API to delete an individual metric series.

After the agent stops publishing, new custom metric datapoints will no longer be sent.

Previously published data remains subject to CloudWatch metric retention.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| CloudWatch Agent | Stopped |
| EC2 Instance | Terminated |
| Root EBS Volume | Deleted |
| IAM Role | Deleted |
| Instance Profile | Deleted |
| Security Group | Deleted |
| Route Table | Deleted |
| Public Subnet | Deleted |
| Internet Gateway | Deleted |
| Lab VPC | Deleted |
| New Custom Metric Publishing | Stopped |
| Historical Metric Data | Retained until normal expiration |
| Default VPC | Unchanged |

---

## 19. Interview Questions and Answers

### Q1. Does Amazon EC2 automatically publish memory metrics?

No. Native EC2 monitoring does not include operating-system memory utilization. The CloudWatch Agent or another monitoring solution is required.

### Q2. What is the default CloudWatch Agent metrics namespace?

`CWAgent`.

### Q3. What is a CloudWatch namespace?

A logical container used to organize metrics.

### Q4. What is a metric dimension?

A name/value pair that identifies a CloudWatch metric series.

### Q5. Why might memory metrics appear missing even if the CloudWatch Agent is running?

The metric may be published under a different namespace, with incorrect dimensions, or in another AWS Region.

### Q6. How can you search for a metric across namespaces?

```bash
aws cloudwatch list-metrics \
  --metric-name mem_used_percent \
  --region us-east-1
```

### Q7. What is the difference between list-metrics and get-metric-data?

`list-metrics` discovers metric identities.

`get-metric-data` retrieves metric datapoints for a specified query and time range.

### Q8. Which IAM permission allows publishing custom metrics?

`cloudwatch:PutMetricData`.

### Q9. What does mem_used_percent measure?

The percentage of memory utilization calculated from operating-system memory information.

### Q10. What caused this lab's missing memory metric?

The CloudWatch Agent published `mem_used_percent` under `CWAgent-Lab03-Wrong`, but monitoring queries expected `CWAgent`.

### Q11. Why did native CPU metrics still work?

Native EC2 metrics are published independently of the CloudWatch Agent's custom memory metric configuration.

### Q12. How would you explain this lab in an interview?

I deployed an Amazon Linux EC2 instance and installed the CloudWatch Agent to collect Linux memory utilization.

I intentionally configured the agent to publish metrics under an incorrect CloudWatch namespace.

The EC2 instance and CloudWatch Agent were running, and the IAM permissions were correct.

However, the monitoring query could not find memory utilization under the expected namespace.

I investigated native EC2 metrics, CloudWatch Agent metrics, IAM permissions, namespaces, dimensions, and metric datapoints using AWS CLI.

I discovered that the memory metric was being published successfully, but under the wrong namespace.

I corrected the CloudWatch Agent configuration, reloaded the agent, and verified that new memory utilization datapoints appeared under `CWAgent`.

Finally, I stopped metric publishing, removed the temporary AWS resources, and documented the incident.

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
│   ├── README.md
│   ├── ec2-trust-policy.json
│   ├── user-data.sh
│   ├── broken-agent.json
│   ├── cloudwatch-agent.json
│   ├── metric-query.json
│   ├── lab03-before-wrong-namespace.json
│   ├── lab03-before-expected-namespace.json
│   ├── lab03-before-metric-data.json
│   ├── lab03-after-metric.json
│   └── lab03-after-metric-data.json
│
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
| `ec2-trust-policy.json` | IAM trust policy for EC2 |
| `user-data.sh` | Installs CloudWatch Agent |
| `broken-agent.json` | Incorrect namespace configuration |
| `cloudwatch-agent.json` | Corrected namespace configuration |
| `metric-query.json` | CloudWatch metric retrieval query |
| `lab03-before-wrong-namespace.json` | Captures metric under incorrect namespace |
| `lab03-before-expected-namespace.json` | Captures missing expected metric |
| `lab03-before-metric-data.json` | Captures memory datapoints before remediation |
| `lab03-after-metric.json` | Captures corrected metric identity |
| `lab03-after-metric-data.json` | Captures memory datapoints after remediation |

### Evidence Guidelines

Save real AWS CLI outputs rather than example results.

The CloudWatch Agent configuration files are initially created inside EC2. Save copies locally before terminating the instance.

Do not publish confidential infrastructure information or credentials.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how a CloudWatch metric can appear missing even when it is being collected and published successfully.

We created a custom AWS VPC and deployed an Amazon Linux EC2 instance.

We verified that native EC2 CPU metrics were available through the `AWS/EC2` namespace.

We also confirmed that memory utilization was not included in native EC2 monitoring.

We installed the CloudWatch Agent and configured it to collect Linux memory utilization.

However, we intentionally configured the agent to use the incorrect namespace `CWAgent-Lab03-Wrong`.

The agent started successfully and published memory metric datapoints under that namespace.

When we queried the expected `CWAgent` namespace, no matching memory datapoints were found.

We investigated the problem using AWS CLI commands, IAM policy inspection, metric namespaces, dimensions, and CloudWatch Agent configuration.

We identified the incorrect namespace as the root cause.

After correcting the configuration and reloading the agent, new memory datapoints appeared under the intended namespace.

The exercise showed that engineers must distinguish between metric collection failures and metric query misconfigurations.

**Key Lesson:** When a CloudWatch metric appears missing, verify the complete metric identity, including namespace, metric name, dimensions, AWS Region, and time range, before assuming the agent or infrastructure has failed.

### Skills Demonstrated

- Amazon CloudWatch Metrics
- Native EC2 monitoring
- CloudWatch Agent
- EC2 memory monitoring
- CloudWatch namespaces
- CloudWatch metric dimensions
- CloudWatch custom metrics
- `mem_used_percent`
- `CPUUtilization`
- AWS CLI list-metrics
- AWS CLI get-metric-statistics
- AWS CLI get-metric-data
- CloudWatch Agent JSON configuration
- Amazon EC2
- Amazon VPC
- AWS IAM
- IAM instance profiles
- AWS Systems Manager
- Linux memory troubleshooting
- Linux Bash
- Python JSON validation
- Root cause analysis
- Monitoring configuration remediation
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-003 |
| Scenario | EC2 Metrics Missing |
| EC2 Instance | Running |
| Native CPU Metrics | Available |
| Linux Memory Information | Available |
| CloudWatch Agent | Running |
| IAM Permissions | Correct |
| Memory Metric Collection | Working |
| Initial Namespace | CWAgent-Lab03-Wrong |
| Expected Namespace | CWAgent |
| Root Cause | Incorrect metric namespace |
| Remediation | Correct namespace |
| Agent Restart | Successful |
| Corrected Memory Metric | Available under CWAgent |
| New Metric Datapoints | Successfully published |
| EC2 Redeployment | Not required |
| Cleanup | Temporary AWS resources removed |
| Incident Status | Resolved after verification |

**Key Takeaway:** CloudWatch monitoring depends on accurate metric configuration and queries. A running agent does not guarantee that dashboards are requesting the correct metric. Engineers must understand namespaces, dimensions, and metric identities to troubleshoot missing metrics effectively.

---

## Official AWS Documentation

- [Amazon CloudWatch Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/working_with_metrics.html)
- [CloudWatch Agent Configuration File Details](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html)
- [CloudWatch Agent Configuration Examples](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/create-cloudwatch-agent-configuration-file-examples.html)
- [AWS CLI — list-metrics](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/list-metrics.html)
- [AWS CLI — get-metric-statistics](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-statistics.html)
- [AWS CLI — get-metric-data](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-data.html)