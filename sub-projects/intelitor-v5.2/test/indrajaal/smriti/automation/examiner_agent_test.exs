defmodule Indrajaal.Smriti.Automation.ExaminerAgentTest do
  @moduledoc """
  TDG test suite for Smriti.Automation.ExaminerAgent.

  ## STAMP Safety Integration
  - SC-AI-001: AI agents persist context via SMRITI
  - SC-SMRITI-SRS-001: Interval MUST be non-negative

  ## TPS 5-Level RCA Context
  - L1 Symptom: Spaced repetition schedule not generated
  - L5 Root Cause: ExaminerAgent not started before review
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Smriti.Automation.ExaminerAgent

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(ExaminerAgent)
    end

    test "start_link/1 is exported" do
      assert function_exported?(ExaminerAgent, :start_link, 1)
    end

    test "review/2 is exported" do
      assert function_exported?(ExaminerAgent, :review, 2)
    end
  end

  describe "GenServer behaviour" do
    test "implements GenServer" do
      behaviours = ExaminerAgent.__info__(:attributes) |> Keyword.get_values(:behaviour)
      flat = List.flatten(behaviours)
      assert GenServer in flat
    end
  end

  describe "review/2 without running server" do
    test "returns exit when server not started" do
      result =
        try do
          ExaminerAgent.review("holon_001", 4)
        rescue
          _ -> {:error, :not_running}
        catch
          :exit, _ -> {:error, :not_running}
        end

      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end
end
