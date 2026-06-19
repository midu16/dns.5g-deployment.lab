#!/usr/bin/env bash
set -euo pipefail
CONF=/etc/powerdns/pdns.conf
sed -i "s|changeme-pdns-db|${POSTGRES_PASSWORD:-changeme-pdns-db}|g" "$CONF"

echo "Waiting for PostgreSQL replica at postgres-replica:5432..."
while ! (echo > /dev/tcp/postgres-replica/5432) 2>/dev/null; do sleep 2; done
echo "PostgreSQL replica is up."

exec /usr/local/sbin/pdns_server --guardian=no --daemon=no --disable-syslog --log-timestamp
