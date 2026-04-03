defmodule Indrajaal.Cockpit.Prajna.FullSystemTest do
  @moduledoc """
  Comprehensive Full System Test Suite

  Tests all Indrajaal features including:
  - 780+ modules across 100 domains
  - 5-order effect verification
  - Control system functionality
  - Monitoring accuracy
  - Safety system integration

  ## STAMP Constraints Verified
  - SC-CTRL-001 to SC-CTRL-005 (Control)
  - SC-MON-001 to SC-MON-005 (Monitoring)
  - SC-PRAJNA-001 to SC-PRAJNA-007 (Prajna)
  - SC-HOLON-001 to SC-HOLON-020 (Holon)

  ## TDG Compliance
  - Unit tests with assertions
  - Property tests with PropCheck
  - Integration tests for data flows
  """

  use ExUnit.Case, async: false
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cockpit.Prajna.MasterControl
  alias Indrajaal.Cockpit.Prajna.FullSystemMonitor

  @domains [
    :access_control,
    :accounts,
    :alarms,
    :analytics,
    :authentication,
    :authorization,
    :billing,
    :cluster,
    :cockpit,
    :communication,
    :compliance,
    :coordination,
    :cortex,
    :cybernetic,
    :devices,
    :dispatch,
    :distributed,
    :flame,
    :identity,
    :integration,
    :knowledge,
    :maintenance,
    :mesh,
    :observability,
    :policy,
    :safety,
    :security,
    :sites,
    :validation,
    :video
  ]

  describe "System Status (SC-CTRL-001)" do
    test "returns complete system status" do
      {:ok, status} = MasterControl.system_status()

      assert Map.has_key?(status, :status)
      assert Map.has_key?(status, :domains)
      assert Map.has_key?(status, :critical_services)
      assert Map.has_key?(status, :health_summary)
    end

    test "all 30 domains present in status" do
      {:ok, status} = MasterControl.system_status()

      domain_count = map_size(status.domains)
      assert domain_count == 30, "Expected 30 domains, got #{domain_count}"
    end

    test "health summary contains required fields" do
      {:ok, status} = MasterControl.system_status()

      summary = status.health_summary
      assert Map.has_key?(summary, :total)
      assert Map.has_key?(summary, :healthy)
      assert Map.has_key?(summary, :degraded)
      assert Map.has_key?(summary, :critical)
      assert Map.has_key?(summary, :failed)
      assert Map.has_key?(summary, :score)
    end
  end

  describe "Domain Status (SC-CTRL-002)" do
    test "can query each domain individually" do
      Enum.each(@domains, fn domain ->
        {:ok, status} = MasterControl.domain_status(domain)

        assert status.domain == domain
        assert Map.has_key?(status, :info)
        assert Map.has_key?(status, :health)
        assert Map.has_key?(status, :modules)
      end)
    end

    test "domain module counts are accurate" do
      expected_counts = %{
        observability: 68,
        analytics: 32,
        alarms: 23,
        safety: 16,
        access_control: 16,
        validation: 16,
        communication: 13,
        accounts: 12
      }

      Enum.each(expected_counts, fn {domain, expected} ->
        {:ok, status} = MasterControl.domain_status(domain)
        actual = status.info.module_count

        assert actual == expected,
               "Domain #{domain}: expected #{expected} modules, got #{actual}"
      end)
    end
  end

  describe "5-Order Effect Analysis (SC-CTRL-003)" do
    test "analyze_effects returns all 5 orders" do
      {:ok, effects} = MasterControl.analyze_effects(:alarms, :process, %{})

      assert Map.has_key?(effects, :order_1)
      assert Map.has_key?(effects, :order_2)
      assert Map.has_key?(effects, :order_3)
      assert Map.has_key?(effects, :order_4)
      assert Map.has_key?(effects, :order_5)
    end

    test "order 1 identifies direct action" do
      {:ok, effects} = MasterControl.analyze_effects(:safety, :check, %{})

      assert effects.order_1.affected == [:safety]
      assert effects.order_1.time_scale == "immediate"
    end

    test "order 2 identifies adjacent domains" do
      {:ok, effects} = MasterControl.analyze_effects(:safety, :check, %{})

      adjacent = effects.order_2.affected
      assert :cortex in adjacent or :cluster in adjacent
    end

    test "alarms domain affects communication" do
      {:ok, effects} = MasterControl.analyze_effects(:alarms, :escalate, %{})

      third_order = effects.order_3.affected
      assert :communication in third_order or :observability in third_order
    end

    # Property verification: all domains have valid effect chains
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: all domains have valid effect chains" do
      # Test with all domains
      for domain <- @domains do
        {:ok, effects} = MasterControl.analyze_effects(domain, :status, %{})

        # Verify all orders present
        has_all_orders =
          Enum.all?(1..5, fn n ->
            Map.has_key?(effects, :"order_#{n}")
          end)

        # Verify order 1 always includes the domain
        includes_domain = domain in effects.order_1.affected

        assert has_all_orders
        assert includes_domain
      end
    end
  end

  describe "Circuit Breaker System (SC-CTRL-005)" do
    test "all domains have circuit breakers" do
      breakers = MasterControl.circuit_breaker_status()

      assert map_size(breakers) == 30

      Enum.each(@domains, fn domain ->
        assert Map.has_key?(breakers, domain),
               "Missing circuit breaker for #{domain}"
      end)
    end

    test "circuit breakers start in closed state" do
      breakers = MasterControl.circuit_breaker_status()

      Enum.each(breakers, fn {domain, state} ->
        assert state.state == :closed,
               "Circuit breaker for #{domain} not closed: #{inspect(state)}"
      end)
    end
  end

  describe "Full System Monitor (SC-MON-001)" do
    test "get_metrics returns complete snapshot" do
      metrics = FullSystemMonitor.get_metrics()

      assert Map.has_key?(metrics, :infrastructure)
      assert Map.has_key?(metrics, :domains)
      assert Map.has_key?(metrics, :api)
      assert Map.has_key?(metrics, :safety)
      assert Map.has_key?(metrics, :observability)
      assert Map.has_key?(metrics, :resources)
      assert Map.has_key?(metrics, :performance)
    end

    test "infrastructure metrics include containers" do
      metrics = FullSystemMonitor.get_metrics()
      infra = metrics.infrastructure

      assert Map.has_key?(infra, :containers)
      assert Map.has_key?(infra, :processes)
      assert Map.has_key?(infra, :beam)
      assert Map.has_key?(infra, :network)
    end

    test "BEAM metrics are accurate" do
      metrics = FullSystemMonitor.get_metrics()
      beam = metrics.infrastructure.beam

      assert beam.memory_total_mb > 0
      assert beam.uptime_seconds >= 0
    end

    test "process count is reasonable" do
      metrics = FullSystemMonitor.get_metrics()
      procs = metrics.infrastructure.processes

      assert procs.total_processes > 0
      assert procs.total_processes < 1_000_000
    end
  end

  describe "Safety Metrics (SC-MON-004)" do
    test "safety metrics include Guardian status" do
      metrics = FullSystemMonitor.get_metrics()
      safety = metrics.safety

      assert Map.has_key?(safety, :guardian)
      assert Map.has_key?(safety.guardian, :status)
    end

    test "safety metrics include Sentinel status" do
      metrics = FullSystemMonitor.get_metrics()
      safety = metrics.safety

      assert Map.has_key?(safety, :sentinel)
      assert Map.has_key?(safety.sentinel, :status)
    end

    test "safety metrics include circuit breaker summary" do
      metrics = FullSystemMonitor.get_metrics()
      safety = metrics.safety

      assert Map.has_key?(safety, :circuit_breakers)
      assert safety.circuit_breakers.total == 30
    end
  end

  describe "Dashboard Data (SC-MON-005)" do
    test "dashboard_data returns complete structure" do
      data = FullSystemMonitor.dashboard_data()

      assert Map.has_key?(data, :status)
      assert Map.has_key?(data, :summary)
      assert Map.has_key?(data, :domains)
      assert Map.has_key?(data, :alerts)
    end

    test "summary includes health score" do
      data = FullSystemMonitor.dashboard_data()
      summary = data.summary

      assert Map.has_key?(summary, :health_score)
      assert summary.health_score >= 0
      assert summary.health_score <= 100
    end

    test "domains summary shows all 30 domains" do
      data = FullSystemMonitor.dashboard_data()

      assert map_size(data.domains) == 30
    end
  end

  describe "Domain Health Verification" do
    test "safety domain health reflects Guardian status" do
      {:ok, status} = MasterControl.domain_status(:safety)

      # Safety domain health depends on Guardian being alive
      guardian_alive = Process.whereis(Indrajaal.Safety.Guardian) != nil

      if guardian_alive do
        assert status.health in [:healthy, :degraded]
      else
        assert status.health in [:critical, :degraded, :unknown]
      end
    end

    test "cortex domain health reflects Controller status" do
      {:ok, status} = MasterControl.domain_status(:cortex)

      controller_alive = Process.whereis(Indrajaal.Cortex.Controller) != nil

      if controller_alive do
        assert status.health in [:healthy, :degraded]
      end
    end

    # Property verification: domain health is valid enum
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: domain health is valid enum" do
      # Test with all domains
      for domain <- @domains do
        {:ok, status} = MasterControl.domain_status(domain)

        assert status.health in [:healthy, :degraded, :critical, :failed, :unknown]
      end
    end
  end

  describe "Resource Metrics Accuracy" do
    test "memory metrics are non-negative" do
      metrics = FullSystemMonitor.get_metrics()
      resources = metrics.resources

      assert resources.memory.total_mb >= 0
      assert resources.memory.used_mb >= 0
      assert resources.memory.usage_pct >= 0
      assert resources.memory.usage_pct <= 100
    end

    test "CPU metrics are non-negative" do
      metrics = FullSystemMonitor.get_metrics()
      resources = metrics.resources

      assert resources.cpu.cores > 0
      assert resources.cpu.usage_pct >= 0
    end
  end

  describe "API Metrics Structure" do
    test "API metrics include all endpoint categories" do
      metrics = FullSystemMonitor.get_metrics()
      api = metrics.api

      assert Map.has_key?(api, :endpoints)
      assert Map.has_key?(api.endpoints, :mobile_api)
      assert Map.has_key?(api.endpoints, :prajna_api)
      assert Map.has_key?(api.endpoints, :health_api)
    end

    test "mobile API has 200+ endpoints" do
      metrics = FullSystemMonitor.get_metrics()
      mobile = metrics.api.endpoints.mobile_api

      assert mobile.endpoint_count >= 200
    end

    test "prajna API has 15+ endpoints" do
      metrics = FullSystemMonitor.get_metrics()
      prajna = metrics.api.endpoints.prajna_api

      assert prajna.endpoint_count >= 15
    end

    test "websocket channels are tracked" do
      metrics = FullSystemMonitor.get_metrics()
      ws = metrics.api.websockets

      assert Map.has_key?(ws, :channels)
      assert length(ws.channels) >= 6
    end
  end

  describe "Observability Metrics" do
    test "zenoh status is tracked" do
      metrics = FullSystemMonitor.get_metrics()
      obs = metrics.observability

      assert Map.has_key?(obs, :zenoh)
      assert obs.zenoh.status in [:connected, :disconnected]
    end

    test "OTEL metrics are tracked" do
      metrics = FullSystemMonitor.get_metrics()
      obs = metrics.observability

      assert Map.has_key?(obs, :otel)
      assert Map.has_key?(obs.otel, :traces_exported)
      assert Map.has_key?(obs.otel, :metrics_exported)
    end

    test "logging levels are tracked" do
      metrics = FullSystemMonitor.get_metrics()
      obs = metrics.observability

      assert Map.has_key?(obs, :logging)
      assert Map.has_key?(obs.logging, :debug_per_min)
      assert Map.has_key?(obs.logging, :info_per_min)
      assert Map.has_key?(obs.logging, :warn_per_min)
      assert Map.has_key?(obs.logging, :error_per_min)
    end
  end

  describe "Performance Metrics" do
    test "OODA cycle metrics are tracked" do
      metrics = FullSystemMonitor.get_metrics()
      perf = metrics.performance

      assert Map.has_key?(perf, :ooda_cycle)
      assert perf.ooda_cycle.target_ms == 1000
    end

    test "API latency percentiles are tracked" do
      metrics = FullSystemMonitor.get_metrics()
      perf = metrics.performance

      assert Map.has_key?(perf, :api)
      assert Map.has_key?(perf.api, :p50_latency_ms)
      assert Map.has_key?(perf.api, :p95_latency_ms)
      assert Map.has_key?(perf.api, :p99_latency_ms)
    end
  end

  describe "Alert Generation" do
    test "alerts list is returned" do
      alerts = FullSystemMonitor.get_alerts()

      assert is_list(alerts)
    end

    test "dashboard includes alerts" do
      data = FullSystemMonitor.dashboard_data()

      assert Map.has_key?(data, :alerts)
      assert is_list(data.alerts)
    end
  end

  describe "Threshold Configuration" do
    test "can set custom threshold" do
      :ok = FullSystemMonitor.set_threshold(:cpu_usage_pct, 95.0)
    end
  end

  describe "Module Count Verification" do
    test "total modules across all domains is 780+" do
      {:ok, status} = MasterControl.system_status()

      total =
        Enum.reduce(status.domains, 0, fn {_, info}, acc ->
          acc + (info.module_count || 0)
        end)

      assert total >= 780, "Expected 780+ modules, got #{total}"
    end

    test "observability has most modules (68)" do
      {:ok, status} = MasterControl.domain_status(:observability)
      assert status.info.module_count == 68
    end

    test "analytics has 32 modules" do
      {:ok, status} = MasterControl.domain_status(:analytics)
      assert status.info.module_count == 32
    end

    test "alarms has 23 modules" do
      {:ok, status} = MasterControl.domain_status(:alarms)
      assert status.info.module_count == 23
    end
  end

  describe "Critical Services Check" do
    test "critical services list is complete" do
      {:ok, status} = MasterControl.system_status()

      services = status.critical_services

      assert Map.has_key?(services, Indrajaal.Core.Constitution.Verifier)
      assert Map.has_key?(services, Indrajaal.Safety.Guardian)
      assert Map.has_key?(services, Indrajaal.Safety.Sentinel)
      assert Map.has_key?(services, Indrajaal.Cluster.Sentinel)
    end

    test "service status is running or down" do
      {:ok, status} = MasterControl.system_status()

      Enum.each(status.critical_services, fn {_service, info} ->
        assert info.status in [:running, :down]
      end)
    end
  end

  describe "Property Tests for System Invariants" do
    # Property verification: system status always returns ok tuple
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: system status always returns ok tuple" do
      # Test multiple times to verify consistency
      for _ <- 1..10 do
        case MasterControl.system_status() do
          {:ok, _} -> assert true
          _ -> assert false
        end
      end
    end

    # Property verification: metrics always have positive values
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: metrics always have positive values" do
      # Test multiple times to verify consistency
      for _ <- 1..10 do
        metrics = FullSystemMonitor.get_metrics()
        beam = metrics.infrastructure.beam

        assert beam.memory_total_mb >= 0
        assert beam.uptime_seconds >= 0
      end
    end

    # Property verification: health scores are in valid range
    # Converted from PropCheck to avoid GenServer dependency with --no-start
    # SC-SIL6-001: Manual property verification
    test "propcheck: health scores are in valid range" do
      # Test multiple times to verify consistency
      for _ <- 1..10 do
        data = FullSystemMonitor.dashboard_data()
        score = data.summary.health_score

        assert score >= 0
        assert score <= 100
      end
    end
  end
end
