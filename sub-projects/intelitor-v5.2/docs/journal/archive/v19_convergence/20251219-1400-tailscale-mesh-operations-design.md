# Journal Entry: Tailscale Mesh Operations Architecture Design

**Date:** 2025-12-19
**Time:** 14:00 CET
**Author:** Claude Code (Agent)
**Subject:** Complete Tailscale Mesh Networking Operations Architecture
**Document Reference:** `docs/architecture/TAILSCALE_MESH_OPERATIONS.md`

---

## 1. Executive Summary

This journal entry documents the design decisions, research findings, and rationale behind the comprehensive Tailscale Mesh Operations Architecture document. The work addresses the "Split-Brain" networking topology where the application container is mesh-enabled but infrastructure containers (database, cache, observability) remain on bridge-only networking.

### Deliverables Created

| Artifact | Path | Lines | Purpose |
|----------|------|-------|---------|
| Operations Architecture | `docs/architecture/TAILSCALE_MESH_OPERATIONS.md` | ~800 | Complete operational specification |
| This Journal Entry | `docs/journal/20251219-1400-tailscale-mesh-operations-design.md` | ~400 | Design rationale & research log |

---

## 2. Research Sources Reviewed

### 2.1 External Tailscale Documentation

| Source | URL | Key Findings |
|--------|-----|--------------|
| Tailscale Containers Guide | https://tailscale.com/kb/1282/docker | Sidecar vs direct integration patterns |
| Kubernetes Operator | https://tailscale.com/kb/1185/kubernetes | Operator CRD patterns for K8s |
| Auth Keys | https://tailscale.com/kb/1085/auth-keys | Key types: one-time, reusable, ephemeral, tagged |
| MagicDNS | https://tailscale.com/kb/1081/magicdns | 100.100.100.100 resolver, FQDN structure |
| ACLs | https://tailscale.com/kb/1018/acls | Tag-based access control, autoApprovers |
| Subnet Routers | https://tailscale.com/kb/1019/subnets | `--advertise-routes` for bridge exposure |
| DERP Servers | https://tailscale.com/kb/1232/derp-servers | 20+ regions, ~15s failover, TCP/443 traversal |
| Exit Nodes | https://tailscale.com/kb/1103/exit-nodes | Full traffic routing through mesh |
| Funnel | https://tailscale.com/kb/1223/funnel | Public HTTPS exposure via mesh |
| Headscale | https://github.com/juanfont/headscale | Self-hosted control plane alternative |
| Tailscale API | https://tailscale.com/kb/1101/api | Device management, key rotation |
| Troubleshooting | https://tailscale.com/kb/1023/troubleshooting | Connection debugging procedures |
| Network Lock | https://tailscale.com/kb/1226/tailnet-lock | Cryptographic node verification |

### 2.2 Local Project Files Reviewed

| File | Purpose | Implications |
|------|---------|--------------|
| `containers/lib/tailscale.nix` | Nix wrapper library | Functional pattern for entrypoint wrapping |
| `containers/indrajaal-timescaledb-demo.nix` | DB container definition | Integration example with `ts.wrap` |
| `docs/architecture/NIX_MESH_WRAPPER_DESIGN.md` | Design note | Constraints: read-only rootfs, no COPY in Nix |
| `docs/architecture/FULL_MESH_GAP_ANALYSIS.md` | Gap analysis | Current state: App=READY, DB/Redis/Nginx=GAP |
| `docs/architecture/tailscale-dns-integration-guide.md` | DNS guide | FQDN mapping, STAMP compliance matrix |
| `docs/journal/20251219-1100-nix-mesh-expansion.md` | Previous journal | 5-level implementation plan |
| `podman-compose.yml` | Orchestration | Volume mounts, environment variables |
| `podman-compose-3container.yml` | 3-container variant | Simplified topology |
| `config/runtime.exs` | Runtime config | Database URL configuration patterns |
| `CLAUDE.md` | System specification | STAMP constraints SC-CLU-*, SC-FLAME-* |

---

## 3. Key Design Decisions

### 3.1 Decision: ON/OFF Toggle via Environment Variable

**Problem:** Not all environments need mesh networking. Development may use local bridge, while production uses full mesh.

**Options Considered:**
1. Compile-time toggle (build separate images)
2. Runtime toggle via environment variable
3. Configuration file toggle

**Decision:** Runtime environment variable `TS_ENABLED`

**Rationale:**
- Same image works in all environments (12-factor app principle)
- No rebuild required to toggle networking mode
- Easy integration with orchestration (Kubernetes ConfigMaps, Podman env)
- Clear boolean semantics: `0`=off, `1`=on

**Implementation:**
```bash
# In Nix wrapper (containers/lib/tailscale.nix)
if [ "${TS_ENABLED:-0}" != "1" ]; then
    log "Tailscale DISABLED (TS_ENABLED != 1). Skipping mesh setup."
    exec ${originalEntrypoint}/bin/docker-entrypoint "$@"
fi
```

### 3.2 Decision: Separate Auth Keys Per Container Category

**Problem:** How to manage authentication for multiple containers across environments?

**Options Considered:**
1. Single shared key for all containers
2. Per-container unique keys
3. Category-based keys (app, db, infra, obs)

**Decision:** Category-based keys with tags

**Rationale:**
- Enables ACL enforcement at category level (`tag:db` can receive from `tag:app`)
- Reduces key management overhead vs per-container keys
- Better security isolation than single shared key
- Aligns with STAMP constraint SC-CLU-001 (identity-based networking)

**Key Mapping:**
```
Environment Variable          Container(s)           Tag
TS_AUTHKEY_APP               indrajaal-app          tag:app
TS_AUTHKEY_DB                postgres, timescaledb  tag:db
TS_AUTHKEY_INFRA             redis, nginx           tag:infra
TS_AUTHKEY_OBS               signoz, otel-collector tag:obs
TS_AUTHKEY_FLAME             flame-runner-*         tag:flame
```

### 3.3 Decision: Dual Network Interface Architecture

**Problem:** Mesh adds latency (~1-5ms). High-throughput local traffic shouldn't traverse mesh.

**Options Considered:**
1. Mesh-only (all traffic through Tailscale)
2. Bridge-only (no mesh benefits)
3. Dual interface with routing rules

**Decision:** Dual interface with explicit routing

**Rationale:**
- Local bulk data (DB connections from same host) uses bridge (microsecond latency)
- Cross-host and remote access uses mesh (encrypted, identity-verified)
- Prevents routing loops via explicit interface binding
- Aligns with STAMP constraint SC-CLU-004 (network performance)

**Routing Strategy:**
```
Source          Destination        Interface    Use Case
app (local)     db (same host)     bridge       Bulk queries, migrations
app (remote)    db (mesh)          tailscale0   Cross-host, remote dev
admin (laptop)  db (mesh)          tailscale0   Debug access
```

### 3.4 Decision: Userspace Networking Mode

**Problem:** Rootless Podman containers don't have access to `/dev/net/tun`.

**Options Considered:**
1. Privileged containers with tun device
2. Userspace networking mode
3. Host networking (defeats isolation)

**Decision:** Userspace networking with automatic fallback

**Rationale:**
- Maintains rootless security posture
- Functional in all container runtimes (Podman, Docker, Kubernetes)
- Slight performance penalty acceptable for control plane
- Aligns with STAMP constraint SC-CNT-012 (rootless execution)

**Implementation:**
```bash
if [ -c /dev/net/tun ]; then
    tailscaled --state=${TS_STATE_DIR}/tailscaled.state --socket=${TS_SOCKET} &
else
    tailscaled --tun=userspace-networking --state=${TS_STATE_DIR}/tailscaled.state --socket=${TS_SOCKET} &
fi
```

### 3.5 Decision: State Persistence via Volume Mounts

**Problem:** Container restarts lose Tailscale identity, creating new devices in admin console.

**Options Considered:**
1. Ephemeral keys (auto-cleanup)
2. Persistent state volumes
3. Re-authentication on every start

**Decision:** Persistent state volumes with ephemeral key fallback

**Rationale:**
- Stable device identity in admin console
- Faster startup (no re-authentication if state valid)
- Ephemeral keys as fallback for truly ephemeral workloads (FLAME runners)
- Volume mount path: `/var/lib/tailscale`

**Volume Configuration:**
```yaml
volumes:
  tailscale_app_state:
  tailscale_db_state:
  tailscale_infra_state:
```

---

## 4. Error Condition Analysis

### 4.1 Error Categories Identified

| Code | Category | Severity | Recovery |
|------|----------|----------|----------|
| TS-ERR-001 | Auth key invalid/expired | Critical | Rotate key, restart |
| TS-ERR-002 | Control plane unreachable | Warning | Use cached policies, retry |
| TS-ERR-003 | DERP relay timeout | Warning | Automatic failover (~15s) |
| TS-ERR-004 | DNS resolution failure | Error | Fallback to IP, check MagicDNS |
| TS-ERR-005 | ACL denied | Error | Update ACL rules |
| TS-ERR-006 | State corruption | Critical | Clear state, re-authenticate |
| TS-ERR-007 | Userspace mode failure | Critical | Check permissions, restart |
| TS-ERR-008 | Certificate expiry | Warning | Automatic renewal (24h before) |
| TS-ERR-009 | Network partition | Warning | Use local bridge until healed |
| TS-ERR-010 | Resource exhaustion | Critical | Check memory/CPU, scale down |

### 4.2 Critical Insight: Offline Resilience

**Finding:** Tailscale maintains cached policies when control plane is unreachable.

**Implication:** Existing mesh connections continue working during control plane outages. New connections may fail until control plane returns.

**STAMP Alignment:** SC-CLU-005 (split-brain prevention) - mesh continues operating with cached state.

---

## 5. Performance Considerations

### 5.1 Latency Analysis

| Path | Expected Latency | Notes |
|------|------------------|-------|
| Direct P2P (same LAN) | 1-2ms | After NAT traversal |
| Direct P2P (cross-region) | 20-100ms | Geographic distance |
| DERP relay | 50-200ms | Through relay server |
| Bridge network | <1ms | Local only |

### 5.2 Throughput Analysis

| Mode | Expected Throughput | Bottleneck |
|------|---------------------|------------|
| Direct P2P | Near line rate | WireGuard encryption CPU |
| DERP relay | ~100Mbps typical | Relay server capacity |
| Userspace networking | Reduced vs kernel | Context switches |

### 5.3 Optimization Recommendations

1. **Use direct P2P when possible**: Ensure NAT traversal succeeds
2. **Bind high-throughput traffic to bridge**: Database bulk operations
3. **Monitor DERP usage**: High DERP indicates NAT traversal failures
4. **Consider kernel mode for high-throughput**: Where `/dev/net/tun` available

---

## 6. Security Model Summary

### 6.1 Authentication Layers

1. **Auth Keys**: Initial device authentication
2. **WireGuard Keys**: Cryptographic device identity
3. **ACLs**: Access control between tagged devices
4. **Network Lock (optional)**: Additional cryptographic verification

### 6.2 ACL Example

```json
{
  "tagOwners": {
    "tag:app": ["autogroup:admin"],
    "tag:db": ["autogroup:admin"],
    "tag:infra": ["autogroup:admin"],
    "tag:obs": ["autogroup:admin"]
  },
  "acls": [
    {"action": "accept", "src": ["tag:app"], "dst": ["tag:db:5432,5433"]},
    {"action": "accept", "src": ["tag:app"], "dst": ["tag:infra:6379"]},
    {"action": "accept", "src": ["tag:obs"], "dst": ["*:*"]},
    {"action": "accept", "src": ["autogroup:admin"], "dst": ["*:*"]}
  ],
  "autoApprovers": {
    "routes": {
      "10.89.0.0/24": ["tag:infra"]
    }
  }
}
```

---

## 7. STAMP Compliance Mapping

| STAMP Constraint | Requirement | Addressed In |
|------------------|-------------|--------------|
| SC-CLU-001 | Identity-based networking | Auth keys with tags |
| SC-CLU-002 | Minimum 3 nodes HA | Multi-container deployment |
| SC-CLU-003 | Kubernetes DNS in production | MagicDNS + libcluster |
| SC-CLU-004 | EPMD binding to Tailscale IP | Runtime configuration |
| SC-CLU-005 | Split-brain prevention | Cached policies, quorum |
| SC-FLAME-001 | No local state reliance | State persistence volumes |
| SC-FLAME-004 | Graceful draining | Shutdown procedure |
| SC-FLAME-006 | Configurable backend | TS_ENABLED toggle |

---

## 8. Implementation Roadmap

### Phase 1: Infrastructure Containers (Current Focus)
- [ ] Update `containers/lib/tailscale.nix` with toggle logic
- [ ] Add Tailscale to `indrajaal-redis-demo.nix`
- [ ] Add Tailscale to `nginx-nixos.nix`
- [ ] Update `podman-compose.yml` with volumes and env vars

### Phase 2: Testing & Validation
- [ ] Local bridge + mesh dual-mode testing
- [ ] Cross-host connectivity verification
- [ ] ACL enforcement testing
- [ ] Failover scenario testing (DERP, control plane down)

### Phase 3: Production Hardening
- [ ] Network Lock evaluation
- [ ] Key rotation automation
- [ ] Monitoring dashboard integration
- [ ] Runbook creation for error conditions

---

## 9. Open Questions

1. **Headscale vs Tailscale SaaS**: Should we evaluate self-hosted control plane for air-gapped deployments?
2. **FLAME Runner Key Rotation**: Ephemeral keys have 30min-48hr lifetimes - sufficient for FLAME workloads?
3. **Subnet Router Placement**: Which container should advertise bridge subnet routes?
4. **Certificate Pinning**: Should we enable Network Lock for additional security?

---

## 10. Conclusion

The Tailscale Mesh Operations Architecture document provides a complete specification for unified mesh networking across all Indrajaal containers. Key innovations include:

1. **Toggle Mechanism**: Environment-variable-based ON/OFF for deployment flexibility
2. **Category Keys**: Balanced security isolation with manageable key count
3. **Dual Networking**: Performance optimization with explicit routing
4. **Error Matrix**: Comprehensive error handling with recovery procedures

The design aligns with STAMP safety constraints and supports the goal of eliminating the "Split-Brain" networking topology where only the application container has mesh access.

---

## References

### Created Documents
- `docs/architecture/TAILSCALE_MESH_OPERATIONS.md` - Main architecture document

### Related Project Files
- `containers/lib/tailscale.nix` - Nix wrapper implementation
- `docs/architecture/NIX_MESH_WRAPPER_DESIGN.md` - Design note
- `docs/architecture/FULL_MESH_GAP_ANALYSIS.md` - Gap analysis
- `docs/architecture/tailscale-dns-integration-guide.md` - DNS guide
- `CLAUDE.md` - System specification (STAMP constraints)

### External Documentation
- Tailscale Knowledge Base: https://tailscale.com/kb/
- Headscale Project: https://github.com/juanfont/headscale
- WireGuard Protocol: https://www.wireguard.com/

---

**Document Status:** COMPLETE
**Next Action:** Implementation of Phase 1 (Infrastructure Container Updates)
