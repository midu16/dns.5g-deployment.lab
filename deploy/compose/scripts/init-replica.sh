#!/usr/bin/env bash
# Initialize PostgreSQL streaming replica from primary (profile ha).
set -euo pipefail

export PGPASSWORD="${POSTGRES_PASSWORD:-changeme-pdns-db}"
PRIMARY_HOST="${POSTGRES_PRIMARY_HOST:-postgres}"
PRIMARY_PORT="${POSTGRES_PRIMARY_PORT:-5432}"
REPL_USER="${POSTGRES_REPLICATION_USER:-replicator}"
REPL_PASSWORD="${POSTGRES_REPLICATION_PASSWORD:-changeme-replica}"

echo "Waiting for primary PostgreSQL at ${PRIMARY_HOST}:${PRIMARY_PORT}..."
until pg_isready -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "${POSTGRES_USER:-pdns}"; do
  sleep 2
done

if [[ -s "${PGDATA}/PG_VERSION" ]]; then
  echo "Replica data directory already initialized."
  exec docker-entrypoint.sh postgres \
    -c hot_standby=on \
    -c wal_level=replica
fi

echo "Running pg_basebackup from primary..."
export PGPASSWORD="$REPL_PASSWORD"
pg_basebackup -h "$PRIMARY_HOST" -p "$PRIMARY_PORT" -U "$REPL_USER" -D "$PGDATA" -Fp -Xs -P -R

echo "Starting replica PostgreSQL..."
exec docker-entrypoint.sh postgres \
  -c hot_standby=on \
  -c wal_level=replica
