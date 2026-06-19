#!/bin/bash
set -e
echo "host replication replicator 10.89.0.0/16 scram-sha-256" >> "$PGDATA/pg_hba.conf"
echo "host replication replicator 127.0.0.1/32 scram-sha-256" >> "$PGDATA/pg_hba.conf"
