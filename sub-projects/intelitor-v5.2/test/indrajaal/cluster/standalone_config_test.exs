defmodule Indrajaal.Cluster.StandaloneConfigTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cluster.StandaloneConfig

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(StandaloneConfig)
    end
  end

  describe "pure configuration functions" do
    test "defines topology_config/0" do
      assert function_exported?(StandaloneConfig, :topology_config, 0)
    end

    test "defines kubernetes_topology/0" do
      assert function_exported?(StandaloneConfig, :kubernetes_topology, 0)
    end

    test "defines erlang_dist_config/0" do
      assert function_exported?(StandaloneConfig, :erlang_dist_config, 0)
    end

    test "defines erl_aflags/0" do
      assert function_exported?(StandaloneConfig, :erl_aflags, 0)
    end

    test "defines configure_distribution!/0" do
      assert function_exported?(StandaloneConfig, :configure_distribution!, 0)
    end

    test "defines generate_node_name/0" do
      assert function_exported?(StandaloneConfig, :generate_node_name, 0)
    end

    test "defines detect_network_mode/0" do
      assert function_exported?(StandaloneConfig, :detect_network_mode, 0)
    end

    test "defines get_cookie/0" do
      assert function_exported?(StandaloneConfig, :get_cookie, 0)
    end

    test "defines set_cookie!/1" do
      assert function_exported?(StandaloneConfig, :set_cookie!, 1)
    end

    test "defines health_status/0" do
      assert function_exported?(StandaloneConfig, :health_status, 0)
    end

    test "defines apply_config!/0" do
      assert function_exported?(StandaloneConfig, :apply_config!, 0)
    end

    test "defines epmd_port/0" do
      assert function_exported?(StandaloneConfig, :epmd_port, 0)
    end

    test "defines dist_port_min/0" do
      assert function_exported?(StandaloneConfig, :dist_port_min, 0)
    end

    test "defines dist_port_max/0" do
      assert function_exported?(StandaloneConfig, :dist_port_max, 0)
    end

    test "defines dist_ports/0" do
      assert function_exported?(StandaloneConfig, :dist_ports, 0)
    end

    test "defines health_check_interval/0" do
      assert function_exported?(StandaloneConfig, :health_check_interval, 0)
    end
  end

  describe "port configuration values" do
    test "epmd_port returns integer" do
      result = StandaloneConfig.epmd_port()
      assert is_integer(result)
    end

    test "dist_port_min returns integer" do
      result = StandaloneConfig.dist_port_min()
      assert is_integer(result)
    end

    test "dist_port_max returns integer" do
      result = StandaloneConfig.dist_port_max()
      assert is_integer(result)
    end

    test "dist_port_max >= dist_port_min" do
      assert StandaloneConfig.dist_port_max() >= StandaloneConfig.dist_port_min()
    end

    test "health_check_interval returns positive integer" do
      interval = StandaloneConfig.health_check_interval()
      assert is_integer(interval)
      assert interval > 0
    end
  end

  describe "detect_network_mode/0" do
    test "returns an atom" do
      result = StandaloneConfig.detect_network_mode()
      assert is_atom(result)
    end
  end

  describe "topology_config/0" do
    test "returns a map or list" do
      result = StandaloneConfig.topology_config()
      assert is_map(result) or is_list(result)
    end
  end
end
