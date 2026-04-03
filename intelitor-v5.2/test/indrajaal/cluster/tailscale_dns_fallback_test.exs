defmodule Indrajaal.Cluster.TailscaleDNSFallbackTest do
  @moduledoc """
  Tests for TailscaleDNS local fallback functions (SC-CLU-004).

  STAMP Compliance:
  - SC-CLU-004: Graceful degradation when Tailscale unavailable

  These tests verify the 10 new fallback functions that provide
  transparent failover from Tailscale to local naming when the
  Tailscale network is unavailable.

  TDG: Test-Driven Generation - tests created for fallback implementation.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Cluster.TailscaleDNS

  @default_local_suffix "local.indrajaal"
  @test_local_suffix "test.local.indrajaal"
  @test_tailnet_suffix "test-tailnet.ts.net"

  # ============================================================================
  # Setup helpers
  # ============================================================================

  setup do
    # Clean up environment variables before each test
    System.delete_env("LOCAL_DNS_SUFFIX")
    System.delete_env("TAILSCALE_DNS_SUFFIX")

    on_exit(fn ->
      System.delete_env("LOCAL_DNS_SUFFIX")
      System.delete_env("TAILSCALE_DNS_SUFFIX")
    end)

    :ok
  end

  # ============================================================================
  # 1. get_local_suffix/0 tests
  # ============================================================================

  describe "get_local_suffix/0" do
    test "returns default local suffix" do
      assert TailscaleDNS.get_local_suffix() == @default_local_suffix
    end

    test "returns suffix from LOCAL_DNS_SUFFIX environment variable" do
      System.put_env("LOCAL_DNS_SUFFIX", @test_local_suffix)

      assert TailscaleDNS.get_local_suffix() == @test_local_suffix
    end

    test "returns string type" do
      suffix = TailscaleDNS.get_local_suffix()
      assert is_binary(suffix)
    end

    test "suffix is not empty" do
      suffix = TailscaleDNS.get_local_suffix()
      assert byte_size(suffix) > 0
    end

    test "suffix contains 'local' or 'indrajaal'" do
      suffix = TailscaleDNS.get_local_suffix()
      assert String.contains?(suffix, "local") or String.contains?(suffix, "indrajaal")
    end
  end

  # ============================================================================
  # 2. detect_network_mode/0 tests
  # ============================================================================

  describe "detect_network_mode/0" do
    test "returns :tailscale or :local atom" do
      mode = TailscaleDNS.detect_network_mode()
      assert mode in [:tailscale, :local]
    end

    test "returns valid network_mode type" do
      mode = TailscaleDNS.detect_network_mode()
      assert is_atom(mode)
    end

    test "returns consistent result on multiple calls" do
      mode1 = TailscaleDNS.detect_network_mode()
      mode2 = TailscaleDNS.detect_network_mode()
      assert mode1 == mode2
    end
  end

  # ============================================================================
  # 3. tailscale_available?/0 tests
  # ============================================================================

  describe "tailscale_available?/0" do
    test "returns boolean" do
      result = TailscaleDNS.tailscale_available?()
      assert is_boolean(result)
    end

    test "matches detect_network_mode result" do
      available = TailscaleDNS.tailscale_available?()
      mode = TailscaleDNS.detect_network_mode()

      if available do
        assert mode == :tailscale
      else
        assert mode == :local
      end
    end

    test "returns consistent result on multiple calls" do
      result1 = TailscaleDNS.tailscale_available?()
      result2 = TailscaleDNS.tailscale_available?()
      assert result1 == result2
    end
  end

  # ============================================================================
  # 4. get_active_suffix/0 tests
  # ============================================================================

  describe "get_active_suffix/0" do
    test "returns string type" do
      suffix = TailscaleDNS.get_active_suffix()
      assert is_binary(suffix)
    end

    test "returns non-empty suffix" do
      suffix = TailscaleDNS.get_active_suffix()
      assert byte_size(suffix) > 0
    end

    test "returns appropriate suffix based on network mode" do
      suffix = TailscaleDNS.get_active_suffix()
      mode = TailscaleDNS.detect_network_mode()

      case mode do
        :tailscale ->
          # Should contain ts.net or configured tailnet suffix
          assert String.contains?(suffix, "ts.net") or
                   suffix == TailscaleDNS.get_tailnet_suffix()

        :local ->
          # Should match local suffix
          assert suffix == TailscaleDNS.get_local_suffix()
      end
    end

    test "does not contain leading or trailing dots" do
      suffix = TailscaleDNS.get_active_suffix()
      refute String.starts_with?(suffix, ".")
      refute String.ends_with?(suffix, ".")
    end
  end

  # ============================================================================
  # 5. get_node_name_with_fallback/2 tests
  # ============================================================================

  describe "get_node_name_with_fallback/2" do
    test "returns atom type" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1")
      assert is_atom(node)
    end

    test "returns node name containing base name" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1")
      node_str = Atom.to_string(node)
      assert String.contains?(node_str, "app-1")
    end

    test "uses default app name" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1")
      node_str = Atom.to_string(node)
      assert String.starts_with?(node_str, "indrajaal@")
    end

    test "allows custom app name" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1", app: "myapp")
      node_str = Atom.to_string(node)
      assert String.starts_with?(node_str, "myapp@")
    end

    test "node name ends with appropriate suffix" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1")
      node_str = Atom.to_string(node)
      suffix = TailscaleDNS.get_active_suffix()
      assert String.ends_with?(node_str, suffix)
    end

    test "sanitizes underscores in base name" do
      node = TailscaleDNS.get_node_name_with_fallback("app_with_underscore")
      node_str = Atom.to_string(node)
      # After @ there should be no underscores
      [_app, host] = String.split(node_str, "@")
      refute String.contains?(host, "_")
    end

    test "handles numeric suffixes" do
      node = TailscaleDNS.get_node_name_with_fallback("flame-runner-12_345")
      node_str = Atom.to_string(node)
      assert String.contains?(node_str, "flame-runner-12_345")
    end

    test "node name format is valid for Erlang distribution" do
      node = TailscaleDNS.get_node_name_with_fallback("test-node")
      node_str = Atom.to_string(node)

      # Must contain exactly one @
      parts = String.split(node_str, "@")
      assert length(parts) == 2

      [app_name, host] = parts
      assert byte_size(app_name) > 0
      assert byte_size(host) > 0
    end
  end

  # ============================================================================
  # 6. get_local_node_name/2 tests
  # ============================================================================

  describe "get_local_node_name/2" do
    test "returns atom type" do
      node = TailscaleDNS.get_local_node_name("app-1")
      assert is_atom(node)
    end

    test "always uses local suffix regardless of network mode" do
      node = TailscaleDNS.get_local_node_name("app-1")
      node_str = Atom.to_string(node)
      local_suffix = TailscaleDNS.get_local_suffix()
      assert String.ends_with?(node_str, local_suffix)
    end

    test "uses default app name" do
      node = TailscaleDNS.get_local_node_name("app-1")
      node_str = Atom.to_string(node)
      assert String.starts_with?(node_str, "indrajaal@")
    end

    test "allows custom app name" do
      node = TailscaleDNS.get_local_node_name("app-1", app: "custom")
      node_str = Atom.to_string(node)
      assert String.starts_with?(node_str, "custom@")
    end

    test "generates expected format" do
      node = TailscaleDNS.get_local_node_name("app-1")
      expected = :"indrajaal@app-1.#{@default_local_suffix}"
      assert node == expected
    end

    test "sanitizes base name" do
      node = TailscaleDNS.get_local_node_name("App_Name")
      node_str = Atom.to_string(node)
      # Should be lowercased and underscores replaced
      assert String.contains?(node_str, "app-name")
    end
  end

  # ============================================================================
  # 7. list_cluster_nodes_with_fallback/0 tests
  # ============================================================================

  describe "list_cluster_nodes_with_fallback/0" do
    test "returns list of atoms" do
      nodes = TailscaleDNS.list_cluster_nodes_with_fallback()
      assert is_list(nodes)
      Enum.each(nodes, fn node -> assert is_atom(node) end)
    end

    test "returns at least 3 nodes (SC-CLU-002)" do
      nodes = TailscaleDNS.list_cluster_nodes_with_fallback()
      assert length(nodes) >= 3
    end

    test "all nodes use active suffix" do
      nodes = TailscaleDNS.list_cluster_nodes_with_fallback()
      suffix = TailscaleDNS.get_active_suffix()

      Enum.each(nodes, fn node ->
        node_str = Atom.to_string(node)
        assert String.ends_with?(node_str, suffix)
      end)
    end

    test "all nodes start with indrajaal@" do
      nodes = TailscaleDNS.list_cluster_nodes_with_fallback()

      Enum.each(nodes, fn node ->
        node_str = Atom.to_string(node)
        assert String.starts_with?(node_str, "indrajaal@")
      end)
    end

    test "returns unique node names" do
      nodes = TailscaleDNS.list_cluster_nodes_with_fallback()
      unique_nodes = Enum.uniq(nodes)
      assert length(nodes) == length(unique_nodes)
    end
  end

  # ============================================================================
  # 8. normalize_node_name/1 tests
  # ============================================================================

  describe "normalize_node_name/1" do
    test "returns atom type" do
      result = TailscaleDNS.normalize_node_name(:"indrajaal@app-1.old-suffix.net")
      assert is_atom(result)
    end

    test "converts node to use active suffix" do
      input = :"indrajaal@app-1.some-old-suffix.net"
      result = TailscaleDNS.normalize_node_name(input)
      result_str = Atom.to_string(result)
      suffix = TailscaleDNS.get_active_suffix()

      assert String.ends_with?(result_str, suffix)
    end

    test "preserves app name" do
      input = :"myapp@app-1.old-suffix"
      result = TailscaleDNS.normalize_node_name(input)
      result_str = Atom.to_string(result)

      assert String.starts_with?(result_str, "myapp@")
    end

    test "handles invalid node name gracefully" do
      input = :invalid_no_at_symbol
      result = TailscaleDNS.normalize_node_name(input)
      # Should return input unchanged when parsing fails
      assert result == input
    end

    test "normalizes node already in correct format" do
      suffix = TailscaleDNS.get_active_suffix()
      input = String.to_atom("indrajaal@app-1.#{suffix}")
      result = TailscaleDNS.normalize_node_name(input)

      # Should still work correctly
      result_str = Atom.to_string(result)
      assert String.ends_with?(result_str, suffix)
    end
  end

  # ============================================================================
  # 9. get_this_host_name/0 tests
  # ============================================================================

  describe "get_this_host_name/0" do
    test "returns string type" do
      hostname = TailscaleDNS.get_this_host_name()
      assert is_binary(hostname)
    end

    test "returns non-empty hostname" do
      hostname = TailscaleDNS.get_this_host_name()
      assert byte_size(hostname) > 0
    end

    test "hostname ends with active suffix" do
      hostname = TailscaleDNS.get_this_host_name()
      suffix = TailscaleDNS.get_active_suffix()
      assert String.ends_with?(hostname, suffix)
    end

    test "hostname contains a dot (DNS format)" do
      hostname = TailscaleDNS.get_this_host_name()
      assert String.contains?(hostname, ".")
    end

    test "hostname is lowercase" do
      hostname = TailscaleDNS.get_this_host_name()
      assert hostname == String.downcase(hostname)
    end
  end

  # ============================================================================
  # 10. get_this_node_name/1 tests
  # ============================================================================

  describe "get_this_node_name/1" do
    test "returns atom type" do
      node = TailscaleDNS.get_this_node_name()
      assert is_atom(node)
    end

    test "uses default app name" do
      node = TailscaleDNS.get_this_node_name()
      node_str = Atom.to_string(node)
      assert String.starts_with?(node_str, "indrajaal@")
    end

    test "allows custom app name" do
      node = TailscaleDNS.get_this_node_name(app: "custom")
      node_str = Atom.to_string(node)
      assert String.starts_with?(node_str, "custom@")
    end

    test "node name ends with active suffix" do
      node = TailscaleDNS.get_this_node_name()
      node_str = Atom.to_string(node)
      suffix = TailscaleDNS.get_active_suffix()
      assert String.ends_with?(node_str, suffix)
    end

    test "node name format is valid for Erlang distribution" do
      node = TailscaleDNS.get_this_node_name()
      node_str = Atom.to_string(node)

      parts = String.split(node_str, "@")
      assert length(parts) == 2

      [app_name, host] = parts
      assert byte_size(app_name) > 0
      assert byte_size(host) > 0
    end

    test "returns consistent result on multiple calls" do
      node1 = TailscaleDNS.get_this_node_name()
      node2 = TailscaleDNS.get_this_node_name()
      assert node1 == node2
    end
  end

  # ============================================================================
  # SC-CLU-004 Compliance Tests: Graceful Degradation
  # ============================================================================

  describe "SC-CLU-004: Graceful Degradation" do
    test "system provides valid node names regardless of Tailscale status" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1")
      assert is_atom(node)

      node_str = Atom.to_string(node)
      assert String.contains?(node_str, "@")
      assert String.contains?(node_str, "app-1")
    end

    test "system provides valid cluster nodes regardless of Tailscale status" do
      nodes = TailscaleDNS.list_cluster_nodes_with_fallback()
      assert is_list(nodes)
      assert length(nodes) >= 3
    end

    test "local fallback always available" do
      local_suffix = TailscaleDNS.get_local_suffix()
      assert is_binary(local_suffix)
      assert byte_size(local_suffix) > 0
    end

    test "network mode detection never raises" do
      mode = TailscaleDNS.detect_network_mode()
      assert mode in [:tailscale, :local]
    end

    test "tailscale_available? never raises" do
      result = TailscaleDNS.tailscale_available?()
      assert is_boolean(result)
    end

    test "fallback functions work in local mode" do
      # These should all work regardless of Tailscale availability
      assert TailscaleDNS.get_local_suffix() == @default_local_suffix
      assert is_atom(TailscaleDNS.get_local_node_name("app-1"))
    end

    test "consistency between fallback and non-fallback functions in same mode" do
      mode = TailscaleDNS.detect_network_mode()

      case mode do
        :tailscale ->
          # In tailscale mode, fallback should match regular
          node_regular = TailscaleDNS.get_node_name("app-1")
          node_fallback = TailscaleDNS.get_node_name_with_fallback("app-1")
          assert node_regular == node_fallback

        :local ->
          # In local mode, fallback should match local
          node_local = TailscaleDNS.get_local_node_name("app-1")
          node_fallback = TailscaleDNS.get_node_name_with_fallback("app-1")
          assert node_local == node_fallback
      end
    end
  end

  # ============================================================================
  # Integration Tests: Fallback Behavior
  # ============================================================================

  describe "Fallback Integration" do
    test "all fallback functions return consistent suffix" do
      suffix = TailscaleDNS.get_active_suffix()

      node_with_fallback = TailscaleDNS.get_node_name_with_fallback("test")
      this_host = TailscaleDNS.get_this_host_name()
      this_node = TailscaleDNS.get_this_node_name()
      cluster_nodes = TailscaleDNS.list_cluster_nodes_with_fallback()

      assert String.ends_with?(Atom.to_string(node_with_fallback), suffix)
      assert String.ends_with?(this_host, suffix)
      assert String.ends_with?(Atom.to_string(this_node), suffix)

      Enum.each(cluster_nodes, fn node ->
        assert String.ends_with?(Atom.to_string(node), suffix)
      end)
    end

    test "normalize_node_name uses active suffix" do
      input = :"indrajaal@app-1.old.suffix"
      result = TailscaleDNS.normalize_node_name(input)
      result_str = Atom.to_string(result)
      suffix = TailscaleDNS.get_active_suffix()

      assert String.ends_with?(result_str, suffix)
    end

    test "local functions always use local suffix" do
      local_suffix = TailscaleDNS.get_local_suffix()

      local_node = TailscaleDNS.get_local_node_name("test")
      local_node_str = Atom.to_string(local_node)

      assert String.ends_with?(local_node_str, local_suffix)
    end
  end

  # ============================================================================
  # Edge Cases
  # ============================================================================

  describe "Edge Cases" do
    test "get_node_name_with_fallback handles special characters" do
      node = TailscaleDNS.get_node_name_with_fallback("app-1-test_name")
      node_str = Atom.to_string(node)
      [_app, host] = String.split(node_str, "@")
      # Underscores should be converted to hyphens
      refute String.contains?(host, "_")
    end

    test "get_local_node_name handles uppercase" do
      node = TailscaleDNS.get_local_node_name("APP-NAME")
      node_str = Atom.to_string(node)
      [_app, host] = String.split(node_str, "@")
      # Should be lowercase
      assert host == String.downcase(host)
    end

    test "environment variable override for local suffix" do
      System.put_env("LOCAL_DNS_SUFFIX", "custom.local.suffix")

      suffix = TailscaleDNS.get_local_suffix()
      assert suffix == "custom.local.suffix"

      node = TailscaleDNS.get_local_node_name("app-1")
      node_str = Atom.to_string(node)
      assert String.ends_with?(node_str, "custom.local.suffix")
    end

    test "normalize_node_name handles nodeleft without suffix" do
      # A short node name without suffix
      result = TailscaleDNS.normalize_node_name(:"indrajaal@app-1")
      assert is_atom(result)
    end
  end
end
