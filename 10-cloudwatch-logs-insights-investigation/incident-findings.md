# INC-CW-010 — Payment API Incident Findings

## Summary

A simulated payment API incident caused increased latency
and HTTP 503 failures.

## Evidence

- 20 successful baseline requests
- 30 requests during the incident
- 12 HTTP 503 failures
- DB_POOL_EXHAUSTED errors
- Connection pool limit changed from 20 to 2
- Configuration restored from 2 to 20
- 20 successful recovery requests

## Root Cause

Database connection pool limit reduced from 20 to 2.

## Remediation

Restore the validated database connection pool size.

## Verification

CloudWatch Logs Insights queries show successful requests
and normal latency following the simulated restoration.

## Prevention

- Validate application configuration changes
- Monitor database pool utilization
- Test application behavior following deployments
- Review connection limits and workload requirements
