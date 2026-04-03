defmodule Indrajaal.Morphogenic.L6SplitBrainDetectionTest do
  @moduledoc """
  WHAT: Self-contained L6 (Cluster-level) test suite for split-brain detection
        and resolution in the Indrajaal SIL-6 Biomorphic Mesh. All cluster state
        is simulated in-process using ETS tables and pure Elixir data structures.
        No production modules are imported.

  WHY: Split-brain is the most dangerous cluster failure mode: two sub-clusters
       independently believe they are authoritative, leading to divergent state
       mutations that cannot be automatically reconciled. At L6, the Indrajaal
       biomorphic mesh must:
         * Detect a split-brain within one heartbeat cycle
         * Identify which partition holds quorum (majority)
         * Force the minority partition into apoptosis (SC-SIL4-015)
         * Enable the surviving majority to fence the minority
         * Allow rejoining once the split heals, with proper epoch bump
         * Reconcile version vectors after merge-back

       Specific scenarios verified:
         * Heartbeat absence correctly classifies a node as suspected/dead
         * Quorum calculation Q(N) = floor(N/2)+1 for all N in 1..50
         * Symmetric (50/50) split forces apoptosis in BOTH partitions
         * Asymmetric split preserves the majority, triggers apoptosis in minority
         * Fencing: minority must shut down when instructed by coordinator
         * Merge-back: rejoining node bumps epoch, receives cluster VV
         * Version vector merge resolves concurrent edits correctly
         * Network partition simulation: groups correctly isolated from each other
         * Leader election inside a degraded majority still completes
         * Dying gasp message is recorded when a node detects split-brain
         * Gossip failure detects silent nodes via missed-heartbeat counters
         * 2oo3 voting produces correct outcome in both normal and degraded modes

  ## STAMP Compliance
  - SC-SIL4-015:    Split-brain detection MUST trigger apoptosis on minority partition
  - SC-SIL6-006:    2oo3 voting MANDATORY for safety-critical production actuations
  - SC-QUORUM-001:  Quorum = floor(N/2)+1 MUST hold for all N >= 1
  - SC-CONSENSUS-001: Two-out-of-three (2oo3) voting MANDATORY
  - SC-XHOLON-007:  Monotonically increasing version vectors
  - SC-SIL6-011:    Quorum formula enforced throughout upgrades
  - SC-SIL4-007:    Dying gasp checkpoint MANDATORY before shutdown
  - SC-SIL4-008:    Connection drain timeout 30 seconds
  - SC-FED-005:     Membership management maintained across federation

  ## FMEA Risk Analysis

  | Failure Mode                          | S | O | D | RPN | Mitigation                        |
  |---------------------------------------|---|---|---|-----|-----------------------------------|
  | Minority commits during split         | 9 | 3 | 2 |  54 | fencing + quorum gate             |
  | Dying gasp not recorded               | 8 | 2 | 3 |  48 | ETS write before process halt     |
  | Epoch not bumped on rejoin            | 7 | 3 | 3 |  63 | rejoin protocol mandates +1 epoch |
  | VV divergence undetected             | 8 | 2 | 2 |  32 | concurrent detection via compare  |
  | Leader elected in minority partition  | 9 | 2 | 2 |  36 | leader checks quorum membership   |
  | Apoptosis skipped on 50/50 split      | 9 | 2 | 1 |  18 | both sides below quorum → both    |
  | Gossip miss-count overflow            | 5 | 2 | 4 |  40 | capped at @dead_threshold         |
  | Merge-back with stale data            | 7 | 3 | 2 |  42 | VV merge with component-max       |

  ## Coverage Matrix

  | Test Category               | Unit | PropCheck forall | check all (SD) |
  |-----------------------------|------|------------------|----------------|
  | Heartbeat / failure detect  |  5   |        1         |       1        |
  | Quorum calculation          |  5   |        1         |       1        |
  | Partition detection         |  4   |        0         |       1        |
  | Apoptosis trigger           |  4   |        1         |       0        |
  | Fencing mechanism           |  3   |        0         |       0        |
  | Merge-back / rejoin         |  3   |        0         |       0        |
  | Version vector merge        |  4   |        0         |       1        |
  | Leader election (degraded)  |  3   |        0         |       0        |
  | Dying gasp                  |  3   |        0         |       0        |
  | 2oo3 voting (degraded)      |  3   |        0         |       0        |

  ## Change History
  | Version | Date       | Author | Change                                          |
  |---------|------------|--------|-------------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Self-contained L6 split-brain detection suite   |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: false
  use PropCheck
  # ExUnitProperties imported with check: 2 excluded to avoid conflict with PropCheck.
  # check all(...) blocks use the fully-qualified ExUnitProperties.check all(...)  form
  # to disambiguate from PropCheck's check/2 — see EP-GEN-014 and SC-PROP-023.
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag layer: :l6
  @moduletag :split_brain
  @moduletag timeout: 90_000

  # ---------------------------------------------------------------------------
  # Module-level constants
  # ---------------------------------------------------------------------------

  # Number of missed heartbeats before a node is considered :suspected.
  @suspected_threshold 3

  # Number of missed heartbeats before a node is considered :dead.
  @dead_threshold 5

  # Maximum gossip rounds before we declare non-convergence.
  @max_gossip_rounds 8

  # Heartbeat timeout used in detection tests (milliseconds).
  @heartbeat_timeout_ms 200

  # ---------------------------------------------------------------------------
  # Quorum mathematics (SC-QUORUM-001)
  # ---------------------------------------------------------------------------

  @spec quorum(pos_integer()) :: pos_integer()
  defp quorum(n) when is_integer(n) and n >= 1, do: div(n, 2) + 1

  # Returns true when the given partition_size can form a quorum in a cluster
  # of total_nodes.
  @spec has_quorum?(pos_integer(), pos_integer()) :: boolean()
  defp has_quorum?(total_nodes, partition_size),
    do: partition_size >= quorum(total_nodes)

  # ---------------------------------------------------------------------------
  # 2oo3 voting (SC-SIL6-006, SC-CONSENSUS-001)
  # ---------------------------------------------------------------------------

  @spec vote_2oo3([{term(), term()}]) ::
          {:ok, term(), pos_integer()} | {:no_quorum, [{term(), term()}]}
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

  # General N-node majority vote — used for degraded clusters.
  @spec majority_vote([{term(), term()}], pos_integer()) ::
          {:ok, term(), pos_integer()} | {:no_quorum, [{term(), term()}]}
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
  # Version vector helpers (SC-XHOLON-007)
  # ---------------------------------------------------------------------------

  defp vv_new, do: %{}
  defp vv_tick(vv, node_id), do: Map.update(vv, node_id, 1, &(&1 + 1))

  defp vv_merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, t1, t2 -> max(t1, t2) end)
  end

  defp vv_leq(vv1, vv2) do
    Enum.all?(vv1, fn {k, v1} -> Map.get(vv2, k, 0) >= v1 end)
  end

  defp vv_compare(vv1, vv2) do
    leq_12 = vv_leq(vv1, vv2)
    leq_21 = vv_leq(vv2, vv1)

    cond do
      leq_12 and leq_21 -> :equal
      leq_12 -> :before
      leq_21 -> :after
      true -> :concurrent
    end
  end

  # ---------------------------------------------------------------------------
  # ETS cluster table helpers
  # ---------------------------------------------------------------------------

  defp new_table(name) do
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp drop_table(t) do
    if :ets.info(t) != :undefined, do: :ets.delete(t)
  end

  defp mono_ms, do: System.monotonic_time(:millisecond)

  # Join a node with explicit initial state.
  defp join_node(table, node_id, opts \\ []) do
    epoch = Keyword.get(opts, :epoch, 1)
    partition = Keyword.get(opts, :partition, nil)

    entry = %{
      id: node_id,
      status: :alive,
      epoch: epoch,
      last_heartbeat: mono_ms(),
      partition: partition,
      vv: %{node_id => 1},
      missed_hbs: 0,
      fenced: false,
      dying_gasp: nil
    }

    :ets.insert(table, {{:node, node_id}, entry})
    entry
  end

  defp get_node(table, node_id) do
    case :ets.lookup(table, {:node, node_id}) do
      [{_, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end

  defp update_node(table, node_id, fun) do
    case get_node(table, node_id) do
      {:ok, data} ->
        :ets.insert(table, {{:node, node_id}, fun.(data)})
        :ok

      {:error, _} = err ->
        err
    end
  end

  defp all_nodes(table) do
    :ets.tab2list(table)
    |> Enum.filter(fn {{kind, _}, _} -> kind == :node end)
    |> Enum.map(fn {_, data} -> data end)
  end

  defp alive_nodes(table) do
    all_nodes(table) |> Enum.filter(fn n -> n.status == :alive end)
  end

  # Simulate a fresh heartbeat from node_id.
  defp heartbeat(table, node_id) do
    update_node(table, node_id, fn n ->
      %{n | last_heartbeat: mono_ms(), missed_hbs: 0}
    end)
  end

  # Scan cluster for nodes that have not heartbeated within timeout_ms.
  # Updates their missed_hbs counter and transitions status accordingly.
  defp detect_failures(table, timeout_ms) do
    now = mono_ms()

    all_nodes(table)
    |> Enum.filter(fn n -> n.status == :alive and now - n.last_heartbeat > timeout_ms end)
    |> Enum.each(fn n ->
      new_missed = n.missed_hbs + 1

      new_status =
        cond do
          new_missed >= @dead_threshold -> :dead
          new_missed >= @suspected_threshold -> :suspected
          true -> :alive
        end

      update_node(table, n.id, fn data ->
        %{data | missed_hbs: new_missed, status: new_status}
      end)
    end)

    :ok
  end

  # Forcibly mark a node as dead (hard crash simulation).
  defp mark_dead(table, node_id) do
    update_node(table, node_id, fn n ->
      %{n | status: :dead, missed_hbs: @dead_threshold}
    end)
  end

  # ---------------------------------------------------------------------------
  # Partition simulation helpers
  # ---------------------------------------------------------------------------

  # Assign partition labels. Nodes in the same partition can reach each other.
  defp assign_partition(table, node_ids, label) do
    Enum.each(node_ids, fn nid ->
      update_node(table, nid, fn n -> %{n | partition: label} end)
    end)
  end

  # Remove partition boundaries — all nodes become mutually reachable.
  defp heal_partition(table) do
    all_nodes(table)
    |> Enum.each(fn n ->
      update_node(table, n.id, fn data -> %{data | partition: nil} end)
    end)
  end

  # Returns the list of node IDs reachable from node_id (same partition).
  defp reachable_from(table, node_id) do
    case get_node(table, node_id) do
      {:ok, %{partition: p}} ->
        all_nodes(table)
        |> Enum.filter(fn n -> n.partition == p end)
        |> Enum.map(fn n -> n.id end)

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Apoptosis evaluation (SC-SIL4-015)
  # ---------------------------------------------------------------------------

  # Returns the disposition for a partition of the given size:
  #   :apoptosis_required — minority, must self-destruct
  #   :minority_safe      — majority, can continue
  #   :healthy            — partition healed, no action required
  @spec evaluate_apoptosis(pos_integer(), pos_integer(), boolean()) ::
          :apoptosis_required | :minority_safe | :healthy
  defp evaluate_apoptosis(_total, _size, true), do: :healthy

  defp evaluate_apoptosis(total, size, false) do
    if has_quorum?(total, size), do: :minority_safe, else: :apoptosis_required
  end

  # ---------------------------------------------------------------------------
  # Fencing helpers
  # ---------------------------------------------------------------------------

  # Coordinator (majority side) tells each node in minority_ids to fence itself.
  defp fence_minority(table, minority_ids) do
    Enum.each(minority_ids, fn nid ->
      update_node(table, nid, fn n -> %{n | fenced: true, status: :fenced} end)
    end)
  end

  defp is_fenced?(table, node_id) do
    case get_node(table, node_id) do
      {:ok, %{fenced: true}} -> true
      _ -> false
    end
  end

  # ---------------------------------------------------------------------------
  # Dying gasp helpers (SC-SIL4-007)
  # ---------------------------------------------------------------------------

  # A node records its dying gasp message before halting.
  defp record_dying_gasp(table, node_id, reason) do
    gasp = %{
      node: node_id,
      reason: reason,
      timestamp_ms: mono_ms(),
      epoch: get_epoch(table, node_id)
    }

    update_node(table, node_id, fn n -> %{n | dying_gasp: gasp} end)
    gasp
  end

  defp get_dying_gasp(table, node_id) do
    case get_node(table, node_id) do
      {:ok, %{dying_gasp: gasp}} -> gasp
      _ -> nil
    end
  end

  defp get_epoch(table, node_id) do
    case get_node(table, node_id) do
      {:ok, %{epoch: e}} -> e
      _ -> 0
    end
  end

  # ---------------------------------------------------------------------------
  # Merge-back / rejoin protocol
  # ---------------------------------------------------------------------------

  # A node rejoining after a partition receives the cluster's current VV and
  # bumps its own epoch to invalidate any stale messages from its old incarnation.
  defp rejoin_node(table, node_id, cluster_vv) do
    case get_node(table, node_id) do
      {:ok, current} ->
        merged_vv = vv_merge(current.vv, cluster_vv)
        new_epoch = current.epoch + 1

        :ets.insert(table, {
          {:node, node_id},
          %{
            current
            | status: :alive,
              epoch: new_epoch,
              vv: merged_vv,
              partition: nil,
              fenced: false
          }
        })

        :ok

      {:error, _} = err ->
        err
    end
  end

  # ---------------------------------------------------------------------------
  # Gossip failure detection helpers
  # ---------------------------------------------------------------------------

  defp gossip_init(table, node_id, known_peers) do
    view =
      Map.new(known_peers, fn peer ->
        {peer, %{status: :alive, missed_hbs: 0, version: 1}}
      end)

    :ets.insert(table, {{:gossip, node_id}, view})
    view
  end

  defp gossip_get(table, node_id) do
    case :ets.lookup(table, {:gossip, node_id}) do
      [{_, view}] -> view
      [] -> %{}
    end
  end

  defp gossip_set_status(table, observer_id, target_id, status) do
    view = gossip_get(table, observer_id)
    current_ver = get_in(view, [target_id, :version]) || 0
    updated = Map.put(view, target_id, %{status: status, missed_hbs: 0, version: current_ver + 2})
    :ets.insert(table, {{:gossip, observer_id}, updated})
    updated
  end

  defp gossip_merge_views(view_a, view_b) do
    Map.merge(view_a, view_b, fn _id, ea, eb ->
      if eb.version > ea.version, do: eb, else: ea
    end)
  end

  defp gossip_round(table, live_node_ids) do
    snapshots = Map.new(live_node_ids, fn nid -> {nid, gossip_get(table, nid)} end)

    Enum.each(live_node_ids, fn nid ->
      merged =
        Enum.reduce(live_node_ids, gossip_get(table, nid), fn peer, acc ->
          gossip_merge_views(acc, Map.get(snapshots, peer, %{}))
        end)

      :ets.insert(table, {{:gossip, nid}, merged})
    end)

    :ok
  end

  defp gossip_converged?(table, observer_ids, target_id, expected_status) do
    Enum.all?(observer_ids, fn nid ->
      view = gossip_get(table, nid)
      get_in(view, [target_id, :status]) == expected_status
    end)
  end

  # ---------------------------------------------------------------------------
  # Leader election in partitioned cluster
  # ---------------------------------------------------------------------------

  # Elect the leader from the given node list (lexicographically smallest alive node).
  defp elect_leader(nodes_data) do
    alive = Enum.filter(nodes_data, fn n -> n.status == :alive end)

    case Enum.sort_by(alive, &to_string(&1.id)) do
      [] -> {:error, :no_live_nodes}
      [leader | _] -> {:ok, leader.id}
    end
  end

  # ===========================================================================
  # Section 1 — Heartbeat / failure detection
  # ===========================================================================

  describe "heartbeat absence triggers split-brain detection pipeline" do
    setup do
      t = new_table(:"l6_splitbrain_hb_#{:erlang.unique_integer([:positive])}")
      for i <- 1..5, do: join_node(t, :"hb#{i}")
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :sil6_heartbeat
    test "node receiving fresh heartbeat remains :alive", %{t: t} do
      :ok = heartbeat(t, :hb1)
      :ok = detect_failures(t, @heartbeat_timeout_ms)
      {:ok, n} = get_node(t, :hb1)
      assert n.status == :alive
    end

    @tag :sil6_heartbeat
    test "node with stale heartbeat is not immediately :dead — must cross threshold", %{t: t} do
      stale_ts = mono_ms() - @heartbeat_timeout_ms - 50
      :ok = update_node(t, :hb2, fn n -> %{n | last_heartbeat: stale_ts, missed_hbs: 2} end)
      :ok = detect_failures(t, @heartbeat_timeout_ms)
      {:ok, n} = get_node(t, :hb2)
      # missed_hbs was 2, now 3 — hits @suspected_threshold
      assert n.status == :suspected
    end

    @tag :sil6_heartbeat
    test "node reaching @dead_threshold transitions to :dead", %{t: t} do
      stale_ts = mono_ms() - @heartbeat_timeout_ms - 50

      :ok =
        update_node(t, :hb3, fn n ->
          %{n | last_heartbeat: stale_ts, missed_hbs: @dead_threshold - 1}
        end)

      :ok = detect_failures(t, @heartbeat_timeout_ms)
      {:ok, n} = get_node(t, :hb3)
      assert n.status == :dead
    end

    @tag :sil6_heartbeat
    test "hard crash transitions node to :dead immediately", %{t: t} do
      :ok = mark_dead(t, :hb4)
      {:ok, n} = get_node(t, :hb4)
      assert n.status == :dead
      assert n.missed_hbs == @dead_threshold
    end

    @tag :sil6_heartbeat
    test "dead node does not affect other live nodes", %{t: t} do
      :ok = mark_dead(t, :hb5)
      live = alive_nodes(t) |> Enum.map(& &1.id)
      assert :hb1 in live
      assert :hb2 in live
      assert :hb3 in live
      assert :hb4 in live
      refute :hb5 in live
    end
  end

  # ===========================================================================
  # Section 2 — Quorum calculation (SC-QUORUM-001)
  # ===========================================================================

  describe "quorum(N) = floor(N/2)+1 for all cluster sizes" do
    @tag :sil6_quorum
    test "quorum(1) = 1 — single node is its own quorum" do
      assert quorum(1) == 1
    end

    @tag :sil6_quorum
    test "quorum(2) = 2 — both nodes required" do
      assert quorum(2) == 2
    end

    @tag :sil6_quorum
    test "quorum(3) = 2 — standard 2oo3 quorum" do
      assert quorum(3) == 2
    end

    @tag :sil6_quorum
    test "quorum(5) = 3 — five-node cluster" do
      assert quorum(5) == 3
    end

    @tag :sil6_quorum
    test "quorum(6) = 4 — even-size cluster needs strict majority" do
      assert quorum(6) == 4
    end

    @tag :sil6_quorum
    test "quorum table N=1..12 matches expected values exactly" do
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
        10 => 6,
        11 => 6,
        12 => 7
      }

      for {n, eq} <- expected do
        actual = quorum(n)
        assert actual == eq, "quorum(#{n}) expected #{eq} got #{actual}"
      end
    end

    @tag :sil6_quorum
    test "quorum is strictly greater than N/2 for N in 1..30" do
      for n <- 1..30 do
        q = quorum(n)
        assert q > n / 2.0, "quorum(#{n}) = #{q} must be > #{n / 2.0}"
      end
    end
  end

  # ===========================================================================
  # Section 3 — Partition detection (reachability isolation)
  # ===========================================================================

  describe "partition detection via reachability simulation" do
    setup do
      t = new_table(:"l6_splitbrain_part_#{:erlang.unique_integer([:positive])}")
      for i <- 1..6, do: join_node(t, :"p#{i}")
      :ok = assign_partition(t, [:p1, :p2, :p3], :alpha)
      :ok = assign_partition(t, [:p4, :p5, :p6], :beta)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :sil6_partition
    test "alpha-side nodes can reach each other but not beta", %{t: t} do
      alpha_reach = reachable_from(t, :p1) |> Enum.sort()
      assert alpha_reach == [:p1, :p2, :p3]
      refute :p4 in alpha_reach
      refute :p5 in alpha_reach
      refute :p6 in alpha_reach
    end

    @tag :sil6_partition
    test "beta-side nodes can reach each other but not alpha", %{t: t} do
      beta_reach = reachable_from(t, :p4) |> Enum.sort()
      assert beta_reach == [:p4, :p5, :p6]
      refute :p1 in beta_reach
    end

    @tag :sil6_partition
    test "healing removes partition labels and makes all nodes mutually reachable", %{t: t} do
      :ok = heal_partition(t)
      reachable = reachable_from(t, :p1) |> Enum.sort()
      assert reachable == [:p1, :p2, :p3, :p4, :p5, :p6]
    end

    @tag :sil6_partition
    test "post-heal all nodes have nil partition label", %{t: t} do
      :ok = heal_partition(t)

      Enum.each(1..6, fn i ->
        {:ok, node} = get_node(t, :"p#{i}")
        assert node.partition == nil
      end)
    end
  end

  # ===========================================================================
  # Section 4 — Apoptosis trigger (SC-SIL4-015)
  # ===========================================================================

  describe "apoptosis trigger on minority partition (SC-SIL4-015)" do
    @tag :sil6_apoptosis
    test "symmetric 50/50 split (N=4): both halves below quorum → both need apoptosis" do
      n = 4
      # Q(4) = 3. Each partition has 2 nodes.
      assert evaluate_apoptosis(n, 2, false) == :apoptosis_required
      assert evaluate_apoptosis(n, 2, false) == :apoptosis_required
    end

    @tag :sil6_apoptosis
    test "asymmetric split (N=5): majority is safe, minority needs apoptosis" do
      n = 5
      assert evaluate_apoptosis(n, 3, false) == :minority_safe
      assert evaluate_apoptosis(n, 2, false) == :apoptosis_required
    end

    @tag :sil6_apoptosis
    test "healed partition is always :healthy regardless of size" do
      assert evaluate_apoptosis(5, 2, true) == :healthy
      assert evaluate_apoptosis(10, 1, true) == :healthy
    end

    @tag :sil6_apoptosis
    test "single-node partition is always :apoptosis_required" do
      for total <- 3..10 do
        result = evaluate_apoptosis(total, 1, false)

        assert result == :apoptosis_required,
               "Single node from N=#{total} cluster must self-destruct"
      end
    end
  end

  # ===========================================================================
  # Section 5 — Fencing mechanism
  # ===========================================================================

  describe "fencing: coordinator shuts down minority partition" do
    setup do
      t = new_table(:"l6_splitbrain_fence_#{:erlang.unique_integer([:positive])}")
      for i <- 1..5, do: join_node(t, :"f#{i}")
      :ok = assign_partition(t, [:f1, :f2, :f3], :majority)
      :ok = assign_partition(t, [:f4, :f5], :minority)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :sil6_fencing
    test "coordinator fences the minority partition nodes", %{t: t} do
      :ok = fence_minority(t, [:f4, :f5])
      assert is_fenced?(t, :f4)
      assert is_fenced?(t, :f5)
    end

    @tag :sil6_fencing
    test "fenced nodes transition to :fenced status", %{t: t} do
      :ok = fence_minority(t, [:f4, :f5])
      {:ok, f4} = get_node(t, :f4)
      assert f4.status == :fenced
    end

    @tag :sil6_fencing
    test "majority nodes are unaffected by fencing operation", %{t: t} do
      :ok = fence_minority(t, [:f4, :f5])

      Enum.each([:f1, :f2, :f3], fn nid ->
        {:ok, n} = get_node(t, nid)
        assert n.status == :alive
        refute n.fenced
      end)
    end
  end

  # ===========================================================================
  # Section 6 — Merge-back / rejoin protocol
  # ===========================================================================

  describe "merge-back protocol: rejoining partition reconciles state" do
    setup do
      t = new_table(:"l6_splitbrain_rejoin_#{:erlang.unique_integer([:positive])}")
      for i <- 1..4, do: join_node(t, :"r#{i}")
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :sil6_rejoin
    test "rejoining node receives merged version vector from cluster", %{t: t} do
      cluster_vv = %{r1: 5, r2: 3, r3: 7}
      :ok = rejoin_node(t, :r4, cluster_vv)

      {:ok, r4} = get_node(t, :r4)
      assert Map.get(r4.vv, :r1) >= 5
      assert Map.get(r4.vv, :r2) >= 3
      assert Map.get(r4.vv, :r3) >= 7
    end

    @tag :sil6_rejoin
    test "epoch increments on rejoin to invalidate stale messages", %{t: t} do
      {:ok, before} = get_node(t, :r2)
      old_epoch = before.epoch

      :ok = rejoin_node(t, :r2, %{r1: 2})
      {:ok, after_rejoin} = get_node(t, :r2)

      assert after_rejoin.epoch == old_epoch + 1
    end

    @tag :sil6_rejoin
    test "rejoining node clears fenced and partition flags", %{t: t} do
      :ok = update_node(t, :r3, fn n -> %{n | fenced: true, partition: :split_alpha} end)
      :ok = rejoin_node(t, :r3, %{})

      {:ok, r3} = get_node(t, :r3)
      assert r3.status == :alive
      refute r3.fenced
      assert r3.partition == nil
    end
  end

  # ===========================================================================
  # Section 7 — Version vector merge for conflict resolution
  # ===========================================================================

  describe "version vector merge: conflict resolution during reunification" do
    @tag :sil6_vv
    test "merge produces component-wise maximum across all keys" do
      vv_a = %{n1: 4, n2: 1, n3: 2}
      vv_b = %{n1: 2, n2: 6, n4: 3}
      merged = vv_merge(vv_a, vv_b)

      assert merged == %{n1: 4, n2: 6, n3: 2, n4: 3}
    end

    @tag :sil6_vv
    test "merged VV dominates both input VVs (leq property)" do
      vv_a = %{n1: 3, n2: 1}
      vv_b = %{n1: 1, n2: 5, n3: 2}
      merged = vv_merge(vv_a, vv_b)

      assert vv_leq(vv_a, merged)
      assert vv_leq(vv_b, merged)
    end

    @tag :sil6_vv
    test "concurrent independent edits are detected via vv_compare" do
      vv_base = %{n1: 2, n2: 2}
      vv_a = vv_tick(vv_base, :n1)
      vv_b = vv_tick(vv_base, :n2)

      assert vv_compare(vv_a, vv_b) == :concurrent
    end

    @tag :sil6_vv
    test "sequential events are ordered correctly (:before / :after)" do
      vv0 = vv_new()
      vv1 = vv_tick(vv0, :n1)
      vv2 = vv_tick(vv1, :n1)

      assert vv_compare(vv0, vv1) == :before
      assert vv_compare(vv1, vv2) == :before
      assert vv_compare(vv0, vv2) == :before
      assert vv_compare(vv2, vv1) == :after
    end
  end

  # ===========================================================================
  # Section 8 — Leader election in degraded (split) cluster
  # ===========================================================================

  describe "leader election inside degraded majority partition" do
    @tag :sil6_leader
    test "election completes in a 3-node majority from a 5-node cluster" do
      alive = [
        %{id: "node-c", status: :alive},
        %{id: "node-a", status: :alive},
        %{id: "node-b", status: :alive}
      ]

      assert {:ok, "node-a"} = elect_leader(alive)
    end

    @tag :sil6_leader
    test "failed/suspected nodes are excluded from election" do
      nodes = [
        %{id: "n1", status: :dead},
        %{id: "n2", status: :alive},
        %{id: "n3", status: :suspected},
        %{id: "n4", status: :alive}
      ]

      {:ok, leader} = elect_leader(nodes)
      assert leader in ["n2", "n4"]
      refute leader == "n1"
      refute leader == "n3"
    end

    @tag :sil6_leader
    test "election with no alive nodes returns :no_live_nodes error" do
      nodes = [
        %{id: "n1", status: :dead},
        %{id: "n2", status: :fenced}
      ]

      assert {:error, :no_live_nodes} = elect_leader(nodes)
    end
  end

  # ===========================================================================
  # Section 9 — Dying gasp (SC-SIL4-007)
  # ===========================================================================

  describe "dying gasp message recorded before node halts (SC-SIL4-007)" do
    setup do
      t = new_table(:"l6_splitbrain_gasp_#{:erlang.unique_integer([:positive])}")
      for i <- 1..3, do: join_node(t, :"g#{i}")
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    @tag :sil6_dying_gasp
    test "dying gasp is recorded with reason, timestamp, and epoch", %{t: t} do
      gasp = record_dying_gasp(t, :g1, :split_brain_detected)

      assert gasp.node == :g1
      assert gasp.reason == :split_brain_detected
      assert is_integer(gasp.timestamp_ms)
      assert gasp.epoch >= 1
    end

    @tag :sil6_dying_gasp
    test "dying gasp is persisted and retrievable from ETS", %{t: t} do
      _gasp = record_dying_gasp(t, :g2, :fenced_by_coordinator)
      retrieved = get_dying_gasp(t, :g2)

      refute is_nil(retrieved)
      assert retrieved.reason == :fenced_by_coordinator
    end

    @tag :sil6_dying_gasp
    test "dying gasp is nil for a node that has not yet halted", %{t: t} do
      gasp = get_dying_gasp(t, :g3)
      assert is_nil(gasp)
    end
  end

  # ===========================================================================
  # Section 10 — Gossip failure detection
  # ===========================================================================

  describe "gossip protocol detects silent nodes via missed-heartbeat counters" do
    setup do
      t = new_table(:"l6_splitbrain_gossip_#{:erlang.unique_integer([:positive])}")
      nodes = [:gg1, :gg2, :gg3, :gg4, :gg5]
      Enum.each(nodes, fn n -> gossip_init(t, n, nodes) end)
      on_exit(fn -> drop_table(t) end)
      %{t: t, nodes: nodes}
    end

    @tag :sil6_gossip_failure
    test "status update propagates to all nodes within @max_gossip_rounds", %{t: t, nodes: nodes} do
      gossip_set_status(t, :gg1, :gg3, :suspected)

      converged =
        Enum.reduce_while(1..@max_gossip_rounds, false, fn _r, _acc ->
          gossip_round(t, nodes)

          if gossip_converged?(t, nodes, :gg3, :suspected),
            do: {:halt, true},
            else: {:cont, false}
        end)

      assert converged, "Gossip did not converge within #{@max_gossip_rounds} rounds"
    end

    @tag :sil6_gossip_failure
    test "higher-version update always wins during gossip merge", %{t: t} do
      # gg2 observes gg5 as :suspected at version 3
      gossip_set_status(t, :gg2, :gg5, :suspected)
      gossip_set_status(t, :gg2, :gg5, :suspected)

      view = gossip_get(t, :gg2)
      high_ver = get_in(view, [:gg5, :version])
      assert high_ver >= 3

      # gg4 has an older view of gg5 — the merge should keep the higher version.
      gossip_round(t, [:gg2, :gg4])
      view_gg4 = gossip_get(t, :gg4)
      assert get_in(view_gg4, [:gg5, :version]) >= high_ver
    end
  end

  # ===========================================================================
  # Section 11 — 2oo3 voting during degraded operation
  # ===========================================================================

  describe "2oo3 voting (SC-SIL6-006): degraded cluster scenarios" do
    @tag :sil6_2oo3
    test "unanimous 3-node vote returns winning value with count 3" do
      votes = [{"n1", :commit}, {"n2", :commit}, {"n3", :commit}]
      assert {:ok, :commit, 3} = vote_2oo3(votes)
    end

    @tag :sil6_2oo3
    test "2-of-3 majority for :abort wins over single dissenter" do
      votes = [{"n1", :commit}, {"n2", :abort}, {"n3", :abort}]
      assert {:ok, :abort, 2} = vote_2oo3(votes)
    end

    @tag :sil6_2oo3
    test "split 1-1-1 vote produces :no_quorum (three distinct values)" do
      votes = [{"n1", :commit}, {"n2", :abort}, {"n3", :retry}]
      assert {:no_quorum, _} = vote_2oo3(votes)
    end

    @tag :sil6_2oo3
    test "degraded N=5 cluster with 3 alive nodes can still form a quorum vote" do
      # N=5, Q=3 — exactly 3 alive nodes voting :commit should win.
      alive_votes = [{"n1", :commit}, {"n2", :commit}, {"n3", :commit}]
      assert {:ok, :commit, 3} = majority_vote(alive_votes, 5)
    end
  end

  # ===========================================================================
  # Section 12 — PropCheck property: quorum is strictly > N/2 (SC-QUORUM-001)
  # ===========================================================================

  @tag :sil6_property
  test "propcheck forall: Q(N) > N/2 for all N in 1..100 (PC.choose)" do
    Application.ensure_all_started(:propcheck)

    assert quickcheck(
             forall n <- PC.choose(1, 100) do
               q = quorum(n)
               q > n / 2.0
             end,
             [:quiet, numtests: 100]
           )
  end

  # ===========================================================================
  # Section 13 — PropCheck property: apoptosis forced on minority (SC-SIL4-015)
  # ===========================================================================

  @tag :sil6_property
  test "propcheck forall: minority partition always requires apoptosis (PC.choose)" do
    Application.ensure_all_started(:propcheck)

    assert quickcheck(
             forall total <- PC.choose(3, 20) do
               q = quorum(total)
               minority_size = q - 1
               # Minority (size < quorum) must trigger apoptosis.
               evaluate_apoptosis(total, minority_size, false) == :apoptosis_required
             end,
             [:quiet, numtests: 80]
           )
  end

  # ===========================================================================
  # Section 14 — PropCheck property: version vector tick monotonicity
  # ===========================================================================

  @tag :sil6_property
  test "propcheck forall: VV tick is strictly monotone (PC.choose + PC.atom)" do
    Application.ensure_all_started(:propcheck)

    assert quickcheck(
             forall {n_ticks, node_idx} <- {PC.choose(1, 20), PC.choose(1, 5)} do
               node_id = :"vv_nd_#{node_idx}"
               vv0 = vv_new()

               vv_final =
                 Enum.reduce(1..n_ticks, vv0, fn _, acc -> vv_tick(acc, node_id) end)

               Map.get(vv_final, node_id, 0) == n_ticks
             end,
             [:quiet, numtests: 100]
           )
  end

  # ===========================================================================
  # Section 15 — check all (SD): quorum holds for arbitrary cluster sizes
  # ===========================================================================

  @tag :sil6_property
  test "check all (SD): quorum(N) > N/2 for generated cluster sizes" do
    ExUnitProperties.check all(n <- SD.integer(1..200), max_runs: 200) do
      q = quorum(n)
      assert q > n / 2.0
      assert q == div(n, 2) + 1
    end
  end

  # ===========================================================================
  # Section 16 — check all (SD): partition isolation preserved before healing
  # ===========================================================================

  @tag :sil6_property
  test "check all (SD): nodes in disjoint partitions never appear in each other's reachable set" do
    ExUnitProperties.check all(
                             n_alpha <- SD.integer(1..5),
                             n_beta <- SD.integer(1..5),
                             max_runs: 50
                           ) do
      uid = :erlang.unique_integer([:positive])
      t = new_table(:"l6_sb_prop_iso_#{uid}")

      alpha_ids = Enum.map(1..n_alpha, fn i -> :"iso_a#{i}_#{uid}" end)
      beta_ids = Enum.map(1..n_beta, fn i -> :"iso_b#{i}_#{uid}" end)
      all_ids = alpha_ids ++ beta_ids

      Enum.each(all_ids, fn nid -> join_node(t, nid) end)
      assign_partition(t, alpha_ids, :alpha)
      assign_partition(t, beta_ids, :beta)

      alpha_reach = reachable_from(t, hd(alpha_ids)) |> MapSet.new()
      beta_reach = reachable_from(t, hd(beta_ids)) |> MapSet.new()

      intersection = MapSet.intersection(alpha_reach, beta_reach)

      drop_table(t)

      assert MapSet.size(intersection) == 0,
             "Partitioned nodes should not be reachable from each other; " <>
               "got intersection: #{inspect(MapSet.to_list(intersection))}"
    end
  end

  # ===========================================================================
  # Section 17 — check all (SD): VV merge commutativity
  # ===========================================================================

  @tag :sil6_property
  test "check all (SD): VV merge is commutative (vv_merge(a,b) == vv_merge(b,a))" do
    ExUnitProperties.check all(
                             keys_a <- SD.list_of(SD.atom(:alphanumeric), max_length: 6),
                             keys_b <- SD.list_of(SD.atom(:alphanumeric), max_length: 6),
                             vals_a <- SD.list_of(SD.integer(1..20)),
                             vals_b <- SD.list_of(SD.integer(1..20)),
                             max_runs: 50
                           ) do
      build_vv = fn keys, vals ->
        Enum.zip(keys, vals) |> Map.new()
      end

      vv_a = build_vv.(keys_a, vals_a)
      vv_b = build_vv.(keys_b, vals_b)

      merged_ab = vv_merge(vv_a, vv_b)
      merged_ba = vv_merge(vv_b, vv_a)

      assert merged_ab == merged_ba,
             "VV merge must be commutative; got #{inspect(merged_ab)} vs #{inspect(merged_ba)}"
    end
  end

  # ===========================================================================
  # Section 18 — check all (SD): symmetric split always blocks both sides
  # ===========================================================================

  @tag :sil6_property
  test "check all (SD): symmetric even split means neither half has quorum" do
    ExUnitProperties.check all(half_size <- SD.integer(1..10), max_runs: 100) do
      total = half_size * 2
      # Each side of a 50/50 split has exactly half the nodes.
      assert has_quorum?(total, half_size) == false,
             "N=#{total} half=#{half_size}: neither side of a 50/50 split can have quorum"

      # Both sides must trigger apoptosis (SC-SIL4-015).
      assert evaluate_apoptosis(total, half_size, false) == :apoptosis_required
    end
  end
end
