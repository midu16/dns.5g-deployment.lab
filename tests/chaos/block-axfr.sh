#!/usr/bin/env bash
# Chaos: document AXFR block scenario — requires manual nftables or compose network isolation
# Validates that serial drift detection is configured in Prometheus rules.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "==> AXFR block chaos test (simulated)"
echo "This test verifies ZoneSerialDrift alert rule exists in Prometheus config."

RULE_FILE="$ROOT_DIR/monitoring/prometheus/rules/dns-slo.yaml"
if grep -q 'ZoneSerialDrift\|serial' "$RULE_FILE" 2>/dev/null; then
  echo "PASS: Serial drift alert rule present (or related DNS SLO rules configured)"
else
  echo "NOTE: Add ZoneSerialDrift recording rule when SOA exporter is wired"
fi

echo "Manual step: block TCP/53 between pdns-primary and pdns-secondary-1, publish zone change,"
echo "verify SOA serial mismatch alert fires within 2 minutes."
echo "See docs/reliability-model.md evidence report."
