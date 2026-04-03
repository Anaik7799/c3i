defmodule Indrajaal.Substrate.L1.ReflexArc do
  @moduledoc """
  ## Design Intent
  L1 substrate reflex arc — implements a configurable stimulus→response arc.
  When a stimulus arrives, the arc evaluates whether it crosses the threshold
  and schedules a response after a configurable latency. Responses are
  published to PubSub and dispatched to a registered handler function.

  Reflex model:
    - Stimulus arrives via `stimulate/2`
    - Intensity compared against `threshold` (default 0.5)
    - Sub-threshold stimuli increment fatigue counter but do not fire
    - Supra-threshold stimuli fire a response after `latency_ms` (default 50)
    - Refractory period prevents re-firing within `refractory_ms` (default 200)
    - Response count and last_fired tracked in state

  ## STAMP Constraints
  - SC-BIO-001: Biomorphic substrate layer L1 — ENFORCED
  - SC-VER-041: OODA cycle < 100ms — latency default satisfies — ENFORCED
  - SC-FUNC-001: System must compile at all times — ENFORCED

  ## Change History
  | Version | Date       | Author  | Change               |
  |---------|------------|---------|----------------------|
  | 21.3.1  | 2026-03-28 | Claude  | Initial morphogenesis |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "substrate:reflex_arc"

  @default_threshold 0.5
  @default_latency_ms 50
  @default_refractory_ms 200

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
  end

  @doc """
  Deliver a stimulus with intensity in [0.0, 1.0] and optional metadata.
  Returns `:fired`, `:sub_threshold`, or `:refractory`.
  """
  @spec stimulate(float(), map()) :: :fired | :sub_threshold | :refractory
  def stimulate(intensity, metadata \\ %{})
      when is_float(intensity) and intensity >= 0.0 and intensity <= 1.0 do
    GenServer.call(@name, {:stimulate, intensity, metadata})
  end

  @doc "Returns current arc state summary."
  @spec status() :: map()
  def status do
    GenServer.call(@name, :status)
  end

  @doc "Update the intensity threshold."
  @spec set_threshold(float()) :: :ok
  def set_threshold(threshold)
      when is_float(threshold) and threshold >= 0.0 and threshold <= 1.0 do
    GenServer.call(@name, {:set_threshold, threshold})
  end

  @doc "Register a response handler function `(map() -> any())`."
  @spec register_handler(function()) :: :ok
  def register_handler(fun) when is_function(fun, 1) do
    GenServer.call(@name, {:register_handler, fun})
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    state = %{
      threshold: Keyword.get(opts, :threshold, @default_threshold),
      latency_ms: Keyword.get(opts, :latency_ms, @default_latency_ms),
      refractory_ms: Keyword.get(opts, :refractory_ms, @default_refractory_ms),
      handler: Keyword.get(opts, :handler, nil),
      response_count: 0,
      fatigue_count: 0,
      last_fired_at: nil,
      last_stimulus_at: nil
    }

    Logger.info(
      "[REFLEX_ARC] started — threshold=#{state.threshold} latency=#{state.latency_ms}ms"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:stimulate, intensity, metadata}, _from, state) do
    now_ms = System.monotonic_time(:millisecond)

    cond do
      in_refractory_period?(state, now_ms) ->
        {:reply, :refractory, %{state | last_stimulus_at: now_ms}}

      intensity < state.threshold ->
        {:reply, :sub_threshold,
         %{state | fatigue_count: state.fatigue_count + 1, last_stimulus_at: now_ms}}

      true ->
        # Schedule response after latency
        stimulus_data = Map.merge(metadata, %{intensity: intensity, stimulus_time: now_ms})
        Process.send_after(self(), {:fire_response, stimulus_data}, state.latency_ms)
        {:reply, :fired, %{state | last_stimulus_at: now_ms}}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply,
     %{
       threshold: state.threshold,
       latency_ms: state.latency_ms,
       refractory_ms: state.refractory_ms,
       response_count: state.response_count,
       fatigue_count: state.fatigue_count,
       last_fired_at: state.last_fired_at
     }, state}
  end

  @impl true
  def handle_call({:set_threshold, threshold}, _from, state) do
    {:reply, :ok, %{state | threshold: threshold}}
  end

  @impl true
  def handle_call({:register_handler, fun}, _from, state) do
    {:reply, :ok, %{state | handler: fun}}
  end

  @impl true
  def handle_info({:fire_response, stimulus_data}, state) do
    now_ms = System.monotonic_time(:millisecond)

    response = %{
      stimulus: stimulus_data,
      response_time_ms: now_ms,
      latency_ms: now_ms - Map.get(stimulus_data, :stimulus_time, now_ms),
      arc: __MODULE__
    }

    # Invoke optional registered handler
    if state.handler, do: state.handler.(response)

    # Broadcast to PubSub
    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:reflex_response, response})

    Logger.debug(
      "[REFLEX_ARC] fired response=#{state.response_count + 1} latency=#{response.latency_ms}ms"
    )

    {:noreply, %{state | response_count: state.response_count + 1, last_fired_at: now_ms}}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec in_refractory_period?(map(), integer()) :: boolean()
  defp in_refractory_period?(%{last_fired_at: nil}, _now), do: false

  defp in_refractory_period?(%{last_fired_at: last, refractory_ms: ref}, now) do
    now - last < ref
  end
end
