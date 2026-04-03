defmodule Indrajaal.Cluster.Capabilities.BehaviourTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Capabilities.Behaviour

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Behaviour)
    end
  end

  describe "behaviour callbacks" do
    test "defines capability_type/0 callback" do
      callbacks = Behaviour.behaviour_info(:callbacks)
      assert {:capability_type, 0} in callbacks
    end

    test "defines available?/0 callback" do
      callbacks = Behaviour.behaviour_info(:callbacks)
      assert {:available?, 0} in callbacks
    end

    test "defines status/0 callback" do
      callbacks = Behaviour.behaviour_info(:callbacks)
      assert {:status, 0} in callbacks
    end

    test "behaviour_info/1 returns callbacks list" do
      callbacks = Behaviour.behaviour_info(:callbacks)
      assert is_list(callbacks)
      assert length(callbacks) >= 3
    end
  end
end
