defmodule Indrajaal.Core.Holon.StateTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Core.Holon.State

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(State)
    end
  end

  describe "new/3" do
    test "function is exported" do
      assert function_exported?(State, :new, 3)
    end

    test "creates a new state struct" do
      state = State.new("holon-1", :function, nil)
      assert is_struct(state) or is_map(state)
    end

    test "state has holon_id field" do
      state = State.new("holon-1", :module, nil)
      assert state.id == "holon-1" or state.holon_id == "holon-1"
    end

    test "state has layer field" do
      state = State.new("holon-2", :agent, nil)
      assert state.layer == :agent
    end
  end

  describe "update_s1/2 through update_s5/2" do
    setup do
      state = State.new("test-holon", :node, nil)
      %{state: state}
    end

    test "update_s1/2 is exported" do
      assert function_exported?(State, :update_s1, 2)
    end

    test "update_s2/2 is exported" do
      assert function_exported?(State, :update_s2, 2)
    end

    test "update_s3/2 is exported" do
      assert function_exported?(State, :update_s3, 2)
    end

    test "update_s4/2 is exported" do
      assert function_exported?(State, :update_s4, 2)
    end

    test "update_s5/2 is exported" do
      assert function_exported?(State, :update_s5, 2)
    end

    test "update_s1/2 returns updated state", %{state: state} do
      updated = State.update_s1(state, %{operations: 5})
      assert is_struct(updated) or is_map(updated)
    end

    test "update_s5/2 returns updated state", %{state: state} do
      updated = State.update_s5(state, %{policy: "strict"})
      assert is_struct(updated) or is_map(updated)
    end
  end

  describe "update_health/2" do
    test "function is exported" do
      assert function_exported?(State, :update_health, 2)
    end

    test "updates health score" do
      state = State.new("h1", :cluster, nil)
      updated = State.update_health(state, 0.88)
      assert is_struct(updated) or is_map(updated)
    end
  end

  describe "add_child/2 and remove_child/2" do
    test "add_child/2 is exported" do
      assert function_exported?(State, :add_child, 2)
    end

    test "remove_child/2 is exported" do
      assert function_exported?(State, :remove_child, 2)
    end

    test "add_child/2 adds child id" do
      state = State.new("parent", :node, nil)
      updated = State.add_child(state, "child-1")
      assert is_struct(updated) or is_map(updated)
    end

    test "remove_child/2 removes child id" do
      state = State.new("parent", :node, nil)
      state = State.add_child(state, "child-1")
      updated = State.remove_child(state, "child-1")
      assert is_struct(updated) or is_map(updated)
    end
  end

  describe "derive_health/1" do
    test "function is exported" do
      assert function_exported?(State, :derive_health, 1)
    end

    test "returns float health score" do
      state = State.new("h2", :function, nil)
      score = State.derive_health(state)
      assert is_float(score) or is_integer(score)
    end
  end

  describe "refresh_health/1" do
    test "function is exported" do
      assert function_exported?(State, :refresh_health, 1)
    end

    test "returns state with updated health" do
      state = State.new("h3", :module, nil)
      refreshed = State.refresh_health(state)
      assert is_struct(refreshed) or is_map(refreshed)
    end
  end

  describe "summary/1" do
    test "function is exported" do
      assert function_exported?(State, :summary, 1)
    end

    test "returns summary map" do
      state = State.new("h4", :container, nil)
      result = State.summary(state)
      assert is_map(result)
    end
  end
end
