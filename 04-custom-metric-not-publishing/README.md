# Lab 04 — CloudWatch Custom Metric Not Publishing

## Overview

This lab demonstrates how to troubleshoot an Amazon CloudWatch custom metric publishing failure caused by missing IAM permissions on an EC2 instance.

We deploy an Amazon Linux 2023 EC2 instance inside a dedicated AWS VPC and configure a Python application using Boto3 to publish custom application metrics.

The application simulates failed payment requests and attempts to publish the `PaymentFailures` metric to Amazon CloudWatch.

The intended metric namespace is:

`CloudWatchLab04/Payments`

However, we intentionally configure the EC2 instance role without the `cloudwatch:PutMetricData` permission.

When the Python application attempts to publish the metric, AWS rejects the request with an authorization error.

Although Python, Boto3, and the EC2 instance are functioning correctly, the custom metric does not appear in CloudWatch.

We investigate the problem using AWS CLI, IAM policies, EC2 instance profiles, Boto3 error handling, CloudWatch metric queries, and IAM authorization testing.

After identifying the missing permission, we create a least-privilege IAM policy that permits metric publishing only to the intended namespace.

We attach the policy to the EC2 role, rerun the Python application, and verify that custom metric datapoints are successfully published.

Finally, we remove all temporary AWS resources.

**Troubleshooting Workflow:**

Infrastructure Setup → EC2 Deployment → Python Application → Custom Metric Publishing → IAM AccessDenied → AWS CLI Investigation → Root Cause Analysis → Least-Privilege IAM Remediation → Metric Publication → Verification → Cleanup

---

## 1. Lab Information

| Item | Configuration |
|---|---|
| Incident ID | INC-CW-004 |
| Difficulty | Intermediate |
| AWS Region | `us-east-1` |
| AWS Services | CloudWatch, EC2, IAM, VPC, Systems Manager |
| Local Environment | WSL Ubuntu |
| Operating System | Amazon Linux 2023 |
| EC2 Instance Type | `t3.micro` |
| VPC CIDR | `10.67.0.0/16` |
| Public Subnet | `10.67.1.0/24` |
| Application Language | Python 3 |
| AWS SDK | Boto3 |
| API Operation | `PutMetricData` |
| Metric Namespace | `CloudWatchLab04/Payments` |
| Metric Name | `PaymentFailures` |
| Metric Dimensions | `Environment=Lab04`, `Service=PaymentAPI` |
| Metric Unit | Count |
| Storage Resolution | 60 seconds |
| Initial IAM Policy | AmazonSSMManagedInstanceCore |
| Missing Permission | `cloudwatch:PutMetricData` |
| Fault Injection | IAM permission intentionally omitted |
| Expected Failure | AccessDenied |
| Root Cause | Missing metric publishing permission |
| Remediation | Add namespace-scoped IAM policy |
| Verification | Boto3, IAM Policy Simulator, AWS CLI |
| Expected Recovery | Custom metric successfully published |

---

## 2. Production Incident Scenario

### Incident Description

A company operates a payment processing application on Amazon EC2.

The application uses Python and Boto3 to publish custom operational metrics to Amazon CloudWatch.

One important metric is `PaymentFailures`, which measures the number of simulated failed payment requests.

The operations team uses this metric to monitor payment processing errors and investigate application reliability issues.

However, the team notices that the custom metric is missing from CloudWatch.

The Python application runs successfully, and Boto3 can obtain temporary AWS credentials from the EC2 instance role.

The AWS Region, metric name, namespace, and dimensions are correctly configured.

Despite this, the application receives an authorization error when attempting to publish metric data.

A Cloud Engineer investigates the EC2 instance profile and discovers that its IAM role contains only Systems Manager permissions.

The role does not have permission to call the CloudWatch `PutMetricData` API.

The engineer must correct the IAM permissions and confirm that the metric is successfully published.

### Incident Symptoms

- EC2 instance is running.
- Python 3 is installed.
- Boto3 is installed.
- Python application executes.
- Temporary AWS credentials are available.
- EC2 IAM role is correctly attached.
- Metric namespace is correct.
- Metric name is correct.
- Metric dimensions are correct.
- `PutMetricData` returns AccessDenied.
- CloudWatch custom metric is missing.
- No successful datapoints are available.

### Business Impact

- Operations teams cannot monitor application-specific failures.
- Application monitoring dashboards may show incomplete information.
- CloudWatch alarms may receive no metric data.
- Payment processing problems may go undetected.
- Incident response teams may lack useful application telemetry.
- Engineers may incorrectly assume the application is not generating monitoring data.

### Objective

Identify why the Python application cannot publish custom metrics, determine the missing IAM permission, apply a least-privilege correction, and verify successful metric publication.

---

## 3. AWS Architecture

### Infrastructure Architecture

```text
                       AWS Region
                        us-east-1
                            |
                            v
                        Amazon VPC
                      10.67.0.0/16
                            |
                            v
                       Public Subnet
                      10.67.1.0/24
                            |
                            v
                       EC2 Instance
                    Amazon Linux 2023
                            |
                            v
                      Python 3 + Boto3
                            |
                            v
                      PaymentFailures
                            |
                            v
                     PutMetricData API
                            |
                            v
                       EC2 IAM Role
                            |
                            v
                       Amazon CloudWatch
                            |
                            v
                       Custom Namespace
                   CloudWatchLab04/Payments
                            |
                            v
                       Metric Datapoints
```

### Architecture Before Remediation

```text
Python Application
       |
       v
Boto3 CloudWatch Client
       |
       v
PutMetricData Request
       |
       v
EC2 Instance Role
       |
       v
IAM Authorization Check
       |
       v
Missing cloudwatch:PutMetricData
       |
       v
AccessDenied
       |
       v
Metric Not Published
       |
       v
CloudWatch Has No Datapoints
```

### Architecture After Remediation

```text
Python Application
       |
       v
Boto3 CloudWatch Client
       |
       v
PutMetricData Request
       |
       v
EC2 IAM Role
       |
       v
Least-Privilege IAM Policy
       |
       v
PutMetricData Allowed
       |
       v
Amazon CloudWatch
       |
       v
CloudWatchLab04/Payments
       |
       v
PaymentFailures
       |
       v
Metric Datapoints Available
```

### Network Configuration

| Component | Configuration |
|---|---|
| VPC | `10.67.0.0/16` |
| Public Subnet | `10.67.1.0/24` |
| Internet Gateway | Attached |
| Default Route | `0.0.0.0/0` |
| EC2 Operating System | Amazon Linux 2023 |
| EC2 Public IP | Assigned |
| Inbound SSH | Not required |
| EC2 Management | AWS Systems Manager |
| CloudWatch API Connectivity | Outbound HTTPS |
| AWS Credentials | EC2 IAM Role |

No inbound SSH or HTTP access is required.

---

## 4. Understanding CloudWatch Custom Metrics

### What Is a CloudWatch Custom Metric?

A custom metric is a numerical measurement published to CloudWatch by an application or user.

Unlike native AWS service metrics, custom metrics are created and published by the application or monitoring system.

Examples include:

- Failed payment requests
- Successful login attempts
- Application errors
- Queue processing time
- Failed API requests
- Business transaction counts

### What Is PutMetricData?

`PutMetricData` is a CloudWatch API operation that allows applications to publish custom metric datapoints.

The corresponding IAM permission is:

`cloudwatch:PutMetricData`

### What Is Boto3?

Boto3 is the AWS SDK for Python.

It allows Python applications to interact with AWS services using API calls.

Example:

```python
import boto3

cloudwatch = boto3.client(
    "cloudwatch",
    region_name="us-east-1"
)
```

### What Is a Metric Namespace?

A namespace organizes related CloudWatch metrics.

This lab uses:

`CloudWatchLab04/Payments`

### What Is a Metric Name?

A metric name identifies the measurement being published.

This lab uses:

`PaymentFailures`

### What Are Metric Dimensions?

Dimensions are name/value pairs that distinguish metric series.

This lab uses:

```text
Environment = Lab04
Service     = PaymentAPI
```

### What Identifies a CloudWatch Metric?

CloudWatch identifies a metric using:

```text
Namespace
    +
MetricName
    +
Dimensions
```

The full dimension set must match when retrieving a particular metric series.

### What Is the Count Unit?

The `Count` unit represents a numerical count.

For this lab, a datapoint value of `3` represents three simulated failed payment requests.

No real payment processing is performed.

### What Is Authentication?

Authentication determines the AWS identity making an API request.

An EC2 instance can obtain temporary credentials from its IAM role.

### What Is Authorization?

Authorization determines whether that AWS identity is allowed to perform an action.

An application can have valid AWS credentials and still receive AccessDenied.

### Why Is Least Privilege Important?

Least privilege means granting only the permissions required for a specific task.

Our Python application needs permission to publish a metric to one namespace.

It does not require broad CloudWatch administrative permissions.

---

## 5. Prerequisites and Safety

### Requirements

- AWS account
- AWS CLI v2
- WSL Ubuntu
- Bash
- Python 3
- Boto3
- EC2 permissions
- IAM permissions
- CloudWatch permissions
- VPC permissions
- Systems Manager access
- Git and GitHub

### Security Rules

- Use disposable AWS infrastructure.
- Do not modify production IAM roles.
- Do not store AWS access keys in Python code.
- Use an EC2 instance profile.
- Restrict IAM permissions to the required operations.
- Avoid exposing inbound management ports.
- Do not publish sensitive information.
- Review evidence files before committing them.
- Delete temporary AWS resources after testing.

### Cost Considerations

Potential charges include:

- EC2 instance usage
- EBS storage
- Public IPv4 address
- CloudWatch custom metrics

This lab publishes only a small number of simulated metric datapoints.

Historical CloudWatch metric data may remain available after the EC2 instance is terminated.

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

export PROJECT_TAG="CloudWatch-Troubleshooting-Lab04"

export VPC_CIDR="10.67.0.0/16"
export SUBNET_CIDR="10.67.1.0/24"

export EC2_ROLE_NAME="cloudwatch-lab04-ec2-role"
export PROFILE_NAME="cloudwatch-lab04-instance-profile"

export SG_NAME="cloudwatch-lab04-sg"

export METRIC_NAMESPACE="CloudWatchLab04/Payments"
export METRIC_NAME="PaymentFailures"

export INLINE_POLICY_NAME="cloudwatch-lab04-publish-metric"
```

### Step 3 — Verify Variables

```bash
echo "$AWS_REGION"
echo "$PROJECT_TAG"
echo "$VPC_CIDR"
echo "$METRIC_NAMESPACE"
echo "$METRIC_NAME"
```

Keep the WSL terminal open to preserve AWS resource identifiers.

---

## 7. Create VPC and Networking

### Step 1 — Create VPC

```bash
export VPC_ID=$(aws ec2 create-vpc \
  --cidr-block "$VPC_CIDR" \
  --tag-specifications \
  "ResourceType=vpc,Tags=[{Key=Name,Value=cloudwatch-lab04-vpc},{Key=Project,Value=$PROJECT_TAG}]" \
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

Choose a supported zone:

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
  "ResourceType=subnet,Tags=[{Key=Name,Value=cloudwatch-lab04-public},{Key=Project,Value=$PROJECT_TAG}]" \
  --query 'Subnet.SubnetId' \
  --output text \
  --region "$AWS_REGION")
```

### Step 5 — Create Internet Gateway

```bash
export IGW_ID=$(aws ec2 create-internet-gateway \
  --tag-specifications \
  "ResourceType=internet-gateway,Tags=[{Key=Name,Value=cloudwatch-lab04-igw},{Key=Project,Value=$PROJECT_TAG}]" \
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
  "ResourceType=route-table,Tags=[{Key=Name,Value=cloudwatch-lab04-rt},{Key=Project,Value=$PROJECT_TAG}]" \
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
  --description "CloudWatch Lab04 metrics publisher" \
  --vpc-id "$VPC_ID" \
  --tag-specifications \
  "ResourceType=security-group,Tags=[{Key=Name,Value=$SG_NAME},{Key=Project,Value=$PROJECT_TAG}]" \
  --query GroupId \
  --output text \
  --region "$AWS_REGION")
```

No inbound rules are required.

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

Do not grant CloudWatch metric publishing permissions yet.

### Step 5 — Create Instance Profile

```bash
aws iam create-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --tags Key=Project,Value="$PROJECT_TAG"

aws iam add-role-to-instance-profile \
  --instance-profile-name "$PROFILE_NAME" \
  --role-name "$EC2_ROLE_NAME"
```

### Step 6 — Verify Attached IAM Policies

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output table
```

Expected:

```text
AmazonSSMManagedInstanceCore
```

### Step 7 — Verify Inline Policies

```bash
aws iam list-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json
```

Expected:

```json
{
  "PolicyNames": []
}
```

The missing `cloudwatch:PutMetricData` permission is our intentional fault.

---

## 9. Create Python Custom Metric Publisher

### Step 1 — Create Python Script

Save as `publish_metric.py`:

```python
#!/usr/bin/env python3

import argparse
import sys

import boto3
from botocore.exceptions import ClientError, BotoCoreError

REGION = "us-east-1"
NAMESPACE = "CloudWatchLab04/Payments"
METRIC_NAME = "PaymentFailures"


def publish_metric(value):
    client = boto3.client(
        "cloudwatch",
        region_name=REGION
    )

    try:
        client.put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[
                {
                    "MetricName": METRIC_NAME,
                    "Value": float(value),
                    "Unit": "Count",
                    "Dimensions": [
                        {
                            "Name": "Environment",
                            "Value": "Lab04"
                        },
                        {
                            "Name": "Service",
                            "Value": "PaymentAPI"
                        }
                    ],
                    "StorageResolution": 60
                }
            ]
        )

        print(
            f"SUCCESS: Published {METRIC_NAME}={value}"
        )

    except ClientError as error:
        code = error.response["Error"]["Code"]
        message = error.response["Error"]["Message"]

        print(f"ERROR: {code}")
        print(message)

        sys.exit(1)

    except BotoCoreError as error:
        print(f"AWS SDK ERROR: {error}")
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--value",
        type=float,
        default=3.0
    )

    args = parser.parse_args()

    publish_metric(args.value)
```

### Python Code Explanation

| Code | Purpose |
|---|---|
| `import boto3` | Loads AWS SDK |
| `boto3.client()` | Creates CloudWatch client |
| `put_metric_data()` | Publishes metric datapoints |
| `Namespace` | Defines custom metric namespace |
| `MetricName` | Identifies the metric |
| `Value` | Numerical measurement |
| `Unit` | Specifies Count |
| `Dimensions` | Identifies environment and service |
| `ClientError` | Captures AWS API errors |
| `sys.exit(1)` | Indicates application failure |

### Step 2 — Validate Python Syntax

From WSL:

```bash
python3 -m py_compile publish_metric.py
```

Expected: no syntax errors.

The application will be executed on EC2 after deployment.

---

## 10. Deploy EC2 with Python and Boto3

### Step 1 — Create User Data

Save as `user-data.sh`:

```bash
#!/bin/bash
set -euxo pipefail

dnf install -y python3 python3-pip

mkdir -p /opt/cloudwatch-lab04

python3 -m venv /opt/cloudwatch-lab04/venv

/opt/cloudwatch-lab04/venv/bin/pip install boto3

cat > /opt/cloudwatch-lab04/publish_metric.py <<'PYTHON'
#!/usr/bin/env python3

import argparse
import sys

import boto3
from botocore.exceptions import ClientError, BotoCoreError

REGION = "us-east-1"
NAMESPACE = "CloudWatchLab04/Payments"
METRIC_NAME = "PaymentFailures"

def publish_metric(value):
    client = boto3.client("cloudwatch", region_name=REGION)

    try:
        client.put_metric_data(
            Namespace=NAMESPACE,
            MetricData=[
                {
                    "MetricName": METRIC_NAME,
                    "Value": float(value),
                    "Unit": "Count",
                    "Dimensions": [
                        {"Name": "Environment", "Value": "Lab04"},
                        {"Name": "Service", "Value": "PaymentAPI"}
                    ],
                    "StorageResolution": 60
                }
            ]
        )

        print(f"SUCCESS: Published {METRIC_NAME}={value}")

    except ClientError as error:
        print("ERROR:", error.response["Error"]["Code"])
        print(error.response["Error"]["Message"])
        sys.exit(1)

    except BotoCoreError as error:
        print("AWS SDK ERROR:", error)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--value", type=float, default=3.0)
    args = parser.parse_args()
    publish_metric(args.value)
PYTHON

chmod 755 /opt/cloudwatch-lab04/publish_metric.py
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
  "ResourceType=instance,Tags=[{Key=Name,Value=cloudwatch-lab04-ec2},{Key=Project,Value=$PROJECT_TAG}]" \
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

### Step 6 — Verify Python

Inside EC2:

```bash
/opt/cloudwatch-lab04/venv/bin/python --version
```

### Step 7 — Verify Boto3

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  -c "import boto3; print(boto3.__version__)"
```

### Step 8 — Verify Python Script

```bash
ls -l /opt/cloudwatch-lab04/publish_metric.py
```

Expected: the application script exists.

If user data has not completed, inspect:

```bash
sudo tail -n 60 /var/log/cloud-init-output.log
```

---

## 11. Fault Injection — Custom Metric Publishing Failure

### Step 1 — Verify Application Configuration

Inside EC2:

```bash
grep -E "REGION|NAMESPACE|METRIC_NAME" \
  /opt/cloudwatch-lab04/publish_metric.py
```

Expected:

```text
REGION = "us-east-1"
NAMESPACE = "CloudWatchLab04/Payments"
METRIC_NAME = "PaymentFailures"
```

### Step 2 — Attempt Metric Publishing

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 3
```

Expected: an authorization error indicating the role is not permitted to call `cloudwatch:PutMetricData`.

Example:

```text
ERROR: AccessDenied
User: arn:aws:sts::ACCOUNT_ID:assumed-role/cloudwatch-lab04-ec2-role/...
is not authorized to perform: cloudwatch:PutMetricData
```

The exact error code and message may vary.

### Step 3 — Verify Application Exit Code

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 5

echo "Exit code: $?"
```

Expected:

```text
Exit code: 1
```

### Step 4 — Capture Failure Evidence

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 3 \
  > /tmp/lab04-publish-before.txt 2>&1

echo "Exit code: $?"

cat /tmp/lab04-publish-before.txt
```

Expected: the error output contains the denied CloudWatch API operation.

### Step 5 — Verify Credential Availability

```bash
/opt/cloudwatch-lab04/venv/bin/python - <<'PY'
import boto3

session = boto3.Session(region_name="us-east-1")

credentials = session.get_credentials()

print("Credentials available:", credentials is not None)

if credentials is not None:
    print("Credential method:", credentials.method)
PY
```

Expected: credentials are available from the EC2 role.

Do not print credential secrets.

### Step 6 — Verify AWS Identity

```bash
/opt/cloudwatch-lab04/venv/bin/python - <<'PY'
import boto3

sts = boto3.client("sts", region_name="us-east-1")

identity = sts.get_caller_identity()

print("Account:", identity["Account"])
print("ARN:", identity["Arn"])
PY
```

Expected: an assumed-role ARN associated with `cloudwatch-lab04-ec2-role`.

### Step 7 — Exit EC2

```bash
exit
```

### Fault Injection Summary

| Component | Expected Finding |
|---|---|
| EC2 Instance | Running |
| Python | Working |
| Boto3 | Installed |
| Temporary AWS Credentials | Available |
| IAM Role Identity | Correct |
| Metric Namespace | Correct |
| Metric Name | Correct |
| Metric Dimensions | Correct |
| PutMetricData Permission | Missing |
| Metric Publishing | Failed |
| Error | AccessDenied |
| CloudWatch Datapoints | Missing |

---

## 12. Investigate Using AWS CLI

### Check 1 — Verify Instance Profile

From WSL:

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
  --output text \
  --region "$AWS_REGION"
```

Expected: the correct Lab 04 instance profile ARN.

### Check 2 — Inspect Attached IAM Policies

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output table
```

Expected:

```text
AmazonSSMManagedInstanceCore
```

### Check 3 — Inspect Inline Policies

```bash
aws iam list-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json
```

Expected:

```json
{
  "PolicyNames": []
}
```

### Check 4 — Search for Custom Metric

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --output json \
  --region "$AWS_REGION"
```

Expected for a new lab:

```json
{
  "Metrics": []
}
```

### Check 5 — Configure Metric Query Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Check 6 — Query Metric Datapoints

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --region "$AWS_REGION"
```

Expected:

```json
{
  "Label": "PaymentFailures",
  "Datapoints": []
}
```

### Check 7 — Retrieve IAM Role ARN

```bash
export ROLE_ARN=$(aws iam get-role \
  --role-name "$EC2_ROLE_NAME" \
  --query 'Role.Arn' \
  --output text)
```

### Check 8 — Simulate IAM Authorization

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$ROLE_ARN" \
  --action-names cloudwatch:PutMetricData \
  --resource-arns "*" \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision}' \
  --output table
```

Expected:

```text
cloudwatch:PutMetricData    implicitDeny
```

The IAM Policy Simulator checks the role's policy evaluation but does not fully replace testing the actual API operation.

The command also requires appropriate IAM simulation permissions.

### Check 9 — Save Attached Policy Evidence

```bash
aws iam list-attached-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json \
  > lab04-before-iam.json
```

### Check 10 — Save Inline Policy Evidence

```bash
aws iam list-role-policies \
  --role-name "$EC2_ROLE_NAME" \
  --output json \
  > lab04-before-inline-policies.json
```

### Check 11 — Save Missing Metric Evidence

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --output json \
  --region "$AWS_REGION" \
  > lab04-before-metric.json
```

### Check 12 — Save Missing Datapoint Evidence

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum \
  --region "$AWS_REGION" \
  > lab04-before-metric-data.json
```

### Investigation Matrix

| Investigation | Expected Finding |
|---|---|
| EC2 | Healthy |
| Python | Working |
| Boto3 | Installed |
| AWS Credentials | Available |
| EC2 IAM Role | Correctly attached |
| Namespace | Correct |
| Metric Name | Correct |
| Dimensions | Correct |
| PutMetricData Operation | Denied |
| IAM Permission | Missing |
| Metric Datapoints | None |
| Root Cause | IAM authorization failure |

---

## 13. Root Cause Analysis

### Root Cause

The Python application failed to publish its custom CloudWatch metric because the EC2 IAM role did not have the `cloudwatch:PutMetricData` permission.

The role was configured with only the `AmazonSSMManagedInstanceCore` policy.

This permitted the instance to communicate with Systems Manager but did not authorize custom metric publishing.

Boto3 successfully obtained temporary credentials from the instance role.

However, when the application attempted to call `PutMetricData`, AWS denied the request.

The application returned an error and exited unsuccessfully.

### Root Cause Flow

```text
Python Payment Application
          |
          v
Boto3 CloudWatch Client
          |
          v
PutMetricData API Request
          |
          v
EC2 IAM Role Credentials
          |
          v
IAM Authorization Evaluation
          |
          v
No Allow for PutMetricData
          |
          v
AccessDenied
          |
          v
Custom Metric Not Published
```

### Five Whys

1. **Why was the custom metric missing?** No datapoints had been successfully published.
2. **Why were datapoints not published?** The `PutMetricData` request was denied.
3. **Why was the request denied?** The IAM role lacked the required CloudWatch permission.
4. **Why did AWS credentials still work?** Credential availability and authorization are separate.
5. **How was the issue resolved?** A least-privilege IAM policy was added to permit the metric publishing operation.

### Root Cause Summary

| Component | Finding |
|---|---|
| AWS Service | Amazon CloudWatch |
| Incident | INC-CW-004 |
| EC2 Instance | Healthy |
| Python Application | Operational |
| Boto3 | Operational |
| AWS Authentication | Successful |
| AWS Authorization | Failed |
| IAM Role | Missing PutMetricData |
| Metric Namespace | Correct |
| Metric Dimensions | Correct |
| Root Cause | Missing IAM permission |
| Remediation | Namespace-scoped IAM policy |
| EC2 Redeployment | Not required |

**Key Lesson:** An AWS application can successfully obtain credentials while lacking permission to perform its intended API operations.

---

## 14. Remediation — Grant Least-Privilege IAM Permission

### Step 1 — Create Custom IAM Policy

From WSL, save as `cloudwatch-metric-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLab04MetricPublishing",
      "Effect": "Allow",
      "Action": "cloudwatch:PutMetricData",
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "cloudwatch:namespace": "CloudWatchLab04/Payments"
        }
      }
    }
  ]
}
```

### Policy Explanation

| Setting | Purpose |
|---|---|
| `Effect: Allow` | Permits an action |
| `cloudwatch:PutMetricData` | Allows metric publishing |
| `Resource: "*"` | Required because PutMetricData does not support metric-level resource scoping |
| `cloudwatch:namespace` | Restricts publishing to the intended namespace |

### Step 2 — Attach Inline IAM Policy

```bash
aws iam put-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --policy-document file://cloudwatch-metric-policy.json
```

### Step 3 — Verify Policy

```bash
aws iam get-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --output json
```

Expected: the policy permits `cloudwatch:PutMetricData` for namespace `CloudWatchLab04/Payments`.

### Step 4 — Simulate Corrected Authorization

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$ROLE_ARN" \
  --action-names cloudwatch:PutMetricData \
  --resource-arns "*" \
  --context-entries \
    "ContextKeyName=cloudwatch:namespace,ContextKeyValues=CloudWatchLab04/Payments,ContextKeyType=string" \
  --query 'EvaluationResults[].{Action:EvalActionName,Decision:EvalDecision}' \
  --output table
```

Expected:

```text
cloudwatch:PutMetricData    allowed
```

### Step 5 — Connect to EC2

```bash
aws ssm start-session \
  --target "$INSTANCE_ID" \
  --region "$AWS_REGION"
```

### Step 6 — Publish Custom Metric

Inside EC2:

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 3
```

Expected:

```text
SUCCESS: Published PaymentFailures=3.0
```

IAM changes may require a short propagation period before the request succeeds.

### Step 7 — Publish Additional Datapoints

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 2
```

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 5
```

Expected: both operations succeed.

### Step 8 — Capture Recovery Output

```bash
/opt/cloudwatch-lab04/venv/bin/python \
  /opt/cloudwatch-lab04/publish_metric.py \
  --value 4 \
  > /tmp/lab04-publish-after.txt 2>&1

echo "Exit code: $?"

cat /tmp/lab04-publish-after.txt
```

Expected:

```text
Exit code: 0
SUCCESS: Published PaymentFailures=4.0
```

Exit EC2:

```bash
exit
```

---

## 15. Verify Custom Metric Publication

### Step 1 — Discover Custom Metric

From WSL:

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --output json \
  --region "$AWS_REGION"
```

Expected: the `PaymentFailures` metric becomes discoverable.

A newly created custom metric can take several minutes, potentially up to 15 minutes, to appear in `list-metrics`.

### Step 2 — Refresh Time Range

```bash
export START_TIME=$(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ)
export END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Step 3 — Retrieve Metric Statistics

```bash
aws cloudwatch get-metric-statistics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --period 60 \
  --statistics Sum SampleCount \
  --region "$AWS_REGION"
```

Expected: numerical datapoints.

Example if four successful values fall within the same minute:

```json
{
  "Datapoints": [
    {
      "Sum": 14.0,
      "SampleCount": 4.0,
      "Unit": "Count"
    }
  ],
  "Label": "PaymentFailures"
}
```

This output is illustrative. Actual values depend on metric publication timestamps and aggregation windows.

### Step 4 — Create Metric Query

Save as `metric-query.json`:

```json
[
  {
    "Id": "payment_failures",
    "MetricStat": {
      "Metric": {
        "Namespace": "CloudWatchLab04/Payments",
        "MetricName": "PaymentFailures",
        "Dimensions": [
          {
            "Name": "Environment",
            "Value": "Lab04"
          },
          {
            "Name": "Service",
            "Value": "PaymentAPI"
          }
        ]
      },
      "Period": 60,
      "Stat": "Sum"
    },
    "ReturnData": true
  }
]
```

### Step 5 — Retrieve Metric Data

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://metric-query.json \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --region "$AWS_REGION"
```

Expected: metric data results containing numerical values.

### Step 6 — Save Corrected IAM Evidence

```bash
aws iam get-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME" \
  --output json \
  > lab04-after-iam.json
```

### Step 7 — Save Metric Evidence

```bash
aws cloudwatch list-metrics \
  --namespace "$METRIC_NAMESPACE" \
  --metric-name "$METRIC_NAME" \
  --dimensions \
    "Name=Environment,Value=Lab04" \
    "Name=Service,Value=PaymentAPI" \
  --output json \
  --region "$AWS_REGION" \
  > lab04-after-metric.json
```

### Step 8 — Save Metric Data Evidence

```bash
aws cloudwatch get-metric-data \
  --metric-data-queries file://metric-query.json \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --output json \
  --region "$AWS_REGION" \
  > lab04-after-metric-data.json
```

### Before and After Comparison

| Investigation | Before Remediation | After Remediation |
|---|---|---|
| EC2 Instance | Running | Running |
| Python Application | Runs but publishing fails | Publishes successfully |
| Boto3 | Installed | Installed |
| AWS Credentials | Available | Available |
| Metric Namespace | Correct | Correct |
| Metric Name | Correct | Correct |
| Metric Dimensions | Correct | Correct |
| PutMetricData Permission | Missing | Granted |
| AWS API Result | AccessDenied | Success |
| Custom Metric | Missing | Available |
| Metric Datapoints | None | Published |
| Incident | Active | Resolved |

### Final Verification Criteria

The incident is resolved when:

1. The Python application executes successfully.
2. Boto3 uses the correct EC2 role.
3. The IAM role permits `cloudwatch:PutMetricData`.
4. The application publishes without AccessDenied.
5. The metric appears under the expected namespace.
6. The metric has the correct dimensions.
7. CloudWatch metric retrieval returns datapoints.
8. The successful publishing output is captured as evidence.

---

## 16. Production Troubleshooting Best Practices

### Custom Metric Troubleshooting Checklist

1. Verify application health.
2. Verify Python and Boto3 installation.
3. Confirm AWS Region.
4. Inspect metric namespace.
5. Inspect metric name.
6. Verify metric dimensions.
7. Confirm metric values and units.
8. Verify credential availability.
9. Identify the AWS role using STS.
10. Inspect IAM attached policies.
11. Inspect IAM inline policies.
12. Verify `cloudwatch:PutMetricData` authorization.
13. Investigate Boto3 API errors.
14. Check CloudWatch metric discovery.
15. Retrieve metric datapoints.
16. Correct IAM permissions.
17. Retry metric publishing.
18. Verify successful API responses.
19. Verify CloudWatch ingestion.
20. Document the root cause and remediation.

### Common Custom Metric Problems

| Symptom | Possible Cause |
|---|---|
| AccessDenied | Missing IAM permission |
| Unable to locate credentials | Missing role or credential configuration |
| Metric missing | Wrong namespace |
| No datapoints | Wrong dimensions or time range |
| Endpoint timeout | Network connectivity problem |
| InvalidParameterValue | Invalid metric request |
| Metric appears in another Region | Region mismatch |
| New metric not listed immediately | Discovery delay |
| Unexpected aggregation | Statistic or period mismatch |
| Publishing succeeds but dashboard empty | Metric query mismatch |

### Monitoring Recommendations

Production systems should monitor the health of the telemetry publishing process itself.

Applications should report errors when metric publishing fails and should not silently ignore repeated monitoring failures.

Metric names and dimensions should remain consistent across application deployments.

---

## 17. Security and Operational Recommendations

### IAM Least Privilege

Grant applications only the AWS permissions they require.

For this lab, the application needs:

`cloudwatch:PutMetricData`

The policy uses the `cloudwatch:namespace` condition to restrict the publishing destination.

### AWS Credentials

Use an IAM role attached to the EC2 instance.

Avoid embedding access keys in Python applications or configuration files.

### Error Handling

Capture and investigate Boto3 errors.

A failed AWS API request should produce useful diagnostic information without exposing secrets.

### Application Observability

Successful business operations do not guarantee that monitoring is functioning.

Application health and telemetry publishing health should be verified independently.

### Infrastructure as Code

In production, IAM policies, EC2 instance profiles, and monitoring configurations should preferably be maintained using Terraform, CloudFormation, or another controlled deployment process.

---

## 18. AWS Resource Cleanup

**Warning:** Verify that all resource identifiers belong to Lab 04 before deleting any resources.

Save your evidence before terminating the EC2 instance.

### Step 1 — Verify EC2 Instance

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{ID:InstanceId,State:State.Name,Profile:IamInstanceProfile.Arn}' \
  --output table \
  --region "$AWS_REGION"
```

### Step 2 — Verify Root EBS Volume

```bash
aws ec2 describe-instances \
  --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings' \
  --output json \
  --region "$AWS_REGION"
```

Confirm root EBS `DeleteOnTermination=true`.

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

Confirm the Lab 04 project tag.

### Step 5 — Delete Inline IAM Policy

```bash
aws iam delete-role-policy \
  --role-name "$EC2_ROLE_NAME" \
  --policy-name "$INLINE_POLICY_NAME"
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

Also verify the EC2 instance, EBS volume, IAM role, and instance profile are removed.

### CloudWatch Metric Cleanup

CloudWatch does not provide an API to delete individual metric series.

Terminating the publisher stops this lab from sending new metric datapoints.

Previously published metric data remains subject to CloudWatch's normal retention policies.

### Cleanup Summary

| Resource | Expected Result |
|---|---|
| Python Metric Publisher | Stopped |
| EC2 Instance | Terminated |
| Root EBS Volume | Deleted |
| Inline IAM Policy | Deleted |
| IAM Role | Deleted |
| Instance Profile | Deleted |
| Security Group | Deleted |
| Route Table | Deleted |
| Public Subnet | Deleted |
| Internet Gateway | Deleted |
| Lab VPC | Deleted |
| New Custom Metric Publishing | Stopped |
| Historical Metric Data | Expires normally |
| Default VPC | Unchanged |

---

## 19. Interview Questions and Answers

### Q1. What is a CloudWatch custom metric?

A metric published by an application, user, or monitoring system rather than automatically generated by an AWS service.

### Q2. Which AWS API publishes custom metrics?

`PutMetricData`.

### Q3. What IAM permission is required?

`cloudwatch:PutMetricData`.

### Q4. What is Boto3?

The AWS SDK for Python, used to interact with AWS services programmatically.

### Q5. How does Boto3 authenticate on EC2?

It can obtain temporary credentials from an IAM role associated with the instance.

### Q6. Can an application have valid AWS credentials and still receive AccessDenied?

Yes. Authentication and authorization are different.

### Q7. Why did this lab's metric fail to publish?

The EC2 IAM role lacked the `cloudwatch:PutMetricData` permission.

### Q8. How can you restrict metric publishing to a namespace?

Use the `cloudwatch:namespace` condition in an IAM policy.

### Q9. What identifies a CloudWatch metric?

The namespace, metric name, and dimension set.

### Q10. What is the difference between PutMetricData and GetMetricData?

`PutMetricData` publishes metric datapoints.

`GetMetricData` retrieves datapoints.

### Q11. Why might a custom metric not immediately appear in list-metrics?

New metric discovery can take several minutes after publishing.

### Q12. Why use a custom IAM policy instead of CloudWatchAgentServerPolicy?

Our Python application only needs custom metric publishing permissions. A focused IAM policy avoids unnecessary permissions.

### Q13. What is the purpose of the IAM Policy Simulator?

It helps evaluate whether specified IAM policies allow or deny an AWS action under supplied conditions.

### Q14. How would you explain this lab in an interview?

I deployed an EC2 instance running a Python Boto3 application that attempted to publish custom payment failure metrics to Amazon CloudWatch.

I intentionally configured the EC2 IAM role without the `cloudwatch:PutMetricData` permission.

The Python application could obtain temporary AWS credentials, but its CloudWatch API request failed with AccessDenied.

I investigated the EC2 instance profile, IAM role policies, Boto3 error output, and CloudWatch metric queries.

I identified the missing IAM permission as the root cause.

I created a least-privilege IAM policy restricted to the application's custom metric namespace and attached it to the EC2 role.

After the permissions were updated, I successfully published custom metric datapoints.

I verified metric ingestion using AWS CLI and removed the temporary resources after testing.

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
│   ├── README.md
│   ├── ec2-trust-policy.json
│   ├── user-data.sh
│   ├── publish_metric.py
│   ├── cloudwatch-metric-policy.json
│   ├── metric-query.json
│   ├── lab04-before-iam.json
│   ├── lab04-before-inline-policies.json
│   ├── lab04-before-metric.json
│   ├── lab04-before-metric-data.json
│   ├── lab04-after-iam.json
│   ├── lab04-after-metric.json
│   └── lab04-after-metric-data.json
│
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
| `ec2-trust-policy.json` | IAM trust policy |
| `user-data.sh` | Installs Python and deploys metric publisher |
| `publish_metric.py` | Python Boto3 metric publishing application |
| `cloudwatch-metric-policy.json` | Least-privilege IAM policy |
| `metric-query.json` | CloudWatch GetMetricData query |
| `lab04-before-iam.json` | Captures initial attached policies |
| `lab04-before-inline-policies.json` | Captures initial inline policies |
| `lab04-before-metric.json` | Captures missing metric |
| `lab04-before-metric-data.json` | Captures missing datapoints |
| `lab04-after-iam.json` | Captures corrected IAM policy |
| `lab04-after-metric.json` | Captures published custom metric |
| `lab04-after-metric-data.json` | Captures successful metric datapoints |

### Optional Application Evidence

```text
lab04-publish-before.txt
lab04-publish-after.txt
```

These files contain Python application output before and after remediation.

Copy them from EC2 before terminating the instance if you want to preserve them.

### Evidence Guidelines

Evidence should be generated from actual AWS CLI and Python outputs.

Do not fabricate successful responses or metric values.

Review evidence before publishing because command outputs can contain AWS account and resource identifiers.

---

## 21. Lessons Learned and Skills Demonstrated

### Lessons Learned

This lab demonstrates how missing IAM permissions can prevent an application from publishing custom metrics to Amazon CloudWatch.

We created a dedicated AWS VPC and deployed an Amazon Linux EC2 instance.

We developed a Python application using Boto3 to publish simulated payment failure metrics.

The application used the `PutMetricData` API to publish data under the `CloudWatchLab04/Payments` namespace.

However, we intentionally configured the EC2 IAM role without CloudWatch metric publishing permissions.

The Python application could obtain temporary credentials but received an authorization error when attempting to publish data.

We investigated the error using Boto3 output, AWS CLI, IAM role policies, and CloudWatch metric queries.

We identified the missing `cloudwatch:PutMetricData` permission as the root cause.

Instead of granting broad CloudWatch permissions, we created a least-privilege IAM policy restricted to the required metric namespace.

After attaching the policy, the Python application successfully published custom metric datapoints.

We verified the metric's namespace, name, dimensions, and numerical datapoints using AWS CLI.

Finally, we removed the temporary AWS resources.

**Key Lesson:** Successful AWS authentication does not guarantee authorization. When an application cannot publish CloudWatch custom metrics, engineers should investigate its effective IAM permissions and API errors before changing metric names, dimensions, or infrastructure.

### Skills Demonstrated

- Amazon CloudWatch
- CloudWatch custom metrics
- CloudWatch namespaces
- CloudWatch metric dimensions
- CloudWatch PutMetricData API
- CloudWatch GetMetricData API
- Python 3
- Boto3
- AWS SDK error handling
- AWS STS
- IAM authentication
- IAM authorization
- IAM instance roles
- IAM inline policies
- IAM Policy Simulator
- Least-privilege policy design
- Amazon EC2
- Amazon VPC
- AWS Systems Manager
- Linux Bash
- AWS CLI v2
- Root cause analysis
- Monitoring remediation
- Custom metric verification
- AWS resource cleanup

### Final Outcome

| Item | Expected Result |
|---|---|
| Incident | INC-CW-004 |
| Scenario | Custom Metric Not Publishing |
| EC2 Instance | Running during testing |
| Python Application | Operational |
| Boto3 | Operational |
| IAM Credentials | Available |
| Initial IAM Authorization | Insufficient |
| Initial API Result | AccessDenied |
| Root Cause | Missing PutMetricData permission |
| Remediation | Namespace-scoped IAM policy |
| Corrected API Result | Success |
| Custom Metric | PaymentFailures |
| Namespace | CloudWatchLab04/Payments |
| Metric Dimensions | Environment, Service |
| Metric Datapoints | Successfully published |
| EC2 Redeployment | Not required |
| Cleanup | Temporary resources removed |
| Incident Status | Resolved after verification |

**Key Takeaway:** CloudWatch custom metric publishing depends on correct application code, AWS credentials, IAM authorization, metric configuration, and successful API delivery. Engineers must investigate each layer to diagnose monitoring failures and should apply least-privilege permissions when implementing the solution.

---

## Official AWS Documentation

- [AWS — Publishing Custom Metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/publishingMetrics.html)
- [AWS CLI — PutMetricData](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-data.html)
- [AWS CLI — GetMetricData](https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/get-metric-data.html)
- [AWS — CloudWatch IAM Permissions](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/permissions-reference-cw.html)
- [Boto3 — CloudWatch PutMetricData](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/cloudwatch/client/put_metric_data.html)
- [AWS — IAM Policy Simulator](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_testing-policies.html)