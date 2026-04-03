# Cepaf.Podman - ACE/VTO Integration Architecture

**Document Version**: 1.0.0
**Last Updated**: 2025-12-23
**Status**: DESIGN PROPOSAL
**Authors**: Architecture Team

---

## 1. Executive Summary

This document specifies the integration architecture between Cepaf.Podman (F# library) and the Indrajaal ACE/VTO Orchestrator (Elixir). The goal is to leverage Cepaf.Podman's type-safe Podman REST API client and STAMP safety constraints while maintaining the VTO orchestrator's role as the primary container lifecycle manager.

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Interop Method | Erlang Port with JSON-RPC | Low latency (<50ms per SC-PRF-050), persistent connection |
| Protocol | JSON-RPC 2.0 over stdio | Simple, debuggable, bidirectional |
| F# Runtime | Long-running daemon | Avoid startup overhead, maintain socket connection |
| Error Handling | Structured error types | Map Cepaf errors to Elixir tuples |

---

## 2. Architecture Overview

### 2.1 System Context Diagram

```
+-----------------------------------------------------------------------------------+
|                          Indrajaal System Boundary                                 |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  +-------------------+          JSON-RPC/stdio           +-------------------+    |
|  |                   |  <----------------------------->  |                   |    |
|  |   Elixir Layer    |                                   |    F# Layer       |    |
|  |                   |                                   |                   |    |
|  +-------------------+                                   +-------------------+    |
|  |                   |                                   |                   |    |
|  | VTO Orchestrator  |                                   | Cepaf.Podman      |    |
|  | - Lifecycle mgmt  |                                   | - REST API client |    |
|  | - Health checks   |                                   | - STAMP validation|    |
|  | - Deploy config   |                                   | - Type safety     |    |
|  |                   |                                   | - Health probes   |    |
|  | Config (SSoT)     |                                   |                   |    |
|  | - Container specs |                                   | Unix Socket       |    |
|  | - Health configs  |                                   |   |               |    |
|  |                   |                                   |   v               |    |
|  +-------------------+                                   +-------------------+    |
|          |                                                        |               |
|          |                                                        |               |
|          +--------------------------------------------------------+               |
|                                        |                                          |
|                                        v                                          |
|                        +------------------------------+                           |
|                        |       Podman 5.4.1+          |                           |
|                        |     (Rootless Runtime)       |                           |
|                        +------------------------------+                           |
|                        |  indrajaal-db  |  indrajaal-app  |  indrajaal-obs  |     |
|                        +------------------------------+                           |
|                                                                                   |
+-----------------------------------------------------------------------------------+
```

### 2.2 Component Architecture

```
+-----------------------------------------------------------------------+
|                       ACE Integration Layer                            |
+-----------------------------------------------------------------------+
|                                                                       |
|   Elixir Side                           F# Side                       |
|   ============                          ========                      |
|                                                                       |
|   +-------------------------+           +-------------------------+   |
|   | Indrajaal.Cepaf.Bridge  |           | Cepaf.Bridge.Server     |   |
|   |-------------------------|           |-------------------------|   |
|   | - Port management       |<--------->| - JSON-RPC handler      |   |
|   | - Request encoding      |  stdio    | - Command dispatch      |   |
|   | - Response decoding     |           | - Response encoding     |   |
|   | - Timeout handling      |           | - Error translation     |   |
|   +-------------------------+           +-------------------------+   |
|            |                                     |                    |
|            v                                     v                    |
|   +-------------------------+           +-------------------------+   |
|   | Indrajaal.Cepaf.Client  |           | Cepaf.Podman.Client     |   |
|   |-------------------------|           |-------------------------|   |
|   | - Container ops         |           | - HttpClient            |   |
|   | - Health checks         |           | - Serialization         |   |
|   | - Safety validation     |           | - Unix socket           |   |
|   +-------------------------+           +-------------------------+   |
|            |                                     |                    |
|            v                                     v                    |
|   +-------------------------+           +-------------------------+   |
|   | VTOOrchestrator         |           | Cepaf.Podman.Api.*      |   |
|   |-------------------------|           |-------------------------|   |
|   | - start_sequence/1      |           | - Containers            |   |
|   | - stop_sequence/0       |           | - Images                |   |
|   | - run_vto_loop/1        |           | - Networks              |   |
|   +-------------------------+           | - Health.Probes         |   |
|                                         | - Safety.Constraints    |   |
|                                         +-------------------------+   |
|                                                                       |
+-----------------------------------------------------------------------+
```

---

## 3. Interop Strategy Analysis

### 3.1 Options Evaluated

| Option | Latency | Complexity | Reliability | Chosen |
|--------|---------|------------|-------------|--------|
| **A: Port + JSON-RPC** | ~5-10ms | Low | High | YES |
| B: gRPC | ~2-5ms | Medium | High | No |
| C: REST API (Giraffe) | ~10-20ms | Medium | Medium | No |
| D: Shared File Protocol | ~50-100ms | Low | Low | No |

### 3.2 Recommended Approach: Erlang Port with JSON-RPC

**Why Port-based over CLI invocation:**
- Current VTO uses `System.cmd("podman", ...)` for each operation
- CLI spawns new process per command (~50-100ms overhead)
- Port maintains persistent F# process (~5ms per call)

**Why JSON-RPC over raw stdio:**
- Structured request/response format
- Built-in error handling
- Request ID correlation for async ops
- Well-documented specification

---

## 4. Communication Protocol

### 4.1 JSON-RPC 2.0 Message Format

#### Request Format
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "method": "container.create",
  "params": {
    "name": "indrajaal-db",
    "image": "localhost/indrajaal-timescaledb-demo:nixos-devenv",
    "ports": [{"host": 5433, "container": 5433}],
    "env": {"POSTGRES_USER": "indrajaal"},
    "healthCheck": {
      "test": ["CMD", "pg_isready", "-U", "indrajaal"],
      "interval": "2s",
      "retries": 60
    }
  }
}
```

#### Success Response
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "result": {
    "containerId": "abc123def456",
    "name": "indrajaal-db",
    "status": "created"
  }
}
```

#### Error Response
```json
{
  "jsonrpc": "2.0",
  "id": "req-001",
  "error": {
    "code": -32001,
    "message": "ContainerAlreadyExists",
    "data": {
      "name": "indrajaal-db",
      "existingId": "xyz789"
    }
  }
}
```

### 4.2 Method Catalog

| Method | Description | SC Constraint |
|--------|-------------|---------------|
| `system.ping` | Health check for bridge | SC-PRF-050 |
| `system.info` | Get Podman system info | SC-CNT-009 |
| `container.create` | Create container with validation | SC-POD-001..008 |
| `container.start` | Start container | SC-EMR-057 |
| `container.stop` | Stop container gracefully | SC-EMR-057 |
| `container.remove` | Remove container | SC-EMR-060 |
| `container.inspect` | Get container details | - |
| `container.list` | List containers with filters | - |
| `container.logs` | Get container logs | - |
| `container.healthCheck` | Run health check | SC-POD-003 |
| `health.summary` | Get all container health | SC-POD-003 |
| `health.probe` | Run specific probe | SC-POD-003 |
| `safety.validate` | Validate container spec | SC-CNT-010, SC-POD-* |
| `network.ensure` | Create network if not exists | SC-POD-006 |
| `emergency.stop` | Force stop with timeout | SC-EMR-057 |
| `emergency.stopAll` | Stop all managed containers | SC-EMR-057 |

### 4.3 Error Codes

| Code | Type | Description |
|------|------|-------------|
| -32700 | ParseError | Invalid JSON |
| -32600 | InvalidRequest | Invalid JSON-RPC |
| -32601 | MethodNotFound | Unknown method |
| -32602 | InvalidParams | Invalid parameters |
| -32603 | InternalError | Internal error |
| -32001 | SocketNotFound | Podman socket missing |
| -32002 | ConnectionRefused | Cannot connect |
| -32003 | ConnectionTimeout | Operation timeout |
| -32004 | ContainerNotFound | Container missing |
| -32005 | ContainerAlreadyExists | Name conflict |
| -32006 | ImageNotFound | Image missing |
| -32007 | HealthCheckFailed | Health check error |
| -32008 | SafetyViolation | STAMP constraint failed |

---

## 5. Error Handling Strategy

### 5.1 Error Type Mapping

```
F# PodmanError                    -->  Elixir Error Tuple
=============================          ====================

SocketNotFound path               -->  {:error, :socket_not_found, path}
ConnectionRefused endpoint        -->  {:error, :connection_refused, endpoint}
ConnectionTimeout op duration     -->  {:error, :timeout, op, duration}
ContainerNotFound id              -->  {:error, :container_not_found, id}
ContainerAlreadyExists name       -->  {:error, :container_exists, name}
ImageNotFound ref                 -->  {:error, :image_not_found, ref}
HealthCheckFailed cont output     -->  {:error, :health_check_failed, cont, output}
SafetyConstraintViolation id rea  -->  {:error, :safety_violation, id, reason}
```

### 5.2 Retry Strategy

```elixir
# In Indrajaal.Cepaf.Client
@retry_config %{
  max_attempts: 3,
  initial_delay_ms: 100,
  max_delay_ms: 2000,
  retryable_errors: [:connection_refused, :timeout]
}
```

### 5.3 Circuit Breaker

```
State Machine:
  CLOSED  --[5 failures]--> OPEN --[30s timeout]--> HALF_OPEN
                                                         |
                                            [1 success]-+-> CLOSED
                                            [1 failure]-+-> OPEN
```

---

## 6. Performance Considerations

### 6.1 Latency Requirements (SC-PRF-050)

| Operation | Target | Max Acceptable |
|-----------|--------|----------------|
| Port startup | N/A (once) | 500ms |
| Ping | 2ms | 10ms |
| Container create | 30ms | 100ms |
| Container start | 20ms | 50ms |
| Health check | 10ms | 30ms |
| Stop (graceful) | 100ms | 5000ms (SC-EMR-057) |

### 6.2 Connection Pooling

```
+------------------------+
|  Elixir Port Process   |
|                        |
|  +-----------------+   |
|  | F# Bridge Daemon|   |
|  |                 |   |
|  |  +-----------+  |   |
|  |  | Podman    |  |   |
|  |  | HttpClient|--|---+---> Unix Socket
|  |  |           |  |   |     /run/user/1000/podman/podman.sock
|  |  +-----------+  |   |
|  |                 |   |
|  +-----------------+   |
+------------------------+
```

- Single long-lived F# process per VTO orchestrator
- Reuses Podman socket connection
- Async request handling with correlation IDs

### 6.3 Message Size Optimization

- Compact JSON keys (no pretty printing)
- Binary encoding for logs/large outputs (base64)
- Streaming for container logs (chunked responses)

---

## 7. Implementation Phases

### Phase 1: Bridge Foundation (Week 1)

**F# Side:**
- [ ] Create `Cepaf.Bridge.Server` project
- [ ] Implement JSON-RPC parser/serializer
- [ ] Implement stdio communication layer
- [ ] Add ping/info methods

**Elixir Side:**
- [ ] Create `Indrajaal.Cepaf.Bridge` GenServer
- [ ] Implement Port management
- [ ] Add request/response encoding
- [ ] Add timeout handling

### Phase 2: Core Operations (Week 2)

**Methods to implement:**
- [ ] `container.create`
- [ ] `container.start`
- [ ] `container.stop`
- [ ] `container.remove`
- [ ] `container.inspect`
- [ ] `container.list`

**Integration:**
- [ ] Create `Indrajaal.Cepaf.Client` high-level API
- [ ] Add to VTO orchestrator

### Phase 3: Health & Safety (Week 3)

**Methods to implement:**
- [ ] `container.healthCheck`
- [ ] `health.summary`
- [ ] `health.probe`
- [ ] `safety.validate`

**Integration:**
- [ ] Replace VTO health checks with Cepaf
- [ ] Add pre-flight validation

### Phase 4: Advanced Features (Week 4)

**Methods to implement:**
- [ ] `network.ensure`
- [ ] `emergency.stop`
- [ ] `emergency.stopAll`
- [ ] `container.logs` (streaming)

**Integration:**
- [ ] Full VTO migration
- [ ] Remove System.cmd calls

---

## 8. Security Considerations

### 8.1 Port Security

- F# daemon runs as same user as Elixir app
- No network exposure (stdio only)
- Inherits parent process permissions

### 8.2 Input Validation

```fsharp
// All inputs validated before Podman API calls
let validateContainerSpec spec =
    Constraints.validateContainerSpec spec
    |> Result.bind (fun _ -> Constraints.validateImageReference spec.Image)
```

### 8.3 STAMP Constraint Enforcement

| Constraint | Enforcement Point |
|------------|-------------------|
| SC-CNT-010 | `validateImageReference` before pull/create |
| SC-POD-001 | `validateContainerSpec` name check |
| SC-POD-002 | `validateContainerSpec` resource limits |
| SC-POD-003 | `validateContainerSpec` health check |
| SC-EMR-057 | `emergencyStop` timeout enforcement |

---

## 9. Monitoring & Observability

### 9.1 Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `cepaf_bridge_requests_total` | Counter | Total requests by method |
| `cepaf_bridge_request_duration_ms` | Histogram | Request latency |
| `cepaf_bridge_errors_total` | Counter | Errors by type |
| `cepaf_container_operations_total` | Counter | Container ops |
| `cepaf_health_checks_total` | Counter | Health checks run |

### 9.2 Logging

```elixir
# Quadplex Observability integration
Logger.info("Cepaf:bridge:request", method: method, id: id)
Logger.debug("Cepaf:bridge:response", id: id, duration_ms: duration)
Logger.error("Cepaf:bridge:error", id: id, code: code, message: msg)
```

### 9.3 Health Endpoints

- Bridge process health: `Cepaf.Bridge.healthy?()`
- Podman socket health: `system.ping` method

---

## 10. Testing Strategy

### 10.1 Unit Tests

**F# Side:**
```fsharp
// test/Cepaf.Bridge.Tests/JsonRpcTests.fs
[<Test>]
let ``parseRequest handles valid container create`` () =
    let json = """{"jsonrpc":"2.0","id":"1","method":"container.create","params":{...}}"""
    let result = JsonRpc.parseRequest json
    Expect.isOk result "Should parse valid request"
```

**Elixir Side:**
```elixir
# test/indrajaal/cepaf/bridge_test.exs
test "encode/decode roundtrip" do
  request = %{method: "container.create", params: %{name: "test"}}
  encoded = Bridge.encode_request(request)
  assert {:ok, decoded} = Bridge.decode_response(encoded)
end
```

### 10.2 Integration Tests

```elixir
# test/indrajaal/cepaf/client_test.exs
describe "Cepaf.Client integration" do
  @tag :integration
  test "create and start container" do
    {:ok, id} = Cepaf.Client.create_container(@valid_spec)
    assert {:ok, _} = Cepaf.Client.start_container(id)
    on_exit(fn -> Cepaf.Client.remove_container(id) end)
  end
end
```

### 10.3 Property Tests

```elixir
# test/indrajaal/cepaf/client_property_test.exs
property "all error responses map to valid Elixir tuples" do
  check all error <- StreamData.member_of(@cepaf_error_codes) do
    {:error, _type, _details} = Cepaf.Bridge.map_error(error)
  end
end
```

---

## 11. Migration Path

### 11.1 Current State (VTO v1)

```elixir
# Current: Direct podman CLI calls
System.cmd("podman", ["run", "-d", "--name", name, image])
System.cmd("podman", ["exec", name] ++ health_cmd)
```

### 11.2 Target State (VTO v2 with Cepaf)

```elixir
# Target: Type-safe Cepaf client
{:ok, id} = Cepaf.Client.create_container(spec)
{:ok, _} = Cepaf.Client.start_container(id)
{:ok, :healthy} = Cepaf.Client.health_check(id)
```

### 11.3 Migration Steps

1. **Parallel Operation**: Run both implementations, compare results
2. **Shadow Mode**: Cepaf executes but results not used
3. **Canary Mode**: 10% of operations via Cepaf
4. **Full Migration**: Remove CLI-based implementation

---

## 12. Appendices

### A. F# Project Structure

```
lib/cepaf/src/Cepaf.Bridge/
    Cepaf.Bridge.fsproj
    JsonRpc.fs           -- JSON-RPC 2.0 implementation
    Server.fs            -- Main stdio server loop
    Commands.fs          -- Method handlers
    Program.fs           -- Entry point
```

### B. Elixir Module Structure

```
lib/indrajaal/cepaf/
    bridge.ex            -- Port GenServer
    client.ex            -- High-level API
    protocol.ex          -- JSON-RPC encoding
    errors.ex            -- Error translation
```

### C. Sample Container Spec Translation

**Elixir Config (current):**
```elixir
%{
  service_name: "indrajaal-db",
  image_name: "indrajaal-timescaledb-demo",
  image_tag: "nixos-devenv",
  ports: ["5433:5433"],
  env: ["POSTGRES_USER=indrajaal"],
  health_check: {:cmd, ["pg_isready", "-U", "indrajaal"], [interval: 2, retries: 60]}
}
```

**Cepaf.Podman ContainerSpec:**
```fsharp
ContainerSpec.create "localhost/indrajaal-timescaledb-demo:nixos-devenv"
|> ContainerSpec.withName "indrajaal-db"
|> ContainerSpec.withPort 5433us 5433us
|> ContainerSpec.withEnv "POSTGRES_USER" "indrajaal"
|> ContainerSpec.withHealthCheck (
    HealthCheckConfig.create (HealthCheckTest.Cmd ["pg_isready"; "-U"; "indrajaal"])
    |> HealthCheckConfig.withInterval (TimeSpan.FromSeconds(2.0))
    |> HealthCheckConfig.withRetries 60
)
```

---

## 13. References

- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [Erlang Port Documentation](https://www.erlang.org/doc/tutorial/c_port.html)
- [Podman REST API](https://docs.podman.io/en/latest/_static/api.html)
- [GEMINI.md v10.2.0](../../GEMINI.md) - STAMP Safety Constraints
- [VTO Orchestrator](../../lib/indrajaal/deployment/vto_orchestrator.ex)
- [Cepaf.Podman](../../lib/cepaf/src/Cepaf.Podman/)
