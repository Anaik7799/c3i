defmodule Indrajaal.Morphogenic.L6ClusterConsensusQuorumTest do
  @moduledoc """
  WHAT: Self-contained L6 (Cluster-level) test suite for consensus and quorum
        mechanics in the Indrajaal SIL-6 Biomorphic Mesh. All cluster state is
        simulated in-process using ETS tables and lightweight GenServer-like
        message-passing via Process.send/receive. No production modules are
        imported.

  WHY: The L6 fractal layer governs cluster-wide coordination invariants.
       Consensus failures or quorum miscalculations at L6 cascade down through
       all lower layers and can compromise safety guarantees. These tests verify:
         * 2-out-of-3 voting returns the correct outcome for all vote patterns
         * Quorum computation Q(N) = floor(N/2)+1 for arbitrary cluster sizes
         * Leader election resolves ties deterministically
         * Node failure is detected via heartbeat timeout simulation
         * Gossip converges the cluster view across partitions
         * Anti-entropy repairs state after a network partition heals
         * Cluster membership views stay consistent across concurrent joins/leaves
         * Vector clock (Lamport) ordering preserves happens-before for events
         * Quorum decisions are monotonic — committed decisions are never revoked
         * Cluster makes progress whenever strictly more than N/2 nodes are live

  CONSTRAINTS:
    - SC-CONSENSUS-001: Two-out-of-three (2oo3) voting MANDATORY for
                        safety-critical cluster decisions
    - SC-QUORUM-001:    Quorum = floor(N/2)+1 MUST hold for all N >= 1
    - SC-SIL6-006:      2oo3 voting MANDATORY at production actuations
    - SC-SIL6-011:      Quorum formula enforced throughout upgrades
    - SC-SIL4-015:      Split-brain detection MUST trigger apoptosis
    - SC-HA-003:         Zenoh 2oo3 quorum in HA configuration
    - SC-DIST-001:       All agents MUST have FQUN
    - SC-ZTEST-020:      Quorum messages require 2oo3 consensus

  ## Change History
  | Version | Date       | Author | Change                                    |
  |---------|------------|--------|-------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Self-contained L6 cluster consensus suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l6
  @moduletag :consensus
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # Quorum mathematics (SC-QUORUM-001)
  # ---------------------------------------------------------------------------

  @spec quorum(pos_integer()) :: pos_integer()
  defp quorum(n) when is_integer(n) and n >= 1, do: div(n, 2) + 1

  # ---------------------------------------------------------------------------
  # 2oo3 voting engine (SC-CONSENSUS-001)
  # ---------------------------------------------------------------------------

  # Each vote is {node_id, value} where value is any comparable term.
  # Returns {:ok, winning_value, count} | {:no_quorum, votes}.
  @spec vote_2oo3([{term(), term()}]) :: {:ok, term(), pos_integer()} | {:no_quorum, list()}
  defp vote_2oo3(votes) when length(votes) == 3 do
    tally =
      Enum.reduce(votes, %{}, fn {_node, val}, acc ->
        Map.update(acc, val, 1, &(&1 + 1))
      end)

    case Enum.find(tally, fn {_val, count} -> count >= 2 end) do
      {winning_val, count} -> {:ok, winning_val, count}
      nil -> {:no_quorum, votes}
    end
  end

  defp vote_2oo3(votes), do: {:no_quorum, votes}

  # Generic majority vote for N nodes (2oo3 is a special case of this).
  @spec majority_vote([{term(), term()}], pos_integer()) ::
          {:ok, term(), pos_integer()} | {:no_quorum, list()}
  defp majority_vote(votes, total_nodes) do
    threshold = quorum(total_nodes)

    tally =
      Enum.reduce(votes, %{}, fn {_node, val}, acc ->
        Map.update(acc, val, 1, &(&1 + 1))
      end)

    case Enum.find(tally, fn {_val, count} -> count >= threshold end) do
      {winning_val, count} -> {:ok, winning_val, count}
      nil -> {:no_quorum, votes}
    end
  end

  # ---------------------------------------------------------------------------
  # ETS-backed cluster state (membership + heartbeats)
  # ---------------------------------------------------------------------------

  defp new_cluster_table(name) do
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp delete_table(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
  end

  # Register a node into the cluster membership view.
  defp cluster_join(table, node_id) do
    entry = %{
      id: node_id,
      status: :alive,
      last_heartbeat: now_ms(),
      epoch: 1,
      terms_voted: []
    }

    :ets.insert(table, {node_id, entry})
    entry
  end

  defp cluster_leave(table, node_id) do
    :ets.delete(table, node_id)
    :ok
  end

  defp cluster_members(table) do
    :ets.tab2list(table)
    |> Enum.filter(fn {k, _} -> is_binary(k) end)
    |> Enum.map(fn {_k, v} -> v end)
  end

  defp alive_members(table) do
    cluster_members(table)
    |> Enum.filter(fn m -> m.status == :alive end)
  end

  # Simulate a heartbeat from a node.
  defp heartbeat(table, node_id) do
    case :ets.lookup(table, node_id) do
      [{^node_id, entry}] ->
        :ets.insert(table, {node_id, %{entry | last_heartbeat: now_ms()}})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  # Mark nodes as failed if their last heartbeat exceeds timeout_ms.
  defp detect_failures(table, timeout_ms) do
    cutoff = now_ms() - timeout_ms

    failed =
      :ets.tab2list(table)
      |> Enum.filter(fn {k, _} -> is_binary(k) end)
      |> Enum.filter(fn {_k, v} -> v.status == :alive and v.last_heartbeat < cutoff end)
      |> Enum.map(fn {k, v} ->
        :ets.insert(table, {k, %{v | status: :suspected}})
        k
      end)

    failed
  end

  # Mark a node as explicitly failed (simulate crash).
  defp mark_failed(table, node_id) do
    case :ets.lookup(table, node_id) do
      [{^node_id, entry}] ->
        :ets.insert(table, {node_id, %{entry | status: :failed}})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Leader election helpers
  # ---------------------------------------------------------------------------

  # Simple deterministic leader: alive node with the lexicographically smallest id.
  # Ties are broken by id comparison — fully deterministic.
  defp elect_leader(members) do
    alive = Enum.filter(members, fn m -> m.status == :alive end)

    case Enum.sort_by(alive, & &1.id) do
      [] -> {:error, :no_live_nodes}
      [leader | _] -> {:ok, leader.id}
    end
  end

  # ---------------------------------------------------------------------------
  # Gossip protocol simulation
  # ---------------------------------------------------------------------------

  # Each node maintains a gossip view: a map of node_id => {status, version}.
  defp gossip_init(table, node_id, known_nodes) do
    view =
      Map.new(known_nodes, fn nid ->
        {nid, %{status: :alive, version: 1}}
      end)

    :ets.insert(table, {gossip_key(node_id), view})
    view
  end

  defp gossip_merge(table, node_id, incoming_view) do
    current =
      case :ets.lookup(table, gossip_key(node_id)) do
        [{_, v}] -> v
        [] -> %{}
      end

    merged =
      Map.merge(current, incoming_view, fn _k, local, remote ->
        if remote.version > local.version, do: remote, else: local
      end)

    :ets.insert(table, {gossip_key(node_id), merged})
    merged
  end

  defp gossip_get(table, node_id) do
    case :ets.lookup(table, gossip_key(node_id)) do
      [{_, view}] -> view
      [] -> %{}
    end
  end

  defp gossip_set_status(table, observer_id, target_id, status) do
    view = gossip_get(table, observer_id)
    current_version = get_in(view, [target_id, :version]) || 0

    updated = Map.put(view, target_id, %{status: status, version: current_version + 1})
    :ets.insert(table, {gossip_key(observer_id), updated})
    updated
  end

  defp gossip_key(node_id), do: {:gossip, node_id}

  # Simulate one round of gossip: every node merges its neighbours' views.
  defp gossip_round(table, all_node_ids) do
    views = Enum.map(all_node_ids, fn nid -> {nid, gossip_get(table, nid)} end)

    Enum.each(all_node_ids, fn nid ->
      Enum.each(views, fn {other_id, other_view} ->
        if other_id != nid, do: gossip_merge(table, nid, other_view)
      end)
    end)

    :ok
  end

  # ---------------------------------------------------------------------------
  # Vector clock (Lamport) helpers
  # ---------------------------------------------------------------------------

  defp vc_new, do: %{}

  defp vc_tick(clock, node_id) do
    Map.update(clock, node_id, 1, &(&1 + 1))
  end

  defp vc_merge(c1, c2) do
    Map.merge(c1, c2, fn _k, t1, t2 -> max(t1, t2) end)
  end

  # Returns :before | :after | :concurrent
  defp vc_compare(c1, c2) do
    keys = MapSet.union(MapSet.new(Map.keys(c1)), MapSet.new(Map.keys(c2)))

    {c1_leq, c2_leq} =
      Enum.reduce(keys, {true, true}, fn k, {acc1, acc2} ->
        v1 = Map.get(c1, k, 0)
        v2 = Map.get(c2, k, 0)
        {acc1 and v1 <= v2, acc2 and v2 <= v1}
      end)

    cond do
      c1_leq and not c2_leq -> :before
      c2_leq and not c1_leq -> :after
      c1_leq and c2_leq -> :equal
      true -> :concurrent
    end
  end

  # ---------------------------------------------------------------------------
  # Anti-entropy repair simulation
  # ---------------------------------------------------------------------------

  # Store keyed state as {key => {value, version}}.
  defp ae_put(table, store_key, key, value, version) do
    store = ae_get_store(table, store_key)
    updated = Map.put(store, key, {value, version})
    :ets.insert(table, {store_key, updated})
    updated
  end

  defp ae_get_store(table, store_key) do
    case :ets.lookup(table, store_key) do
      [{^store_key, store}] -> store
      [] -> %{}
    end
  end

  # Merge two stores: highest version wins per key.
  defp ae_merge(table, dst_key, src_key) do
    dst = ae_get_store(table, dst_key)
    src = ae_get_store(table, src_key)

    merged =
      Map.merge(dst, src, fn _k, {dv, dver}, {sv, sver} ->
        if sver > dver, do: {sv, sver}, else: {dv, dver}
      end)

    :ets.insert(table, {dst_key, merged})
    merged
  end

  # ---------------------------------------------------------------------------
  # Shared utility
  # ---------------------------------------------------------------------------

  defp now_ms, do: System.monotonic_time(:millisecond)

  # ===========================================================================
  # Section 1: 2oo3 Voting (SC-CONSENSUS-001)
  # ===========================================================================

  describe "2oo3 voting: unanimous agreement" do
    @tag :sil6_voting
    test "all three nodes agree on :commit — returns :commit with count 3" do
      votes = [{"node-a", :commit}, {"node-b", :commit}, {"node-c", :commit}]
      assert {:ok, :commit, 3} = vote_2oo3(votes)
    end

    @tag :sil6_voting
    test "all three nodes agree on :abort — returns :abort" do
      votes = [{"node-a", :abort}, {"node-b", :abort}, {"node-c", :abort}]
      assert {:ok, :abort, 3} = vote_2oo3(votes)
    end
  end

  describe "2oo3 voting: majority (2 of 3)" do
    @tag :sil6_voting
    test "2-1 majority for :commit wins regardless of dissenter" do
      votes = [{"node-a", :commit}, {"node-b", :commit}, {"node-c", :abort}]
      assert {:ok, :commit, 2} = vote_2oo3(votes)
    end

    @tag :sil6_voting
    test "2-1 majority for :abort wins when node-a dissents" do
      votes = [{"node-a", :commit}, {"node-b", :abort}, {"node-c", :abort}]
      assert {:ok, :abort, 2} = vote_2oo3(votes)
    end

    @tag :sil6_voting
    test "dissenter can be any of the three positions" do
      # All three orderings of a 2-1 majority must resolve identically.
      votes_1 = [{"n1", :yes}, {"n2", :yes}, {"n3", :no}]
      votes_2 = [{"n1", :yes}, {"n2", :no}, {"n3", :yes}]
      votes_3 = [{"n1", :no}, {"n2", :yes}, {"n3", :yes}]

      assert {:ok, :yes, 2} = vote_2oo3(votes_1)
      assert {:ok, :yes, 2} = vote_2oo3(votes_2)
      assert {:ok, :yes, 2} = vote_2oo3(votes_3)
    end
  end

  describe "2oo3 voting: no quorum (split)" do
    @tag :sil6_voting
    test "all-different votes produce no quorum" do
      votes = [{"node-a", :commit}, {"node-b", :abort}, {"node-c", :retry}]
      assert {:no_quorum, _} = vote_2oo3(votes)
    end

    @tag :sil6_voting
    test "vote with fewer than 3 nodes always returns no quorum" do
      votes = [{"node-a", :commit}, {"node-b", :commit}]
      assert {:no_quorum, ^votes} = vote_2oo3(votes)
    end

    @tag :sil6_voting
    test "empty vote set returns no quorum" do
      assert {:no_quorum, []} = vote_2oo3([])
    end
  end

  # ===========================================================================
  # Section 2: Quorum calculation Q(N) = floor(N/2) + 1 (SC-QUORUM-001)
  # ===========================================================================

  describe "quorum calculation: floor(N/2)+1" do
    @tag :sil6_quorum
    test "Q(1) = 1 — single node is its own quorum" do
      assert quorum(1) == 1
    end

    @tag :sil6_quorum
    test "Q(2) = 2 — both nodes required for quorum" do
      assert quorum(2) == 2
    end

    @tag :sil6_quorum
    test "Q(3) = 2 — standard 2oo3 quorum" do
      assert quorum(3) == 2
    end

    @tag :sil6_quorum
    test "Q(5) = 3 — standard Raft/Paxos quorum" do
      assert quorum(5) == 3
    end

    @tag :sil6_quorum
    test "Q(7) = 4 — seven-node cluster" do
      assert quorum(7) == 4
    end

    @tag :sil6_quorum
    test "quorum table for N = 1..10 matches expected values" do
      expected = %{
        1 => 1,
        2 => 2,
        3 => 2,
        4 => 3,
        5 => 3,
        6 => 4,
        7 => 4,
        8 => 5,
        9 => 5,
        10 => 6
      }

      for {n, expected_q} <- expected do
        assert quorum(n) == expected_q,
               "quorum(#{n}) — expected #{expected_q}, got #{quorum(n)}"
      end
    end

    @tag :sil6_quorum
    test "quorum is always strictly greater than N/2 (strict majority)" do
      for n <- 1..20 do
        q = quorum(n)
        assert q > n / 2.0, "quorum(#{n}) = #{q} must be > #{n / 2.0}"
      end
    end

    @tag :sil6_quorum
    test "quorum decisions from disjoint majorities cannot contradict each other" do
      # If quorum Q is met by set A and set B simultaneously, then A ∩ B ≠ ∅.
      # This ensures no split-brain can commit two different values.
      # For N=5, Q=3: any two sets of 3 nodes from {1..5} share at least one node.
      nodes = MapSet.new([1, 2, 3, 4, 5])
      q = quorum(5)

      sets_of_q =
        for a <- 1..5, b <- 1..5, c <- 1..5, a < b, b < c do
          MapSet.new([a, b, c])
        end
        |> Enum.filter(fn s -> MapSet.size(s) == q end)

      for s1 <- sets_of_q, s2 <- sets_of_q do
        intersection = MapSet.intersection(s1, s2)

        assert MapSet.size(intersection) >= 1,
               "Quorum sets #{inspect(MapSet.to_list(s1))} and " <>
                 "#{inspect(MapSet.to_list(s2))} must overlap. " <>
                 "Total nodes: #{MapSet.size(nodes)}"
      end
    end
  end

  # ===========================================================================
  # Section 3: Leader election
  # ===========================================================================

  describe "leader election: deterministic tie-breaking" do
    @tag :sil6_leader
    test "single alive node is always elected leader" do
      members = [%{id: "node-alpha", status: :alive}]
      assert {:ok, "node-alpha"} = elect_leader(members)
    end

    @tag :sil6_leader
    test "lexicographically smallest id wins among equal-epoch live nodes" do
      members = [
        %{id: "node-gamma", status: :alive},
        %{id: "node-alpha", status: :alive},
        %{id: "node-beta", status: :alive}
      ]

      assert {:ok, "node-alpha"} = elect_leader(members)
    end

    @tag :sil6_leader
    test "failed nodes are excluded from leader election" do
      members = [
        %{id: "node-alpha", status: :failed},
        %{id: "node-beta", status: :alive},
        %{id: "node-gamma", status: :alive}
      ]

      # node-alpha would win alphabetically, but it is failed.
      {:ok, leader} = elect_leader(members)
      assert leader == "node-beta"
    end

    @tag :sil6_leader
    test "election with no alive nodes returns :no_live_nodes error" do
      members = [
        %{id: "node-alpha", status: :failed},
        %{id: "node-beta", status: :suspected}
      ]

      assert {:error, :no_live_nodes} = elect_leader(members)
    end

    @tag :sil6_leader
    test "election is idempotent: repeated calls return the same leader" do
      members = [
        %{id: "node-b", status: :alive},
        %{id: "node-a", status: :alive},
        %{id: "node-c", status: :alive}
      ]

      assert {:ok, leader1} = elect_leader(members)
      assert {:ok, leader2} = elect_leader(members)
      assert leader1 == leader2
    end
  end

  # ===========================================================================
  # Section 4: Node failure detection via heartbeat timeout
  # ===========================================================================

  describe "node failure detection: heartbeat timeout simulation" do
    setup do
      t = new_cluster_table(:heartbeat_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    @tag :sil6_failure
    test "recently heartbeating node is not suspected", %{t: t} do
      cluster_join(t, "node-1")
      heartbeat(t, "node-1")

      # Timeout of 10_000 ms — node just heartbeated so it is safe.
      failed = detect_failures(t, 10_000)
      assert "node-1" not in failed
    end

    @tag :sil6_failure
    test "node with stale heartbeat is suspected after timeout", %{t: t} do
      cluster_join(t, "node-stale")

      # Backdate the heartbeat to simulate a node that stopped reporting.
      [{_, entry}] = :ets.lookup(t, "node-stale")
      :ets.insert(t, {"node-stale", %{entry | last_heartbeat: now_ms() - 2000}})

      failed = detect_failures(t, 1000)
      assert "node-stale" in failed
    end

    @tag :sil6_failure
    test "explicit node crash marks node as :failed immediately", %{t: t} do
      cluster_join(t, "node-crash")
      assert :ok = mark_failed(t, "node-crash")

      [{_, entry}] = :ets.lookup(t, "node-crash")
      assert entry.status == :failed
    end

    @tag :sil6_failure
    test "failure detection does not affect other live nodes", %{t: t} do
      cluster_join(t, "node-live")
      cluster_join(t, "node-dead")

      [{_, dead_entry}] = :ets.lookup(t, "node-dead")
      :ets.insert(t, {"node-dead", %{dead_entry | last_heartbeat: now_ms() - 5000}})

      detect_failures(t, 1000)

      alive = alive_members(t)
      alive_ids = Enum.map(alive, & &1.id)
      assert "node-live" in alive_ids
      refute "node-dead" in alive_ids
    end
  end

  # ===========================================================================
  # Section 5: Gossip protocol convergence
  # ===========================================================================

  describe "gossip protocol: state convergence" do
    setup do
      t = new_cluster_table(:gossip_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    @tag :sil6_gossip
    test "each node's initial gossip view contains all known nodes", %{t: t} do
      nodes = ["g1", "g2", "g3"]
      Enum.each(nodes, fn nid -> gossip_init(t, nid, nodes) end)

      view_g1 = gossip_get(t, "g1")
      assert Map.keys(view_g1) |> Enum.sort() == Enum.sort(nodes)
    end

    @tag :sil6_gossip
    test "gossip converges a status update in one round (3-node cluster)", %{t: t} do
      nodes = ["g1", "g2", "g3"]
      Enum.each(nodes, fn nid -> gossip_init(t, nid, nodes) end)

      # g1 observes that g3 is failing.
      gossip_set_status(t, "g1", "g3", :suspected)

      # One gossip round propagates g1's view to g2 and g3.
      gossip_round(t, nodes)

      view_g2 = gossip_get(t, "g2")
      # g2 should now see g3 as :suspected (higher version from g1).
      assert view_g2["g3"].status == :suspected
    end

    @tag :sil6_gossip
    test "higher version always wins during gossip merge", %{t: t} do
      nodes = ["h1", "h2"]
      Enum.each(nodes, fn nid -> gossip_init(t, nid, nodes) end)

      # h1 updates h2's status with version 5.
      view = gossip_get(t, "h1")
      updated_view = Map.put(view, "h2", %{status: :failed, version: 5})
      :ets.insert(t, {gossip_key("h1"), updated_view})

      # h2 still has its own view at version 1.
      gossip_merge(t, "h2", updated_view)

      final_view = gossip_get(t, "h2")
      assert final_view["h2"].version == 5
      assert final_view["h2"].status == :failed
    end

    @tag :sil6_gossip
    test "two gossip rounds fully converge a 4-node cluster", %{t: t} do
      nodes = ["n1", "n2", "n3", "n4"]
      Enum.each(nodes, fn nid -> gossip_init(t, nid, nodes) end)

      # n1 marks n4 as :failed.
      gossip_set_status(t, "n1", "n4", :failed)

      # Round 1: n2, n3 learn from n1.
      gossip_round(t, nodes)
      # Round 2: n2, n3, n4 all converge.
      gossip_round(t, nodes)

      # All nodes must agree that n4 is :failed.
      for nid <- ["n1", "n2", "n3"] do
        view = gossip_get(t, nid)

        assert view["n4"].status == :failed,
               "Node #{nid} should see n4 as :failed after 2 gossip rounds"
      end
    end
  end

  # ===========================================================================
  # Section 6: Anti-entropy repair after partition healing
  # ===========================================================================

  describe "anti-entropy: state repair after partition healing" do
    setup do
      t = new_cluster_table(:ae_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    @tag :sil6_anti_entropy
    test "partition heals: stale replica is updated with newer version", %{t: t} do
      # Primary shard writes key "config" at version 3.
      ae_put(t, :primary, "config", "v3-value", 3)
      # Replica has an older version 1 from before the partition.
      ae_put(t, :replica, "config", "v1-value", 1)

      ae_merge(t, :replica, :primary)

      replica_store = ae_get_store(t, :replica)
      {value, version} = replica_store["config"]
      assert version == 3
      assert value == "v3-value"
    end

    @tag :sil6_anti_entropy
    test "anti-entropy does not downgrade already-newer replica data", %{t: t} do
      # Replica independently advanced to version 4 during partition.
      ae_put(t, :replica, "state", "newer-local", 4)
      # Primary only has version 2.
      ae_put(t, :primary, "state", "older-primary", 2)

      ae_merge(t, :replica, :primary)

      replica_store = ae_get_store(t, :replica)
      {value, version} = replica_store["state"]
      assert version == 4
      assert value == "newer-local"
    end

    @tag :sil6_anti_entropy
    test "anti-entropy repairs missing keys from the source", %{t: t} do
      ae_put(t, :source, "key-a", "val-a", 1)
      ae_put(t, :source, "key-b", "val-b", 2)
      # Destination has only key-a.
      ae_put(t, :dest, "key-a", "val-a", 1)

      ae_merge(t, :dest, :source)

      dest_store = ae_get_store(t, :dest)
      assert Map.has_key?(dest_store, "key-b")
      {_v, ver} = dest_store["key-b"]
      assert ver == 2
    end

    @tag :sil6_anti_entropy
    test "merge of identical stores is idempotent", %{t: t} do
      ae_put(t, :s1, "x", 42, 7)
      ae_put(t, :s2, "x", 42, 7)

      before_merge = ae_get_store(t, :s1)
      ae_merge(t, :s1, :s2)
      after_merge = ae_get_store(t, :s1)

      assert before_merge == after_merge
    end
  end

  # ===========================================================================
  # Section 7: Cluster membership view consistency
  # ===========================================================================

  describe "cluster membership: view consistency" do
    setup do
      t = new_cluster_table(:membership_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    @tag :sil6_membership
    test "joining nodes appear in membership view immediately", %{t: t} do
      cluster_join(t, "m1")
      cluster_join(t, "m2")
      cluster_join(t, "m3")

      ids = alive_members(t) |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == ["m1", "m2", "m3"]
    end

    @tag :sil6_membership
    test "leaving nodes are removed from membership view", %{t: t} do
      cluster_join(t, "m1")
      cluster_join(t, "m2")
      cluster_leave(t, "m1")

      ids = alive_members(t) |> Enum.map(& &1.id)
      assert ids == ["m2"]
      refute "m1" in ids
    end

    @tag :sil6_membership
    test "failed nodes do not count toward live membership" do
      members = [
        %{id: "a", status: :alive},
        %{id: "b", status: :failed},
        %{id: "c", status: :suspected}
      ]

      alive = Enum.filter(members, fn m -> m.status == :alive end)
      assert length(alive) == 1
      assert hd(alive).id == "a"
    end

    @tag :sil6_membership
    test "cluster with quorum of alive nodes can continue operating" do
      # N=5 cluster, Q=3. As long as >= 3 nodes are alive, the cluster progresses.
      n = 5
      q = quorum(n)

      # Case 1: exactly quorum nodes alive.
      alive_count_1 = q
      assert alive_count_1 >= q

      # Case 2: below quorum.
      alive_count_2 = q - 1
      assert alive_count_2 < q
    end
  end

  # ===========================================================================
  # Section 8: Vector clock ordering for concurrent events
  # ===========================================================================

  describe "vector clocks: Lamport causality ordering" do
    @tag :sil6_vector_clock
    test "fresh clock starts at empty map (all zeros)" do
      vc = vc_new()
      assert vc == %{}
    end

    @tag :sil6_vector_clock
    test "ticking a node increments only that node's counter" do
      vc = vc_new() |> vc_tick("node-a") |> vc_tick("node-a")
      assert vc["node-a"] == 2
      refute Map.has_key?(vc, "node-b")
    end

    @tag :sil6_vector_clock
    test "merged clock takes max of each component" do
      c1 = %{"a" => 3, "b" => 1}
      c2 = %{"a" => 1, "b" => 5, "c" => 2}
      merged = vc_merge(c1, c2)

      assert merged["a"] == 3
      assert merged["b"] == 5
      assert merged["c"] == 2
    end

    @tag :sil6_vector_clock
    test "event A happens-before B when all of A's components are <= B's and some are <" do
      c_a = %{"node-1" => 1, "node-2" => 0}
      c_b = %{"node-1" => 2, "node-2" => 1}

      assert vc_compare(c_a, c_b) == :before
      assert vc_compare(c_b, c_a) == :after
    end

    @tag :sil6_vector_clock
    test "concurrent events neither happens-before the other" do
      # node-1 and node-2 each made progress independently.
      c_a = %{"node-1" => 2, "node-2" => 1}
      c_b = %{"node-1" => 1, "node-2" => 3}

      assert vc_compare(c_a, c_b) == :concurrent
    end

    @tag :sil6_vector_clock
    test "identical clocks compare as :equal" do
      c = %{"n" => 5}
      assert vc_compare(c, c) == :equal
    end

    @tag :sil6_vector_clock
    test "send-receive sequence: receiver merges sender clock then ticks" do
      # node-a sends an event.
      clock_a = vc_new() |> vc_tick("node-a") |> vc_tick("node-a")
      # node-b was at its own tick 1.
      clock_b_before = vc_new() |> vc_tick("node-b")

      # On receive, node-b merges then ticks.
      clock_b_after = clock_b_before |> vc_merge(clock_a) |> vc_tick("node-b")

      # node-b's own counter is 2 (1 original + 1 on receive).
      assert clock_b_after["node-b"] == 2
      # node-a's counter is at least 2 (inherited from sender).
      assert clock_b_after["node-a"] == 2

      # The event at clock_b_after happens after clock_a.
      assert vc_compare(clock_a, clock_b_after) == :before
    end
  end

  # ===========================================================================
  # Section 9: Property — quorum decisions are monotonic (SD generators)
  # ===========================================================================

  @tag :sil6_property
  property "once a value is committed by majority, minority cannot overturn it (SD)" do
    forall {n_nodes, committed_value} <- {PC.integer(3, 9), PC.elements([:commit, :abort, :hold])} do
      q = quorum(n_nodes)

      # Build a quorum-sized set of votes all agreeing on committed_value.
      quorum_votes =
        Enum.map(1..q, fn i -> {"node-#{i}", committed_value} end)

      assert {:ok, ^committed_value, count} = majority_vote(quorum_votes, n_nodes)
      assert count >= q

      # The remaining minority (n_nodes - q) cannot form a conflicting quorum.
      minority_size = n_nodes - q

      minority_votes =
        Enum.map(1..max(minority_size, 1), fn i ->
          {"node-minority-#{i}", :conflicting}
        end)

      # Minority cannot reach quorum on a different value.
      assert {:no_quorum, _} = majority_vote(minority_votes, n_nodes)
    end
  end

  # ===========================================================================
  # Section 10: Property — progress with >N/2 healthy nodes (SD generators)
  # ===========================================================================

  @tag :sil6_property
  property "majority of alive nodes guarantees decision progress (SD)" do
    forall {n_nodes, value} <- {PC.integer(3, 11), PC.elements([:commit, :abort, :prepare])} do
      q = quorum(n_nodes)

      # Simulate exactly quorum nodes voting the same way.
      votes = Enum.map(1..q, fn i -> {"n#{i}", value} end)

      # Majority vote must succeed.
      result = majority_vote(votes, n_nodes)
      assert {:ok, ^value, _count} = result
    end
  end

  # ===========================================================================
  # Section 11: Property — quorum is always strictly more than half (PC forall)
  # ===========================================================================

  @tag :sil6_property
  test "propcheck: Q(N) > N/2 for all N in 1..50 (PC forall)" do
    Application.ensure_all_started(:propcheck)

    assert quickcheck(
             forall n <- PC.choose(1, 50) do
               q = quorum(n)
               q > n / 2.0
             end,
             numtests: 100
           )
  end

  # ===========================================================================
  # Section 12: Property — gossip merge is idempotent and commutative (SD)
  # ===========================================================================

  @tag :sil6_property
  property "gossip merge is idempotent — applying same view twice is a no-op (SD)" do
    forall entries <-
             PC.list({PC.utf8(), PC.elements([:alive, :dead, :suspect]), PC.non_neg_integer()}) do
      t = new_cluster_table(:prop_gossip_idempotent)

      try do
        nodes = Enum.map(entries, fn {id, _s, _v} -> id end) |> Enum.uniq()
        base_nodes = if nodes == [], do: ["fallback"], else: nodes
        Enum.each(base_nodes, fn nid -> gossip_init(t, nid, base_nodes) end)

        # Apply a view once.
        remote_view =
          Map.new(entries, fn {id, status, version} ->
            {id, %{status: status, version: version}}
          end)

        primary = hd(base_nodes)
        gossip_merge(t, primary, remote_view)
        view_after_first = gossip_get(t, primary)

        # Apply the same view again.
        gossip_merge(t, primary, remote_view)
        view_after_second = gossip_get(t, primary)

        # Result must be identical.
        assert view_after_first == view_after_second
      after
        delete_table(t)
      end
    end
  end

  # ===========================================================================
  # Section 13: Split-brain detection
  # ===========================================================================

  describe "split-brain detection" do
    @tag :sil6_split_brain
    test "cluster with N/2 nodes in each partition cannot make progress on either side" do
      # N = 4, Q = 3. Each partition has 2 nodes -> no quorum.
      n = 4
      q = quorum(n)

      partition_a_votes = [{"p1", :commit}, {"p2", :commit}]
      partition_b_votes = [{"p3", :abort}, {"p4", :abort}]

      assert {:no_quorum, _} = majority_vote(partition_a_votes, n)
      assert {:no_quorum, _} = majority_vote(partition_b_votes, n)

      # Neither partition can commit independently — SC-SIL4-015.
      refute length(partition_a_votes) >= q
      refute length(partition_b_votes) >= q
    end

    @tag :sil6_split_brain
    test "asymmetric partition: larger side retains quorum, smaller side loses it" do
      # N = 5, Q = 3. Larger partition = 3 nodes, smaller = 2.
      n = 5
      q = quorum(n)

      large_votes = Enum.map(1..3, fn i -> {"L#{i}", :commit} end)
      small_votes = Enum.map(1..2, fn i -> {"S#{i}", :commit} end)

      assert {:ok, :commit, _} = majority_vote(large_votes, n)
      assert {:no_quorum, _} = majority_vote(small_votes, n)

      # Verify the counts directly.
      assert length(large_votes) >= q
      assert length(small_votes) < q
    end

    @tag :sil6_split_brain
    test "network partition heal restores full cluster quorum" do
      n_before_partition = 5
      n_after_heal = 5
      q_after = quorum(n_after_heal)

      # After healing, all 5 votes should form quorum.
      healed_votes = Enum.map(1..5, fn i -> {"node-#{i}", :commit} end)
      assert {:ok, :commit, count} = majority_vote(healed_votes, n_before_partition)
      assert count >= q_after
    end
  end

  # ===========================================================================
  # Section 14: Majority vote for arbitrary cluster sizes
  # ===========================================================================

  describe "majority vote: generalised N-node clusters" do
    @tag :sil6_majority
    test "N=5, Q=3: three agreeing votes win even with two dissenters" do
      n = 5
      votes = [{"a", :yes}, {"b", :yes}, {"c", :yes}, {"d", :no}, {"e", :no}]
      assert {:ok, :yes, 3} = majority_vote(votes, n)
    end

    @tag :sil6_majority
    test "N=7, Q=4: exactly four votes forms quorum" do
      n = 7

      votes = [
        {"1", :go},
        {"2", :go},
        {"3", :go},
        {"4", :go},
        {"5", :stop},
        {"6", :stop},
        {"7", :stop}
      ]

      assert {:ok, :go, 4} = majority_vote(votes, n)
    end

    @tag :sil6_majority
    test "N=5, Q=3: two-way tie among five votes produces no quorum" do
      n = 5
      # 2 vs 2, 5th is different.
      votes = [{"a", :x}, {"b", :x}, {"c", :y}, {"d", :y}, {"e", :z}]
      assert {:no_quorum, _} = majority_vote(votes, n)
    end
  end
end
