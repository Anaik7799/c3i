defmodule Indrajaal.Cockpit.Prajna.AnalyticsIntegration do
  @moduledoc """
  Analytics Domain Integration for Prajna Cockpit.

  Provides real-time visibility into incident prediction, model accuracy,
  and trend analysis metrics.

  ## STAMP Constraints
  - SC-PRAJNA-004: All domain metrics via Zenoh/Telemetry
  - SC-ANA-INTEG-001: Real-time trend analysis synchronization
  """

  use GenServer
  require Logger

  alias Indrajaal.Analytics.PredictiveAnalytics
  alias Indrajaal.Observability.ZenohCoordinator

  @sync_interval_ms 30_000

  defstruct [
    :prediction_stats,
    :risk_score,
    :trend_strength,
    :last_sync
  ]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current analytics integration status.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    state = %__MODULE__{
      prediction_stats: %{accuracy: 0.0},
      risk_score: 0.0,
      trend_strength: %{},
      last_sync: nil
    }

    # Schedule periodic sync
    schedule_sync()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, {:ok, state}, state}
  end

  @impl true
  def handle_info(:sync_metrics, state) do
    # 1. Fetch performance prediction stats
    prediction = PredictiveAnalytics.predict_performance(%{}, 24)

    # 2. Fetch trend analysis
    trends = PredictiveAnalytics.analyze_trends(%{})

    # 3. Fetch risk assessment
    risks = PredictiveAnalytics.assess_risks(%{})

    # 4. Publish to Zenoh
    ZenohCoordinator.publish("indrajaal/control/analytics", %{
      prediction: prediction.model_accuracy,
      trends: trends.trend_strength,
      risk: risks.overall_risk_score,
      timestamp: DateTime.utc_now()
    })

    # 5. Emit telemetry
    :telemetry.execute(
      [:indrajaal, :prajna, :analytics, :sync],
      %{prediction_accuracy: prediction.model_accuracy.accuracy},
      %{risk_score: risks.overall_risk_score}
    )

    new_state = %{
      state
      | prediction_stats: prediction.model_accuracy,
        risk_score: risks.overall_risk_score,
        trend_strength: trends.trend_strength,
        last_sync: DateTime.utc_now()
    }

    schedule_sync()

    {:noreply, new_state}
  end

  # Private Functions

  defp schedule_sync do
    Process.send_after(self(), :sync_metrics, @sync_interval_ms)
  end
end
