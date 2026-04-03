defmodule Indrajaal.Cluster.Capabilities.ContainerCapabilityTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Capabilities.ContainerCapability

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ContainerCapability)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(ContainerCapability, :start_link, 1)
    end

    test "defines start_container/2" do
      assert function_exported?(ContainerCapability, :start_container, 2)
    end

    test "defines stop_container/1" do
      assert function_exported?(ContainerCapability, :stop_container, 1)
    end

    test "defines container_status/1" do
      assert function_exported?(ContainerCapability, :container_status, 1)
    end

    test "defines list_containers/0" do
      assert function_exported?(ContainerCapability, :list_containers, 0)
    end

    test "defines get_container_node/1" do
      assert function_exported?(ContainerCapability, :get_container_node, 1)
    end

    test "defines podman_available?/0" do
      assert function_exported?(ContainerCapability, :podman_available?, 0)
    end

    test "defines status/0" do
      assert function_exported?(ContainerCapability, :status, 0)
    end

    test "defines capability_type/0" do
      assert function_exported?(ContainerCapability, :capability_type, 0)
    end

    test "defines available?/0" do
      assert function_exported?(ContainerCapability, :available?, 0)
    end
  end

  describe "behaviour implementation" do
    test "implements Behaviour callbacks via GenServer" do
      assert function_exported?(ContainerCapability, :capability_type, 0)
      assert function_exported?(ContainerCapability, :available?, 0)
      assert function_exported?(ContainerCapability, :status, 0)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(ContainerCapability, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = ContainerCapability.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end
end
