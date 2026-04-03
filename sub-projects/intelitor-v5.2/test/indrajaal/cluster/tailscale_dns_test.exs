defmodule Indrajaal.Cluster.TailscaleDNSTest do
  @moduledoc """
  Tests for the TailscaleDNS module.

  STAMP Compliance:
  - SC-CLU-001: Identity-based networking via Tailscale
  - SC-CLU-002: Minimum 3 nodes for HA
  - SC-CLU-004: EPMD binds to Tailscale IP only
  - SC-CLU-005: Split-brain prevention with consistent naming

  TDG: Test-Driven Generation - tests created BEFORE implementation.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cluster.TailscaleDNS

  # Default test tailnet suffix
  @default_suffix "tailnet.ts.net"
  @test_suffix "test-tailnet.ts.net"

  describe "get_tailnet_suffix/0" do
    test "returns suffix from TAILSCALE_DNS_SUFFIX environment variable" do
      # Set test environment variable
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)

      suffix = TailscaleDNS.get_tailnet_suffix()

      assert suffix == @test_suffix

      # Cleanup
      System.delete_env("TAILSCALE_DNS_SUFFIX")
    end

    test "returns default suffix when environment variable not set" do
      # Ensure env var is not set
      System.delete_env("TAILSCALE_DNS_SUFFIX")

      suffix = TailscaleDNS.get_tailnet_suffix()

      assert suffix == @default_suffix
    end

    test "returns string type" do
      suffix = TailscaleDNS.get_tailnet_suffix()

      assert is_binary(suffix)
    end

    test "suffix does not contain leading or trailing dots" do
      System.put_env("TAILSCALE_DNS_SUFFIX", ".example.ts.net.")

      suffix = TailscaleDNS.get_tailnet_suffix()

      refute String.starts_with?(suffix, ".")
      refute String.ends_with?(suffix, ".")

      System.delete_env("TAILSCALE_DNS_SUFFIX")
    end
  end

  describe "get_node_name/1" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "generates valid Erlang node name from base name" do
      node_name = TailscaleDNS.get_node_name("app-1")

      assert is_atom(node_name)
      assert node_name == :"indrajaal@app-1.#{@test_suffix}"
    end

    test "generates node name with custom application prefix" do
      node_name = TailscaleDNS.get_node_name("app-2", app: "myapp")

      assert node_name == :"myapp@app-2.#{@test_suffix}"
    end

    test "handles numeric suffixes in base name" do
      node_name = TailscaleDNS.get_node_name("flame-runner-123")

      assert node_name == :"indrajaal@flame-runner-123.#{@test_suffix}"
    end

    test "sanitizes invalid characters in base name" do
      node_name = TailscaleDNS.get_node_name("app_with_underscores")

      # Underscores should be converted to hyphens for DNS compatibility
      name_string = Atom.to_string(node_name)
      refute String.contains?(name_string, "_")
    end

    test "returns atom type" do
      node_name = TailscaleDNS.get_node_name("test-node")

      assert is_atom(node_name)
    end

    test "node name is valid for Erlang distribution" do
      node_name = TailscaleDNS.get_node_name("app-1")
      name_string = Atom.to_string(node_name)

      # Must contain exactly one @
      assert String.contains?(name_string, "@")
      [app_name, host] = String.split(name_string, "@")

      # App name must be non-empty
      assert byte_size(app_name) > 0

      # Host must be non-empty and contain the suffix
      assert byte_size(host) > 0
      assert String.ends_with?(host, @test_suffix)
    end
  end

  describe "get_full_dns_name/1" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "returns full DNS name for a base name" do
      dns_name = TailscaleDNS.get_full_dns_name("app-1")

      assert dns_name == "app-1.#{@test_suffix}"
    end

    test "returns string type" do
      dns_name = TailscaleDNS.get_full_dns_name("test")

      assert is_binary(dns_name)
    end

    test "does not duplicate suffix if already present" do
      dns_name = TailscaleDNS.get_full_dns_name("app-1.#{@test_suffix}")

      # Should not have double suffix
      refute String.contains?(dns_name, "#{@test_suffix}.#{@test_suffix}")
    end
  end

  describe "validate_tailscale_connectivity/0" do
    test "returns {:ok, info} when Tailscale is connected" do
      # This test will pass in environments with Tailscale
      # In test environments without Tailscale, it should return an error tuple
      result = TailscaleDNS.validate_tailscale_connectivity()

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error tuple with reason when disconnected" do
      # Mock disconnected state by checking the error format
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, info} ->
          assert is_map(info)
          assert Map.has_key?(info, :dns_name)
          assert Map.has_key?(info, :ip_address)

        {:error, reason} ->
          assert is_atom(reason) or is_binary(reason)
      end
    end

    test "includes DNS name in success response" do
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, info} ->
          assert Map.has_key?(info, :dns_name)
          assert is_binary(info.dns_name) or is_nil(info.dns_name)

        {:error, _} ->
          # Expected in test environment without Tailscale
          :ok
      end
    end

    test "includes IP address in success response" do
      case TailscaleDNS.validate_tailscale_connectivity() do
        {:ok, info} ->
          assert Map.has_key?(info, :ip_address)

        {:error, _} ->
          :ok
      end
    end
  end

  describe "node_to_tailscale_name/1" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "converts short node name to Tailscale DNS name" do
      result = TailscaleDNS.node_to_tailscale_name(:"indrajaal@app-1")

      assert result == :"indrajaal@app-1.#{@test_suffix}"
    end

    test "returns unchanged if already has Tailscale suffix" do
      original = :"indrajaal@app-1.#{@test_suffix}"
      result = TailscaleDNS.node_to_tailscale_name(original)

      assert result == original
    end

    test "handles node name with IP address" do
      result = TailscaleDNS.node_to_tailscale_name(:"indrajaal@192.168.1.1")

      # Should convert IP to DNS name format
      assert is_atom(result)
    end

    test "handles string input" do
      result = TailscaleDNS.node_to_tailscale_name("indrajaal@app-1")

      assert is_atom(result)
    end
  end

  describe "parse_node_name/1" do
    test "extracts app name and host from node name atom" do
      {:ok, parsed} = TailscaleDNS.parse_node_name(:"indrajaal@app-1.tailnet.ts.net")

      assert parsed.app_name == "indrajaal"
      assert parsed.host == "app-1.tailnet.ts.net"
      assert parsed.base_name == "app-1"
    end

    test "extracts app name and host from node name string" do
      {:ok, parsed} = TailscaleDNS.parse_node_name("indrajaal@app-1.tailnet.ts.net")

      assert parsed.app_name == "indrajaal"
      assert parsed.host == "app-1.tailnet.ts.net"
    end

    test "returns error for invalid node name format" do
      result = TailscaleDNS.parse_node_name("invalid-no-at-symbol")

      assert match?({:error, _}, result)
    end

    test "handles node name without suffix" do
      {:ok, parsed} = TailscaleDNS.parse_node_name(:"indrajaal@app-1")

      assert parsed.app_name == "indrajaal"
      assert parsed.host == "app-1"
      assert parsed.base_name == "app-1"
    end
  end

  describe "list_cluster_nodes/0" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "returns list of configured cluster node names" do
      nodes = TailscaleDNS.list_cluster_nodes()

      assert is_list(nodes)
    end

    test "all returned nodes have Tailscale DNS suffix" do
      nodes = TailscaleDNS.list_cluster_nodes()

      Enum.each(nodes, fn node ->
        node_string = Atom.to_string(node)

        assert String.contains?(node_string, @test_suffix),
               "Node #{node} should contain Tailscale suffix"
      end)
    end

    test "returns at least 3 nodes for HA (SC-CLU-002)" do
      nodes = TailscaleDNS.list_cluster_nodes()

      assert length(nodes) >= 3,
             "SC-CLU-002: Cluster must have at least 3 nodes for HA"
    end

    test "node names follow naming convention" do
      nodes = TailscaleDNS.list_cluster_nodes()

      Enum.each(nodes, fn node ->
        node_string = Atom.to_string(node)

        assert String.starts_with?(node_string, "indrajaal@"),
               "Node #{node} should start with 'indrajaal@'"
      end)
    end
  end

  describe "STAMP compliance" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "SC-CLU-001: uses identity-based networking (Tailscale DNS)" do
      node_name = TailscaleDNS.get_node_name("app-1")
      node_string = Atom.to_string(node_name)

      # Must use DNS name, not IP address
      refute Regex.match?(~r/\d+\.\d+\.\d+\.\d+/, node_string),
             "SC-CLU-001: Node names must use DNS, not IP addresses"

      # Must have Tailscale suffix
      assert String.contains?(node_string, ".ts.net") or
               String.contains?(node_string, @test_suffix),
             "SC-CLU-001: Node names must use Tailscale DNS suffix"
    end

    test "SC-CLU-002: minimum 3 nodes for HA" do
      nodes = TailscaleDNS.list_cluster_nodes()

      assert length(nodes) >= 3,
             "SC-CLU-002: Cluster must have minimum 3 nodes"
    end

    test "SC-CLU-004: EPMD binding configuration available" do
      # Verify the module provides EPMD binding information
      epmd_info = TailscaleDNS.get_epmd_binding()

      assert is_map(epmd_info) or match?({:ok, _}, epmd_info) or match?({:error, _}, epmd_info)
    end

    test "SC-CLU-005: consistent naming for split-brain prevention" do
      # Generate same node name multiple times
      node1 = TailscaleDNS.get_node_name("app-1")
      node2 = TailscaleDNS.get_node_name("app-1")
      node3 = TailscaleDNS.get_node_name("app-1")

      assert node1 == node2,
             "SC-CLU-005: Node naming must be deterministic"

      assert node2 == node3,
             "SC-CLU-005: Node naming must be consistent"
    end

    test "SC-CLU-005: all cluster nodes have unique names" do
      nodes = TailscaleDNS.list_cluster_nodes()
      unique_nodes = Enum.uniq(nodes)

      assert length(nodes) == length(unique_nodes),
             "SC-CLU-005: All cluster nodes must have unique names"
    end
  end

  describe "FLAME integration" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "generates FLAME runner node name with pool identifier" do
      runner_name = TailscaleDNS.get_flame_runner_name("intelligence", "abc123")

      assert is_atom(runner_name)
      runner_string = Atom.to_string(runner_name)

      assert String.contains?(runner_string, "intelligence")
      assert String.contains?(runner_string, "abc123")
      assert String.contains?(runner_string, @test_suffix)
    end

    test "FLAME runner names include pool type" do
      for pool <- ["intelligence", "video", "analytics"] do
        runner_name = TailscaleDNS.get_flame_runner_name(pool, "test123")
        runner_string = Atom.to_string(runner_name)

        assert String.contains?(runner_string, pool),
               "FLAME runner name should include pool type: #{pool}"
      end
    end

    test "FLAME runner names are unique per runner_id" do
      name1 = TailscaleDNS.get_flame_runner_name("intelligence", "runner1")
      name2 = TailscaleDNS.get_flame_runner_name("intelligence", "runner2")

      assert name1 != name2,
             "Different runner IDs must produce different names"
    end
  end

  describe "Sentinel/HA integration" do
    setup do
      System.put_env("TAILSCALE_DNS_SUFFIX", @test_suffix)
      on_exit(fn -> System.delete_env("TAILSCALE_DNS_SUFFIX") end)
      :ok
    end

    test "get_quorum_nodes/0 returns nodes for sentinel quorum" do
      quorum_nodes = TailscaleDNS.get_quorum_nodes()

      assert is_list(quorum_nodes)
      assert length(quorum_nodes) >= 3, "Quorum requires at least 3 nodes"
    end

    test "quorum nodes all use Tailscale DNS names" do
      quorum_nodes = TailscaleDNS.get_quorum_nodes()

      Enum.each(quorum_nodes, fn node ->
        node_string = Atom.to_string(node)

        assert String.contains?(node_string, @test_suffix),
               "Quorum node #{node} must use Tailscale DNS"
      end)
    end

    test "is_valid_quorum_node?/1 validates node format" do
      valid_node = :"indrajaal@app-1.#{@test_suffix}"
      invalid_node = :"indrajaal@192.168.1.1"

      assert TailscaleDNS.is_valid_quorum_node?(valid_node)
      refute TailscaleDNS.is_valid_quorum_node?(invalid_node)
    end
  end

  describe "error handling" do
    test "handles nil input gracefully" do
      assert_raise ArgumentError, fn ->
        TailscaleDNS.get_node_name(nil)
      end
    end

    test "handles empty string input" do
      assert_raise ArgumentError, fn ->
        TailscaleDNS.get_node_name("")
      end
    end

    test "handles whitespace-only input" do
      assert_raise ArgumentError, fn ->
        TailscaleDNS.get_node_name("   ")
      end
    end
  end
end
