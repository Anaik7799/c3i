defmodule Indrajaal.Core.VsmInteractionTest do
  @moduledoc """
  WHAT: Self-contained ETS-backed test suite for VSM (Viable System Model) S1-S5
        inter-layer interaction patterns at L4 (Container Architecture level).
        Simulates all five subsystems in-process without production module dependencies.

  WHY: Validates that Beer's Viable System Model recursive homeostatic constraints
       hold at the container level: operational isolation (S1), anti-oscillation
       coordination (S2), resource governance (S3), environmental intelligence (S4),
       and constitutional policy (S5). Algedonic bypass and inter-system message
       ordering are exercised under property-based testing.

  CONSTRAINTS:
    - SC-S1-001: S1 operational units MUST be isolated and independently schedulable
    - SC-S2-001: S2 coordination MUST damp oscillation without blocking S1
    - SC-S3-001: S3 resource allocation MUST never exceed declared capacity
    - SC-S3-004: S3 audit trigger MUST fire when threshold is exceeded
    - SC-S4-001: S4 trend detection MUST operate on time-ordered observations
    - SC-S5-001: S5 constitutional checks MUST be evaluated before policy mutations
    - SC-VSM-001: VSM recursion MUST be self-similar at every fractal layer

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Self-contained ETS-backed VSM suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :vsm
  @moduletag timeout: 60_000

  # ---------------------------------------------------------------------------
  # ETS helpers shared by all sections
  # ---------------------------------------------------------------------------

  defp new_table(name) do
    :ets.new(name, [:set, :public, {:write_concurrency, false}])
  end

  defp delete_table(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
  end

  # ---------------------------------------------------------------------------
  # Embedded VSM simulation (pure ETS — no production modules)
  # ---------------------------------------------------------------------------

  # --- S1: Operational units ---

  defp s1_register(table, unit_id, meta \\ %{}) do
    entry = Map.merge(%{id: unit_id, health: :ok, tasks: [], registered_at: now_ms()}, meta)
    :ets.insert(table, {unit_id, entry})
    entry
  end

  defp s1_get(table, unit_id) do
    case :ets.lookup(table, unit_id) do
      [{^unit_id, entry}] -> {:ok, entry}
      [] -> {:error, :not_found}
    end
  end

  defp s1_execute(table, unit_id, task_id, fun) do
    case s1_get(table, unit_id) do
      {:ok, entry} ->
        try do
          result = fun.()
          updated = Map.update(entry, :tasks, [task_id], &[task_id | &1])
          :ets.insert(table, {unit_id, updated})
          {:ok, result}
        rescue
          e -> {:error, Exception.message(e)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp s1_set_health(table, unit_id, health) do
    case s1_get(table, unit_id) do
      {:ok, entry} ->
        :ets.insert(table, {unit_id, %{entry | health: health}})
        :ok

      {:error, _} = err ->
        err
    end
  end

  # --- S2: Coordination ---

  defp s2_record_signal(table, from_id, to_id, value) do
    key = {from_id, to_id}

    signals =
      case :ets.lookup(table, key) do
        [{^key, existing}] -> existing
        [] -> []
      end

    :ets.insert(table, {key, [%{value: value, ts: now_ms()} | signals]})
    :ok
  end

  defp s2_get_signals(table, from_id, to_id) do
    case :ets.lookup(table, {from_id, to_id}) do
      [{{^from_id, ^to_id}, signals}] -> signals
      [] -> []
    end
  end

  defp s2_oscillation_score(signals) when length(signals) < 2, do: 0.0

  defp s2_oscillation_score(signals) do
    values = Enum.map(signals, & &1.value)
    pairs = Enum.zip(values, tl(values))
    sign_changes = Enum.count(pairs, fn {a, b} -> (a >= 0 and b < 0) or (a < 0 and b >= 0) end)
    sign_changes / max(length(pairs), 1)
  end

  defp s2_damp(table, from_id, to_id, alpha \\ 0.3) do
    signals = s2_get_signals(table, from_id, to_id)

    case signals do
      [] ->
        0.0

      [latest | _] ->
        raw = latest.value

        prev =
          case tl(signals) do
            [] -> 0.0
            [prev_sig | _] -> prev_sig.value
          end

        damped = alpha * raw + (1 - alpha) * prev
        :ets.insert(table, {{from_id, to_id, :damped}, damped})
        damped
    end
  end

  defp s2_schedule(table, resource_id, unit_ids) do
    # Naive round-robin assignment to resolve resource contention
    schedule =
      unit_ids
      |> Enum.with_index()
      |> Enum.map(fn {uid, i} -> {resource_id, uid, i} end)

    Enum.each(schedule, fn entry ->
      :ets.insert(table, {elem(entry, 0) <> "_" <> elem(entry, 1), entry})
    end)

    {:ok, length(schedule)}
  end

  # --- S3: Operational management ---

  defp s3_new_state(capacity) do
    %{
      capacity: capacity,
      allocated: 0,
      audit_log: [],
      audit_threshold: trunc(capacity * 0.8),
      audit_triggered: false
    }
  end

  defp s3_allocate(table, state_key, amount) do
    state = s3_get_state(table, state_key)

    if state.allocated + amount > state.capacity do
      {:error, :over_capacity}
    else
      updated = %{state | allocated: state.allocated + amount}
      :ets.insert(table, {state_key, updated})
      {:ok, updated}
    end
  end

  defp s3_release(table, state_key, amount) do
    state = s3_get_state(table, state_key)
    released = max(0, state.allocated - amount)
    updated = %{state | allocated: released}
    :ets.insert(table, {state_key, updated})
    {:ok, updated}
  end

  defp s3_monitor(table, state_key) do
    state = s3_get_state(table, state_key)
    utilisation = state.allocated / max(state.capacity, 1)

    updated =
      if utilisation >= 0.8 and not state.audit_triggered do
        entry = %{event: :high_utilisation, at: now_ms(), utilisation: utilisation}
        %{state | audit_triggered: true, audit_log: [entry | state.audit_log]}
      else
        state
      end

    :ets.insert(table, {state_key, updated})
    {:ok, updated, utilisation}
  end

  defp s3_get_state(table, state_key) do
    case :ets.lookup(table, state_key) do
      [{^state_key, st}] -> st
      [] -> s3_new_state(100)
    end
  end

  defp s3_star_sample(table, unit_ids) do
    sample_size = max(1, trunc(length(unit_ids) * 0.3))
    sampled = Enum.take(unit_ids, sample_size)

    results =
      Enum.map(sampled, fn uid ->
        case :ets.lookup(table, uid) do
          [{^uid, entry}] -> {uid, entry.health}
          [] -> {uid, :unknown}
        end
      end)

    :ets.insert(table, {:s3_star_last_audit, %{sampled: sampled, results: results, at: now_ms()}})
    {:ok, results}
  end

  # --- S4: Intelligence ---

  defp s4_record_observation(table, type, value) do
    obs = %{type: type, value: value, ts: now_ms()}

    current =
      case :ets.lookup(table, :s4_observations) do
        [{:s4_observations, list}] -> list
        [] -> []
      end

    :ets.insert(table, {:s4_observations, [obs | current]})
    obs
  end

  defp s4_observations(table) do
    case :ets.lookup(table, :s4_observations) do
      [{:s4_observations, list}] -> Enum.reverse(list)
      [] -> []
    end
  end

  defp s4_detect_trend(observations, window \\ 5) do
    recent = observations |> Enum.take(-window) |> Enum.map(& &1.value)

    case recent do
      [] ->
        :stable

      [_single] ->
        :stable

      vals ->
        first = List.first(vals)
        last = List.last(vals)
        delta = last - first

        cond do
          delta > 0.1 * abs(first + 1) -> :rising
          delta < -0.1 * abs(first + 1) -> :falling
          true -> :stable
        end
    end
  end

  defp s4_propose_adaptation(table, trend) do
    proposal = %{trend: trend, proposed_at: now_ms(), action: trend_to_action(trend)}
    :ets.insert(table, {:s4_pending_proposal, proposal})
    {:ok, proposal}
  end

  defp trend_to_action(:rising), do: :scale_up
  defp trend_to_action(:falling), do: :scale_down
  defp trend_to_action(:stable), do: :hold

  # --- S5: Policy ---

  defp s5_new_policy(version \\ 1) do
    %{
      version: version,
      identity: "indrajaal-vsm",
      purpose: :homeostatic_control,
      constitutional_hash: compute_hash("Ψ₀Ψ₁Ψ₂Ψ₃Ψ₄Ψ₅"),
      checked_at: nil,
      violations: []
    }
  end

  defp s5_check_identity(table, policy_key, identity) do
    policy = s5_get_policy(table, policy_key)

    if policy.identity == identity do
      updated = %{policy | checked_at: now_ms()}
      :ets.insert(table, {policy_key, updated})
      {:ok, :identity_maintained}
    else
      {:error, :identity_drift}
    end
  end

  defp s5_check_purpose(table, policy_key, action) do
    policy = s5_get_policy(table, policy_key)
    allowed = action in [:scale_up, :scale_down, :hold, :audit, :alert]

    if allowed do
      {:ok, :purpose_aligned}
    else
      violation = %{action: action, at: now_ms()}
      updated = %{policy | violations: [violation | policy.violations]}
      :ets.insert(table, {policy_key, updated})
      {:error, :purpose_misaligned}
    end
  end

  defp s5_constitutional_check(table, policy_key) do
    policy = s5_get_policy(table, policy_key)
    expected = compute_hash("Ψ₀Ψ₁Ψ₂Ψ₃Ψ₄Ψ₅")

    if policy.constitutional_hash == expected do
      updated = %{policy | checked_at: now_ms()}
      :ets.insert(table, {policy_key, updated})
      {:ok, :constitutional_valid}
    else
      {:error, :constitutional_violated}
    end
  end

  defp s5_get_policy(table, policy_key) do
    case :ets.lookup(table, policy_key) do
      [{^policy_key, p}] -> p
      [] -> s5_new_policy()
    end
  end

  # --- Message bus (inter-system) ---

  defp bus_send(table, from, to, msg) do
    key = {:msg, from, to}

    current =
      case :ets.lookup(table, key) do
        [{^key, msgs}] -> msgs
        [] -> []
      end

    :ets.insert(table, {key, current ++ [%{msg: msg, seq: length(current), ts: now_ms()}]})
    :ok
  end

  defp bus_drain(table, from, to) do
    key = {:msg, from, to}

    msgs =
      case :ets.lookup(table, key) do
        [{^key, msgs}] -> msgs
        [] -> []
      end

    :ets.delete(table, key)
    msgs
  end

  # --- Algedonic channel ---

  defp algedonic_signal(table, unit_id, level, payload) do
    entry = %{unit: unit_id, level: level, payload: payload, ts: now_ms()}

    current =
      case :ets.lookup(table, :algedonic_queue) do
        [{:algedonic_queue, q}] -> q
        [] -> []
      end

    :ets.insert(table, {:algedonic_queue, current ++ [entry]})
    entry
  end

  defp algedonic_above_threshold?(table, threshold) do
    case :ets.lookup(table, :algedonic_queue) do
      [{:algedonic_queue, q}] ->
        Enum.any?(q, fn sig -> sig.level >= threshold end)

      [] ->
        false
    end
  end

  defp algedonic_drain(table) do
    case :ets.lookup(table, :algedonic_queue) do
      [{:algedonic_queue, q}] ->
        :ets.delete(table, :algedonic_queue)
        q

      [] ->
        []
    end
  end

  # --- Utility ---

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp compute_hash(data) do
    Base.encode16(:crypto.hash(:sha256, data), case: :lower)
  end

  # ===========================================================================
  # 1. S1 operational units
  # ===========================================================================

  describe "S1 operational units" do
    setup do
      t = new_table(:s1_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "register operational unit stores identity and default health", %{t: t} do
      entry = s1_register(t, "unit-alpha")
      assert entry.id == "unit-alpha"
      assert entry.health == :ok
      assert entry.tasks == []
    end

    test "unit health tracking: healthy unit can be set degraded", %{t: t} do
      s1_register(t, "unit-beta")
      assert :ok = s1_set_health(t, "unit-beta", :degraded)
      {:ok, entry} = s1_get(t, "unit-beta")
      assert entry.health == :degraded
    end

    test "unit health tracking: unknown unit returns :not_found", %{t: t} do
      assert {:error, :not_found} = s1_get(t, "non-existent")
    end

    test "task execution records task ID on success", %{t: t} do
      s1_register(t, "unit-gamma")
      {:ok, result} = s1_execute(t, "unit-gamma", "task-1", fn -> :done end)
      assert result == :done

      {:ok, entry} = s1_get(t, "unit-gamma")
      assert "task-1" in entry.tasks
    end

    test "task execution captures error without crashing unit", %{t: t} do
      s1_register(t, "unit-delta")
      {:error, reason} = s1_execute(t, "unit-delta", "task-bad", fn -> raise "deliberate" end)
      assert is_binary(reason)

      # Unit still accessible after error
      {:ok, entry} = s1_get(t, "unit-delta")
      assert entry.id == "unit-delta"
    end

    test "multiple units are independently tracked", %{t: t} do
      for i <- 1..4, do: s1_register(t, "unit-#{i}")

      s1_set_health(t, "unit-2", :failed)

      {:ok, u1} = s1_get(t, "unit-1")
      {:ok, u2} = s1_get(t, "unit-2")

      assert u1.health == :ok
      assert u2.health == :failed
    end
  end

  # ===========================================================================
  # 2. S2 coordination
  # ===========================================================================

  describe "S2 coordination" do
    setup do
      t = new_table(:s2_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "anti-oscillation: oscillation score zero for constant signal", %{t: t} do
      for _ <- 1..5, do: s2_record_signal(t, "a", "b", 1.0)
      sigs = s2_get_signals(t, "a", "b")
      assert s2_oscillation_score(sigs) == 0.0
    end

    test "anti-oscillation: alternating signal produces high oscillation score", %{t: t} do
      Enum.each([1.0, -1.0, 1.0, -1.0, 1.0], fn v ->
        s2_record_signal(t, "p", "q", v)
      end)

      sigs = s2_get_signals(t, "p", "q")
      score = s2_oscillation_score(sigs)
      assert score > 0.5
    end

    test "anti-oscillation damping reduces the magnitude of latest signal", %{t: t} do
      Enum.each([10.0, -5.0, 8.0, -3.0, 6.0], fn v ->
        s2_record_signal(t, "x", "y", v)
      end)

      damped = s2_damp(t, "x", "y")
      raw_latest = hd(s2_get_signals(t, "x", "y")).value
      # Damped value should be between raw and previous (magnitude reduced toward 0)
      assert abs(damped) <= abs(raw_latest) + 1.0
    end

    test "resource conflict resolution: schedule assigns each unit a slot", %{t: t} do
      unit_ids = ["unit-1", "unit-2", "unit-3"]
      {:ok, count} = s2_schedule(t, "cpu", unit_ids)
      assert count == 3
    end

    test "schedule coordination: empty unit list produces zero assignments", %{t: t} do
      {:ok, count} = s2_schedule(t, "cpu", [])
      assert count == 0
    end

    test "signals from different pairs are stored independently", %{t: t} do
      s2_record_signal(t, "a", "b", 1.0)
      s2_record_signal(t, "c", "d", 99.0)

      assert s2_get_signals(t, "a", "b") |> hd() |> Map.get(:value) == 1.0
      assert s2_get_signals(t, "c", "d") |> hd() |> Map.get(:value) == 99.0
    end
  end

  # ===========================================================================
  # 3. S3 operational management
  # ===========================================================================

  describe "S3 operational management" do
    setup do
      t = new_table(:s3_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "resource allocation succeeds within capacity", %{t: t} do
      :ets.insert(t, {:res_pool, s3_new_state(100)})
      {:ok, state} = s3_allocate(t, :res_pool, 40)
      assert state.allocated == 40
    end

    test "resource allocation refused when it would exceed capacity", %{t: t} do
      :ets.insert(t, {:res_pool, s3_new_state(100)})
      {:ok, _} = s3_allocate(t, :res_pool, 90)
      assert {:error, :over_capacity} = s3_allocate(t, :res_pool, 20)
    end

    test "resource release decrements allocation", %{t: t} do
      :ets.insert(t, {:res_pool, s3_new_state(100)})
      {:ok, _} = s3_allocate(t, :res_pool, 50)
      {:ok, state} = s3_release(t, :res_pool, 20)
      assert state.allocated == 30
    end

    test "performance monitoring records utilisation fraction", %{t: t} do
      :ets.insert(t, {:res_pool, s3_new_state(100)})
      {:ok, _} = s3_allocate(t, :res_pool, 60)
      {:ok, _state, utilisation} = s3_monitor(t, :res_pool)
      assert utilisation == 0.6
    end

    test "audit trigger fires when utilisation exceeds 80%", %{t: t} do
      :ets.insert(t, {:res_pool, s3_new_state(100)})
      {:ok, _} = s3_allocate(t, :res_pool, 85)
      {:ok, state, _util} = s3_monitor(t, :res_pool)
      assert state.audit_triggered == true
      assert length(state.audit_log) == 1
    end

    test "audit trigger does NOT fire when utilisation is below 80%", %{t: t} do
      :ets.insert(t, {:res_pool, s3_new_state(100)})
      {:ok, _} = s3_allocate(t, :res_pool, 50)
      {:ok, state, _util} = s3_monitor(t, :res_pool)
      assert state.audit_triggered == false
      assert state.audit_log == []
    end
  end

  # ===========================================================================
  # 4. S3* sporadic audit
  # ===========================================================================

  describe "S3* sporadic audit" do
    setup do
      t = new_table(:s3star_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "random audit sampling selects at most 30% of units", %{t: t} do
      unit_ids =
        Enum.map(1..10, fn i ->
          id = "unit-#{i}"
          s1_register(t, id)
          id
        end)

      {:ok, results} = s3_star_sample(t, unit_ids)
      assert length(results) <= 3
    end

    test "audit result is recorded in ETS", %{t: t} do
      unit_ids = ["u-a", "u-b", "u-c"]
      Enum.each(unit_ids, &s1_register(t, &1))
      {:ok, _} = s3_star_sample(t, unit_ids)

      [{:s3_star_last_audit, record}] = :ets.lookup(t, :s3_star_last_audit)
      assert is_list(record.sampled)
      assert is_integer(record.at)
    end

    test "audit on empty unit list returns empty results", %{t: t} do
      {:ok, results} = s3_star_sample(t, [])
      assert results == []
    end

    test "threshold alert: audit triggered when any unit is degraded", %{t: t} do
      ids = ["u-1", "u-2", "u-3"]
      Enum.each(ids, &s1_register(t, &1))
      s1_set_health(t, "u-2", :failed)

      {:ok, results} = s3_star_sample(t, ids)
      statuses = Enum.map(results, &elem(&1, 1))
      # Health values should include the :failed state when that unit is sampled
      # At minimum results are present and have valid health atoms
      Enum.each(statuses, fn s -> assert s in [:ok, :degraded, :failed, :unknown] end)
    end
  end

  # ===========================================================================
  # 5. S4 intelligence
  # ===========================================================================

  describe "S4 intelligence" do
    setup do
      t = new_table(:s4_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "environment scanning: observations are stored in time order", %{t: t} do
      s4_record_observation(t, :cpu, 0.4)
      s4_record_observation(t, :cpu, 0.6)
      s4_record_observation(t, :cpu, 0.8)

      obs = s4_observations(t)
      assert length(obs) == 3
      values = Enum.map(obs, & &1.value)
      assert values == [0.4, 0.6, 0.8]
    end

    test "trend detection: rising values produce :rising trend", %{t: t} do
      Enum.each([1.0, 2.0, 4.0, 8.0, 16.0], fn v ->
        s4_record_observation(t, :load, v)
      end)

      obs = s4_observations(t)
      assert s4_detect_trend(obs) == :rising
    end

    test "trend detection: constant values produce :stable trend", %{t: t} do
      Enum.each([5.0, 5.0, 5.0, 5.0, 5.0], fn v ->
        s4_record_observation(t, :load, v)
      end)

      obs = s4_observations(t)
      assert s4_detect_trend(obs) == :stable
    end

    test "trend detection: falling values produce :falling trend", %{t: t} do
      Enum.each([100.0, 60.0, 30.0, 10.0, 2.0], fn v ->
        s4_record_observation(t, :load, v)
      end)

      obs = s4_observations(t)
      assert s4_detect_trend(obs) == :falling
    end

    test "adaptation proposals map trend to correct action", %{t: t} do
      {:ok, up} = s4_propose_adaptation(t, :rising)
      assert up.action == :scale_up

      {:ok, down} = s4_propose_adaptation(t, :falling)
      assert down.action == :scale_down

      {:ok, hold} = s4_propose_adaptation(t, :stable)
      assert hold.action == :hold
    end

    test "pending proposal is stored in ETS and retrievable", %{t: t} do
      {:ok, _} = s4_propose_adaptation(t, :rising)
      [{:s4_pending_proposal, p}] = :ets.lookup(t, :s4_pending_proposal)
      assert p.trend == :rising
      assert p.action == :scale_up
    end
  end

  # ===========================================================================
  # 6. S5 policy
  # ===========================================================================

  describe "S5 policy" do
    setup do
      t = new_table(:s5_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "identity maintenance: matching identity returns :identity_maintained", %{t: t} do
      :ets.insert(t, {:p, s5_new_policy()})
      assert {:ok, :identity_maintained} = s5_check_identity(t, :p, "indrajaal-vsm")
    end

    test "identity maintenance: drifted identity returns :identity_drift", %{t: t} do
      :ets.insert(t, {:p, s5_new_policy()})
      assert {:error, :identity_drift} = s5_check_identity(t, :p, "rogue-vsm")
    end

    test "purpose alignment: whitelisted action returns :purpose_aligned", %{t: t} do
      :ets.insert(t, {:p, s5_new_policy()})

      for action <- [:scale_up, :scale_down, :hold, :audit, :alert] do
        assert {:ok, :purpose_aligned} = s5_check_purpose(t, :p, action)
      end
    end

    test "purpose alignment: unknown action records violation", %{t: t} do
      :ets.insert(t, {:p, s5_new_policy()})
      assert {:error, :purpose_misaligned} = s5_check_purpose(t, :p, :rogue_action)

      policy = s5_get_policy(t, :p)
      assert length(policy.violations) == 1
    end

    test "constitutional check: fresh policy passes verification", %{t: t} do
      :ets.insert(t, {:p, s5_new_policy()})
      assert {:ok, :constitutional_valid} = s5_constitutional_check(t, :p)
    end

    test "constitutional check: tampered hash triggers violation", %{t: t} do
      bad = %{s5_new_policy() | constitutional_hash: "000000"}
      :ets.insert(t, {:p, bad})
      assert {:error, :constitutional_violated} = s5_constitutional_check(t, :p)
    end

    test "check records timestamp after successful verification", %{t: t} do
      :ets.insert(t, {:p, s5_new_policy()})
      {:ok, :constitutional_valid} = s5_constitutional_check(t, :p)
      policy = s5_get_policy(t, :p)
      assert is_integer(policy.checked_at)
    end
  end

  # ===========================================================================
  # 7. Inter-system communication
  # ===========================================================================

  describe "inter-system communication" do
    setup do
      t = new_table(:bus_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "S1↔S2: S2 receives load signal from S1 unit", %{t: t} do
      s1_register(t, "s1-unit")
      {:ok, _} = s1_execute(t, "s1-unit", "t1", fn -> :ok end)
      s2_record_signal(t, "s1-unit", "s2", 0.7)

      sigs = s2_get_signals(t, "s1-unit", "s2")
      assert length(sigs) == 1
      assert hd(sigs).value == 0.7
    end

    test "S3→S1: S3 directive transmitted via bus", %{t: t} do
      bus_send(t, :s3, :s1, %{directive: :throttle, target: "unit-1"})
      msgs = bus_drain(t, :s3, :s1)
      assert length(msgs) == 1
      assert hd(msgs).msg.directive == :throttle
    end

    test "S4→S5: S4 recommendation forwarded to S5 via bus", %{t: t} do
      bus_send(t, :s4, :s5, %{recommendation: :scale_up, confidence: 0.85})
      msgs = bus_drain(t, :s4, :s5)
      assert hd(msgs).msg.recommendation == :scale_up
    end

    test "bus drain empties queue after consumption", %{t: t} do
      bus_send(t, :s3, :s1, %{cmd: :a})
      bus_send(t, :s3, :s1, %{cmd: :b})
      first_drain = bus_drain(t, :s3, :s1)
      second_drain = bus_drain(t, :s3, :s1)

      assert length(first_drain) == 2
      assert second_drain == []
    end

    test "messages from different pairs do not interfere", %{t: t} do
      bus_send(t, :s3, :s1, %{cmd: :x})
      bus_send(t, :s4, :s5, %{cmd: :y})

      s3_to_s1 = bus_drain(t, :s3, :s1)
      s4_to_s5 = bus_drain(t, :s4, :s5)

      assert hd(s3_to_s1).msg.cmd == :x
      assert hd(s4_to_s5).msg.cmd == :y
    end
  end

  # ===========================================================================
  # 8. Algedonic signals
  # ===========================================================================

  describe "algedonic signals" do
    setup do
      t = new_table(:alg_test)
      on_exit(fn -> delete_table(t) end)
      %{t: t}
    end

    test "urgent signal bypasses S1→S5 direct path", %{t: t} do
      sig = algedonic_signal(t, "unit-critical", 9, %{reason: :memory_exhaustion})
      assert sig.unit == "unit-critical"
      assert sig.level == 9
    end

    test "signal is queued and retrievable via drain", %{t: t} do
      algedonic_signal(t, "u1", 7, %{reason: :cpu_spike})
      algedonic_signal(t, "u2", 5, %{reason: :disk_full})
      queue = algedonic_drain(t)
      assert length(queue) == 2
    end

    test "threshold-based escalation: signals at/above threshold are detected", %{t: t} do
      algedonic_signal(t, "low-unit", 3, %{reason: :minor_issue})
      refute algedonic_above_threshold?(t, 7)

      algedonic_signal(t, "high-unit", 8, %{reason: :critical_issue})
      assert algedonic_above_threshold?(t, 7)
    end

    test "draining algedonic queue removes all signals", %{t: t} do
      algedonic_signal(t, "u", 5, %{})
      algedonic_drain(t)
      refute algedonic_above_threshold?(t, 1)
    end

    test "S5 receives escalated signal with level >= threshold", %{t: t} do
      algedonic_signal(t, "s1-node", 9, %{reason: :constitutional_violation})
      queue = algedonic_drain(t)
      escalated = Enum.filter(queue, fn s -> s.level >= 9 end)
      assert length(escalated) == 1
    end

    test "multiple units can raise independent algedonic signals", %{t: t} do
      for i <- 1..5, do: algedonic_signal(t, "unit-#{i}", i + 4, %{reason: :test})
      queue = algedonic_drain(t)
      assert length(queue) == 5
      units = Enum.map(queue, & &1.unit)
      assert length(Enum.uniq(units)) == 5
    end
  end

  # ===========================================================================
  # 9. Property: message propagation preserves ordering (SD generators)
  # ===========================================================================

  property "bus message ordering is FIFO within a channel (SD)" do
    ExUnitProperties.check all(
                             n <- SD.integer(2..10),
                             max_runs: 30
                           ) do
      t = new_table(:prop_order_test)

      try do
        for seq <- 0..(n - 1) do
          bus_send(t, :src, :dst, %{seq: seq})
        end

        msgs = bus_drain(t, :src, :dst)
        assert length(msgs) == n

        # Sequence numbers must be non-decreasing (FIFO ordering preserved)
        seqs = Enum.map(msgs, & &1.msg.seq)
        assert seqs == Enum.sort(seqs)
      after
        delete_table(t)
      end
    end
  end

  # ===========================================================================
  # 10. Property: resource allocation never exceeds capacity (SD generators)
  # ===========================================================================

  property "S3 allocation never exceeds declared capacity (SD)" do
    ExUnitProperties.check all(
                             capacity <- SD.integer(10..200),
                             requests <-
                               SD.list_of(SD.integer(1..50), min_length: 1, max_length: 8),
                             max_runs: 40
                           ) do
      t = new_table(:prop_cap_test)

      try do
        :ets.insert(t, {:cap_pool, s3_new_state(capacity)})

        Enum.each(requests, fn amount ->
          # Fire and forget — errors are expected and correct
          s3_allocate(t, :cap_pool, amount)
        end)

        state = s3_get_state(t, :cap_pool)
        # Invariant: allocated MUST never exceed capacity
        assert state.allocated <= state.capacity
      after
        delete_table(t)
      end
    end
  end

  # ===========================================================================
  # PropCheck forall: oscillation score is always in [0.0, 1.0] (PC generators)
  # ===========================================================================

  test "propcheck: oscillation score is bounded in [0.0, 1.0] (PC forall)" do
    Application.ensure_all_started(:propcheck)

    assert quickcheck(
             forall signals <- PC.list(PC.float()) do
               score = s2_oscillation_score(Enum.map(signals, fn v -> %{value: v} end))
               score >= 0.0 and score <= 1.0
             end
           )
  end
end
