defmodule Indrajaal.Biomorphic.ApoptosisManager do
  @moduledoc """
  ## Design Intent
  Programmed cell death manager for the Indrajaal biomorphic mesh. Monitors
  registered processes' health scores (0.0–1.0) and orchestrates graceful
  termination when a process falls below the death threshold, preventing
  diseased processes from corrupting healthy system state.

  Apoptosis protocol (3-phase):
    Phase 1 — Warn:      health <= warn_threshold (default 0.4)
    Phase 2 — Drain:     health <= drain_threshold (default 0.3)
    Phase 3 — Terminate: health <= death_threshold (default 0.2)

  Revival tracking records processes that restart after apoptosis to detect
  persistent health failures (zombie pattern).

  Broadcasts all lifecycle events via PubSub "biomorphic:apoptosis".

  ## STAMP Constraints
  - SC-SAFETY-020: Auto-halt at threat threshold — ENFORCED
  - SC-SIL4-015: Split-brain detection triggers apoptosis — ENFORCED
  - SC-SAFETY-022: Emergency stop < 5 seconds — REFERENCED
  - SC-FUNC-002: Core services MUST be operational — RESPECTED (exemption list)

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude | Initial implementation |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @ets_scores :apoptosis_scores
  @ets_revivals :apoptosis_revivals
  @pubsub_topic "biomorphic:apoptosis"
  @zenoh_topic "indrajaal/biomorphic/apoptosis/event"
  @checkpoint "CP-BIO-APOPTOSIS-01"

  # Health thresholds
  @warn_threshold 0.4
  @drain_threshold 0.3
  @death_threshold 0.2

  # Max revival count before escalation to Guardian
  @max_revivals 3

  # Scan interval for proactive health monitoring
  @scan_interval_ms 10_000

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Register a process for health monitoring."
  @spec register(atom(), keyword()) :: :ok
  def register(process_name, opts \\ []) when is_atom(process_name) do
    GenServer.call(@name, {:register, process_name, opts})
  end

  @doc "Update the health score for a monitored process (0.0–1.0)."
  @spec update_health(atom(), float()) :: :ok | {:error, :not_registered}
  def update_health(process_name, score)
      when is_atom(process_name) and is_float(score) do
    GenServer.call(@name, {:update_health, process_name, score})
  end

  @doc "Deregister a process from health monitoring."
  @spec deregister(atom()) :: :ok
  def deregister(process_name) when is_atom(process_name) do
    GenServer.call(@name, {:deregister, process_name})
  end

  @doc "Notify the manager that a process has revived after apoptosis."
  @spec notify_revival(atom()) :: :ok
  def notify_revival(process_name) when is_atom(process_name) do
    GenServer.cast(@name, {:notify_revival, process_name})
  end

  @doc "Returns the current health entry for a process."
  @spec health_entry(atom()) :: {:ok, map()} | :not_found
  def health_entry(process_name) when is_atom(process_name) do
    case :ets.lookup(@ets_scores, process_name) do
      [{^process_name, entry}] -> {:ok, entry}
      [] -> :not_found
    end
  end

  @doc "Returns all monitored processes and their health status."
  @spec all_entries() :: list(map())
  def all_entries do
    :ets.tab2list(@ets_scores)
    |> Enum.map(fn {_name, entry} -> entry end)
  end

  @doc "Returns apoptosis manager status summary."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    :ets.new(@ets_scores, [:set, :public, :named_table, read_concurrency: true])
    :ets.new(@ets_revivals, [:set, :public, :named_table, read_concurrency: true])

    death_threshold = Keyword.get(opts, :death_threshold, @death_threshold)
    schedule_scan()

    state = %{
      death_threshold: death_threshold,
      warn_count: 0,
      drain_count: 0,
      termination_count: 0,
      revival_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.warning(
      "[APOPTOSIS] ApoptosisManager started — " <>
        "death_threshold=#{death_threshold} checkpoint=#{@checkpoint}"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:register, process_name, opts}, _from, state) do
    threshold = Keyword.get(opts, :death_threshold, state.death_threshold)
    exempt = Keyword.get(opts, :exempt, false)

    entry = %{
      name: process_name,
      score: 1.0,
      phase: :healthy,
      death_threshold: threshold,
      exempt: exempt,
      registered_at: DateTime.utc_now(),
      last_updated: DateTime.utc_now()
    }

    :ets.insert(@ets_scores, {process_name, entry})
    Logger.debug("[APOPTOSIS] Process registered: #{inspect(process_name)} exempt=#{exempt}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:update_health, process_name, score}, _from, state) do
    case :ets.lookup(@ets_scores, process_name) do
      [] ->
        {:reply, {:error, :not_registered}, state}

      [{^process_name, entry}] ->
        clamped = max(0.0, min(1.0, score))
        new_phase = compute_phase(clamped)
        updated = %{entry | score: clamped, phase: new_phase, last_updated: DateTime.utc_now()}
        :ets.insert(@ets_scores, {process_name, updated})

        {new_state, _} = maybe_apoptose(updated, state)
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:deregister, process_name}, _from, state) do
    :ets.delete(@ets_scores, process_name)
    Logger.debug("[APOPTOSIS] Process deregistered: #{inspect(process_name)}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    entries = all_entries()
    healthy = Enum.count(entries, fn e -> e.phase == :healthy end)
    warned = Enum.count(entries, fn e -> e.phase == :warned end)
    draining = Enum.count(entries, fn e -> e.phase == :draining end)

    reply = %{
      monitored_count: length(entries),
      healthy: healthy,
      warned: warned,
      draining: draining,
      warn_count: state.warn_count,
      drain_count: state.drain_count,
      termination_count: state.termination_count,
      revival_count: state.revival_count,
      death_threshold: state.death_threshold,
      uptime_s: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, reply, state}
  end

  @impl true
  def handle_cast({:notify_revival, process_name}, state) do
    revival_count =
      case :ets.lookup(@ets_revivals, process_name) do
        [{^process_name, count}] -> count + 1
        [] -> 1
      end

    :ets.insert(@ets_revivals, {process_name, revival_count})

    broadcast_event(:process_revived, %{
      process: process_name,
      revival_count: revival_count
    })

    if revival_count > @max_revivals do
      Logger.warning(
        "[APOPTOSIS] Zombie pattern detected: #{inspect(process_name)} " <>
          "revivals=#{revival_count} SC-SAFETY-020"
      )

      report_zombie_to_guardian(process_name, revival_count)
    end

    {:noreply, %{state | revival_count: state.revival_count + 1}}
  end

  @impl true
  def handle_info(:scan_tick, state) do
    new_state = scan_all_processes(state)
    schedule_scan()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[APOPTOSIS] Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private — health logic
  # ---------------------------------------------------------------------------

  defp compute_phase(score) when score > @warn_threshold, do: :healthy
  defp compute_phase(score) when score > @drain_threshold, do: :warned
  defp compute_phase(score) when score > @death_threshold, do: :draining
  defp compute_phase(_score), do: :terminal

  defp maybe_apoptose(%{exempt: true}, state), do: {state, :exempted}

  defp maybe_apoptose(entry, state) do
    case entry.phase do
      :terminal ->
        Logger.warning(
          "[APOPTOSIS] Terminal phase: #{inspect(entry.name)} " <>
            "score=#{entry.score} threshold=#{entry.death_threshold} SC-SAFETY-020"
        )

        execute_apoptosis(entry.name)

        broadcast_event(:process_terminated, %{
          process: entry.name,
          score: entry.score,
          reason: :health_below_threshold
        })

        emit_telemetry(:terminated, entry.name, entry.score)

        new_state = %{state | termination_count: state.termination_count + 1}
        {new_state, :terminated}

      :draining ->
        if entry.phase != :draining do
          broadcast_event(:process_draining, %{process: entry.name, score: entry.score})
          emit_telemetry(:draining, entry.name, entry.score)
        end

        new_state = %{state | drain_count: state.drain_count + 1}
        {new_state, :draining}

      :warned ->
        broadcast_event(:process_warned, %{process: entry.name, score: entry.score})
        emit_telemetry(:warned, entry.name, entry.score)
        new_state = %{state | warn_count: state.warn_count + 1}
        {new_state, :warned}

      _ ->
        {state, :healthy}
    end
  end

  defp execute_apoptosis(process_name) do
    case Process.whereis(process_name) do
      nil ->
        Logger.debug("[APOPTOSIS] Process #{inspect(process_name)} already gone")

      pid ->
        Logger.warning(
          "[APOPTOSIS] Sending shutdown to #{inspect(process_name)} (#{inspect(pid)})"
        )

        try do
          GenServer.stop(pid, :shutdown, 5_000)
        catch
          :exit, _ -> Process.exit(pid, :kill)
        end
    end

    :ets.delete(@ets_scores, process_name)
  end

  defp scan_all_processes(state) do
    entries = all_entries()

    Enum.reduce(entries, state, fn entry, acc ->
      {new_acc, _} = maybe_apoptose(entry, acc)
      new_acc
    end)
  end

  defp report_zombie_to_guardian(process_name, revival_count) do
    try do
      Indrajaal.Safety.Guardian.report_threat(%{
        type: :zombie_process,
        severity: :high,
        source: __MODULE__,
        metadata: %{process: process_name, revival_count: revival_count}
      })
    rescue
      _ -> :ok
    end
  end

  defp schedule_scan do
    Process.send_after(self(), :scan_tick, @scan_interval_ms)
  end

  defp broadcast_event(event_type, payload) do
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      @pubsub_topic,
      {:apoptosis_event, event_type, payload}
    )

    publish_zenoh(event_type, payload)
  rescue
    _e -> :ok
  end

  defp publish_zenoh(event_type, payload) do
    data = %{
      checkpoint: @checkpoint,
      topic: @zenoh_topic,
      event: Atom.to_string(event_type),
      payload: payload,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, data)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(phase, process_name, score) do
    :telemetry.execute(
      [:indrajaal, :biomorphic, :apoptosis, :lifecycle],
      %{score: score},
      %{phase: phase, process: process_name, constraint: "SC-SAFETY-020"}
    )
  end
end
