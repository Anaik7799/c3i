defmodule Indrajaal.Safety.EnvelopeTest do
  @moduledoc """
  Tests for the Safety Envelope module.

  WHAT: Validates safety constraint definitions and validation logic.
  WHY: SC-ENV-001 to SC-ENV-004 require deterministic envelope evaluation.
  CONSTRAINTS: Must verify all constraint categories work correctly.
  """
  use ExUnit.Case, async: true

  alias Indrajaal.Safety.Envelope

  # ============================================================
  # RESOURCE CONSTRAINTS TESTS (SC-RES)
  # ============================================================

  describe "resource constraint definitions" do
    test "max_flame_nodes returns 50" do
      assert Envelope.max_flame_nodes() == 50
    end

    test "max_ram_mb returns 32_000" do
      assert Envelope.max_ram_mb() == 32_000
    end

    test "max_cpu_percent returns 90" do
      assert Envelope.max_cpu_percent() == 90
    end

    test "max_db_connections returns 100" do
      assert Envelope.max_db_connections() == 100
    end

    test "max_websocket_connections returns 10_000" do
      assert Envelope.max_websocket_connections() == 10_000
    end
  end

  describe "check_resource/2" do
    test "flame_nodes within limit returns :ok" do
      assert Envelope.check_resource(:flame_nodes, 25) == :ok
      assert Envelope.check_resource(:flame_nodes, 50) == :ok
    end

    test "flame_nodes exceeding limit returns violation" do
      assert {:violation, :flame_node_limit, %{value: 51, max: 50}} =
               Envelope.check_resource(:flame_nodes, 51)
    end

    test "ram_mb within limit returns :ok" do
      assert Envelope.check_resource(:ram_mb, 16_000) == :ok
      assert Envelope.check_resource(:ram_mb, 32_000) == :ok
    end

    test "ram_mb exceeding limit returns violation" do
      assert {:violation, :ram_limit, %{value: 33_000, max: 32_000}} =
               Envelope.check_resource(:ram_mb, 33_000)
    end

    test "cpu_percent within limit returns :ok" do
      assert Envelope.check_resource(:cpu_percent, 50) == :ok
      assert Envelope.check_resource(:cpu_percent, 90) == :ok
    end

    test "cpu_percent exceeding limit returns violation" do
      assert {:violation, :cpu_limit, %{value: 95, max: 90}} =
               Envelope.check_resource(:cpu_percent, 95)
    end

    test "unknown constraint returns :ok" do
      assert Envelope.check_resource(:unknown, 999) == :ok
    end
  end

  # ============================================================
  # PHYSICAL CONSTRAINTS TESTS (SC-PHY)
  # ============================================================

  describe "physical constraint definitions" do
    test "max_pressure_delta returns 0.1" do
      assert Envelope.max_pressure_delta() == 0.1
    end

    test "max_temperature_c returns 50.0" do
      assert Envelope.max_temperature_c() == 50.0
    end

    test "min_temperature_c returns -10.0" do
      assert Envelope.min_temperature_c() == -10.0
    end

    test "max_voltage_deviation_percent returns 10.0" do
      assert Envelope.max_voltage_deviation_percent() == 10.0
    end
  end

  describe "check_physical/2" do
    test "pressure_delta within limit returns :ok" do
      assert Envelope.check_physical(:pressure_delta, 0.05) == :ok
      assert Envelope.check_physical(:pressure_delta, 0.1) == :ok
    end

    test "pressure_delta exceeding limit returns violation" do
      assert {:violation, :pressure_limit, %{value: 0.15, max: 0.1}} =
               Envelope.check_physical(:pressure_delta, 0.15)
    end

    test "temperature_c within range returns :ok" do
      assert Envelope.check_physical(:temperature_c, 25.0) == :ok
      assert Envelope.check_physical(:temperature_c, 50.0) == :ok
      assert Envelope.check_physical(:temperature_c, -10.0) == :ok
    end

    test "temperature_c too high returns violation" do
      assert {:violation, :temperature_high, %{value: 55.0, max: 50.0}} =
               Envelope.check_physical(:temperature_c, 55.0)
    end

    test "temperature_c too low returns violation" do
      assert {:violation, :temperature_low, %{value: -15.0, min: -10.0}} =
               Envelope.check_physical(:temperature_c, -15.0)
    end

    test "voltage_deviation within limit returns :ok" do
      assert Envelope.check_physical(:voltage_deviation, 5.0) == :ok
      assert Envelope.check_physical(:voltage_deviation, -5.0) == :ok
    end

    test "voltage_deviation exceeding limit returns violation" do
      assert {:violation, :voltage_deviation, %{value: 15.0, max: 10.0}} =
               Envelope.check_physical(:voltage_deviation, 15.0)
    end
  end

  # ============================================================
  # SECURITY CONSTRAINTS TESTS (SC-SEC)
  # ============================================================

  describe "security constraint definitions" do
    test "forbidden_operations returns list of dangerous operations" do
      ops = Envelope.forbidden_operations()
      assert is_list(ops)
      assert :rm_rf in ops
      assert :eval_string in ops
      assert :sudo in ops
      assert :modify_guardian in ops
    end

    test "dangerous_patterns returns list of regex patterns" do
      patterns = Envelope.dangerous_patterns()
      assert is_list(patterns)
      assert Enum.all?(patterns, &is_struct(&1, Regex))
    end

    test "allowed_network_destinations returns whitelist" do
      destinations = Envelope.allowed_network_destinations()
      assert is_list(destinations)
      assert "localhost" in destinations
      assert "127.0.0.1" in destinations
    end
  end

  describe "check_security/1" do
    test "safe code returns :ok" do
      assert Envelope.check_security("def hello, do: :world") == :ok
      assert Envelope.check_security("IO.puts(\"hello\")") == :ok
    end

    test "code with forbidden operation returns violation" do
      assert {:violation, :forbidden_operation, %{operation: :rm_rf}} =
               Envelope.check_security("rm_rf something")
    end

    test "code with dangerous pattern returns violation" do
      assert {:violation, :dangerous_pattern, _} =
               Envelope.check_security("rm -rf /")
    end

    test "code with sudo pattern returns violation" do
      # sudo is in both forbidden_operations and dangerous_patterns
      result = Envelope.check_security("sudo apt install")
      assert {:violation, violation_type, _} = result
      assert violation_type in [:forbidden_operation, :dangerous_pattern]
    end

    test "non-binary input returns :ok" do
      assert Envelope.check_security(nil) == :ok
      assert Envelope.check_security(123) == :ok
    end
  end

  describe "check_network/1" do
    test "localhost returns :ok" do
      assert Envelope.check_network("localhost") == :ok
      assert Envelope.check_network("http://localhost:4000") == :ok
    end

    test "127.0.0.1 returns :ok" do
      assert Envelope.check_network("127.0.0.1") == :ok
      assert Envelope.check_network("http://127.0.0.1:8080") == :ok
    end

    test "allowed external destinations return :ok" do
      assert Envelope.check_network("openrouter.ai") == :ok
      assert Envelope.check_network("api.anthropic.com") == :ok
    end

    test "unknown destination returns violation" do
      assert {:violation, :network_destination, _} =
               Envelope.check_network("evil-server.com")
    end

    test "non-binary input returns :ok" do
      assert Envelope.check_network(nil) == :ok
    end
  end

  # ============================================================
  # TEMPORAL CONSTRAINTS TESTS (SC-TMP)
  # ============================================================

  describe "temporal constraint definitions" do
    test "max_response_time_ms returns 50" do
      assert Envelope.max_response_time_ms() == 50
    end

    test "heartbeat_interval_ms returns 100" do
      assert Envelope.heartbeat_interval_ms() == 100
    end

    test "max_recovery_time_ms returns 5000" do
      assert Envelope.max_recovery_time_ms() == 5_000
    end
  end

  describe "check_temporal/2" do
    test "response_time within limit returns :ok" do
      assert Envelope.check_temporal(:response_time, 25) == :ok
      assert Envelope.check_temporal(:response_time, 50) == :ok
    end

    test "response_time exceeding limit returns violation" do
      assert {:violation, :response_time_limit, %{value: 60, max: 50}} =
               Envelope.check_temporal(:response_time, 60)
    end

    test "heartbeat_gap within limit returns :ok" do
      assert Envelope.check_temporal(:heartbeat_gap, 50) == :ok
      assert Envelope.check_temporal(:heartbeat_gap, 100) == :ok
    end

    test "heartbeat_gap exceeding limit returns violation" do
      assert {:violation, :heartbeat_timeout, %{value: 150, max: 100}} =
               Envelope.check_temporal(:heartbeat_gap, 150)
    end
  end

  # ============================================================
  # HEALTH CHECK TESTS
  # ============================================================

  describe "health_check/1" do
    test "healthy metrics returns healthy status" do
      metrics = %{
        flame_nodes: 25,
        ram_mb: 16_000,
        cpu_percent: 50,
        temperature_c: 25.0
      }

      result = Envelope.health_check(metrics)

      assert result.healthy == true
      assert result.violations == []
      assert result.constraints_checked > 0
    end

    test "violated metrics returns unhealthy status" do
      metrics = %{
        flame_nodes: 100,
        ram_mb: 50_000
      }

      result = Envelope.health_check(metrics)

      assert result.healthy == false
      assert length(result.violations) >= 2
    end

    test "empty metrics returns healthy status" do
      result = Envelope.health_check(%{})

      assert result.healthy == true
      assert result.violations == []
    end
  end

  # ============================================================
  # ALL CONSTRAINTS TEST
  # ============================================================

  describe "all_constraints/0" do
    test "returns comprehensive constraint map" do
      constraints = Envelope.all_constraints()

      assert is_map(constraints)
      assert Map.has_key?(constraints, :resource)
      assert Map.has_key?(constraints, :physical)
      assert Map.has_key?(constraints, :security)
      assert Map.has_key?(constraints, :temporal)
      assert Map.has_key?(constraints, :operational)
    end

    test "resource constraints are complete" do
      constraints = Envelope.all_constraints()

      assert constraints.resource.max_flame_nodes == 50
      assert constraints.resource.max_ram_mb == 32_000
    end

    test "security constraints include forbidden operations" do
      constraints = Envelope.all_constraints()

      assert is_list(constraints.security.forbidden_operations)
      assert :rm_rf in constraints.security.forbidden_operations
    end
  end
end
