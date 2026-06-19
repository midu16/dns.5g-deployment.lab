#!/usr/bin/env bash
# Chaos: withdraw EU PoP route; US continues answering on anycast VIP.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"
COMPOSE_DIR="$(cd "$(dirname "$0")/../../deploy/compose" && pwd)"
cd "$COMPOSE_DIR"

ANYCAST_VIP="${ANYCAST_VIP:-10.89.99.53}"
MODE="${ANYCAST_LAB_MODE:-anycast}"

if ! podman ps --format '{{.Names}}' 2>/dev/null | grep -q robust-dns-bird-pop-eu; then
  echo "SKIP: anycast profile not running"
  exit 0
fi

if [[ "$MODE" == "unicast" ]]; then
  echo "==> Unicast mode: stopping EU dnsdist instead of BGP withdraw..."
  podman-compose -f docker-compose.yml -f docker-compose.anycast.yml stop dnsdist-pop-eu
  target="10.89.5.10"
else
  echo "==> Disabling BIRD BGP export on EU PoP..."
  podman exec robust-dns-bird-pop-eu birdc disable rr 2>/dev/null || \
    podman-compose -f docker-compose.yml -f docker-compose.anycast.yml stop bird-pop-eu
  target="$ANYCAST_VIP"
fi

start=$(date +%s)
while ! podman exec robust-dns-dns-tools dig @"${target}" -p 5300 +norecurse +time=2 +tries=1 \
  infra.5g-deployment.lab SOA +short 2>/dev/null | grep -q infra; do
  if (( $(date +%s) - start > 30 )); then
    echo "FAIL: US PoP did not answer within 30s"
    podman-compose -f docker-compose.yml -f docker-compose.anycast.yml start bird-pop-eu dnsdist-pop-eu 2>/dev/null || true
    exit 1
  fi
  sleep 1
done

echo "PASS: Remaining PoP answered in $(( $(date +%s) - start ))s"
podman-compose -f docker-compose.yml -f docker-compose.anycast.yml start bird-pop-eu dnsdist-pop-eu 2>/dev/null || true
