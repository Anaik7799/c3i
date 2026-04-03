defmodule Indrajaal.Smriti.Senses.SupervisorTest do
  @moduledoc """
  TDG test suite for Smriti.Senses.Supervisor.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-FUNC-001: System MUST compile at all times

  ## TPS 5-Level RCA Context
  - L1 Symptom: Senses supervisor fails to start
  - L5 Root Cause: Missing child spec validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Senses.Supervisor, as: SensesSupervisor

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SensesSupervisor)
    end

    test "start_link/1 is exported" do
      assert function_exported?(SensesSupervisor, :start_link, 1)
    end
  end

  describe "supervisor behaviour" do
    test "module uses Supervisor behaviour" do
      behaviours =
        SensesSupervisor.__info__(:attributes) |> Keyword.get_values(:behaviour)

      flat = List.flatten(behaviours)
      assert Supervisor in flat
    end
  end

  describe "child specifications" do
    test "child_spec/1 returns valid supervisor spec" do
      spec = SensesSupervisor.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
