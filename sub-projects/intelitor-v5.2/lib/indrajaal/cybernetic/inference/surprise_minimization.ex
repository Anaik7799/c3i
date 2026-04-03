defmodule Indrajaal.Cybernetic.Inference.SurpriseMinimization do
  @moduledoc """
  [AGENT_RECREATION_GENOME]
  Purpose: Active Inference reflex for "Surprise" reduction.
  Function: Measures prediction error between AI hypotheses and sensor reality.
  STAMP: SC-DRIFT-002, T22.1.4
  Recovery:
  - Supervisor: `Indrajaal.Cortex.Supervisor`
  - Logic: Calculates variational free energy (simplified as squared error).
  - Verification: Triggers 'recalibrate' signal to Cortex if error > 0.1.
  [/AGENT_RECREATION_GENOME]
  """
  use GenServer
  require Logger

  @surprise_threshold 0.1

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("[Cortex] Surprise Minimization reflex active (SC-DRIFT-002).")
    {:ok, %{last_surprise: 0.0, prediction_errors: []}}
  end

  # --- Public API ---

  @doc "Observe reality and compare against hypothesis"
  def observe(hypothesis, reality) do
    GenServer.cast(__MODULE__, {:observe, hypothesis, reality})
  end

  # --- Callbacks ---

  @impl true
  def handle_cast({:observe, hypothesis, reality}, state) do
    # Simplified Variational Free Energy calculation
    # error = (Reality - Hypothesis)^2
    error = compute_prediction_error(hypothesis, reality)

    new_state =
      if error > @surprise_threshold do
        trigger_recalibration(error, state)
      else
        %{state | last_surprise: error}
      end

    {:noreply, new_state}
  end

  defp compute_prediction_error(h, r) when is_number(h) and is_number(r) do
    :math.pow(r - h, 2)
  end

  defp compute_prediction_error(_, _), do: 0.0

  defp trigger_recalibration(error, state) do
    Logger.warning("[Cortex] HIGH SURPRISE DETECTED: #{error}. Triggering recalibration.")

    # ZUIP: Publish surprise event to Zenoh
    if Code.ensure_loaded?(Indrajaal.Observability.ZenohNeuralStream) do
      Indrajaal.Observability.ZenohNeuralStream.stream_state(
        :cortex,
        :high_surprise,
        %{error: error, timestamp: DateTime.utc_now()}
      )
    end

    %{
      state
      | last_surprise: error,
        prediction_errors: [error | state.prediction_errors] |> Enum.take(10)
    }
  end
end
