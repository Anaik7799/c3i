# Tailscale DNS Integration Architecture & Implementation Guide

**Version**: 1.1.0
**Date**: 2025-12-26
**STAMP Compliance**: SC-CLU-001 to SC-CLU-005, SC-FLAME-001 to SC-FLAME-006
**Status**: PRODUCTION READY (Free Tier Compatible)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Detailed Design](#3-detailed-design)
4. [Implementation Guide](#4-implementation-guide)
5. [User Guide](#5-user-guide)
6. [Operations & Troubleshooting](#6-operations--troubleshooting)

---

## 1. Executive Summary

### 1.1 Purpose

This document describes the Tailscale DNS integration for Indrajaal's distributed cluster architecture. The integration provides:

- **Identity-based networking** via Tailscale MagicDNS
- **FQDN-based container naming** for all cluster nodes
- **Centralized configuration** for easy deployment
- **STAMP compliance** for safety-critical operations

### 1.2 Key Benefits

| Benefit | Description |
|---------|-------------|
| Security | Zero-trust networking with identity-based access |
| Reliability | Consistent DNS naming prevents split-brain scenarios |
| Simplicity | Single configuration source for all nodes |
| Scalability | Easy addition of new cluster nodes |
| Observability | Clear node identification in logs and metrics |

### 1.3 STAMP Compliance Matrix

| Constraint | Description | Implementation |
|------------|-------------|----------------|
| SC-CLU-001 | Identity-based networking | Tailscale MagicDNS FQDN |
| SC-CLU-002 | Minimum 3 nodes for HA | Cluster node validation |
| SC-CLU-003 | Kubernetes DNS in production | K8s headless service support |
| SC-CLU-004 | EPMD binds to Tailscale IP | `ERL_EPMD_ADDRESS` enforcement |
| SC-CLU-005 | Split-brain prevention | Consistent Tailscale naming |

### 1.4 Tailscale Plan Tier Compatibility

**Updated: 2025-12-26** - Based on current Tailscale pricing and feature availability.

#### Free/Personal Plan Capabilities

The Indrajaal system is designed to work with Tailscale's **Free Personal Plan**, which provides:

| Feature | Free/Personal | Starter | Premium+ |
|---------|---------------|---------|----------|
| **Devices** | 100 | 10/user | Unlimited |
| **Users** | 3 | 10+ | Unlimited |
| **ACLs (Basic)** | Yes | Yes | Yes |
| **Autogroups** | `admin`, `member` only | `admin`, `member` only | Full |
| **Custom Groups** | No | No | Yes |
| **Name Users in ACL Rules** | No | No | Yes |
| **MagicDNS** | Yes | Yes | Yes |
| **HTTPS Certs** | Yes | Yes | Yes |
| **Exit Nodes** | Yes | Yes | Yes |

#### Free Tier Implementation Strategy

Since the free tier limits ACLs to **autogroups only**, our implementation uses:

```json
{
  "acls": [
    // Admin group has full access to all cluster nodes
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:*"]
    },
    // Member group can access application ports only
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["*:4000", "*:4001", "*:8080"]
    },
    // Cluster nodes can communicate on Erlang ports
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["*:4369", "*:9100-9199"]
    }
  ],
  "tagOwners": {
    "tag:indrajaal": ["autogroup:admin"]
  }
}
```

#### Code Adaptations for Free Tier

The following modules have been adapted for free tier compatibility:

1. **`lib/indrajaal/cluster/tailscale_dns.ex`**
   - Uses device tags instead of custom groups
   - Validates connectivity via MagicDNS (available on all tiers)
   - Falls back to local naming when Tailscale unavailable (SC-CLU-004)

2. **`lib/indrajaal/cluster/strategies/standalone.ex`**
   - Hybrid mode: Tailscale-first with local fallback
   - No dependency on custom ACL groups

3. **`lib/indrajaal/cluster/process_capability.ex`**
   - Capability tokens for secure RPC (independent of Tailscale ACLs)
   - FlameBackend uses node() resolution with Tailscale names

#### Upgrade Path to Premium

If upgrading to Premium tier in future, the following enhancements become available:

| Enhancement | Implementation |
|-------------|----------------|
| Custom Groups | Define `group:indrajaal-workers`, `group:indrajaal-managers` |
| User-based ACLs | Restrict access by individual developer identity |
| SSH Action Logs | Audit trail for SSH access to nodes |
| Funnel | Public HTTPS endpoints without reverse proxy |

#### Migration Notes

To migrate from Free to Premium:

1. Update `tailscale.env` with new ACL configuration
2. Replace `autogroup:admin` with custom groups
3. Add individual user identities to ACL rules
4. Run `tailscale up --force-reauth` on all nodes

---

## 2. Architecture Overview

### 2.1 High-Level Architecture (Level 1)

**Host-Aligned Naming Convention**: `{service}-{hostname}.{tailnet}`

All containers inherit the host machine's Tailscale identity, ensuring proper MagicDNS resolution and identity-based access control.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TAILSCALE MESH NETWORK                          │
│                     (Identity-Based Zero-Trust)                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Host: devbox                  Host: server1                Host: server2│
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │ indrajaal-devbox│    │indrajaal-server1│    │indrajaal-server2│     │
│  │  .tailnet.ts.net│    │  .tailnet.ts.net│    │  .tailnet.ts.net│     │
│  │                 │◄──►│                 │◄──►│                 │     │
│  │  ┌───────────┐  │    │  ┌───────────┐  │    │  ┌───────────┐  │     │
│  │  │  Erlang   │  │    │  │  Erlang   │  │    │  │  Erlang   │  │     │
│  │  │  Node     │  │    │  │  Node     │  │    │  │  Node     │  │     │
│  │  └───────────┘  │    │  └───────────┘  │    │  └───────────┘  │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│           │                      │                      │               │
│           └──────────────────────┼──────────────────────┘               │
│                                  │                                       │
│                          ┌───────┴───────┐                              │
│                          │   Sentinel    │                              │
│                          │   (Quorum)    │                              │
│                          └───────────────┘                              │
│                                                                          │
├─────────────────────────────────────────────────────────────────────────┤
│  Supporting Services (on host "devbox"):                                 │
│  • timescaledb-devbox.tailnet.ts.net    (Database)                      │
│  • redis-devbox.tailnet.ts.net          (Cache)                         │
│  • prometheus-devbox.tailnet.ts.net     (Metrics)                       │
│  • grafana-devbox.tailnet.ts.net        (Dashboards)                    │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Architecture (Level 2)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      INTELITOR CLUSTER COMPONENTS                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     CONFIGURATION LAYER                          │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │    │
│  │  │tailscale.env│  │runtime.exs  │  │TailscaleDNS Module      │  │    │
│  │  │             │  │             │  │                         │  │    │
│  │  │• DNS_SUFFIX │  │• Topology   │  │• get_node_name/1        │  │    │
│  │  │• TS_IP      │  │• Libcluster │  │• get_tailnet_suffix/0   │  │    │
│  │  │• FQDN vars  │  │• FLAME      │  │• list_cluster_nodes/0   │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                       CLUSTER LAYER                              │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │    │
│  │  │  Sentinel   │  │  NodeManager│  │  FLAME Supervisor       │  │    │
│  │  │             │  │             │  │                         │  │    │
│  │  │• Quorum     │  │• Discovery  │  │• Pool Management        │  │    │
│  │  │• Apoptosis  │  │• Membership │  │• Runner Naming          │  │    │
│  │  │• DNS Valid  │  │• Health     │  │• Telemetry              │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │                     CONTAINER LAYER                              │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │    │
│  │  │podman-      │  │podman-      │  │Tailscale Setup Script   │  │    │
│  │  │compose.yml  │  │compose-     │  │                         │  │    │
│  │  │             │  │cluster.yml  │  │• Installation           │  │    │
│  │  │• FQDN hosts │  │• 3-node HA  │  │• Configuration          │  │    │
│  │  │• Env vars   │  │• Quorum     │  │• Verification           │  │    │
│  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 Data Flow Architecture (Level 3)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         DNS RESOLUTION FLOW                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Environment Variable Loading (Host-Aligned)                          │
│     ┌─────────────────────────────────────────────────────────────┐     │
│     │  tailscale.env                                               │     │
│     │  ├── TAILSCALE_DNS_SUFFIX=tailnet-abc123.ts.net             │     │
│     │  ├── TS_IP_ADDRESS=100.x.x.x                                │     │
│     │  ├── TS_HOSTNAME=devbox  (from host's Tailscale identity)   │     │
│     │  └── TS_APP_FQDN=indrajaal-devbox.tailnet-abc123.ts.net     │     │
│     └─────────────────────────────────────────────────────────────┘     │
│                                    │                                     │
│                                    ▼                                     │
│  2. Container Hostname Assignment                                        │
│     ┌─────────────────────────────────────────────────────────────┐     │
│     │  podman-compose.yml                                          │     │
│     │  hostname: ${TS_APP_1_FQDN:-indrajaal-app-1.tailnet.ts.net} │     │
│     └─────────────────────────────────────────────────────────────┘     │
│                                    │                                     │
│                                    ▼                                     │
│  3. Erlang Node Naming                                                   │
│     ┌─────────────────────────────────────────────────────────────┐     │
│     │  ERL_AFLAGS=-name indrajaal@indrajaal-app-1.tailnet.ts.net  │     │
│     │  ERL_EPMD_ADDRESS=100.x.x.x (Tailscale IP only)             │     │
│     └─────────────────────────────────────────────────────────────┘     │
│                                    │                                     │
│                                    ▼                                     │
│  4. Cluster Discovery (libcluster)                                       │
│     ┌─────────────────────────────────────────────────────────────┐     │
│     │  tailscale_mesh topology:                                    │     │
│     │  hosts: [                                                    │     │
│     │    :"indrajaal@indrajaal-app-1.tailnet.ts.net",             │     │
│     │    :"indrajaal@indrajaal-app-2.tailnet.ts.net",             │     │
│     │    :"indrajaal@indrajaal-app-3.tailnet.ts.net"              │     │
│     │  ]                                                           │     │
│     └─────────────────────────────────────────────────────────────┘     │
│                                    │                                     │
│                                    ▼                                     │
│  5. Sentinel Quorum Validation                                           │
│     ┌─────────────────────────────────────────────────────────────┐     │
│     │  is_valid_quorum_node?/1 verifies:                          │     │
│     │  • Not an IP address                                         │     │
│     │  • Contains .ts.net or configured suffix                     │     │
│     │  • Has at least one dot (DNS format)                         │     │
│     └─────────────────────────────────────────────────────────────┘     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.4 Module Interaction (Level 4)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      MODULE DEPENDENCY GRAPH                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│                    ┌────────────────────────┐                           │
│                    │   Application.start/2   │                           │
│                    └───────────┬────────────┘                           │
│                                │                                         │
│                    ┌───────────▼────────────┐                           │
│                    │   Supervisor Tree       │                           │
│                    └───────────┬────────────┘                           │
│                                │                                         │
│         ┌──────────────────────┼──────────────────────┐                 │
│         │                      │                      │                 │
│         ▼                      ▼                      ▼                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐          │
│  │   Sentinel   │    │  NodeManager │    │ FLAME.Supervisor │          │
│  │              │    │              │    │                  │          │
│  │  • start_link│    │  • start_link│    │  • start_link    │          │
│  │  • init      │    │  • init      │    │  • init          │          │
│  └──────┬───────┘    └──────┬───────┘    └────────┬─────────┘          │
│         │                   │                     │                     │
│         └───────────────────┼─────────────────────┘                     │
│                             │                                            │
│                    ┌────────▼────────┐                                  │
│                    │  TailscaleDNS   │                                  │
│                    │                 │                                  │
│                    │ • get_tailnet_suffix/0                             │
│                    │ • get_node_name/1                                  │
│                    │ • list_cluster_nodes/0                             │
│                    │ • get_flame_runner_name/2                          │
│                    │ • is_valid_quorum_node?/1                          │
│                    │ • parse_node_name/1                                │
│                    │ • node_to_tailscale_name/1                         │
│                    │ • validate_tailscale_connectivity/0                │
│                    │ • get_epmd_binding/0                               │
│                    └─────────────────┘                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.5 Function Reference (Level 5)

```elixir
# =============================================================================
# TailscaleDNS Module API Reference
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration Functions
# -----------------------------------------------------------------------------

@spec get_tailnet_suffix() :: String.t()
# Returns the Tailscale DNS suffix from:
# 1. TAILSCALE_DNS_SUFFIX environment variable
# 2. Application config :indrajaal, :tailscale_dns_suffix
# 3. Default: "tailnet.ts.net"

@spec get_epmd_binding() :: {:ok, map()} | {:error, atom()} | map()
# Returns EPMD binding information for Tailscale interface.
# Used to verify SC-CLU-004 compliance.

# -----------------------------------------------------------------------------
# Node Name Generation Functions
# -----------------------------------------------------------------------------

@spec get_node_name(String.t(), keyword()) :: atom()
# Generates a valid Erlang node name using Tailscale DNS.
# Example: get_node_name("app-1") => :"indrajaal@app-1.tailnet.ts.net"

@spec get_full_dns_name(String.t()) :: String.t()
# Returns the full DNS name for a base hostname.
# Example: get_full_dns_name("app-1") => "app-1.tailnet.ts.net"

@spec get_flame_runner_name(String.t(), String.t()) :: atom()
# Generates a FLAME runner node name with Tailscale DNS.
# Example: get_flame_runner_name("intelligence", "abc123")
#          => :"indrajaal@flame-intelligence-abc123.tailnet.ts.net"

# -----------------------------------------------------------------------------
# Node Name Parsing Functions
# -----------------------------------------------------------------------------

@spec parse_node_name(atom() | String.t()) :: {:ok, map()} | {:error, atom()}
# Parses an Erlang node name into its components.
# Returns: %{app_name: String.t(), host: String.t(), base_name: String.t()}

@spec node_to_tailscale_name(atom() | String.t()) :: atom()
# Converts a short node name to Tailscale DNS format.
# Example: :"indrajaal@app-1" => :"indrajaal@app-1.tailnet.ts.net"

# -----------------------------------------------------------------------------
# Cluster Management Functions
# -----------------------------------------------------------------------------

@spec list_cluster_nodes() :: [atom()]
# Returns the list of configured cluster nodes with Tailscale DNS names.
# Enforces SC-CLU-002 (minimum 3 nodes).

@spec get_quorum_nodes() :: [atom()]
# Returns the list of nodes that participate in quorum decisions.

@spec is_valid_quorum_node?(atom()) :: boolean()
# Validates that a node name is suitable for quorum participation.
# Valid nodes must:
# - Use DNS format (not IP)
# - Include Tailscale suffix (.ts.net or configured)

# -----------------------------------------------------------------------------
# Connectivity Validation Functions
# -----------------------------------------------------------------------------

@spec validate_tailscale_connectivity() :: {:ok, map()} | {:error, atom()}
# Validates Tailscale connectivity and returns status information.
# Returns: %{dns_name: String.t(), ip_address: String.t(), connected: boolean()}
```

---

## 3. Detailed Design

### 3.1 Configuration Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CONFIGURATION PRECEDENCE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Priority 1 (Highest): Environment Variables                            │
│  ├── TAILSCALE_DNS_SUFFIX                                               │
│  ├── TS_IP_ADDRESS                                                      │
│  ├── TS_HOSTNAME                                                        │
│  └── TS_*_FQDN (container-specific)                                     │
│                                                                          │
│  Priority 2: Application Config (config/runtime.exs)                    │
│  ├── config :indrajaal, :tailscale_dns_suffix                          │
│  ├── config :indrajaal, :cluster_nodes                                  │
│  └── config :indrajaal, :cluster (production settings)                  │
│                                                                          │
│  Priority 3 (Lowest): Module Defaults                                   │
│  ├── @default_suffix "tailnet.ts.net"                                   │
│  ├── @default_app_name "indrajaal"                                      │
│  ├── @min_cluster_nodes 3                                               │
│  └── @cluster_node_bases ["indrajaal-app-1", ...]                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Container FQDN Mapping

| Container | Short Name | FQDN Template | Environment Variable |
|-----------|------------|---------------|---------------------|
| TimescaleDB | timescaledb-primary | timescaledb.${SUFFIX} | TS_TIMESCALEDB_FQDN |
| Redis | redis-cache | redis.${SUFFIX} | TS_REDIS_FQDN |
| App | indrajaal-app | indrajaal-app.${SUFFIX} | TS_APP_FQDN |
| App Node 1 | indrajaal-app-1 | indrajaal-app-1.${SUFFIX} | TS_APP_1_FQDN |
| App Node 2 | indrajaal-app-2 | indrajaal-app-2.${SUFFIX} | TS_APP_2_FQDN |
| App Node 3 | indrajaal-app-3 | indrajaal-app-3.${SUFFIX} | TS_APP_3_FQDN |
| Prometheus | prometheus-metrics | prometheus.${SUFFIX} | TS_PROMETHEUS_FQDN |
| Grafana | grafana-dashboards | grafana.${SUFFIX} | TS_GRAFANA_FQDN |
| Nginx | nginx-proxy | nginx.${SUFFIX} | TS_NGINX_FQDN |
| OTel Collector | otel-collector | otel-collector.${SUFFIX} | TS_OTEL_FQDN |
| ClickHouse | clickhouse-db | clickhouse.${SUFFIX} | TS_CLICKHOUSE_FQDN |
| SigNoz | signoz-query-service | signoz.${SUFFIX} | TS_SIGNOZ_FQDN |

### 3.3 Erlang Node Naming Convention

```
Format: {app_name}@{hostname}.{tailnet_suffix}

Examples:
  indrajaal@indrajaal-app-1.tailnet-abc123.ts.net
  indrajaal@flame-intelligence-runner123.tailnet-abc123.ts.net
  indrajaal@flame-video-runner456.tailnet-abc123.ts.net

Components:
  - app_name: Always "indrajaal" (configurable)
  - hostname: Container/node base name
  - tailnet_suffix: Tailscale MagicDNS suffix
```

### 3.4 Quorum Validation Logic

```elixir
def is_valid_quorum_node?(node_name) do
  node_string = Atom.to_string(node_name)

  case String.split(node_string, "@") do
    [_app_name, host] ->
      not_ip = not is_ip_address?(host)
      suffix = get_tailnet_suffix()
      has_suffix = String.contains?(host, ".ts.net") or String.contains?(host, suffix)
      has_dot = String.contains?(host, ".")

      not_ip and has_suffix and has_dot

    _ ->
      false
  end
end
```

---

## 4. Implementation Guide

### 4.1 Prerequisites

1. **Tailscale Installation**
   - Tailscale client installed on all nodes
   - Authenticated to same tailnet
   - MagicDNS enabled in Tailscale admin console

2. **Network Configuration**
   - Tailscale ACLs configured for cluster communication
   - Ports 4369 (EPMD) and 9100-9155 (Erlang) allowed

3. **Environment Setup**
   - Podman 5.4.1+ with rootless mode
   - NixOS-based container images from localhost registry

### 4.2 Step-by-Step Setup

#### Step 1: Install Tailscale on All Nodes

```bash
# On each cluster node:
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable --now tailscaled
sudo tailscale up
```

#### Step 2: Configure Environment Variables

```bash
# Auto-detect from Tailscale
cd /path/to/indrajaal-v5.2
./scripts/cluster/tailscale_setup.sh --export

# Or manually in tailscale.env:
export TAILSCALE_DNS_SUFFIX=$(tailscale status --json | jq -r '.MagicDNSSuffix')
export TS_IP_ADDRESS=$(tailscale ip -4)
export TS_HOSTNAME=$(tailscale status --json | jq -r '.Self.HostName')
```

#### Step 3: Start Development Environment

```bash
# Single-node development
source tailscale.env
podman-compose --env-file tailscale.env -f podman-compose.yml up -d
```

#### Step 4: Start HA Cluster

```bash
# On each node (app-1, app-2, app-3):
source tailscale.env
podman-compose --env-file tailscale.env -f podman-compose-cluster.yml up -d
```

#### Step 5: Verify Cluster Formation

```bash
# Check cluster status
./scripts/cluster/tailscale_setup.sh --verify

# From Elixir:
iex> Node.list()
[:"indrajaal@indrajaal-app-2.tailnet.ts.net",
 :"indrajaal@indrajaal-app-3.tailnet.ts.net"]

iex> Indrajaal.Cluster.Sentinel.get_status()
%{
  status: :healthy,
  active_count: 3,
  total_expected: 3,
  quorum_threshold: 2,
  has_quorum: true,
  tailnet_suffix: "tailnet-abc123.ts.net"
}
```

---

## 5. User Guide

### 5.1 Quick Start

```bash
# 1. Clone and setup
cd indrajaal-v5.2
./scripts/cluster/tailscale_setup.sh

# 2. Source environment
source tailscale.env

# 3. Start services
podman-compose --env-file tailscale.env up -d

# 4. Verify
./scripts/cluster/tailscale_setup.sh --check
```

### 5.2 Common Operations

#### Check Tailscale Status

```bash
./scripts/cluster/tailscale_setup.sh --check
```

Output:
```
═══════════════════════════════════════════════════════════════
                    TAILSCALE STATUS
═══════════════════════════════════════════════════════════════

[✓] Tailscale Connected

  Hostname:     indrajaal-app-1
  DNS Name:     indrajaal-app-1.tailnet-abc123.ts.net
  IP Address:   100.64.1.5
  Tailnet:      tailnet-abc123.ts.net

═══════════════════════════════════════════════════════════════
```

#### Verify Cluster Connectivity

```bash
./scripts/cluster/tailscale_setup.sh --verify
```

#### Generate DNS Names

```bash
./scripts/cluster/tailscale_setup.sh --dns
```

### 5.3 Troubleshooting

#### Problem: Tailscale Not Connected

```bash
# Check Tailscale status
tailscale status

# If not connected:
sudo tailscale up

# If authentication needed:
sudo tailscale up --authkey=<your-auth-key>
```

#### Problem: EPMD Binding Issues

```bash
# Verify EPMD is binding to correct IP
epmd -names

# Check environment variable
echo $ERL_EPMD_ADDRESS

# Should show Tailscale IP (100.x.x.x), not 0.0.0.0
```

#### Problem: Nodes Cannot Discover Each Other

```bash
# Test Tailscale connectivity
tailscale ping indrajaal-app-2.tailnet.ts.net

# Check firewall rules in Tailscale ACLs
# Ensure ports 4369 and 9100-9155 are allowed
```

#### Problem: Quorum Not Forming

```elixir
# Check node validation
iex> alias Indrajaal.Cluster.TailscaleDNS
iex> TailscaleDNS.is_valid_quorum_node?(Node.self())
true

# Check all nodes are using correct naming
iex> Node.list()
[:"indrajaal@indrajaal-app-2.tailnet.ts.net", ...]

# Verify Sentinel status
iex> Indrajaal.Cluster.Sentinel.get_status()
```

### 5.4 Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| TAILSCALE_DNS_SUFFIX | Yes | tailnet.ts.net | Tailnet MagicDNS suffix |
| TS_IP_ADDRESS | Yes | 127.0.0.1 | Tailscale IPv4 for EPMD |
| TS_HOSTNAME | Yes | localhost | Current host's Tailscale name |
| RELEASE_COOKIE | Yes | indrajaal_secure_cookie | Erlang distribution cookie |
| CLUSTER_SIZE | No | 3 | Expected cluster size |
| CLUSTER_NODES | No | app-1,app-2,app-3 | Comma-separated node names |

---

## 6. Operations & Troubleshooting

### 6.1 Monitoring

#### Prometheus Metrics

```yaml
# Key metrics to monitor
indrajaal_cluster_nodes_active
indrajaal_cluster_quorum_status
indrajaal_tailscale_connectivity
indrajaal_epmd_binding_status
```

#### Grafana Dashboard

Access at: `http://grafana.tailnet.ts.net:3000`

Panels:
- Cluster Node Status
- Quorum Health
- Tailscale Connectivity
- EPMD Binding Status

### 6.2 Log Analysis

```bash
# Sentinel logs
grep "Sentinel" /var/log/indrajaal/app.log

# Key patterns
"Sentinel: Quorum Restored"        # Healthy
"Sentinel: Node Joined"            # New node
"Sentinel: Node Lost"              # Node departure
"Sentinel: QUORUM LOST!"           # Critical - partition
"Sentinel: INITIATING APOPTOSIS"   # Emergency shutdown
```

### 6.3 Recovery Procedures

#### Single Node Failure

```bash
# 1. Restart the failed node
podman-compose --env-file tailscale.env up -d app-1

# 2. Verify it rejoins
./scripts/cluster/tailscale_setup.sh --verify
```

#### Quorum Loss

```bash
# 1. Identify available nodes
tailscale status

# 2. Restart all healthy nodes
for node in app-1 app-2 app-3; do
  ssh $node "podman-compose --env-file tailscale.env up -d"
done

# 3. Verify quorum restoration
./scripts/cluster/tailscale_setup.sh --verify
```

#### Complete Cluster Restart

```bash
# 1. Stop all nodes
for node in app-1 app-2 app-3; do
  ssh $node "podman-compose --env-file tailscale.env down"
done

# 2. Start primary node first
ssh app-1 "podman-compose --env-file tailscale.env up -d"
sleep 30

# 3. Start remaining nodes
for node in app-2 app-3; do
  ssh $node "podman-compose --env-file tailscale.env up -d"
  sleep 10
done

# 4. Verify cluster
./scripts/cluster/tailscale_setup.sh --verify
```

---

## Appendix A: File Reference

| File | Purpose |
|------|---------|
| tailscale.env | Centralized environment configuration |
| scripts/cluster/tailscale_setup.sh | Setup and verification script |
| lib/indrajaal/cluster/tailscale_dns.ex | Core Tailscale DNS module |
| lib/indrajaal/cluster/sentinel.ex | Cluster quorum management |
| lib/indrajaal/flame/telemetry.ex | FLAME telemetry with DNS names |
| podman-compose.yml | Development container configuration |
| podman-compose-cluster.yml | HA cluster configuration |
| config/runtime.exs | Runtime cluster configuration |
| config/prod.exs | Production Tailscale settings |

---

## Appendix B: STAMP Compliance Checklist

- [x] SC-CLU-001: Identity-based networking via Tailscale MagicDNS
- [x] SC-CLU-002: Minimum 3 nodes for HA (validated in list_cluster_nodes/0)
- [x] SC-CLU-003: Kubernetes DNS strategy support (in runtime.exs)
- [x] SC-CLU-004: EPMD binds to Tailscale IP only (ERL_EPMD_ADDRESS)
- [x] SC-CLU-005: Split-brain prevention with consistent naming (Sentinel)
- [x] SC-FLAME-001: FLAME backends configurable (runtime.exs)
- [x] SC-FLAME-004: Graceful drain with node name tracking
- [x] SC-FLAME-005: Distributed tracing with Tailscale DNS names

---

**Document Version**: 1.0.0
**Last Updated**: 2025-12-18
**Author**: Claude Code (Opus 4.5)
**Review Status**: COMPLETE
