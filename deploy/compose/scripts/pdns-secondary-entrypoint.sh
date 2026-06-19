#!/bin/bash
set -euo pipefail
exec /usr/local/sbin/pdns_server --guardian=no --daemon=no --disable-syslog --log-timestamp
