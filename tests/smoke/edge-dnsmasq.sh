#!/usr/bin/env bash
# Smoke tests for dnsmasq edge profile (requires --profile edge).
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

pass=0
fail=0

pass_test() { echo "PASS: $1"; pass=$((pass + 1)); }
fail_test() { echo "FAIL: $1"; fail=$((fail + 1)); }

echo "=== dnsmasq edge smoke tests ==="
echo

if ! podman ps --format '{{.Names}}' 2>/dev/null | grep -q robust-dns-dnsmasq-edge; then
  echo "SKIP: dnsmasq-edge not running (start with: podman-compose --profile edge up -d)"
  exit 0
fi

if podman exec robust-dns-dnsmasq-edge dig @127.0.0.1 -p 5353 edge-local.robust-dns.lab A +short 2>/dev/null | grep -q '10.89.3.99'; then
  pass_test "Edge local override edge-local.robust-dns.lab"
else fail_test "Edge local override edge-local.robust-dns.lab"; fi

if podman exec robust-dns-dnsmasq-edge dig @127.0.0.1 -p 5353 ns1.infra.5g-deployment.lab A +short 2>/dev/null | grep -q '10.89.2.10'; then
  pass_test "Edge forwards to recursive for infra zone"
else fail_test "Edge forwards to recursive for infra zone"; fi

if podman exec robust-dns-dnsmasq-edge dig @127.0.0.1 -p 5353 example.com A +short 2>/dev/null | grep -qE '^[0-9]+\.'; then
  pass_test "Edge forwards external names (example.com)"
else fail_test "Edge forwards external names (example.com)"; fi

echo
echo "Results: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
