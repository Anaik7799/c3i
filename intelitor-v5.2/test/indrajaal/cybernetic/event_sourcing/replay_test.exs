defmodule Indrajaal.Cybernetic.EventSourcing.ReplayTest do
  @moduledoc """
  TDG tests for Indrajaal.Cybernetic.EventSourcing.Replay GenServer.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cybernetic.EventSourcing.Replay

  describe "Replay module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Replay)
    end

    test "start_link/1 is exported" do
      assert function_exported?(Replay, :start_link, 1)
    end

    test "start_replay/1 is exported" do
      assert function_exported?(Replay, :start_replay, 1)
    end

    test "pause/1 is exported" do
      assert function_exported?(Replay, :pause, 1)
    end

    test "resume/1 is exported" do
      assert function_exported?(Replay, :resume, 1)
    end

    test "stop/1 is exported" do
      assert function_exported?(Replay, :stop, 1)
    end

    test "status/1 is exported" do
      assert function_exported?(Replay, :status, 1)
    end

    test "step/1 is exported" do
      assert function_exported?(Replay, :step, 1)
    end

    test "instant_replay/3 is exported" do
      assert function_exported?(Replay, :instant_replay, 3)
    end
  end

  describe "Replay child_spec" do
    test "has child_spec/1" do
      assert function_exported?(Replay, :child_spec, 1)
    end
  end

  describe "Replay GenServer start" do
    test "can start a replay server with unique name" do
      name = :"replay_test_#{System.unique_integer([:positive])}"
      result = start_supervised({Replay, [name: name]})
      assert {:ok, _pid} = result
    end
  end
end
