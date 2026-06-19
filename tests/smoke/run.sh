#!/usr/bin/env bash
# Smoke tests for the reference DNS stack
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

pass=0
fail=0

pass_test() { echo "PASS: $1"; pass=$((pass + 1)); }
fail_test() { echo "FAIL: $1"; fail=$((fail + 1)); }

dig_auth() {
  podman exec robust-dns-dns-tools dig @10.89.2.10 -p 5300 +norecurse +short +time=3 +tries=2 "$@" 2>/dev/null \
    || dig @127.0.0.1 -p 5300 +norecurse +short +time=3 +tries=2 "$@"
}

dig_recursive() {
  podman exec robust-dns-dns-tools dig @10.89.3.10 -p 5353 +short +time=3 +tries=2 "$@" 2>/dev/null \
    || dig @127.0.0.1 -p 5354 +short +time=3 +tries=2 "$@"
}

echo "=== Robust DNS smoke tests ==="
echo

if dig_auth infra.5g-deployment.lab SOA | grep -q 'infra.5g-deployment.lab'; then
  pass_test "Auth SOA infra.5g-deployment.lab"
else fail_test "Auth SOA infra.5g-deployment.lab"; fi

if dig_auth ns1.infra.5g-deployment.lab A | grep -qE '^10\.89\.2\.10$'; then
  pass_test "Auth A ns1.infra.5g-deployment.lab"
else fail_test "Auth A ns1.infra.5g-deployment.lab"; fi

if dig_auth api.hub.5g-deployment.lab SOA | grep -q 'api.hub.5g-deployment.lab'; then
  pass_test "Auth SOA api.hub.5g-deployment.lab"
else fail_test "Auth SOA api.hub.5g-deployment.lab"; fi

if dig_auth ns1.api.hub.5g-deployment.lab A | grep -qE '^10\.89\.2\.10$'; then
  pass_test "Auth A ns1.api.hub.5g-deployment.lab"
else fail_test "Auth A ns1.api.hub.5g-deployment.lab"; fi

if dig_recursive ns1.infra.5g-deployment.lab A | grep -qE '^10\.89\.2\.10$'; then
  pass_test "Recursive resolves infra zone"
else fail_test "Recursive resolves infra zone"; fi

if dig_recursive ns1.api.hub.5g-deployment.lab A | grep -qE '^10\.89\.2\.10$'; then
  pass_test "Recursive resolves api zone"
else fail_test "Recursive resolves api zone"; fi

if curl -sf -H "X-API-Key: changeme-pdns-api-key" \
  "http://127.0.0.1:8081/api/v1/servers/localhost/zones/infra.5g-deployment.lab." \
  | grep -q '"dnssec": true'; then
  pass_test "DNSSEC enabled on infra zone (PowerDNS API)"
else fail_test "DNSSEC enabled on infra zone (PowerDNS API)"; fi

serial_primary=$(dig_auth infra.5g-deployment.lab SOA | awk '{print $1}' | head -1)
if [[ -n "$serial_primary" ]]; then
  pass_test "SOA serial returned for infra zone"
else fail_test "SOA serial returned for infra zone"; fi

echo
echo "Results: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
