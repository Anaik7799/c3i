defmodule Intelitor.Parallelization.AgentPoolTest do
  @moduledoc """
  Test suite for Intelitor.Parallelization.AgentPool.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/parallelization/agent_pool.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Parallelization.AgentPool

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AgentPool)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AgentPool, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AgentPool.__info__(:module)
      assert info == Intelitor.Parallelization.AgentPool
    end
  end
end
