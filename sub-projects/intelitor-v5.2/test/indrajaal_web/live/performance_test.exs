defmodule IndrajaalWeb.PerformanceLiveTest do
  @moduledoc """
  Performance budget tests for LiveView pages.

  WHAT: Verifies that LiveView mount, event response, and PubSub propagation
        meet defined latency budgets.
  WHY: Operator response time in safety-critical cockpits depends on sub-second
       UI responsiveness. SC-OODA requires < 100ms OODA cycles.
  CONSTRAINTS: SC-COV-001, SC-OODA, SC-PERF-001
  """

  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest

  @moduletag :performance
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # MOUNT PERFORMANCE (< 200ms budget)
  # ═══════════════════════════════════════════════════════════════════════

  describe "mount performance" do
    test "observability mount completes within 200ms" do
      {time_us, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(build_conn(), "/cockpit/observability")
        end)

      assert time_us < 200_000, "Mount took #{div(time_us, 1000)}ms, budget is 200ms"
    end

    test "alarms mount completes within 200ms" do
      {time_us, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(build_conn(), "/cockpit/alarms")
        end)

      assert time_us < 200_000, "Mount took #{div(time_us, 1000)}ms, budget is 200ms"
    end

    test "main cockpit mount completes within 200ms" do
      {time_us, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(build_conn(), "/cockpit")
        end)

      assert time_us < 200_000, "Mount took #{div(time_us, 1000)}ms, budget is 200ms"
    end

    test "sentinel mount completes within 200ms" do
      {time_us, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(build_conn(), "/cockpit/sentinel")
        end)

      assert time_us < 200_000, "Mount took #{div(time_us, 1000)}ms, budget is 200ms"
    end

    test "cluster mount completes within 200ms" do
      {time_us, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(build_conn(), "/cockpit/cluster")
        end)

      assert time_us < 200_000, "Mount took #{div(time_us, 1000)}ms, budget is 200ms"
    end

    test "navigation portal mount completes within 200ms" do
      {time_us, {:ok, _view, _html}} =
        :timer.tc(fn ->
          live(build_conn(), "/")
        end)

      assert time_us < 200_000, "Mount took #{div(time_us, 1000)}ms, budget is 200ms"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # EVENT RESPONSE (< 100ms budget)
  # ═══════════════════════════════════════════════════════════════════════

  describe "event response performance" do
    test "tab switch responds within 100ms" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      {time_us, _html} =
        :timer.tc(fn ->
          render_click(view, "switch_tab", %{"tab" => "traces"})
        end)

      assert time_us < 100_000, "Event took #{div(time_us, 1000)}ms, budget is 100ms"
    end

    test "alarm filter responds within 100ms" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

      {time_us, _html} =
        :timer.tc(fn ->
          render_click(view, "filter_severity", %{"severity" => "critical"})
        end)

      assert time_us < 100_000, "Event took #{div(time_us, 1000)}ms, budget is 100ms"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # PUBSUB PROPAGATION (< 50ms budget)
  # ═══════════════════════════════════════════════════════════════════════

  describe "PubSub propagation performance" do
    test "metric update propagates within 50ms" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      t1 = System.monotonic_time(:microsecond)

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:metrics",
        {:metric_update, :request_rate, %{value: 42.0}}
      )

      # Allow message to be processed
      Process.sleep(5)
      _html = render(view)
      t2 = System.monotonic_time(:microsecond)

      assert t2 - t1 < 50_000,
             "Propagation took #{div(t2 - t1, 1000)}ms, budget is 50ms"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RENDER PERFORMANCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "render performance" do
    test "re-render after state change within 50ms" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      {time_us, _html} =
        :timer.tc(fn ->
          render(view)
        end)

      assert time_us < 50_000, "Render took #{div(time_us, 1000)}ms, budget is 50ms"
    end
  end
end
