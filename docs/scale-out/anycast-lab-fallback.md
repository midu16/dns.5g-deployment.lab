# Anycast Lab Fallback (no BGP)

When BIRD/FRR cannot run under rootless Podman (missing `NET_ADMIN` or loopback route injection), use **unicast per-PoP** addresses instead of a shared anycast VIP.

## Unicast lab mode

| PoP | dnsdist address | Secondary |
|-----|-----------------|-----------|
| EU | `10.89.4.10` | `10.89.4.12` |
| US | `10.89.5.10` | `10.89.5.12` |

Clients select PoP explicitly (GeoDNS, split DHCP scopes, or manual `dig @10.89.4.10`).

## Enable

```bash
export ANYCAST_LAB_MODE=unicast
podman-compose -f docker-compose.yml -f docker-compose.anycast.yml --profile anycast up -d
```

Smoke tests skip shared VIP checks and probe each PoP unicast IP.

## Production path

Use real BGP speakers (BIRD/FRR on dedicated hosts) per [anycast-bgp.md](anycast-bgp.md). Withdraw routes on backend failure via health-check hooks calling `birdc disable protocol`.

## Why rootless may fail

- Loopback `/32` binding inside container namespace does not propagate to host routing table
- BGP peering requires `CAP_NET_ADMIN` and often `privileged: true`

Document host-level BIRD when container BGP is unavailable.
