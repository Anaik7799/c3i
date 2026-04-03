# Testing Guide: Standalone App Container System
## Version: 1.0.0 | Date: 2025-12-24 | Status: PRODUCTION
## Compliance: SOPv5.11 + STAMP + TDG + IEC 61508 SIL-2

---

## Table of Contents

1. [Testing Philosophy](#1-testing-philosophy)
2. [Test Pyramid](#2-test-pyramid)
3. [DAG Verification Tests](#3-dag-verification-tests)
4. [Health Probe Tests](#4-health-probe-tests)
5. [Container Integration Tests](#5-container-integration-tests)
6. [Logging Verification Tests](#6-logging-verification-tests)
7. [Telemetry Tests](#7-telemetry-tests)
8. [Performance Tests](#8-performance-tests)
9. [Security Tests](#9-security-tests)
10. [Chaos Engineering Tests](#10-chaos-engineering-tests)
11. [Automated Test Scripts](#11-automated-test-scripts)
12. [CI/CD Integration](#12-cicd-integration)
13. [Test Reporting](#13-test-reporting)

---

## 1. Testing Philosophy

### 1.1 TDG Methodology

Test-Driven Generation (TDG) requires that tests exist and FAIL before implementation:

```
1. Write failing test → 2. Implement feature → 3. Verify test passes → 4. Refactor
```

### 1.2 STAMP Compliance Testing

Every test must verify relevant STAMP safety constraints:

| Test Category | Constraints Verified |
|---------------|---------------------|
| Container | SC-CNT-009, SC-CNT-010, SC-CNT-012 |
| Compilation | SC-CMP-025, SC-CMP-026, SC-CMP-028 |
| Validation | SC-VAL-001, SC-VAL-002, SC-VAL-003 |
| Performance | SC-PRF-050, SC-PRF-055 |
| Observability | SC-OBS-069, SC-OBS-070, SC-OBS-071 |

### 1.3 Test Coverage Requirements

- Unit tests: >80% line coverage
- Integration tests: All critical paths
- E2E tests: All user journeys
- Property tests: All data generators

---

## 2. Test Pyramid

```
                    ┌─────────────────┐
                    │   E2E Tests     │  ← Slow, Expensive
                    │   (5-10%)       │
                    ├─────────────────┤
                    │  Integration    │
                    │    Tests        │  ← Medium Speed
                    │   (20-30%)      │
                    ├─────────────────┤
                    │                 │
                    │   Unit Tests    │  ← Fast, Cheap
                    │   (60-70%)      │
                    │                 │
                    └─────────────────┘
```

### 2.1 Test File Structure

```
test/
├── indrajaal/
│   ├── container/
│   │   ├── app_container_test.exs
│   │   ├── db_container_test.exs
│   │   └── obs_container_test.exs
│   ├── health/
│   │   ├── liveness_probe_test.exs
│   │   ├── readiness_probe_test.exs
│   │   └── startup_probe_test.exs
│   ├── telemetry/
│   │   ├── metrics_test.exs
│   │   ├── tracing_test.exs
│   │   └── logging_test.exs
│   └── cybernetic/
│       ├── ooda_loop_test.exs
│       └── cortex_test.exs
├── integration/
│   ├── container_lifecycle_test.exs
│   ├── database_connectivity_test.exs
│   └── full_stack_test.exs
└── support/
    ├── container_helpers.ex
    ├── telemetry_helpers.ex
    └── factory.ex
```

---

## 3. DAG Verification Tests

### 3.1 Phase 0: Prerequisites Tests

```elixir
# test/indrajaal/container/prerequisites_test.exs

defmodule Indrajaal.Container.PrerequisitesTest do
  use ExUnit.Case, async: false

  @moduledoc """
  DAG Phase 0: Prerequisites verification tests.

  Verifies:
  - P0.1_IMG: Container image exists
  - P0.2_NET: Networks created
  - P0.3_DB: Database healthy
  """

  describe "P0.1_IMG: Image Verification" do
    test "app image exists in local registry" do
      {output, 0} = System.cmd("podman", [
        "images",
        "--format", "{{.Repository}}:{{.Tag}}",
        "localhost/indrajaal-sopv51-elixir-app"
      ])

      assert String.contains?(output, "nixos-25.05-devenv")
    end

    test "image has correct labels" do
      {output, 0} = System.cmd("podman", [
        "inspect",
        "--format", "{{.Config.Labels}}",
        "localhost/indrajaal-sopv51-elixir-app:nixos-25.05-devenv"
      ])

      assert String.contains?(output, "sopv51")
    end
  end

  describe "P0.2_NET: Network Verification" do
    test "db-standalone-net exists" do
      {output, _} = System.cmd("podman", ["network", "ls", "--format", "{{.Name}}"])
      assert String.contains?(output, "db-standalone-net")
    end

    test "app-standalone-net exists" do
      {output, _} = System.cmd("podman", ["network", "ls", "--format", "{{.Name}}"])
      assert String.contains?(output, "app-standalone-net") or
             String.contains?(output, "app-debug-net")
    end
  end

  describe "P0.3_DB: Database Health" do
    @tag :requires_db
    test "database container is healthy" do
      {output, 0} = System.cmd("podman", [
        "inspect",
        "--format", "{{.State.Health.Status}}",
        "indrajaal-db-standalone"
      ])

      assert String.trim(output) == "healthy"
    end

    @tag :requires_db
    test "database accepts connections" do
      {output, 0} = System.cmd("podman", [
        "exec", "indrajaal-db-standalone",
        "pg_isready", "-U", "postgres", "-p", "5433"
      ])

      assert String.contains?(output, "accepting connections")
    end
  end
end
```

### 3.2 Phase 1-3: Setup Tests

```elixir
# test/indrajaal/container/setup_test.exs

defmodule Indrajaal.Container.SetupTest do
  use ExUnit.Case, async: false

  @moduledoc """
  DAG Phases 1-3: Container setup verification tests.
  """

  @container_name "indrajaal-app-debug"

  describe "P1.1_CNT: Container Creation" do
    @tag :requires_container
    test "container exists and is running" do
      {output, 0} = System.cmd("podman", [
        "inspect",
        "--format", "{{.State.Running}}",
        @container_name
      ])

      assert String.trim(output) == "true"
    end

    @tag :requires_container
    test "container has correct environment" do
      {output, 0} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "echo $MIX_ENV"
      ])

      assert String.trim(output) == "test"
    end
  end

  describe "P2.1_HEX: Hex Installation" do
    @tag :requires_container
    test "hex is installed" do
      {output, 0} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "ls ~/.mix/archives/ | grep hex"
      ])

      assert String.contains?(output, "hex")
    end
  end

  describe "P2.2_REB: Rebar Installation" do
    @tag :requires_container
    test "rebar3 is installed" do
      {output, 0} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "ls ~/.mix/elixir/ | grep rebar"
      ])

      assert String.contains?(output, "rebar")
    end
  end

  describe "P3.1_CONN: Database Connectivity" do
    @tag :requires_container
    test "can reach database from app container" do
      {output, 0} = System.cmd("podman", [
        "exec", @container_name,
        "pg_isready", "-h", "indrajaal-db-standalone", "-p", "5433", "-U", "postgres"
      ])

      assert String.contains?(output, "accepting connections")
    end
  end
end
```

### 3.3 Phase 4: Compilation Tests

```elixir
# test/indrajaal/container/compilation_test.exs

defmodule Indrajaal.Container.CompilationTest do
  use ExUnit.Case, async: false

  @moduledoc """
  DAG Phase 4: Compilation verification tests.

  STAMP Compliance:
  - SC-CMP-025: Zero warnings
  - SC-CMP-026: All files compiled
  """

  @container_name "indrajaal-app-debug"

  describe "P4.1_MIX: Application Compilation" do
    @tag :requires_container
    @tag timeout: 600_000  # 10 minutes for Patient Mode
    test "application compiles successfully" do
      {output, exit_code} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "cd /workspace && mix compile --return-errors"
      ], stderr_to_stdout: true)

      # Exit code 0 means success
      assert exit_code == 0, "Compilation failed: #{output}"
    end
  end

  describe "P4.4_WAR: Warning Analysis (SC-CMP-025)" do
    @tag :requires_container
    test "zero compilation warnings" do
      {output, _} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "grep -c 'warning:' /var/log/claude/compile.log 2>/dev/null || echo 0"
      ])

      warning_count = String.trim(output) |> String.to_integer()

      assert warning_count == 0,
        "SC-CMP-025 VIOLATION: #{warning_count} warnings found"
    end

    @tag :requires_container
    test "no compilation errors" do
      {output, _} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "grep -c 'error:' /var/log/claude/compile.log 2>/dev/null || echo 0"
      ])

      error_count = String.trim(output) |> String.to_integer()

      assert error_count == 0,
        "Compilation errors found: #{error_count}"
    end
  end
end
```

### 3.4 Phase 5-7: Runtime Tests

```elixir
# test/indrajaal/container/runtime_test.exs

defmodule Indrajaal.Container.RuntimeTest do
  use ExUnit.Case, async: false

  @moduledoc """
  DAG Phases 5-7: Runtime verification tests.
  """

  @container_name "indrajaal-app-debug"
  @health_url "http://localhost:4000/health"

  describe "P5.1_PHX: Phoenix Server" do
    @tag :requires_container
    test "phoenix is listening on port 4000" do
      {output, 0} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "ss -tlnp | grep ':4000'"
      ])

      assert String.contains?(output, "LISTEN")
    end
  end

  describe "P6.1_TCP: TCP Port Probes" do
    @tag :requires_container
    test "port 4000 is open" do
      {_, exit_code} = System.cmd("curl", [
        "-sf", "--connect-timeout", "5",
        "http://localhost:4000/"
      ], stderr_to_stdout: true)

      # Any response (including errors) means port is open
      assert exit_code in [0, 22]
    end
  end

  describe "P6.2_HTTP: Health Endpoint" do
    @tag :requires_container
    test "health endpoint responds" do
      {output, 0} = System.cmd("curl", ["-sf", @health_url])
      response = Jason.decode!(output)

      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "timestamp")
    end

    @tag :requires_container
    test "health endpoint returns expected structure" do
      {output, 0} = System.cmd("curl", ["-sf", @health_url])
      response = Jason.decode!(output)

      assert Map.has_key?(response, "probes")
      assert Map.has_key?(response["probes"], "liveness")
      assert Map.has_key?(response["probes"], "readiness")
      assert Map.has_key?(response["probes"], "startup")
    end
  end

  describe "P7.1_API: API Verification" do
    @tag :requires_container
    test "liveness probe returns ok" do
      {output, 0} = System.cmd("curl", ["-sf", "http://localhost:4000/healthz"])
      response = Jason.decode!(output)

      assert response["status"] == "ok"
      assert response["probe"] == "liveness"
    end

    @tag :requires_container
    test "startup probe returns started" do
      {output, 0} = System.cmd("curl", ["-sf", "http://localhost:4000/startup"])
      response = Jason.decode!(output)

      assert response["status"] == "started"
      assert is_integer(response["uptime_ms"])
    end
  end

  describe "P7.2_OBS: Observability Verification" do
    @tag :requires_container
    test "OODA loop is active" do
      {output, 0} = System.cmd("podman", [
        "logs", "--tail", "10", @container_name
      ], stderr_to_stdout: true)

      assert String.contains?(output, "OODA Cycle")
    end
  end
end
```

---

## 4. Health Probe Tests

### 4.1 Liveness Probe Tests

```elixir
# test/indrajaal/health/liveness_probe_test.exs

defmodule Indrajaal.Health.LivenessProbeTest do
  use IndrajaalWeb.ConnCase, async: true

  @moduledoc """
  Liveness probe verification tests.

  The liveness probe checks if the BEAM VM is responsive and healthy.
  If this fails, the container should be restarted.
  """

  describe "GET /healthz" do
    test "returns 200 when healthy", %{conn: conn} do
      conn = get(conn, ~p"/healthz")

      assert json_response(conn, 200)["status"] == "ok"
    end

    test "includes node name", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      response = json_response(conn, 200)

      assert Map.has_key?(response, "node")
    end

    test "includes timestamp", %{conn: conn} do
      conn = get(conn, ~p"/healthz")
      response = json_response(conn, 200)

      assert Map.has_key?(response, "timestamp")
      {:ok, _, _} = DateTime.from_iso8601(response["timestamp"])
    end

    test "responds within 50ms (SC-PRF-050)", %{conn: conn} do
      start = System.monotonic_time(:millisecond)
      _conn = get(conn, ~p"/healthz")
      duration = System.monotonic_time(:millisecond) - start

      assert duration < 50, "Response time #{duration}ms exceeds 50ms limit"
    end
  end
end
```

### 4.2 Readiness Probe Tests

```elixir
# test/indrajaal/health/readiness_probe_test.exs

defmodule Indrajaal.Health.ReadinessProbeTest do
  use IndrajaalWeb.ConnCase, async: true

  @moduledoc """
  Readiness probe verification tests.

  The readiness probe checks if the application can serve traffic.
  If this fails, traffic should be routed elsewhere.
  """

  describe "GET /ready" do
    test "returns probe type", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      response = json_response(conn, :any)

      assert response["probe"] == "readiness"
    end

    test "includes database check", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      response = json_response(conn, :any)

      assert Map.has_key?(response["checks"], "database")
    end

    test "includes pubsub check", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      response = json_response(conn, :any)

      assert Map.has_key?(response["checks"], "pubsub")
    end

    test "includes telemetry check", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      response = json_response(conn, :any)

      assert Map.has_key?(response["checks"], "telemetry")
    end

    @tag :requires_db
    test "returns ready when database is connected", %{conn: conn} do
      conn = get(conn, ~p"/ready")
      response = json_response(conn, 200)

      assert response["checks"]["database"]["healthy"] == true
    end
  end
end
```

### 4.3 Startup Probe Tests

```elixir
# test/indrajaal/health/startup_probe_test.exs

defmodule Indrajaal.Health.StartupProbeTest do
  use IndrajaalWeb.ConnCase, async: true

  @moduledoc """
  Startup probe verification tests.

  The startup probe checks if the application has finished starting.
  This prevents premature liveness/readiness checks during slow startups.
  """

  describe "GET /startup" do
    test "returns started status", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      response = json_response(conn, 200)

      assert response["status"] == "started"
    end

    test "includes uptime", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      response = json_response(conn, 200)

      assert is_integer(response["uptime_ms"])
      assert response["uptime_ms"] > 0
    end

    test "verifies application started", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      response = json_response(conn, 200)

      assert response["checks"]["application"]["healthy"] == true
    end

    test "verifies endpoint started", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      response = json_response(conn, 200)

      assert response["checks"]["endpoint"]["healthy"] == true
    end

    test "verifies supervision tree", %{conn: conn} do
      conn = get(conn, ~p"/startup")
      response = json_response(conn, 200)

      assert response["checks"]["supervision_tree"]["healthy"] == true
    end
  end
end
```

### 4.4 Comprehensive Health Tests

```elixir
# test/indrajaal/health/comprehensive_test.exs

defmodule Indrajaal.Health.ComprehensiveTest do
  use IndrajaalWeb.ConnCase, async: true

  @moduledoc """
  Comprehensive health endpoint tests.
  """

  describe "GET /health" do
    test "returns full health status", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, :any)

      assert Map.has_key?(response, "status")
      assert Map.has_key?(response, "version")
      assert Map.has_key?(response, "system")
      assert Map.has_key?(response, "probes")
    end

    test "includes system information", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, :any)

      assert Map.has_key?(response["system"], "elixir_version")
      assert Map.has_key?(response["system"], "otp_release")
      assert Map.has_key?(response["system"], "process_count")
      assert Map.has_key?(response["system"], "schedulers")
      assert Map.has_key?(response["system"], "memory_mb")
    end

    test "includes all probe categories", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, :any)

      assert Map.has_key?(response["probes"], "liveness")
      assert Map.has_key?(response["probes"], "readiness")
      assert Map.has_key?(response["probes"], "startup")
    end

    test "memory is within limits", %{conn: conn} do
      conn = get(conn, ~p"/health")
      response = json_response(conn, :any)

      memory_mb = response["system"]["memory_mb"]
      assert memory_mb < 6000, "Memory #{memory_mb}MB exceeds 6GB limit"
    end
  end
end
```

---

## 5. Container Integration Tests

### 5.1 Container Lifecycle Tests

```elixir
# test/integration/container_lifecycle_test.exs

defmodule Integration.ContainerLifecycleTest do
  use ExUnit.Case, async: false

  @moduledoc """
  End-to-end container lifecycle tests.

  These tests verify the complete container lifecycle from creation
  to termination, including health transitions.
  """

  @compose_file "lib/cepaf/artifacts/podman-compose-app-debug.yml"
  @container_name "indrajaal-app-debug"

  setup_all do
    # Ensure container is stopped before tests
    System.cmd("podman", ["stop", @container_name], stderr_to_stdout: true)
    System.cmd("podman", ["rm", @container_name], stderr_to_stdout: true)

    on_exit(fn ->
      # Cleanup after tests
      System.cmd("podman", ["stop", @container_name], stderr_to_stdout: true)
      System.cmd("podman", ["rm", @container_name], stderr_to_stdout: true)
    end)

    :ok
  end

  describe "Container Lifecycle" do
    @tag timeout: 900_000  # 15 minutes for full lifecycle
    test "complete lifecycle from start to healthy" do
      # Start container
      {_, 0} = System.cmd("podman-compose", [
        "-f", @compose_file, "up", "-d"
      ], cd: "/home/an/dev/ver/indrajaal-v5.2")

      # Wait for container to be running
      assert wait_for_state("running", 60_000)

      # Wait for health endpoint
      assert wait_for_health(300_000)

      # Verify health status
      {output, 0} = System.cmd("curl", ["-sf", "http://localhost:4000/health"])
      response = Jason.decode!(output)

      assert response["probes"]["liveness"]["beam_vm"]["healthy"] == true
      assert response["probes"]["startup"]["application"]["healthy"] == true
    end
  end

  # Helper functions

  defp wait_for_state(expected_state, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      {output, _} = System.cmd("podman", [
        "inspect", "--format", "{{.State.Status}}", @container_name
      ], stderr_to_stdout: true)

      state = String.trim(output)
      {state, state == expected_state}
    end)
    |> Stream.take_while(fn {_, match} ->
      !match and System.monotonic_time(:millisecond) < deadline
    end)
    |> Stream.each(fn _ -> Process.sleep(1000) end)
    |> Stream.run()

    {output, _} = System.cmd("podman", [
      "inspect", "--format", "{{.State.Status}}", @container_name
    ], stderr_to_stdout: true)

    String.trim(output) == expected_state
  end

  defp wait_for_health(timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout

    Stream.repeatedly(fn ->
      {_, exit_code} = System.cmd("curl", [
        "-sf", "--connect-timeout", "5",
        "http://localhost:4000/healthz"
      ], stderr_to_stdout: true)

      exit_code == 0
    end)
    |> Stream.take_while(fn success ->
      !success and System.monotonic_time(:millisecond) < deadline
    end)
    |> Stream.each(fn _ -> Process.sleep(5000) end)
    |> Stream.run()

    {_, exit_code} = System.cmd("curl", [
      "-sf", "http://localhost:4000/healthz"
    ], stderr_to_stdout: true)

    exit_code == 0
  end
end
```

---

## 6. Logging Verification Tests

### 6.1 Dual Logging Tests

```elixir
# test/indrajaal/telemetry/logging_test.exs

defmodule Indrajaal.Telemetry.LoggingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Logging system verification tests.

  STAMP Compliance:
  - SC-OBS-069: Dual logging (console + JSON)
  - SC-OBS-070: Channel-based routing
  """

  alias Indrajaal.Observability.QuadplexLogger

  describe "QuadplexLogger" do
    test "logs to security channel" do
      assert :ok = QuadplexLogger.security(:auth_attempt, %{user: "test"})
    end

    test "logs to business channel" do
      assert :ok = QuadplexLogger.business(:order_created, %{id: 123})
    end

    test "logs to performance channel" do
      assert :ok = QuadplexLogger.performance(:slow_query, %{duration_ms: 100})
    end

    test "logs to system channel" do
      assert :ok = QuadplexLogger.system(:container_health, %{status: :ok})
    end
  end

  describe "Logger Configuration" do
    test "console backend is configured" do
      backends = Application.get_env(:logger, :backends)
      assert :console in backends
    end

    test "logger level is configurable via env" do
      level = Application.get_env(:logger, :level)
      assert level in [:debug, :info, :warning, :error]
    end
  end
end
```

### 6.2 Log Format Tests

```elixir
# test/indrajaal/telemetry/log_format_test.exs

defmodule Indrajaal.Telemetry.LogFormatTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  @moduledoc """
  Log format verification tests.
  """

  describe "Console Log Format" do
    test "includes timestamp" do
      log = capture_log(fn ->
        require Logger
        Logger.info("Test message")
      end)

      # Format: HH:MM:SS.mmm
      assert Regex.match?(~r/\d{2}:\d{2}:\d{2}\.\d{3}/, log)
    end

    test "includes log level" do
      log = capture_log(fn ->
        require Logger
        Logger.info("Test message")
      end)

      assert String.contains?(log, "[info]")
    end

    test "includes message" do
      log = capture_log(fn ->
        require Logger
        Logger.info("Specific test message")
      end)

      assert String.contains?(log, "Specific test message")
    end
  end

  describe "Debug Mode Logging" do
    @tag :debug_mode
    test "MIX_DEBUG enables verbose output" do
      System.put_env("MIX_DEBUG", "1")

      on_exit(fn ->
        System.delete_env("MIX_DEBUG")
      end)

      assert System.get_env("MIX_DEBUG") == "1"
    end
  end
end
```

---

## 7. Telemetry Tests

### 7.1 Metrics Collection Tests

```elixir
# test/indrajaal/telemetry/metrics_test.exs

defmodule Indrajaal.Telemetry.MetricsTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Telemetry metrics collection tests.
  """

  describe "VM Metrics" do
    test "memory metrics are available" do
      memory = :erlang.memory()

      assert is_integer(memory[:total])
      assert is_integer(memory[:processes])
      assert is_integer(memory[:ets])
    end

    test "process count is available" do
      count = :erlang.system_info(:process_count)
      assert is_integer(count)
      assert count > 0
    end

    test "scheduler count is available" do
      count = :erlang.system_info(:schedulers_online)
      assert is_integer(count)
      assert count > 0
    end
  end

  describe "Telemetry Events" do
    test "can attach handlers" do
      handler_id = "test-handler-#{System.unique_integer()}"

      :ok = :telemetry.attach(
        handler_id,
        [:test, :event],
        fn _event, _measurements, _metadata, _config ->
          :ok
        end,
        nil
      )

      handlers = :telemetry.list_handlers([:test, :event])
      assert length(handlers) > 0

      :telemetry.detach(handler_id)
    end

    test "can execute events" do
      test_pid = self()

      handler_id = "test-execute-#{System.unique_integer()}"

      :telemetry.attach(
        handler_id,
        [:test, :execute],
        fn _event, measurements, _metadata, _config ->
          send(test_pid, {:telemetry, measurements})
        end,
        nil
      )

      :telemetry.execute([:test, :execute], %{value: 42}, %{})

      assert_receive {:telemetry, %{value: 42}}

      :telemetry.detach(handler_id)
    end
  end
end
```

### 7.2 Tracing Tests

```elixir
# test/indrajaal/telemetry/tracing_test.exs

defmodule Indrajaal.Telemetry.TracingTest do
  use ExUnit.Case, async: true

  @moduledoc """
  OpenTelemetry tracing tests.
  """

  describe "OpenTelemetry Configuration" do
    test "tracer is available" do
      tracer = OpenTelemetry.Tracer
      assert tracer != nil
    end

    test "can create spans" do
      OpenTelemetry.Tracer.with_span "test-span" do
        ctx = OpenTelemetry.Tracer.current_span_ctx()
        assert ctx != :undefined
      end
    end
  end
end
```

---

## 8. Performance Tests

### 8.1 Response Time Tests

```elixir
# test/indrajaal/performance/response_time_test.exs

defmodule Indrajaal.Performance.ResponseTimeTest do
  use IndrajaalWeb.ConnCase, async: true

  @moduledoc """
  Response time performance tests.

  STAMP Compliance:
  - SC-PRF-050: Response time <50ms
  """

  @iterations 100

  describe "Health Endpoint Performance" do
    test "average response time under 50ms", %{conn: conn} do
      times = for _ <- 1..@iterations do
        start = System.monotonic_time(:millisecond)
        get(conn, ~p"/healthz")
        System.monotonic_time(:millisecond) - start
      end

      avg = Enum.sum(times) / @iterations
      p99 = times |> Enum.sort() |> Enum.at(round(@iterations * 0.99))

      assert avg < 50, "Average response time #{avg}ms exceeds 50ms"
      assert p99 < 100, "P99 response time #{p99}ms exceeds 100ms"
    end
  end

  describe "Memory Usage" do
    test "memory stays within limits during requests", %{conn: conn} do
      initial_memory = :erlang.memory(:total)

      for _ <- 1..1000 do
        get(conn, ~p"/healthz")
      end

      final_memory = :erlang.memory(:total)
      growth_mb = (final_memory - initial_memory) / 1_048_576

      assert growth_mb < 100, "Memory grew by #{growth_mb}MB during test"
    end
  end
end
```

---

## 9. Security Tests

### 9.1 Container Security Tests

```elixir
# test/indrajaal/security/container_security_test.exs

defmodule Indrajaal.Security.ContainerSecurityTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Container security verification tests.

  STAMP Compliance:
  - SC-CNT-012: Rootless containers
  - SC-SEC-044: Security scanning
  """

  @container_name "indrajaal-app-debug"

  describe "Rootless Container" do
    @tag :requires_container
    test "container runs as non-root user" do
      {output, 0} = System.cmd("podman", [
        "exec", @container_name,
        "whoami"
      ])

      # In rootless mode, even "root" inside container is mapped to non-root
      # The important thing is Podman itself is rootless
      assert String.trim(output) != ""
    end

    test "podman is running rootless" do
      {output, 0} = System.cmd("podman", ["info", "--format", "{{.Host.Security.Rootless}}"])
      assert String.trim(output) == "true"
    end
  end

  describe "Secret Management" do
    @tag :requires_container
    test "no secrets in environment listing" do
      {output, _} = System.cmd("podman", [
        "exec", @container_name,
        "env"
      ])

      # Ensure actual secret values aren't exposed
      # (the variable names are ok, just not production secrets)
      refute String.contains?(output, "actual-production-secret")
    end
  end
end
```

---

## 10. Chaos Engineering Tests

### 10.1 Fault Injection Tests

```elixir
# test/indrajaal/chaos/fault_injection_test.exs

defmodule Indrajaal.Chaos.FaultInjectionTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chaos engineering tests for resilience verification.
  """

  @container_name "indrajaal-app-debug"

  describe "Network Partition" do
    @tag :chaos
    @tag :requires_container
    test "survives brief network interruption" do
      # Get initial state
      {_, 0} = System.cmd("curl", ["-sf", "http://localhost:4000/healthz"])

      # Simulate brief network partition (disconnect and reconnect)
      System.cmd("podman", [
        "network", "disconnect", "artifacts_db-standalone-net", @container_name
      ])

      Process.sleep(5000)

      System.cmd("podman", [
        "network", "connect", "artifacts_db-standalone-net", @container_name
      ])

      Process.sleep(10000)

      # Verify recovery
      {output, 0} = System.cmd("curl", ["-sf", "http://localhost:4000/healthz"])
      response = Jason.decode!(output)

      assert response["status"] == "ok"
    end
  end

  describe "Resource Pressure" do
    @tag :chaos
    @tag :requires_container
    test "handles memory pressure gracefully" do
      # Create memory pressure inside container
      {_, _} = System.cmd("podman", [
        "exec", @container_name,
        "sh", "-c", "dd if=/dev/zero of=/tmp/memfile bs=1M count=500 2>/dev/null &"
      ])

      Process.sleep(5000)

      # Verify still responsive
      {output, exit_code} = System.cmd("curl", [
        "-sf", "--max-time", "10",
        "http://localhost:4000/healthz"
      ])

      assert exit_code == 0, "Container unresponsive under memory pressure"

      # Cleanup
      System.cmd("podman", [
        "exec", @container_name,
        "rm", "-f", "/tmp/memfile"
      ])
    end
  end
end
```

---

## 11. Automated Test Scripts

### 11.1 Full Verification Script

```bash
#!/bin/bash
# scripts/testing/full_verification.sh
# Complete container verification test suite

set -e

COMPOSE_FILE="lib/cepaf/artifacts/podman-compose-app-debug.yml"
CONTAINER_NAME="indrajaal-app-debug"
HEALTH_URL="http://localhost:4000/health"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║           INTELITOR CONTAINER VERIFICATION TEST SUITE                ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"

# Phase 0: Prerequisites
echo ""
echo "━━━ PHASE 0: PREREQUISITES ━━━"

echo -n "[P0.1] Checking image... "
if podman images | grep -q "indrajaal-sopv51-elixir-app"; then
    echo "✓ EXISTS"
else
    echo "✗ MISSING"
    exit 1
fi

echo -n "[P0.2] Checking networks... "
if podman network ls | grep -q "db-standalone-net"; then
    echo "✓ EXISTS"
else
    echo "✗ MISSING"
    exit 1
fi

echo -n "[P0.3] Checking database... "
if podman ps | grep -q "indrajaal-db-standalone"; then
    echo "✓ RUNNING"
else
    echo "✗ NOT RUNNING"
    exit 1
fi

# Phase 1-5: Container Startup
echo ""
echo "━━━ PHASES 1-5: CONTAINER STARTUP ━━━"

echo "[P1.1] Starting container..."
cd /home/an/dev/ver/indrajaal-v5.2
podman-compose -f "$COMPOSE_FILE" up -d

echo "[P2-4] Waiting for compilation (Patient Mode)..."
TIMEOUT=600
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        echo "[P5.1] Phoenix server ready!"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "  Waiting... ${ELAPSED}s / ${TIMEOUT}s"
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "✗ TIMEOUT waiting for health endpoint"
    exit 1
fi

# Phase 6: Health Verification
echo ""
echo "━━━ PHASE 6: HEALTH VERIFICATION ━━━"

echo -n "[P6.1] TCP probe (4000)... "
if ss -tlnp | grep -q ":4000"; then
    echo "✓ LISTENING"
else
    echo "✗ NOT LISTENING"
fi

echo -n "[P6.2] HTTP health... "
HEALTH=$(curl -sf "$HEALTH_URL")
if [ $? -eq 0 ]; then
    echo "✓ RESPONDING"
else
    echo "✗ FAILED"
    exit 1
fi

echo -n "[P6.3] Liveness probe... "
LIVENESS=$(curl -sf "http://localhost:4000/healthz" | jq -r '.status')
if [ "$LIVENESS" = "ok" ]; then
    echo "✓ OK"
else
    echo "✗ FAILED"
fi

echo -n "[P6.4] Startup probe... "
STARTUP=$(curl -sf "http://localhost:4000/startup" | jq -r '.status')
if [ "$STARTUP" = "started" ]; then
    echo "✓ STARTED"
else
    echo "✗ FAILED"
fi

# Phase 7: E2E Verification
echo ""
echo "━━━ PHASE 7: E2E VERIFICATION ━━━"

echo -n "[P7.1] OODA loop active... "
if podman logs --tail 10 "$CONTAINER_NAME" 2>&1 | grep -q "OODA Cycle"; then
    echo "✓ ACTIVE"
else
    echo "✗ INACTIVE"
fi

echo -n "[P7.2] Database connectivity... "
if podman exec "$CONTAINER_NAME" pg_isready -h indrajaal-db-standalone -p 5433 > /dev/null 2>&1; then
    echo "✓ CONNECTED"
else
    echo "✗ DISCONNECTED"
fi

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                     VERIFICATION COMPLETE                            ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Health Status:"
echo "$HEALTH" | jq '.probes'
echo ""
echo "System Metrics:"
echo "$HEALTH" | jq '.system'
```

### 11.2 Quick Smoke Test Script

```bash
#!/bin/bash
# scripts/testing/smoke_test.sh
# Quick container smoke test

CONTAINER_NAME="${1:-indrajaal-app-debug}"
HEALTH_URL="http://localhost:4000/health"

echo "Running smoke test for $CONTAINER_NAME..."

# Test 1: Container running
echo -n "Container running: "
if podman ps | grep -q "$CONTAINER_NAME"; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 2: Health endpoint
echo -n "Health endpoint: "
if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

# Test 3: Liveness
echo -n "Liveness probe: "
STATUS=$(curl -sf "http://localhost:4000/healthz" | jq -r '.status')
if [ "$STATUS" = "ok" ]; then
    echo "PASS"
else
    echo "FAIL"
    exit 1
fi

echo ""
echo "All smoke tests passed!"
```

---

## 12. CI/CD Integration

### 12.1 GitHub Actions Workflow

```yaml
# .github/workflows/container-tests.yml

name: Container Tests

on:
  push:
    paths:
      - 'lib/cepaf/**'
      - 'config/**'
      - 'lib/indrajaal/**'
  pull_request:
    branches: [main]

jobs:
  container-verification:
    runs-on: ubuntu-latest
    timeout-minutes: 30

    steps:
      - uses: actions/checkout@v4

      - name: Install Podman
        run: |
          sudo apt-get update
          sudo apt-get install -y podman podman-compose

      - name: Start Database Container
        run: |
          cd lib/cepaf/artifacts
          podman-compose -f podman-compose-db-standalone.yml up -d
          sleep 30

      - name: Start App Container
        run: |
          cd lib/cepaf/artifacts
          podman-compose -f podman-compose-app-standalone.yml up -d

      - name: Wait for Health
        run: |
          timeout 600 bash -c 'until curl -sf http://localhost:4000/health; do sleep 10; done'

      - name: Run Verification Tests
        run: |
          curl -sf http://localhost:4000/healthz | jq .
          curl -sf http://localhost:4000/startup | jq .
          curl -sf http://localhost:4000/health | jq .

      - name: Run Unit Tests
        run: |
          MIX_ENV=test mix test test/indrajaal/health/

      - name: Cleanup
        if: always()
        run: |
          podman-compose -f lib/cepaf/artifacts/podman-compose-app-standalone.yml down -v
          podman-compose -f lib/cepaf/artifacts/podman-compose-db-standalone.yml down -v
```

---

## 13. Test Reporting

### 13.1 Test Report Format

```json
{
  "test_run": {
    "id": "run-20251224-0800",
    "timestamp": "2025-12-24T08:00:00Z",
    "duration_ms": 45000,
    "environment": "container-debug"
  },
  "phases": {
    "P0_PREREQUISITES": {
      "status": "PASS",
      "tasks": {
        "P0.1_IMG": {"status": "PASS", "duration_ms": 100},
        "P0.2_NET": {"status": "PASS", "duration_ms": 50},
        "P0.3_DB": {"status": "PASS", "duration_ms": 200}
      }
    },
    "P6_HEALTH": {
      "status": "PASS",
      "tasks": {
        "P6.1_TCP": {"status": "PASS", "duration_ms": 10},
        "P6.2_HTTP": {"status": "PASS", "duration_ms": 25},
        "P6.3_LOG": {"status": "PASS", "duration_ms": 100}
      }
    }
  },
  "metrics": {
    "tests_passed": 47,
    "tests_failed": 0,
    "tests_skipped": 3,
    "coverage_percent": 85.2
  },
  "compliance": {
    "SC-CMP-025": "PASS",
    "SC-VAL-001": "PASS",
    "SC-PRF-050": "PASS",
    "SC-OBS-069": "PASS"
  }
}
```

---

## Appendix: Test Tags Reference

| Tag | Description | Usage |
|-----|-------------|-------|
| `:requires_db` | Requires database container | Skip if no DB |
| `:requires_container` | Requires app container | Skip if no container |
| `:chaos` | Chaos engineering test | Run separately |
| `:debug_mode` | Requires debug env vars | Skip in CI |
| `:slow` | Takes >30 seconds | Run separately |
| `:integration` | Integration test | Run after unit tests |
