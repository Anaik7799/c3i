defmodule Indrajaal.Distributed.Agents.AceAgentTest do
  @moduledoc """
  TDG tests for Indrajaal.Distributed.Agents.AceAgent.

  Tests the ACE (Autonomic Compute Engine) agent.
  Uses async: false because AceAgent registers under module name.
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Distributed.Agents.AceAgent

  describe "module definition" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(AceAgent)
    end

    test "start_link/1 is exported" do
      assert function_exported?(AceAgent, :start_link, 1)
    end
  end

  describe "start_link/1" do
    test "starts ace agent process" do
      {:ok, pid} = start_supervised({AceAgent, []})
      assert is_pid(pid)
    end

    test "started process is alive" do
      {:ok, pid} = start_supervised({AceAgent, []})
      assert Process.alive?(pid)
    end
  end
end
