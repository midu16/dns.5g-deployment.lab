# Reliability Model

This document defines what "robust" means for the reference DNS stack: explicit SLOs, failure modes, degraded behaviors, and how chaos tests validate each claim.

## Service level objectives

| SLI | Target SLO | Measurement |
|-----|------------|-------------|
| Authoritative query success | 99.99% | Blackbox probe `A/AAAA` for SOA + sample records |
| Recursive query success (validated) | 99.9% | Unbound probe with DNSSEC validation enabled |
| p99 query latency (internal) | < 50 ms | dnsdist / Unbound Prometheus metrics |
| Zone propagation lag | < 60 s | Compare SOA serial across primary + secondaries |
| RTO for single backend loss | < 30 s | dnsdist health-check failover in chaos test |
| DNSSEC chain validity | 100% signed public zones | `delv` / `dig +dnssec` automation |

**Design principle:** No single component failure should cause total DNS unavailability. Degraded mode (stale cache, secondary serving) is acceptable; silent wrong answers are not.

## Failure mode matrix

| Failure | Expected behavior | SLO impact | Alert |
|---------|-------------------|------------|-------|
| Primary down | Secondaries serve via dnsdist-auth; writes blocked until recovery | Auth queries continue | `DNSBackendDown`, `PowerDNSPrimaryDown` |
| One secondary down | Remaining secondary + primary serve | None if N+1 holds | `DNSBackendDown` |
| Both secondaries down | Primary serves alone; no AXFR redundancy | Elevated risk; auth SLO may hold briefly | `DNSBackendDown`, `ZoneSerialDrift` |
| dnsdist-auth down | Unbound cannot reach auth VIP; internal zones fail | Internal zone SLO breach | `DNSBackendDown` |
| dnsdist-recursive down | Clients cannot resolve | Recursive SLO breach | `DNSBackendDown`, blackbox probe fail |
| One Unbound down | dnsdist-recursive routes to healthy backend | RTO < 30 s | `DNSBackendDown` |
| Upstream root loss | Cached answers served within TTL; new names fail | Recursive SLO degradation | `UnboundUpstreamFailure` |
| AXFR blocked | Serial drift between primary and secondaries | Propagation SLO breach | `ZoneSerialDrift` |
| DNSSEC key expiry | Validation failures; SERVFAIL for affected zones | Recursive SLO breach | `DNSSECValidationFailure` |
| Bad zone in Git | CI rejects before apply | No production impact | CI failure (pre-deploy) |
| PostgreSQL down | Primary cannot serve writes; may fail reads | Auth SLO breach | `PostgreSQLDown` |

## Degraded modes

### Authoritative tier

- **Primary unavailable:** Secondaries continue serving last transferred zone data. dnsdist marks primary unhealthy and routes to secondaries. Zone changes queue in Git until primary recovers.
- **Stale secondary:** If AXFR is blocked, secondary serves stale data until serial mismatch is detected and alerted.

### Recursive tier

- **Cache hit during upstream failure:** Unbound returns cached answer within TTL (may be stale but not forged).
- **DNSSEC validation failure:** Unbound returns SERVFAIL rather than an unsigned or tampered answer (`val-permissive-mode: no`).

### What we refuse to degrade into

- Serving unsigned answers when DNSSEC validation is required
- Open recursion to the internet
- Accepting unsigned dynamic updates (`allow-update { any; }`)

## Alert thresholds

Prometheus rules in [`monitoring/prometheus/rules/`](../monitoring/prometheus/rules/):

| Alert | Condition | For | Maps to SLO |
|-------|-----------|-----|-------------|
| `DNSBackendDown` | dnsdist backend unhealthy | 30s | RTO < 30s |
| `ZoneSerialDrift` | SOA serial mismatch | 2m | Propagation < 60s |
| `DNSSECValidationFailure` | Unbound validator errors > 0 | 5m | DNSSEC 100% |
| `DNSP99LatencyHigh` | dnsdist p99 latency > 50ms | 10m | p99 < 50ms |
| `DNSAuthProbeFailure` | blackbox auth probe failing | 1m | Auth 99.99% |
| `DNSRecursiveProbeFailure` | blackbox recursive probe failing | 1m | Recursive 99.9% |

## Chaos test evidence report

Each chaos test in [`tests/chaos/`](../tests/chaos/) maps to an SLO claim:

| Test | Injected failure | SLO validated | Pass criteria |
|------|------------------|---------------|---------------|
| `kill-primary.sh` | Stop PowerDNS primary | Auth 99.99%, RTO < 30s | `dig` via auth VIP succeeds within 30s; primary alert fires |
| `kill-unbound.sh` | Stop one Unbound | RTO < 30s | Recursive queries succeed via dnsdist within 30s |
| `block-axfr.sh` | Block AXFR port between primary/secondary | Propagation < 60s | `ZoneSerialDrift` alert fires within 2m |
| `bad-zone-ci.sh` | Invalid OctoDNS YAML | No silent wrong answers | `octodns-validate` exits non-zero |
| `smoke/run.sh` | None (baseline) | DNSSEC 100%, auth/recursive success | All `dig +dnssec` and `delv` checks pass |

Run the full evidence suite:

```bash
./tests/smoke/run.sh
./tests/chaos/kill-primary.sh
./tests/chaos/kill-unbound.sh
```

Document results in your lab journal or CI artifacts.

## Comparison matrix

| Capability | dnsmasq (monolith) | BIND single-replica | This stack |
|------------|-------------------|---------------------|------------|
| Auth HA | No | No | Yes (N+1 + dnsdist) |
| Recursive HA | No | N/A if auth-only | Yes (Unbound pool) |
| DNSSEC signing | No | Manual | PowerDNS automated |
| DNSSEC validation | No | Optional | Unbound strict |
| GitOps zones | No | No | OctoDNS |
| Failover RTO | N/A (total outage) | N/A | < 30s measured |
| Observability | None | Limited | Full Prometheus stack |
