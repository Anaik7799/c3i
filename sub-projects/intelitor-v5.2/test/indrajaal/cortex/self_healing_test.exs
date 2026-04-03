defmodule Indrajaal.Cortex.SelfHealingTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.Cortex.SelfHealing.
  Tests GenServer init contract and failure reporting API.
  STAMP: SC-IMMUNE-001, SC-BIO-EXT (self-healing), SC-GDE-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cortex.SelfHealing

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SelfHealing)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(SelfHealing, :start_link, 1)
      assert function_exported?(SelfHealing, :init, 1)
    end

    test "exports report_failure/1" do
      assert function_exported?(SelfHealing, :report_failure, 1)
    end
  end

  describe "start_link/1 contract" do
    test "starts process with empty opts" do
      {:ok, pid} = start_supervised({SelfHealing, []})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state is a map" do
      {:ok, pid} = start_supervised({SelfHealing, []})
      state = :sys.get_state(pid)
      assert is_map(state)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = SelfHealing.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
