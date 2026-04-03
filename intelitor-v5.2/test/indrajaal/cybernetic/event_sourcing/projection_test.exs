defmodule Indrajaal.Cybernetic.EventSourcing.ProjectionTest do
  @moduledoc """
  TDG tests for Indrajaal.Cybernetic.EventSourcing.Projection GenServer.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cybernetic.EventSourcing.Projection

  describe "Projection module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Projection)
    end

    test "start_link/1 is exported" do
      assert function_exported?(Projection, :start_link, 1)
    end

    test "create/1 is exported" do
      assert function_exported?(Projection, :create, 1)
    end

    test "get_state/1 is exported" do
      assert function_exported?(Projection, :get_state, 1)
    end

    test "get_info/1 is exported" do
      assert function_exported?(Projection, :get_info, 1)
    end

    test "pause/1 is exported" do
      assert function_exported?(Projection, :pause, 1)
    end

    test "resume/1 is exported" do
      assert function_exported?(Projection, :resume, 1)
    end

    test "rebuild/1 is exported" do
      assert function_exported?(Projection, :rebuild, 1)
    end

    test "delete/1 is exported" do
      assert function_exported?(Projection, :delete, 1)
    end

    test "list/0 is exported" do
      assert function_exported?(Projection, :list, 0)
    end

    test "lag/1 is exported" do
      assert function_exported?(Projection, :lag, 1)
    end
  end

  describe "Projection child_spec" do
    test "has child_spec/1" do
      assert function_exported?(Projection, :child_spec, 1)
    end
  end

  describe "Projection GenServer start" do
    test "can start a projection with unique name" do
      name = :"projection_test_#{System.unique_integer([:positive])}"
      result = start_supervised({Projection, [name: name]})
      assert {:ok, _pid} = result
    end

    test "list/0 returns a list" do
      result = Projection.list()
      assert is_list(result)
    end
  end
end
