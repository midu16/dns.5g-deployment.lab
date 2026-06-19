#!/usr/bin/env bash
# dnsdist recursive entrypoint: render policy loader and start dnsdist.
set -euo pipefail

POLICIES="${DNSDIST_POLICIES:-split-horizon,blocklist}"
export DNSDIST_POLICIES="$POLICIES"

exec dnsdist --supervised --disable-syslog -C /etc/dnsdist/dnsdist.conf
