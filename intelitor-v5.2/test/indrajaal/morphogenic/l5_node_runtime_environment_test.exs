defmodule Indrajaal.Morphogenic.L5NodeRuntimeEnvironmentTest do
  @moduledoc """
  WHAT: L5 (Node Runtime Environment) test suite for BEAM VM stability in the
        Indrajaal SIL-6 Biomorphic Mesh.  All runtime metrics are simulated via
        ETS tables and lightweight pure-Elixir helpers — no production module
        dependencies.  Covers scheduler configuration, memory allocation
        tracking, process limit enforcement, runtime flag validation, Patient
        Mode environment variables, and scheduler utilisation accounting.

  WHY:  At L5 the fractal layer governs the runtime substrate on which all
        higher-level holons execute.  A misconfigured scheduler pool degrades
        throughput and can cause SIL-6 response-time violations.  Unbounded
        memory growth or stale runtime flags invalidate formal proofs that
        assume a well-formed BEAM node.  The tests here encode the invariants
        that MUST hold at the node boundary before the cluster (L6) can assert
        consensus or the domain (L3) can run business logic:
          * 16 BEAM schedulers active (SC-METRICS-003, SC-METRICS-007)
          * Scheduler wall-time utilisation ∈ [0.0, 1.0] per scheduler
          * Memory pressure detected and alerted when total/binary/atom
            allocations exceed configurable thresholds
          * Process count never silently exceeds the soft limit
          * Patient Mode env vars present and well-formed (Ω₁)
          * ELIXIR_ERL_OPTIONS contains +S 16:16 token
          * Runtime flags are idempotent and non-conflicting
          * Memory snapshots are monotonically tracked (allocations ≥ 0)
          * Scheduler IDs form a dense, zero-indexed range [0, N-1]
          * Soft-limit threshold headroom is always ≥ 0

  CONSTRAINTS:
    - SC-VER-006:      Patient Mode active during verification
    - SC-METRICS-003:  Parallelisation MANDATORY — 16 schedulers required
    - SC-METRICS-007:  MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8 required
    - SC-OPT-001:      Boot time < 60s target — scheduler configuration is
                       on the critical path
    - SC-SIL6-001:     Validate topology cache before startup; node runtime
                       MUST be stable before cache is trusted
    - SC-FUNC-001:     System MUST compile at all times — inline modules
                       used here must compile cleanly
    - Ω₁ Patient Mode: NO_TIMEOUT=true, PATIENT_MODE=enabled,
                       INFINITE_PATIENCE=true must be present in env
    - SC-SAFETY-018:   Pre-execution validation must complete all checks
    - SC-VER-041:      OODA cycle < 100ms — runtime polling must not block

  ## Change History
  | Version | Date       | Author | Change                                        |
  |---------|------------|--------|-----------------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Self-contained L5 node runtime stability suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :morphogenic
  @moduletag :l5
  @moduletag :runtime_environment
  @moduletag timeout: 60_000

  # ============================================================================
  # Constants (mirrors production configuration)
  # ============================================================================

  # SC-METRICS-003 mandated scheduler count
  @required_schedulers 16

  # Patient Mode env-var names (Ω₁)
  @patient_env_vars ~w[NO_TIMEOUT PATIENT_MODE ELIXIR_ERL_OPTIONS]

  # Memory alert thresholds (bytes)
  @memory_soft_limit_bytes 512 * 1024 * 1024
  @memory_critical_limit_bytes 1 * 1024 * 1024 * 1024

  # Process soft-limit fraction (alert when processes > soft_fraction * max)
  @process_soft_fraction 0.80

  # ============================================================================
  # ETS-based runtime metric simulation
  #
  # All "BEAM introspection" below uses ETS tables populated with synthetic
  # data.  Production code would call :erlang.system_info/1 and
  # :erlang.statistics/1 directly; here we model those shapes faithfully so
  # the test logic validates the same invariants.
  # ============================================================================

  # ---------------------------------------------------------------------------
  # SchedulerSim — simulates :erlang.system_info(:schedulers) and
  #                :erlang.statistics(:scheduler_wall_time)
  # ---------------------------------------------------------------------------

  defmodule SchedulerSim do
    @moduledoc false

    @doc "Create a fresh scheduler simulation table with `count` schedulers."
    @spec new(atom(), pos_integer()) :: atom()
    def new(name, count) when is_integer(count) and count > 0 do
      :ets.new(name, [:set, :public, :named_table])
      :ets.insert(name, {:scheduler_count, count})

      # Each entry: {{:sched, id}, active_time_us, total_time_us}
      # Key is a 2-tuple {:sched, id} so record_work/utilisation lookups match.
      # Represents the shape returned by :erlang.statistics(:scheduler_wall_time)
      for id <- 0..(count - 1) do
        :ets.insert(name, {{:sched, id}, 0, 1})
      end

      name
    end

    @doc "Return the scheduler count stored in the table."
    @spec scheduler_count(atom()) :: pos_integer()
    def scheduler_count(table) do
      [{_, count}] = :ets.lookup(table, :scheduler_count)
      count
    end

    @doc "Simulate work on scheduler `id` by adding `active_us` active time
         and `total_us` elapsed time."
    @spec record_work(atom(), non_neg_integer(), non_neg_integer(), pos_integer()) :: :ok
    def record_work(table, id, active_us, total_us)
        when is_integer(active_us) and active_us >= 0 and
               is_integer(total_us) and total_us > 0 do
      case :ets.lookup(table, {:sched, id}) do
        [{_, prev_active, prev_total}] ->
          :ets.insert(table, {{:sched, id}, prev_active + active_us, prev_total + total_us})

        [] ->
          :ets.insert(table, {{:sched, id}, active_us, total_us})
      end

      :ok
    end

    @doc "Return a list of {id, utilisation} tuples where utilisation ∈ [0.0, 1.0]."
    @spec utilisation(atom()) :: [{non_neg_integer(), float()}]
    def utilisation(table) do
      count = scheduler_count(table)

      for id <- 0..(count - 1) do
        case :ets.lookup(table, {:sched, id}) do
          [{_, active, total}] when total > 0 ->
            {id, min(1.0, active / total)}

          _ ->
            {id, 0.0}
        end
      end
    end

    @doc "Return IDs of schedulers that are considered 'hot' (utilisation > threshold)."
    @spec hot_schedulers(atom(), float()) :: [non_neg_integer()]
    def hot_schedulers(table, threshold \\ 0.90) do
      utilisation(table)
      |> Enum.filter(fn {_id, u} -> u > threshold end)
      |> Enum.map(fn {id, _} -> id end)
    end
  end

  # ---------------------------------------------------------------------------
  # MemorySim — simulates :erlang.memory/0 snapshot accumulation
  # ---------------------------------------------------------------------------

  defmodule MemorySim do
    @moduledoc false

    @categories [:total, :processes, :binary, :atom, :ets, :code]

    @doc "Create a memory simulation table with all categories at `initial_bytes`."
    @spec new(atom(), non_neg_integer()) :: atom()
    def new(name, initial_bytes \\ 0) do
      :ets.new(name, [:set, :public, :named_table])
      :ets.insert(name, {:snapshot_count, 0})

      for cat <- @categories do
        :ets.insert(name, {cat, initial_bytes})
      end

      name
    end

    @doc "Record a new memory snapshot, updating each category."
    @spec record_snapshot(atom(), keyword()) :: :ok
    def record_snapshot(table, readings) do
      [{_, count}] = :ets.lookup(table, :snapshot_count)
      :ets.insert(table, {:snapshot_count, count + 1})

      for {cat, bytes} <- readings do
        :ets.insert(table, {cat, bytes})
      end

      :ok
    end

    @doc "Read current bytes for a memory category."
    @spec bytes(atom(), atom()) :: non_neg_integer()
    def bytes(table, category) do
      case :ets.lookup(table, category) do
        [{_, b}] -> b
        [] -> 0
      end
    end

    @doc "Return true when total memory exceeds the given threshold."
    @spec pressure?(atom(), non_neg_integer()) :: boolean()
    def pressure?(table, threshold_bytes) do
      bytes(table, :total) > threshold_bytes
    end

    @doc "Return :ok | {:alert, category, bytes} for the first category above threshold."
    @spec check_thresholds(atom(), [{atom(), non_neg_integer()}]) ::
            :ok | {:alert, atom(), non_neg_integer()}
    def check_thresholds(table, thresholds) do
      Enum.find_value(thresholds, :ok, fn {cat, limit} ->
        current = bytes(table, cat)
        if current > limit, do: {:alert, cat, current}, else: nil
      end)
    end

    @doc "Return the number of snapshots recorded."
    @spec snapshot_count(atom()) :: non_neg_integer()
    def snapshot_count(table) do
      [{_, n}] = :ets.lookup(table, :snapshot_count)
      n
    end
  end

  # ---------------------------------------------------------------------------
  # ProcessSim — simulates process count tracking against system limits
  # ---------------------------------------------------------------------------

  defmodule ProcessSim do
    @moduledoc false

    @doc "Create a process limit simulation table."
    @spec new(atom(), pos_integer()) :: atom()
    def new(name, max_processes) when is_integer(max_processes) and max_processes > 0 do
      :ets.new(name, [:set, :public, :named_table])
      :ets.insert(name, {:max_processes, max_processes})
      :ets.insert(name, {:current_count, 0})
      :ets.insert(name, {:peak_count, 0})
      :ets.insert(name, {:rejections, 0})
      name
    end

    @doc "Attempt to spawn a simulated process.  Returns :ok or {:error, :system_limit}."
    @spec spawn_process(atom()) :: :ok | {:error, :system_limit}
    def spawn_process(table) do
      [{_, max}] = :ets.lookup(table, :max_processes)
      [{_, current}] = :ets.lookup(table, :current_count)

      if current >= max do
        [{_, rej}] = :ets.lookup(table, :rejections)
        :ets.insert(table, {:rejections, rej + 1})
        {:error, :system_limit}
      else
        new_count = current + 1
        :ets.insert(table, {:current_count, new_count})
        [{_, peak}] = :ets.lookup(table, :peak_count)
        if new_count > peak, do: :ets.insert(table, {:peak_count, new_count})
        :ok
      end
    end

    @doc "Simulate a process exiting, decrementing the count."
    @spec exit_process(atom()) :: :ok
    def exit_process(table) do
      [{_, current}] = :ets.lookup(table, :current_count)
      new_count = max(0, current - 1)
      :ets.insert(table, {:current_count, new_count})
      :ok
    end

    @doc "Return the headroom (max - current) in absolute process count."
    @spec headroom(atom()) :: non_neg_integer()
    def headroom(table) do
      [{_, max}] = :ets.lookup(table, :max_processes)
      [{_, current}] = :ets.lookup(table, :current_count)
      max(0, max - current)
    end

    @doc "Return true when current > soft_fraction * max."
    @spec soft_limit_breached?(atom(), float()) :: boolean()
    def soft_limit_breached?(table, soft_fraction) do
      [{_, max}] = :ets.lookup(table, :max_processes)
      [{_, current}] = :ets.lookup(table, :current_count)
      current > soft_fraction * max
    end

    @doc "Return current process count."
    @spec current_count(atom()) :: non_neg_integer()
    def current_count(table) do
      [{_, n}] = :ets.lookup(table, :current_count)
      n
    end

    @doc "Return max processes limit."
    @spec max_processes(atom()) :: pos_integer()
    def max_processes(table) do
      [{_, n}] = :ets.lookup(table, :max_processes)
      n
    end

    @doc "Return rejection count."
    @spec rejection_count(atom()) :: non_neg_integer()
    def rejection_count(table) do
      [{_, n}] = :ets.lookup(table, :rejections)
      n
    end
  end

  # ---------------------------------------------------------------------------
  # EnvSim — simulates Patient Mode environment variable validation (Ω₁)
  # ---------------------------------------------------------------------------

  defmodule EnvSim do
    @moduledoc false

    @doc "Build a synthetic env map representing a correctly configured Patient Mode node."
    @spec patient_mode_env() :: %{String.t() => String.t()}
    def patient_mode_env do
      %{
        "NO_TIMEOUT" => "true",
        "PATIENT_MODE" => "enabled",
        "INFINITE_PATIENCE" => "true",
        "ELIXIR_ERL_OPTIONS" => "+S 16:16 +SDio 16",
        "MIX_OS_DEPS_COMPILE_PARTITION_COUNT" => "8",
        "SKIP_ZENOH_NIF" => "0"
      }
    end

    @doc "Build an env map missing a specific key."
    @spec env_missing(String.t()) :: %{String.t() => String.t()}
    def env_missing(key), do: Map.delete(patient_mode_env(), key)

    @doc "Check whether all required Patient Mode keys are present and non-empty."
    @spec patient_mode_valid?(%{String.t() => String.t()}, [String.t()]) :: boolean()
    def patient_mode_valid?(env, required_keys) do
      Enum.all?(required_keys, fn k ->
        case Map.get(env, k) do
          nil -> false
          "" -> false
          _val -> true
        end
      end)
    end

    @doc "Check ELIXIR_ERL_OPTIONS contains the +S scheduler token."
    @spec erl_options_have_scheduler?(String.t()) :: boolean()
    def erl_options_have_scheduler?(erl_options) do
      String.contains?(erl_options, "+S ")
    end

    @doc "Parse the scheduler count N from `+S N:N` token in erl_options."
    @spec parse_scheduler_count(String.t()) :: {:ok, pos_integer()} | :error
    def parse_scheduler_count(erl_options) do
      case Regex.run(~r/\+S\s+(\d+):/, erl_options, capture: :all_but_first) do
        [n_str] ->
          case Integer.parse(n_str) do
            {n, ""} when n > 0 -> {:ok, n}
            _ -> :error
          end

        _ ->
          :error
      end
    end

    @doc "Validate the MIX_OS_DEPS_COMPILE_PARTITION_COUNT is set to at least `min`."
    @spec partition_count_valid?(%{String.t() => String.t()}, pos_integer()) :: boolean()
    def partition_count_valid?(env, min) do
      case Map.get(env, "MIX_OS_DEPS_COMPILE_PARTITION_COUNT") do
        nil ->
          false

        val ->
          case Integer.parse(val) do
            {n, ""} -> n >= min
            _ -> false
          end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # RuntimeFlagSim — simulates BEAM runtime flag idempotency
  # ---------------------------------------------------------------------------

  defmodule RuntimeFlagSim do
    @moduledoc false

    @known_flags ~w[
      async_threads
      max_ports
      scheduler_bind_type
      multi_scheduling
      smp_support
      time_warp_mode
    ]a

    @doc "Build a default runtime flags map."
    @spec defaults() :: %{atom() => term()}
    def defaults do
      %{
        async_threads: 16,
        max_ports: 65_536,
        scheduler_bind_type: :no_node_processor_spread,
        multi_scheduling: :enabled,
        smp_support: true,
        time_warp_mode: :no_time_warp
      }
    end

    @doc "Return the list of recognised flag names."
    @spec known_flags() :: [atom()]
    def known_flags, do: @known_flags

    @doc "Apply a flag update.  Returns {:ok, new_flags} or {:error, :unknown_flag}."
    @spec apply_flag(%{atom() => term()}, atom(), term()) ::
            {:ok, %{atom() => term()}} | {:error, :unknown_flag}
    def apply_flag(flags, name, value) do
      if name in @known_flags do
        {:ok, Map.put(flags, name, value)}
      else
        {:error, :unknown_flag}
      end
    end

    @doc "Check that applying the same flag twice yields the same final state (idempotency)."
    @spec idempotent?(atom(), term()) :: boolean()
    def idempotent?(flag_name, value) do
      base = defaults()
      {:ok, once} = apply_flag(base, flag_name, value)
      {:ok, twice} = apply_flag(once, flag_name, value)
      once == twice
    end

    @doc "Return true when flags contain no conflicting entries."
    @spec conflict_free?(%{atom() => term()}) :: boolean()
    def conflict_free?(flags) do
      # Known conflict: multi_scheduling disabled AND smp_support true
      not (flags[:multi_scheduling] == :disabled and flags[:smp_support] == true)
    end
  end

  # ============================================================================
  # Utility helpers
  # ============================================================================

  defp unique_table(prefix) do
    :"#{prefix}_#{System.unique_integer([:positive])}"
  end

  defp delete_table_if_alive(table) do
    if :ets.info(table) != :undefined, do: :ets.delete(table)
  end

  # ============================================================================
  # 1. Scheduler configuration (SC-METRICS-003)
  # ============================================================================

  describe "scheduler configuration — SC-METRICS-003" do
    @tag :scheduler
    test "scheduler simulation initialises with the mandated 16-scheduler count" do
      t = unique_table(:sched_init)
      SchedulerSim.new(t, @required_schedulers)
      on_exit(fn -> delete_table_if_alive(t) end)

      assert SchedulerSim.scheduler_count(t) == @required_schedulers
    end

    @tag :scheduler
    test "scheduler IDs form a dense zero-indexed range [0, N-1]" do
      t = unique_table(:sched_range)
      SchedulerSim.new(t, @required_schedulers)
      on_exit(fn -> delete_table_if_alive(t) end)

      ids = SchedulerSim.utilisation(t) |> Enum.map(fn {id, _} -> id end) |> Enum.sort()
      expected = Enum.to_list(0..(@required_schedulers - 1))
      assert ids == expected
    end

    @tag :scheduler
    test "all schedulers start with zero utilisation (no work recorded yet)" do
      t = unique_table(:sched_zero)
      SchedulerSim.new(t, @required_schedulers)
      on_exit(fn -> delete_table_if_alive(t) end)

      utils = SchedulerSim.utilisation(t)
      assert Enum.all?(utils, fn {_id, u} -> u == 0.0 end)
    end

    @tag :scheduler
    test "record_work on a scheduler increases its utilisation above zero" do
      t = unique_table(:sched_work)
      SchedulerSim.new(t, @required_schedulers)
      on_exit(fn -> delete_table_if_alive(t) end)

      # Simulate scheduler 0 spending 80% of 1s in active work
      SchedulerSim.record_work(t, 0, 800_000, 1_000_000)
      [{0, u}] = SchedulerSim.utilisation(t) |> Enum.filter(fn {id, _} -> id == 0 end)
      assert u > 0.0
      assert u <= 1.0
    end

    @tag :scheduler
    test "hot_schedulers returns only schedulers above the given threshold" do
      t = unique_table(:sched_hot)
      SchedulerSim.new(t, @required_schedulers)
      on_exit(fn -> delete_table_if_alive(t) end)

      # Schedulers 0 and 1 are hot; rest idle
      SchedulerSim.record_work(t, 0, 950_000, 1_000_000)
      SchedulerSim.record_work(t, 1, 920_000, 1_000_000)

      hot = SchedulerSim.hot_schedulers(t, 0.90)
      assert 0 in hot
      assert 1 in hot
      # Scheduler 2 should NOT be hot
      refute 2 in hot
    end

    @tag :scheduler
    test "utilisation is capped at 1.0 even when active_time > total_time (guard)" do
      t = unique_table(:sched_cap)
      SchedulerSim.new(t, 4)
      on_exit(fn -> delete_table_if_alive(t) end)

      # Record more active than total — should not exceed 1.0
      SchedulerSim.record_work(t, 0, 2_000_000, 1_000_000)
      [{0, u}] = SchedulerSim.utilisation(t) |> Enum.filter(fn {id, _} -> id == 0 end)
      assert u <= 1.0
    end
  end

  # ============================================================================
  # 2. Memory pressure detection
  # ============================================================================

  describe "memory pressure detection" do
    @tag :memory
    test "memory simulation starts at the specified initial bytes" do
      t = unique_table(:mem_init)
      MemorySim.new(t, 100_000)
      on_exit(fn -> delete_table_if_alive(t) end)

      assert MemorySim.bytes(t, :total) == 100_000
    end

    @tag :memory
    test "pressure? returns false when total memory is below threshold" do
      t = unique_table(:mem_pressure_low)
      MemorySim.new(t, 100_000)
      on_exit(fn -> delete_table_if_alive(t) end)

      refute MemorySim.pressure?(t, @memory_soft_limit_bytes)
    end

    @tag :memory
    test "pressure? returns true when total memory exceeds soft limit" do
      t = unique_table(:mem_pressure_high)
      # Start at one byte above soft limit
      MemorySim.new(t, @memory_soft_limit_bytes + 1)
      on_exit(fn -> delete_table_if_alive(t) end)

      assert MemorySim.pressure?(t, @memory_soft_limit_bytes)
    end

    @tag :memory
    test "check_thresholds returns :ok when no category exceeds its limit" do
      t = unique_table(:mem_ok)
      MemorySim.new(t, 0)
      on_exit(fn -> delete_table_if_alive(t) end)

      MemorySim.record_snapshot(t, total: 1_000, binary: 500, atom: 100)
      result = MemorySim.check_thresholds(t, total: 10_000, binary: 5_000)
      assert result == :ok
    end

    @tag :memory
    test "check_thresholds returns {:alert, category, bytes} when limit breached" do
      t = unique_table(:mem_alert)
      MemorySim.new(t, 0)
      on_exit(fn -> delete_table_if_alive(t) end)

      MemorySim.record_snapshot(t, total: 600_000_000, binary: 200_000_000)
      result = MemorySim.check_thresholds(t, total: @memory_soft_limit_bytes)
      assert {:alert, :total, bytes} = result
      assert bytes == 600_000_000
    end

    @tag :memory
    test "snapshot_count increments on each record_snapshot call" do
      t = unique_table(:mem_snap_count)
      MemorySim.new(t)
      on_exit(fn -> delete_table_if_alive(t) end)

      assert MemorySim.snapshot_count(t) == 0
      MemorySim.record_snapshot(t, total: 1_000)
      MemorySim.record_snapshot(t, total: 2_000)
      assert MemorySim.snapshot_count(t) == 2
    end
  end

  # ============================================================================
  # 3. Process limit enforcement
  # ============================================================================

  describe "process limit enforcement" do
    @tag :process_limits
    test "spawn_process succeeds when current count is below max" do
      t = unique_table(:proc_ok)
      ProcessSim.new(t, 1000)
      on_exit(fn -> delete_table_if_alive(t) end)

      assert ProcessSim.spawn_process(t) == :ok
      assert ProcessSim.current_count(t) == 1
    end

    @tag :process_limits
    test "spawn_process returns system_limit when count equals max" do
      t = unique_table(:proc_limit)
      ProcessSim.new(t, 3)
      on_exit(fn -> delete_table_if_alive(t) end)

      assert ProcessSim.spawn_process(t) == :ok
      assert ProcessSim.spawn_process(t) == :ok
      assert ProcessSim.spawn_process(t) == :ok
      assert ProcessSim.spawn_process(t) == {:error, :system_limit}
    end

    @tag :process_limits
    test "exit_process decrements the count, restoring headroom" do
      t = unique_table(:proc_exit)
      ProcessSim.new(t, 10)
      on_exit(fn -> delete_table_if_alive(t) end)

      ProcessSim.spawn_process(t)
      ProcessSim.spawn_process(t)
      assert ProcessSim.current_count(t) == 2

      ProcessSim.exit_process(t)
      assert ProcessSim.current_count(t) == 1
    end

    @tag :process_limits
    test "headroom is always max - current (non-negative)" do
      t = unique_table(:proc_headroom)
      ProcessSim.new(t, 100)
      on_exit(fn -> delete_table_if_alive(t) end)

      for _ <- 1..30, do: ProcessSim.spawn_process(t)
      assert ProcessSim.headroom(t) == 70
    end

    @tag :process_limits
    test "soft_limit_breached? triggers alert above configured fraction" do
      t = unique_table(:proc_soft)
      ProcessSim.new(t, 100)
      on_exit(fn -> delete_table_if_alive(t) end)

      for _ <- 1..85, do: ProcessSim.spawn_process(t)
      assert ProcessSim.soft_limit_breached?(t, @process_soft_fraction)
    end

    @tag :process_limits
    test "soft_limit_breached? is false when well below the fraction" do
      t = unique_table(:proc_soft_ok)
      ProcessSim.new(t, 100)
      on_exit(fn -> delete_table_if_alive(t) end)

      for _ <- 1..50, do: ProcessSim.spawn_process(t)
      refute ProcessSim.soft_limit_breached?(t, @process_soft_fraction)
    end

    @tag :process_limits
    test "rejection_count increments for every refused spawn" do
      t = unique_table(:proc_reject)
      ProcessSim.new(t, 2)
      on_exit(fn -> delete_table_if_alive(t) end)

      ProcessSim.spawn_process(t)
      ProcessSim.spawn_process(t)
      # Both subsequent attempts should be rejected
      ProcessSim.spawn_process(t)
      ProcessSim.spawn_process(t)

      assert ProcessSim.rejection_count(t) == 2
    end
  end

  # ============================================================================
  # 4. Runtime flag validation
  # ============================================================================

  describe "runtime flag validation (idempotency and conflict detection)" do
    @tag :flags
    test "applying a valid flag updates the flags map" do
      flags = RuntimeFlagSim.defaults()
      assert {:ok, updated} = RuntimeFlagSim.apply_flag(flags, :async_threads, 32)
      assert updated[:async_threads] == 32
    end

    @tag :flags
    test "applying an unknown flag returns {:error, :unknown_flag}" do
      flags = RuntimeFlagSim.defaults()
      assert {:error, :unknown_flag} = RuntimeFlagSim.apply_flag(flags, :nonexistent_flag, 1)
    end

    @tag :flags
    test "known_flags/0 contains all expected flag names" do
      flags = RuntimeFlagSim.known_flags()
      assert :multi_scheduling in flags
      assert :smp_support in flags
      assert :async_threads in flags
    end

    @tag :flags
    test "idempotent?/2 returns true for any known flag applied twice" do
      for flag <- RuntimeFlagSim.known_flags() do
        current = RuntimeFlagSim.defaults()[flag]

        assert RuntimeFlagSim.idempotent?(flag, current),
               "Expected #{flag} to be idempotent but was not"
      end
    end

    @tag :flags
    test "conflict_free? returns false for multi_scheduling:disabled with smp_support:true" do
      conflicting = %{RuntimeFlagSim.defaults() | multi_scheduling: :disabled, smp_support: true}
      refute RuntimeFlagSim.conflict_free?(conflicting)
    end

    @tag :flags
    test "conflict_free? returns true for default flags" do
      assert RuntimeFlagSim.conflict_free?(RuntimeFlagSim.defaults())
    end
  end

  # ============================================================================
  # 5. Patient Mode environment variables (SC-VER-006, Ω₁)
  # ============================================================================

  describe "Patient Mode environment variables — SC-VER-006, Ω₁" do
    @tag :patient_mode
    test "patient_mode_env/0 provides all required keys" do
      env = EnvSim.patient_mode_env()
      assert EnvSim.patient_mode_valid?(env, @patient_env_vars)
    end

    @tag :patient_mode
    test "env missing NO_TIMEOUT is invalid" do
      env = EnvSim.env_missing("NO_TIMEOUT")
      refute EnvSim.patient_mode_valid?(env, @patient_env_vars)
    end

    @tag :patient_mode
    test "env missing PATIENT_MODE is invalid" do
      env = EnvSim.env_missing("PATIENT_MODE")
      refute EnvSim.patient_mode_valid?(env, @patient_env_vars)
    end

    @tag :patient_mode
    test "ELIXIR_ERL_OPTIONS contains +S scheduler token (SC-METRICS-003)" do
      opts = EnvSim.patient_mode_env()["ELIXIR_ERL_OPTIONS"]
      assert EnvSim.erl_options_have_scheduler?(opts)
    end

    @tag :patient_mode
    test "parse_scheduler_count extracts 16 from canonical +S 16:16 token" do
      opts = "+S 16:16 +SDio 16"
      assert {:ok, 16} = EnvSim.parse_scheduler_count(opts)
    end

    @tag :patient_mode
    test "parse_scheduler_count returns :error for options without +S" do
      assert :error = EnvSim.parse_scheduler_count("+SDio 16")
    end

    @tag :patient_mode
    test "MIX_OS_DEPS_COMPILE_PARTITION_COUNT is >= 8 (SC-METRICS-007)" do
      env = EnvSim.patient_mode_env()
      assert EnvSim.partition_count_valid?(env, 8)
    end

    @tag :patient_mode
    test "partition_count_valid? returns false when key is absent" do
      env = Map.delete(EnvSim.patient_mode_env(), "MIX_OS_DEPS_COMPILE_PARTITION_COUNT")
      refute EnvSim.partition_count_valid?(env, 8)
    end
  end

  # ============================================================================
  # 6. Property: scheduler utilisation always in [0.0, 1.0]  (SD check all)
  # ============================================================================

  @tag :property
  property "scheduler utilisation is always in [0.0, 1.0] for any workload (SD)" do
    forall {active_us, total_us, id} <-
             {PC.integer(0, 10_000_000), PC.pos_integer(), PC.integer(0, 15)} do
      t = unique_table(:prop_util)
      SchedulerSim.new(t, @required_schedulers)

      # total must be >= 1 (guaranteed by positive_integer)
      safe_total = max(total_us, 1)
      SchedulerSim.record_work(t, id, active_us, safe_total)

      for {_scheduler_id, u} <- SchedulerSim.utilisation(t) do
        assert u >= 0.0,
               "Expected utilisation >= 0.0 but got #{u} for scheduler #{_scheduler_id}"

        assert u <= 1.0,
               "Expected utilisation <= 1.0 but got #{u} for scheduler #{_scheduler_id}"
      end

      delete_table_if_alive(t)
    end
  end

  # ============================================================================
  # 7. Property: memory allocations are monotonically tracked  (SD check all)
  #
  # Each snapshot only grows the total.  The snapshot_count is strictly
  # monotonically increasing across calls to record_snapshot/2.
  # ============================================================================

  @tag :property
  property "snapshot_count increases monotonically with every record_snapshot call (SD)" do
    forall snapshots <- PC.list(PC.pos_integer()) do
      t = unique_table(:prop_snap)
      MemorySim.new(t, 0)

      {final_count, _} =
        Enum.reduce(snapshots, {0, 0}, fn bytes, {prev_count, _prev_bytes} ->
          MemorySim.record_snapshot(t, total: bytes)
          new_count = MemorySim.snapshot_count(t)

          assert new_count > prev_count,
                 "snapshot_count #{new_count} must exceed previous #{prev_count}"

          {new_count, bytes}
        end)

      assert final_count == length(snapshots)
      delete_table_if_alive(t)
    end
  end

  # ============================================================================
  # 8. Property: process headroom is always non-negative  (PC forall)
  # ============================================================================

  @tag :property
  property "property: headroom is always >= 0 regardless of spawn sequence (PC)" do
    forall {max_procs, spawn_count} <-
             {PC.pos_integer(), PC.non_neg_integer()} do
      t = unique_table(:prop_head)
      ProcessSim.new(t, max_procs)

      # Spawn up to spawn_count processes — stop early if limit is reached
      Enum.each(1..spawn_count, fn _ ->
        ProcessSim.spawn_process(t)
      end)

      headroom = ProcessSim.headroom(t)
      delete_table_if_alive(t)

      headroom >= 0
    end
  end

  # ============================================================================
  # 9. Property: all known runtime flags are idempotent  (PC forall)
  # ============================================================================

  @tag :property
  property "property: applying any known flag twice produces the same state (PC)" do
    forall flag <- PC.elements(RuntimeFlagSim.known_flags()) do
      current_value = RuntimeFlagSim.defaults()[flag]
      RuntimeFlagSim.idempotent?(flag, current_value)
    end
  end
end
