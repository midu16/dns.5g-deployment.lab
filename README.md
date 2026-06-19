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

## Ports

| Port | Service |
|------|---------|
| 5354 | dnsdist-recursive (client-facing; rootless lab, avoids mDNS 5353) |
| 5300 | dnsdist-auth (internal) |
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
- [Scale-out: anycast](docs/scale-out/anycast-bgp.md)
- [Scale-out: BIND interop](docs/scale-out/bind-interop.md)

## Tests

```bash
./tests/smoke/run.sh           # Baseline health + DNSSEC
./tests/chaos/kill-primary.sh  # Auth failover
./tests/chaos/kill-unbound.sh  # Recursive failover
```

## Production deployment

- [Ansible roles](deploy/ansible/README.md)
- [Kubernetes / OpenShift](deploy/kubernetes/README.md)

## Explicit non-goals (v1)

Custom resolver code, anycast, multi-master authoritative, combined dnsmasq-style servers.
