defmodule Indrajaal.Cockpit.Prajna.Domain do
  @moduledoc """
  PRAJNA C3I Mesh Cockpit - Domain Types

  WHAT: Safety-Critical Domain Types for Distributed Control Interface
        implementing NASA-STD-3000, NUREG-0700, and MIL-STD-1472H standards.

  WHY: The "Dark Cockpit" philosophy reduces cognitive load by only highlighting
       deviations from normal. Smart Metrics provide trend awareness and staleness
       detection for safety-critical decision making.

  CONSTRAINTS:
    - SC-HMI-001: Dark Cockpit philosophy (gray/blue default, amber/red deviations)
    - SC-HMI-002: Trend vectors displayed for predictive awareness
    - SC-HMI-003: Staleness detection (5-second watchdog)
    - SC-HMI-004: Two-step commit for critical commands

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-27 |
  | Author | Cybernetic Architect |
  | STAMP | SC-HMI-001 to SC-HMI-004, SC-C3I-001 to SC-C3I-004 |
  """

  # ═══════════════════════════════════════════════════════════════════════════
  # TREND VECTORS - Shows where the data is GOING, not just where it IS
  # ═══════════════════════════════════════════════════════════════════════════

  @type trend :: :rising | :rising_fast | :falling | :falling_fast | :stable

  @doc "Trend icons for visual representation (NUREG-0700 compliant)"
  def trend_icon(:rising), do: "↑"
  def trend_icon(:rising_fast), do: "↑↑"
  def trend_icon(:falling), do: "↓"
  def trend_icon(:falling_fast), do: "↓↓"
  def trend_icon(:stable), do: "→"

  # ═══════════════════════════════════════════════════════════════════════════
  # CONNECTION STATUS with Staleness Detection
  # ═══════════════════════════════════════════════════════════════════════════

  @type conn_status :: :connected | :stale | :degraded | :disconnected

  @doc "Status icons (analog indicators per NUREG-0700)"
  def status_icon(:connected), do: "●"
  def status_icon(:stale), do: "◐"
  def status_icon(:degraded), do: "◐"
  def status_icon(:disconnected), do: "○"

  # ═══════════════════════════════════════════════════════════════════════════
  # ALARM LEVELS - Dark Cockpit Philosophy
  # ═══════════════════════════════════════════════════════════════════════════

  @type alarm_level :: :normal | :advisory | :caution | :warning | :critical

  @doc "Alarm icons (safety-critical symbology)"
  def alarm_icon(:normal), do: "·"
  def alarm_icon(:advisory), do: "ℹ"
  def alarm_icon(:caution), do: "⚠"
  def alarm_icon(:warning), do: "⛔"
  def alarm_icon(:critical), do: "☢"

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMAND STATE for Two-Step Commit (SC-HMI-004)
  # ═══════════════════════════════════════════════════════════════════════════

  @type command_state :: :idle | :armed | :executing | :acknowledged | :failed

  def command_icon(:idle), do: "○"
  def command_icon(:armed), do: "◎"
  def command_icon(:executing), do: "●"
  def command_icon(:acknowledged), do: "✓"
  def command_icon(:failed), do: "✗"

  # ═══════════════════════════════════════════════════════════════════════════
  # NODE ROLE in the Mesh
  # ═══════════════════════════════════════════════════════════════════════════

  @type node_role :: :supervisor | :controller | :worker | :observer | :gateway

  # ═══════════════════════════════════════════════════════════════════════════
  # AI INSIGHT TYPES
  # ═══════════════════════════════════════════════════════════════════════════

  @type insight_type ::
          :anomaly | :prediction | :recommendation | :correlation | :root_cause | :summary

  # ═══════════════════════════════════════════════════════════════════════════
  # VIEW MODES
  # ═══════════════════════════════════════════════════════════════════════════

  @type view_mode ::
          :overview
          | :mesh
          | :alarms
          | :commands
          | :ai
          | :dashboard
          | :node_detail
          | :alarm_center
          | :topology
          | :timeline
          | :ai_assistant

  # ═══════════════════════════════════════════════════════════════════════════
  # SMART METRIC - More Than Just a Number
  # ═══════════════════════════════════════════════════════════════════════════

  @type smart_metric :: %{
          value: number(),
          previous_value: number() | nil,
          last_updated: DateTime.t(),
          trend: trend(),
          level: alarm_level(),
          thresholds: thresholds() | nil,
          unit: String.t(),
          label: String.t(),
          sparkline: list(float())
        }

  @type thresholds :: %{
          advisory_low: number() | nil,
          advisory_high: number() | nil,
          caution_low: number() | nil,
          caution_high: number() | nil,
          warning_low: number() | nil,
          warning_high: number() | nil
        }

  @doc "Create a new smart metric with defaults"
  @spec create_metric(String.t(), String.t(), number()) :: smart_metric()
  def create_metric(label, unit, value) do
    %{
      value: value,
      previous_value: nil,
      last_updated: DateTime.utc_now(),
      trend: :stable,
      level: :normal,
      thresholds: nil,
      unit: unit,
      label: label,
      sparkline: []
    }
  end

  @doc "Create a smart metric (alias for create_metric with keyword opts)"
  @spec create_smart_metric(String.t(), number(), keyword()) :: smart_metric()
  def create_smart_metric(label, value, opts \\ []) do
    unit = Keyword.get(opts, :unit, "")
    thresholds = Keyword.get(opts, :thresholds, nil)

    metric = create_metric(label, unit, value)
    level = evaluate_level(value, thresholds)

    %{metric | thresholds: thresholds, level: level}
  end

  @doc "Update a metric with staleness and trend detection"
  @spec update_metric(smart_metric(), number()) :: smart_metric()
  def update_metric(metric, new_value) do
    trend = compute_trend(metric.value, new_value)
    sparkline = [new_value | metric.sparkline] |> Enum.take(60)
    level = evaluate_level(new_value, metric.thresholds)

    %{
      metric
      | value: new_value,
        previous_value: metric.value,
        last_updated: DateTime.utc_now(),
        trend: trend,
        level: level,
        sparkline: sparkline
    }
  end

  @doc "Check if metric is stale (default > 5 seconds since last update)"
  @spec stale?(smart_metric(), integer()) :: boolean()
  def stale?(metric, timeout_seconds \\ 5) do
    DateTime.diff(DateTime.utc_now(), metric.last_updated, :second) > timeout_seconds
  end

  @doc "Evaluate alarm level based on thresholds"
  @spec evaluate_level(number(), thresholds() | nil) :: alarm_level()
  def evaluate_level(_value, nil), do: :normal

  def evaluate_level(value, thresholds) do
    cond do
      Map.get(thresholds, :warning_high) && value >= thresholds.warning_high -> :warning
      Map.get(thresholds, :warning_low) && value <= thresholds.warning_low -> :warning
      Map.get(thresholds, :caution_high) && value >= thresholds.caution_high -> :caution
      Map.get(thresholds, :caution_low) && value <= thresholds.caution_low -> :caution
      Map.get(thresholds, :advisory_high) && value >= thresholds.advisory_high -> :advisory
      Map.get(thresholds, :advisory_low) && value <= thresholds.advisory_low -> :advisory
      true -> :normal
    end
  end

  @doc "Get staleness in seconds"
  @spec staleness_seconds(smart_metric()) :: integer()
  def staleness_seconds(metric) do
    DateTime.diff(DateTime.utc_now(), metric.last_updated, :second)
  end

  defp compute_trend(old_value, new_value) when is_number(old_value) and is_number(new_value) do
    diff = new_value - old_value
    percent_change = if old_value != 0, do: abs(diff / old_value) * 100, else: 0

    cond do
      diff > 0 and percent_change > 10 -> :rising_fast
      diff > 0 -> :rising
      diff < 0 and percent_change > 10 -> :falling_fast
      diff < 0 -> :falling
      true -> :stable
    end
  end

  defp compute_trend(_, _), do: :stable

  # ═══════════════════════════════════════════════════════════════════════════
  # MESH NODE - Entity in the Distributed Fabric
  # ═══════════════════════════════════════════════════════════════════════════

  @type mesh_node :: %{
          id: String.t(),
          name: String.t(),
          zone: String.t(),
          role: node_role(),
          status: conn_status(),
          cpu: smart_metric(),
          memory: smart_metric(),
          battery: smart_metric() | nil,
          network_latency: smart_metric(),
          capabilities: list(String.t()),
          health_score: smart_metric(),
          location: {float(), float()} | nil,
          ai_insight: String.t() | nil,
          ai_insight_updated_at: DateTime.t() | nil
        }

  @doc "Create a new mesh node with sensible defaults"
  @spec create_node(String.t(), String.t(), String.t(), node_role()) :: mesh_node()
  def create_node(id, name, zone, role) do
    %{
      id: id,
      name: name,
      zone: zone,
      role: role,
      status: :disconnected,
      cpu: create_metric("CPU", "%", 0.0),
      memory: create_metric("Memory", "%", 0.0),
      battery: nil,
      network_latency: create_metric("Latency", "ms", 0.0),
      capabilities: [],
      health_score: create_metric("Health", "%", 100),
      location: nil,
      ai_insight: nil,
      ai_insight_updated_at: nil
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ALARM - Safety-Critical Event Notifications
  # ═══════════════════════════════════════════════════════════════════════════

  @type alarm :: %{
          id: String.t(),
          node_id: String.t(),
          level: alarm_level(),
          category: String.t(),
          message: String.t(),
          details: String.t() | nil,
          occurred_at: DateTime.t(),
          acknowledged_at: DateTime.t() | nil,
          acknowledged_by: String.t() | nil,
          auto_clearable: boolean()
        }

  @doc "Create a new alarm"
  @spec create_alarm(String.t(), String.t(), alarm_level(), String.t(), String.t()) :: alarm()
  def create_alarm(id, node_id, level, category, message) do
    %{
      id: id,
      node_id: node_id,
      level: level,
      category: category,
      message: message,
      details: nil,
      occurred_at: DateTime.utc_now(),
      acknowledged_at: nil,
      acknowledged_by: nil,
      auto_clearable: false
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # COMMANDS - Control Plane with Two-Step Commit
  # ═══════════════════════════════════════════════════════════════════════════

  @type mesh_command ::
          :power_off
          | :power_on
          | :restart
          | :hibernate
          | :isolate_network
          | :resume_network
          | {:set_load_balancer, integer()}
          | :force_health_check
          | :clear_alarms
          | {:custom, String.t(), binary()}

  @type command_record :: %{
          id: String.t(),
          target_node_id: String.t(),
          command: mesh_command(),
          state: command_state(),
          armed_at: DateTime.t() | nil,
          executed_at: DateTime.t() | nil,
          acknowledged_at: DateTime.t() | nil,
          error_message: String.t() | nil,
          requires_confirmation: boolean()
        }

  @doc "Check if a command is critical (requires two-step commit)"
  @spec critical_command?(mesh_command()) :: boolean()
  def critical_command?(cmd) do
    cmd in [:power_off, :restart, :isolate_network, :hibernate, :shutdown]
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # AI INSIGHT - LLM-Generated Intelligence
  # ═══════════════════════════════════════════════════════════════════════════

  @type ai_insight :: %{
          id: String.t(),
          type: insight_type(),
          level: alarm_level(),
          title: String.t(),
          description: String.t(),
          related_nodes: list(String.t()),
          related_alarms: list(String.t()),
          confidence: float(),
          generated_at: DateTime.t(),
          expires_at: DateTime.t() | nil,
          action_items: list(String.t())
        }

  @doc "Create a new AI insight"
  @spec create_insight(insight_type(), alarm_level(), String.t(), String.t(), float()) ::
          ai_insight()
  def create_insight(type, level, title, description, confidence) do
    %{
      id: generate_id(),
      type: type,
      level: level,
      title: title,
      description: description,
      related_nodes: [],
      related_alarms: [],
      confidence: confidence,
      generated_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), 300, :second),
      action_items: []
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # COCKPIT STATE - The Complete Digital Twin
  # ═══════════════════════════════════════════════════════════════════════════

  @type cockpit_state :: %{
          operator_id: String.t(),
          session_id: String.t(),
          started_at: DateTime.t(),
          nodes: %{String.t() => mesh_node()},
          zones: %{String.t() => map()},
          alarms: %{String.t() => alarm()},
          pending_commands: %{String.t() => command_record()},
          command_history: list(command_record()),
          insights: list(ai_insight()),
          ai_enabled: boolean(),
          last_ai_update: DateTime.t() | nil,
          current_view: view_mode(),
          selected_node_id: String.t() | nil,
          selected_zone_id: String.t() | nil,
          filter_level: alarm_level() | nil,
          messages_received: integer(),
          last_message_at: DateTime.t() | nil,
          ui_refresh_rate: integer(),
          monitor_only: boolean(),
          simulation_mode: boolean()
        }

  @doc "Create initial cockpit state"
  @spec create_cockpit_state(String.t()) :: cockpit_state()
  def create_cockpit_state(operator_id) do
    %{
      operator_id: operator_id,
      session_id: generate_id(),
      started_at: DateTime.utc_now(),
      nodes: %{},
      zones: %{},
      alarms: %{},
      pending_commands: %{},
      command_history: [],
      insights: [],
      ai_enabled: true,
      last_ai_update: nil,
      current_view: :overview,
      selected_node_id: nil,
      selected_zone_id: nil,
      filter_level: nil,
      messages_received: 0,
      last_message_at: nil,
      ui_refresh_rate: 10,
      monitor_only: false,
      simulation_mode: false
    }
  end

  # ═══════════════════════════════════════════════════════════════════════════
  # ZENOH KEY SPACE
  # ═══════════════════════════════════════════════════════════════════════════

  @prefix "c3i"

  @doc "Telemetry key: c3i/units/{zone}/{id}/telemetry"
  def telemetry_key(zone, node_id), do: "#{@prefix}/units/#{zone}/#{node_id}/telemetry"

  @doc "Alarm key: c3i/alarms/{severity}/{id}"
  def alarm_key(severity, alarm_id), do: "#{@prefix}/alarms/#{severity}/#{alarm_id}"

  @doc "Control key: c3i/ctrl/{id}/{subsystem}/set"
  def control_key(node_id, subsystem), do: "#{@prefix}/ctrl/#{node_id}/#{subsystem}/set"

  @doc "Config key: c3i/config/{id}"
  def config_key(node_id), do: "#{@prefix}/config/#{node_id}"

  @doc "AI insight key: c3i/ai/insights/{type}"
  def ai_insight_key(insight_type), do: "#{@prefix}/ai/insights/#{insight_type}"

  @doc "Subscription pattern for all unit telemetry"
  def all_telemetry_pattern, do: "#{@prefix}/units/**"

  @doc "Subscription pattern for all alarms"
  def all_alarms_pattern, do: "#{@prefix}/alarms/**"

  # ═══════════════════════════════════════════════════════════════════════════
  # DISCRIMINABLE NAMING (SC-VDP-005: Discriminability Principle)
  # "zone-alpha.node-01" format for unambiguous identification
  # ═══════════════════════════════════════════════════════════════════════════

  @doc """
  Format a node ID with discriminable naming per SC-VDP-005.

  Instead of: "Node 1" (ambiguous)
  Use: "zone-alpha.node-01" (discriminable)

  Examples:
      iex> discriminable_name("app", "primary", 1)
      "primary.app-01"

      iex> discriminable_name("sensor", "zone-a", 42)
      "zone-a.sensor-42"
  """
  @spec discriminable_name(String.t(), String.t(), integer() | String.t()) :: String.t()
  def discriminable_name(type, zone, index) when is_integer(index) do
    "#{zone}.#{type}-#{String.pad_leading(to_string(index), 2, "0")}"
  end

  def discriminable_name(type, zone, id) when is_binary(id) do
    "#{zone}.#{type}-#{id}"
  end

  @doc """
  Parse a discriminable name back into components.

  Returns {:ok, %{zone: ..., type: ..., id: ...}} or {:error, :invalid_format}
  """
  @spec parse_discriminable_name(String.t()) :: {:ok, map()} | {:error, :invalid_format}
  def parse_discriminable_name(name) do
    case String.split(name, ".") do
      [zone, type_id] ->
        case String.split(type_id, "-", parts: 2) do
          [type, id] -> {:ok, %{zone: zone, type: type, id: id}}
          _ -> {:error, :invalid_format}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  @doc """
  Format a short discriminable display name (for constrained UI space).

  Truncates zone and uses abbreviated type indicators.
  """
  @spec short_name(String.t(), String.t(), integer()) :: String.t()
  def short_name(type, zone, index) do
    zone_abbrev = zone |> String.slice(0, 3) |> String.upcase()
    type_abbrev = type_abbreviation(type)
    "#{zone_abbrev}:#{type_abbrev}#{index}"
  end

  defp type_abbreviation("app"), do: "A"
  defp type_abbreviation("database"), do: "D"
  defp type_abbreviation("db"), do: "D"
  defp type_abbreviation("observability"), do: "O"
  defp type_abbreviation("obs"), do: "O"
  defp type_abbreviation("sensor"), do: "S"
  defp type_abbreviation("camera"), do: "C"
  defp type_abbreviation("gateway"), do: "G"
  defp type_abbreviation("controller"), do: "CTL"
  defp type_abbreviation("worker"), do: "W"
  defp type_abbreviation(type), do: String.upcase(String.slice(type, 0, 1))

  @doc """
  Format an alarm ID with discriminable components.

  Format: ALM-{severity}-{source}-{timestamp_suffix}
  Example: "ALM-CRIT-sensor-42-1735"
  """
  @spec discriminable_alarm_id(alarm_level(), String.t()) :: String.t()
  def discriminable_alarm_id(level, source) do
    severity = alarm_level_abbrev(level)
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> rem(10_000)
    "ALM-#{severity}-#{source}-#{timestamp}"
  end

  defp alarm_level_abbrev(:critical), do: "CRIT"
  defp alarm_level_abbrev(:warning), do: "WARN"
  defp alarm_level_abbrev(:caution), do: "CAUT"
  defp alarm_level_abbrev(:advisory), do: "ADVS"
  defp alarm_level_abbrev(:normal), do: "NORM"

  # ═══════════════════════════════════════════════════════════════════════════
  # AUTOMATION STATE (SC-VDP-001: Supervisory Control Paradigm)
  # ═══════════════════════════════════════════════════════════════════════════

  @type automation_state ::
          :normal_ops
          | :auto_healing
          | :auto_scaling
          | :manual_override
          | :degraded_mode
          | :emergency_stop
          | :executing

  @doc "Human-readable automation state label"
  def automation_label(:normal_ops), do: "NOMINAL"
  def automation_label(:auto_healing), do: "AUTO-HEALING"
  def automation_label(:auto_scaling), do: "AUTO-SCALING"
  def automation_label(:manual_override), do: "MANUAL"
  def automation_label(:degraded_mode), do: "DEGRADED"
  def automation_label(:emergency_stop), do: "EMERGENCY STOP"
  def automation_label(:executing), do: "EXECUTING"
  def automation_label(_), do: "UNKNOWN"

  # ═══════════════════════════════════════════════════════════════════════════
  # HELPERS
  # ═══════════════════════════════════════════════════════════════════════════

  defp generate_id do
    random_bytes = :crypto.strong_rand_bytes(4)
    Base.encode16(random_bytes, case: :lower)
  end
end
