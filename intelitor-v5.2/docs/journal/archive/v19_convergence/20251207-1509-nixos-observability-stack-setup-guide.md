# NixOS Observability Stack Setup Guide

**Date**: 2025-12-07 15:09 CET
**Author**: Claude Code (Opus 4.5)
**Status**: VERIFIED COMPLETE

## Overview

This guide documents the complete setup of the NixOS-based observability stack for Indrajaal. All containers use **real NixOS packages** built with `dockerTools.buildLayeredImage` - no Docker Hub images, no placeholders.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OBSERVABILITY STACK                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────────┐    ┌──────────────────┐          │
│  │   Phoenix    │───▶│  OTEL Collector  │───▶│     Tempo        │          │
│  │   App        │    │  (otelcol-contrib│    │  (Distributed    │          │
│  │  (Local)     │    │   0.124.0)       │    │   Tracing)       │          │
│  └──────────────┘    └────────┬─────────┘    └──────────────────┘          │
│         │                     │                       │                     │
│         │                     ▼                       │                     │
│         │            ┌──────────────────┐            │                     │
│         │            │   ClickHouse     │            │                     │
│         │            │  (25.5.2.24)     │◀───────────┘                     │
│         │            │  Trace Storage   │                                   │
│         │            └──────────────────┘                                   │
│         │                     │                                             │
│         ▼                     ▼                                             │
│  ┌──────────────┐    ┌──────────────────┐                                  │
│  │ TimescaleDB  │    │    Grafana       │                                  │
│  │ (PostgreSQL) │    │   (12.2.1)       │                                  │
│  │    5433      │    │  Visualization   │                                  │
│  └──────────────┘    └──────────────────┘                                  │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────┐                                                          │
│  │    Redis     │                                                          │
│  │    6379      │                                                          │
│  └──────────────┘                                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Container Summary

| Container | NixOS Package | Version | Ports | Purpose |
|-----------|---------------|---------|-------|---------|
| signoz-clickhouse | `pkgs.clickhouse` | 25.5.2.24 | 8123, 9000 | Trace/metrics storage |
| signoz-otel-collector | `pkgs.opentelemetry-collector-contrib` | 0.124.0 | 4317, 4318, 8888, 8889, 13133 | Telemetry ingestion |
| signoz-tempo | `pkgs.tempo` | 2.9.0 | 3200, 9095 | Distributed tracing |
| signoz-grafana | `pkgs.grafana` | 12.2.1 | 3001 | Visualization |
| indrajaal-timescaledb-demo | `pkgs.postgresql` + TimescaleDB | 17+ | 5433 | Application database |
| indrajaal-redis-demo | `pkgs.redis` | 7+ | 6379 | Cache/sessions |

## Prerequisites

- NixOS or Nix package manager installed
- Podman 5.4.1+ (rootless)
- No KVM required (uses `buildLayeredImage` instead of `buildImage` with `runAsRoot`)

## Directory Structure

```
containers/signoz/
├── clickhouse-nixos.nix      # ClickHouse container definition
├── otel-collector-nixos.nix  # OTEL Collector container definition
├── tempo-nixos.nix           # Tempo container definition
├── grafana-nixos.nix         # Grafana container definition
├── result                    # Symlink to built ClickHouse image
├── result-otel               # Symlink to built OTEL Collector image
├── result-tempo              # Symlink to built Tempo image
└── result-grafana            # Symlink to built Grafana image
```

## Step 1: Build All Container Images

```bash
cd /home/an/dev/indrajaal-demo/containers/signoz

# Build all images (each takes 1-5 minutes)
nix-build clickhouse-nixos.nix -o result
nix-build otel-collector-nixos.nix -o result-otel
nix-build tempo-nixos.nix -o result-tempo
nix-build grafana-nixos.nix -o result-grafana
```

## Step 2: Load Images into Podman

```bash
# Load all images into podman registry
podman load < result
podman load < result-otel
podman load < result-tempo
podman load < result-grafana

# Verify images are loaded
podman images | grep -E "signoz|localhost"
```

Expected output:
```
localhost/signoz-clickhouse        latest    ...    1.35 GB
localhost/signoz-otel-collector    latest    ...    426 MB
localhost/signoz-tempo             latest    ...    330 MB
localhost/signoz-grafana           latest    ...    751 MB
```

## Step 3: Create Podman Network

```bash
# Create isolated network for observability stack
podman network create signoz-net
```

## Step 4: Create Data Directories

```bash
# Create persistent data directories
mkdir -p /tmp/clickhouse-data /tmp/clickhouse-logs
mkdir -p /tmp/otel-data
mkdir -p /tmp/tempo-data
mkdir -p /tmp/grafana-data

# Set permissions
chmod 777 /tmp/clickhouse-data /tmp/clickhouse-logs
chmod 777 /tmp/otel-data
chmod 777 /tmp/tempo-data
chmod 777 /tmp/grafana-data
```

## Step 5: Start ClickHouse

```bash
podman run -d \
  --name signoz-clickhouse \
  --network signoz-net \
  --user 0:0 \
  -p 8123:8123 \
  -p 9000:9000 \
  -v /tmp/clickhouse-data:/var/lib/clickhouse:z \
  -v /tmp/clickhouse-logs:/var/log/clickhouse-server:z \
  localhost/signoz-clickhouse:latest

# Verify health
sleep 10
curl -s http://localhost:8123/ping
# Expected: Ok.
```

## Step 6: Start Tempo

```bash
podman run -d \
  --name signoz-tempo \
  --network signoz-net \
  -p 3200:3200 \
  -p 9095:9095 \
  -v /tmp/tempo-data:/var/lib/tempo:z \
  localhost/signoz-tempo:latest

# Verify health
sleep 5
curl -s http://localhost:3200/ready
# Expected: ready
```

## Step 7: Start OTEL Collector

```bash
podman run -d \
  --name signoz-otel-collector \
  --network signoz-net \
  -p 4317:4317 \
  -p 4318:4318 \
  -p 8888:8888 \
  -p 8889:8889 \
  -p 13133:13133 \
  -v /tmp/otel-data:/var/lib/otel:z \
  localhost/signoz-otel-collector:latest

# Verify health
sleep 5
curl -s http://localhost:13133/health
# Expected: {"status":"Server available",...}
```

## Step 8: Start Grafana

```bash
podman run -d \
  --name signoz-grafana \
  --network signoz-net \
  -p 3001:3000 \
  -v /tmp/grafana-data:/var/lib/grafana:z \
  localhost/signoz-grafana:latest

# Verify health
sleep 10
curl -s http://localhost:3001/api/health
# Expected: {"database":"ok","version":"12.2.1",...}
```

## Step 9: Verify Full Stack

```bash
# Check all containers are healthy
podman ps --format "table {{.Names}}\t{{.Status}}" | grep signoz

# Expected output:
# signoz-clickhouse        Up X minutes (healthy)
# signoz-tempo             Up X minutes (healthy)
# signoz-grafana           Up X minutes (healthy)
# signoz-otel-collector    Up X minutes (healthy)
```

## Step 10: Test Telemetry Pipeline

```bash
# Send test trace via OTLP HTTP
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "scopeSpans": [{
        "scope": {"name": "test"},
        "spans": [{
          "traceId": "5B8EFFF798038103D269B633813FC60C",
          "spanId": "EEE19B7EC3C1B174",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": 1733578500000000000,
          "endTimeUnixNano": 1733578501000000000
        }]
      }]
    }]
  }'

# Expected: {"partialSuccess":{}}
```

## Quick Start Script

Save this as `start-observability-stack.sh`:

```bash
#!/bin/bash
set -e

cd /home/an/dev/indrajaal-demo/containers/signoz

echo "=== Building NixOS Container Images ==="
nix-build clickhouse-nixos.nix -o result
nix-build otel-collector-nixos.nix -o result-otel
nix-build tempo-nixos.nix -o result-tempo
nix-build grafana-nixos.nix -o result-grafana

echo "=== Loading Images into Podman ==="
podman load < result
podman load < result-otel
podman load < result-tempo
podman load < result-grafana

echo "=== Creating Network ==="
podman network create signoz-net 2>/dev/null || true

echo "=== Creating Data Directories ==="
mkdir -p /tmp/clickhouse-data /tmp/clickhouse-logs /tmp/otel-data /tmp/tempo-data /tmp/grafana-data
chmod 777 /tmp/clickhouse-data /tmp/clickhouse-logs /tmp/otel-data /tmp/tempo-data /tmp/grafana-data

echo "=== Starting ClickHouse ==="
podman run -d --name signoz-clickhouse --network signoz-net --user 0:0 \
  -p 8123:8123 -p 9000:9000 \
  -v /tmp/clickhouse-data:/var/lib/clickhouse:z \
  -v /tmp/clickhouse-logs:/var/log/clickhouse-server:z \
  localhost/signoz-clickhouse:latest

echo "=== Starting Tempo ==="
podman run -d --name signoz-tempo --network signoz-net \
  -p 3200:3200 -p 9095:9095 \
  -v /tmp/tempo-data:/var/lib/tempo:z \
  localhost/signoz-tempo:latest

echo "=== Starting OTEL Collector ==="
podman run -d --name signoz-otel-collector --network signoz-net \
  -p 4317:4317 -p 4318:4318 -p 8888:8888 -p 8889:8889 -p 13133:13133 \
  -v /tmp/otel-data:/var/lib/otel:z \
  localhost/signoz-otel-collector:latest

echo "=== Starting Grafana ==="
podman run -d --name signoz-grafana --network signoz-net \
  -p 3001:3000 \
  -v /tmp/grafana-data:/var/lib/grafana:z \
  localhost/signoz-grafana:latest

echo "=== Waiting for Health Checks ==="
sleep 15

echo "=== Verifying Stack ==="
echo "ClickHouse: $(curl -s http://localhost:8123/ping)"
echo "Tempo: $(curl -s http://localhost:3200/ready)"
echo "OTEL: $(curl -s http://localhost:13133/health | head -c 50)..."
echo "Grafana: $(curl -s http://localhost:3001/api/health | head -c 50)..."

echo ""
echo "=== Stack Ready ==="
echo "Grafana UI: http://localhost:3001 (admin/admin)"
echo "OTLP gRPC: localhost:4317"
echo "OTLP HTTP: localhost:4318"
```

## Stop All Containers

```bash
# Stop and remove all signoz containers
podman stop signoz-clickhouse signoz-tempo signoz-otel-collector signoz-grafana
podman rm signoz-clickhouse signoz-tempo signoz-otel-collector signoz-grafana

# Optional: Remove network
podman network rm signoz-net
```

## Phoenix Application Configuration

To send telemetry from your local Phoenix app to this stack, configure OpenTelemetry in your `config/runtime.exs`:

```elixir
# config/runtime.exs
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: "http://localhost:4317"

# Or for HTTP:
# config :opentelemetry_exporter,
#   otlp_protocol: :http_protobuf,
#   otlp_endpoint: "http://localhost:4318"
```

Add to your `mix.exs` dependencies:

```elixir
{:opentelemetry, "~> 1.4"},
{:opentelemetry_api, "~> 1.3"},
{:opentelemetry_exporter, "~> 1.7"},
{:opentelemetry_phoenix, "~> 1.2"},
{:opentelemetry_ecto, "~> 1.2"},
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
podman logs signoz-<container-name>

# Check if port is already in use
ss -tlnp | grep <port>
```

### ClickHouse Config Errors

If you see "user-level settings in wrong place" errors, the config has been fixed to use `users.xml` profiles. Rebuild the image:

```bash
nix-build clickhouse-nixos.nix -o result --check
podman load < result
```

### OTEL Collector Can't Reach Tempo

Ensure both containers are on the same network (`signoz-net`) and the OTEL config uses `signoz-tempo:4317` (container name, not `tempo`).

### Healthcheck Format Errors

All Nix files use nanosecond integers for healthcheck durations (not strings like "30s"):
- `Interval = 30000000000` (30 seconds)
- `Timeout = 5000000000` (5 seconds)
- `StartPeriod = 40000000000` (40 seconds)

## Key Technical Notes

1. **No KVM Required**: Uses `dockerTools.buildLayeredImage` with `extraCommands` instead of `buildImage` with `runAsRoot`

2. **Healthcheck Format**: Podman requires nanoseconds as integers, not duration strings

3. **Container Networking**: All containers must be on `signoz-net` for inter-container communication

4. **ClickHouse User Settings**: Must be in `users.xml` under `<profiles><default>`, not in main config

5. **Registry**: All images use `localhost/` prefix - no external registries

## Access Points Summary

| Service | URL/Endpoint | Credentials |
|---------|--------------|-------------|
| Grafana UI | http://localhost:3001 | admin / admin |
| OTLP gRPC | localhost:4317 | - |
| OTLP HTTP | localhost:4318 | - |
| Prometheus Metrics | http://localhost:8889/metrics | - |
| Tempo API | http://localhost:3200 | - |
| ClickHouse HTTP | http://localhost:8123 | - |
| ClickHouse Native | localhost:9000 | - |
| OTEL Health | http://localhost:13133/health | - |

---

**Document Status**: Verified working as of 2025-12-07 15:09 CET
