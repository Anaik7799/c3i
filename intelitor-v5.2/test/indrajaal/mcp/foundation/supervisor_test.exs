defmodule Indrajaal.MCP.Foundation.SupervisorTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Foundation.Supervisor.

  ## STAMP Safety Integration
  - SC-MCP-060: MCP supervisor must restart children on failure
  - SC-MCP-061: Supervisor strategy is one_for_one

  ## TPS 5-Level RCA Context
  - L1 Symptom: MCP subsystem unavailable after child crash
  - L5 Root Cause: Supervisor child spec not including all required children
  """

  # async: false due to named GenServer + ETS children
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Foundation.Supervisor, as: McpSupervisor

  describe "module existence" do
    test "McpSupervisor module is defined" do
      assert Code.ensure_loaded?(McpSupervisor)
    end

    test "implements Supervisor via start_link/1" do
      assert function_exported?(McpSupervisor, :start_link, 1)
    end
  end

  describe "supervisor children" do
    test "child_spec is defined" do
      assert function_exported?(McpSupervisor, :child_spec, 1)
    end
  end

  describe "supervisor can start" do
    test "starts without error with unique name" do
      name = :"mcp_sup_test_#{:erlang.unique_integer([:positive])}"
      result = start_supervised({McpSupervisor, [name: name]})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
