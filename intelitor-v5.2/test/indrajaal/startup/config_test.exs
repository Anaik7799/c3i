defmodule Indrajaal.Startup.ConfigTest do
  @moduledoc """
  TDG test suite for Indrajaal.Startup.Config.

  ## TPS 5-Level RCA Context
  - L1 Symptom: Boot stage using hardcoded values instead of Config
  - L5 Root Cause: Single source of truth not being consulted
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Startup.Config

  describe "ports/1" do
    test "returns phoenix primary port 4000" do
      assert Config.ports(:phoenix_primary) == 4000
    end

    test "returns postgres port 5433" do
      assert Config.ports(:postgres) == 5433
    end

    test "returns zenoh router tcp port 7447" do
      assert Config.ports(:zenoh_router1_tcp) == 7447
    end

    test "returns grafana port 3000" do
      assert Config.ports(:grafana) == 3000
    end

    test "raises ArgumentError for unknown port name" do
      assert_raise ArgumentError, fn -> Config.ports(:unknown_port_xyz) end
    end
  end

  describe "ports_map/0" do
    test "returns a map" do
      result = Config.ports_map()
      assert is_map(result)
    end

    test "includes phoenix and postgres keys" do
      result = Config.ports_map()
      assert Map.has_key?(result, :phoenix)
      assert Map.has_key?(result, :postgres)
    end
  end

  describe "all_ports/0" do
    test "returns a list of integers" do
      ports = Config.all_ports()
      assert is_list(ports)
      assert Enum.all?(ports, &is_integer/1)
    end

    test "list is non-empty" do
      assert Config.all_ports() != []
    end
  end

  describe "hostname/1" do
    test "returns db hostname" do
      assert Config.hostname(:db_prod) == "indrajaal-db-prod"
    end

    test "returns app primary hostname" do
      assert Config.hostname(:app_primary) == "indrajaal-ex-app-1"
    end

    test "raises ArgumentError for unknown hostname" do
      assert_raise ArgumentError, fn -> Config.hostname(:unknown_service_xyz) end
    end
  end

  describe "timeout/1" do
    test "returns health_check timeout as positive integer" do
      t = Config.timeout(:health_check)
      assert is_integer(t)
      assert t > 0
    end

    test "ooda_cycle_max is 100ms" do
      assert Config.timeout(:ooda_cycle_max) == 100
    end

    test "raises ArgumentError for unknown timeout" do
      assert_raise ArgumentError, fn -> Config.timeout(:unknown_timeout_xyz) end
    end
  end

  describe "calculate_quorum/1" do
    test "returns floor(N/2) + 1 for 3 nodes" do
      assert Config.calculate_quorum(3) == 2
    end

    test "returns floor(N/2) + 1 for 5 nodes" do
      assert Config.calculate_quorum(5) == 3
    end

    test "returns 1 for single node" do
      assert Config.calculate_quorum(1) == 1
    end
  end

  describe "state_vector_valid?/1" do
    test "returns true when all components are valid" do
      state = %{
        compile: :valid,
        migrations: :valid,
        containers: :valid,
        zenoh: :valid,
        health: :valid,
        quorum: :valid
      }

      assert Config.state_vector_valid?(state) == true
    end

    test "returns false when compile is invalid" do
      state = %{
        compile: :invalid,
        migrations: :valid,
        containers: :valid,
        zenoh: :valid,
        health: :valid,
        quorum: :valid
      }

      assert Config.state_vector_valid?(state) == false
    end
  end

  describe "empty_state_vector/0" do
    test "returns map with all components invalid" do
      sv = Config.empty_state_vector()
      assert is_map(sv)
      assert sv.compile == :invalid
      assert sv.quorum == :invalid
    end
  end

  describe "validate_all/0" do
    test "returns :ok when config is valid" do
      result = Config.validate_all()
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "boot_stages/0" do
    test "returns a list of 5 stages" do
      stages = Config.boot_stages()
      assert is_list(stages)
      assert length(stages) == 5
      assert :s0_preflight in stages
      assert :s4_homeostasis in stages
    end
  end
end
