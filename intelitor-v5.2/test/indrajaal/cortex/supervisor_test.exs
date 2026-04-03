defmodule Indrajaal.Cortex.SupervisorTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.Supervisor.
  Tests OTP Supervisor contract and child_spec.
  STAMP: SC-COG-001, SC-GDE-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.Supervisor, as: CortexSupervisor

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(CortexSupervisor)
    end

    test "implements Supervisor behaviour" do
      assert function_exported?(CortexSupervisor, :start_link, 1)
      assert function_exported?(CortexSupervisor, :init, 1)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec map" do
      spec = CortexSupervisor.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end

    test "child spec type is supervisor" do
      spec = CortexSupervisor.child_spec([])
      assert Map.get(spec, :type) == :supervisor
    end
  end

  describe "start_link/1 contract" do
    test "starts a supervisor process" do
      {:ok, pid} = start_supervised({CortexSupervisor, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end
end
