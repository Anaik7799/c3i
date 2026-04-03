defmodule Indrajaal.Morphogenic.L6ClusterPartitionHealingTest do
  @moduledoc """
  WHAT: Self-contained L6 (Cluster-level) test suite for network partition
        detection, split-brain resolution, and partition healing in the
        Indrajaal SIL-6 Biomorphic Mesh.

  WHY: Validates that the cluster correctly detects partitions via heartbeat
       timeouts, resolves split-brain scenarios, heals partitions with proper
       state reconciliation, and triggers apoptosis on irrecoverable splits.

  ## STAMP Compliance
  - SC-XHOLON-007: Monotonically increasing version vectors
  - SC-SIL4-015: Split-brain detection triggers apoptosis
  - SC-SIL6-006: 2oo3 voting mandatory for safety-critical decisions
  - SC-SIL6-011: Quorum = floor(N/2) + 1

  ## Constitutional Alignment
  - Ψ₀ Existence: Cluster heals to functional state
  - Ψ₃ Verification: Hash-chain integrity after merge
  """

  use ExUnit.Case, async: true
  use PropCheck
  # EP-GEN-014: Both PropCheck and ExUnitProperties are used.
  # ExUnitProperties is imported excluding conflicting generator names.
  # PropCheck forall uses PC. prefix; ExUnitProperties check all uses ExUnitProperties.check all.
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l6
  @moduletag :partition_healing
  @moduletag timeout: 60_000

  @heartbeat_timeout_ms 300
  @max_gossip_rounds 5

  # ---------------------------------------------------------------------------
  # Quorum mathematics (SC-SIL6-011)
  # ---------------------------------------------------------------------------

  defp quorum(n) when is_integer(n) and n >= 1, do: div(n, 2) + 1

  # ---------------------------------------------------------------------------
  # ETS cluster table helpers
  # ---------------------------------------------------------------------------

  defp new_table(name) do
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp drop_table(t) do
    if :ets.info(t) != :undefined, do: :ets.delete(t)
  end

  defp join_node(table, node_id, epoch \\ 1) do
    ts = System.monotonic_time(:millisecond)

    :ets.insert(table, {
      {:member, node_id},
      %{
        id: node_id,
        status: :alive,
        epoch: epoch,
        last_heartbeat: ts,
        partition: nil,
        vv: %{node_id => 1}
      }
    })

    :ok
  end

  defp all_members(table) do
    :ets.tab2list(table)
    |> Enum.filter(fn {{kind, _}, _} -> kind == :member end)
    |> Enum.map(fn {_, data} -> data end)
  end

  defp alive_members(table) do
    all_members(table)
    |> Enum.filter(fn m -> m.status == :alive end)
  end

  defp get_member(table, node_id) do
    case :ets.lookup(table, {:member, node_id}) do
      [{_, data}] -> {:ok, data}
      [] -> {:error, :not_found}
    end
  end

  defp update_member(table, node_id, fun) do
    case get_member(table, node_id) do
      {:ok, data} ->
        :ets.insert(table, {{:member, node_id}, fun.(data)})
        :ok

      {:error, _} = err ->
        err
    end
  end

  defp heartbeat(table, node_id) do
    ts = System.monotonic_time(:millisecond)
    update_member(table, node_id, fn m -> %{m | last_heartbeat: ts} end)
  end

  defp detect_failures(table, timeout_ms) do
    now = System.monotonic_time(:millisecond)

    all_members(table)
    |> Enum.filter(fn m ->
      m.status == :alive and now - m.last_heartbeat > timeout_ms
    end)
    |> Enum.each(fn m ->
      update_member(table, m.id, fn data -> %{data | status: :suspected} end)
    end)

    :ok
  end

  defp assign_partition(table, node_ids, label) do
    Enum.each(node_ids, fn nid ->
      update_member(table, nid, fn m -> %{m | partition: label} end)
    end)
  end

  defp heal_partition(table) do
    all_members(table)
    |> Enum.each(fn m ->
      update_member(table, m.id, fn data -> %{data | partition: nil} end)
    end)
  end

  defp reachable_from(table, node_id) do
    case get_member(table, node_id) do
      {:ok, %{partition: p}} ->
        all_members(table)
        |> Enum.filter(fn m -> m.partition == p end)
        |> Enum.map(fn m -> m.id end)

      {:error, _} ->
        []
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

  defp vv_store_init(table, node_id) do
    :ets.insert(table, {{:vv, node_id}, vv_new()})
  end

  defp vv_store_merge(table, node_id, remote_vv) do
    case :ets.lookup(table, {:vv, node_id}) do
      [{_, local_vv}] ->
        merged = vv_merge(local_vv, remote_vv)
        :ets.insert(table, {{:vv, node_id}, merged})
        merged

      [] ->
        :ets.insert(table, {{:vv, node_id}, remote_vv})
        remote_vv
    end
  end

  defp vv_store_get(table, node_id) do
    case :ets.lookup(table, {:vv, node_id}) do
      [{_, vv}] -> vv
      [] -> vv_new()
    end
  end

  # ---------------------------------------------------------------------------
  # LWW and CRDT data reconciliation helpers
  # ---------------------------------------------------------------------------

  # LWW entry: {value, version, timestamp_ms}
  defp lww_merge({_val_a, ver_a, ts_a} = a, {_val_b, ver_b, ts_b} = b) do
    cond do
      ver_a > ver_b -> a
      ver_b > ver_a -> b
      ts_a >= ts_b -> a
      true -> b
    end
  end

  # G-Counter CRDT: map of node_id -> count
  defp gcounter_new, do: %{}

  defp gcounter_increment(counter, node_id) do
    Map.update(counter, node_id, 1, &(&1 + 1))
  end

  defp gcounter_merge(c1, c2) do
    Map.merge(c1, c2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  defp gcounter_value(counter) do
    counter |> Map.values() |> Enum.sum()
  end

  # ---------------------------------------------------------------------------
  # Gossip simulation helpers
  # ---------------------------------------------------------------------------

  defp gossip_init(table, node_id, initial_status) do
    :ets.insert(table, {
      {:gossip, node_id},
      %{node_id => %{status: initial_status, version: 1}}
    })
  end

  defp gossip_get(table, node_id) do
    case :ets.lookup(table, {:gossip, node_id}) do
      [{_, view}] -> view
      [] -> %{}
    end
  end

  defp gossip_set_status(table, node_id, target_id, status) do
    view = gossip_get(table, node_id)
    # Use max known version + 2 to ensure this update dominates any existing entry
    # including the target's own self-reported version (which starts at 1)
    current_ver = get_in(view, [target_id, :version]) || 0
    new_ver = max(current_ver, 1) + 1
    updated = Map.put(view, target_id, %{status: status, version: new_ver})
    :ets.insert(table, {{:gossip, node_id}, updated})
  end

  defp gossip_merge_views(view_a, view_b) do
    Map.merge(view_a, view_b, fn _id, entry_a, entry_b ->
      if entry_b.version > entry_a.version, do: entry_b, else: entry_a
    end)
  end

  defp gossip_round(table, live_node_ids) do
    views =
      Enum.map(live_node_ids, fn nid -> {nid, gossip_get(table, nid)} end)
      |> Map.new()

    Enum.each(live_node_ids, fn nid ->
      merged =
        Enum.reduce(live_node_ids, gossip_get(table, nid), fn peer, acc ->
          peer_view = Map.get(views, peer, %{})
          gossip_merge_views(acc, peer_view)
        end)

      :ets.insert(table, {{:gossip, nid}, merged})
    end)

    :ok
  end

  defp gossip_converged?(table, node_ids, target_id, expected_status) do
    Enum.all?(node_ids, fn nid ->
      view = gossip_get(table, nid)
      get_in(view, [target_id, :status]) == expected_status
    end)
  end

  # ---------------------------------------------------------------------------
  # Apoptosis evaluation (SC-SIL4-015)
  # ---------------------------------------------------------------------------

  defp evaluate_apoptosis(total_nodes, partition_size, healed) do
    q = quorum(total_nodes)

    cond do
      healed -> :healthy
      partition_size >= q -> :minority_safe
      true -> :apoptosis_required
    end
  end

  # ---------------------------------------------------------------------------
  # Node rejoin protocol
  # ---------------------------------------------------------------------------

  defp rejoin_node(table, node_id, current_epoch, healing_vv) do
    new_epoch = current_epoch + 1
    ts = System.monotonic_time(:millisecond)

    merged_vv = vv_merge(vv_store_get(table, node_id), healing_vv)

    :ets.insert(table, {
      {:member, node_id},
      %{
        id: node_id,
        status: :alive,
        epoch: new_epoch,
        last_heartbeat: ts,
        partition: nil,
        vv: merged_vv
      }
    })

    vv_store_merge(table, node_id, healing_vv)
    :ok
  end

  defp mono_ms, do: System.monotonic_time(:millisecond)

  # ===========================================================================
  # Test Suite
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Section 1: Network partition detection via heartbeat timeout
  # ---------------------------------------------------------------------------

  describe "partition detection via heartbeat timeout" do
    setup do
      t = new_table(:"part_detect_#{:erlang.unique_integer([:positive])}")
      :ok = join_node(t, :n1)
      :ok = join_node(t, :n2)
      :ok = join_node(t, :n3)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    test "nodes with fresh heartbeats are not suspected", %{t: t} do
      :ok = heartbeat(t, :n1)
      :ok = heartbeat(t, :n2)
      :ok = heartbeat(t, :n3)
      :ok = detect_failures(t, @heartbeat_timeout_ms)

      alive = alive_members(t) |> Enum.map(& &1.id) |> Enum.sort()
      assert alive == [:n1, :n2, :n3]
    end

    test "node with stale heartbeat is suspected after timeout", %{t: t} do
      stale_ts = mono_ms() - @heartbeat_timeout_ms - 100
      :ok = update_member(t, :n2, fn m -> %{m | last_heartbeat: stale_ts} end)
      :ok = detect_failures(t, @heartbeat_timeout_ms)

      {:ok, n2} = get_member(t, :n2)
      assert n2.status == :suspected

      {:ok, n1} = get_member(t, :n1)
      assert n1.status == :alive
    end

    test "multiple stale nodes can be suspected simultaneously", %{t: t} do
      stale_ts = mono_ms() - @heartbeat_timeout_ms - 100
      :ok = update_member(t, :n2, fn m -> %{m | last_heartbeat: stale_ts} end)
      :ok = update_member(t, :n3, fn m -> %{m | last_heartbeat: stale_ts} end)
      :ok = detect_failures(t, @heartbeat_timeout_ms)

      {:ok, n2} = get_member(t, :n2)
      {:ok, n3} = get_member(t, :n3)
      assert n2.status == :suspected
      assert n3.status == :suspected

      {:ok, n1} = get_member(t, :n1)
      assert n1.status == :alive
    end
  end

  # ---------------------------------------------------------------------------
  # Section 2: Split-brain resolution strategy
  # ---------------------------------------------------------------------------

  describe "split-brain resolution via quorum" do
    setup do
      t = new_table(:"split_brain_#{:erlang.unique_integer([:positive])}")
      for i <- 1..5, do: join_node(t, :"sb#{i}")
      on_exit(fn -> drop_table(t) end)
      %{t: t, total: 5}
    end

    test "majority partition retains authority", %{t: t, total: total} do
      :ok = assign_partition(t, [:sb1, :sb2, :sb3], :alpha)
      :ok = assign_partition(t, [:sb4, :sb5], :beta)

      majority_size = 3
      minority_size = 2
      q = quorum(total)

      assert majority_size >= q
      assert minority_size < q
      assert evaluate_apoptosis(total, minority_size, false) == :apoptosis_required
      assert evaluate_apoptosis(total, majority_size, false) == :minority_safe
    end

    test "even split triggers apoptosis in both partitions (SC-SIL4-015)", %{t: _t} do
      t4 = new_table(:"even_split_#{:erlang.unique_integer([:positive])}")
      on_exit(fn -> drop_table(t4) end)

      for i <- 1..4, do: join_node(t4, :"es#{i}")

      :ok = assign_partition(t4, [:es1, :es2], :alpha)
      :ok = assign_partition(t4, [:es3, :es4], :beta)

      q = quorum(4)
      assert q == 3
      assert evaluate_apoptosis(4, 2, false) == :apoptosis_required
    end
  end

  # ---------------------------------------------------------------------------
  # Section 3: Partition healing sequence
  # ---------------------------------------------------------------------------

  describe "partition healing sequence" do
    setup do
      t = new_table(:"healing_seq_#{:erlang.unique_integer([:positive])}")
      for i <- 1..4, do: join_node(t, :"hs#{i}")
      :ok = assign_partition(t, [:hs1, :hs2], :alpha)
      :ok = assign_partition(t, [:hs3, :hs4], :beta)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    test "nodes in different partitions cannot reach each other before healing", %{t: t} do
      alpha_reachable = reachable_from(t, :hs1) |> Enum.sort()
      beta_reachable = reachable_from(t, :hs3) |> Enum.sort()

      assert alpha_reachable == [:hs1, :hs2]
      assert beta_reachable == [:hs3, :hs4]
      refute :hs3 in alpha_reachable
      refute :hs1 in beta_reachable
    end

    test "healing removes partition labels from all nodes", %{t: t} do
      :ok = heal_partition(t)

      Enum.each(1..4, fn i ->
        {:ok, member} = get_member(t, :"hs#{i}")
        assert member.partition == nil
      end)
    end

    test "full cluster is reachable from any node after healing", %{t: t} do
      :ok = heal_partition(t)

      reachable = reachable_from(t, :hs1) |> Enum.sort()
      assert reachable == [:hs1, :hs2, :hs3, :hs4]
    end
  end

  # ---------------------------------------------------------------------------
  # Section 4: Version vector merge during healing (SC-XHOLON-007)
  # ---------------------------------------------------------------------------

  describe "version vector merge during healing (SC-XHOLON-007)" do
    test "merge produces component-wise maximum" do
      vv_a = %{n1: 3, n2: 1, n3: 2}
      vv_b = %{n1: 2, n2: 4, n4: 1}
      merged = vv_merge(vv_a, vv_b)

      assert merged == %{n1: 3, n2: 4, n3: 2, n4: 1}
    end

    test "merged vv dominates both inputs" do
      vv_a = %{n1: 5, n2: 2}
      vv_b = %{n1: 3, n2: 7, n3: 1}
      merged = vv_merge(vv_a, vv_b)

      assert vv_leq(vv_a, merged)
      assert vv_leq(vv_b, merged)
    end

    test "concurrent edits are detected correctly" do
      vv_base = %{n1: 1, n2: 1}
      vv_a = vv_tick(vv_base, :n1)
      vv_b = vv_tick(vv_base, :n2)

      assert vv_compare(vv_a, vv_b) == :concurrent
      assert vv_compare(vv_base, vv_a) == :before
      assert vv_compare(vv_a, vv_base) == :after
    end
  end

  # ---------------------------------------------------------------------------
  # Section 5: Data reconciliation (LWW vs CRDT merge)
  # ---------------------------------------------------------------------------

  describe "data reconciliation after partition" do
    test "LWW merge selects entry with highest version, breaking ties by timestamp" do
      entry_old = {"data_v1", 1, 1_000}
      entry_new = {"data_v2", 2, 999}
      assert lww_merge(entry_old, entry_new) == entry_new

      entry_a = {"alpha", 3, 2_000}
      entry_b = {"beta", 3, 1_500}
      assert lww_merge(entry_a, entry_b) == entry_a
    end

    test "G-Counter CRDT merge is commutative and idempotent" do
      c1 = gcounter_increment(gcounter_new(), :n1)
      c1 = gcounter_increment(c1, :n1)
      c2 = gcounter_increment(gcounter_new(), :n2)
      c2 = gcounter_increment(c2, :n2)
      c2 = gcounter_increment(c2, :n2)

      merged_ab = gcounter_merge(c1, c2)
      merged_ba = gcounter_merge(c2, c1)

      assert merged_ab == merged_ba
      assert gcounter_merge(merged_ab, merged_ab) == merged_ab
      assert gcounter_value(merged_ab) == 5
      assert Map.get(merged_ab, :n1) == 2
      assert Map.get(merged_ab, :n2) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # Section 6: Node rejoin protocol
  # ---------------------------------------------------------------------------

  describe "node rejoin protocol" do
    setup do
      t = new_table(:"rejoin_#{:erlang.unique_integer([:positive])}")
      :ok = join_node(t, :r1, 1)
      :ok = join_node(t, :r2, 1)
      :ok = join_node(t, :r3, 1)
      vv_store_init(t, :r1)
      vv_store_init(t, :r2)
      vv_store_init(t, :r3)
      on_exit(fn -> drop_table(t) end)
      %{t: t}
    end

    test "rejoining node receives merged version vector from healing cluster", %{t: t} do
      healing_vv = %{r1: 5, r2: 3}
      :ok = rejoin_node(t, :r3, 1, healing_vv)

      {:ok, r3} = get_member(t, :r3)
      assert r3.epoch == 2
      assert r3.status == :alive
      assert r3.partition == nil

      r3_vv = vv_store_get(t, :r3)
      assert Map.get(r3_vv, :r1) >= 5
      assert Map.get(r3_vv, :r2) >= 3
    end

    test "epoch increments on rejoin to invalidate stale messages", %{t: t} do
      {:ok, before} = get_member(t, :r2)
      old_epoch = before.epoch

      healing_vv = %{r1: 2}
      :ok = rejoin_node(t, :r2, old_epoch, healing_vv)

      {:ok, after_rejoin} = get_member(t, :r2)
      assert after_rejoin.epoch == old_epoch + 1
    end
  end

  # ---------------------------------------------------------------------------
  # Section 7: Gossip protocol convergence after partition healing
  # ---------------------------------------------------------------------------

  describe "gossip convergence after partition healing" do
    setup do
      t = new_table(:"gossip_conv_#{:erlang.unique_integer([:positive])}")
      nodes = [:gc1, :gc2, :gc3, :gc4, :gc5]
      Enum.each(nodes, fn n -> gossip_init(t, n, :alive) end)
      on_exit(fn -> drop_table(t) end)
      %{t: t, nodes: nodes}
    end

    test "status change propagates to all nodes within max gossip rounds", %{t: t, nodes: nodes} do
      gossip_set_status(t, :gc1, :gc3, :crashed)

      converged =
        Enum.reduce_while(1..@max_gossip_rounds, false, fn _round, _acc ->
          gossip_round(t, nodes)

          if gossip_converged?(t, nodes, :gc3, :crashed) do
            {:halt, true}
          else
            {:cont, false}
          end
        end)

      assert converged == true,
             "Gossip did not converge within #{@max_gossip_rounds} rounds"
    end

    test "gossip views are eventually consistent across all nodes", %{t: t, nodes: nodes} do
      gossip_set_status(t, :gc2, :gc5, :suspected)
      gossip_set_status(t, :gc4, :gc1, :alive)

      Enum.each(1..@max_gossip_rounds, fn _ -> gossip_round(t, nodes) end)

      gc5_statuses =
        Enum.map(nodes, fn n ->
          view = gossip_get(t, n)
          get_in(view, [:gc5, :status])
        end)
        |> Enum.uniq()

      assert length(gc5_statuses) == 1
    end
  end

  # ---------------------------------------------------------------------------
  # Section 8: Apoptosis trigger on irrecoverable split (SC-SIL4-015)
  # ---------------------------------------------------------------------------

  describe "apoptosis trigger on irrecoverable split (SC-SIL4-015)" do
    test "minority partition below quorum requires apoptosis" do
      total = 7
      assert quorum(total) == 4
      assert evaluate_apoptosis(total, 3, false) == :apoptosis_required
    end

    test "healed partition avoids apoptosis regardless of size" do
      assert evaluate_apoptosis(7, 3, true) == :healthy
      assert evaluate_apoptosis(10, 2, true) == :healthy
    end
  end

  # ---------------------------------------------------------------------------
  # Section 9: Property — version vectors are monotonically increasing
  # ---------------------------------------------------------------------------

  describe "property: version vectors monotonically increasing (SC-XHOLON-007)" do
    test "each tick strictly advances the vector for any node and tick count" do
      Application.ensure_all_started(:propcheck)

      result =
        quickcheck(
          forall {node_str, n_ticks} <- {PC.utf8(), PC.choose(1, 10)} do
            safe_str = if node_str == "", do: "x", else: String.slice(node_str, 0, 10)
            node_atom = String.to_atom("vv_node_#{safe_str}")
            vv0 = vv_new()

            vv_final =
              Enum.reduce(1..n_ticks, vv0, fn _, acc ->
                vv_tick(acc, node_atom)
              end)

            Map.get(vv_final, node_atom, 0) == n_ticks
          end,
          [:quiet, numtests: 50]
        )

      assert result == true
    end
  end

  # ---------------------------------------------------------------------------
  # Section 10: Property — gossip converges within bounded rounds
  # ---------------------------------------------------------------------------

  describe "property: gossip converges in bounded rounds" do
    test "any status update propagates within max_gossip_rounds for small clusters" do
      forall {n_nodes, target_idx, initiator_idx} <-
               {PC.integer(3, 7), PC.integer(0, 6), PC.integer(0, 6)} do
        t = new_table(:"prop_gossip_#{:erlang.unique_integer([:positive])}")

        nodes =
          Enum.map(1..n_nodes, fn i -> :"gp_#{i}_#{:erlang.unique_integer([:positive])}" end)

        Enum.each(nodes, fn n -> gossip_init(t, n, :alive) end)

        initiator = Enum.at(nodes, rem(initiator_idx, length(nodes)))
        target = Enum.at(nodes, rem(target_idx, length(nodes)))

        gossip_set_status(t, initiator, target, :crashed)

        converged =
          Enum.reduce_while(1..@max_gossip_rounds, false, fn _round, _acc ->
            gossip_round(t, nodes)

            if gossip_converged?(t, nodes, target, :crashed) do
              {:halt, true}
            else
              {:cont, false}
            end
          end)

        drop_table(t)
        assert converged == true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 11: Property — node count preserved after healing
  # ---------------------------------------------------------------------------

  describe "property: node count preserved after partition healing" do
    test "total alive nodes after healing equals pre-partition count" do
      forall {n_nodes, split_point} <- {PC.integer(3, 10), PC.integer(1, 2)} do
        t = new_table(:"prop_count_#{:erlang.unique_integer([:positive])}")

        uid = :erlang.unique_integer([:positive])
        nodes = Enum.map(1..n_nodes, fn i -> :"pc_#{i}_#{uid}" end)
        Enum.each(nodes, fn n -> join_node(t, n) end)

        pre_count = length(alive_members(t))

        actual_split = min(split_point, n_nodes - 1)
        {alpha_nodes, beta_nodes} = Enum.split(nodes, actual_split)

        assign_partition(t, alpha_nodes, :alpha)
        assign_partition(t, beta_nodes, :beta)

        heal_partition(t)

        post_count = length(alive_members(t))

        drop_table(t)

        assert post_count == pre_count,
               "Expected #{pre_count} alive nodes after healing, got #{post_count}"
      end
    end
  end
end
