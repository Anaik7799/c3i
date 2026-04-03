defmodule Indrajaal.Cluster.Capabilities.K8sCapabilityTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.Capabilities.K8sCapability

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(K8sCapability)
    end
  end

  describe "public API" do
    test "defines start_link/1" do
      assert function_exported?(K8sCapability, :start_link, 1)
    end

    test "defines create_pod/2" do
      assert function_exported?(K8sCapability, :create_pod, 2)
    end

    test "defines delete_pod/1" do
      assert function_exported?(K8sCapability, :delete_pod, 1)
    end

    test "defines pod_status/1" do
      assert function_exported?(K8sCapability, :pod_status, 1)
    end

    test "defines list_pods/0" do
      assert function_exported?(K8sCapability, :list_pods, 0)
    end

    test "defines get_pod_node/1" do
      assert function_exported?(K8sCapability, :get_pod_node, 1)
    end

    test "defines k8s_available?/0" do
      assert function_exported?(K8sCapability, :k8s_available?, 0)
    end

    test "defines status/0" do
      assert function_exported?(K8sCapability, :status, 0)
    end

    test "defines capability_type/0" do
      assert function_exported?(K8sCapability, :capability_type, 0)
    end

    test "defines available?/0" do
      assert function_exported?(K8sCapability, :available?, 0)
    end
  end

  describe "GenServer" do
    test "defines child_spec/1" do
      assert function_exported?(K8sCapability, :child_spec, 1)
    end

    test "child_spec returns valid map" do
      spec = K8sCapability.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
    end
  end
end
