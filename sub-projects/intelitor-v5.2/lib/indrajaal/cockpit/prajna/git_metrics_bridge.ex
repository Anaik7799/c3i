defmodule Indrajaal.Cockpit.Prajna.GitMetricsBridge do
  @moduledoc """
  Bridges Git Intelligence ETS data into Prajna SmartMetrics.

  WHAT: Periodically reads Git Health Score and biomorphic health from
        the GitZenohSubscriber ETS cache and records them as SmartMetrics,
        making git health visible in the Prajna health score computation.

  WHY: SmartMetrics is the central aggregation point for Prajna's health
       score. Without this bridge, git intelligence data flows through
       Zenoh and ETS but never reaches the SmartMetrics health_summary/0.

  CONSTRAINTS:
    - SC-BRIDGE-003: Latency budget 50ms
    - SC-HMI-002: Trend vectors MUST be displayed
    - SC-PRF-050: Metric updates < 50ms latency
  """

  use GenServer
  require Logger

  alias Indrajaal.Cockpit.Prajna.SmartMetrics
  alias Indrajaal.Observability.GitIntegration.GitZenohSubscriber

  @sync_interval_ms 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    if connected_to_pubsub?() do
      Phoenix.PubSub.subscribe(Indrajaal.PubSub, "git_intelligence:health")
    end

    schedule_sync()

    Logger.info(
      "[GitMetricsBridge] Started — syncing git health to SmartMetrics every #{@sync_interval_ms}ms"
    )

    {:ok, %{syncs: 0}}
  end

  @impl true
  def handle_info(:sync, state) do
    sync_git_metrics()
    schedule_sync()
    {:noreply, %{state | syncs: state.syncs + 1}}
  end

  # React to PubSub health updates immediately
  @impl true
  def handle_info({:git_intelligence_health, health_data}, state) do
    record_health_metrics(health_data)
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  defp sync_git_metrics do
    metrics = safe_get_metrics()

    if map_size(metrics) > 0 do
      if ghs = metrics[:ghs] do
        SmartMetrics.record("git.health_score", "Git Health Score", ghs * 100,
          unit: "%",
          thresholds: %{advisory: 85, caution: 70, warning: 50, critical: 30}
        )
      end

      if adoption = metrics[:icp_adoption] do
        SmartMetrics.record("git.icp_adoption", "ICP v2.0 Adoption", adoption * 100,
          unit: "%",
          thresholds: %{advisory: 90, caution: 75, warning: 50, critical: 25}
        )
      end

      if bio = metrics[:biomorphic_health] do
        if is_map(bio) do
          for {subsystem, score} <- bio, is_number(score) do
            SmartMetrics.record(
              "git.bio.#{subsystem}",
              "Git #{String.capitalize(to_string(subsystem))}",
              normalize_score(score) * 100,
              unit: "%"
            )
          end
        end
      end

      if threat = metrics[:threat_level] do
        threat_num = threat_to_number(threat)

        SmartMetrics.record("git.threat_level", "Git Threat Level", threat_num,
          unit: "level",
          thresholds: %{advisory: 2, caution: 3, warning: 4, critical: 5}
        )
      end
    end
  end

  defp record_health_metrics(data) when is_map(data) do
    if ghs = data["ghs"] || data[:ghs] do
      SmartMetrics.record("git.health_score", "Git Health Score", ghs * 100,
        unit: "%",
        thresholds: %{advisory: 85, caution: 70, warning: 50, critical: 30}
      )
    end
  end

  defp record_health_metrics(_), do: :ok

  defp safe_get_metrics do
    try do
      GitZenohSubscriber.get_metrics()
    rescue
      _ -> %{}
    catch
      :exit, _ -> %{}
    end
  end

  defp normalize_score(score) when is_float(score) and score <= 1.0, do: score
  defp normalize_score(score) when is_float(score), do: score / 100.0
  defp normalize_score(score) when is_integer(score) and score <= 100, do: score / 100.0
  defp normalize_score(_), do: 0.0

  defp threat_to_number("none"), do: 0
  defp threat_to_number("low"), do: 1
  defp threat_to_number("medium"), do: 2
  defp threat_to_number("high"), do: 3
  defp threat_to_number("critical"), do: 4
  defp threat_to_number("emergency"), do: 5
  defp threat_to_number(_), do: 0

  defp schedule_sync do
    Process.send_after(self(), :sync, @sync_interval_ms)
  end

  defp connected_to_pubsub? do
    case Process.whereis(Indrajaal.PubSub) do
      nil -> false
      _pid -> true
    end
  end
end
