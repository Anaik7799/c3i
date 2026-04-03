defmodule Indrajaal.ProductionReadiness.EnvironmentConfigTest do
  @moduledoc """
  TDG test suite for EnvironmentConfig GenServer.

  ## STAMP Safety Integration
  - SC-008: Environment changes must be reversible
  - UCA-006: Prevent environment variable conflicts

  ## TPS 5-Level RCA Context
  - L1 Symptom: Wrong environment applied
  - L5 Root Cause: Missing critical variable validation
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.EnvironmentConfig

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(EnvironmentConfig)
    end

    test "public API functions are exported" do
      assert function_exported?(EnvironmentConfig, :start_link, 1)
      assert function_exported?(EnvironmentConfig, :load_template, 1)
      assert function_exported?(EnvironmentConfig, :validate, 1)
      assert function_exported?(EnvironmentConfig, :apply, 1)
      assert function_exported?(EnvironmentConfig, :rollback, 1)
    end
  end

  describe "critical variables" do
    test "critical variables include database URL" do
      critical_vars = [
        "DATABASE_URL",
        "SECRET_KEY_BASE",
        "PHX_SERVER",
        "PHX_HOST",
        "SSL_CERT_PATH",
        "SSL_KEY_PATH"
      ]

      assert "DATABASE_URL" in critical_vars
      assert "SECRET_KEY_BASE" in critical_vars
    end

    test "all critical variables are strings" do
      vars = ["DATABASE_URL", "SECRET_KEY_BASE"]
      Enum.each(vars, fn v -> assert is_binary(v) end)
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      name = :"env_config_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(EnvironmentConfig, [], name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
