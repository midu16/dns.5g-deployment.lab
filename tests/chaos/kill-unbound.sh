#!/usr/bin/env bash
# Chaos: kill one Unbound, verify recursive tier fails over (RTO < 30s)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_DIR="$ROOT_DIR/deploy/compose"
export PATH="${HOME}/.local/bin:${PATH}"
RTO_MAX="${RTO_MAX:-30}"

cd "$COMPOSE_DIR"

dig_recursive() {
  podman exec robust-dns-dns-tools dig @10.89.3.10 -p 5353 +short +time=2 ns1.infra.5g-deployment.lab A 2>/dev/null \
    || dig @127.0.0.1 -p 5354 +short +time=2 ns1.infra.5g-deployment.lab A
}

echo "==> Stopping unbound-1..."
podman-compose stop unbound-1

start=$(date +%s)
recovered=false
while (( $(date +%s) - start < RTO_MAX )); do
  if dig_recursive | grep -qE '^10\.89\.2\.10$'; then
    recovered=true
    break
  fi
  sleep 1
done
elapsed=$(( $(date +%s) - start ))

echo "==> Restarting unbound-1..."
podman-compose start unbound-1

if $recovered; then
  echo "PASS: Recursive queries succeeded within ${elapsed}s (RTO target: ${RTO_MAX}s)"
  exit 0
else
  echo "FAIL: Recursive queries did not recover within ${RTO_MAX}s"
  exit 1
fi
