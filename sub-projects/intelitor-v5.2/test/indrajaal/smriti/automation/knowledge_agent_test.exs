defmodule Indrajaal.SMRITI.Automation.KnowledgeAgentTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Automation.KnowledgeAgent

  describe "Knowledge Agent OODA" do
    test "executes OODA loop cycle" do
      input = %{observation: "high_latency"}
      result = KnowledgeAgent.cycle(input)

      assert result.phase == :act
      assert result.decision == :scale_up
    end

    test "learns from history" do
      history = [%{observation: "low_load", decision: :scale_down}]
      agent = KnowledgeAgent.new(history)
      assert agent.history_count == 1
    end
  end
end
