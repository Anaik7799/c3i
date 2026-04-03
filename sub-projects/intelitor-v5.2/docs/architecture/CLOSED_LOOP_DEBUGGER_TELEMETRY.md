# Closed-Loop Debugger-LSP-Telemetry Architecture

**Version**: 1.0.0 | **Date**: 2026-01-04 | **Status**: ACTIVE
**STAMP**: SC-DEBUG-001 to SC-DEBUG-015 | **AOR**: AOR-DEBUG-001 to AOR-DEBUG-010

## 1.0 Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CLOSED-LOOP DEBUGGER TELEMETRY SYSTEM                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                   │
│  │   Elixir    │     │    F#       │     │   Claude    │                   │
│  │  Debugger   │     │  Debugger   │     │    LSP      │                   │
│  │   (DAP)     │     │  (.NET DAP) │     │   Plugin    │                   │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                   │
│         │                   │                   │                           │
│         └───────────┬───────┴───────────────────┘                           │
│                     │                                                       │
│                     ▼                                                       │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    TELEMETRY AGGREGATION BUS                         │   │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐        │   │
│  │  │ Debugger  │  │   LSP     │  │  Fractal  │  │   OODA    │        │   │
│  │  │  Events   │  │  Events   │  │   Logs    │  │  Metrics  │        │   │
│  │  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘        │   │
│  └────────┼──────────────┼──────────────┼──────────────┼───────────────┘   │
│           │              │              │              │                    │
│           └──────────────┴──────┬───────┴──────────────┘                    │
│                                 │                                           │
│                                 ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         ZENOH PUB/SUB MESH                           │   │
│  │                                                                       │   │
│  │  indrajaal/debug/**     indrajaal/lsp/**      indrajaal/log/**      │   │
│  │  indrajaal/trace/**     indrajaal/metrics/**  indrajaal/ooda/**     │   │
│  └──────────────────────────────┬──────────────────────────────────────┘   │
│                                 │                                           │
│           ┌─────────────────────┼─────────────────────┐                    │
│           │                     │                     │                    │
│           ▼                     ▼                     ▼                    │
│  ┌─────────────┐       ┌─────────────┐       ┌─────────────┐              │
│  │   Prajna    │       │   CEPAF     │       │   SigNoz    │              │
│  │  Dashboard  │       │  Cockpit    │       │    OTEL     │              │
│  │  (Phoenix)  │       │   (F# TUI)  │       │   Backend   │              │
│  └─────────────┘       └─────────────┘       └─────────────┘              │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         gRPC SERVICE LAYER                           │   │
│  │                                                                       │   │
│  │  DebuggerService    LSPService    TelemetryService    TraceService  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 2.0 STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-DEBUG-001 | Debugger events MUST publish to Zenoh within 10ms | CRITICAL |
| SC-DEBUG-002 | LSP events MUST correlate with debugger context | HIGH |
| SC-DEBUG-003 | Fractal logs MUST include debugger session ID | HIGH |
| SC-DEBUG-004 | gRPC calls MUST timeout at 5 seconds | CRITICAL |
| SC-DEBUG-005 | Breakpoint state MUST sync across all subscribers | CRITICAL |
| SC-DEBUG-006 | Stack traces MUST include source mapping | HIGH |
| SC-DEBUG-007 | Variable inspection MUST be non-blocking | HIGH |
| SC-DEBUG-008 | Telemetry bus MUST handle 10K events/sec | HIGH |
| SC-DEBUG-009 | Dashboard refresh MUST be < 100ms latency | MEDIUM |
| SC-DEBUG-010 | Session state MUST persist to DuckDB | HIGH |

## 3.0 AOR Rules

| ID | Rule |
|----|------|
| AOR-DEBUG-001 | Debugger MUST emit structured telemetry events |
| AOR-DEBUG-002 | LSP MUST forward diagnostics to telemetry bus |
| AOR-DEBUG-003 | Breakpoints MUST be versioned in Immutable Register |
| AOR-DEBUG-004 | gRPC services MUST use circuit breakers |
| AOR-DEBUG-005 | Fractal logs MUST tag with session correlation ID |
| AOR-DEBUG-006 | Zenoh topics MUST follow FQUN naming |
| AOR-DEBUG-007 | Dashboard MUST subscribe to relevant topics |
| AOR-DEBUG-008 | Trace spans MUST propagate through all layers |
| AOR-DEBUG-009 | Hot reload MUST preserve debugger state |
| AOR-DEBUG-010 | Crash recovery MUST restore breakpoints |

## 4.0 Zenoh Topic Hierarchy (FQUN)

```
indrajaal/
├── debug/
│   ├── elixir/
│   │   ├── breakpoint/{module}/{line}     # Breakpoint events
│   │   ├── step/{session_id}              # Step execution
│   │   ├── variable/{session_id}/{var}    # Variable inspection
│   │   └── stack/{session_id}             # Stack trace
│   ├── fsharp/
│   │   ├── breakpoint/{namespace}/{line}
│   │   ├── step/{session_id}
│   │   ├── variable/{session_id}/{var}
│   │   └── stack/{session_id}
│   └── session/
│       ├── start/{session_id}
│       ├── pause/{session_id}
│       └── stop/{session_id}
├── lsp/
│   ├── elixir/
│   │   ├── diagnostic/{file_path}
│   │   ├── completion/{file_path}
│   │   ├── hover/{file_path}/{line}
│   │   └── definition/{symbol}
│   ├── fsharp/
│   │   ├── diagnostic/{file_path}
│   │   └── ...
│   └── nix/
│       └── diagnostic/{file_path}
├── log/
│   ├── L1/{domain}/{module}               # Function level
│   ├── L2/{domain}                        # Module level
│   ├── L3/                                # Service level
│   ├── L4/                                # Container level
│   └── L5/                                # System level
├── trace/
│   ├── span/{trace_id}/{span_id}
│   └── context/{trace_id}
└── grpc/
    ├── call/{service}/{method}
    └── stream/{service}/{stream_id}
```

## 5.0 Component Architecture

### 5.1 Elixir Debug Adapter (DAP)

```elixir
# lib/indrajaal/debugger/elixir_dap.ex
defmodule Indrajaal.Debugger.ElixirDAP do
  @moduledoc """
  Debug Adapter Protocol bridge for Elixir with Zenoh telemetry.

  STAMP: SC-DEBUG-001, SC-DEBUG-005
  AOR: AOR-DEBUG-001, AOR-DEBUG-003
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohPublisher
  alias Indrajaal.Observability.Fractal.Decorator

  @zenoh_prefix "indrajaal/debug/elixir"
  @publish_timeout_ms 10

  defstruct [:session_id, :breakpoints, :status, :stack, :variables]

  # Breakpoint management
  def set_breakpoint(module, line, opts \\ []) do
    GenServer.call(__MODULE__, {:set_breakpoint, module, line, opts})
  end

  def remove_breakpoint(module, line) do
    GenServer.call(__MODULE__, {:remove_breakpoint, module, line})
  end

  # Execution control
  def continue(session_id), do: GenServer.cast(__MODULE__, {:continue, session_id})
  def step_over(session_id), do: GenServer.cast(__MODULE__, {:step_over, session_id})
  def step_into(session_id), do: GenServer.cast(__MODULE__, {:step_into, session_id})
  def step_out(session_id), do: GenServer.cast(__MODULE__, {:step_out, session_id})

  # Variable inspection
  def inspect_variable(session_id, var_name) do
    GenServer.call(__MODULE__, {:inspect_var, session_id, var_name})
  end

  # GenServer callbacks
  def handle_call({:set_breakpoint, module, line, opts}, _from, state) do
    # Set breakpoint using :int module
    case :int.break(module, line) do
      :ok ->
        breakpoint = %{module: module, line: line, opts: opts, id: generate_bp_id()}
        new_breakpoints = [breakpoint | state.breakpoints]

        # Publish to Zenoh
        publish_breakpoint_event(:set, breakpoint)

        # Log to fractal
        Decorator.log(:L2, :debugger, "Breakpoint set", %{
          module: module, line: line, session: state.session_id
        })

        {:reply, {:ok, breakpoint.id}, %{state | breakpoints: new_breakpoints}}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_cast({:continue, session_id}, state) do
    :int.continue(session_id)
    publish_step_event(:continue, session_id)
    {:noreply, state}
  end

  # Zenoh publishing
  defp publish_breakpoint_event(action, breakpoint) do
    topic = "#{@zenoh_prefix}/breakpoint/#{breakpoint.module}/#{breakpoint.line}"
    payload = %{
      action: action,
      breakpoint: breakpoint,
      timestamp: DateTime.utc_now()
    }

    Task.start(fn ->
      ZenohPublisher.publish(topic, payload, timeout: @publish_timeout_ms)
    end)
  end

  defp publish_step_event(action, session_id) do
    topic = "#{@zenoh_prefix}/step/#{session_id}"
    ZenohPublisher.publish(topic, %{action: action, timestamp: DateTime.utc_now()})
  end
end
```

### 5.2 F# Debug Adapter Bridge

```fsharp
// lib/cepaf/src/Cepaf/Debugger/FSharpDAP.fs
namespace Cepaf.Debugger

open System
open System.Diagnostics
open Cepaf.Observability
open Cepaf.Zenoh

/// F# Debug Adapter Protocol bridge with Zenoh telemetry
/// STAMP: SC-DEBUG-001, SC-DEBUG-005
/// AOR: AOR-DEBUG-001, AOR-DEBUG-003
module FSharpDAP =

    type BreakpointInfo = {
        Id: Guid
        Namespace: string
        File: string
        Line: int
        Condition: string option
        HitCount: int
    }

    type DebugSession = {
        Id: Guid
        StartTime: DateTime
        Breakpoints: BreakpointInfo list
        Status: string
        CurrentStack: string list
    }

    let private zenohPrefix = "indrajaal/debug/fsharp"
    let private publishTimeoutMs = 10

    /// Publish debug event to Zenoh
    let private publishEvent (topic: string) (payload: obj) =
        async {
            let fullTopic = sprintf "%s/%s" zenohPrefix topic
            do! ZenohSession.publish fullTopic payload publishTimeoutMs
        } |> Async.Start

    /// Set breakpoint with Zenoh notification
    let setBreakpoint (ns: string) (file: string) (line: int) =
        let bp = {
            Id = Guid.NewGuid()
            Namespace = ns
            File = file
            Line = line
            Condition = None
            HitCount = 0
        }

        // Publish to Zenoh
        publishEvent (sprintf "breakpoint/%s/%d" ns line) {|
            action = "set"
            breakpoint = bp
            timestamp = DateTime.UtcNow
        |}

        // Log to fractal
        QuadplexLogger.log L2 "debugger" "Breakpoint set" [
            "namespace", ns
            "file", file
            "line", string line
        ]

        bp

    /// Step execution
    let stepOver (sessionId: Guid) =
        publishEvent (sprintf "step/%O" sessionId) {|
            action = "step_over"
            timestamp = DateTime.UtcNow
        |}

    let stepInto (sessionId: Guid) =
        publishEvent (sprintf "step/%O" sessionId) {|
            action = "step_into"
            timestamp = DateTime.UtcNow
        |}

    /// Inspect variable
    let inspectVariable (sessionId: Guid) (varName: string) =
        async {
            // Get variable value from debugger
            let! value = Debugger.GetVariableValue varName

            publishEvent (sprintf "variable/%O/%s" sessionId varName) {|
                name = varName
                value = value
                type_ = value.GetType().Name
                timestamp = DateTime.UtcNow
            |}

            return value
        }
```

### 5.3 Telemetry Aggregation Bus

```elixir
# lib/indrajaal/debugger/telemetry_bus.ex
defmodule Indrajaal.Debugger.TelemetryBus do
  @moduledoc """
  Central telemetry aggregation bus for debugger, LSP, and fractal logs.

  Aggregates events from multiple sources and publishes to Zenoh mesh.

  STAMP: SC-DEBUG-008
  AOR: AOR-DEBUG-002, AOR-DEBUG-005
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.ZenohPublisher
  alias Indrajaal.Observability.Fractal.BatchEncoder

  @flush_interval_ms 50
  @max_batch_size 100

  defstruct [
    :correlation_id,
    :buffer,
    :subscribers,
    :stats
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Event ingestion
  def emit(source, event_type, payload) do
    GenServer.cast(__MODULE__, {:emit, source, event_type, payload, self()})
  end

  def emit_debugger(event_type, payload) do
    emit(:debugger, event_type, payload)
  end

  def emit_lsp(event_type, payload) do
    emit(:lsp, event_type, payload)
  end

  def emit_fractal(level, domain, message, metadata) do
    emit(:fractal, level, %{domain: domain, message: message, metadata: metadata})
  end

  # Subscription
  def subscribe(topics) when is_list(topics) do
    GenServer.call(__MODULE__, {:subscribe, topics, self()})
  end

  # GenServer implementation
  def init(_opts) do
    # Attach telemetry handlers
    attach_telemetry_handlers()

    # Schedule periodic flush
    Process.send_after(self(), :flush, @flush_interval_ms)

    {:ok, %__MODULE__{
      correlation_id: generate_correlation_id(),
      buffer: [],
      subscribers: %{},
      stats: %{events_processed: 0, batches_sent: 0}
    }}
  end

  def handle_cast({:emit, source, event_type, payload, from_pid}, state) do
    event = %{
      source: source,
      type: event_type,
      payload: payload,
      correlation_id: state.correlation_id,
      timestamp: System.system_time(:nanosecond),
      from: from_pid
    }

    new_buffer = [event | state.buffer]

    # Flush if buffer full
    if length(new_buffer) >= @max_batch_size do
      flush_buffer(new_buffer, state)
      {:noreply, %{state | buffer: [], stats: update_stats(state.stats, length(new_buffer))}}
    else
      {:noreply, %{state | buffer: new_buffer}}
    end
  end

  def handle_info(:flush, state) do
    if length(state.buffer) > 0 do
      flush_buffer(state.buffer, state)
    end

    Process.send_after(self(), :flush, @flush_interval_ms)
    {:noreply, %{state | buffer: [], stats: update_stats(state.stats, length(state.buffer))}}
  end

  defp flush_buffer(events, state) do
    # Group by source
    grouped = Enum.group_by(events, & &1.source)

    # Publish each group to appropriate Zenoh topic
    Enum.each(grouped, fn {source, source_events} ->
      topic = zenoh_topic_for(source)
      encoded = BatchEncoder.encode(source_events)
      ZenohPublisher.publish_batch(topic, encoded)

      # Notify local subscribers
      notify_subscribers(source, source_events, state.subscribers)
    end)
  end

  defp zenoh_topic_for(:debugger), do: "indrajaal/debug/events"
  defp zenoh_topic_for(:lsp), do: "indrajaal/lsp/events"
  defp zenoh_topic_for(:fractal), do: "indrajaal/log/events"
  defp zenoh_topic_for(:trace), do: "indrajaal/trace/events"
  defp zenoh_topic_for(_), do: "indrajaal/telemetry/events"

  defp attach_telemetry_handlers do
    :telemetry.attach_many(
      "debugger-bus",
      [
        [:elixir_ls, :request, :stop],
        [:debugger, :breakpoint, :hit],
        [:debugger, :step, :complete],
        [:lsp, :diagnostic, :published],
        [:fractal, :log, :emitted]
      ],
      &handle_telemetry_event/4,
      nil
    )
  end

  defp handle_telemetry_event(event, measurements, metadata, _config) do
    emit(:telemetry, event, %{measurements: measurements, metadata: metadata})
  end
end
```

### 5.4 gRPC Service Definitions

```protobuf
// lib/cepaf/proto/debugger.proto
syntax = "proto3";

package indrajaal.debugger;

option csharp_namespace = "Indrajaal.Debugger.Grpc";

// Debug session management
service DebuggerService {
  // Session lifecycle
  rpc StartSession(StartSessionRequest) returns (StartSessionResponse);
  rpc StopSession(StopSessionRequest) returns (StopSessionResponse);
  rpc GetSessionStatus(GetSessionStatusRequest) returns (SessionStatus);

  // Breakpoint management
  rpc SetBreakpoint(SetBreakpointRequest) returns (BreakpointResponse);
  rpc RemoveBreakpoint(RemoveBreakpointRequest) returns (BreakpointResponse);
  rpc ListBreakpoints(ListBreakpointsRequest) returns (BreakpointList);

  // Execution control
  rpc Continue(ContinueRequest) returns (ExecutionResponse);
  rpc StepOver(StepRequest) returns (ExecutionResponse);
  rpc StepInto(StepRequest) returns (ExecutionResponse);
  rpc StepOut(StepRequest) returns (ExecutionResponse);

  // Variable inspection
  rpc InspectVariable(InspectVariableRequest) returns (VariableValue);
  rpc EvaluateExpression(EvaluateRequest) returns (EvaluateResponse);

  // Stack trace
  rpc GetStackTrace(GetStackTraceRequest) returns (StackTrace);

  // Event streaming
  rpc StreamEvents(StreamEventsRequest) returns (stream DebugEvent);
}

// LSP coordination service
service LSPService {
  rpc GetDiagnostics(GetDiagnosticsRequest) returns (DiagnosticList);
  rpc GetDefinition(GetDefinitionRequest) returns (Location);
  rpc GetReferences(GetReferencesRequest) returns (LocationList);
  rpc GetHover(GetHoverRequest) returns (HoverInfo);

  // Streaming diagnostics
  rpc StreamDiagnostics(StreamDiagnosticsRequest) returns (stream Diagnostic);
}

// Telemetry service
service TelemetryService {
  rpc EmitEvent(EmitEventRequest) returns (EmitEventResponse);
  rpc StreamEvents(StreamTelemetryRequest) returns (stream TelemetryEvent);
  rpc GetMetrics(GetMetricsRequest) returns (MetricsResponse);
}

// Messages
message StartSessionRequest {
  string language = 1;  // "elixir" | "fsharp"
  string project_root = 2;
  map<string, string> options = 3;
}

message StartSessionResponse {
  string session_id = 1;
  bool success = 2;
  string error_message = 3;
}

message SetBreakpointRequest {
  string session_id = 1;
  string file_path = 2;
  int32 line = 3;
  string condition = 4;
  int32 hit_count = 5;
}

message BreakpointResponse {
  string breakpoint_id = 1;
  bool verified = 2;
  string message = 3;
}

message StackTrace {
  repeated StackFrame frames = 1;
}

message StackFrame {
  int32 id = 1;
  string name = 2;
  string source_path = 3;
  int32 line = 4;
  int32 column = 5;
  repeated Variable locals = 6;
}

message Variable {
  string name = 1;
  string value = 2;
  string type = 3;
  repeated Variable children = 4;
}

message DebugEvent {
  string event_type = 1;  // breakpoint_hit, step_complete, exception, etc.
  string session_id = 2;
  int64 timestamp = 3;
  oneof payload {
    BreakpointHit breakpoint_hit = 4;
    StepComplete step_complete = 5;
    ExceptionInfo exception = 6;
    OutputEvent output = 7;
  }
}

message BreakpointHit {
  string breakpoint_id = 1;
  StackTrace stack = 2;
  map<string, string> variables = 3;
}

message TelemetryEvent {
  string source = 1;
  string event_type = 2;
  int64 timestamp = 3;
  string correlation_id = 4;
  bytes payload = 5;
}
```

## 6.0 Fractal Log Integration

```elixir
# lib/indrajaal/debugger/fractal_integration.ex
defmodule Indrajaal.Debugger.FractalIntegration do
  @moduledoc """
  Integrates debugger events with 5-level fractal logging system.

  Maps debugger events to appropriate fractal levels:
  - L1: Individual step/expression evaluation
  - L2: Breakpoint hits, variable changes
  - L3: Session lifecycle
  - L4: Cross-language debugging
  - L5: System-wide debug state

  STAMP: SC-DEBUG-003
  AOR: AOR-DEBUG-005
  """

  alias Indrajaal.Observability.Fractal.{Decorator, ContentRouter}
  alias Indrajaal.Debugger.TelemetryBus

  @debug_session_key :debugger_session_id

  def attach do
    :telemetry.attach_many(
      "fractal-debugger",
      [
        [:debugger, :session, :start],
        [:debugger, :session, :stop],
        [:debugger, :breakpoint, :set],
        [:debugger, :breakpoint, :hit],
        [:debugger, :step, :complete],
        [:debugger, :variable, :inspected],
        [:debugger, :exception, :caught]
      ],
      &handle_event/4,
      nil
    )
  end

  defp handle_event([:debugger, :session, :start], _measurements, metadata, _config) do
    # Store session ID for correlation
    Process.put(@debug_session_key, metadata.session_id)

    Decorator.log(:L3, :debugger, "Debug session started", %{
      session_id: metadata.session_id,
      language: metadata.language,
      project: metadata.project_root
    })
  end

  defp handle_event([:debugger, :breakpoint, :hit], measurements, metadata, _config) do
    session_id = Process.get(@debug_session_key)

    Decorator.log(:L2, :debugger, "Breakpoint hit", %{
      session_id: session_id,
      breakpoint_id: metadata.breakpoint_id,
      file: metadata.file,
      line: metadata.line,
      hit_count: metadata.hit_count,
      duration_us: measurements.duration
    })

    # Also emit to telemetry bus for Zenoh
    TelemetryBus.emit_debugger(:breakpoint_hit, %{
      session_id: session_id,
      breakpoint: metadata,
      stack: metadata.stack
    })
  end

  defp handle_event([:debugger, :step, :complete], measurements, metadata, _config) do
    session_id = Process.get(@debug_session_key)

    Decorator.log(:L1, :debugger, "Step complete", %{
      session_id: session_id,
      step_type: metadata.step_type,
      new_line: metadata.line,
      duration_us: measurements.duration
    })
  end

  defp handle_event([:debugger, :variable, :inspected], _measurements, metadata, _config) do
    session_id = Process.get(@debug_session_key)

    Decorator.log(:L1, :debugger, "Variable inspected", %{
      session_id: session_id,
      variable: metadata.name,
      type: metadata.type,
      # Don't log value for security
      has_children: metadata.has_children
    })
  end

  defp handle_event([:debugger, :exception, :caught], measurements, metadata, _config) do
    session_id = Process.get(@debug_session_key)

    Decorator.log(:L2, :debugger, "Exception caught in debugger", %{
      session_id: session_id,
      exception_type: metadata.type,
      message: metadata.message,
      stack: metadata.stack,
      duration_us: measurements.duration
    })
  end
end
```

## 7.0 Launch Configuration

### 7.1 VSCode/Claude Code Launch Config

```json
// .vscode/launch.json (also used by Claude Code)
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Elixir: Debug Phoenix",
      "type": "mix_task",
      "request": "launch",
      "task": "phx.server",
      "projectDir": "${workspaceFolder}",
      "env": {
        "DEBUG_SESSION_ID": "${env:DEBUG_SESSION_ID}",
        "ZENOH_TELEMETRY": "true",
        "FRACTAL_LOG_LEVEL": "L1"
      },
      "preLaunchTask": "start-zenoh",
      "postDebugTask": "stop-zenoh"
    },
    {
      "name": "Elixir: Debug Tests",
      "type": "mix_task",
      "request": "launch",
      "task": "test",
      "taskArgs": ["--trace"],
      "projectDir": "${workspaceFolder}",
      "env": {
        "MIX_ENV": "test",
        "DEBUG_SESSION_ID": "${env:DEBUG_SESSION_ID}",
        "ZENOH_TELEMETRY": "true"
      }
    },
    {
      "name": "F#: Debug CEPAF",
      "type": "coreclr",
      "request": "launch",
      "program": "${workspaceFolder}/lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll",
      "args": ["--debug", "--telemetry"],
      "cwd": "${workspaceFolder}/lib/cepaf",
      "env": {
        "DEBUG_SESSION_ID": "${env:DEBUG_SESSION_ID}",
        "ZENOH_TELEMETRY": "true",
        "DOTNET_ENVIRONMENT": "Development"
      }
    },
    {
      "name": "F#: Debug Cockpit",
      "type": "coreclr",
      "request": "launch",
      "program": "${workspaceFolder}/lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll",
      "args": ["Prajna", "--debug"],
      "cwd": "${workspaceFolder}/lib/cepaf",
      "env": {
        "DEBUG_SESSION_ID": "${env:DEBUG_SESSION_ID}",
        "ZENOH_TELEMETRY": "true"
      }
    },
    {
      "name": "Multi-Language: Full Stack",
      "type": "compound",
      "configurations": [
        "Elixir: Debug Phoenix",
        "F#: Debug CEPAF"
      ]
    }
  ]
}
```

### 7.2 Claude Code DAP Configuration

```json
// .claude/plugins/debugger/.dap.json
{
  "elixir": {
    "adapter": "elixir-ls",
    "command": "/home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/elixir-ls-debugger",
    "args": [],
    "configuration": {
      "projectDir": ".",
      "mixEnv": "dev",
      "requireFiles": ["test/test_helper.exs"],
      "startApps": true,
      "env": {
        "ZENOH_TELEMETRY": "true"
      }
    },
    "breakpoints": {
      "exceptionBreakpoints": ["all", "runtime", "debugger"]
    }
  },
  "fsharp": {
    "adapter": "netcoredbg",
    "command": "/home/an/dev/ver/intelitor-v5.2/.devenv/profile/bin/netcoredbg",
    "args": ["--interpreter=vscode"],
    "configuration": {
      "program": "${workspaceFolder}/lib/cepaf/src/Cepaf/bin/Debug/net10.0/Cepaf.dll",
      "cwd": "${workspaceFolder}/lib/cepaf",
      "env": {
        "ZENOH_TELEMETRY": "true"
      }
    }
  },
  "telemetry": {
    "zenoh": {
      "enabled": true,
      "prefix": "indrajaal/debug",
      "publishInterval": 10
    },
    "fractal": {
      "enabled": true,
      "minLevel": "L1"
    },
    "grpc": {
      "enabled": true,
      "endpoint": "localhost:50051"
    }
  }
}
```

## 8.0 Closed-Loop Data Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CLOSED LOOP SEQUENCE                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. DEVELOPER ACTION                                                        │
│     User sets breakpoint in VSCode/Claude Code                              │
│                          │                                                  │
│                          ▼                                                  │
│  2. DAP REQUEST                                                             │
│     Debugger adapter receives setBreakpoint request                         │
│                          │                                                  │
│                          ▼                                                  │
│  3. TELEMETRY EMIT                                                          │
│     TelemetryBus.emit(:debugger, :breakpoint_set, payload)                  │
│                          │                                                  │
│          ┌───────────────┼───────────────┐                                  │
│          ▼               ▼               ▼                                  │
│  4a. ZENOH PUBLISH   4b. FRACTAL LOG  4c. gRPC NOTIFY                       │
│     indrajaal/debug/    L2 logging      DebuggerService.                    │
│     breakpoint/...      with session    StreamEvents()                      │
│                          │               │                                  │
│          └───────────────┼───────────────┘                                  │
│                          ▼                                                  │
│  5. DASHBOARD UPDATE                                                        │
│     Prajna LiveView receives PubSub, updates UI                             │
│     CEPAF Cockpit receives Zenoh, updates TUI                               │
│                          │                                                  │
│                          ▼                                                  │
│  6. BREAKPOINT HIT                                                          │
│     Execution reaches breakpoint                                            │
│                          │                                                  │
│                          ▼                                                  │
│  7. STACK/VARIABLE CAPTURE                                                  │
│     Debugger captures state, emits to telemetry                             │
│                          │                                                  │
│          ┌───────────────┼───────────────┐                                  │
│          ▼               ▼               ▼                                  │
│  8a. ZENOH STREAM    8b. OTEL SPAN    8c. DUCKDB PERSIST                    │
│     indrajaal/debug/    trace.span      Debug session                       │
│     stack/...           with context    history                             │
│                          │                                                  │
│                          ▼                                                  │
│  9. LSP CORRELATION                                                         │
│     LSP provides hover/definition at current line                           │
│     Diagnostics updated with debug context                                  │
│                          │                                                  │
│                          ▼                                                  │
│  10. FEEDBACK TO USER                                                       │
│      Stack trace, variables, LSP info displayed                             │
│      Developer makes decision, cycle repeats                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 9.0 FMEA Analysis

| Failure Mode | Severity | Occurrence | Detection | RPN | Mitigation |
|--------------|----------|------------|-----------|-----|------------|
| Zenoh publish timeout | 6 | 3 | 8 | 144 | Async publish, buffer |
| Debugger crash | 8 | 2 | 7 | 112 | Supervisor restart, state recovery |
| LSP unresponsive | 5 | 4 | 6 | 120 | Timeout, fallback |
| gRPC connection lost | 6 | 3 | 5 | 90 | Reconnect, circuit breaker |
| Telemetry bus overflow | 7 | 2 | 6 | 84 | Backpressure, sampling |
| Breakpoint desync | 6 | 3 | 4 | 72 | Versioned state, reconciliation |

## 10.0 Test Coverage

| Test Category | Count | Focus |
|---------------|-------|-------|
| Unit: DAP Protocol | 25 | Message serialization |
| Unit: Telemetry Bus | 20 | Event buffering, routing |
| Property: Event ordering | 10 | FIFO guarantee |
| Integration: Elixir+Zenoh | 15 | End-to-end flow |
| Integration: F#+gRPC | 15 | Cross-language debug |
| E2E: Full stack debug | 5 | Complete workflow |
| **Total** | **90** | |
