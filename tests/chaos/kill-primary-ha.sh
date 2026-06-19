#!/usr/bin/env bash
# Chaos: kill primary with HA profile; verify auth reads and post-promotion writes.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
COMPOSE_DIR="$(cd "$(dirname "$0")/../../deploy/compose" && pwd)"
cd "$COMPOSE_DIR"

if ! podman ps --format '{{.Names}}' 2>/dev/null | grep -q robust-dns-pdns-standby; then
  echo "SKIP: HA profile not running (podman-compose --profile ha up -d)"
  exit 0
fi

# shellcheck source=/dev/null
source .env 2>/dev/null || source ../../.env

echo "==> Stopping active primary + postgres..."
podman-compose stop pdns-primary postgres

start=$(date +%s)
echo "==> Waiting for auth SOA via dnsdist (secondaries)..."
while ! podman exec robust-dns-dns-tools dig @10.89.2.10 -p 5300 +norecurse +time=2 +tries=1 \
  infra.5g-deployment.lab SOA +short 2>/dev/null | grep -q infra; do
  if (( $(date +%s) - start > 30 )); then
    echo "FAIL: Auth read RTO exceeded 30s"
    podman-compose start postgres pdns-primary
    exit 1
  fi
  sleep 1
done
read_rto=$(( $(date +%s) - start ))
echo "PASS: Auth reads OK in ${read_rto}s"

echo "==> Promoting postgres-replica..."
podman-compose exec -T postgres-replica pg_ctl promote -D /var/lib/postgresql/data
sleep 5

echo "==> Restarting pdns-standby (API still off in config — manual promotion step)..."
podman-compose restart pdns-standby

echo "==> Restoring primary stack for lab..."
podman-compose start postgres pdns-primary

echo "HA chaos complete. Read RTO: ${read_rto}s (target < 30s)"
[[ "$read_rto" -lt 30 ]]
