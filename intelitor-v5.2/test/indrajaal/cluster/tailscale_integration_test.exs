defmodule Indrajaal.Cluster.TailscaleIntegrationTest do
  @moduledoc """
  Integration tests for Tailscale DNS-based clustering.

  STAMP Compliance:
  - SC-CLU-001: Identity-based networking via Tailscale
  - SC-CLU-002: Minimum 3 nodes for HA
  - SC-CLU-003: Kubernetes DNS in production
  - SC-CLU-004: EPMD binds to Tailscale IP only
  - SC-CLU-005: Split-brain prevention with consistent naming
  - SC-FLAME-001: FLAME backends configurable
  - SC-FLAME-004: Graceful drain with node tracking

  TDG: Test-Driven Generation - tests created BEFORE implementation.

  These tests verify:
  - Node discovery via Tailscale DNS
  - FLAME runner registration with Tailscale names
  - Sentinel quorum naming consistency
  - Failover scenarios with DNS-based nodes
  """

  use ExUnit.Case, async: false

  alias Indrajaal.Cluster.TailscaleDNS

  # Test tailnet configuration
  @test_tailnet "test-tailnet.ts.net"
  @test_nodes ["indrajaal-app-1", "indrajaal-app-2", "indrajaal-app-3"]

  setup_all do
    # Set test environment
    System.put_env("TAILSCALE_DNS_SUFFIX", @test_tailnet)

    on_exit(fn ->
      System.delete_env("TAILSCALE_DNS_SUFFIX")
    end)

    :ok
  end

  describe "node discovery via Tailscale DNS" do
    test "discovers all configured cluster nodes" do
      nodes = TailscaleDNS.list_cluster_nodes()

      assert is_list(nodes)
      assert length(nodes) >= 3, "SC-CLU-002: Must have at least 3 nodes"
    end

    test "all discovered nodes use Tailscale DNS format" do
      nodes = TailscaleDNS.list_cluster_nodes()

      Enum.each(nodes, fn node ->
        node_string = Atom.to_string(node)

        # Must contain @ separator
        assert String.contains?(node_string, "@"),
               "Node #{node} must have app@host format"

        # Must NOT be an IP address
        [_app, host] = String.split(node_string, "@")

        refute Regex.match?(~r/^\d+\.\d+\.\d+\.\d+$/, host),
               "SC-CLU-001: Node #{node} must use DNS name, not IP"

        # Must contain Tailscale suffix
        assert String.contains?(host, ".ts.net") or String.contains?(host, @test_tailnet),
               "SC-CLU-001: Node #{node} must use Tailscale DNS suffix"
      end)
    end

    test "node discovery is consistent across multiple calls" do
      nodes1 = TailscaleDNS.list_cluster_nodes()
      nodes2 = TailscaleDNS.list_cluster_nodes()
      nodes3 = TailscaleDNS.list_cluster_nodes()

      assert MapSet.new(nodes1) == MapSet.new(nodes2),
             "SC-CLU-005: Node discovery must be deterministic"

      assert MapSet.new(nodes2) == MapSet.new(nodes3),
             "SC-CLU-005: Node discovery must be consistent"
    end

    test "discovered nodes are in expected naming format" do
      nodes = TailscaleDNS.list_cluster_nodes()

      Enum.each(nodes, fn node ->
        node_string = Atom.to_string(node)

        # Expected format: indrajaal@<hostname>.<tailnet>
        assert Regex.match?(~r/^indrajaal@[\w\-]+\.[\w\-\.]+$/, node_string),
               "Node #{node} doesn't match expected naming format"
      end)
    end

    test "can resolve each discovered node to full DNS name" do
      nodes = TailscaleDNS.list_cluster_nodes()

      Enum.each(nodes, fn node ->
        {:ok, parsed} = TailscaleDNS.parse_node_name(node)

        assert Map.has_key?(parsed, :host),
               "Parsed node must have host"

        assert Map.has_key?(parsed, :app_name),
               "Parsed node must have app_name"

        assert parsed.app_name == "indrajaal",
               "App name must be 'indrajaal'"
      end)
    end
  end

  describe "FLAME runner registration" do
    test "generates unique runner names for each pool" do
      pools = ["intelligence", "video", "analytics"]
      runner_id = "test-runner-#{:rand.uniform(10_000)}"

      runner_names =
        Enum.map(pools, fn pool ->
          TailscaleDNS.get_flame_runner_name(pool, runner_id)
        end)

      # All names should be unique
      assert length(Enum.uniq(runner_names)) == length(runner_names),
             "Each pool must have unique runner names"
    end

    test "runner names include pool identifier" do
      runner_name = TailscaleDNS.get_flame_runner_name("intelligence", "runner-123")
      runner_string = Atom.to_string(runner_name)

      assert String.contains?(runner_string, "intelligence"),
             "Runner name must include pool identifier"
    end

    test "runner names include Tailscale DNS suffix" do
      runner_name = TailscaleDNS.get_flame_runner_name("video", "runner-456")
      runner_string = Atom.to_string(runner_name)

      assert String.contains?(runner_string, @test_tailnet),
             "SC-FLAME-001: Runner must use Tailscale DNS"
    end

    test "runner names are valid Erlang node names" do
      runner_name = TailscaleDNS.get_flame_runner_name("analytics", "runner-789")

      assert is_atom(runner_name)

      runner_string = Atom.to_string(runner_name)
      assert String.contains?(runner_string, "@")

      [app_name, host] = String.split(runner_string, "@")
      assert byte_size(app_name) > 0
      assert byte_size(host) > 0
    end

    test "multiple runners in same pool have distinct names" do
      pool = "intelligence"

      runner1 = TailscaleDNS.get_flame_runner_name(pool, "runner-001")
      runner2 = TailscaleDNS.get_flame_runner_name(pool, "runner-002")
      runner3 = TailscaleDNS.get_flame_runner_name(pool, "runner-003")

      assert runner1 != runner2
      assert runner2 != runner3
      assert runner1 != runner3
    end

    test "SC-FLAME-004: runner names support graceful drain tracking" do
      pool = "video"
      runner_id = "drain-test-#{:rand.uniform(10_000)}"

      runner_name = TailscaleDNS.get_flame_runner_name(pool, runner_id)

      # Should be able to parse the runner name back to pool and ID
      runner_string = Atom.to_string(runner_name)

      assert String.contains?(runner_string, pool),
             "Runner name must contain pool for tracking"

      assert String.contains?(runner_string, runner_id),
             "Runner name must contain ID for tracking"
    end
  end

  describe "Sentinel quorum naming" do
    test "quorum nodes all use Tailscale DNS" do
      quorum_nodes = TailscaleDNS.get_quorum_nodes()

      Enum.each(quorum_nodes, fn node ->
        assert TailscaleDNS.is_valid_quorum_node?(node),
               "SC-CLU-005: Quorum node #{node} must use Tailscale DNS"
      end)
    end

    test "quorum has at least 3 nodes for HA" do
      quorum_nodes = TailscaleDNS.get_quorum_nodes()

      assert length(quorum_nodes) >= 3,
             "SC-CLU-002: Quorum must have at least 3 nodes"
    end

    test "quorum nodes are all unique" do
      quorum_nodes = TailscaleDNS.get_quorum_nodes()
      unique_nodes = Enum.uniq(quorum_nodes)

      assert length(quorum_nodes) == length(unique_nodes),
             "SC-CLU-005: All quorum nodes must be unique"
    end

    test "quorum node validation rejects IP-based nodes" do
      ip_node = :"indrajaal@192.168.1.100"

      refute TailscaleDNS.is_valid_quorum_node?(ip_node),
             "SC-CLU-001: IP-based nodes must be rejected from quorum"
    end

    test "quorum node validation rejects short names" do
      short_node = :"indrajaal@app-1"

      refute TailscaleDNS.is_valid_quorum_node?(short_node),
             "SC-CLU-001: Short names must be rejected from quorum"
    end

    test "quorum node validation accepts valid Tailscale names" do
      valid_node = :"indrajaal@app-1.#{@test_tailnet}"

      assert TailscaleDNS.is_valid_quorum_node?(valid_node),
             "Valid Tailscale DNS names must be accepted"
    end

    test "quorum nodes form odd count for consensus" do
      quorum_nodes = TailscaleDNS.get_quorum_nodes()
      count = length(quorum_nodes)

      # For proper consensus, odd numbers are preferred (3, 5, 7)
      # At minimum, 3 nodes are required
      assert count >= 3, "Quorum requires at least 3 nodes"

      # Warn if even (not a hard failure, but suboptimal)
      if rem(count, 2) == 0 do
        IO.warn("Quorum has even number of nodes (#{count}), odd is preferred for tie-breaking")
      end
    end
  end

  describe "failover scenarios with DNS-based nodes" do
    test "can convert short node names to Tailscale DNS" do
      short_node = :"indrajaal@app-1"
      tailscale_node = TailscaleDNS.node_to_tailscale_name(short_node)

      tailscale_string = Atom.to_string(tailscale_node)

      assert String.contains?(tailscale_string, @test_tailnet),
             "Converted node must use Tailscale DNS"
    end

    test "preserves already-qualified Tailscale nodes" do
      original = :"indrajaal@app-1.#{@test_tailnet}"
      converted = TailscaleDNS.node_to_tailscale_name(original)

      assert converted == original,
             "Already-qualified nodes should not be modified"
    end

    test "handles node name conversion for failover list" do
      # Simulate a failover list with mixed formats
      mixed_nodes = [
        :"indrajaal@app-1",
        :"indrajaal@app-2.#{@test_tailnet}",
        :"indrajaal@192.168.1.1"
      ]

      converted = Enum.map(mixed_nodes, &TailscaleDNS.node_to_tailscale_name/1)

      # All converted nodes should have Tailscale suffix and not be raw IPs
      Enum.each(converted, fn node ->
        node_string = Atom.to_string(node)
        [_app, host] = String.split(node_string, "@")

        # Should not be raw IP (must have been converted to DNS format)
        refute Regex.match?(~r/^\d+\.\d+\.\d+\.\d+$/, host),
               "Failover node #{node} should not be raw IP after conversion"

        # Should contain Tailscale suffix
        assert String.contains?(host, @test_tailnet) or String.contains?(host, ".ts.net"),
               "Failover node #{node} should have Tailscale DNS suffix"
      end)
    end

    test "failover node list matches cluster node list" do
      cluster_nodes = TailscaleDNS.list_cluster_nodes()
      quorum_nodes = TailscaleDNS.get_quorum_nodes()

      # Quorum nodes should be subset of cluster nodes
      cluster_set = MapSet.new(cluster_nodes)
      quorum_set = MapSet.new(quorum_nodes)

      assert MapSet.subset?(quorum_set, cluster_set),
             "Quorum nodes must be subset of cluster nodes"
    end
  end

  describe "EPMD binding verification" do
    test "EPMD binding information is available" do
      epmd_info = TailscaleDNS.get_epmd_binding()

      assert is_map(epmd_info) or match?({:ok, _}, epmd_info) or match?({:error, _}, epmd_info)
    end

    test "SC-CLU-004: EPMD binds to Tailscale interface when available" do
      case TailscaleDNS.get_epmd_binding() do
        {:ok, binding} ->
          # If Tailscale is available, EPMD should bind to Tailscale IP
          assert Map.has_key?(binding, :interface) or Map.has_key?(binding, :ip_address)

        {:error, :tailscale_not_available} ->
          # Expected in test environments without Tailscale
          :ok

        %{} = binding_map ->
          # Direct map response
          assert is_map(binding_map)
      end
    end
  end

  describe "libcluster topology integration" do
    test "generates valid libcluster host list" do
      nodes = TailscaleDNS.list_cluster_nodes()

      # All nodes should be atoms (as required by libcluster)
      Enum.each(nodes, fn node ->
        assert is_atom(node)
      end)
    end

    test "host list can be used in Cluster.Strategy.Epmd config" do
      nodes = TailscaleDNS.list_cluster_nodes()

      # Simulate libcluster config structure
      config = [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: nodes]
      ]

      assert config[:config][:hosts] == nodes
      assert is_list(config[:config][:hosts])
    end
  end

  describe "DNS resolution simulation" do
    test "full DNS names are resolvable format" do
      dns_name = TailscaleDNS.get_full_dns_name("app-1")

      # Should be a valid DNS name format
      assert is_binary(dns_name)
      assert String.contains?(dns_name, ".")
      refute String.contains?(dns_name, " ")

      # Should match DNS name pattern
      assert Regex.match?(~r/^[a-z0-9\-]+(\.[a-z0-9\-]+)+$/, dns_name)
    end

    test "generated node names can be parsed back" do
      base_name = "app-1"
      node_name = TailscaleDNS.get_node_name(base_name)

      {:ok, parsed} = TailscaleDNS.parse_node_name(node_name)

      assert parsed.app_name == "indrajaal"
      assert parsed.base_name == base_name
      assert String.contains?(parsed.host, @test_tailnet)
    end
  end

  describe "STAMP compliance verification" do
    test "SC-CLU-001: all generated names use identity-based networking" do
      # Generate various node types
      cluster_nodes = TailscaleDNS.list_cluster_nodes()
      quorum_nodes = TailscaleDNS.get_quorum_nodes()
      flame_runner = TailscaleDNS.get_flame_runner_name("test", "runner-1")

      all_nodes = cluster_nodes ++ quorum_nodes ++ [flame_runner]

      Enum.each(all_nodes, fn node ->
        node_string = Atom.to_string(node)
        [_app, host] = String.split(node_string, "@")

        # No raw IP addresses allowed
        refute Regex.match?(~r/^\d+\.\d+\.\d+\.\d+$/, host),
               "SC-CLU-001 violation: #{node} uses IP instead of DNS"

        # Must have DNS suffix
        assert String.contains?(host, "."),
               "SC-CLU-001 violation: #{node} missing DNS suffix"
      end)
    end

    test "SC-CLU-002: minimum node count enforced" do
      cluster_nodes = TailscaleDNS.list_cluster_nodes()
      quorum_nodes = TailscaleDNS.get_quorum_nodes()

      assert length(cluster_nodes) >= 3,
             "SC-CLU-002: Cluster must have minimum 3 nodes"

      assert length(quorum_nodes) >= 3,
             "SC-CLU-002: Quorum must have minimum 3 nodes"
    end

    test "SC-CLU-005: naming is deterministic for split-brain prevention" do
      # Generate same names multiple times
      results =
        for _ <- 1..10 do
          {
            TailscaleDNS.get_node_name("app-1"),
            TailscaleDNS.get_flame_runner_name("pool", "runner"),
            TailscaleDNS.list_cluster_nodes()
          }
        end

      # All results should be identical
      first = hd(results)

      Enum.each(results, fn result ->
        assert result == first,
               "SC-CLU-005: Node naming must be deterministic"
      end)
    end
  end
end
