# Primary Failover Runbook (profile ha)

Fail over the write path from `pdns-primary` + `postgres` to `pdns-standby` + `postgres-replica` after primary database or PowerDNS failure.

## Prerequisites

- Stack running with `--profile ha`
- Replication healthy: `postgres-replica` in recovery mode

## Detection

- Alert: `PowerDNSPrimaryDown`, `PostgreSQLDown`, or `PowerDNSStandbyLag`
- GitOps `/ready` fails when active primary API unreachable

## Failover steps

1. **Confirm primary failure** — do not fail over on transient blips.

```bash
podman-compose stop pdns-primary postgres
```

2. **Promote PostgreSQL replica**

```bash
podman-compose exec postgres-replica pg_ctl promote -D /var/lib/postgresql/data
```

3. **Enable PowerDNS standby API** — edit runtime or swap config:

```bash
podman-compose exec pdns-standby pdns_control set api=yes
# Or redeploy with api=yes in pdns-standby.conf and restart pdns-standby
```

4. **Repoint GitOps** — set in `.env`:

```
PDNS_PRIMARY=pdns-standby
```

```bash
podman-compose up -d gitops-controller
curl -X POST http://127.0.0.1:8088/sync
```

5. **Verify reads and writes**

```bash
dig @127.0.0.1 -p 5300 +norecurse infra.5g-deployment.lab SOA
curl -sf -H "X-API-Key: $PDNS_API_KEY" http://127.0.0.1:8081/api/v1/servers/localhost/statistics
```

6. **Optional: re-seed old primary as replica** after hardware repair (reverse pg_basebackup flow).

## Rollback

Restore original primary + postgres from backup; demote promoted replica; reset `PDNS_PRIMARY=pdns-primary`.

## RTO targets

| Path | Target |
|------|--------|
| Auth reads via dnsdist | < 30s (secondaries continue) |
| GitOps writes after promotion | < 120s manual |
