# BIND Interoperability

PowerDNS primary with ISC BIND secondaries is a common production pattern. This stack uses PowerDNS for all three authoritative nodes in v1; use this guide when BIND is required.

## BIND as secondary

### PowerDNS primary configuration

Ensure AXFR is allowed to BIND secondary IP with TSIG:

```ini
allow-axfr-ips=10.89.2.50
also-notify=10.89.2.50
```

Import TSIG key: `pdnsutil import-tsig-key bind-slave. bind-slave. "<secret>"`

### BIND secondary configuration

```bind
zone "infra.5g-deployment.lab" {
    type secondary;
    file "secondary/infra.5g-deployment.lab";
    primaries { 10.89.2.11; };
    allow-transfer { none; };
};
```

Configure TSIG in BIND:

```bind
key "axfr-key." {
    algorithm hmac-sha256;
    secret "<base64-secret>";
};
```

### dnsdist auth front-end

Add BIND secondary as additional backend in [`config/dnsdist/dnsdist-auth.conf`](../../config/dnsdist/dnsdist-auth.conf):

```lua
newServer({ address = "bind-secondary:53", name = "bind-secondary", ... })
```

## BIND as primary (not recommended for GitOps path)

If BIND must be primary, use OctoDNS BIND provider as source and PowerDNS as secondary — loses native PowerDNS DNSSEC automation. Prefer PowerDNS primary for new deployments.

## Testing interop

1. Add BIND container to Compose with secondary config
2. Trigger NOTIFY from PowerDNS primary
3. Verify zone serial match: `dig @bind SOA infra.5g-deployment.lab`
4. Include BIND in dnsdist auth pool health checks
