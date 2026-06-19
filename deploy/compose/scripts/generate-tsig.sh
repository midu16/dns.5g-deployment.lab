#!/bin/bash
# Generate a TSIG key for AXFR/NOTIFY. Output suitable for .env
set -euo pipefail

KEYNAME="${1:-axfr-key.}"
SECRET=$(openssl rand -base64 32)

echo "Add to .env:"
echo "TSIG_KEY_NAME=${KEYNAME}"
echo "TSIG_KEY_SECRET=${SECRET}"
echo ""
echo "PowerDNS import command (run on primary):"
echo "pdnsutil import-tsig-key ${KEYNAME} ${KEYNAME} \"${SECRET}\""
