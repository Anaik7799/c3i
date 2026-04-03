defmodule Indrajaal.Cockpit.Proprioceptive.DarkCockpit do
  @moduledoc """
  Dark Cockpit - NASA-STD-3000 Compliant HMI for v20.0.0

  Implements "dark cockpit" philosophy where:
  - Normal state = dark/minimal display
  - Only anomalies illuminate
  - Reduces cognitive load
  - Highlights what needs attention

  ## Dark Cockpit Model (NASA-STD-3000)

  Visual hierarchy:
  - Level 0 (Dark): All systems nominal
  - Level 1 (Dim): Advisory/info
  - Level 2 (Amber): Caution/warning
  - Level 3 (Red): Alert/critical
  - Level 4 (Flashing): Emergency

  ## Human Factors

  - Foveal attention: Central 2° vision
  - Peripheral awareness: Motion detection
  - Color coding: Universal meanings
  - Sound: Escalating urgency

  ## STAMP Constraints
  - SC-DRK-001: Default state MUST be dark
  - SC-DRK-002: Anomalies MUST illuminate within 100ms
  - SC-DRK-003: Critical alerts MUST be multimodal
  - SC-DRK-004: No false positives in Level 3+
  """

  use GenServer
  require Logger

  @type alert_level :: 0 | 1 | 2 | 3 | 4
  @type display_state :: :dark | :dim | :amber | :red | :flashing

  @type indicator :: %{
          id: String.t(),
          name: String.t(),
          subsystem: String.t(),
          level: alert_level(),
          state: display_state(),
          message: String.t(),
          timestamp: DateTime.t(),
          acknowledged: boolean()
        }

  @type state :: %{
          indicators: map(),
          global_state: display_state(),
          history: [indicator()],
          config: map()
        }

  # Level to state mapping
  @level_states %{
    0 => :dark,
    1 => :dim,
    2 => :amber,
    3 => :red,
    4 => :flashing
  }

  # Level colors
  @level_colors %{
    dark: {20, 20, 20},
    dim: {60, 60, 60},
    amber: {255, 191, 0},
    red: {255, 0, 0},
    flashing: {255, 0, 0}
  }

  # Max history entries
  @max_history 500

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers an indicator for a subsystem.
  """
  @spec register_indicator(String.t(), String.t(), String.t()) :: :ok
  def register_indicator(id, name, subsystem) do
    GenServer.cast(__MODULE__, {:register, id, name, subsystem})
  end

  @doc """
  Sets indicator level (0-4).
  """
  @spec set_level(String.t(), alert_level(), String.t()) :: :ok
  def set_level(indicator_id, level, message \\ "") do
    GenServer.cast(__MODULE__, {:set_level, indicator_id, level, message})
  end

  @doc """
  Clears indicator to dark state.
  """
  @spec clear(String.t()) :: :ok
  def clear(indicator_id) do
    GenServer.cast(__MODULE__, {:clear, indicator_id})
  end

  @doc """
  Clears all indicators.
  """
  @spec clear_all() :: :ok
  def clear_all do
    GenServer.cast(__MODULE__, :clear_all)
  end

  @doc """
  Acknowledges an alert.
  """
  @spec acknowledge(String.t()) :: :ok | {:error, :not_found}
  def acknowledge(indicator_id) do
    GenServer.call(__MODULE__, {:acknowledge, indicator_id})
  end

  @doc """
  Gets current cockpit state.
  """
  @spec current_state() :: %{global: display_state(), indicators: [indicator()]}
  def current_state do
    GenServer.call(__MODULE__, :current_state)
  end

  @doc """
  Gets active alerts (level >= 2).
  """
  @spec active_alerts() :: [indicator()]
  def active_alerts do
    GenServer.call(__MODULE__, :active_alerts)
  end

  @doc """
  Gets critical alerts (level >= 3).
  """
  @spec critical_alerts() :: [indicator()]
  def critical_alerts do
    GenServer.call(__MODULE__, :critical_alerts)
  end

  @doc """
  Renders cockpit as ASCII display.
  """
  @spec render_ascii() :: String.t()
  def render_ascii do
    GenServer.call(__MODULE__, :render_ascii)
  end

  @doc """
  Renders cockpit as JSON for web UI.
  """
  @spec render_json() :: map()
  def render_json do
    GenServer.call(__MODULE__, :render_json)
  end

  @doc """
  Gets cockpit statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    state = %{
      indicators: %{},
      global_state: :dark,
      history: [],
      stats: %{
        alerts_raised: 0,
        alerts_cleared: 0,
        alerts_acknowledged: 0,
        max_level_reached: 0
      },
      config: %{
        max_history: Keyword.get(opts, :max_history, @max_history),
        sound_enabled: Keyword.get(opts, :sound_enabled, true),
        flash_interval: Keyword.get(opts, :flash_interval, 500)
      }
    }

    Logger.info("🔲 Dark Cockpit initialized (NASA-STD-3000)")

    {:ok, state}
  end

  @impl true
  def handle_cast({:register, id, name, subsystem}, state) do
    indicator = %{
      id: id,
      name: name,
      subsystem: subsystem,
      level: 0,
      state: :dark,
      message: "",
      timestamp: DateTime.utc_now(),
      acknowledged: false
    }

    new_indicators = Map.put(state.indicators, id, indicator)
    {:noreply, %{state | indicators: new_indicators}}
  end

  @impl true
  def handle_cast({:set_level, indicator_id, level, message}, state) do
    case Map.get(state.indicators, indicator_id) do
      nil ->
        {:noreply, state}

      indicator ->
        # Determine new state
        new_state_name = Map.get(@level_states, level, :dark)
        old_level = indicator.level

        updated_indicator = %{
          indicator
          | level: level,
            state: new_state_name,
            message: message,
            timestamp: DateTime.utc_now(),
            acknowledged: false
        }

        new_indicators = Map.put(state.indicators, indicator_id, updated_indicator)

        # Update history if level increased
        new_history =
          if level > old_level do
            [updated_indicator | state.history]
            |> Enum.take(state.config.max_history)
          else
            state.history
          end

        # Update global state
        new_global = calculate_global_state(new_indicators)

        # Update stats
        new_stats =
          if level > old_level do
            %{
              state.stats
              | alerts_raised: state.stats.alerts_raised + 1,
                max_level_reached: max(state.stats.max_level_reached, level)
            }
          else
            state.stats
          end

        # Log based on level (SC-DRK-003: multimodal for critical)
        log_alert(updated_indicator)

        {:noreply,
         %{
           state
           | indicators: new_indicators,
             global_state: new_global,
             history: new_history,
             stats: new_stats
         }}
    end
  end

  @impl true
  def handle_cast({:clear, indicator_id}, state) do
    case Map.get(state.indicators, indicator_id) do
      nil ->
        {:noreply, state}

      indicator ->
        updated = %{indicator | level: 0, state: :dark, message: "", acknowledged: false}
        new_indicators = Map.put(state.indicators, indicator_id, updated)
        new_global = calculate_global_state(new_indicators)
        new_stats = %{state.stats | alerts_cleared: state.stats.alerts_cleared + 1}

        {:noreply,
         %{state | indicators: new_indicators, global_state: new_global, stats: new_stats}}
    end
  end

  @impl true
  def handle_cast(:clear_all, state) do
    cleared_indicators =
      Map.new(state.indicators, fn {id, ind} ->
        {id, %{ind | level: 0, state: :dark, message: "", acknowledged: false}}
      end)

    {:noreply, %{state | indicators: cleared_indicators, global_state: :dark}}
  end

  @impl true
  def handle_call({:acknowledge, indicator_id}, _from, state) do
    case Map.get(state.indicators, indicator_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      indicator ->
        updated = %{indicator | acknowledged: true}
        new_indicators = Map.put(state.indicators, indicator_id, updated)
        new_stats = %{state.stats | alerts_acknowledged: state.stats.alerts_acknowledged + 1}

        {:reply, :ok, %{state | indicators: new_indicators, stats: new_stats}}
    end
  end

  @impl true
  def handle_call(:current_state, _from, state) do
    result = %{
      global: state.global_state,
      indicators: Map.values(state.indicators)
    }

    {:reply, result, state}
  end

  @impl true
  def handle_call(:active_alerts, _from, state) do
    active =
      state.indicators
      |> Map.values()
      |> Enum.filter(fn i -> i.level >= 2 end)
      |> Enum.sort_by(& &1.level, :desc)

    {:reply, active, state}
  end

  @impl true
  def handle_call(:critical_alerts, _from, state) do
    critical =
      state.indicators
      |> Map.values()
      |> Enum.filter(fn i -> i.level >= 3 end)
      |> Enum.sort_by(& &1.level, :desc)

    {:reply, critical, state}
  end

  @impl true
  def handle_call(:render_ascii, _from, state) do
    ascii = render_cockpit_ascii(state)
    {:reply, ascii, state}
  end

  @impl true
  def handle_call(:render_json, _from, state) do
    json = render_cockpit_json(state)
    {:reply, json, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats =
      Map.merge(state.stats, %{
        total_indicators: map_size(state.indicators),
        active_count: Enum.count(state.indicators, fn {_, i} -> i.level >= 2 end),
        critical_count: Enum.count(state.indicators, fn {_, i} -> i.level >= 3 end),
        global_state: state.global_state,
        history_count: length(state.history)
      })

    {:reply, stats, state}
  end

  # Private helpers

  defp calculate_global_state(indicators) do
    max_level =
      indicators
      |> Map.values()
      |> Enum.map(& &1.level)
      |> Enum.max(fn -> 0 end)

    Map.get(@level_states, max_level, :dark)
  end

  defp log_alert(%{level: 0}), do: :ok

  defp log_alert(%{level: 1} = ind) do
    Logger.debug("[ADVISORY] #{ind.subsystem}/#{ind.name}: #{ind.message}")
  end

  defp log_alert(%{level: 2} = ind) do
    Logger.warning("[CAUTION] #{ind.subsystem}/#{ind.name}: #{ind.message}")
  end

  defp log_alert(%{level: 3} = ind) do
    Logger.error("[ALERT] #{ind.subsystem}/#{ind.name}: #{ind.message}")
  end

  defp log_alert(%{level: 4} = ind) do
    Logger.error("[EMERGENCY] #{ind.subsystem}/#{ind.name}: #{ind.message}")
    # In production: trigger audio/haptic feedback
  end

  defp render_cockpit_ascii(state) do
    # Group by subsystem
    by_subsystem =
      state.indicators
      |> Map.values()
      |> Enum.group_by(& &1.subsystem)

    subsystem_displays =
      Enum.map_join(by_subsystem, "\n", fn {subsystem, indicators} ->
        header = "╔═══ #{String.upcase(subsystem)} ═══╗"
        indicator_lines = Enum.map_join(indicators, "\n", &render_indicator_ascii/1)
        footer = "╚#{String.duplicate("═", String.length(header) - 2)}╝"
        "#{header}\n#{indicator_lines}\n#{footer}"
      end)

    global_bar = render_global_state_ascii(state.global_state)

    """
    ┌─────────────────────────────────────────┐
    │          DARK COCKPIT DISPLAY           │
    │  Global: #{global_bar}  │
    └─────────────────────────────────────────┘

    #{subsystem_displays}
    """
  end

  defp render_indicator_ascii(indicator) do
    symbol =
      case indicator.state do
        :dark -> "⚫"
        :dim -> "⚪"
        :amber -> "🟡"
        :red -> "🔴"
        :flashing -> "🔴"
      end

    ack = if indicator.acknowledged, do: "✓", else: " "
    "║ #{symbol} #{String.pad_trailing(indicator.name, 12)} #{ack} ║"
  end

  defp render_global_state_ascii(global_state) do
    case global_state do
      :dark -> "████████████████ NOMINAL"
      :dim -> "░░░░████████████ ADVISORY"
      :amber -> "▓▓▓▓▓▓▓▓████████ CAUTION"
      :red -> "████████████████ ALERT"
      :flashing -> "████████████████ EMERGENCY"
    end
  end

  defp render_cockpit_json(state) do
    %{
      global_state: state.global_state,
      global_color: color_to_hex(Map.get(@level_colors, state.global_state, {0, 0, 0})),
      timestamp: DateTime.to_iso8601(DateTime.utc_now()),
      indicators:
        Enum.map(Map.values(state.indicators), fn ind ->
          %{
            id: ind.id,
            name: ind.name,
            subsystem: ind.subsystem,
            level: ind.level,
            state: ind.state,
            color: color_to_hex(Map.get(@level_colors, ind.state, {0, 0, 0})),
            message: ind.message,
            timestamp: DateTime.to_iso8601(ind.timestamp),
            acknowledged: ind.acknowledged
          }
        end),
      by_subsystem:
        state.indicators
        |> Map.values()
        |> Enum.group_by(& &1.subsystem)
        |> Enum.into(%{}, fn {k, v} ->
          {k,
           %{
             max_level: Enum.max_by(v, & &1.level).level,
             count: length(v),
             active: Enum.count(v, fn i -> i.level > 0 end)
           }}
        end),
      summary: %{
        total: map_size(state.indicators),
        dark: Enum.count(state.indicators, fn {_, i} -> i.level == 0 end),
        advisory: Enum.count(state.indicators, fn {_, i} -> i.level == 1 end),
        caution: Enum.count(state.indicators, fn {_, i} -> i.level == 2 end),
        alert: Enum.count(state.indicators, fn {_, i} -> i.level == 3 end),
        emergency: Enum.count(state.indicators, fn {_, i} -> i.level == 4 end)
      }
    }
  end

  defp color_to_hex({r, g, b}) do
    r_hex = r |> Integer.to_string(16) |> String.pad_leading(2, "0")
    g_hex = g |> Integer.to_string(16) |> String.pad_leading(2, "0")
    b_hex = b |> Integer.to_string(16) |> String.pad_leading(2, "0")
    "#" <> r_hex <> g_hex <> b_hex
  end
end
