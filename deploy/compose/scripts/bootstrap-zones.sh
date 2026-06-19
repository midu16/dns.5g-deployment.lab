#!/bin/bash
# Bootstrap zones via OctoDNS, enable DNSSEC, configure TSIG, trigger AXFR
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_DIR="$(dirname "$SCRIPT_DIR")"
ROOT_DIR="$(cd "$COMPOSE_DIR/../.." && pwd)"

cd "$COMPOSE_DIR"
export PATH="${HOME}/.local/bin:${PATH}"
COMPOSE="podman-compose"

if [[ ! -f .env ]]; then
  if [[ -f "$ROOT_DIR/.env" ]]; then
    ln -sf "$ROOT_DIR/.env" .env
  else
    cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
    ln -sf "$ROOT_DIR/.env" .env
    echo "Created $ROOT_DIR/.env from .env.example — review secrets before production use."
  fi
fi

# shellcheck source=/dev/null
source .env

echo "==> Waiting for PowerDNS primary API..."
for i in $(seq 1 60); do
  if curl -sf -H "X-API-Key: ${PDNS_API_KEY}" "http://127.0.0.1:8081/api/v1/servers/localhost/statistics" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "==> Syncing zones via OctoDNS..."
$COMPOSE --profile tools run --rm \
  -e PDNS_API_KEY="${PDNS_API_KEY}" \
  octodns-sync --config-file /octodns/config.yaml --doit

echo "==> Starting GitOps controller (ongoing reconcile)..."
$COMPOSE up -d gitops-controller 2>/dev/null || true

echo "==> Configuring secondaries (autoprimary + zone create)..."
for sec in pdns-secondary-1 pdns-secondary-2; do
  $COMPOSE exec -T "$sec" /usr/local/bin/pdnsutil add-autoprimary 10.89.2.11 pdns-primary st 2>/dev/null || true
  for zone in infra.5g-deployment.lab api.hub.5g-deployment.lab; do
    $COMPOSE exec -T "$sec" /usr/local/bin/pdnsutil create-secondary-zone "$zone" 10.89.2.11 2>/dev/null || true
  done
done

echo "==> Importing TSIG key on primary..."
  $COMPOSE exec -T pdns-primary /usr/local/bin/pdnsutil import-tsig-key \
  "${TSIG_KEY_NAME}" "${TSIG_KEY_NAME}" "${TSIG_KEY_SECRET}" 2>/dev/null || true

echo "==> Enabling DNSSEC on reference zones..."
for zone in infra.5g-deployment.lab api.hub.5g-deployment.lab; do
  $COMPOSE exec -T pdns-primary /usr/local/bin/pdnsutil secure-zone "$zone" 2>/dev/null || true
  $COMPOSE exec -T pdns-primary /usr/local/bin/pdnsutil set-nsec3 "$zone" '1 0 0 -' 2>/dev/null || true
done

echo "==> Retrieving DS records for Unbound trust anchor..."
TRUST_FILE="$ROOT_DIR/config/unbound/trust-anchor.conf"
: > "$TRUST_FILE"
for zone in infra.5g-deployment.lab api.hub.5g-deployment.lab; do
  $COMPOSE exec -T pdns-primary /usr/local/bin/pdnsutil show-zone "$zone" 2>/dev/null | grep -E '^DS' >> "$TRUST_FILE" || true
done

echo "==> Restarting Unbound to load trust anchors..."
$COMPOSE restart unbound-1 unbound-2

echo "==> Triggering NOTIFY to secondaries..."
for zone in infra.5g-deployment.lab api.hub.5g-deployment.lab; do
  $COMPOSE exec -T pdns-primary /usr/local/bin/pdns_control notify "$zone" 2>/dev/null || true
done

echo "==> Bootstrap complete."
echo "Run: $ROOT_DIR/tests/smoke/run.sh"
