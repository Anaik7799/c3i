defmodule Indrajaal.Observability.DirectedTelescopeTest do
  @moduledoc """
  TDG test suite for Indrajaal.Observability.DirectedTelescope.

  ## STAMP Safety Integration
  - SC-OBS-DT-001: Directed telescope enables deep-dive RCA

  ## TPS 5-Level RCA Context
  - L1 Symptom: No targeted observation capability during incidents
  - L5 Root Cause: Blind root cause analysis in production
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.DirectedTelescope

  describe "inspect_holon/1" do
    test "returns {:error, :not_found} for non-existent process" do
      result = DirectedTelescope.inspect_holon(:NonExistentProcess)
      assert result == {:error, :not_found}
    end

    test "returns {:ok, map} for existing registered process" do
      # Use a real registered process
      case GenServer.whereis(Indrajaal.Observability.FractalLogger) do
        nil ->
          # Process not running, expected error
          result = DirectedTelescope.inspect_holon(:FractalLogger)
          assert result == {:error, :not_found}

        _pid ->
          result = DirectedTelescope.inspect_holon(Indrajaal.Observability.FractalLogger)
          assert match?({:ok, _}, result)
      end
    end
  end

  describe "trace_process/2" do
    test "returns {:error, :not_found} for non-existent atom name" do
      result = DirectedTelescope.trace_process(:NonExistentForTrace, 5)
      assert result == {:error, :not_found}
    end

    test "returns :ok for valid pid" do
      {:ok, pid} = Task.start(fn -> Process.sleep(500) end)
      result = DirectedTelescope.trace_process(pid, 3)
      assert result == :ok
      Process.exit(pid, :kill)
    end
  end

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Indrajaal.Observability.DirectedTelescope)
    end

    test "zoom_zenoh/1 exported" do
      assert function_exported?(DirectedTelescope, :zoom_zenoh, 1)
    end

    test "zoom_zenoh/2 exported" do
      assert function_exported?(DirectedTelescope, :zoom_zenoh, 2)
    end

    test "inspect_holon/1 exported" do
      assert function_exported?(DirectedTelescope, :inspect_holon, 1)
    end

    test "trace_process/1 exported" do
      assert function_exported?(DirectedTelescope, :trace_process, 1)
    end

    test "trace_process/2 exported" do
      assert function_exported?(DirectedTelescope, :trace_process, 2)
    end

    test "comprehensive_snapshot/0 exported" do
      assert function_exported?(DirectedTelescope, :comprehensive_snapshot, 0)
    end
  end
end
