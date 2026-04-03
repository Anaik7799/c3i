defmodule Indrajaal.Observability.InstrumentationHealthTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.InstrumentationHealth.

  ## STAMP Safety Integration
  - SC-OBS-001: Observability instrumentation must be verified at startup

  ## TPS 5-Level RCA Context
  - L1 Symptom: Silent observability gaps in production
  - L5 Root Cause: Missing health verification for OTEL pipeline
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.InstrumentationHealth

  describe "verify_instrumentation/0" do
    test "returns :ok or {:error, list}" do
      result = InstrumentationHealth.verify_instrumentation()
      assert result == :ok or match?({:error, _}, result)
    end

    test "returns a valid shape" do
      case InstrumentationHealth.verify_instrumentation() do
        :ok -> assert true
        {:error, failed_list} -> assert is_list(failed_list)
      end
    end
  end

  describe "verify_core_observability/0" do
    test "returns :ok or {:error, list}" do
      result = InstrumentationHealth.verify_core_observability()
      assert result == :ok or match?({:error, _}, result)
    end

    test "on error, returns list of failed modules" do
      case InstrumentationHealth.verify_core_observability() do
        :ok -> assert true
        {:error, failed} -> assert is_list(failed)
      end
    end
  end

  describe "verify_all/0" do
    test "returns :ok or {:error, map}" do
      result = InstrumentationHealth.verify_all()
      assert result == :ok or match?({:error, %{}}, result)
    end

    test "error map has expected keys when degraded" do
      case InstrumentationHealth.verify_all() do
        :ok ->
          assert true

        {:error, errors} ->
          assert is_map(errors)
          assert Map.has_key?(errors, :instrumentation)
          assert Map.has_key?(errors, :core_modules)
      end
    end
  end

  describe "health_status/0" do
    test "returns a map" do
      result = InstrumentationHealth.health_status()
      assert is_map(result)
    end

    test "has status field" do
      result = InstrumentationHealth.health_status()
      assert Map.has_key?(result, :status)
    end

    test "status is :healthy or :degraded" do
      result = InstrumentationHealth.health_status()
      assert result.status in [:healthy, :degraded]
    end

    test "has instrumentation field" do
      result = InstrumentationHealth.health_status()
      assert Map.has_key?(result, :instrumentation)
      assert is_map(result.instrumentation)
    end

    test "has core_observability field" do
      result = InstrumentationHealth.health_status()
      assert Map.has_key?(result, :core_observability)
      assert is_map(result.core_observability)
    end

    test "has checked_at timestamp" do
      result = InstrumentationHealth.health_status()
      assert Map.has_key?(result, :checked_at)
      assert %DateTime{} = result.checked_at
    end

    test "instrumentation has modules list" do
      result = InstrumentationHealth.health_status()
      assert is_list(result.instrumentation.modules)
    end

    test "each module entry has loaded boolean" do
      result = InstrumentationHealth.health_status()

      Enum.each(result.instrumentation.modules, fn mod_entry ->
        assert Map.has_key?(mod_entry, :loaded)
        assert is_boolean(mod_entry.loaded)
      end)
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.InstrumentationHealth)
    end

    test "verify_instrumentation/0 exported" do
      assert function_exported?(InstrumentationHealth, :verify_instrumentation, 0)
    end

    test "verify_core_observability/0 exported" do
      assert function_exported?(InstrumentationHealth, :verify_core_observability, 0)
    end

    test "verify_all/0 exported" do
      assert function_exported?(InstrumentationHealth, :verify_all, 0)
    end

    test "health_status/0 exported" do
      assert function_exported?(InstrumentationHealth, :health_status, 0)
    end

    test "start_link/1 exported" do
      assert function_exported?(InstrumentationHealth, :start_link, 1)
    end
  end
end
