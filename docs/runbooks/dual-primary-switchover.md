# Dual-Primary Switchover Runbook (profile dual-primary)

Active/passive write model: Git + OctoDNS target **one** primary API at a time. Both primaries may serve queries via dnsdist; passive node receives AXFR from active.

## Topology

| Node | IP | Role |
|------|-----|------|
| pdns-primary (A) | 10.89.2.11 | Active writer (default) |
| pdns-primary-b (B) | 10.89.2.14 | Passive AXFR + serve |

## Switchover to B

1. Verify serial parity:

```bash
dig @10.89.2.11 +norecurse infra.5g-deployment.lab SOA
dig @10.89.2.14 +norecurse infra.5g-deployment.lab SOA
```

2. Update `.env`:

```
PDNS_ACTIVE_PRIMARY=B
PDNS_ACTIVE_HOST=pdns-primary-b
```

3. Enable API on B (disable on A if isolating):

```bash
# Promote B: convert zones to native primary on B (lab)
podman-compose exec pdns-primary-b pdnsutil set-kind infra.5g-deployment.lab primary
podman-compose exec pdns-primary-b pdnsutil set-kind api.hub.5g-deployment.lab primary
```

4. Restart GitOps with dual-primary config:

```bash
export OCTODNS_CONFIG=/octodns/config-dual-primary.yaml
podman-compose --profile dual-primary up -d gitops-controller
curl -X POST http://127.0.0.1:8088/sync
```

5. Reconfigure A as secondary of B (production) or decommission A auth pool member.

## Switch back to A

Reverse steps; set `PDNS_ACTIVE_PRIMARY=A`, `PDNS_ACTIVE_HOST=pdns-primary`.

## Conflict model

- **Never** run OctoDNS `--doit` against both primaries concurrently.
- Passive primary has `api=no` in [`pdns-primary-b.conf`](../../config/powerdns/pdns-primary-b.conf).
- Git remains source of truth; primaries are materialized views.
