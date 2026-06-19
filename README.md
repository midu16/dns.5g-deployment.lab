# Robust DNS Reference Architecture

Research-grade, deployable DNS stack separating authoritative and recursive roles with HA, DNSSEC, GitOps zone management, and observability.

## Quick start

Requires [podman-compose](https://github.com/containers/podman-compose) (`pip install --user podman-compose`).

```bash
cp .env.example .env
# Edit .env — generate TSIG: deploy/compose/scripts/generate-tsig.sh

cd deploy/compose
podman-compose up -d

# Wait for healthchecks, then bootstrap zones + DNSSEC
./scripts/bootstrap-zones.sh

# Run smoke tests (uses in-network dns-tools container)
../../tests/smoke/run.sh
```

## Architecture

| Layer | Software |
|-------|----------|
| Authoritative | PowerDNS (PostgreSQL) + 2 secondaries |
| Auth front-end | dnsdist |
| Recursive | Unbound (validating) ×2 |
| Recursive front-end | dnsdist |
| Platform stub | CoreDNS |
| GitOps | GitOps controller + OctoDNS |
| Monitoring | Prometheus + Grafana + blackbox_exporter |

See [docs/architecture.md](docs/architecture.md) for the full design.

## Reference zones

Mirrors lab zones from the 5G deployment environment:

- `infra.5g-deployment.lab`
- `api.hub.5g-deployment.lab`

NS records point at the auth dnsdist VIP (`AUTH_VIP` in `.env`, default `10.89.2.10`).

## v2 optional profiles (Compose)

v1 core remains `podman-compose up -d`. v2 features are opt-in profiles:

| Profile | Command | Capability |
|---------|---------|------------|
| `edge` | `--profile edge` | dnsmasq forwarder + local overrides |
| `edge-dhcp` | `--profile edge-dhcp` | edge + DHCP option 6 |
| `policy` | `--profile policy` | external-client split-horizon tests |
| `ha` | `--profile ha` | PostgreSQL replica + PowerDNS standby |
| `dual-primary` | `--profile dual-primary` | passive primary B in auth pool |
| `anycast` | `-f docker-compose.anycast.yml --profile anycast` | 2-PoP lab + BIRD/FRR |

See [dnsmasq edge migration](docs/runbooks/dnsmasq-edge-migration.md), [primary failover](docs/runbooks/primary-failover.md), [dual-primary switchover](docs/runbooks/dual-primary-switchover.md), [ADR 001 policy layer](docs/adr/001-custom-resolver-policy-vs-protocol.md).

## Ports

| Port | Service |
|------|---------|
| 5354 | dnsdist-recursive (client-facing; rootless lab, avoids mDNS 5353) |
| 5356 | dnsmasq-edge (profile edge) |
| 5300 | dnsdist-auth (internal) |
| 5310 / 5311 | PoP EU / US unicast (profile anycast) |
| 8088 | GitOps controller webhook |
| 8081 | PowerDNS API |
| 9090 | Prometheus |
| 3001 | Grafana |

## Documentation

- [Architecture](docs/architecture.md)
- [Reliability model & SLOs](docs/reliability-model.md)
- [Threat model](docs/threat-model.md)
- [Zone GitOps runbook](docs/runbooks/zone-gitops.md)
- [DNSSEC rollover runbook](docs/runbooks/dnssec-rollover.md)
- [Replace forcedns runbook](docs/runbooks/replace-forcedns.md)
- [dnsmasq edge migration (v2)](docs/runbooks/dnsmasq-edge-migration.md)
- [Primary failover (v2)](docs/runbooks/primary-failover.md)
- [Dual-primary switchover (v2)](docs/runbooks/dual-primary-switchover.md)
- [Scale-out: anycast](docs/scale-out/anycast-bgp.md)
- [Scale-out: BIND interop](docs/scale-out/bind-interop.md)

## Tests

```bash
./tests/smoke/run.sh           # Baseline health + DNSSEC
./tests/smoke/edge-dnsmasq.sh  # v2 edge profile
./tests/smoke/policy-split-horizon.sh  # v2 dnsdist policies
./tests/smoke/anycast-pop.sh   # v2 anycast profile
./tests/chaos/kill-primary.sh  # Auth failover
./tests/chaos/kill-primary-ha.sh  # v2 HA profile
./tests/chaos/kill-unbound.sh  # Recursive failover
./tests/chaos/withdraw-pop-route.sh  # v2 anycast PoP withdraw
```

## Production deployment

- [Ansible roles](deploy/ansible/README.md)
- [Kubernetes / OpenShift](deploy/kubernetes/README.md)

v1 non-goals are addressed as **optional v2 profiles** (see table above). Custom protocol implementations remain out of scope per [ADR 001](docs/adr/001-custom-resolver-policy-vs-protocol.md).
