defmodule Indrajaal.Distributed.Agents.CortexAgentTest do
  @moduledoc """
  TDG tests for Indrajaal.Distributed.Agents.CortexAgent.

  Tests the Cortex (Cognitive Control) agent.
  Uses async: false because CortexAgent registers under module name.
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Agents.CortexAgent

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(CortexAgent)
    end

    test "start_link/1 is exported" do
      assert function_exported?(CortexAgent, :start_link, 1)
    end
  end

  describe "start_link/1" do
    test "starts cortex agent process" do
      {:ok, pid} = start_supervised({CortexAgent, []})
      assert is_pid(pid)
    end

    test "started process is alive" do
      {:ok, pid} = start_supervised({CortexAgent, []})
      assert Process.alive?(pid)
    end
  end
end
