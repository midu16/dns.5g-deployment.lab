# Kubernetes / OpenShift Deployment

Manifests for running the recursive and stub layers on OpenShift. Authoritative tier typically runs on dedicated VMs or a separate cluster segment.

## Components

| Manifest | Purpose |
|----------|---------|
| [`coredns-forward-patch.yaml`](coredns-forward-patch.yaml) | Forward cluster DNS to recursive VIP |
| `unbound-deployment.yaml` | Validating resolver pool (optional in-cluster) |
| `dnsdist-recursive.yaml` | Load balancer for Unbound (DaemonSet or Deployment) |

## OpenShift DNS operator

Replace `RECURSIVE_VIP` in the CoreDNS patch with your recursive dnsdist service IP:

```bash
RECURSIVE_VIP=10.89.3.10
sed "s/RECURSIVE_VIP/${RECURSIVE_VIP}/g" coredns-forward-patch.yaml | oc apply -f -
```

Or configure the Cluster DNS Operator upstream via DNS spec (OpenShift 4.14+):

```yaml
apiVersion: operator.openshift.io/v1
kind: DNS
metadata:
  name: cluster
spec:
  upstreamPolicy:
    upstreams:
      - type: Forward
        forwardPolicy: Sequential
        upstreams:
          - address: 10.89.3.10
            port: 53
```

## Authoritative tier

PowerDNS primary + secondaries should **not** run inside the application cluster for production. Deploy via [`deploy/ansible/`](../ansible/) on dedicated DNS hosts.

## Network policies

Restrict Unbound to accept queries only from:
- CoreDNS pod CIDR
- Node CIDR
- dnsdist-recursive pods

## Monitoring

Scrape dnsdist and PowerDNS metrics via Prometheus Operator `ServiceMonitor` resources. Import dashboards from [`monitoring/grafana/dashboards/`](../../monitoring/grafana/dashboards/).

## Security context

Run dnsdist and Unbound as non-root where image supports it. OpenShift restricted SCC may require custom SCC for binding low ports — prefer NodePort or hostNetwork DaemonSet for dnsdist-recursive on port 53.
