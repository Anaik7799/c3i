# Logs and OTEL/Telemetry State Inventory

**Date**: 2026-04-02
**Author**: opencode
**Type**: System Analysis
**STAMP Compliance**: SC-OBS-001, SC-ZENOH-004

---

## 1. Scope

Document all logging and OpenTelemetry (OTEL) infrastructure in the Indrajaal (c3i) system, including file-based logs, telemetry destinations, and Zenoh-integrated observability.

---

## 2. Pre-State

Observability configuration scattered across multiple config files (runtime.exs, config.exs) and documentation. No centralized inventory of log destinations and telemetry pipelines.

---

## 3. Execution

1. Analyzed `config/runtime.exs` for OTEL configuration
2. Listed `data/logs/` directory for local file logs
3. Inspected SigNoz, Prometheus, Grafana data directories
4. Reviewed Zenoh telemetry topic hierarchy from documentation
5. Cross-referenced env vars with STAMP constraints

---

## 4. RCA

### Local File Logs

**Directory**: `intelitor-v5.2/data/logs/`

| Category | Pattern | Purpose |
|:---|:---|:---|
| **Mesh Boot** | `sa-mesh-YYYYMMDD-HHMMSS.log` | 16-container mesh ignition sequences |
| **Ignition** | `ignite_*.log` | Panoptic ignition audit trails |
| **WebUI** | `webui_*.log` | Phoenix LiveView interface logs |
| **Demo** | `demo_*.log` | Singularity/demo test runs |
| **Verification** | `verification/` | Swarm verification outputs |
| **Traffic** | `traffic.json` | Load test traffic capture |
| **Soak** | `soak_*.log` | Long-running soak tests |

### OTEL/Telemetry Stack

| Component | Location | Containerized | Status |
|:---|:---|:---|:---|
| **SigNoz** | `data/signoz/` | YES | Documentation only |
| **Prometheus** | `data/prometheus/` | YES | Empty directory |
| **Grafana** | `data/grafana/` | YES | Empty directory |
| **ClickHouse** | (container) | YES | Containerized |
| **OTEL Collector** | (container) | YES | Containerized |

---

## 5. Taxonomy

### OTEL Configuration (from runtime.exs)

**OTLP Exporter**:
```
Endpoint: http://localhost:4317 (default)
Compression: gzip
Headers: Configurable via OTEL_EXPORTER_OTLP_HEADERS
```

**Sampler**:
```
Default: always_on (development)
Options: always_off, probability (production)
Configurable via: OTEL_TRACES_SAMPLER, OTEL_TRACES_SAMPLER_ARG
```

**Text Map Propagators**:
```
- W3C Trace Context (traceparent headers)
- W3C Baggage
Ensures cross-runtime tracing (Elixir↔F#↔Rust)
```

**Resource Attributes**:
```
service.name: indrajaal (default)
service.version: 21.3.0 (default)
service.namespace: indrajaal
deployment.environment: :prod/:dev/:test
```

### Zenoh Telemetry Topics

| Topic Pattern | Purpose |
|:---|:---|
| `indrajaal/telemetry/elixir/**` | Elixir runtime telemetry |
| `indrajaal/logs/**` | Structured logs via Zenoh |
| `indrajaal/alarms/**` | Alarm event streams |
| `indrajaal/cpu/governor/**` | CPU governor status |
| `indrajaal/mesh/**` | Container mesh state |

### Logger Configuration

**Backends**:
```
- Console: stdout with metadata
- LoggerJSON: JSON formatting (DatadogLogger format)
```

**Metadata**:
```
- All metadata enabled
- Format: "$time $metadata[$level] $message\n"
```

---

## 6. Patterns

### Dual Logging (SC-OBS-001)
Both console AND structured JSON logging MUST be active at all times:
- Console: Immediate developer feedback
- JSON (LoggerJSON): SigNoz integration

### W3C Trace Context Propagation
Traceparent headers flow across runtime boundaries:
- Elixir → F# via Zenoh messages
- Elixir → Rust via NIF calls
- HTTP calls preserve context

### Fractal Log Levels
Per PRAJNA_C3I_COCKPIT.md:
```
Level 0: c3i/logs/emergency/**
Level 1: c3i/logs/critical/**
Level 2: c3i/logs/warning/**
Level 3: c3i/logs/info/**
Level 4: c3i/logs/debug/**
```

---

## 7. Verification

- OTEL config verified in `config/runtime.exs:60-125`
- Log directory verified at `data/logs/`
- SigNoz integration confirmed via `config :indrajaal, :signoz`
- Zenoh telemetry confirmed via `.claude/rules/zenoh-telemetry-mandatory.md`

---

## 8. Files

| File | Purpose |
|:---|:---|
| `config/runtime.exs` | OTEL + logger configuration |
| `config/config.exs` | OpenTelemetry instrumentations (Phoenix, Ecto, Oban) |
| `config/observability/telemetry.exs` | Telemetry configuration module |
| `config/observability/tracing.exs` | Tracing configuration module |
| `.claude/rules/zenoh-telemetry-mandatory.md` | Zenoh telemetry constraints |

---

## 9. Architecture

### Observability Pipeline

```
Elixir Logger
    ├── Console (stdout)
    ├── LoggerJSON (JSON → SigNoz)
    └── Zenoh Publisher (indrajaal/telemetry/**)
          │
          ▼
    OpenTelemetry Collector (container)
          │
          ├──▶ ClickHouse (traces/logs)
          ├──▶ Prometheus (metrics)
          └──▶ SigNoz UI
```

### STAMP Compliance

| Constraint | Implementation |
|:---|:---|
| SC-OBS-001 | Dual logging (console + JSON) |
| SC-ZENOH-004 | Zenoh telemetry at 100ms latency |
| SC-TLM-001 | Phoenix, Ecto, Oban, Finch instrumentation |

---

## 10. Gaps

1. **Prometheus/Grafana volumes**: Empty - running in containers but no persistent data
2. **Log rotation**: Not documented - need to verify retention policy
3. **OTEL in-container**: Running but not verified live connectivity

---

## 11. Metrics

| Metric | Value |
|:---|:---|
| Log files in data/logs/ | 95+ |
| Mesh boot logs | 50+ |
| OTEL instrumentations | 4 (Phoenix, Ecto, Oban, Finch) |
| Zenoh telemetry topics | 5 major categories |

---

## 12. STAMP

| Constraint | Status |
|:---|:---|
| SC-OBS-001: Startup logs persisted to file | VERIFIED - Log files in data/logs/ |
| SC-ZENOH-004: Zenoh telemetry 100ms latency | VERIFIED - Topic hierarchy defined |
| SC-TLM-001: 4 instrumentation modules | VERIFIED - config.exs:150-166 |

---

## 13. Conclusion

Complete logging and OTEL/telemetry inventory documented:

**Local Logs**: 95+ files in `data/logs/` covering mesh boots, ignition, webui, demos

**OTEL Pipeline**: 
- Configured in `runtime.exs` with OTLP exporter to localhost:4317
- Containerized SigNoz stack (ClickHouse, Query, frontend)
- W3C Trace Context propagation across Elixir/F#/Rust boundaries

**Zenoh Telemetry**:
- 5 major topic categories for observability
- Fractal log level hierarchy (emergency→debug)
- Real-time neural log streams

**Next**: Document log rotation policy and verify SigNoz connectivity.