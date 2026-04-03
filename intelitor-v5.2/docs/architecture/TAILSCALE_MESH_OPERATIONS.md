# Tailscale Mesh Networking: Complete Operations Architecture

**Version**: 2.0.0
**Date**: 2025-12-19
**Classification**: INFRASTRUCTURE / NETWORKING / SECURITY
**STAMP Compliance**: SC-CLU-001 to SC-CLU-005, SC-FLAME-001 to SC-FLAME-006
**Status**: COMPREHENSIVE SPECIFICATION
**Author**: Claude Code (Opus 4.5)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Control Plane vs Data Plane](#3-control-plane-vs-data-plane)
4. [Container Integration Design](#4-container-integration-design)
5. [ON/OFF Toggle Mechanism](#5-onoff-toggle-mechanism)
6. [Authentication Key Management](#6-authentication-key-management)
7. [Dual Network Interface Architecture](#7-dual-network-interface-architecture)
8. [Lifecycle Operations](#8-lifecycle-operations)
9. [Error Conditions & Recovery](#9-error-conditions--recovery)
10. [Performance Considerations](#10-performance-considerations)
11. [Security Model](#11-security-model)
12. [Monitoring & Observability](#12-monitoring--observability)
13. [References](#13-references)

---

## 1. Executive Summary

### 1.1 Purpose

This document provides the complete operational specification for Tailscale mesh networking integration across all Indrajaal containerized services. It covers:

- **Toggle Control**: Per-container ON/OFF switch for Tailscale integration
- **Key Management**: Secure authentication key distribution strategy
- **Dual Networking**: Coexistence of Tailscale mesh and bridge networks
- **Full Lifecycle**: Setup, activation, runtime, error handling, and shutdown
- **Performance**: Control plane vs data plane optimization

### 1.2 Current State Assessment

| Component | Build Method | Tailscale Status | Toggle Support | Network Mode |
|-----------|-------------|------------------|----------------|--------------|
| **sopv51-app** | Dockerfile | ✅ READY | ✅ Implemented | Dual (Mesh + Bridge) |
| **sopv51-base** | Dockerfile | ✅ Binary Present | N/A | N/A |
| **TimescaleDB** | Nix | ⚠️ Wrapper Ready | 🔲 Pending | Bridge Only |
| **Redis** | Nix | 🔲 Not Integrated | 🔲 Pending | Bridge Only |
| **Nginx** | Nix | 🔲 Not Integrated | 🔲 Pending | Bridge Only |
| **Observability Stack** | Docker Compose | 🔲 Not Integrated | 🔲 Pending | Bridge Only |

### 1.3 Design Principles

1. **Opt-In Mesh**: Tailscale is optional per container via `TS_ENABLED`
2. **Fail-Safe**: Containers must start even if Tailscale fails (bridge fallback)
3. **Key Separation**: Each container type has unique auth key lineage
4. **Network Isolation**: Mesh and data paths are logically separated
5. **State Persistence**: Identity survives container restarts
6. **Graceful Degradation**: Offline operation with cached policies

---

## 2. Architecture Overview

### 2.1 High-Level Topology

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                          TAILSCALE COORDINATION SERVER                           │
│                        (control.tailscale.com - Control Plane)                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│  • Key Exchange           • Policy Distribution       • ACL Enforcement          │
│  • Node Registration      • DNS Configuration         • DERP Relay Coordination  │
└───────────────────────────────────────┬─────────────────────────────────────────┘
                                        │ HTTPS (Control)
                                        ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              HOST MACHINE (devbox)                               │
│                          Tailscale IP: 100.x.x.x                                │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │                        PODMAN BRIDGE NETWORK                             │   │
│  │                    (indrajaal-network: 10.89.0.0/24)                     │   │
│  │                       HIGH-SPEED DATA PLANE                              │   │
│  ├─────────────────────────────────────────────────────────────────────────┤   │
│  │                                                                          │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐  │   │
│  │  │  APP         │  │  TIMESCALE   │  │  REDIS       │  │  NGINX      │  │   │
│  │  │  Container   │  │  Container   │  │  Container   │  │  Container  │  │   │
│  │  │              │  │              │  │              │  │             │  │   │
│  │  │ TS_ENABLED=1 │  │ TS_ENABLED=1 │  │ TS_ENABLED=0 │  │TS_ENABLED=1 │  │   │
│  │  │              │  │              │  │              │  │             │  │   │
│  │  │ ┌──────────┐ │  │ ┌──────────┐ │  │              │  │┌──────────┐ │  │   │
│  │  │ │Tailscale │ │  │ │Tailscale │ │  │  (Bridge     │  ││Tailscale │ │  │   │
│  │  │ │ Daemon   │ │  │ │ Daemon   │ │  │   Only)      │  ││ Daemon   │ │  │   │
│  │  │ └──────────┘ │  │ └──────────┘ │  │              │  │└──────────┘ │  │   │
│  │  │              │  │              │  │              │  │             │  │   │
│  │  │ 10.89.0.10   │  │ 10.89.0.20   │  │ 10.89.0.30   │  │ 10.89.0.40  │  │   │
│  │  │ 100.x.x.11   │  │ 100.x.x.12   │  │ (no mesh IP) │  │ 100.x.x.13  │  │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘  │   │
│  │         │                  │                                    │       │   │
│  │         └──────────────────┼────────────────────────────────────┘       │   │
│  │                            │                                            │   │
│  │                    WireGuard Data Plane                                 │   │
│  │                    (Direct P2P or DERP Relay)                           │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Network Address Allocation

| Network Type | CIDR | Purpose | Speed | Encryption |
|-------------|------|---------|-------|------------|
| **Podman Bridge** | 10.89.0.0/24 | Container-to-container data | 10+ Gbps | None (local) |
| **Tailscale Mesh** | 100.64.0.0/10 (CGNAT) | Cross-host, remote access | Variable | WireGuard |
| **Host Network** | Varies | External services | Native | TLS |

---

## 3. Control Plane vs Data Plane

### 3.1 Separation of Concerns

**Tailscale implements a strict separation** between control and data planes:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CONTROL PLANE                                      │
│                  (control.tailscale.com via HTTPS)                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  FUNCTIONS:                                                                  │
│  ├── Key Exchange: WireGuard public keys distributed to peers              │
│  ├── Policy Distribution: ACLs, DNS settings, exit nodes                   │
│  ├── NAT Traversal Coordination: STUN/TURN server selection               │
│  ├── DERP Map Updates: Relay server locations and health                   │
│  └── Node Metadata: Hostnames, tags, last seen times                       │
│                                                                              │
│  CHARACTERISTICS:                                                            │
│  ├── Low bandwidth (~KB/min per node)                                       │
│  ├── Tolerates 30+ minute outages (cached policies)                        │
│  ├── Encrypted (HTTPS + additional payload encryption)                      │
│  └── NOT involved in actual traffic forwarding                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                            DATA PLANE                                        │
│                     (WireGuard: Direct P2P or DERP)                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  PATH PREFERENCE (in order):                                                 │
│  1. Direct UDP (NAT traversal successful)                                   │
│  2. DERP Relay (TCP/443 via nearest relay server)                          │
│                                                                              │
│  DIRECT PATH REQUIREMENTS:                                                   │
│  ├── UDP port 41641 (default, configurable)                                │
│  ├── NAT type: Full Cone, Restricted Cone, or Port-Restricted              │
│  └── Both peers must complete STUN hole-punching                           │
│                                                                              │
│  DERP RELAY (Fallback):                                                      │
│  ├── 20+ global regions (US, EU, Asia, etc.)                               │
│  ├── Adds 50-200ms latency vs direct                                        │
│  ├── Encrypted end-to-end (relay cannot read traffic)                      │
│  └── TCP/443 through corporate firewalls                                    │
│                                                                              │
│  FAILOVER TIMING:                                                            │
│  ├── Direct → DERP: ~5-10 seconds on path failure                          │
│  ├── DERP region switch: ~15 seconds                                        │
│  └── Total HA failover: ~15 seconds                                         │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Offline Resilience

When the coordination server is unreachable:

| Feature | Status | Duration |
|---------|--------|----------|
| Existing connections | ✅ Continue working | Indefinite |
| New peer connections | ⚠️ Fails (no key exchange) | Until reconnect |
| DNS resolution | ⚠️ Cached only | Until TTL expires |
| ACL enforcement | ✅ Cached policies | Indefinite |
| Key rotation | ❌ Blocked | Until reconnect |

### 3.3 DERP Server Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DERP RELAY NETWORK                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   DERP 1    │    │   DERP 2    │    │   DERP 3    │    │   DERP N    │  │
│  │  New York   │    │  Frankfurt  │    │  Singapore  │    │   Custom    │  │
│  │             │    │             │    │             │    │             │  │
│  │ derp1.ts    │    │ derp2.ts    │    │ derp3.ts    │    │ your.derp   │  │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘    └──────┬──────┘  │
│         │                  │                  │                  │          │
│         └──────────────────┴──────────────────┴──────────────────┘          │
│                                     │                                        │
│                          Latency-based selection                            │
│                          (lowest RTT wins)                                  │
│                                                                              │
│  FAILOVER BEHAVIOR:                                                          │
│  ├── Primary DERP fails → Switch to next-lowest-latency                    │
│  ├── Switchover time: ~15 seconds                                           │
│  └── Connections preserved (WireGuard sessions survive relay change)        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Container Integration Design

### 4.1 Integration Methods by Build Type

#### 4.1.1 Dockerfile-Based Containers (App)

```dockerfile
# In sopv51-base/Dockerfile
FROM nixos/nix:latest AS tailscale-builder
RUN nix-build '<nixpkgs>' -A tailscale -o /result

FROM elixir:1.19-otp-28 AS runtime
COPY --from=tailscale-builder /result/bin/tailscale /usr/local/bin/
COPY --from=tailscale-builder /result/bin/tailscaled /usr/local/bin/
COPY scripts/containers/tailscale-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["/usr/local/bin/tailscale-entrypoint.sh"]
```

#### 4.1.2 Nix-Based Containers (Infrastructure)

```nix
# containers/lib/tailscale.nix
{ pkgs }:
let
  tailscale = pkgs.tailscale;
in {
  package = tailscale;

  wrap = originalEntrypoint:
    pkgs.writeShellScriptBin "entrypoint-with-tailscale" ''
      set -e

      # Toggle check
      if [ "''${TS_ENABLED:-0}" != "1" ]; then
        log "Tailscale DISABLED (TS_ENABLED != 1)"
        exec ${originalEntrypoint}/bin/docker-entrypoint "$@"
      fi

      # ... Tailscale startup logic ...

      exec ${originalEntrypoint}/bin/docker-entrypoint "$@"
    '';
}
```

### 4.2 Entrypoint Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CONTAINER STARTUP SEQUENCE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐                                                        │
│  │ Container Start │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐     ┌────────────────────────────────────────────┐    │
│  │ TS_ENABLED=1 ?  │─NO─▶│ Skip Tailscale, exec original entrypoint  │    │
│  └────────┬────────┘     └────────────────────────────────────────────┘    │
│           │ YES                                                             │
│           ▼                                                                  │
│  ┌─────────────────┐     ┌────────────────────────────────────────────┐    │
│  │ /dev/net/tun ?  │─NO─▶│ Use --tun=userspace-networking             │    │
│  └────────┬────────┘     └────────────────────────────────────────────┘    │
│           │ YES                     │                                       │
│           ▼                         │                                       │
│  ┌─────────────────┐               │                                       │
│  │ mkdir state dir │◀──────────────┘                                       │
│  │ /var/lib/tailsc │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │ Start tailscaled│                                                        │
│  │ (background)    │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐     ┌────────────────────────────────────────────┐    │
│  │ Wait for socket │─TIMEOUT─▶│ Log warning, continue anyway          │    │
│  │ (20 attempts)   │     └────────────────────────────────────────────┘    │
│  └────────┬────────┘                                                        │
│           │ OK                                                              │
│           ▼                                                                  │
│  ┌─────────────────┐     ┌────────────────────────────────────────────┐    │
│  │ TS_AUTHKEY set? │─NO─▶│ Skip 'tailscale up' (use cached state)    │    │
│  └────────┬────────┘     └────────────────────────────────────────────┘    │
│           │ YES                                                             │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │ tailscale up    │                                                        │
│  │ --authkey=...   │                                                        │
│  │ --hostname=...  │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │ Log Tailscale IP│                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │ exec original   │                                                        │
│  │ entrypoint      │                                                        │
│  └─────────────────┘                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. ON/OFF Toggle Mechanism

### 5.1 Environment Variable Design

```bash
# Toggle variable
TS_ENABLED=0|1|true|false

# Default: OFF (conservative)
TS_ENABLED=${TS_ENABLED:-0}
```

### 5.2 Toggle Behavior Matrix

| TS_ENABLED | TS_AUTHKEY | Behavior |
|------------|------------|----------|
| `0` or unset | Any | Skip Tailscale entirely |
| `1` | Set | Full authentication + mesh join |
| `1` | Unset | Use cached state (if exists) |
| `1` | Unset + No cache | Log warning, continue without mesh |

### 5.3 Container Configuration Table

| Service | TS_ENABLED Default | Recommended Production | Auth Key Var |
|---------|-------------------|----------------------|--------------|
| `indrajaal-app` | `1` | `1` | `TS_AUTHKEY_APP` |
| `timescaledb-primary` | `0` | `1` | `TS_AUTHKEY_DB` |
| `redis-cache` | `0` | `0` (local only) | `TS_AUTHKEY_REDIS` |
| `nginx-proxy` | `0` | `1` | `TS_AUTHKEY_NGINX` |
| `prometheus` | `0` | `1` | `TS_AUTHKEY_METRICS` |
| `grafana` | `0` | `1` | `TS_AUTHKEY_METRICS` |
| `signoz-*` | `0` | `0` (internal) | `TS_AUTHKEY_OBS` |

### 5.4 podman-compose.yml Integration

```yaml
services:
  app:
    environment:
      # Toggle ON
      TS_ENABLED: ${TS_ENABLED_APP:-1}
      TS_AUTHKEY: ${TS_AUTHKEY_APP}
      TS_HOSTNAME: ${TS_APP_FQDN:-indrajaal-app}
    volumes:
      - tailscale_app_state:/var/lib/tailscale:z
    # DUAL NETWORK: Both mesh and bridge
    networks:
      - indrajaal-network
    # Capabilities for userspace fallback
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun

  timescaledb-primary:
    environment:
      # Toggle OFF by default
      TS_ENABLED: ${TS_ENABLED_DB:-0}
      TS_AUTHKEY: ${TS_AUTHKEY_DB:-}
      TS_HOSTNAME: ${TS_DB_FQDN:-timescaledb-primary}
    volumes:
      - tailscale_db_state:/var/lib/tailscale:z
    networks:
      - indrajaal-network

  redis-cache:
    environment:
      # Redis typically stays bridge-only
      TS_ENABLED: ${TS_ENABLED_REDIS:-0}
    networks:
      - indrajaal-network

volumes:
  tailscale_app_state:
  tailscale_db_state:
  tailscale_redis_state:
  tailscale_nginx_state:
```

---

## 6. Authentication Key Management

### 6.1 Key Types Comparison

| Key Type | Reusable | Auto-Cleanup | Best For |
|----------|----------|--------------|----------|
| **One-time** | No | No | Single-use manual setup |
| **Reusable** | Yes | No | Development, persistent infra |
| **Ephemeral** | Yes | Yes (30min-48hr) | Auto-scaling, CI/CD, FLAME runners |
| **Pre-authorized** | Either | Either | Automated deployments |
| **Tagged** | Either | Either | ACL-based access control |

### 6.2 Container-to-Key Mapping

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TAILSCALE AUTH KEY ALLOCATION                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                     PRODUCTION KEYS                                 │     │
│  ├────────────────────────────────────────────────────────────────────┤     │
│  │                                                                     │     │
│  │  Key Name              │ Type      │ Tags           │ Containers   │     │
│  │  ─────────────────────┼───────────┼────────────────┼─────────────  │     │
│  │  ts-key-prod-app      │ Reusable  │ tag:app        │ indrajaal-app │     │
│  │  ts-key-prod-db       │ Reusable  │ tag:database   │ timescaledb   │     │
│  │  ts-key-prod-infra    │ Reusable  │ tag:infra      │ nginx, redis  │     │
│  │  ts-key-prod-obs      │ Reusable  │ tag:monitoring │ prometheus,   │     │
│  │                       │           │                │ grafana       │     │
│  │  ts-key-prod-flame    │ Ephemeral │ tag:flame      │ FLAME runners │     │
│  │                       │ (48hr)    │                │ (auto-cleanup)│     │
│  │                                                                     │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                     DEVELOPMENT KEYS                                │     │
│  ├────────────────────────────────────────────────────────────────────┤     │
│  │                                                                     │     │
│  │  Key Name              │ Type      │ Tags           │ Containers   │     │
│  │  ─────────────────────┼───────────┼────────────────┼─────────────  │     │
│  │  ts-key-dev-all       │ Reusable  │ tag:dev        │ All dev       │     │
│  │                       │           │                │ containers    │     │
│  │                                                                     │     │
│  └────────────────────────────────────────────────────────────────────┘     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Environment File Structure

```bash
# tailscale.env - Git-ignored, machine-specific

# Global Tailnet Configuration
TAILSCALE_DNS_SUFFIX=tailnet-abc123.ts.net
TS_IP_ADDRESS=100.64.1.5
TS_HOSTNAME=devbox

# Per-Container Keys (Production: separate keys)
TS_AUTHKEY_APP=tskey-auth-xxxxx-yyyyy
TS_AUTHKEY_DB=tskey-auth-aaaaa-bbbbb
TS_AUTHKEY_NGINX=tskey-auth-ccccc-ddddd
TS_AUTHKEY_METRICS=tskey-auth-eeeee-fffff

# Development: Single shared key (optional)
# TS_AUTHKEY=tskey-auth-dev-shared

# Per-Container Toggle Overrides
TS_ENABLED_APP=1
TS_ENABLED_DB=0
TS_ENABLED_REDIS=0
TS_ENABLED_NGINX=0

# FQDN Assignments
TS_APP_FQDN=indrajaal-app.tailnet-abc123.ts.net
TS_DB_FQDN=timescaledb-primary.tailnet-abc123.ts.net
TS_REDIS_FQDN=redis-cache.tailnet-abc123.ts.net
TS_NGINX_FQDN=nginx-proxy.tailnet-abc123.ts.net
```

### 6.4 Key Rotation Procedure

```bash
# 1. Generate new key in Tailscale Admin Console
# 2. Update .env file
# 3. Rolling restart containers one by one:

for service in app timescaledb-primary nginx; do
  echo "Rotating key for $service..."
  podman-compose stop $service
  # Old state will use new key on next auth
  rm -rf /var/lib/containers/storage/volumes/tailscale_${service}_state/_data/tailscaled.state
  podman-compose up -d $service
  sleep 30  # Allow mesh stabilization
done
```

---

## 7. Dual Network Interface Architecture

### 7.1 Design Rationale

**Why Two Networks?**

| Network | Purpose | Performance | Security |
|---------|---------|-------------|----------|
| **Bridge** | High-speed local data | 10+ Gbps | None (trusted) |
| **Mesh** | Cross-host, remote access | Variable | WireGuard |

**Use Cases:**
- **DB Queries**: Use bridge (10.89.0.x) for speed
- **Remote Debug**: Use mesh (100.x.x.x) for access
- **Cluster Gossip**: Use mesh for consistency
- **Bulk Transfers**: Use bridge when co-located

### 7.2 Routing Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      DUAL NETWORK ROUTING RULES                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  DESTINATION              │ ROUTE VIA       │ REASON                        │
│  ─────────────────────────┼─────────────────┼─────────────────────────────  │
│  10.89.0.0/24             │ Bridge          │ Local containers              │
│  100.64.0.0/10            │ Tailscale       │ Remote tailnet nodes          │
│  *.tailnet.ts.net         │ Tailscale       │ MagicDNS resolution           │
│  External (0.0.0.0/0)     │ Host gateway    │ Internet traffic              │
│                                                                              │
│  SPECIAL CASES:                                                              │
│  ─────────────────────────────────────────────────────────────────────────  │
│  • postgres → timescaledb: Bridge (10.89.0.20:5432)                         │
│  • Remote DBA → timescaledb: Mesh (100.x.x.12:5432)                         │
│  • App → Redis: Bridge (10.89.0.30:6379)                                    │
│  • Cluster EPMD: Mesh (100.x.x.x:4369) - SC-CLU-004 compliance              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 7.3 DNS Resolution Order

```bash
# In container /etc/resolv.conf (managed by entrypoint):

# 1. MagicDNS for tailnet hostnames
nameserver 100.100.100.100

# 2. Podman bridge DNS for local containers
nameserver 10.89.0.1

# 3. Host DNS for external resolution
nameserver 8.8.8.8
```

### 7.4 Loop Prevention

**Risk**: Traffic could loop between bridge and mesh interfaces.

**Mitigation**:
1. **Explicit routing**: Application config specifies interface
2. **Firewall rules**: Block mesh→bridge forwarding
3. **Split DNS**: Different domains for each network

```bash
# iptables rule (if needed) - prevent forwarding between interfaces
iptables -A FORWARD -i tailscale0 -o eth0 -j DROP
iptables -A FORWARD -i eth0 -o tailscale0 -j DROP
```

---

## 8. Lifecycle Operations

### 8.1 Setup Phase

```bash
#!/bin/bash
# scripts/cluster/tailscale_full_setup.sh

echo "=== TAILSCALE MESH SETUP ==="

# 1. Verify Tailscale installed on host
if ! command -v tailscale &> /dev/null; then
  echo "Installing Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# 2. Authenticate host
if ! tailscale status &> /dev/null; then
  echo "Authenticating host..."
  sudo tailscale up
fi

# 3. Export environment variables
export TAILSCALE_DNS_SUFFIX=$(tailscale status --json | jq -r '.MagicDNSSuffix')
export TS_IP_ADDRESS=$(tailscale ip -4)
export TS_HOSTNAME=$(hostname)

# 4. Generate tailscale.env
cat > tailscale.env << EOF
TAILSCALE_DNS_SUFFIX=${TAILSCALE_DNS_SUFFIX}
TS_IP_ADDRESS=${TS_IP_ADDRESS}
TS_HOSTNAME=${TS_HOSTNAME}
TS_APP_FQDN=indrajaal-app.${TAILSCALE_DNS_SUFFIX}
TS_DB_FQDN=timescaledb-primary.${TAILSCALE_DNS_SUFFIX}
TS_ENABLED_APP=1
TS_ENABLED_DB=0
EOF

# 5. Create volumes
podman volume create tailscale_app_state
podman volume create tailscale_db_state

echo "=== SETUP COMPLETE ==="
```

### 8.2 Activation Phase

```bash
# Start with mesh enabled
source tailscale.env
podman-compose --env-file tailscale.env up -d app

# Verify mesh connectivity
tailscale ping indrajaal-app.${TAILSCALE_DNS_SUFFIX}
```

### 8.3 Runtime Operations

#### Health Check

```bash
# Check Tailscale status inside container
podman exec indrajaal-app tailscale status

# Check mesh connectivity
podman exec indrajaal-app tailscale ping timescaledb-primary
```

#### Dynamic Toggle (No Restart)

```bash
# Disable mesh (container keeps running, but leaves tailnet)
podman exec indrajaal-app tailscale logout

# Re-enable mesh
podman exec indrajaal-app tailscale up --authkey=$TS_AUTHKEY
```

### 8.4 Backup & State Management

```bash
# Backup Tailscale state (identity)
podman volume export tailscale_app_state > tailscale_app_state_backup.tar

# Restore on new host
podman volume import tailscale_app_state < tailscale_app_state_backup.tar
```

### 8.5 Shutdown Phase

```bash
# Graceful shutdown (remove from tailnet immediately)
podman exec indrajaal-app tailscale logout

# Or let container stop (node marked as offline, not removed)
podman-compose stop app
```

#### Shutdown Behavior Comparison

| Method | Node Status | State Preserved | Cleanup |
|--------|-------------|-----------------|---------|
| `tailscale logout` | Removed immediately | State cleared | Instant |
| Container stop | Offline | State preserved | None |
| Ephemeral key expiry | Auto-removed | N/A | 30min-48hr |

---

## 9. Error Conditions & Recovery

### 9.1 Error Taxonomy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ERROR CONDITION MATRIX                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  CODE     │ CONDITION                │ IMPACT         │ RECOVERY            │
│  ─────────┼──────────────────────────┼────────────────┼──────────────────── │
│  ERR-001  │ TS_AUTHKEY invalid       │ Can't join mesh│ Regenerate key      │
│  ERR-002  │ Coordination server down │ No new peers   │ Wait or use cache   │
│  ERR-003  │ All DERP servers failed  │ Relay blocked  │ Check firewall/DNS  │
│  ERR-004  │ State file corrupted     │ Identity lost  │ Delete & re-auth    │
│  ERR-005  │ /dev/net/tun unavailable │ Kernel mode N/A│ Use userspace mode  │
│  ERR-006  │ Port 41641 blocked       │ Direct P2P N/A │ DERP will be used   │
│  ERR-007  │ MagicDNS not resolving   │ Names broken   │ Check 100.100.100.1 │
│  ERR-008  │ ACL blocking traffic     │ Comm blocked   │ Update Tailscale ACL│
│  ERR-009  │ Key quota exceeded       │ Auth fails     │ Delete old devices  │
│  ERR-010  │ Socket timeout on start  │ Slow startup   │ Increase timeout    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 9.2 Diagnostic Commands

```bash
# Check tailscaled daemon status
podman exec <container> tailscale status --json

# Check direct vs relay connectivity
podman exec <container> tailscale netcheck

# Check peer connection quality
podman exec <container> tailscale ping --tsmp <peer-hostname>

# Debug DNS resolution
podman exec <container> dig @100.100.100.100 <hostname>.tailnet.ts.net

# Check firewall/NAT issues
podman exec <container> tailscale debug portmap

# View daemon logs
podman exec <container> journalctl -u tailscaled -n 100
# Or if no journald:
podman logs <container> 2>&1 | grep -i tailscale
```

### 9.3 Recovery Procedures

#### ERR-001: Invalid Auth Key

```bash
# 1. Generate new key in admin console
# 2. Update environment
export TS_AUTHKEY=tskey-auth-new-xxxxx

# 3. Force re-authentication
podman exec <container> tailscale logout
podman exec <container> tailscale up --authkey=$TS_AUTHKEY
```

#### ERR-004: Corrupted State

```bash
# 1. Stop container
podman-compose stop app

# 2. Clear state
podman volume rm tailscale_app_state
podman volume create tailscale_app_state

# 3. Restart with fresh auth
podman-compose up -d app
```

#### ERR-007: MagicDNS Not Resolving

```bash
# 1. Verify MagicDNS enabled in admin console
# 2. Check nameserver inside container
podman exec <container> cat /etc/resolv.conf
# Should include: nameserver 100.100.100.100

# 3. Force DNS update
podman exec <container> tailscale set --accept-dns=true
```

### 9.4 STAMP Failure Mode Analysis

| Failure Mode | STAMP ID | Hazard | Mitigation |
|--------------|----------|--------|------------|
| Mesh unavailable | FM-01 | Cluster partition | Bridge fallback |
| State loss | FM-02 | Identity churn | Volume persistence |
| Auth key leak | FM-03 | Unauthorized access | Key rotation + tags |
| DERP overload | FM-04 | Latency spike | Direct path preference |
| Coord server down | FM-05 | No new connections | Cached policy |

---

## 10. Performance Considerations

### 10.1 Latency Comparison

| Path Type | Latency | Throughput | Use Case |
|-----------|---------|------------|----------|
| Bridge (local) | <1ms | 10+ Gbps | DB queries, bulk data |
| Direct (P2P) | 5-50ms | 100+ Mbps | Cross-host sync |
| DERP (relay) | 50-200ms | 10-50 Mbps | Fallback only |

### 10.2 Startup Time Impact

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONTAINER STARTUP TIME BREAKDOWN                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Phase                    │ Without TS │ With TS (Cached) │ With TS (Fresh) │
│  ─────────────────────────┼────────────┼──────────────────┼──────────────── │
│  Container creation       │    0.5s    │      0.5s        │      0.5s       │
│  Tailscale daemon start   │     -      │      1.0s        │      1.0s       │
│  Socket ready wait        │     -      │      0.5s        │      0.5s       │
│  Authentication           │     -      │       -          │      2-3s       │
│  Key exchange             │     -      │      0.5s        │      0.5s       │
│  Application start        │    2.0s    │      2.0s        │      2.0s       │
│  ─────────────────────────┼────────────┼──────────────────┼──────────────── │
│  TOTAL                    │   ~2.5s    │     ~4.5s        │     ~6.5s       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 10.3 Optimization Strategies

1. **State Persistence**: Mount `/var/lib/tailscale` volume → Skip re-auth
2. **Pre-authorized Keys**: Use pre-approved keys → Skip interactive auth
3. **Userspace Mode**: Avoid /dev/net/tun requirement → Faster start
4. **Parallel Start**: Start Tailscale in background → Don't block app
5. **Health Check Delay**: Increase `start_period` in health checks

### 10.4 Resource Usage

| Component | CPU (Idle) | CPU (Active) | Memory | Disk |
|-----------|------------|--------------|--------|------|
| tailscaled | 0.1% | 1-5% | 20-50 MB | 1-5 MB |
| WireGuard kernel | <0.1% | 1-3% | 1 MB | 0 |
| Userspace mode | 0.5% | 5-10% | 50-100 MB | 0 |

---

## 11. Security Model

### 11.1 ACL Configuration

```hcl
// Tailscale ACL policy (in admin console)
{
  "acls": [
    // App containers can access database
    {
      "action": "accept",
      "src": ["tag:app"],
      "dst": ["tag:database:5432"]
    },

    // Monitoring can access all metrics endpoints
    {
      "action": "accept",
      "src": ["tag:monitoring"],
      "dst": ["tag:app:9090", "tag:database:9090"]
    },

    // Developers can access everything
    {
      "action": "accept",
      "src": ["group:developers"],
      "dst": ["*:*"]
    },

    // Deny all other traffic
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*"]
    }
  ],

  "tagOwners": {
    "tag:app": ["group:admins"],
    "tag:database": ["group:admins"],
    "tag:monitoring": ["group:admins"],
    "tag:flame": ["group:admins"]
  }
}
```

### 11.2 Key Security Best Practices

1. **Separate Keys**: Each environment/role gets unique key
2. **Ephemeral for CI**: Use auto-expiring keys for builds
3. **Tags**: Use tags for ACL-based access control
4. **Rotation**: Rotate keys monthly or on suspected compromise
5. **Least Privilege**: Grant minimum required access
6. **Audit**: Monitor key usage in admin console

### 11.3 Network Isolation

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SECURITY ZONES                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      TRUSTED ZONE (Bridge Only)                      │   │
│  │  • Redis (no external exposure needed)                               │   │
│  │  • Internal caches                                                   │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      SEMI-TRUSTED ZONE (Dual Network)                │   │
│  │  • App containers (bridge for data, mesh for cluster)               │   │
│  │  • Database (bridge for queries, mesh for remote DBA)               │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      EXPOSED ZONE (Mesh Required)                    │   │
│  │  • Nginx (mesh for secure external access)                          │   │
│  │  • Grafana (mesh for remote monitoring)                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 12. Monitoring & Observability

### 12.1 Prometheus Metrics

```yaml
# Tailscale metrics to monitor
- tailscale_health_status{container="app"} # 1 = healthy, 0 = unhealthy
- tailscale_peer_count{container="app"} # Number of connected peers
- tailscale_derp_latency_ms{container="app",region="nyc"} # Relay latency
- tailscale_direct_connection{container="app",peer="db"} # 1 = direct, 0 = relay
```

### 12.2 Health Check Integration

```yaml
# docker-compose health check
healthcheck:
  test: |
    if [ "${TS_ENABLED:-0}" = "1" ]; then
      tailscale status --self=true --json | jq -e '.Self.Online == true'
    else
      exit 0
    fi
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s  # Allow time for Tailscale startup
```

### 12.3 Log Patterns

```
# Successful startup
[Tailscale-Wrapper] Starting Tailscale daemon...
[Tailscale-Wrapper] ✅ /dev/net/tun exists. Using kernel networking.
[Tailscale-Wrapper] Waiting for tailscaled socket...
[Tailscale-Wrapper] Authenticating with Tailscale...
[Tailscale-Wrapper] ✅ Tailscale is UP. IP: 100.64.1.15
[Tailscale-Wrapper] 🚀 Executing original entrypoint: /app/bin/server

# Warning patterns
[Tailscale-Wrapper] ⚠️ /dev/net/tun not found. Using userspace networking.
[Tailscale-Wrapper] ⚠️ TS_AUTHKEY not provided. Skipping 'tailscale up'.

# Error patterns
[Tailscale-Wrapper] ❌ Timed out waiting for tailscaled socket.
[Tailscale-Wrapper] ❌ Failed to authenticate: invalid auth key
```

### 12.4 Alerting Rules

```yaml
# Prometheus alerting rules
groups:
  - name: tailscale
    rules:
      - alert: TailscaleDown
        expr: tailscale_health_status == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Tailscale unhealthy on {{ $labels.container }}"

      - alert: TailscaleRelayOnly
        expr: tailscale_direct_connection == 0
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "{{ $labels.container }} using DERP relay to {{ $labels.peer }}"

      - alert: TailscalePeerLost
        expr: delta(tailscale_peer_count[5m]) < -1
        labels:
          severity: warning
        annotations:
          summary: "Peer count dropped on {{ $labels.container }}"
```

---

## 13. References

### 13.1 External Documentation (Tailscale)

| Document | URL | Key Takeaways |
|----------|-----|---------------|
| Control & Data Planes | https://tailscale.com/kb/1508/control-data-planes | Control (HTTPS) vs Data (WireGuard) separation |
| Userspace Networking | https://tailscale.com/kb/1112/userspace-networking | `--tun=userspace-networking` for containers |
| Docker Deployment | https://tailscale.com/kb/1282/docker | Sidecar pattern, network_mode: service |
| Kubernetes Deployment | https://tailscale.com/kb/1185/kubernetes | Operator vs sidecar, headless services |
| Auth Keys | https://tailscale.com/kb/1085/auth-keys | One-time, reusable, ephemeral, pre-auth |
| Ephemeral Nodes | https://tailscale.com/kb/1111/ephemeral-nodes | Auto-cleanup 30min-48hr |
| DERP Servers | https://tailscale.com/kb/1232/derp-servers | Relay architecture, 20+ regions |
| High Availability | https://tailscale.com/kb/1115/high-availability | ~15s failover, subnet routers |
| Connection Types | https://tailscale.com/kb/1257/connection-types | Direct vs relay via DERP |
| Firewalls | https://tailscale.com/kb/1181/firewalls | Port 41641, STUN/TURN |
| DNS/MagicDNS | https://tailscale.com/kb/1054/dns | 100.100.100.100 resolver, split DNS |
| Troubleshooting | https://tailscale.com/kb/1023/troubleshooting | `tailscale netcheck`, `tailscale debug` |
| Docker Deep Dive | https://tailscale.com/blog/docker-tailscale-guide | Complete container integration |

### 13.2 Local Project Files

| File | Purpose | Key Content |
|------|---------|-------------|
| `podman-compose.yml` | Container orchestration | TS_AUTHKEY, volumes, networks |
| `scripts/containers/tailscale-entrypoint.sh` | Bash entrypoint | Daemon start, auth, handoff |
| `containers/lib/tailscale.nix` | Nix wrapper library | `wrap` function for Nix containers |
| `containers/indrajaal-timescaledb-demo.nix` | DB container | Tailscale integration via wrapper |
| `containers/sopv51-elixir-app.nix` | App container | Base image with Tailscale |
| `docs/architecture/tailscale-dns-integration-guide.md` | DNS/Cluster guide | FQDN mapping, STAMP compliance |
| `docs/architecture/NIX_MESH_WRAPPER_DESIGN.md` | Nix wrapper design | Functional wrapper pattern |
| `docs/architecture/FULL_MESH_GAP_ANALYSIS.md` | Gap analysis | Current state, roadmap |
| `docs/journal/20251219-1100-nix-mesh-expansion.md` | Journal entry | 5-level implementation plan |
| `tailscale.env` | Environment config | Keys, hostnames, toggles |

### 13.3 STAMP Safety Constraint Mapping

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-CLU-001 | Identity-based networking | Tailscale MagicDNS FQDN |
| SC-CLU-002 | Minimum 3 nodes for HA | Cluster validation |
| SC-CLU-003 | K8s DNS in production | libcluster Kubernetes.DNS |
| SC-CLU-004 | EPMD binds to Tailscale IP | ERL_EPMD_ADDRESS |
| SC-CLU-005 | Split-brain prevention | Consistent naming |
| SC-FLAME-001 | FLAME backends configurable | runtime.exs |
| SC-FLAME-004 | Graceful drain | tailscale logout |
| SC-FLAME-005 | Distributed tracing | Tailscale DNS names |

### 13.4 Error Pattern Database

| Pattern ID | Regex | Action |
|------------|-------|--------|
| EP-TS-001 | `invalid auth key` | Regenerate key |
| EP-TS-002 | `timed out waiting.*socket` | Check tailscaled |
| EP-TS-003 | `connection refused.*4369` | Check EPMD binding |
| EP-TS-004 | `DERP.*unreachable` | Check firewall |
| EP-TS-005 | `MagicDNS.*not resolving` | Enable in admin |

---

## Appendix A: Quick Reference Commands

```bash
# Setup
./scripts/cluster/tailscale_setup.sh --setup
source tailscale.env

# Start with mesh
TS_ENABLED_APP=1 podman-compose up -d app

# Start without mesh
TS_ENABLED_APP=0 podman-compose up -d app

# Check status
podman exec app tailscale status

# Test connectivity
podman exec app tailscale ping <peer>

# Force re-auth
podman exec app tailscale logout && podman exec app tailscale up --authkey=$TS_AUTHKEY

# Debug
podman exec app tailscale netcheck
podman exec app tailscale debug portmap
```

## Appendix B: Environment Variable Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `TS_ENABLED` | No | `0` | Toggle Tailscale ON/OFF |
| `TS_AUTHKEY` | Conditional | - | Authentication key |
| `TS_HOSTNAME` | No | `$(hostname)` | Tailscale hostname |
| `TS_STATE_DIR` | No | `/var/lib/tailscale` | State directory |
| `TS_SOCKET` | No | `/var/run/tailscale/tailscaled.sock` | Daemon socket |
| `TS_ROUTES` | No | - | Subnet routes to advertise |
| `TAILSCALE_DNS_SUFFIX` | Recommended | `tailnet.ts.net` | DNS suffix |

---

**Document Version**: 2.0.0
**Last Updated**: 2025-12-19
**Author**: Claude Code (Opus 4.5)
**Review Status**: COMPREHENSIVE SPECIFICATION COMPLETE
