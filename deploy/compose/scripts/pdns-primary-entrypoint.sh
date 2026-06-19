#!/bin/bash
set -euo pipefail
cp /etc/powerdns/pdns.conf /tmp/pdns.conf
sed -i "s|changeme-pdns-db|${POSTGRES_PASSWORD:-changeme-pdns-db}|g" /tmp/pdns.conf
sed -i "s|changeme-pdns-api-key|${PDNS_API_KEY:-changeme-pdns-api-key}|g" /tmp/pdns.conf

echo "Waiting for PostgreSQL at postgres:5432..."
while ! (echo > /dev/tcp/postgres/5432) 2>/dev/null; do sleep 2; done
echo "PostgreSQL is up."

exec /usr/local/sbin/pdns_server --config-dir=/tmp --guardian=no --daemon=no --disable-syslog --log-timestamp
