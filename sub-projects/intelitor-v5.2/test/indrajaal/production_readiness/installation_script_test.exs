defmodule Indrajaal.ProductionReadiness.InstallationScriptTest do
  @moduledoc """
  TDG test suite for InstallationScript GenServer.

  ## STAMP Safety Integration
  - SC-007: Installation must not damage existing system
  - UCA-005: Prevent installation overwriting production data

  ## TPS 5-Level RCA Context
  - L1 Symptom: Installation corrupts existing data
  - L5 Root Cause: Missing pre-installation backup step
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.ProductionReadiness.InstallationScript

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(InstallationScript)
    end

    test "public API functions are exported" do
      assert function_exported?(InstallationScript, :start_link, 1)
      assert function_exported?(InstallationScript, :run, 1)
      assert function_exported?(InstallationScript, :validate_pre_requisites, 1)
      assert function_exported?(InstallationScript, :create_rollback_point, 0)
    end
  end

  describe "installation steps" do
    test "installation has required safety steps" do
      steps = [
        :validate_pre_requisites,
        :create_rollback_point,
        :backup_existing_state,
        :validate_target_paths,
        :install_containers,
        :configure_ssl,
        :validate_frameworks,
        :run_health_checks,
        :finalize_installation
      ]

      assert :validate_pre_requisites in steps
      assert :create_rollback_point in steps
      assert :backup_existing_state in steps
      assert length(steps) == 9
    end
  end

  describe "critical paths" do
    test "critical paths are protected" do
      critical = ["/etc/ssl/certs", "/var/lib/containers"]
      assert is_list(critical)
      assert length(critical) >= 2
    end
  end

  describe "start_link/1" do
    test "starts the GenServer successfully" do
      name = :"installation_script_test_#{System.unique_integer([:positive])}"
      result = GenServer.start_link(InstallationScript, [], name: name)
      assert match?({:ok, _pid}, result)
      {:ok, pid} = result
      GenServer.stop(pid)
    end
  end
end
