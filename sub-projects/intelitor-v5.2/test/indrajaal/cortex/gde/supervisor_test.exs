defmodule Indrajaal.Cortex.GDE.SupervisorTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.GDE.Supervisor.
  Tests OTP Supervisor contract and child_spec.
  STAMP: SC-GDE-001, SC-COG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.GDE.Supervisor, as: GDESupervisor

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(GDESupervisor)
    end

    test "implements Supervisor behaviour" do
      assert function_exported?(GDESupervisor, :start_link, 1)
      assert function_exported?(GDESupervisor, :init, 1)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec map" do
      spec = GDESupervisor.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end

    test "child spec type is supervisor" do
      spec = GDESupervisor.child_spec([])
      assert Map.get(spec, :type) == :supervisor
    end
  end

  describe "public API" do
    test "exports status/0" do
      assert function_exported?(GDESupervisor, :status, 0)
    end

    test "exports combined_stats/0" do
      assert function_exported?(GDESupervisor, :combined_stats, 0)
    end
  end

  describe "start_link/1 contract" do
    test "starts a supervisor process" do
      {:ok, pid} = start_supervised({GDESupervisor, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end
end
