# Tailscale DNS Host-Aligned Naming Integration

**Date**: 2025-12-19T00:30:00+01:00
**Session**: Tailscale DNS Standardization
**STAMP Compliance**: SC-CLU-001 to SC-CLU-005

---

## Summary

Completed the alignment of container naming with host Tailscale identity. All containers now inherit the host machine's Tailscale hostname, ensuring proper MagicDNS resolution and identity-based access control.

## Naming Convention

**Pattern**: `{service}-{TS_HOSTNAME}.{TAILSCALE_DNS_SUFFIX}`

### Examples

| Service | Host | FQDN |
|---------|------|------|
| Application | devbox | `indrajaal-devbox.tailnet-abc.ts.net` |
| Database | devbox | `timescaledb-devbox.tailnet-abc.ts.net` |
| Redis | devbox | `redis-devbox.tailnet-abc.ts.net` |
| Prometheus | devbox | `prometheus-devbox.tailnet-abc.ts.net` |

## Files Modified

### 1. `tailscale.env`
- Updated container FQDN pattern to use `${TS_HOSTNAME}`
- Added `CLUSTER_NODE_1`, `CLUSTER_NODE_2`, `CLUSTER_NODE_3` variables
- Updated `CLUSTER_NODES` to use host-aligned naming

### 2. `podman-compose.yml`
- Updated 6 container hostnames to host-aligned defaults:
  - `timescaledb-localhost.tailnet.ts.net`
  - `redis-localhost.tailnet.ts.net`
  - `indrajaal-localhost.tailnet.ts.net`
  - `prometheus-localhost.tailnet.ts.net`
  - `grafana-localhost.tailnet.ts.net`
  - `nginx-localhost.tailnet.ts.net`

### 3. `podman-compose-cluster.yml`
- Updated 3 cluster node hostnames:
  - `indrajaal-node1.tailnet.ts.net`
  - `indrajaal-node2.tailnet.ts.net`
  - `indrajaal-node3.tailnet.ts.net`
- Updated `ERL_AFLAGS` to use `CLUSTER_NODE_*` variables
- Updated `CLUSTER_NODES` to use environment variable

### 4. `scripts/cluster/tailscale_setup.sh`
- Updated `generate_container_dns()` to show host-aligned names
- Added hostname extraction from Tailscale status

### 5. `docs/architecture/tailscale-dns-integration-guide.md`
- Updated architecture diagrams to show host-aligned naming
- Updated examples to reflect new naming convention

## STAMP Compliance

| Constraint | Status | Implementation |
|------------|--------|----------------|
| SC-CLU-001 | COMPLIANT | Host-aligned FQDN naming |
| SC-CLU-002 | COMPLIANT | 3-node minimum cluster |
| SC-CLU-003 | COMPLIANT | K8s DNS support |
| SC-CLU-004 | COMPLIANT | EPMD binds to Tailscale IP |
| SC-CLU-005 | COMPLIANT | Consistent naming prevents split-brain |

## Usage

### Single-Host Deployment
```bash
# Auto-detect host Tailscale identity
export TS_HOSTNAME=$(tailscale status --json | jq -r '.Self.HostName')
export TAILSCALE_DNS_SUFFIX=$(tailscale status --json | jq -r '.MagicDNSSuffix')

# Start containers with host-aligned names
podman-compose --env-file tailscale.env -f podman-compose.yml up -d
```

### Multi-Host Cluster
```bash
# On each host, set cluster node variables
export TS_HOSTNAME=$(tailscale status --json | jq -r '.Self.HostName')
export CLUSTER_NODE_1=$TS_HOSTNAME  # This host
export CLUSTER_NODE_2=server2       # Other host
export CLUSTER_NODE_3=server3       # Third host

# Start cluster node
podman-compose --env-file tailscale.env -f podman-compose-cluster.yml up -d
```

## Benefits

1. **Identity Inheritance**: Containers inherit host Tailscale identity
2. **ACL Alignment**: Tailscale ACLs can target services by host
3. **Clear Provenance**: Easy to identify which host runs which service
4. **MagicDNS Integration**: Proper DNS resolution across tailnet

## Remaining Tasks

- [ ] Update `config/runtime.exs` with centralized Tailscale config
- [ ] Verify all tests pass with new naming

---

**Status**: COMPLETE
**Next**: Update runtime.exs configuration
