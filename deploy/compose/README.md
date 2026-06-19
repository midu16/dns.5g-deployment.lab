# Podman Compose Lab Stack

Reference deployment simulating multi-tier DNS on a single host.

## Prerequisites

- Podman 4.x+
- `podman-compose` (`pip install --user podman-compose`)
- Ports available: 5300, 5354, 8081, 9090, 3001, 1053

## Start

```bash
cp ../../.env.example ../../.env
podman-compose up -d
./scripts/bootstrap-zones.sh
../../tests/smoke/run.sh
```

## Rootless notes

| Service | Host port | Notes |
|---------|-----------|-------|
| dnsdist-auth | 5300 | Use `dig +norecurse` from host |
| dnsdist-recursive | 5354 | Avoids mDNS conflict on 5353; maps to container 5353 |
| CoreDNS stub | 1053 | |
| Grafana | 3001 | Avoids conflict with other Grafana instances |

Smoke and chaos tests use the `dns-tools` container on compose networks for reliable queries under rootless Podman.

## Services

See [docker-compose.yml](docker-compose.yml) for the full service graph.

### GitOps controller

The `gitops-controller` service runs continuously and reconciles `zones/` to PowerDNS:

```bash
# Trigger immediate sync after editing zones/
curl -X POST http://127.0.0.1:8088/sync

# Health
curl http://127.0.0.1:8088/health
```

See [zone GitOps runbook](../../docs/runbooks/zone-gitops.md).

## Bootstrap

`scripts/bootstrap-zones.sh` performs:

1. OctoDNS sync (Git zones → PowerDNS primary)
2. Secondary autoprimary + zone creation
3. TSIG import
4. DNSSEC signing (`gpgsql-dnssec=yes` required)
5. NOTIFY to secondaries
6. Optional: dual-primary B and anycast PoP secondaries when profiles are active

## v2 Compose profiles

| Profile | Services added | Start |
|---------|----------------|-------|
| (default) | v1 core | `podman-compose up -d` |
| `edge` | dnsmasq-edge | `--profile edge` |
| `edge-dhcp` | dnsmasq-edge-dhcp | `--profile edge-dhcp` |
| `policy` | dns-tools-ext | `--profile policy` |
| `ha` | postgres-replica, pdns-standby | `--profile ha` |
| `dual-primary` | pdns-primary-b | `--profile dual-primary` |
| `anycast` | PoP EU/US, BIRD, FRR | `-f docker-compose.anycast.yml --profile anycast` |

```bash
./scripts/generate-dnsmasq-hosts.sh   # before edge profile
podman-compose --profile edge --profile policy up -d
podman-compose -f docker-compose.yml -f docker-compose.anycast.yml --profile anycast up -d
```

## Tear down

```bash
podman-compose down -v
```
