defmodule Indrajaal.Formal.InvariantChecker do
  @moduledoc """
  Invariant Checker — L7 Formal Layer

  ## Design Intent
  Verifies system invariants at runtime using formal specifications encoded
  as Elixir functions. Each invariant is a predicate that returns true/false
  with an optional diagnostic message. The checker runs periodic sweeps and
  on-demand verification.

  Invariants are organized by constitutional Ψ-level (Ψ₀-Ψ₅) and can be
  registered dynamically at runtime. Failed invariants trigger PubSub alerts
  and telemetry events.

  ## STAMP Constraints
  - SC-VER-074: Constitutional L0-L7 MUST hold
  - SC-VER-075: Ψ₀ preserved through any operation
  - SC-FRACTAL-001: Expected genotype MUST match runtime graph
  - SC-SAFE-001: Safety invariants verified for all proposed state changes

  ## Change History
  | Version | Date       | Author | Change                    |
  |---------|------------|--------|---------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Initial implementation    |
  """

  use GenServer

  require Logger

  @name __MODULE__
  @table :formal_invariants
  @check_interval_ms 30_000
  @pubsub_topic "formal:invariants"

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type invariant_id :: atom()
  @type psi_level :: :psi0 | :psi1 | :psi2 | :psi3 | :psi4 | :psi5
  @type check_fn :: (-> boolean() | {boolean(), String.t()})

  @type invariant :: %{
          id: invariant_id(),
          psi_level: psi_level(),
          description: String.t(),
          check_fn: check_fn(),
          last_result: boolean() | nil,
          last_checked: non_neg_integer() | nil,
          failure_count: non_neg_integer()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a new invariant with a check function."
  @spec register(invariant_id(), psi_level(), String.t(), check_fn()) :: :ok
  def register(id, psi_level, description, check_fn)
      when is_atom(id) and is_function(check_fn, 0) do
    GenServer.call(@name, {:register, id, psi_level, description, check_fn})
  end

  @doc "Unregister an invariant."
  @spec unregister(invariant_id()) :: :ok
  def unregister(id) when is_atom(id) do
    GenServer.call(@name, {:unregister, id})
  end

  @doc "Check a single invariant by ID."
  @spec check(invariant_id()) :: {:ok, boolean()} | {:error, :not_found}
  def check(id) when is_atom(id) do
    GenServer.call(@name, {:check, id})
  end

  @doc "Run all registered invariants and return results."
  @spec check_all() :: %{passed: non_neg_integer(), failed: non_neg_integer(), results: [map()]}
  def check_all do
    GenServer.call(@name, :check_all, 30_000)
  end

  @doc "Check all invariants at a given Ψ level."
  @spec check_psi_level(psi_level()) :: [map()]
  def check_psi_level(level) when level in [:psi0, :psi1, :psi2, :psi3, :psi4, :psi5] do
    GenServer.call(@name, {:check_psi_level, level})
  end

  @doc "Returns all registered invariants with their last results."
  @spec status() :: [invariant()]
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :check_interval_ms, @check_interval_ms)

    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

    schedule_sweep(interval)

    Logger.info("[InvariantChecker] Started — interval=#{interval}ms [SC-VER-074]")

    {:ok, %{check_interval_ms: interval, sweep_count: 0}}
  end

  @impl true
  def handle_call({:register, id, psi_level, description, check_fn}, _from, state) do
    inv = %{
      id: id,
      psi_level: psi_level,
      description: description,
      check_fn: check_fn,
      last_result: nil,
      last_checked: nil,
      failure_count: 0
    }

    :ets.insert(@table, {id, inv})
    Logger.debug("[InvariantChecker] Registered: #{id} (#{psi_level}) [SC-VER-074]")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:unregister, id}, _from, state) do
    :ets.delete(@table, id)
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:check, id}, _from, state) do
    case :ets.lookup(@table, id) do
      [{^id, inv}] ->
        result = execute_check(inv)
        {:reply, {:ok, result.passed}, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:check_all, _from, state) do
    results = run_all_checks()
    {:reply, results, state}
  end

  @impl true
  def handle_call({:check_psi_level, level}, _from, state) do
    results =
      :ets.tab2list(@table)
      |> Enum.filter(fn {_id, inv} -> inv.psi_level == level end)
      |> Enum.map(fn {_id, inv} -> execute_check(inv) end)

    {:reply, results, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    invariants =
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, inv} -> Map.delete(inv, :check_fn) end)
      |> Enum.sort_by(& &1.psi_level)

    {:reply, invariants, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    results = run_all_checks()

    if results.failed > 0 do
      Logger.warning(
        "[InvariantChecker] Sweep #{state.sweep_count + 1}: #{results.failed} FAILED invariants [SC-VER-074]"
      )
    end

    schedule_sweep(state.check_interval_ms)

    {:noreply, %{state | sweep_count: state.sweep_count + 1}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp run_all_checks do
    results =
      :ets.tab2list(@table)
      |> Enum.map(fn {_id, inv} -> execute_check(inv) end)

    passed = Enum.count(results, & &1.passed)
    failed = length(results) - passed

    if failed > 0 do
      broadcast_failures(Enum.reject(results, & &1.passed))
    end

    %{passed: passed, failed: failed, results: results}
  end

  defp execute_check(inv) do
    now = System.system_time(:millisecond)

    {passed, message} =
      try do
        case inv.check_fn.() do
          true -> {true, "OK"}
          false -> {false, "Invariant violated"}
          {true, msg} -> {true, msg}
          {false, msg} -> {false, msg}
        end
      rescue
        e -> {false, "Exception: #{inspect(e)}"}
      end

    failure_count = if passed, do: 0, else: inv.failure_count + 1

    updated = %{inv | last_result: passed, last_checked: now, failure_count: failure_count}
    :ets.insert(@table, {inv.id, updated})

    emit_telemetry(inv.id, passed, inv.psi_level)

    %{id: inv.id, psi_level: inv.psi_level, passed: passed, message: message, timestamp: now}
  end

  defp broadcast_failures(failures) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:invariant_failures, %{failures: failures, timestamp: System.system_time(:millisecond)}}
    )
  rescue
    _ -> :ok
  end

  defp emit_telemetry(id, passed, psi_level) do
    :telemetry.execute(
      [:indrajaal, :formal, :invariant, :check],
      %{passed: if(passed, do: 1, else: 0)},
      %{invariant_id: id, psi_level: psi_level}
    )
  rescue
    _ -> :ok
  end

  defp schedule_sweep(interval) do
    Process.send_after(self(), :sweep, interval)
  end
end
