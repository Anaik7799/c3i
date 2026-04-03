defmodule Indrajaal.KMS.Agents.KnowledgeAgentTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Agents.KnowledgeAgent.
  Tests GenServer init contract. OODA loop is scheduled internally.
  STAMP: SC-COG-001, SC-AI-001 (AI agents persist context via SMRITI)
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Agents.KnowledgeAgent

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(KnowledgeAgent)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(KnowledgeAgent, :start_link, 1)
      assert function_exported?(KnowledgeAgent, :init, 1)
    end
  end

  describe "child_spec/1" do
    test "returns valid child spec" do
      spec = KnowledgeAgent.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
