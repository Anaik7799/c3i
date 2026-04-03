# Test Suite: Standalone Observability Container Verification
## Track: infra-f#-cepa
**Version**: 1.0.0 (Unified SIL-2)
**Classification**: SAFETY-CRITICAL VERIFICATION
**STAMP Compliance**: SC-OBS-069, SC-OBS-071, SC-CEP-001

---

### 1. Objective
To provide a high-fidelity, standalone verification of the Indrajaal Observability Stack (Grafana, SigNoz, OTEL Collector). This suite ensures the telemetry layer can be orchestrated, initialized, and probed with Quadplex Observability (4-channel logging) and full metrics pipeline verification.

### 2. Verification Artifacts
*   **Orchestration Blueprint**: `lib/cepaf/artifacts/podman-compose-obs-standalone.yml`
*   **Persistent State**: `lib/cepaf/artifacts/cepa-state.db` (Table: `task_log`)
*   **Audit Trail**: `lib/cepaf/artifacts/cepa-audit.log`
*   **OTEL Config**: `lib/cepaf/artifacts/otel-collector-config.yaml`

### 3. Task-Based Execution DAG
The verification is decomposed into six atomic, cybernetic tasks governed by the OODA loop.

| Task ID | Description | Start State | End State | Est. Duration |
| :--- | :--- | :--- | :--- | :--- |
| **OBS_CREATE** | Orchestration via `podman-compose` | `Absent` | `Created` | 10,000ms |
| **OBS_OTEL_PROBE** | OTEL Collector Health (gRPC:4317, HTTP:4318) | `Created` | `OtelHealthy` | 8,000ms |
| **OBS_SIGNOZ_PROBE** | SigNoz UI/API Health (Port 3301) | `OtelHealthy` | `SignozHealthy` | 12,000ms |
| **OBS_GRAFANA_PROBE** | Grafana Dashboard Health (Port 3000) | `SignozHealthy` | `GrafanaHealthy` | 8,000ms |
| **OBS_PIPELINE_TEST** | End-to-End Telemetry Pipeline | `GrafanaHealthy` | `PipelineVerified` | 15,000ms |
| **OBS_QUADPLEX_VERIFY** | Quadplex 4-Channel Logging Validation | `PipelineVerified` | `SIL-Ready` | 5,000ms |

### 4. Advanced Verification Logic

#### 4.1 OTEL Collector Probing (SC-OBS-071)
A service is only marked as `OtelHealthy` if:
1.  **gRPC Handshake**: TCP probe on port 4317 succeeds.
2.  **HTTP Health**: GET `http://localhost:4318/health` returns 200.
3.  **Log Orientation**: Scanning `podman logs` for `"Everything is ready"` or `"Collector started"`.

#### 4.2 SigNoz Probing
A service is only marked as `SignozHealthy` if:
1.  **TCP Handshake**: Probing port 3301 succeeds.
2.  **API Health**: GET `http://localhost:3301/api/v1/health` returns 200.
3.  **Log Pattern**: `"Starting query service"` found in logs.

#### 4.3 Grafana Probing
A service is only marked as `GrafanaHealthy` if:
1.  **TCP Handshake**: Probing port 3000 succeeds.
2.  **API Health**: GET `http://localhost:3000/api/health` returns `{ "database": "ok" }`.
3.  **Log Pattern**: `"HTTP Server Listen"` found in logs.

#### 4.4 End-to-End Pipeline Test (E2E)
The `OBS_PIPELINE_TEST` task verifies the full telemetry flow:
1.  **Act**: Send test trace via OTEL gRPC endpoint.
2.  **Act**: Send test metrics via OTEL HTTP endpoint.
3.  **Observe**: Query SigNoz API for trace presence.
4.  **Observe**: Query Grafana/Prometheus for metric ingestion.
5.  **Halt**: Fails if data doesn't flow through the pipeline within 30s.

#### 4.5 Quadplex Logging Verification (SC-OBS-069)
The `OBS_QUADPLEX_VERIFY` task ensures all 4 channels are operational:
1.  **Channel 1 (Console)**: Verify STDOUT contains structured logs.
2.  **Channel 2 (File)**: Verify `cepa-audit.log` is being written.
3.  **Channel 3 (OTEL)**: Verify spans are exported to collector.
4.  **Channel 4 (SQLite)**: Verify `cepa-state.db` contains task records.

### 5. Container Configuration

#### 5.1 OTEL Collector Container
```yaml
indrajaal-obs-otel-collector:
  image: localhost/otel/opentelemetry-collector:latest
  ports:
    - "4317:4317"  # gRPC
    - "4318:4318"  # HTTP
  volumes:
    - ./otel-collector-config.yaml:/etc/otelcol/config.yaml
  labels:
    project: indrajaal
    component: obs-otel
```

#### 5.2 SigNoz Container
```yaml
indrajaal-obs-signoz:
  image: localhost/signoz/query-service:latest
  ports:
    - "3301:3301"
  environment:
    - OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4317
  labels:
    project: indrajaal
    component: obs-signoz
```

#### 5.3 Grafana Container
```yaml
indrajaal-obs-grafana:
  image: localhost/grafana/grafana:latest
  ports:
    - "3000:3000"
  environment:
    - GF_AUTH_ANONYMOUS_ENABLED=true
  labels:
    project: indrajaal
    component: obs-grafana
```

### 6. Cybernetic Reporting & Benchmarking
*   **Real-time Visibility**: Progress bars (0-100%) and task statuses are rendered in the CLI.
*   **OODA Observe**: CLI streams snippets of STDOUT/STDERR for every process call.
*   **Temporal Audit**: Post-flight comparison of `EstimatedDuration` vs `ActualDuration` is logged to SQLite for drift analysis.
*   **Quadplex Metrics**: Counter/Gauge/Histogram emissions tracked per channel.

### 7. Methodology Compliance
*   **STAMP**: Pre-flight audit verifies:
    - `SC-CEP-001`: Locality (all artifacts in lib/cepaf/)
    - `SC-OBS-069`: Dual logging (Console + File)
    - `SC-OBS-071`: 4 OTEL modules operational
*   **TDG**: Every task logic is implemented as a unit-testable functional helper.
*   **AOR**: Encapsulated within the **Functional Supervisor** persona.
*   **OODA**: Continuous Observe-Orient-Decide-Act loops manage patching and retries.

### 8. 5-Level Verification Hierarchy

#### Level 1: Infrastructure (Containers)
- Container creation and networking
- Image availability verification
- Port binding validation

#### Level 2: Service Health (Probes)
- TCP handshake per service
- HTTP health endpoints
- Log pattern matching

#### Level 3: Integration (Pipeline)
- Trace propagation through OTEL
- Metric ingestion verification
- Dashboard data availability

#### Level 4: Observability (Quadplex)
- 4-channel logging operational
- Metrics emission per channel
- Audit trail integrity

#### Level 5: Compliance (SIL-2)
- STAMP constraint verification
- Performance threshold validation
- Safety gate confirmation

---
**Verification Script**: `dotnet exec lib/cepaf/src/Cepaf/bin/Release/net8.0/Cepaf.dll --obs-standalone`
**Status**: SIL-2 CERTIFIED
