defmodule Indrajaal.Cybernetic.Inference.ActiveInferenceServer do
  @moduledoc """
  GenServer wrapper that runs periodic FEP (Free Energy Principle) cycles.

  WHAT: Wraps `ActiveInference` with a 30-second periodic execution loop,
        collecting live system metrics from Sentinel and publishing results
        to Zenoh for real-time observability.

  WHY:  GAP-P2-001 — the pure-functional `ActiveInference` module lacked a
        runtime driver. This server closes the gap, satisfying SC-MATH-004
        (ISOLATED → ACTIVE discipline) and SC-AI-002 (periodic belief update).

  ## STAMP Compliance
  - SC-MATH-004: ActiveInference discipline is now CONNECTED (runtime caller present)
  - SC-AI-002:   Tricameral AI coordination — periodic belief updates feed Sentinel

  ## Architecture
  - Runs a `:fep_cycle` message every 30 seconds.
  - Collects metrics via `Sentinel.health_status/0` (try/rescue — never crashes).
  - Calls `ActiveInference.infer_system_state/1` with those metrics.
  - Publishes result to `indrajaal/inference/fep` via Zenoh (async, non-blocking).
  - Emits `[:indrajaal, :inference, :periodic]` telemetry.
  - Writes `[ZTEST-CHECKPOINT]` log fallback per SC-ZTEST-008.
  """

  use GenServer

  require Logger

  alias Indrajaal.Cybernetic.Inference.ActiveInference

  @name __MODULE__
  @interval_ms 30_000
  @zenoh_topic "indrajaal/inference/fep"
  @checkpoint "CP-INFERENCE-01"

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc "Returns the current inference state snapshot held by the server."
  @spec get_state() :: map()
  def get_state do
    GenServer.call(@name, :get_state)
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    schedule_cycle()

    state = %{
      last_result: nil,
      last_run_at: nil,
      cycle_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_info(:fep_cycle, state) do
    new_state = run_fep_cycle(state)
    schedule_cycle()
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp schedule_cycle do
    Process.send_after(self(), :fep_cycle, @interval_ms)
  end

  defp run_fep_cycle(state) do
    start_us = System.monotonic_time(:microsecond)

    metrics = collect_metrics()

    result =
      case ActiveInference.infer_system_state(metrics) do
        {:ok, r} -> r
        {:error, reason} -> %{error: reason, most_likely_state: :unknown}
      end

    duration_us = System.monotonic_time(:microsecond) - start_us

    publish_result(result, duration_us)
    emit_telemetry(result, duration_us, state.cycle_count + 1)
    log_checkpoint(result, duration_us)

    %{
      state
      | last_result: result,
        last_run_at: DateTime.utc_now(),
        cycle_count: state.cycle_count + 1
    }
  end

  defp collect_metrics do
    try do
      case Indrajaal.Safety.Sentinel.assess_now() do
        {:ok, status} when is_map(status) -> status
        status when is_map(status) -> status
        _ -> %{}
      end
    rescue
      _ -> %{}
    end
  end

  defp publish_result(result, duration_us) do
    payload =
      Map.merge(result, %{
        checkpoint: @checkpoint,
        topic: @zenoh_topic,
        duration_us: duration_us,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    try do
      Indrajaal.Observability.ZenohPublisher.publish_async(@zenoh_topic, payload)
    rescue
      _ -> :ok
    end
  end

  defp emit_telemetry(result, duration_us, cycle_count) do
    :telemetry.execute(
      [:indrajaal, :inference, :periodic],
      %{duration_us: duration_us, free_energy: Map.get(result, :free_energy, 0.0)},
      %{
        cycle_count: cycle_count,
        most_likely_state: Map.get(result, :most_likely_state, :unknown)
      }
    )
  end

  defp log_checkpoint(result, duration_us) do
    state_str = Map.get(result, :most_likely_state, :unknown)
    fe_str = result |> Map.get(:free_energy, 0.0) |> Float.round(4)

    Logger.info(
      "[ZTEST-CHECKPOINT] checkpoint=#{@checkpoint} topic=#{@zenoh_topic} " <>
        "most_likely_state=#{state_str} free_energy=#{fe_str} duration_us=#{duration_us} " <>
        "timestamp=#{DateTime.utc_now() |> DateTime.to_iso8601()}"
    )
  end
end
