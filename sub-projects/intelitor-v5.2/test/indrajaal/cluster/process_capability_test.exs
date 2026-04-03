defmodule Indrajaal.Cluster.ProcessCapabilityTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.ProcessCapability

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ProcessCapability)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(ProcessCapability, :start_link, 1)
    end

    test "defines network_mode/0" do
      assert function_exported?(ProcessCapability, :network_mode, 0)
    end

    test "defines get_node_name/0" do
      assert function_exported?(ProcessCapability, :get_node_name, 0)
    end

    test "defines resolve_node/1" do
      assert function_exported?(ProcessCapability, :resolve_node, 1)
    end

    test "defines generate_capability/0" do
      assert function_exported?(ProcessCapability, :generate_capability, 0)
    end

    test "defines validate_capability/1" do
      assert function_exported?(ProcessCapability, :validate_capability, 1)
    end

    test "defines tailscale_available?/0" do
      assert function_exported?(ProcessCapability, :tailscale_available?, 0)
    end

    test "defines health_check/0" do
      assert function_exported?(ProcessCapability, :health_check, 0)
    end

    test "defines status/0" do
      assert function_exported?(ProcessCapability, :status, 0)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(ProcessCapability, :child_spec, 1)
    end
  end

  describe "FlameBackend nested module" do
    test "FlameBackend module exists" do
      assert Code.ensure_loaded?(Indrajaal.Cluster.ProcessCapability.FlameBackend)
    end
  end
end
