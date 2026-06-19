# DNSSEC Key Rollover Runbook

This runbook covers KSK and ZSK rollover for PowerDNS-managed zones in the reference stack.

## Prerequisites

- Access to PowerDNS primary container: `podman compose exec pdns-primary pdnsutil ...`
- Zone already secured: `pdnsutil show-zone <zone>` shows CSK/KSK/ZSK keys

## ZSK rollover (routine, automated-friendly)

PowerDNS supports RFC 6781-style rollovers via `pdnsutil`:

```bash
ZONE=infra.5g-deployment.lab
podman compose exec pdns-primary pdnsutil show-zone "$ZONE"
podman compose exec pdns-primary pdnsutil activate-zone-key "$ZONE" <key-id>
podman compose exec pdns-primary pdnsutil deactivate-zone-key "$ZONE" <old-key-id>
```

For automated signing, enable `default-soa-edit=INCREMENT` and use PowerDNS built-in signer.

## KSK rollover (requires DS update at parent)

1. Generate new KSK: `pdnsutil add-zone-key "$ZONE" ksk active`
2. Publish new DNSKEY in zone (automatic with PowerDNS signer)
3. Wait for TTL expiry on old DNSKEY
4. Update DS record at parent registrar (if public zone)
5. Deactivate old KSK after propagation

For lab zones (`*.5g-deployment.lab`), update Unbound trust anchor:

```bash
podman compose exec pdns-primary pdnsutil show-zone "$ZONE" | grep ^DS \
  >> config/unbound/trust-anchor.conf
podman compose restart unbound-1 unbound-2
```

## Calendar reminders

| Event | Frequency |
|-------|-----------|
| Review key ages | Monthly |
| ZSK rollover drill | Quarterly |
| KSK rollover drill | Annually |

## Rollback

If validation breaks after rollover:

1. Reactivate previous key: `pdnsutil activate-zone-key`
2. Re-sync trust anchor to Unbound
3. Verify with `delv +rtrace @127.0.0.1 -p 5300 ns1.$ZONE A`
