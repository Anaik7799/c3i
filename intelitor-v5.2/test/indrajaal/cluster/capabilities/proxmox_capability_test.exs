defmodule Indrajaal.Cluster.Capabilities.ProxmoxCapabilityTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Capabilities.ProxmoxCapability

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ProxmoxCapability)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(ProxmoxCapability, :start_link, 1)
    end

    test "defines create_vm/2" do
      assert function_exported?(ProxmoxCapability, :create_vm, 2)
    end

    test "defines start_vm/1" do
      assert function_exported?(ProxmoxCapability, :start_vm, 1)
    end

    test "defines stop_vm/1" do
      assert function_exported?(ProxmoxCapability, :stop_vm, 1)
    end

    test "defines delete_vm/1" do
      assert function_exported?(ProxmoxCapability, :delete_vm, 1)
    end

    test "defines vm_status/1" do
      assert function_exported?(ProxmoxCapability, :vm_status, 1)
    end

    test "defines list_vms/0" do
      assert function_exported?(ProxmoxCapability, :list_vms, 0)
    end

    test "defines get_vm_node/1" do
      assert function_exported?(ProxmoxCapability, :get_vm_node, 1)
    end

    test "defines pve_available?/0" do
      assert function_exported?(ProxmoxCapability, :pve_available?, 0)
    end

    test "defines status/0" do
      assert function_exported?(ProxmoxCapability, :status, 0)
    end

    test "defines capability_type/0" do
      assert function_exported?(ProxmoxCapability, :capability_type, 0)
    end

    test "defines available?/0" do
      assert function_exported?(ProxmoxCapability, :available?, 0)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(ProxmoxCapability, :child_spec, 1)
    end
  end
end
