# ADR 001: Custom Resolver Policy vs Protocol Implementation

## Status

Accepted (v2)

## Context

The v1 stack deliberately excluded "custom resolver code" to avoid operating a bespoke DNS protocol implementation. Operators still need policy hooks: split-horizon, blocklists, rate limits, and migration paths from monolithic resolvers.

## Decision

Implement **policy at the edge** using proven daemons:

| Need | Mechanism | Layer |
|------|-----------|-------|
| Split-horizon, blocklist, QPS | dnsdist Lua (`config/dnsdist/policies/`) | Recursive front-end |
| Validation + local mirror | Unbound `local-data` / views | Resolver |
| Kubernetes stub forwarding | CoreDNS plugins / forward | Platform |
| Small-site combined DHCP+DNS | dnsmasq edge profile (forward only) | Edge |

Do **not** implement a custom DNS wire-protocol stack, custom caching resolver, or replace Unbound/PowerDNS for core recursion/authority.

## Consequences

- Policies are versioned as Lua/YAML alongside existing configs; CI can run `dnsdist --check-config`.
- Split-horizon tests depend on client source IP visibility at dnsdist (preserve real client subnets or use EDNS Client Subnet only when explicitly designed).
- Edge dnsmasq must not become an authoritative signing tier; GitOps → PowerDNS remains the write path.

## When to revisit

- Need for application-layer DNS (DoH/DoT termination) → add dedicated proxy (e.g. dnsdist DoH), not custom UDP stack.
- Geo-aware answers at global scale → pair anycast PoPs with dnsdist Lua or dedicated GSLB; still no custom resolver core.
