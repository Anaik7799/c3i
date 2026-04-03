defmodule IndrajaalWeb.Prajna.CopilotLiveTest do
  @moduledoc """
  LiveView tests for PRAJNA AI Copilot screen.

  WHAT: Verifies all UI interfaces and event handlers for the AI Copilot.

  CONSTRAINTS:
    - SC-AI-001: AI suggestions are ADVISORY only
    - SC-AI-002: Confidence scores displayed
    - TDG-PRAJNA-003: All interfaces must be testable

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 1.0.0 |
  | Created | 2025-12-28 |
  | Author | Cybernetic Architect |
  """

  use IndrajaalWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  describe "mount/3" do
    test "renders the AI Copilot page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "AI COPILOT"
      assert html =~ "CURRENT INSIGHTS"
      assert html =~ "ASK COPILOT"
    end

    test "displays initial insights", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      # Check for insight types from init_insights/0
      assert html =~ "SUMMARY"
      assert html =~ "ANOMALY"
      assert html =~ "PREDICTION"
      assert html =~ "CORRELATION"
    end

    test "displays confidence scores (SC-AI-002)", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "Confidence:"
      assert html =~ ~r/Confidence: \d+%/
    end

    test "displays advisory notice (SC-AI-001)", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "ADVISORY only"
      assert html =~ "Human operator makes all final decisions"
    end

    test "displays LLM status", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "Local Analytics:"
      assert html =~ "LLM (Claude 3.5):"
    end
  end

  describe "analyze_now event" do
    test "triggers analysis and shows flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      result = view |> element("button", "ANALYZE NOW") |> render_click()

      assert result =~ "AI analysis triggered"
    end
  end

  describe "toggle_llm event" do
    test "toggles LLM on/off", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cockpit/ai-copilot")

      # Initial state: LLM ON
      assert html =~ "LLM: ON"

      # Toggle off
      result = view |> element("button[phx-click=toggle_llm]") |> render_click()
      assert result =~ "LLM: OFF"
      assert result =~ "LLM disabled"

      # Toggle back on
      result = view |> element("button[phx-click=toggle_llm]") |> render_click()
      assert result =~ "LLM: ON"
      assert result =~ "LLM enabled"
    end
  end

  describe "select_insight event" do
    test "selects an insight", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      # Click on first insight
      result =
        view
        |> element("[phx-click=select_insight][phx-value-id='INS-001']")
        |> render_click()

      # Should highlight the selected insight (bg-gray-700 class)
      assert result =~ "bg-gray-700"
    end
  end

  describe "dismiss_insight event" do
    test "removes insight from list", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cockpit/ai-copilot")

      # Verify insight exists
      assert html =~ "INS-002"
      assert html =~ "High CPU on app-03"

      # Dismiss it
      result =
        view
        |> element("button[phx-click=dismiss_insight][phx-value-id='INS-002']")
        |> render_click()

      # Should be removed
      refute result =~ "High CPU on app-03"
    end
  end

  describe "submit_query event" do
    test "processes CPU query", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      result =
        view
        |> form("form", %{query: "What's causing high CPU?"})
        |> render_submit()

      assert result =~ "Response:"
      assert result =~ "CPU"
      assert result =~ ~r/Confidence: \d+%/
    end

    test "processes memory query", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      result =
        view
        |> form("form", %{query: "How is memory usage?"})
        |> render_submit()

      assert result =~ "Response:"
      assert result =~ "Memory"
    end

    test "handles unknown query gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      result =
        view
        |> form("form", %{query: "What is the weather?"})
        |> render_submit()

      assert result =~ "Response:"
      # Note: apostrophe is HTML-encoded as &#39;
      assert result =~ "find a specific pattern"
    end
  end

  describe "clear_query event" do
    test "clears query and result", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      # First submit a query
      view
      |> form("form", %{query: "CPU status"})
      |> render_submit()

      # Then clear it
      result =
        view
        |> element("button[phx-click=clear_query]")
        |> render_click()

      # Query result should be cleared (no Response: section)
      refute result =~ "Response:"
    end
  end

  describe "handle_info :refresh" do
    test "refreshes insights on timer", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cockpit/ai-copilot")

      # Simulate refresh message
      send(view.pid, :refresh)

      # Should still render correctly
      html = render(view)
      assert html =~ "CURRENT INSIGHTS"
    end
  end

  describe "handle_info {:new_insight, insight}" do
    test "adds new insight to list", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cockpit/ai-copilot")

      # Verify the new insight title is not present initially
      refute html =~ "New Test Insight"

      # Send new insight
      new_insight = %{
        id: "INS-NEW",
        type: :anomaly,
        title: "New Test Insight",
        description: "This is a new test insight",
        confidence: 0.88,
        related_node: "test-node",
        action_items: ["Action 1"],
        expires: "10m",
        created_at: DateTime.utc_now()
      }

      send(view.pid, {:new_insight, new_insight})

      html = render(view)

      # Should contain the new insight
      assert html =~ "New Test Insight"
      assert html =~ "INS-NEW"
    end
  end

  describe "insight summary sidebar" do
    test "displays insight counts by type", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "Anomalies:"
      assert html =~ "Predictions:"
      assert html =~ "Recommendations:"
      assert html =~ "Correlations:"
    end
  end

  describe "navigation" do
    test "has navigation tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "OVERVIEW"
      assert html =~ "MESH"
      assert html =~ "ALARMS"
      assert html =~ "COMMANDS"
      assert html =~ "AI COPILOT"
      assert html =~ "CONTAINERS"
    end

    test "AI Copilot tab is highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "text-blue-400 border-b-2 border-blue-400"
    end
  end

  describe "keyboard shortcuts hint" do
    test "displays keyboard shortcuts in footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/cockpit/ai-copilot")

      assert html =~ "[A] Analyze"
      assert html =~ "[D] Dismiss"
      assert html =~ "[R] Apply Recommendation"
      assert html =~ "[/] Query"
    end
  end
end
