#!/usr/bin/env bash
# Smoke tests for anycast multi-PoP profile.
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

pass=0
fail=0

pass_test() { echo "PASS: $1"; pass=$((pass + 1)); }
fail_test() { echo "FAIL: $1"; fail=$((fail + 1)); }

ANYCAST_VIP="${ANYCAST_VIP:-10.89.99.53}"
MODE="${ANYCAST_LAB_MODE:-anycast}"

echo "=== Anycast PoP smoke tests (mode=${MODE}) ==="
echo

if ! podman ps --format '{{.Names}}' 2>/dev/null | grep -q robust-dns-dnsdist-pop-eu; then
  echo "SKIP: anycast profile not running"
  exit 0
fi

dig_pop() {
  local server="$1"
  shift
  podman exec robust-dns-dns-tools dig @"${server}" -p 5300 +norecurse +short +time=3 +tries=2 "$@" 2>/dev/null
}

if [[ "$MODE" == "unicast" ]]; then
  eu_target="10.89.4.10"
  us_target="10.89.5.10"
else
  eu_target="$ANYCAST_VIP"
  us_target="$ANYCAST_VIP"
fi

if dig_pop "$eu_target" infra.5g-deployment.lab SOA | grep -q infra; then
  pass_test "PoP EU answers SOA (${eu_target})"
else fail_test "PoP EU answers SOA (${eu_target})"; fi

if dig_pop "$us_target" infra.5g-deployment.lab SOA | grep -q infra; then
  pass_test "PoP US answers SOA (${us_target})"
else fail_test "PoP US answers SOA (${us_target})"; fi

echo
echo "Results: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
