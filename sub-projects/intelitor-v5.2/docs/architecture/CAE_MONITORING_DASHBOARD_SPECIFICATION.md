# CAE Monitoring Dashboard Specification

**Version**: 1.0.0 | **Status**: DESIGN COMPLETE | **Date**: 2025-12-29
**Author**: Agent 10 (C4-STANDARD) | **STAMP Compliance**: SC-HMI-001 to SC-HMI-010

## 1. Executive Summary

The CAE (Cybernetic Autonomous Evolution) Monitoring Dashboard provides a unified real-time interface for monitoring the Indrajaal autonomic system. It integrates OODA cycle metrics, agent status, GDE evolution progress, and control loop health into a cohesive Phoenix LiveView dashboard.

### 1.1 Key Objectives

- **O1**: Real-time visibility into OODA loop latency and phase timings
- **O2**: Agent grid status for all 50 distributed agents
- **O3**: GDE evolution tracking with proposal/validation metrics
- **O4**: Control loop health with autonomic feedback visualization

### 1.2 STAMP Constraints

| Constraint | Description |
|------------|-------------|
| SC-HMI-001 | Dark Cockpit defaults (NASA-STD-3000) |
| SC-HMI-002 | Updates < 50ms latency |
| SC-PRF-050 | Response time < 50ms |
| SC-OBS-069 | Dual logging (Terminal + SigNoz) |
| SC-OBS-071 | 4 OTEL modules active |

---

## 2. Dashboard Architecture

### 2.1 System Context (C4 Level 1)

```
+-------------------------------------------------------------------+
|                         OPERATOR                                   |
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                   CAE MONITORING DASHBOARD                         |
|  (Phoenix LiveView - IndrajaalWeb.CAEDashboardLive)               |
|                                                                    |
|  +-------------+  +-------------+  +-------------+  +-------------+|
|  | CAE         |  | Agent       |  | OODA        |  | GDE         ||
|  | Readiness   |  | Status      |  | Metrics     |  | Evolution   ||
|  | Gauge       |  | Grid        |  | Panel       |  | Status      ||
|  +-------------+  +-------------+  +-------------+  +-------------+|
|                                                                    |
|  +-------------+  +-------------+  +-------------+  +-------------+|
|  | Control     |  | Telemetry   |  | Alert       |  | Action      ||
|  | Loop Health |  | Stream      |  | Panel       |  | Console     ||
|  +-------------+  +-------------+  +-------------+  +-------------+|
+-------------------------------------------------------------------+
                              |
                              v
+-------------------------------------------------------------------+
|                      BACKEND SYSTEMS                               |
|                                                                    |
|  +------------------+  +------------------+  +------------------+  |
|  | Agent Mesh       |  | OODA Controller  |  | GDE Cortex       |  |
|  | (50 Agents)      |  | (Cybernetic)     |  | (Evolution)      |  |
|  +------------------+  +------------------+  +------------------+  |
|                                                                    |
|  +------------------+  +------------------+  +------------------+  |
|  | Telemetry        |  | Guardian         |  | Zenoh Mesh       |  |
|  | (OTEL/SigNoz)    |  | (Safety)         |  | (PubSub)         |  |
|  +------------------+  +------------------+  +------------------+  |
+-------------------------------------------------------------------+
```

### 2.2 Component Hierarchy

```
IndrajaalWeb.CAEDashboardLive
|
+-- Components
|   +-- CAEReadinessGauge          # Overall system readiness 0-10
|   +-- AgentStatusGrid            # 50 agents in grid layout
|   +-- OODAMetricsPanel           # 4-phase latency breakdown
|   +-- GDEEvolutionStatus         # Proposal/validation tracking
|   +-- ControlLoopHealth          # Feedback loop visualization
|   +-- TelemetryStream            # Live event stream
|   +-- AlertPanel                 # Critical alerts
|   +-- ActionConsole              # Operator actions
|
+-- Data Sources
|   +-- Phoenix.PubSub             # Real-time updates
|   +-- Telemetry                  # Metrics collection
|   +-- ZenohCoordinator           # Agent heartbeats
|   +-- OODA.Telemetry             # OODA metrics
|
+-- Update Strategy
    +-- 500ms interval             # Metrics refresh
    +-- WebSocket                  # Agent status push
    +-- Telemetry events           # Reactive updates
```

---

## 3. Component Specifications

### 3.1 CAE Readiness Gauge

**Purpose**: Display overall system readiness on a 0-10 scale with sub-component breakdown.

```
+---------------------------------------------------------+
|              CAE READINESS: 7.5/10                      |
|  ==================================----  (Target: 9.5)  |
|                                                         |
|  OODA Speed:    ====------  4.2/10    [< 100ms target]  |
|  GDE Active:    ----------  PENDING   [Evolution]       |
|  Loop Coupling: ====------  40%       [Feedback]        |
|  Observability: ==========  100%      [OTEL Complete]   |
+---------------------------------------------------------+
```

#### Data Model

```elixir
defmodule CAEReadinessData do
  @type t :: %__MODULE__{
    overall_score: float(),           # 0.0 - 10.0
    target_score: float(),            # 9.5 default
    ooda_speed: float(),              # 0.0 - 10.0
    gde_status: :pending | :active | :learning | :paused,
    loop_coupling: float(),           # 0.0 - 100.0 (%)
    observability: float(),           # 0.0 - 100.0 (%)
    timestamp: DateTime.t()
  }

  defstruct [
    :overall_score,
    :target_score,
    :ooda_speed,
    :gde_status,
    :loop_coupling,
    :observability,
    :timestamp
  ]
end
```

#### Calculation Logic

```elixir
def calculate_readiness(metrics) do
  ooda_score = calculate_ooda_score(metrics.ooda_latency_ms)
  gde_score = calculate_gde_score(metrics.gde_status)
  loop_score = metrics.loop_coupling / 10.0
  obs_score = metrics.observability / 10.0

  overall = (ooda_score + gde_score + loop_score + obs_score) / 4.0
  Float.round(overall, 1)
end

defp calculate_ooda_score(latency_ms) when latency_ms < 50, do: 10.0
defp calculate_ooda_score(latency_ms) when latency_ms < 100, do: 8.0
defp calculate_ooda_score(latency_ms) when latency_ms < 200, do: 6.0
defp calculate_ooda_score(latency_ms) when latency_ms < 500, do: 4.0
defp calculate_ooda_score(_), do: 2.0

defp calculate_gde_score(:active), do: 10.0
defp calculate_gde_score(:learning), do: 8.0
defp calculate_gde_score(:paused), do: 5.0
defp calculate_gde_score(:pending), do: 2.0
```

---

### 3.2 Agent Status Grid

**Purpose**: Display status of all 50 distributed agents in a responsive grid.

```
+---------------------------------------------------------+
|                    AGENT STATUS                          |
+---------------------------------------------------------+
| EXECUTIVE (1)                                            |
| [*] Exec-001: Executive Agent - COORDINATING            |
|---------------------------------------------------------|
| DOMAIN (10)                                              |
| [*] Dom-001: Access Control  - MONITORING               |
| [*] Dom-002: Alarms          - PROCESSING               |
| [*] Dom-003: Analytics       - ANALYZING                |
| [ ] Dom-004: Video           - IDLE                     |
| [!] Dom-005: Dispatch        - ERROR                    |
| ... (5 more)                                            |
|---------------------------------------------------------|
| FUNCTIONAL (15)                                          |
| [*] Func-001: FastOODA       - THINKING...              |
| [*] Func-002: Tests          - WRITING...               |
| [*] Func-003: TrainingGym    - ANALYZING...             |
| [ ] Func-004: GDE            - PENDING                  |
| [ ] Func-005: UnifiedBus     - PENDING                  |
| ... (10 more)                                           |
|---------------------------------------------------------|
| WORKERS (24)                                             |
| [*] W01 [*] W02 [*] W03 [*] W04 [ ] W05 [ ] W06         |
| [*] W07 [*] W08 [ ] W09 [ ] W10 [ ] W11 [*] W12         |
| ... (12 more)                                           |
+---------------------------------------------------------+
```

#### Agent Status Types

```elixir
@type agent_status ::
  :idle          # [ ] Gray - Waiting for work
  | :running     # [*] Green - Actively processing
  | :thinking    # [~] Blue - AI inference in progress
  | :waiting     # [.] Yellow - Waiting on dependency
  | :error       # [!] Red - Error state
  | :offline     # [X] Dark - Not responding
```

#### Grid Configuration

```elixir
defmodule AgentGridConfig do
  @categories [
    %{name: "Executive", prefix: "Exec", count: 1, style: :detailed},
    %{name: "Domain", prefix: "Dom", count: 10, style: :detailed},
    %{name: "Functional", prefix: "Func", count: 15, style: :detailed},
    %{name: "Workers", prefix: "W", count: 24, style: :compact}
  ]

  def categories, do: @categories
end
```

---

### 3.3 OODA Metrics Panel

**Purpose**: Display detailed OODA loop metrics with phase timing breakdown.

```
+---------------------------------------------------------+
|                 OODA CYCLE METRICS                       |
|                                                          |
|  Current Latency: 47ms [========        ] Target: <100ms |
|  Cycle Count:     1,234 cycles                          |
|  Quality Score:   92%                                    |
|  Decision Conf:   87%                                    |
|                                                          |
|  Phase Breakdown:                                        |
|  [Observe] --> [Orient] --> [Decide] --> [Act]          |
|     12ms         15ms         8ms        12ms           |
|    [===]       [====]        [==]       [===]           |
|                                                          |
|  Trend: Stable (last 100 cycles)                        |
|  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~                       |
+---------------------------------------------------------+
```

#### Data Model

```elixir
defmodule OODAMetrics do
  @type t :: %__MODULE__{
    current_latency_ms: non_neg_integer(),
    target_latency_ms: non_neg_integer(),
    cycle_count: non_neg_integer(),
    quality_score: float(),
    decision_confidence: float(),
    phase_timings: phase_timings(),
    trend: :improving | :stable | :degrading,
    history: list(cycle_record())
  }

  @type phase_timings :: %{
    observe_ms: non_neg_integer(),
    orient_ms: non_neg_integer(),
    decide_ms: non_neg_integer(),
    act_ms: non_neg_integer()
  }

  @type cycle_record :: %{
    timestamp: DateTime.t(),
    latency_ms: non_neg_integer(),
    phases: phase_timings()
  }

  defstruct [
    :current_latency_ms,
    target_latency_ms: 100,
    :cycle_count,
    :quality_score,
    :decision_confidence,
    :phase_timings,
    :trend,
    history: []
  ]
end
```

#### Telemetry Integration

```elixir
# Required telemetry events
@ooda_events [
  [:indrajaal, :ooda, :loop, :start],
  [:indrajaal, :ooda, :loop, :stop],
  [:indrajaal, :ooda, :observe, :stop],
  [:indrajaal, :ooda, :orient, :stop],
  [:indrajaal, :ooda, :decide, :stop],
  [:indrajaal, :ooda, :act, :stop]
]

def attach_ooda_handlers do
  :telemetry.attach_many(
    "cae-dashboard-ooda",
    @ooda_events,
    &handle_ooda_event/4,
    nil
  )
end

defp handle_ooda_event([:indrajaal, :ooda, :loop, :stop], measurements, metadata, _config) do
  Phoenix.PubSub.broadcast(
    Indrajaal.PubSub,
    "cae:ooda:metrics",
    {:ooda_cycle_complete, measurements, metadata}
  )
end
```

---

### 3.4 GDE Evolution Status

**Purpose**: Track Goal-Directed Evolution proposal lifecycle and metrics.

```
+---------------------------------------------------------+
|                GDE EVOLUTION STATUS                      |
|                                                          |
|  Status: ENABLED (Manual Gate)                          |
|                                                          |
|  Pipeline Metrics:                                       |
|  +------------------+--------+--------+--------+        |
|  | Proposals Gen    |   47   | +3/hr  | [====] |        |
|  | Guardian Valid   |   42   | 89.4%  | [====] |        |
|  | Shadow Testing   |   38   | 90.5%  | [===]  |        |
|  | Promoted         |   12   | 31.6%  | [=]    |        |
|  +------------------+--------+--------+--------+        |
|                                                          |
|  Current Proposal:                                       |
|  +-----------------------------------------------------+|
|  | optimize_auth_check                                  ||
|  | Fitness: 0.91 / 0.85 threshold                      ||
|  | Status: SHADOW_TESTING (2/5 validators)             ||
|  +-----------------------------------------------------+|
|                                                          |
|  Recent Activity:                                        |
|  - 14:32:05  Proposal #47 generated                     |
|  - 14:31:42  Proposal #46 promoted to production        |
|  - 14:30:18  Proposal #45 failed shadow test            |
+---------------------------------------------------------+
```

#### Data Model

```elixir
defmodule GDEStatus do
  @type t :: %__MODULE__{
    status: :enabled | :disabled | :learning | :paused,
    gate_mode: :manual | :automatic,
    proposals_generated: non_neg_integer(),
    proposals_validated: non_neg_integer(),
    proposals_shadow_tested: non_neg_integer(),
    proposals_promoted: non_neg_integer(),
    current_proposal: proposal() | nil,
    recent_activity: list(activity_event()),
    fitness_threshold: float()
  }

  @type proposal :: %{
    id: String.t(),
    name: String.t(),
    fitness: float(),
    status: :generated | :validating | :shadow_testing | :promoted | :rejected,
    validators_passed: non_neg_integer(),
    validators_total: non_neg_integer()
  }

  @type activity_event :: %{
    timestamp: DateTime.t(),
    event_type: :generated | :validated | :promoted | :rejected,
    proposal_id: String.t(),
    details: String.t()
  }

  defstruct [
    :status,
    gate_mode: :manual,
    proposals_generated: 0,
    proposals_validated: 0,
    proposals_shadow_tested: 0,
    proposals_promoted: 0,
    :current_proposal,
    recent_activity: [],
    fitness_threshold: 0.85
  ]
end
```

---

### 3.5 Control Loop Health

**Purpose**: Visualize autonomic control loop feedback and coupling metrics.

```
+---------------------------------------------------------+
|              CONTROL LOOP HEALTH                         |
|                                                          |
|  Feedback Loop Coupling: 72%                             |
|  [==================================--------]            |
|                                                          |
|  Loop Components:                                        |
|  +-------------------+---------+----------+             |
|  | Component         | Status  | Latency  |             |
|  +-------------------+---------+----------+             |
|  | Sensor Input      | [*] OK  |   5ms    |             |
|  | Pattern Matcher   | [*] OK  |  12ms    |             |
|  | Decision Engine   | [*] OK  |   8ms    |             |
|  | Effector Output   | [*] OK  |  15ms    |             |
|  | Feedback Return   | [*] OK  |   7ms    |             |
|  +-------------------+---------+----------+             |
|                     Total Loop:    47ms                  |
|                                                          |
|  Stability Index: 0.94 (Excellent)                      |
|  Oscillation: None detected                             |
+---------------------------------------------------------+
```

---

## 4. Telemetry Events Required

### 4.1 OODA Telemetry Events

```elixir
defmodule Indrajaal.CAE.Telemetry do
  @moduledoc """
  Telemetry events for CAE Dashboard.
  SC-OBS-065 compliant.
  """

  @prefix [:indrajaal, :cae]

  # OODA Events
  def ooda_loop_start(metadata) do
    :telemetry.execute(
      @prefix ++ [:ooda, :loop, :start],
      %{system_time: System.system_time()},
      metadata
    )
  end

  def ooda_loop_stop(duration, metadata) do
    :telemetry.execute(
      @prefix ++ [:ooda, :loop, :stop],
      %{duration: duration},
      metadata
    )
  end

  def ooda_phase(phase, duration, metadata) do
    :telemetry.execute(
      @prefix ++ [:ooda, phase, :stop],
      %{duration: duration},
      metadata
    )
  end

  # Agent Events
  def agent_status_change(agent_id, old_status, new_status) do
    :telemetry.execute(
      @prefix ++ [:agent, :status_change],
      %{},
      %{agent_id: agent_id, old_status: old_status, new_status: new_status}
    )
  end

  def agent_heartbeat(agent_id, metrics) do
    :telemetry.execute(
      @prefix ++ [:agent, :heartbeat],
      metrics,
      %{agent_id: agent_id, timestamp: DateTime.utc_now()}
    )
  end

  # GDE Events
  def gde_proposal_generated(proposal) do
    :telemetry.execute(
      @prefix ++ [:gde, :proposal, :generated],
      %{fitness: proposal.fitness},
      %{proposal_id: proposal.id, name: proposal.name}
    )
  end

  def gde_proposal_validated(proposal_id, result) do
    :telemetry.execute(
      @prefix ++ [:gde, :proposal, :validated],
      %{},
      %{proposal_id: proposal_id, result: result}
    )
  end

  def gde_proposal_promoted(proposal_id) do
    :telemetry.execute(
      @prefix ++ [:gde, :proposal, :promoted],
      %{},
      %{proposal_id: proposal_id, timestamp: DateTime.utc_now()}
    )
  end

  # Control Loop Events
  def control_loop_cycle(metrics) do
    :telemetry.execute(
      @prefix ++ [:control_loop, :cycle],
      metrics,
      %{timestamp: DateTime.utc_now()}
    )
  end
end
```

### 4.2 PubSub Topics

```elixir
@pubsub_topics %{
  cae_readiness: "cae:readiness",
  agent_status: "cae:agents:status",
  ooda_metrics: "cae:ooda:metrics",
  gde_evolution: "cae:gde:evolution",
  control_loop: "cae:control:loop",
  alerts: "cae:alerts"
}
```

---

## 5. LiveView Implementation

### 5.1 Main Module Structure

```elixir
defmodule IndrajaalWeb.CAEDashboardLive do
  @moduledoc """
  CAE Monitoring Dashboard - Real-time Cybernetic System Monitoring.

  WHAT: Unified dashboard for OODA, Agent, GDE, and Control Loop monitoring.
  WHY: SC-HMI-001 requires comprehensive system visibility for operators.
  CONSTRAINTS: Updates < 50ms, Dark Cockpit defaults, OTEL integration.

  ## STAMP Compliance
  - SC-HMI-001: Dark Cockpit defaults
  - SC-HMI-002: < 50ms update latency
  - SC-PRF-050: Response time < 50ms
  - SC-OBS-069: Dual logging integration
  """

  use IndrajaalWeb, :live_view
  import IndrajaalWeb.PrajnaComponents

  alias Indrajaal.CAE.{ReadinessCalculator, AgentMonitor, OODAMetrics, GDETracker}

  @refresh_interval 500
  @agent_heartbeat_timeout 10_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      subscribe_to_events()
      schedule_refresh()
    end

    {:ok,
     socket
     |> assign(:page_title, "CAE Dashboard")
     |> assign(:current_nav, :cae)
     |> assign(:readiness, init_readiness())
     |> assign(:agents, init_agents())
     |> assign(:ooda, init_ooda())
     |> assign(:gde, init_gde())
     |> assign(:control_loop, init_control_loop())
     |> assign(:alerts, [])}
  end

  defp subscribe_to_events do
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cae:readiness")
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cae:agents:status")
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cae:ooda:metrics")
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cae:gde:evolution")
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cae:control:loop")
    Phoenix.PubSub.subscribe(Indrajaal.PubSub, "cae:alerts")
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  @impl true
  def handle_info(:refresh, socket) do
    schedule_refresh()

    {:noreply,
     socket
     |> update_readiness()
     |> update_agents()
     |> update_ooda()
     |> update_gde()
     |> update_control_loop()
     |> check_alerts()}
  end

  # PubSub handlers for reactive updates
  @impl true
  def handle_info({:agent_status_change, agent_id, status}, socket) do
    agents = update_agent_status(socket.assigns.agents, agent_id, status)
    {:noreply, assign(socket, :agents, agents)}
  end

  @impl true
  def handle_info({:ooda_cycle_complete, metrics, _metadata}, socket) do
    ooda = update_ooda_metrics(socket.assigns.ooda, metrics)
    {:noreply, assign(socket, :ooda, ooda)}
  end

  @impl true
  def handle_info({:gde_event, event}, socket) do
    gde = update_gde_status(socket.assigns.gde, event)
    {:noreply, assign(socket, :gde, gde)}
  end

  @impl true
  def handle_info({:alert, alert}, socket) do
    alerts = [alert | Enum.take(socket.assigns.alerts, 9)]
    {:noreply, assign(socket, :alerts, alerts)}
  end

  # Event handlers
  @impl true
  def handle_event("agent_action", %{"agent_id" => id, "action" => action}, socket) do
    case execute_agent_action(id, action) do
      :ok -> {:noreply, put_flash(socket, :info, "Action #{action} sent to #{id}")}
      {:error, reason} -> {:noreply, put_flash(socket, :error, "Failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("toggle_gde", _params, socket) do
    new_status = toggle_gde_status(socket.assigns.gde.status)
    {:noreply, update(socket, :gde, &%{&1 | status: new_status})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-surface-primary text-content-primary">
      <.prajna_header
        health_score={@readiness.overall_score * 10}
        uptime={format_uptime()}
        node_count={count_active_agents(@agents)}
        total_nodes={50}
        alarm_count={length(@alerts)}
      />

      <.prajna_nav current={:cae} />

      <div class="p-4 space-y-4">
        <!-- Row 1: Readiness + OODA -->
        <div class="grid grid-cols-2 gap-4">
          <.cae_readiness_gauge readiness={@readiness} />
          <.ooda_metrics_panel ooda={@ooda} />
        </div>

        <!-- Row 2: Agent Grid -->
        <.agent_status_grid agents={@agents} />

        <!-- Row 3: GDE + Control Loop -->
        <div class="grid grid-cols-2 gap-4">
          <.gde_evolution_status gde={@gde} />
          <.control_loop_health control_loop={@control_loop} />
        </div>

        <!-- Row 4: Alerts -->
        <.alert_panel alerts={@alerts} />
      </div>
    </div>
    """
  end

  # Component renderers...
  # (Individual component render functions)
end
```

### 5.2 Component Templates

```elixir
# CAE Readiness Gauge Component
defp cae_readiness_gauge(assigns) do
  ~H"""
  <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
    <div class="text-center mb-4">
      <span class="text-content-muted font-mono text-sm">CAE READINESS</span>
      <div class="text-3xl font-bold font-mono mt-2" style={readiness_color(@readiness.overall_score)}>
        {@readiness.overall_score}/10
      </div>
      <div class="text-xs text-content-muted">Target: {@readiness.target_score}</div>
    </div>

    <div class="space-y-3">
      <.readiness_bar label="OODA Speed" value={@readiness.ooda_speed} max={10} />
      <.readiness_bar label="GDE Active" value={gde_score(@readiness.gde_status)} max={10}
        status_text={format_gde_status(@readiness.gde_status)} />
      <.readiness_bar label="Loop Coupling" value={@readiness.loop_coupling} max={100} unit="%" />
      <.readiness_bar label="Observability" value={@readiness.observability} max={100} unit="%" />
    </div>
  </div>
  """
end

# OODA Metrics Panel Component
defp ooda_metrics_panel(assigns) do
  ~H"""
  <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
    <h3 class="text-content-primary font-mono text-sm mb-4">OODA CYCLE METRICS</h3>

    <div class="grid grid-cols-2 gap-4 mb-4">
      <div>
        <div class="text-content-muted text-xs">Current Latency</div>
        <div class={["text-2xl font-bold font-mono", latency_class(@ooda.current_latency_ms)]}>
          {@ooda.current_latency_ms}ms
        </div>
      </div>
      <div>
        <div class="text-content-muted text-xs">Target</div>
        <div class="text-xl font-mono text-content-secondary">&lt;{@ooda.target_latency_ms}ms</div>
      </div>
      <div>
        <div class="text-content-muted text-xs">Cycle Count</div>
        <div class="text-xl font-mono">{number_with_commas(@ooda.cycle_count)}</div>
      </div>
      <div>
        <div class="text-content-muted text-xs">Quality</div>
        <div class="text-xl font-mono">{Float.round(@ooda.quality_score, 1)}%</div>
      </div>
    </div>

    <div class="border-t border-border-theme-primary pt-4">
      <div class="text-xs text-content-muted mb-2">Phase Breakdown:</div>
      <div class="flex justify-between items-center font-mono text-xs">
        <.phase_box name="Observe" ms={@ooda.phase_timings.observe_ms} />
        <span class="text-content-muted">-></span>
        <.phase_box name="Orient" ms={@ooda.phase_timings.orient_ms} />
        <span class="text-content-muted">-></span>
        <.phase_box name="Decide" ms={@ooda.phase_timings.decide_ms} />
        <span class="text-content-muted">-></span>
        <.phase_box name="Act" ms={@ooda.phase_timings.act_ms} />
      </div>
    </div>

    <div class="mt-4 text-xs text-content-muted">
      Trend: <span class={trend_class(@ooda.trend)}>{format_trend(@ooda.trend)}</span>
    </div>
  </div>
  """
end

# Agent Status Grid Component
defp agent_status_grid(assigns) do
  ~H"""
  <div class="bg-surface-secondary rounded-lg border border-border-theme-primary p-4">
    <h3 class="text-content-primary font-mono text-sm mb-4">AGENT STATUS (50 AGENTS)</h3>

    <div class="space-y-4">
      <!-- Executive Agents -->
      <div>
        <div class="text-xs text-content-muted mb-2">EXECUTIVE (1)</div>
        <div class="space-y-1">
          <%= for agent <- filter_agents(@agents, :executive) do %>
            <.agent_row agent={agent} style={:detailed} />
          <% end %>
        </div>
      </div>

      <!-- Domain Agents -->
      <div>
        <div class="text-xs text-content-muted mb-2">DOMAIN (10)</div>
        <div class="space-y-1">
          <%= for agent <- filter_agents(@agents, :domain) do %>
            <.agent_row agent={agent} style={:detailed} />
          <% end %>
        </div>
      </div>

      <!-- Functional Agents -->
      <div>
        <div class="text-xs text-content-muted mb-2">FUNCTIONAL (15)</div>
        <div class="space-y-1">
          <%= for agent <- filter_agents(@agents, :functional) do %>
            <.agent_row agent={agent} style={:detailed} />
          <% end %>
        </div>
      </div>

      <!-- Workers (compact grid) -->
      <div>
        <div class="text-xs text-content-muted mb-2">WORKERS (24)</div>
        <div class="flex flex-wrap gap-1">
          <%= for agent <- filter_agents(@agents, :worker) do %>
            <.agent_compact agent={agent} />
          <% end %>
        </div>
      </div>
    </div>
  </div>
  """
end
```

---

## 6. Real-Time Update Strategy

### 6.1 Update Modes

| Mode | Interval | Use Case |
|------|----------|----------|
| Polling | 500ms | Metrics refresh, history |
| Push | Immediate | Agent status changes, alerts |
| Reactive | Event-driven | OODA cycle completion, GDE events |

### 6.2 Performance Optimization

```elixir
# Efficient diff-based updates
defp update_agents(socket) do
  current = socket.assigns.agents
  new_agents = AgentMonitor.get_all_agents()

  # Only update changed agents
  changed = Enum.filter(new_agents, fn agent ->
    current_agent = Map.get(current, agent.id)
    current_agent == nil or agent.status != current_agent.status
  end)

  if Enum.empty?(changed) do
    socket
  else
    updated = Enum.reduce(changed, current, fn agent, acc ->
      Map.put(acc, agent.id, agent)
    end)
    assign(socket, :agents, updated)
  end
end

# Batch telemetry processing
defp process_telemetry_batch(events) do
  events
  |> Enum.group_by(& &1.type)
  |> Enum.map(fn {type, type_events} ->
    case type do
      :ooda -> aggregate_ooda_events(type_events)
      :agent -> aggregate_agent_events(type_events)
      :gde -> aggregate_gde_events(type_events)
    end
  end)
end
```

### 6.3 WebSocket Configuration

```elixir
# In endpoint.ex
socket "/live", Phoenix.LiveView.Socket,
  websocket: [
    timeout: 45_000,
    compress: true,
    max_frame_size: 1_000_000
  ]

# LiveView configuration in config.exs
config :indrajaal, IndrajaalWeb.Endpoint,
  live_view: [
    signing_salt: "cae_dashboard_salt"
  ]
```

---

## 7. Styling and Theming

### 7.1 Color Scheme (Dark Cockpit - NASA-STD-3000)

```css
/* CAE Dashboard Theme Variables */
:root {
  --cae-bg-primary: #0a0a0a;
  --cae-bg-secondary: #1a1a2e;
  --cae-bg-tertiary: #16213e;

  --cae-text-primary: #e5e5e5;
  --cae-text-secondary: #a0a0a0;
  --cae-text-muted: #666666;

  --cae-accent-green: #00ff41;
  --cae-accent-blue: #00b4d8;
  --cae-accent-amber: #ffb703;
  --cae-accent-red: #ff006e;

  --cae-status-ok: #00ff41;
  --cae-status-warning: #ffb703;
  --cae-status-error: #ff006e;
  --cae-status-idle: #666666;
}
```

### 7.2 Agent Status Colors

```elixir
defp status_color(:running), do: "text-green-400"
defp status_color(:thinking), do: "text-blue-400"
defp status_color(:waiting), do: "text-amber-400"
defp status_color(:error), do: "text-red-400"
defp status_color(:offline), do: "text-gray-600"
defp status_color(:idle), do: "text-gray-400"
```

---

## 8. Testing Requirements

### 8.1 Unit Tests

```elixir
# test/indrajaal_web/live/cae_dashboard_live_test.exs
defmodule IndrajaalWeb.CAEDashboardLiveTest do
  use IndrajaalWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "renders dashboard with all components", %{conn: conn} do
      {:ok, view, html} = live(conn, "/dashboard/cae")

      assert html =~ "CAE READINESS"
      assert html =~ "OODA CYCLE METRICS"
      assert html =~ "AGENT STATUS"
      assert html =~ "GDE EVOLUTION STATUS"
    end

    test "subscribes to PubSub topics", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/cae")

      # Simulate agent status change
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "cae:agents:status",
        {:agent_status_change, "agent-001", :running}
      )

      # Verify update reflected
      assert render(view) =~ "agent-001"
    end
  end

  describe "OODA metrics updates" do
    test "updates latency on OODA cycle complete", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/dashboard/cae")

      send(view.pid, {:ooda_cycle_complete, %{duration: 42}, %{}})

      assert render(view) =~ "42ms"
    end
  end
end
```

### 8.2 Property Tests

```elixir
# Using dual property testing (SC-PROP-023, SC-PROP-024)
defmodule IndrajaalWeb.CAEDashboardPropertyTest do
  use ExUnit.Case
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # PropCheck forall with PC. prefix
  property "readiness score always between 0 and 10" do
    forall metrics <- PC.map(
      ooda_latency: PC.pos_integer(),
      gde_status: PC.oneof([:pending, :active, :learning, :paused]),
      loop_coupling: PC.float(),
      observability: PC.float()
    ) do
      score = ReadinessCalculator.calculate(metrics)
      score >= 0.0 and score <= 10.0
    end
  end

  # ExUnitProperties check all with SD. prefix
  property "agent status transitions are valid" do
    check all(
      old_status <- SD.member_of([:idle, :running, :thinking, :waiting, :error, :offline]),
      new_status <- SD.member_of([:idle, :running, :thinking, :waiting, :error, :offline])
    ) do
      transition = {old_status, new_status}
      assert valid_transition?(transition) or transition in invalid_transitions()
    end
  end
end
```

---

## 9. Deployment Checklist

### 9.1 Prerequisites

- [ ] Phoenix 1.8+ with LiveView 0.20+
- [ ] Telemetry 1.2+
- [ ] OTEL instrumentation configured
- [ ] Zenoh coordinator running
- [ ] PubSub configured

### 9.2 Configuration

```elixir
# config/config.exs
config :indrajaal, :cae_dashboard,
  refresh_interval: 500,
  agent_timeout: 10_000,
  ooda_history_length: 100,
  gde_activity_limit: 20,
  alert_limit: 10

# Enable OTEL metrics
config :opentelemetry,
  span_processor: :batch,
  traces_exporter: :otlp
```

### 9.3 Router Configuration

```elixir
# lib/indrajaal_web/router.ex
scope "/dashboard", IndrajaalWeb do
  pipe_through [:browser, :require_authenticated]

  live "/cae", CAEDashboardLive, :index
end
```

---

## 10. Document Control

| Field | Value |
|-------|-------|
| Version | 1.0.0 |
| Status | DESIGN COMPLETE |
| Author | Agent 10 (C4-STANDARD) |
| Created | 2025-12-29 |
| STAMP Compliance | SC-HMI-001 to SC-HMI-010 |
| Review Required | Architecture Review Board |

### Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | 2025-12-29 | Agent 10 | Initial specification |

---

## Appendix A: ASCII Dashboard Mockup

```
+===========================================================================+
|                        CAE MONITORING DASHBOARD                            |
|  [INDRAJAAL] v5.2.0    Health: 98%    Uptime: 25d 14h    Nodes: 48/50     |
+===========================================================================+
|                                                                            |
| +-------------------------+  +------------------------------------------+ |
| |   CAE READINESS: 7.5/10 |  |            OODA CYCLE METRICS            | |
| | ==================----  |  |                                          | |
| | (Target: 9.5)           |  |  Current Latency: 47ms  Target: <100ms   | |
| |                         |  |  Cycle Count: 1,234     Quality: 92%     | |
| | OODA Speed:    ====---- |  |                                          | |
| | GDE Active:    PENDING  |  |  [Observe] -> [Orient] -> [Decide] -> [Act]|
| | Loop Coupling: 40%      |  |     12ms       15ms        8ms       12ms | |
| | Observability: 100%     |  |                                          | |
| +-------------------------+  +------------------------------------------+ |
|                                                                            |
| +----------------------------------------------------------------------+ |
| |                          AGENT STATUS (50)                            | |
| +----------------------------------------------------------------------+ |
| | EXECUTIVE (1)                                                         | |
| | [*] Exec-001: Executive Agent          - COORDINATING                | |
| |----------------------------------------------------------------------- |
| | DOMAIN (10)                                                           | |
| | [*] Access  [*] Alarms  [*] Analytics  [ ] Video   [!] Dispatch      | |
| | [*] Comm    [*] Core    [*] Policy     [*] Sites   [*] Integration   | |
| |----------------------------------------------------------------------- |
| | FUNCTIONAL (15)                                                       | |
| | [*] FastOODA    [*] Tests      [*] TrainingGym  [ ] GDE   [ ] Bus    | |
| | [*] Cortex      [*] Guardian   [*] Sentinel     [*] CEPAF [*] Mesh   | |
| | ... (5 more)                                                          | |
| |----------------------------------------------------------------------- |
| | WORKERS (24)                                                          | |
| | [*] W01 [*] W02 [*] W03 [*] W04 [ ] W05 [ ] W06 [*] W07 [*] W08      | |
| | [ ] W09 [ ] W10 [ ] W11 [*] W12 [*] W13 [*] W14 [ ] W15 [ ] W16      | |
| | [*] W17 [*] W18 [*] W19 [*] W20 [ ] W21 [ ] W22 [*] W23 [*] W24      | |
| +----------------------------------------------------------------------+ |
|                                                                            |
| +---------------------------+  +---------------------------------------+ |
| |   GDE EVOLUTION STATUS    |  |        CONTROL LOOP HEALTH           | |
| +---------------------------+  +---------------------------------------+ |
| | Status: ENABLED (Manual)  |  | Feedback Loop Coupling: 72%          | |
| |                           |  | ============================--------  | |
| | Proposals Generated:  47  |  |                                       | |
| | Guardian Validated:   42  |  | Components:                           | |
| | Shadow Testing:       38  |  | [*] Sensor Input     - 5ms            | |
| | Promoted:             12  |  | [*] Pattern Matcher  - 12ms           | |
| |                           |  | [*] Decision Engine  - 8ms            | |
| | Current: optimize_auth    |  | [*] Effector Output  - 15ms           | |
| | Fitness: 0.91 / 0.85      |  | [*] Feedback Return  - 7ms            | |
| +---------------------------+  +---------------------------------------+ |
|                                                                            |
| +----------------------------------------------------------------------+ |
| |                           ALERTS (0 Active)                           | |
| | No active alerts - system operating normally                          | |
| +----------------------------------------------------------------------+ |
|                                                                            |
| [EXPORT]  [REFRESH]  [CONFIGURE]  [ACTIONS v]           Last: 14:32:05    |
+===========================================================================+
```

---

**END OF SPECIFICATION**
