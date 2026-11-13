#!/usr/bin/env python3

import json
import sys
import time

phase = sys.argv[1] if len(sys.argv) > 1 else "before"

messages = [
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "application_started",
        "phase": phase
    },
    {
        "level": "ERROR",
        "service": "payment-api",
        "event": "payment_timeout",
        "phase": phase
    },
    {
        "level": "WARN",
        "service": "payment-api",
        "event": "slow_response",
        "phase": phase
    },
    {
        "level": "ERROR",
        "service": "payment-api",
        "event": "database_connection_failed",
        "phase": phase
    },
    {
        "level": "INFO",
        "service": "payment-api",
        "event": "request_completed",
        "phase": phase
    }
]

base_timestamp = int(time.time() * 1000)

events = []

for index, message in enumerate(messages):
    events.append({
        "timestamp": base_timestamp + index,
        "message": json.dumps(message)
    })

with open(f"{phase}-log-events.json", "w") as file:
    json.dump(events, file, indent=2)

with open(f"{phase}-test-messages.json", "w") as file:
    json.dump([event["message"] for event in events], file, indent=2)

print(f"Generated {len(events)} events for phase: {phase}")
print("Expected ERROR matches: 2")
