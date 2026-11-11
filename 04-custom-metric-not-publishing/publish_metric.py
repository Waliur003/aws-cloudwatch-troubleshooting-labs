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
