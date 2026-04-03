defmodule Indrajaal.Compute.FlameSupervisorTest do
  @moduledoc """
  TDG test suite for Indrajaal.Compute.FlameSupervisor.
  STAMP: SC-DB-001
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compute.FlameSupervisor

  describe "module attributes" do
    test "is a module" do
      assert is_atom(FlameSupervisor)
    end

    test "defines child_spec/1" do
      assert function_exported?(FlameSupervisor, :child_spec, 1)
    end

    test "defines start_link/1" do
      assert function_exported?(FlameSupervisor, :start_link, 1)
    end
  end

  describe "supervisor behaviour" do
    test "is a Supervisor behaviour", %{test: test} do
      name = :"flame_sup_#{test}"
      pid = start_supervised!({FlameSupervisor, name: name})
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "starts with no active children", %{test: test} do
      name = :"flame_sup_#{test}"
      start_supervised!({FlameSupervisor, name: name})
      children = Supervisor.which_children(name)
      assert is_list(children)
    end

    test "children count is zero initially", %{test: test} do
      name = :"flame_sup_#{test}"
      start_supervised!({FlameSupervisor, name: name})
      assert Supervisor.count_children(name).active == 0
    end
  end
end
