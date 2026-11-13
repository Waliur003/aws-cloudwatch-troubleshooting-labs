#!/usr/bin/env python3

import json
import time

NOW = int(time.time() * 1000)

events = []

def add_event(timestamp, **fields):
    events.append({
        "timestamp": timestamp,
        "message": json.dumps(fields, separators=(",", ":"))
    })


# =====================================
# PHASE 1 — NORMAL BASELINE
# 12 minutes before now
# =====================================

base = NOW - (12 * 60 * 1000)

for i in range(20):
    add_event(
        base + i * 1000,
        level="INFO",
        service="payment-api",
        phase="baseline",
        endpoint="/api/payments",
        status=200,
        latency_ms=110 + (i % 8) * 12,
        event="request_completed",
        request_id=f"baseline-{i:03d}",
        db_pool_limit=20
    )


# =====================================
# PHASE 2 — INCIDENT
# 7 minutes before now
# =====================================

incident = NOW - (7 * 60 * 1000)

# Configuration change that causes
# the simulated database pool problem.

add_event(
    incident,
    level="WARN",
    service="payment-api",
    phase="incident",
    event="config_change",
    component="database_pool",
    old_pool_limit=20,
    new_pool_limit=2,
    change_id="CHG-LAB10-001",
    message="Database connection pool reduced"
)

# 12 successful but slower requests.

for i in range(12):
    add_event(
        incident + (i + 1) * 1000,
        level="INFO",
        service="payment-api",
        phase="incident",
        endpoint="/api/payments",
        status=200,
        latency_ms=300 + (i % 6) * 35,
        event="request_completed",
        request_id=f"incident-ok-{i:03d}",
        db_pool_limit=2
    )

# 12 failed requests caused by
# database connection pool exhaustion.

for i in range(12):
    add_event(
        incident + (i + 13) * 1000,
        level="ERROR",
        service="payment-api",
        phase="incident",
        endpoint="/api/payments",
        status=503,
        latency_ms=1400 + (i % 6) * 120,
        event="payment_failed",
        request_id=f"incident-fail-{i:03d}",
        error_code="DB_POOL_EXHAUSTED",
        component="database_pool",
        db_pool_limit=2,
        message="Database connection timeout"
    )

# 6 slow requests that complete.

for i in range(6):
    add_event(
        incident + (i + 25) * 1000,
        level="WARN",
        service="payment-api",
        phase="incident",
        endpoint="/api/payments",
        status=200,
        latency_ms=800 + i * 70,
        event="slow_request",
        request_id=f"incident-slow-{i:03d}",
        db_pool_limit=2
    )


# =====================================
# PHASE 3 — RECOVERY
# 2 minutes before now
# =====================================

recovery = NOW - (2 * 60 * 1000)

add_event(
    recovery,
    level="INFO",
    service="payment-api",
    phase="recovery",
    event="config_change",
    component="database_pool",
    old_pool_limit=2,
    new_pool_limit=20,
    change_id="CHG-LAB10-002",
    message="Database connection pool restored"
)

for i in range(20):
    add_event(
        recovery + (i + 1) * 1000,
        level="INFO",
        service="payment-api",
        phase="recovery",
        endpoint="/api/payments",
        status=200,
        latency_ms=105 + (i % 7) * 13,
        event="request_completed",
        request_id=f"recovery-{i:03d}",
        db_pool_limit=20
    )


# =====================================
# WRITE LOG EVENTS
# =====================================

events.sort(key=lambda x: x["timestamp"])

with open("incident-log-events.json", "w") as file:
    json.dump(events, file, indent=2)

summary = {
    "total_events": len(events),
    "baseline_requests": 20,
    "incident_requests": 30,
    "incident_failed_requests": 12,
    "recovery_requests": 20,
    "config_changes": 2,
    "simulated_root_cause": "database_pool_limit_reduced",
    "initial_pool_limit": 20,
    "incorrect_pool_limit": 2,
    "restored_pool_limit": 20
}

with open("incident-expected-results.json", "w") as file:
    json.dump(summary, file, indent=2)

print("Generated", len(events), "log events")
print("Baseline: 20 successful requests")
print("Incident: 30 requests, 12 failures")
print("Recovery: 20 successful requests")
print("Configuration changes: 2")
