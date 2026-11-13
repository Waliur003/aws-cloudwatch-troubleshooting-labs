#!/usr/bin/env python3

import json
import time

messages = [
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "application_started",
        "environment": "lab08"
    },
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "request_received",
        "endpoint": "/payments"
    },
    {
        "level": "WARN",
        "service": "payment-api",
        "event": "slow_response",
        "latency_ms": 750
    },
    {
        "level": "ERROR",
        "service": "payment-api",
        "event": "payment_timeout",
        "request_id": "lab08-demo-001"
    },
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "request_completed",
        "status": 200
    }
]

base_timestamp = int(time.time() * 1000)

events = []

for index, message in enumerate(messages):
    events.append({
        "timestamp": base_timestamp + index,
        "message": json.dumps(message)
    })

with open("test-log-events.json", "w") as file:
    json.dump(events, file, indent=2)

print("Generated", len(events), "test log events")