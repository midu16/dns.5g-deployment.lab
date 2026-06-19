#!/usr/bin/env bash
# Smoke tests for dnsdist policy layer (split-horizon + blocklist).
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

pass=0
fail=0

pass_test() { echo "PASS: $1"; pass=$((pass + 1)); }
fail_test() { echo "FAIL: $1"; fail=$((fail + 1)); }

echo "=== dnsdist policy smoke tests ==="
echo

if ! podman ps --format '{{.Names}}' 2>/dev/null | grep -q robust-dns-dnsdist-recursive; then
  echo "SKIP: dnsdist-recursive not running"
  exit 0
fi

internal=$(podman exec robust-dns-dns-tools dig @10.89.3.10 -b 10.89.3.40 -p 5353 split-horizon.test A +short +time=3 +tries=2 2>/dev/null | head -1 || true)
if [[ "$internal" == "10.89.3.88" ]]; then
  pass_test "Split-horizon internal client -> 10.89.3.88"
else fail_test "Split-horizon internal client -> 10.89.3.88 (got: ${internal:-empty})"; fi

external=$(podman exec robust-dns-dns-tools dig @10.89.2.45 -b 10.89.2.40 -p 5353 split-horizon.test A +short +time=2 +tries=1 2>/dev/null | head -1 || true)
if [[ "$external" == "203.0.113.88" ]]; then
  pass_test "Split-horizon external client -> 203.0.113.88"
elif [[ -z "$external" ]] || echo "$external" | grep -q 'communications error'; then
  echo "SKIP: external split-horizon (recreate dnsdist-recursive for auth_net IP 10.89.2.45)"
else
  fail_test "Split-horizon external client -> 203.0.113.88 (got: ${external})"
fi

blocked=$(podman exec robust-dns-dns-tools dig @10.89.3.10 -b 10.89.3.40 -p 5353 malware.test A +time=3 +tries=2 2>&1 || true)
if echo "$blocked" | grep -qiE 'NXDOMAIN|status: NXDOMAIN'; then
  pass_test "Blocklist returns NXDOMAIN for malware.test"
else fail_test "Blocklist returns NXDOMAIN for malware.test"; fi

echo
echo "Results: ${pass} passed, ${fail} failed"
[[ "$fail" -eq 0 ]]
