# SigNoz Implementation Plan with TDG, STAMP, and GDE Controls

**Date**: 2025-08-03 10:52:00 CEST
**Category**: Infrastructure Implementation Planning
**Focus**: Centralized Observability Platform with Enterprise Controls
**Frameworks**: TDG (Test-Driven Generation), STAMP (Safety Analysis), GDE (Goal-Directed Execution)

## Executive Summary

This document presents a comprehensive implementation plan for deploying SigNoz as the unified observability platform for the Indrajaal Security Monitoring System. The plan integrates mandatory TDG methodology, STAMP safety analysis, and GDE goal-tracking framework to ensure enterprise-grade reliability and systematic execution.

## 🎯 GDE Goal Definition (Phase 0)

### Primary Goals
1. **G1: Zero Data Loss** - 100% telemetry data successfully ingested and stored
2. **G2: Query Performance** - P95 query latency < 2 seconds for all dashboard queries
3. **G3: Platform Adoption** - 80% of development team actively using SigNoz within 30 days
4. **G4: Alert Accuracy** - < 5% false positive rate on production alerts
5. **G5: Storage Efficiency** - < 20% storage increase compared to current logging

### Success Criteria
- All 5 primary goals achieved within 8-week implementation window
- Zero production incidents caused by observability platform
- Complete deprecation of console logging by week 9
- Positive developer feedback score > 4.0/5.0

## 🧪 TDG Methodology Integration

### Pre-Implementation Test Requirements

#### 1. Container Build Tests (`test/observability/tdg/container_build_tests.exs`)
```elixir
defmodule Observability.TDG.ContainerBuildTest do
  use ExUnit.Case

  @tag :tdg_required
  describe "ClickHouse container build" do
    test "creates valid NixOS-based ClickHouse image" do
      # Test specification written BEFORE implementation
      assert {:ok, image_id} = build_clickhouse_container()
      assert container_exists?(image_id)
      assert container_has_nixos_base?(image_id)
      assert exposed_ports_valid?(image_id, [8123, 9000])
    end

    test "ClickHouse container starts successfully" do
      assert {:ok, container_id} = start_clickhouse_container()
      assert wait_for_health_check(container_id, timeout: 30_000)
      assert clickhouse_responding?(container_id)
    end
  end

  describe "SigNoz Query Service container" do
    test "builds with all required dependencies" do
      assert {:ok, image_id} = build_signoz_query_container()
      assert has_signoz_binary?(image_id)
      assert has_required_env_vars?(image_id)
    end
  end
end
```

#### 2. Integration Tests (`test/observability/tdg/integration_tests.exs`)
```elixir
defmodule Observability.TDG.IntegrationTest do
  use ExUnit.Case

  @tag :tdg_required
  describe "OpenTelemetry export" do
    test "traces are successfully exported to SigNoz" do
      # Define expected behavior BEFORE implementation
      span = start_test_span("tdg_test_operation")
      :ok = end_span(span)

      assert_receive {:telemetry_exported, ^span}, 5_000
      assert trace_visible_in_signoz?(span.trace_id)
    end

    test "structured logs are collected and indexed" do
      test_metadata = %{tenant_id: "test", agent_id: "tdg_agent"}
      Logger.info("TDG test message", test_metadata)

      assert log_entry = wait_for_log_in_signoz("TDG test message")
      assert log_entry.metadata == test_metadata
    end
  end
end
```

### TDG Compliance Requirements
1. **No code without tests**: Every implementation file must have corresponding TDG tests
2. **Test-first development**: Tests must be written and reviewed before implementation
3. **100% test coverage**: All generated code must achieve full test coverage
4. **AI validation**: All AI-generated code must pass TDG validation suite

## 🛡️ STAMP Safety Analysis

### STPA Control Structure

```
┌─────────────────────────────────────────┐
│         Operator/SRE Team               │
│    (Views dashboards, receives alerts)  │
└─────────────┬───────────────────────────┘
              │ Control Actions
              ▼
┌─────────────────────────────────────────┐
│         SigNoz Platform                 │
│  (Query Service, Frontend, Collector)   │
└─────────────┬───────────────────────────┘
              │ Control Actions
              ▼
┌─────────────────────────────────────────┐
│         ClickHouse Database             │
│    (Stores metrics, logs, traces)       │
└─────────────┬───────────────────────────┘
              │ Feedback
              ▼
┌─────────────────────────────────────────┐
│      Indrajaal Application              │
│   (Generates telemetry data)            │
└─────────────────────────────────────────┘
```

### Identified Safety Constraints

1. **SC1**: Telemetry data must never be lost during transmission
2. **SC2**: Query service must not expose sensitive data without authorization
3. **SC3**: Storage must not exceed allocated disk space causing system failure
4. **SC4**: Alert notifications must be delivered within 60 seconds of trigger
5. **SC5**: Platform unavailability must not impact application performance

### Unsafe Control Actions (UCAs)

1. **UCA1**: Operator queries data causing ClickHouse OOM (Out of Memory)
   - **Mitigation**: Query resource limits and timeout configuration

2. **UCA2**: Collector drops data due to backpressure
   - **Mitigation**: Buffer configuration and overflow handling

3. **UCA3**: Frontend exposes data across tenant boundaries
   - **Mitigation**: Strict tenant isolation in queries

4. **UCA4**: ClickHouse retention deletes data prematurely
   - **Mitigation**: Careful retention policy configuration with safeguards

### STAMP Validation Script (`scripts/stamp/stpa_signoz_safety_validator.exs`)
```elixir
defmodule STAMP.SignozSafetyValidator do
  @safety_constraints [
    {:data_loss_prevention, &validate_no_data_loss/0},
    {:authorization_check, &validate_data_authorization/0},
    {:resource_limits, &validate_resource_usage/0},
    {:alert_delivery, &validate_alert_timeliness/0},
    {:app_isolation, &validate_app_performance_isolation/0}
  ]

  def validate_all_constraints do
    Enum.map(@safety_constraints, fn {name, validator} ->
      case validator.() do
        :ok -> {:ok, name}
        {:error, reason} -> {:violation, name, reason}
      end
    end)
  end
end
```

## 📋 Implementation Phases

### Phase 1: Infrastructure Setup (Week 1-2)

#### 1.1 NixOS Container Derivations

**ClickHouse Container** (`containers/signoz/clickhouse-nixos.nix`)
```nix
{ pkgs ? import <nixpkgs> {} }:

pkgs.dockerTools.buildImage {
  name = "localhost/signoz-clickhouse";
  tag = "latest";

  contents = with pkgs; [
    clickhouse
    bash
    coreutils
    # TDG: Additional packages determined by tests
  ];

  runAsRoot = ''
    mkdir -p /var/lib/clickhouse
    mkdir -p /etc/clickhouse-server
    # STAMP: Apply safety constraints for data directories
    chmod 700 /var/lib/clickhouse
  '';

  config = {
    Cmd = [ "${pkgs.clickhouse}/bin/clickhouse-server" "--config-file=/etc/clickhouse-server/config.xml" ];
    ExposedPorts = {
      "8123/tcp" = {};  # HTTP interface
      "9000/tcp" = {};  # Native protocol
    };
    Volumes = {
      "/var/lib/clickhouse" = {};
    };
    # GDE: Health check for goal monitoring
    Healthcheck = {
      Test = ["CMD", "clickhouse-client", "--query", "SELECT 1"];
      Interval = "30s";
      Timeout = "5s";
      Retries = 3;
    };
  };
}
```

**Build Automation Script** (`scripts/observability/build_signoz_containers.exs`)
```elixir
defmodule SignozContainerBuilder do
  @moduledoc """
  TDG-compliant container builder with STAMP safety validation
  """

  def build_all_containers do
    # GDE: Track build progress
    goal_tracker = GDE.GoalTracker.start_link(:signoz_build)

    containers = [
      {"clickhouse", "containers/signoz/clickhouse-nixos.nix"},
      {"signoz-query", "containers/signoz/query-service-nixos.nix"},
      {"otel-collector", "containers/signoz/otel-collector-nixos.nix"},
      {"signoz-frontend", "containers/signoz/frontend-nixos.nix"}
    ]

    # TDG: Validate tests exist before building
    assert_all_tests_exist(containers)

    results = Enum.map(containers, fn {name, nix_file} ->
      # STAMP: Validate safety constraints before build
      :ok = STAMP.validate_build_safety(name)

      build_container(name, nix_file)
    end)

    # GDE: Report achievement
    GDE.GoalTracker.mark_complete(goal_tracker, :container_builds)

    results
  end
end
```

#### 1.2 Podman Compose Configuration

**Observability Stack** (`podman-compose.observability.yml`)
```yaml
version: '3.8'

networks:
  indrajaal-observability:
    driver: bridge
    # STAMP: Network isolation for security
    internal: false

volumes:
  clickhouse-data:
    driver: local
    driver_opts:
      # STAMP: Prevent disk overflow (SC3)
      size: 100G

services:
  clickhouse:
    image: localhost/signoz-clickhouse:latest
    container_name: indrajaal-clickhouse
    hostname: clickhouse
    networks:
      - indrajaal-observability
    ports:
      - "127.0.0.1:9000:9000"  # STAMP: Localhost only
      - "127.0.0.1:8123:8123"
    volumes:
      - clickhouse-data:/var/lib/clickhouse
      - ./observability/clickhouse/config.xml:/etc/clickhouse-server/config.xml:ro
    environment:
      - CLICKHOUSE_DB=signoz
      - CLICKHOUSE_USER=signoz
      - CLICKHOUSE_PASSWORD=${CLICKHOUSE_PASSWORD}  # GDE: Secure config
    deploy:
      resources:
        limits:
          # STAMP: Resource limits to prevent OOM (UCA1)
          memory: 8G
          cpus: '4'
        reservations:
          memory: 4G

  signoz-query:
    image: localhost/signoz-query:latest
    container_name: indrajaal-signoz-query
    networks:
      - indrajaal-observability
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - ClickHouseUrl=tcp://clickhouse:9000/?database=signoz
      - STORAGE=clickhouse
      # STAMP: Tenant isolation configuration (UCA3)
      - TENANT_ISOLATION=strict
    depends_on:
      clickhouse:
        condition: service_healthy

  otel-collector:
    image: localhost/signoz-otel-collector:latest
    container_name: indrajaal-otel-collector
    networks:
      - indrajaal-observability
    ports:
      - "127.0.0.1:4317:4317"  # OTLP gRPC
      - "127.0.0.1:4318:4318"  # OTLP HTTP
    volumes:
      - ./observability/otel/config.yaml:/etc/otel/config.yaml:ro
    environment:
      - CLICKHOUSE_HOST=clickhouse
      # STAMP: Buffer configuration (UCA2)
      - BUFFER_SIZE=10000
      - RETRY_ON_FAILURE=true
```

### Phase 2: Application Integration (Week 3-4)

#### 2.1 Structured Logging Configuration

**Logger Configuration** (`config/config.exs`)
```elixir
# TDG: Configuration validated by tests before implementation
config :logger, :default_handler,
  formatter: {LoggerJSON.Formatters.Datadog,
    metadata: [
      :trace_id,
      :span_id,
      :tenant_id,  # STAMP: Tenant isolation (SC2)
      :agent_id,
      :task_id
    ]}

config :logger,
  backends: [LoggerJSON],
  # STAMP: Prevent log overflow
  truncate: 8192,
  compile_time_purge_level: :info
```

#### 2.2 OpenTelemetry Configuration

**Runtime Configuration** (`config/runtime.exs`)
```elixir
# GDE: Configurable endpoints for goal tracking
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp

config :opentelemetry_exporter,
  otlp_protocol: :grpc,
  otlp_endpoint: System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317"),
  # STAMP: Secure token handling
  otlp_headers: [
    {"signoz-access-token", System.get_env("SIGNOZ_ACCESS_TOKEN", "")},
    {"tenant-id", System.get_env("TENANT_ID", "default")}
  ],
  # STAMP: Prevent data loss (SC1)
  otlp_compression: :gzip,
  retry_on_failure: true,
  max_retries: 5
```

### Phase 3: Dashboard & Monitoring (Week 5-6)

#### 3.1 Dashboard Provisioning

**Multi-Agent Dashboard** (`scripts/observability/dashboards/multi_agent_performance.exs`)
```elixir
defmodule Dashboards.MultiAgentPerformance do
  @moduledoc """
  TDG-validated dashboard for 11-agent architecture monitoring
  """

  def provision do
    # GDE: Track dashboard creation goal
    GDE.track_goal(:dashboard_provisioning, fn ->
      dashboard = %{
        uid: "multi-agent-performance",
        title: "Multi-Agent Compilation Performance",
        panels: [
          agent_timeline_panel(),
          compilation_success_rate_panel(),
          resource_utilization_panel(),
          error_analysis_panel()
        ],
        # STAMP: Data access controls
        permissions: %{
          view: ["developer", "sre"],
          edit: ["sre_lead", "admin"]
        }
      }

      SignozAPI.create_dashboard(dashboard)
    end)
  end

  defp agent_timeline_panel do
    %{
      title: "Agent Activity Timeline",
      type: "graph",
      query: """
      SELECT
        toDateTime(timestamp) as time,
        attributes['agent_id'] as agent,
        attributes['task_id'] as task,
        duration_ms
      FROM signoz_traces.distributed_traces_v2
      WHERE
        serviceName = 'indrajaal'
        AND name = 'compilation.task'
        AND timestamp >= now() - INTERVAL 1 HOUR
      ORDER BY timestamp
      """
    }
  end
end
```

#### 3.2 Alert Configuration

**Critical Alerts** (`observability/alerts/critical_alerts.yaml`)
```yaml
# STAMP: Alert configuration with safety constraints
groups:
  - name: telemetry_safety
    interval: 30s
    rules:
      # SC1: Data loss prevention
      - alert: TelemetryDataLoss
        expr: |
          rate(otel_collector_dropped_spans[5m]) > 0
        for: 2m
        severity: critical
        annotations:
          summary: "Telemetry data is being dropped"

      # SC4: Alert delivery timeliness
      - alert: AlertDeliveryDelay
        expr: |
          histogram_quantile(0.95, alert_delivery_duration_seconds) > 60
        severity: warning

      # SC3: Storage capacity
      - alert: ClickHouseStorageHigh
        expr: |
          clickhouse_disk_usage_percent > 80
        severity: warning
        annotations:
          summary: "ClickHouse storage approaching limit"
```

### Phase 4: Testing & Validation (Week 6-7)

#### 4.1 Integration Test Suite

**Comprehensive Validation** (`test/observability/signoz_integration_test.exs`)
```elixir
defmodule SignozIntegrationTest do
  use ExUnit.Case

  # TDG: All tests written before implementation
  @tag :integration
  describe "end-to-end telemetry pipeline" do
    test "traces flow from application to SigNoz" do
      # Start traced operation
      ctx = OpenTelemetry.Tracer.start_span("test_operation")
      :timer.sleep(100)
      OpenTelemetry.Tracer.end_span(ctx)

      # Verify in SigNoz
      assert_eventually(fn ->
        traces = SignozAPI.query_traces(%{
          service: "indrajaal",
          operation: "test_operation"
        })

        assert length(traces) > 0
      end, timeout: 10_000)
    end

    test "structured logs maintain metadata through pipeline" do
      test_id = UUID.uuid4()
      Logger.info("Integration test",
        test_id: test_id,
        tenant_id: "test_tenant"
      )

      assert_eventually(fn ->
        logs = SignozAPI.query_logs(%{
          message: "Integration test",
          test_id: test_id
        })

        assert [log] = logs
        assert log.attributes["tenant_id"] == "test_tenant"
      end)
    end
  end

  # STAMP: Safety constraint validation
  @tag :safety
  describe "safety constraints" do
    test "data loss prevention (SC1)" do
      # Generate high volume of traces
      Enum.each(1..1000, fn i ->
        span = OpenTelemetry.Tracer.start_span("load_test_#{i}")
        OpenTelemetry.Tracer.end_span(span)
      end)

      # Verify no data loss
      :timer.sleep(5000)
      assert SignozAPI.count_traces(%{name_prefix: "load_test"}) == 1000
    end

    test "tenant data isolation (SC2)" do
      # Attempt cross-tenant query
      assert {:error, :unauthorized} =
        SignozAPI.query_traces(%{tenant_id: "other_tenant"})
    end
  end
end
```

#### 4.2 Performance Benchmarks

**Observability Overhead** (`benchmarks/observability_overhead.exs`)
```elixir
Benchee.run(%{
  "baseline_no_telemetry" => fn ->
    perform_operation()
  end,

  "with_tracing" => fn ->
    ctx = OpenTelemetry.Tracer.start_span("benchmark_op")
    perform_operation()
    OpenTelemetry.Tracer.end_span(ctx)
  end,

  "with_tracing_and_logging" => fn ->
    ctx = OpenTelemetry.Tracer.start_span("benchmark_op")
    Logger.info("Benchmark operation", trace_id: ctx.trace_id)
    perform_operation()
    OpenTelemetry.Tracer.end_span(ctx)
  end
},
  # GDE: Performance goals
  after_each: fn result ->
    assert result.average < 1.1 * baseline_average,
      "Overhead must be < 10%"
  end
)
```

### Phase 5: Deployment & Migration (Week 7-8)

#### 5.1 Deployment Automation

**Deployment Script** (`scripts/observability/deploy_signoz.exs`)
```elixir
defmodule SignozDeployment do
  @moduledoc """
  GDE-tracked deployment with STAMP safety validation
  """

  def deploy do
    # GDE: Initialize deployment tracking
    deployment_id = GDE.start_deployment(:signoz_platform)

    steps = [
      # TDG: Validate all tests pass
      {:test_validation, &validate_all_tdg_tests/0},

      # STAMP: Safety pre-checks
      {:safety_validation, &STAMP.validate_all_constraints/0},

      # Build and deploy
      {:build_containers, &SignozContainerBuilder.build_all/0},
      {:start_infrastructure, &start_signoz_stack/0},
      {:validate_health, &health_check_all_services/0},

      # Application configuration
      {:configure_app, &configure_application/0},
      {:validate_export, &validate_telemetry_export/0},

      # Dashboard setup
      {:provision_dashboards, &provision_all_dashboards/0},
      {:configure_alerts, &configure_alert_rules/0}
    ]

    result = Enum.reduce_while(steps, :ok, fn {step, func}, _ ->
      IO.puts("Executing: #{step}")

      case func.() do
        :ok ->
          GDE.mark_step_complete(deployment_id, step)
          {:cont, :ok}

        {:error, reason} ->
          GDE.mark_deployment_failed(deployment_id, step, reason)
          # STAMP: Safety rollback
          rollback_deployment(step)
          {:halt, {:error, step, reason}}
      end
    end)

    # GDE: Report final status
    GDE.complete_deployment(deployment_id, result)

    result
  end
end
```

#### 5.2 Migration Strategy

**Phased Migration Plan**
1. **Week 7**: Deploy SigNoz in shadow mode (dual logging)
2. **Week 7**: Validate data completeness and accuracy
3. **Week 8**: Enable team dashboards and training
4. **Week 8**: Gradual traffic migration (10% → 50% → 100%)
5. **Week 9**: Decommission console logging

### Phase 6: Monitoring & Optimization (Ongoing)

#### 6.1 GDE Goal Tracking

**Goal Monitor** (`scripts/gde/signoz_goal_monitor.exs`)
```elixir
defmodule GDE.SignozGoalMonitor do
  use GenServer

  @goals [
    {:data_loss, &check_data_loss/0, target: 0},
    {:query_latency_p95, &check_query_latency/0, target: 2000},
    {:adoption_rate, &check_adoption_rate/0, target: 80},
    {:alert_false_positive, &check_false_positives/0, target: 5},
    {:storage_increase, &check_storage_increase/0, target: 20}
  ]

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    schedule_check()
    {:ok, %{checks: 0, violations: []}}
  end

  def handle_info(:check_goals, state) do
    results = Enum.map(@goals, fn {name, checker, target: target} ->
      case checker.() do
        {:ok, value} when value <= target ->
          {:ok, name, value}

        {:ok, value} ->
          {:violation, name, value, target}

        {:error, reason} ->
          {:error, name, reason}
      end
    end)

    # Report to monitoring
    report_goal_status(results)

    schedule_check()
    {:noreply, %{state | checks: state.checks + 1}}
  end
end
```

## Risk Management

### Technical Risks

1. **ClickHouse Performance**
   - **Risk**: Query performance degradation under load
   - **Mitigation**: Pre-configured resource limits and query optimization
   - **Monitoring**: Automated performance benchmarks

2. **Container Build Failures**
   - **Risk**: NixOS derivation build issues
   - **Mitigation**: Comprehensive TDG tests and fallback images
   - **Recovery**: Automated rollback procedures

3. **Data Loss During Migration**
   - **Risk**: Telemetry data loss during cutover
   - **Mitigation**: Dual export period with validation
   - **Validation**: Automated data completeness checks

### Organizational Risks

1. **Team Adoption Resistance**
   - **Risk**: Developers prefer console logging
   - **Mitigation**: Comprehensive training and intuitive dashboards
   - **Tracking**: Weekly adoption metrics

2. **Operational Complexity**
   - **Risk**: Increased maintenance burden
   - **Mitigation**: Automation and clear runbooks
   - **Support**: Dedicated SRE training

## Success Metrics

### Week 8 Targets
- ✅ All 5 GDE goals achieved
- ✅ Zero production incidents
- ✅ 100% TDG test coverage
- ✅ All STAMP safety constraints validated
- ✅ Team satisfaction score > 4.0/5.0

### Long-term Targets (3 months)
- 50% reduction in MTTR
- 90% reduction in "unknown" incident causes
- 30% improvement in performance optimization velocity
- Complete elimination of console logging

## Conclusion

This implementation plan provides a systematic, safety-conscious approach to deploying SigNoz as the unified observability platform. By integrating TDG, STAMP, and GDE methodologies, we ensure enterprise-grade reliability while maintaining development velocity and operational excellence.

The 8-week timeline balances thorough preparation with timely delivery, while the comprehensive testing and safety analysis minimize risks. The goal-directed approach ensures measurable success and continuous improvement throughout the implementation.

---

**Author**: Claude
**Plan Status**: Complete and Ready for Execution
**Next Action**: Begin Phase 1 TDG test creation
**Implementation Start**: Week of 2025-08-05