#!/usr/bin/env bash
# Chaos: kill PowerDNS primary, verify auth continues via secondaries (RTO < 30s)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/deploy/compose"
export PATH="${HOME}/.local/bin:${PATH}"
RTO_MAX="${RTO_MAX:-30}"

cd "$COMPOSE_DIR"

dig_auth() {
  podman exec robust-dns-dns-tools dig @10.89.2.10 -p 5300 +norecurse +short +time=2 ns1.infra.5g-deployment.lab A 2>/dev/null \
    || dig @127.0.0.1 -p 5300 +norecurse +short +time=2 ns1.infra.5g-deployment.lab A
}

echo "==> Stopping PowerDNS primary..."
podman-compose stop pdns-primary

start=$(date +%s)
recovered=false
while (( $(date +%s) - start < RTO_MAX )); do
  if dig_auth | grep -qE '^10\.89\.2\.10$'; then
    recovered=true
    break
  fi
  sleep 1
done
elapsed=$(( $(date +%s) - start ))

echo "==> Restarting PowerDNS primary..."
podman-compose start pdns-primary

if $recovered; then
  echo "PASS: Auth queries succeeded within ${elapsed}s (RTO target: ${RTO_MAX}s)"
  exit 0
else
  echo "FAIL: Auth queries did not recover within ${RTO_MAX}s"
  exit 1
fi
