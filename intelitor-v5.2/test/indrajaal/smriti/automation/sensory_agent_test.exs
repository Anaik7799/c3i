defmodule Indrajaal.Smriti.Automation.SensoryAgentTest do
  @moduledoc """
  TDG test suite for Smriti.Automation.SensoryAgent.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-SENS-001: Non-blocking polling required

  ## TPS 5-Level RCA Context
  - L1 Symptom: Content type detection fails
  - L5 Root Cause: GenServer uses module name — conflicts in parallel tests
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Automation.SensoryAgent

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(SensoryAgent)
    end

    test "start_link/1 is exported" do
      assert function_exported?(SensoryAgent, :start_link, 1)
    end

    test "process/2 is exported" do
      assert function_exported?(SensoryAgent, :process, 2)
    end
  end

  describe "GenServer behaviour" do
    test "implements GenServer" do
      behaviours = SensoryAgent.__info__(:attributes) |> Keyword.get_values(:behaviour)
      flat = List.flatten(behaviours)
      assert GenServer in flat
    end
  end
end
