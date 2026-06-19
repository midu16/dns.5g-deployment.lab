# Ansible Deployment

Skeleton roles extracted from the Podman Compose reference stack. Templates use variables from `group_vars/all.yml`.

## Prerequisites

- Ansible 2.14+
- Target hosts: RHEL/Fedora or Debian with Podman or native packages
- PostgreSQL reachable from PowerDNS primary host

## Role layout

```
deploy/ansible/
├── README.md
├── site.yml
├── group_vars/all.yml
└── roles/
    ├── powerdns/
    ├── dnsdist/
    ├── unbound/
    └── monitoring/
```

## Quick start (skeleton)

```bash
cd deploy/ansible
cp group_vars/all.example.yml group_vars/all.yml
ansible-playbook -i inventory site.yml
```

## Variables (group_vars/all.yml)

| Variable | Description |
|----------|-------------|
| `pdns_db_host` | PostgreSQL host |
| `pdns_api_key` | PowerDNS API key (from vault) |
| `tsig_key_name` / `tsig_key_secret` | AXFR TSIG |
| `auth_vip` | dnsdist auth address |
| `recursive_vip` | dnsdist recursive address |
| `recursive_acl` | CIDRs allowed to recurse |

## Role responsibilities

| Role | Templates from |
|------|------------------|
| `powerdns` | `config/powerdns/pdns-primary.conf`, `pdns-secondary.conf` |
| `dnsdist` | `config/dnsdist/dnsdist-auth.conf`, `dnsdist-recursive.conf` |
| `unbound` | `config/unbound/unbound.conf` |
| `monitoring` | `monitoring/prometheus/`, Grafana provisioning |

## Production notes

- Store secrets in Ansible Vault
- Use systemd units for pdns, dnsdist, unbound
- Separate hosts for auth tier vs recursive tier in production
