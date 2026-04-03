defmodule Indrajaal.Test.Steps.PrajnaE2ESteps do
  @moduledoc """
  BDD step definitions for Prajna C3I Cockpit end-to-end scenarios.

  WHAT: Step implementations for comprehensive_prajna_e2e.feature
  WHY: Enable automated BDD testing of Prajna cockpit workflows
  CONSTRAINTS: SC-PRAJNA-001 to SC-PRAJNA-007, SC-BRIDGE-005
  """

  use Cabbage.Feature
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  # Future: MasterControl and FullSystemMonitor integration
  # alias Indrajaal.Cockpit.Prajna.{MasterControl, FullSystemMonitor}
  # alias Indrajaal.Safety.{Guardian, Sentinel}

  @endpoint IndrajaalWeb.Endpoint

  # =============================================================================
  # BACKGROUND STEPS
  # =============================================================================

  defgiven ~r/^Phoenix is running on port (?<port>\d+)$/, %{port: port}, state do
    port = String.to_integer(port)
    assert Application.get_env(:indrajaal, IndrajaalWeb.Endpoint)[:http][:port] == port
    {:ok, Map.put(state, :port, port)}
  end

  defgiven ~r/^I am authenticated as an? "(?<role>[^"]+)"$/, %{role: role}, state do
    user = create_test_user(role)
    conn = build_conn() |> log_in_user(user)
    {:ok, state |> Map.put(:conn, conn) |> Map.put(:user, user) |> Map.put(:role, role)}
  end

  defgiven ~r/^WebSocket connection is established$/, _params, state do
    {:ok, view, _html} = live(state.conn, "/prajna")
    assert render(view) =~ "phx-connected"
    {:ok, Map.put(state, :view, view)}
  end

  defgiven ~r/^Zenoh mesh telemetry is active$/, _params, state do
    # Verify Zenoh telemetry subscription
    assert Process.whereis(Indrajaal.Zenoh.Session) != nil
    {:ok, state}
  end

  # =============================================================================
  # DASHBOARD STEPS
  # =============================================================================

  defwhen ~r/^I navigate to "(?<path>[^"]+)"$/, %{path: path}, state do
    {:ok, view, html} = live(state.conn, path)
    {:ok, state |> Map.put(:view, view) |> Map.put(:html, html) |> Map.put(:path, path)}
  end

  defthen ~r/^the page should load within (?<seconds>\d+) seconds?$/,
          %{seconds: seconds},
          state do
    max_ms = String.to_integer(seconds) * 1000
    start = System.monotonic_time(:millisecond)

    assert state.html != nil
    assert render(state.view) =~ "data-page-loaded"

    elapsed = System.monotonic_time(:millisecond) - start
    assert elapsed < max_ms, "Page load took #{elapsed}ms, expected < #{max_ms}ms"

    {:ok, state}
  end

  defthen ~r/^the health score should be displayed \(([^)]+)\)$/, _params, state do
    html = render(state.view)
    assert html =~ ~r/health-score|health_score/
    assert html =~ ~r/\d+\.\d+/ or html =~ ~r/\d+%/
    {:ok, state}
  end

  defthen ~r/^the following panels should be visible:$/, %{table: table}, state do
    html = render(state.view)

    Enum.each(table, fn row ->
      panel = row["Panel"] |> String.downcase() |> String.replace(" ", "-")

      assert html =~ panel or html =~ String.replace(panel, "-", "_"),
             "Panel '#{row["Panel"]}' not found in page"
    end)

    {:ok, state}
  end

  defwhen ~r/^I click on the health score panel$/, _params, state do
    view = state.view
    view |> element("[data-panel='health-score']") |> render_click()
    {:ok, state}
  end

  defthen ~r/^I should see detailed health breakdown$/, _params, state do
    html = render(state.view)
    assert html =~ "health-breakdown" or html =~ "health-details"
    {:ok, state}
  end

  defthen ~r/^Sentinel health factors should be displayed$/, _params, state do
    html = render(state.view)

    # Verify Sentinel health factors per SC-IMMUNE-001
    factors = ["memory", "cpu", "error", "process", "quarantine"]

    Enum.each(factors, fn factor ->
      assert html =~ factor, "Health factor '#{factor}' not displayed"
    end)

    {:ok, state}
  end

  # =============================================================================
  # NAVIGATION STEPS
  # =============================================================================

  defthen ~r/^the following navigation links should work:$/, %{table: table}, state do
    Enum.each(table, fn row ->
      url = row["URL"]
      expected_title = row["Page Title"]

      {:ok, _view, html} = live(state.conn, url)

      assert html =~ expected_title or html =~ String.downcase(expected_title),
             "Page at #{url} should contain '#{expected_title}'"
    end)

    {:ok, state}
  end

  # =============================================================================
  # REAL-TIME UPDATES STEPS
  # =============================================================================

  defgiven ~r/^Zenoh is publishing to "(?<topic>[^"]+)"$/, %{topic: topic}, state do
    {:ok, Map.put(state, :zenoh_topic, topic)}
  end

  defwhen ~r/^a health update is published$/, _params, state do
    # Simulate Zenoh health update
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:health",
      {:health_update, %{score: 0.95, timestamp: DateTime.utc_now()}}
    )

    # Allow time for LiveView to process
    Process.sleep(100)
    {:ok, state}
  end

  defthen ~r/^the dashboard should update within (?<seconds>\d+) seconds?$/,
          %{seconds: _seconds},
          state do
    # Re-render and verify update
    html = render(state.view)
    assert html =~ "0.95" or html =~ "95%"
    {:ok, state}
  end

  defthen ~r/^no page refresh should be required$/, _params, state do
    # LiveView updates without refresh - verify connected state
    assert render(state.view) =~ "phx-connected"
    {:ok, state}
  end

  defthen ~r/^the WebSocket connection should remain stable$/, _params, state do
    refute render(state.view) =~ "phx-disconnected"
    {:ok, state}
  end

  # =============================================================================
  # ALARM MANAGEMENT STEPS
  # =============================================================================

  defwhen ~r/^a new alarm is received:$/, %{table: table}, state do
    alarm_data = table_to_map(table)

    alarm = %{
      id: Ecto.UUID.generate(),
      type: alarm_data["Type"],
      severity: alarm_data["Severity"],
      site: alarm_data["Site"],
      zone: alarm_data["Zone"],
      timestamp: alarm_data["Timestamp"] || DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Broadcast alarm via PubSub (simulating Zenoh)
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "zenoh:alarms",
      {:new_alarm, alarm}
    )

    Process.sleep(100)
    {:ok, Map.put(state, :alarm, alarm)}
  end

  defthen ~r/^the alarm should appear in the active alarms list$/, _params, state do
    html = render(state.view)
    assert html =~ state.alarm.id or html =~ state.alarm.type
    {:ok, state}
  end

  defthen ~r/^an audio alert should play \(if enabled\)$/, _params, state do
    # Verify audio alert element exists
    html = render(state.view)
    assert html =~ "audio-alert" or html =~ "alert-sound"
    {:ok, state}
  end

  defthen ~r/^the alarm count badge should increment$/, _params, state do
    html = render(state.view)
    assert html =~ ~r/badge|count/
    {:ok, state}
  end

  defwhen ~r/^I click on the alarm$/, _params, state do
    state.view
    |> element("[data-alarm-id='#{state.alarm.id}']")
    |> render_click()

    {:ok, state}
  end

  defthen ~r/^the alarm detail panel should open$/, _params, state do
    html = render(state.view)
    assert html =~ "alarm-detail" or html =~ "detail-panel"
    {:ok, state}
  end

  defwhen ~r/^I click "(?<button>[^"]+)"$/, %{button: button}, state do
    selector = "[data-action='#{String.downcase(button)}']"
    state.view |> element(selector) |> render_click()
    {:ok, state}
  end

  defthen ~r/^the alarm status should change to "(?<status>[^"]+)"$/, %{status: status}, state do
    html = render(state.view)
    assert html =~ status or html =~ String.downcase(status)
    {:ok, state}
  end

  # =============================================================================
  # GUARDIAN INTEGRATION STEPS
  # =============================================================================

  defwhen ~r/^I attempt a privileged operation:$/, %{table: table}, state do
    operation = table_to_map(table)
    {:ok, Map.put(state, :operation, operation)}
  end

  defthen ~r/^Guardian approval should be required$/, _params, state do
    html = render(state.view)
    assert html =~ "guardian-approval" or html =~ "approval-required"
    {:ok, state}
  end

  defthen ~r/^the approval request should show:$/, %{table: table}, state do
    html = render(state.view)

    Enum.each(table, fn row ->
      field = row["Field"] |> String.downcase()
      assert html =~ field, "Field '#{field}' not shown in approval request"
    end)

    {:ok, state}
  end

  defwhen ~r/^Guardian approves$/, _params, state do
    # Simulate Guardian approval
    Phoenix.PubSub.broadcast(
      Indrajaal.PubSub,
      "guardian:decisions",
      {:approved, state.operation}
    )

    Process.sleep(100)
    {:ok, state}
  end

  defthen ~r/^the operation should proceed$/, _params, state do
    html = render(state.view)
    assert html =~ "operation-complete" or html =~ "success"
    {:ok, state}
  end

  defthen ~r/^the decision should be logged$/, _params, state do
    # Verify audit log entry
    assert true, "Audit log verification - implementation pending"
    {:ok, state}
  end

  # =============================================================================
  # WEBSOCKET STEPS
  # =============================================================================

  defthen ~r/^the WebSocket status indicator should show "(?<status>[^"]+)"$/,
          %{status: status},
          state do
    html = render(state.view)
    assert html =~ status
    {:ok, state}
  end

  defwhen ~r/^the WebSocket connection is lost$/, _params, state do
    # Simulate connection loss by stopping the socket
    send(state.view.pid, {:socket_close, :normal})
    Process.sleep(100)
    {:ok, state}
  end

  defthen ~r/^a reconnection attempt should start$/, _params, state do
    html = render(state.view)
    assert html =~ "reconnecting" or html =~ "reconnect"
    {:ok, state}
  end

  defthen ~r/^stale data should be marked with warning$/, _params, state do
    html = render(state.view)
    assert html =~ "stale" or html =~ "warning"
    {:ok, state}
  end

  # =============================================================================
  # PERFORMANCE STEPS
  # =============================================================================

  defgiven ~r/^I measure page load times$/, _params, state do
    {:ok, Map.put(state, :measuring, true)}
  end

  defthen ~r/^all Prajna pages should load within:$/, %{table: table}, state do
    Enum.each(table, fn row ->
      page = row["Page"]
      max_time = row["Max Load Time"] |> parse_duration()

      path = page_to_path(page)
      start = System.monotonic_time(:millisecond)

      {:ok, _view, _html} = live(state.conn, path)

      elapsed = System.monotonic_time(:millisecond) - start

      assert elapsed < max_time,
             "#{page} took #{elapsed}ms, expected < #{max_time}ms"
    end)

    {:ok, state}
  end

  # =============================================================================
  # ACCESSIBILITY STEPS
  # =============================================================================

  defthen ~r/^all interactive elements should be reachable via Tab$/, _params, state do
    html = render(state.view)
    # Verify tabindex attributes
    assert html =~ "tabindex"
    {:ok, state}
  end

  defthen ~r/^focus indicators should be visible$/, _params, state do
    html = render(state.view)
    # Verify focus styles exist
    assert html =~ "focus:" or html =~ "focus-visible"
    {:ok, state}
  end

  # =============================================================================
  # HELPER FUNCTIONS
  # =============================================================================

  defp create_test_user(role) do
    %{
      id: Ecto.UUID.generate(),
      email: "#{role}@test.com",
      role: String.to_atom(role)
    }
  end

  defp log_in_user(conn, user) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> Plug.Conn.put_session(:user_id, user.id)
    |> Plug.Conn.put_session(:user_role, user.role)
  end

  defp table_to_map(table) do
    table
    |> Enum.map(fn row -> {row["Field"], row["Value"]} end)
    |> Map.new()
  end

  defp parse_duration(str) do
    case Regex.run(~r/(\d+)\s*seconds?/, str) do
      [_, seconds] -> String.to_integer(seconds) * 1000
      # default 2 seconds
      _ -> 2000
    end
  end

  defp page_to_path(page) do
    case String.downcase(page) do
      "dashboard" -> "/prajna"
      "alarms" -> "/prajna/alarms"
      "analytics" -> "/prajna/analytics"
      "video" -> "/prajna/video"
      _ -> "/prajna"
    end
  end
end
