# Replace forcedns with Proper DNS Configuration

The lab `forcedns` script rewrites `/etc/resolv.conf` on hypervisor guests. This is fragile and masks resolver failures. Use these patterns instead.

## Target architecture

```
Client → CoreDNS (K8s) or DHCP-provided resolver → dnsdist-recursive → Unbound → dnsdist-auth (local zones)
```

## Step 1: Deploy recursive VIP

Point clients at the recursive dnsdist VIP (Compose lab: `127.0.0.1:53`; production: dedicated service IP).

## Step 2: DHCP option 6

Configure dnsmasq or ISC DHCP to hand out the recursive VIP:

```
dhcp-option=6,<RECURSIVE_VIP>
```

Remove per-guest `forcedns` cron/systemd units.

## Step 3: Kubernetes / OpenShift cluster DNS

Patch CoreDNS to forward to the recursive tier. See [`deploy/kubernetes/coredns-forward-patch.yaml`](../../deploy/kubernetes/coredns-forward-patch.yaml).

```yaml
forward . <RECURSIVE_VIP>:53 {
  max_concurrent 1000
}
```

For OpenShift, edit the `dns` operator or `cluster-dns-operator` forward policy to upstream at the recursive VIP.

## Step 4: NodeLocal DNSCache (optional)

For large clusters, deploy NodeLocal DNSCache with forward to recursive VIP — reduces latency and isolates pod DNS from node resolver changes.

## Verification

```bash
# From a pod or guest
dig @<RECURSIVE_VIP> ns1.infra.5g-deployment.lab A +short
# Expected: auth dnsdist VIP (10.89.2.10 in lab)
```

## What to remove

- Scripts that overwrite `/etc/resolv.conf` on boot
- Hard-coded nameserver entries in cloud-init without DHCP option 6
- Combined dnsmasq authoritative + recursive for production zones

## Rollback

Restore previous DHCP option 6 and CoreDNS ConfigMap from Git; no client-side resolv.conf hacks required.
