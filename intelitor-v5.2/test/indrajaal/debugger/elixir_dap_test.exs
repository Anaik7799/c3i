defmodule Indrajaal.Debugger.ElixirDapTest do
  @moduledoc """
  TDG tests for Indrajaal.Debugger.ElixirDap GenServer.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Debugger.ElixirDap

  describe "ElixirDap module" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ElixirDap)
    end

    test "start_link/1 is exported" do
      assert function_exported?(ElixirDap, :start_link, 1)
    end

    test "start_session/1 is exported" do
      assert function_exported?(ElixirDap, :start_session, 1)
    end

    test "stop_session/1 is exported" do
      assert function_exported?(ElixirDap, :stop_session, 1)
    end

    test "set_breakpoint/3 is exported" do
      assert function_exported?(ElixirDap, :set_breakpoint, 3)
    end

    test "remove_breakpoint/1 is exported" do
      assert function_exported?(ElixirDap, :remove_breakpoint, 1)
    end

    test "list_breakpoints/0 is exported" do
      assert function_exported?(ElixirDap, :list_breakpoints, 0)
    end

    test "continue/1 is exported" do
      assert function_exported?(ElixirDap, :continue, 1)
    end

    test "step_over/1 is exported" do
      assert function_exported?(ElixirDap, :step_over, 1)
    end

    test "step_into/1 is exported" do
      assert function_exported?(ElixirDap, :step_into, 1)
    end

    test "step_out/1 is exported" do
      assert function_exported?(ElixirDap, :step_out, 1)
    end

    test "inspect_variable/2 is exported" do
      assert function_exported?(ElixirDap, :inspect_variable, 2)
    end

    test "get_stack_trace/1 is exported" do
      assert function_exported?(ElixirDap, :get_stack_trace, 1)
    end

    test "evaluate/2 is exported" do
      assert function_exported?(ElixirDap, :evaluate, 2)
    end
  end

  describe "ElixirDap child_spec" do
    test "has child_spec/1" do
      assert function_exported?(ElixirDap, :child_spec, 1)
    end
  end

  describe "ElixirDap GenServer start" do
    test "can start with unique name" do
      name = :"elixir_dap_test_#{System.unique_integer([:positive])}"
      result = start_supervised({ElixirDap, [name: name]})
      assert {:ok, _pid} = result
    end

    test "list_breakpoints/0 returns list when running" do
      name = :"elixir_dap_bp_#{System.unique_integer([:positive])}"
      {:ok, _pid} = start_supervised({ElixirDap, [name: name]})
      breakpoints = ElixirDap.list_breakpoints()
      assert is_list(breakpoints)
    end
  end
end
