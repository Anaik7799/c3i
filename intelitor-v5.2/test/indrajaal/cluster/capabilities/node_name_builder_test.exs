defmodule Indrajaal.Cluster.Capabilities.NodeNameBuilderTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Capabilities.NodeNameBuilder

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(NodeNameBuilder)
    end
  end

  describe "public API" do
    test "defines build_node_name/4" do
      assert function_exported?(NodeNameBuilder, :build_node_name, 4)
    end

    test "defines get_tailscale_suffix/1" do
      assert function_exported?(NodeNameBuilder, :get_tailscale_suffix, 1)
    end

    test "defines normalize_hostname/1" do
      assert function_exported?(NodeNameBuilder, :normalize_hostname, 1)
    end

    test "defines build_vm_hostname/1" do
      assert function_exported?(NodeNameBuilder, :build_vm_hostname, 1)
    end
  end

  describe "normalize_hostname/1" do
    test "converts hostname to lowercase" do
      result = NodeNameBuilder.normalize_hostname("MyHost")
      assert is_binary(result)
      assert result == String.downcase("MyHost") or String.contains?(result, "myhost")
    end

    test "handles already normalized hostname" do
      result = NodeNameBuilder.normalize_hostname("myhost")
      assert is_binary(result)
    end

    test "handles hostname with special chars" do
      result = NodeNameBuilder.normalize_hostname("my-host.local")
      assert is_binary(result)
    end
  end

  describe "build_vm_hostname/1" do
    test "returns a string for integer input" do
      result = NodeNameBuilder.build_vm_hostname(1)
      assert is_binary(result)
    end
  end

  describe "get_tailscale_suffix/1" do
    test "returns a string" do
      result = NodeNameBuilder.get_tailscale_suffix("myhost")
      assert is_binary(result)
    end
  end

  describe "build_node_name/4" do
    test "returns a string" do
      result = NodeNameBuilder.build_node_name("app", "host", "local", :standalone)
      assert is_binary(result)
    end
  end
end
