defmodule Indrajaal.Cockpit.SafetyMonitor do
  @moduledoc """
  Safety Monitor for Cognitive Cockpit - Kino Smart Cell Integration.

  WHAT: Real-time visualization of Safety Envelope and Guardian status.
  WHY: SC-HITL-002 requires continuous safety visibility.
  CONSTRAINTS: Updates must not block main system operation.

  ## Kino Integration

  This module provides helper functions for creating Kino Smart Cells
  in Livebook that display real-time safety information:

  ```elixir
  # In Livebook
  SafetyMonitor.render_envelope_gauge()
  SafetyMonitor.render_guardian_status()
  SafetyMonitor.render_dms_heartbeat()
  ```

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-26 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HITL-002 |
  """

  alias Indrajaal.Safety.{Guardian, Envelope, DeadMansSwitch}

  # ============================================================
  # KINO SMART CELL HELPERS
  # ============================================================

  @doc """
  Render a comprehensive safety dashboard frame.
  Returns VegaLite spec for safety envelope visualization.
  """
  @spec envelope_vegalite_spec() :: map()
  def envelope_vegalite_spec do
    constraints = Envelope.all_constraints()
    current = current_resource_usage()

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "title" => "Safety Envelope - Resource Utilization",
      "width" => 400,
      "height" => 200,
      "layer" => [
        %{
          "data" => %{
            "values" => [
              %{
                "resource" => "FLAME Nodes",
                "current" => current.flame_nodes,
                "max" => constraints.resource.max_flame_nodes,
                "percent" =>
                  safe_percent(current.flame_nodes, constraints.resource.max_flame_nodes)
              },
              %{
                "resource" => "RAM (GB)",
                "current" => div(current.ram_mb, 1024),
                "max" => div(constraints.resource.max_ram_mb, 1024),
                "percent" => safe_percent(current.ram_mb, constraints.resource.max_ram_mb)
              },
              %{
                "resource" => "CPU %",
                "current" => current.cpu_percent,
                "max" => constraints.resource.max_cpu_percent,
                "percent" =>
                  safe_percent(current.cpu_percent, constraints.resource.max_cpu_percent)
              }
            ]
          },
          "mark" => %{"type" => "bar", "cornerRadiusEnd" => 4},
          "encoding" => %{
            "x" => %{
              "field" => "percent",
              "type" => "quantitative",
              "scale" => %{"domain" => [0, 100]}
            },
            "y" => %{"field" => "resource", "type" => "nominal"},
            "color" => %{
              "field" => "percent",
              "type" => "quantitative",
              "scale" => %{
                "domain" => [0, 70, 90, 100],
                "range" => ["#22c55e", "#eab308", "#f97316", "#ef4444"]
              }
            }
          }
        },
        %{
          "mark" => %{
            "type" => "rule",
            "color" => "red",
            "strokeWidth" => 2,
            "strokeDash" => [4, 4]
          },
          "encoding" => %{
            "x" => %{"datum" => 90}
          }
        }
      ]
    }
  end

  @doc """
  Render guardian status as a Kino-compatible data structure.
  """
  @spec guardian_status_data() :: map()
  def guardian_status_data do
    status = Guardian.status()

    %{
      status: if(status[:running], do: :running, else: :stopped),
      validations: status[:validations] || 0,
      violations: status[:violations] || 0,
      uptime: format_uptime(status[:uptime_seconds] || 0),
      last_violation: format_violation(status[:last_violation]),
      health_indicator: calculate_health_indicator(status)
    }
  end

  @doc """
  Render Dead Man's Switch heartbeat status.
  """
  @spec dms_heartbeat_data() :: map()
  def dms_heartbeat_data do
    state = DeadMansSwitch.state()
    stats = DeadMansSwitch.stats()

    %{
      state: state,
      state_display: format_dms_state(state),
      heartbeats: stats.heartbeats_received,
      missed: stats.heartbeats_missed,
      failsafes: stats.failsafe_triggers,
      current_sequence: Map.get(stats, :current_sequence, 0),
      last_heartbeat: format_timestamp(stats.last_heartbeat),
      health: dms_health_level(state, stats)
    }
  end

  @doc """
  Get combined safety score (0-100).
  """
  @spec safety_score() :: integer()
  def safety_score do
    guardian = Guardian.status()
    dms = DeadMansSwitch.state()
    envelope = Envelope.health_check(current_metrics())

    scores = []

    # Guardian score (30 points max)
    guardian_score =
      cond do
        not guardian[:running] -> 0
        guardian[:violations] > 10 -> 10
        guardian[:violations] > 5 -> 20
        guardian[:violations] > 0 -> 25
        true -> 30
      end

    scores = [guardian_score | scores]

    # DMS score (30 points max)
    dms_score =
      case dms do
        :healthy -> 30
        :armed -> 25
        :warning -> 15
        :disabled -> 20
        :failsafe_triggered -> 0
        _ -> 10
      end

    scores = [dms_score | scores]

    # Envelope score (40 points max)
    envelope_score = if envelope.healthy, do: 40, else: 40 - length(envelope.violations) * 10

    scores = [max(0, envelope_score) | scores]

    Enum.sum(scores)
  end

  @doc """
  Get safety alerts that need attention.
  """
  @spec safety_alerts() :: list(map())
  def safety_alerts do
    alerts = []

    # Check Guardian
    guardian = Guardian.status()

    alerts =
      if guardian[:running] do
        alerts
      else
        [
          %{
            level: :critical,
            component: :guardian,
            message: "Guardian is not running!",
            action: "Start Guardian immediately"
          }
          | alerts
        ]
      end

    alerts =
      if guardian[:violations] && guardian[:violations] > 0 do
        [
          %{
            level: :warning,
            component: :guardian,
            message: "#{guardian[:violations]} safety violations detected",
            action: "Review violation log"
          }
          | alerts
        ]
      else
        alerts
      end

    # Check DMS
    dms_state = DeadMansSwitch.state()

    alerts =
      case dms_state do
        :failsafe_triggered ->
          [
            %{
              level: :critical,
              component: :dead_mans_switch,
              message: "FAILSAFE TRIGGERED",
              action: "Immediate intervention required"
            }
            | alerts
          ]

        :warning ->
          [
            %{
              level: :warning,
              component: :dead_mans_switch,
              message: "Heartbeat warning - missed beats detected",
              action: "Check Cortex health"
            }
            | alerts
          ]

        _ ->
          alerts
      end

    # Check Envelope
    envelope = Envelope.health_check(current_metrics())

    alerts =
      if envelope.healthy do
        alerts
      else
        [
          %{
            level: :critical,
            component: :envelope,
            message: "Safety envelope violations: #{length(envelope.violations)}",
            action: "Reduce resource usage"
          }
          | alerts
        ]
      end

    Enum.sort_by(alerts, fn a -> if a.level == :critical, do: 0, else: 1 end)
  end

  @doc """
  Generate a timeline of recent safety events.
  """
  @spec safety_timeline(integer()) :: list(map())
  def safety_timeline(limit \\ 10) do
    # In a real implementation, this would query a safety event log
    # For now, generate based on current state
    events = []

    guardian = Guardian.status()

    events =
      if guardian[:last_violation] do
        [
          %{
            timestamp: guardian[:last_violation][:timestamp],
            event: :violation,
            component: :guardian,
            details: guardian[:last_violation][:reason]
          }
          | events
        ]
      else
        events
      end

    dms_stats = DeadMansSwitch.stats()

    events =
      if dms_stats.failsafe_triggers > 0 do
        [
          %{
            timestamp: DateTime.utc_now(),
            event: :failsafe,
            component: :dead_mans_switch,
            details: "Failsafe triggered #{dms_stats.failsafe_triggers} times"
          }
          | events
        ]
      else
        events
      end

    events
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(limit)
  end

  # ============================================================
  # PRIVATE HELPERS
  # ============================================================

  defp current_resource_usage do
    %{
      flame_nodes: get_flame_node_count(),
      ram_mb: div(:erlang.memory(:total), 1_048_576),
      cpu_percent: get_cpu_percent()
    }
  end

  defp current_metrics do
    usage = current_resource_usage()

    %{
      flame_nodes: usage.flame_nodes,
      ram_mb: usage.ram_mb,
      cpu_percent: usage.cpu_percent
    }
  end

  defp get_flame_node_count do
    # Would query FLAME supervisor
    0
  end

  defp get_cpu_percent do
    case :erlang.statistics(:scheduler_wall_time) do
      :undefined ->
        0

      wall_times when is_list(wall_times) ->
        {active, total} =
          Enum.reduce(wall_times, {0, 0}, fn {_id, a, t}, {acc_a, acc_t} ->
            {acc_a + a, acc_t + t}
          end)

        if total > 0, do: round(active / total * 100), else: 0
    end
  rescue
    _ -> 0
  end

  defp safe_percent(current, max) when max > 0 do
    min(100, round(current / max * 100))
  end

  defp safe_percent(_, _), do: 0

  defp format_uptime(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_uptime(seconds) when seconds < 3600, do: "#{div(seconds, 60)}m #{rem(seconds, 60)}s"

  defp format_uptime(seconds) do
    hours = div(seconds, 3600)
    mins = div(rem(seconds, 3600), 60)
    "#{hours}h #{mins}m"
  end

  defp format_violation(nil), do: "None"

  defp format_violation(%{reason: reason, timestamp: ts}) do
    "#{reason} at #{Calendar.strftime(ts, "%H:%M:%S")}"
  end

  defp format_violation(_), do: "Unknown"

  defp format_timestamp(nil), do: "Never"

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M:%S.%f")
  end

  defp format_timestamp(_), do: "Unknown"

  defp format_dms_state(:healthy), do: "Healthy"
  defp format_dms_state(:armed), do: "Armed"
  defp format_dms_state(:warning), do: "Warning"
  defp format_dms_state(:failsafe_triggered), do: "FAILSAFE"
  defp format_dms_state(:disabled), do: "Disabled"
  defp format_dms_state(state), do: to_string(state)

  defp calculate_health_indicator(status) do
    cond do
      not status[:running] -> :critical
      status[:violations] > 5 -> :warning
      status[:violations] > 0 -> :info
      true -> :healthy
    end
  end

  defp dms_health_level(state, stats) do
    cond do
      state == :failsafe_triggered -> :critical
      state == :warning -> :warning
      stats.heartbeats_missed > 2 -> :warning
      state in [:healthy, :armed] -> :healthy
      state == :disabled -> :info
      true -> :unknown
    end
  end
end
