defmodule IndrajaalWeb.ResilienceLiveTest do
  @moduledoc """
  Resilience tests for LiveView pages — infrastructure failure scenarios.

  WHAT: Verifies that LiveView pages handle PubSub failures, malformed messages,
        and rapid reconnection gracefully without crashing.
  WHY: Safety-critical cockpits must degrade gracefully under adverse conditions.
       A crashed LiveView during an alarm storm could mean missed critical alerts.
  CONSTRAINTS: SC-COV-001, SC-CIRCUIT-001, SC-CIRCUIT-002, SC-HA-001
  """

  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest

  @moduletag :resilience
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # MALFORMED MESSAGE RESILIENCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "malformed PubSub message handling" do
    test "observability survives malformed metric update" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      # Send malformed messages through PubSub
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:metrics",
        {:metric_update, nil, nil}
      )

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:metrics",
        :garbage_message
      )

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:metrics",
        {:unexpected_tuple, 1, 2, 3, 4}
      )

      # Wait for messages to be processed
      Process.sleep(50)

      # View should still be alive
      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "alarms survives malformed alarm event" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

      # Send various malformed messages
      for msg <- [
            {:new_alarm, nil},
            {:new_alarm, "not_a_struct"},
            {:metric_updated, nil, nil},
            :random_atom,
            42,
            {1, 2, 3}
          ] do
        Phoenix.PubSub.broadcast(Indrajaal.PubSub, "prajna:alarms", msg)
      end

      Process.sleep(50)

      html = render(view)
      assert is_binary(html)
    end

    test "cluster survives malformed cluster event" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/cluster")

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:cluster",
        {:cluster_event, nil}
      )

      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        "prajna:cluster",
        "invalid"
      )

      Process.sleep(50)

      html = render(view)
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RAPID RECONNECTION
  # ═══════════════════════════════════════════════════════════════════════

  describe "rapid mount/unmount resilience" do
    test "mounting observability 5 times in succession" do
      for _i <- 1..5 do
        {:ok, view, html} = live(build_conn(), "/cockpit/observability")
        assert is_binary(html)
        assert String.length(html) > 100

        # Explicitly stop the view by navigating away
        try do
          render_click(view, "switch_tab", %{"tab" => "metrics"})
        rescue
          _ -> :ok
        end
      end
    end

    test "mounting alarms 5 times in succession" do
      for _i <- 1..5 do
        {:ok, _view, html} = live(build_conn(), "/cockpit/alarms")
        assert is_binary(html)
      end
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # CONCURRENT EVENTS
  # ═══════════════════════════════════════════════════════════════════════

  describe "concurrent event resilience" do
    test "simultaneous PubSub and user events on observability" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      # Fire PubSub and user events rapidly
      for i <- 1..10 do
        tab = Enum.at(["metrics", "traces", "logs", "signoz"], rem(i, 4))
        render_click(view, "switch_tab", %{"tab" => tab})

        Phoenix.PubSub.broadcast(
          Indrajaal.PubSub,
          "prajna:metrics",
          {:metric_update, :request_rate, %{value: i * 10.0}}
        )
      end

      Process.sleep(50)

      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # TIMER RESILIENCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "timer resilience" do
    test "observability survives past multiple refresh cycles" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      # Wait for 3 refresh cycles (500ms each = 1.5s)
      Process.sleep(1_600)

      html = render(view)
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "cockpit dashboard survives past multiple refresh cycles" do
      {:ok, view, _html} = live(build_conn(), "/cockpit")

      # Wait for 3 refresh cycles (500ms each = 1.5s)
      Process.sleep(1_600)

      html = render(view)
      assert is_binary(html)
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # EMPTY STATE RESILIENCE
  # ═══════════════════════════════════════════════════════════════════════

  describe "empty state handling" do
    test "observability renders with empty metrics" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/observability")
      # Should render even with default/empty metrics
      assert is_binary(html)
      assert String.length(html) > 100
    end

    test "alarms renders with no alarms" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/alarms")
      assert is_binary(html)
    end

    test "cluster renders with no nodes" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/cluster")
      assert is_binary(html)
    end

    test "sentinel renders with no threats" do
      {:ok, _view, html} = live(build_conn(), "/cockpit/sentinel")
      assert is_binary(html)
    end
  end
end
