defmodule Indrajaal.Core.LiveViewRenderingBenchmarkTest do
  @moduledoc """
  TDG test: Phoenix LiveView component rendering benchmark under 16ms.

  ## WHAT
  Validates simulated LiveView component rendering performance:
  single component render, nested component tree, list rendering,
  diff computation (assigns changes), and frame budget compliance (16ms = 60fps).

  ## WHY
  SC-PRF-050 mandates response < 50ms.
  SC-BRIDGE-003 mandates latency budget 50ms for Zenoh-LiveView bridge.
  SC-HMI-001 mandates Prajna cockpit UI compliance.
  Rendering under 16ms ensures 60fps interactive cockpit experience.

  ## CONSTRAINTS
  - SC-PRF-050: Response < 50ms
  - SC-BRIDGE-003: Latency budget 50ms
  - SC-HMI-001: Cockpit UI compliance
  - SC-PRF-055: No blocking operations in render path
  - SC-VDP-001: Visual data plane performance

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-24 | Claude | Initial implementation — Sprint 88 Wave 7 |
  """

  use ExUnit.Case, async: true
  import ExUnitProperties, except: [property: 2, property: 3]
  alias StreamData, as: SD

  @moduletag :liveview
  @moduletag :benchmark
  @moduletag :rendering
  @moduletag :sprint_88

  # 60fps target
  @frame_budget_ms 16

  describe "single component rendering" do
    test "simple health indicator renders under 16ms" do
      assigns = %{health_score: 0.95, status: :healthy, threats: 0}

      {time_us, html} = :timer.tc(fn -> render_health_indicator(assigns) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms,
             "Render took #{time_ms}ms (budget: #{@frame_budget_ms}ms)"

      assert html =~ "health-indicator"
      assert html =~ "95"
    end

    test "agent status card renders under 16ms" do
      assigns = %{
        agent_id: "AGT-001",
        name: "SecurityAgent",
        status: :active,
        cpu: 23.5,
        memory: 128
      }

      {time_us, html} = :timer.tc(fn -> render_agent_card(assigns) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms
      assert html =~ "AGT-001"
      assert html =~ "SecurityAgent"
    end

    test "alarm row renders under 16ms" do
      assigns = %{
        alarm_id: "ALM-042",
        severity: :critical,
        message: "Intrusion detected",
        timestamp: "2026-03-24T10:00:00Z"
      }

      {time_us, html} = :timer.tc(fn -> render_alarm_row(assigns) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms
      assert html =~ "ALM-042"
      assert html =~ "critical"
    end
  end

  describe "nested component tree rendering" do
    test "dashboard with 5 panels renders under 16ms" do
      assigns = %{
        panels: [
          %{id: "health", title: "System Health", score: 0.92},
          %{id: "agents", title: "Agent Status", count: 50},
          %{id: "alarms", title: "Active Alarms", count: 3},
          %{id: "threats", title: "Threat Level", level: :low},
          %{id: "mesh", title: "Mesh Status", nodes: 14}
        ]
      }

      {time_us, html} = :timer.tc(fn -> render_dashboard(assigns) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms, "Dashboard render took #{time_ms}ms"
      assert html =~ "dashboard"
      assert html =~ "System Health"
      assert html =~ "Mesh Status"
    end

    test "deeply nested 3-level component tree renders under 16ms" do
      assigns = %{
        sections:
          Enum.map(1..3, fn s ->
            %{
              id: "section-#{s}",
              rows:
                Enum.map(1..5, fn r ->
                  %{
                    id: "row-#{s}-#{r}",
                    cells:
                      Enum.map(1..4, fn c ->
                        %{id: "cell-#{s}-#{r}-#{c}", value: "V#{s}#{r}#{c}"}
                      end)
                  }
                end)
            }
          end)
      }

      {time_us, html} = :timer.tc(fn -> render_nested_grid(assigns) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms, "Nested grid render took #{time_ms}ms"
      assert html =~ "section-1"
      assert html =~ "cell-3-5-4"
    end
  end

  describe "list rendering performance" do
    test "50 agent rows render under 16ms" do
      agents =
        Enum.map(1..50, fn i ->
          %{
            id: "AGT-#{String.pad_leading("#{i}", 3, "0")}",
            name: "Agent#{i}",
            status: :active,
            cpu: :rand.uniform(100) / 1.0
          }
        end)

      {time_us, html} = :timer.tc(fn -> render_agent_list(agents) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms, "50 agent list render took #{time_ms}ms"
      assert html =~ "AGT-001"
      assert html =~ "AGT-050"
    end

    test "100 alarm entries render under 16ms" do
      alarms =
        Enum.map(1..100, fn i ->
          %{
            id: "ALM-#{i}",
            severity: Enum.random([:info, :warning, :critical]),
            message: "Alarm #{i}",
            timestamp: "2026-03-24T#{rem(i, 24)}:00:00Z"
          }
        end)

      {time_us, html} = :timer.tc(fn -> render_alarm_list(alarms) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms, "100 alarm list render took #{time_ms}ms"
    end

    test "200 metric rows render under 16ms" do
      metrics =
        Enum.map(1..200, fn i ->
          %{name: "metric_#{i}", value: :rand.uniform(1000) / 10, unit: "ms"}
        end)

      {time_us, html} = :timer.tc(fn -> render_metric_table(metrics) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms, "200 metric rows render took #{time_ms}ms"
    end
  end

  describe "diff computation (assigns change)" do
    test "single field change diffed under 16ms" do
      old_assigns = %{health: 0.90, threats: 2, agents: 50}
      new_assigns = %{health: 0.95, threats: 2, agents: 50}

      {time_us, diff} = :timer.tc(fn -> compute_diff(old_assigns, new_assigns) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms
      assert diff == %{health: 0.95}
    end

    test "no change produces empty diff" do
      assigns = %{a: 1, b: 2, c: 3}
      diff = compute_diff(assigns, assigns)

      assert diff == %{}
    end

    test "all fields changed" do
      old = %{a: 1, b: 2, c: 3}
      new = %{a: 10, b: 20, c: 30}

      diff = compute_diff(old, new)
      assert diff == %{a: 10, b: 20, c: 30}
    end

    test "diff with 100 fields under 16ms" do
      old = Map.new(1..100, fn i -> {:"field_#{i}", i} end)
      new = Map.new(1..100, fn i -> {:"field_#{i}", if(rem(i, 3) == 0, do: i * 2, else: i)} end)

      {time_us, diff} = :timer.tc(fn -> compute_diff(old, new) end)
      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms
      changed_count = map_size(diff)
      # Every 3rd field changed
      assert changed_count == 33
    end
  end

  describe "re-render on diff (partial update)" do
    test "partial re-render only touches changed components" do
      old_assigns = %{health: 0.90, threats: 2, agents: 50}
      new_assigns = %{health: 0.95, threats: 2, agents: 50}

      {time_us, {html, changed_count}} =
        :timer.tc(fn ->
          diff = compute_diff(old_assigns, new_assigns)
          html = render_changed_only(diff, new_assigns)
          {html, map_size(diff)}
        end)

      time_ms = time_us / 1000

      assert time_ms < @frame_budget_ms
      assert changed_count == 1
      assert html =~ "health"
      # Unchanged, not re-rendered
      refute html =~ "threats"
    end
  end

  describe "frame budget compliance" do
    test "worst-case render (full dashboard) under 50ms (SC-PRF-050)" do
      # Full Prajna dashboard: health + 50 agents + 100 alarms + 14 mesh nodes
      assigns = %{
        health: %{score: 0.92, status: :healthy},
        agents: Enum.map(1..50, fn i -> %{id: "A#{i}", status: :active} end),
        alarms: Enum.map(1..100, fn i -> %{id: "ALM#{i}", severity: :warning} end),
        mesh_nodes: Enum.map(1..14, fn i -> %{id: "N#{i}", healthy: true} end)
      }

      {time_us, html} = :timer.tc(fn -> render_full_dashboard(assigns) end)
      time_ms = time_us / 1000

      assert time_ms < 50, "Full dashboard render took #{time_ms}ms (budget: 50ms per SC-PRF-050)"
      assert html =~ "prajna-dashboard"
    end
  end

  describe "property-based rendering" do
    test "property — render time stays within budget for any agent count and health score (SD)" do
      check all(
              n_agents <- SD.integer(1..100),
              health <- SD.float(min: 0.0, max: 1.0)
            ) do
        agents =
          Enum.map(1..n_agents, fn i ->
            %{id: "A#{i}", name: "Agent#{i}", status: :active, cpu: 50.0}
          end)

        {time_us, html} =
          :timer.tc(fn ->
            render_health_indicator(%{health_score: health, status: :ok, threats: 0}) <>
              render_agent_list(agents)
          end)

        time_ms = time_us / 1000
        # Allow generous budget for property tests (up to 50ms)
        assert time_ms < 50
        assert is_binary(html)
      end
    end
  end

  # --- Rendering Helpers ---

  defp render_health_indicator(assigns) do
    score_pct = round(assigns.health_score * 100)
    status_class = if assigns.status == :healthy, do: "green", else: "red"

    """
    <div class="health-indicator #{status_class}">
      <span class="score">#{score_pct}%</span>
      <span class="threats">#{assigns.threats} threats</span>
    </div>
    """
  end

  defp render_agent_card(assigns) do
    """
    <div class="agent-card" id="#{assigns.agent_id}">
      <h4>#{assigns.name}</h4>
      <span class="status">#{assigns.status}</span>
      <span class="cpu">CPU: #{assigns.cpu}%</span>
      <span class="memory">MEM: #{assigns.memory}MB</span>
    </div>
    """
  end

  defp render_alarm_row(assigns) do
    """
    <tr class="alarm-row #{assigns.severity}">
      <td>#{assigns.alarm_id}</td>
      <td class="severity">#{assigns.severity}</td>
      <td>#{assigns.message}</td>
      <td>#{assigns.timestamp}</td>
    </tr>
    """
  end

  defp render_dashboard(assigns) do
    panels_html =
      Enum.map_join(assigns.panels, "\n", fn panel ->
        """
        <div class="panel" id="#{panel.id}">
          <h3>#{panel.title}</h3>
          <div class="panel-content">#{inspect(Map.drop(panel, [:id, :title]))}</div>
        </div>
        """
      end)

    """
    <div class="dashboard">#{panels_html}</div>
    """
  end

  defp render_nested_grid(assigns) do
    sections_html =
      Enum.map_join(assigns.sections, "\n", fn section ->
        rows_html =
          Enum.map_join(section.rows, "\n", fn row ->
            cells_html =
              Enum.map_join(row.cells, "", fn cell ->
                "<td id=\"#{cell.id}\">#{cell.value}</td>"
              end)

            "<tr id=\"#{row.id}\">#{cells_html}</tr>"
          end)

        "<table id=\"#{section.id}\">#{rows_html}</table>"
      end)

    "<div class=\"grid\">#{sections_html}</div>"
  end

  defp render_agent_list(agents) do
    rows =
      Enum.map_join(agents, "\n", fn a ->
        "<tr><td>#{a.id}</td><td>#{a.name}</td><td>#{a.status}</td><td>#{a.cpu}%</td></tr>"
      end)

    "<table class=\"agent-list\">#{rows}</table>"
  end

  defp render_alarm_list(alarms) do
    rows =
      Enum.map_join(alarms, "\n", fn a ->
        render_alarm_row(a)
      end)

    "<table class=\"alarm-list\">#{rows}</table>"
  end

  defp render_metric_table(metrics) do
    rows =
      Enum.map_join(metrics, "\n", fn m ->
        "<tr><td>#{m.name}</td><td>#{m.value}</td><td>#{m.unit}</td></tr>"
      end)

    "<table class=\"metric-table\">#{rows}</table>"
  end

  defp render_changed_only(diff, full_assigns) do
    Enum.map_join(diff, "\n", fn {key, _value} ->
      case key do
        :health ->
          render_health_indicator(
            Map.put(%{status: :ok, threats: 0}, :health_score, full_assigns.health)
          )

        :threats ->
          "<span class=\"threats\">#{full_assigns.threats}</span>"

        :agents ->
          "<span class=\"agents\">#{full_assigns.agents}</span>"

        other ->
          "<span>#{other}: #{Map.get(full_assigns, other)}</span>"
      end
    end)
  end

  defp render_full_dashboard(assigns) do
    health_html =
      render_health_indicator(%{
        health_score: assigns.health.score,
        status: assigns.health.status,
        threats: 0
      })

    agents_html =
      render_agent_list(Enum.map(assigns.agents, &Map.merge(&1, %{name: "A", cpu: 0.0})))

    alarms_html =
      render_alarm_list(
        Enum.map(assigns.alarms, &Map.merge(&1, %{message: "alarm", timestamp: "now"}))
      )

    mesh_html =
      Enum.map_join(assigns.mesh_nodes, "", fn n ->
        "<div class=\"node #{if n.healthy, do: "up", else: "down"}\">#{n.id}</div>"
      end)

    """
    <div class="prajna-dashboard">
      #{health_html}
      #{agents_html}
      #{alarms_html}
      <div class="mesh">#{mesh_html}</div>
    </div>
    """
  end

  # --- Diff Helpers ---

  defp compute_diff(old_assigns, new_assigns) do
    new_assigns
    |> Enum.filter(fn {key, value} -> Map.get(old_assigns, key) != value end)
    |> Map.new()
  end
end
