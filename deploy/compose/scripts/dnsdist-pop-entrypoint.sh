#!/usr/bin/env bash
# Add anycast VIP to loopback and start dnsdist (anycast PoP).
set -euo pipefail

VIP="${ANYCAST_VIP:-10.89.99.53}"

if ip addr show dev lo | grep -q "${VIP}/32"; then
  echo "Anycast VIP ${VIP} already on lo"
else
  ip addr add "${VIP}/32" dev lo 2>/dev/null || true
fi

exec dnsdist --supervised --disable-syslog -C /etc/dnsdist/dnsdist.conf
