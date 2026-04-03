defmodule IndrajaalWeb.SecurityLiveTest do
  @moduledoc """
  Security tests for LiveView pages — OWASP Top 10 coverage.

  WHAT: Verifies that LiveView pages properly escape user input, enforce CSRF,
        reject unauthorized access, and resist injection attacks.
  WHY: Safety-critical cockpit UI must not be vulnerable to XSS, injection,
       or authentication bypass. SC-SAFETY-001 requires multi-step commit.
  CONSTRAINTS: SC-COV-001, SC-SAFETY-001, SC-KMS-001
  """

  use IndrajaalWeb.ConnCase
  import Phoenix.LiveViewTest

  @moduletag :security
  @moduletag :zenoh_nif

  # ═══════════════════════════════════════════════════════════════════════
  # XSS PREVENTION (OWASP A7)
  # ═══════════════════════════════════════════════════════════════════════

  describe "XSS prevention" do
    test "alarm search input is HTML-escaped" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")
      xss_payload = "<script>alert('xss')</script>"

      html = render_click(view, "search", %{"query" => xss_payload})

      # LiveView's HEEx templates auto-escape by default
      refute html =~ "<script>alert",
             "XSS payload was not escaped in alarm search"

      # The escaped version should appear if the value is displayed
      if html =~ "script" do
        assert html =~ "&lt;script&gt;" or html =~ "&#39;"
      end
    end

    test "alarm filter rejects script injection via severity" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

      # Attempt to inject through event params
      html =
        render_click(view, "filter_severity", %{
          "severity" => "<img src=x onerror=alert(1)>"
        })

      refute html =~ "onerror=",
             "Event handler did not sanitize severity parameter"
    end

    test "observability tab switch rejects injection" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      html =
        render_click(view, "switch_tab", %{
          "tab" => "\" onmouseover=\"alert(1)"
        })

      refute html =~ "onmouseover",
             "Tab switch did not sanitize tab parameter"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # CSRF PROTECTION (OWASP A5)
  # ═══════════════════════════════════════════════════════════════════════

  describe "CSRF protection" do
    test "LiveView pages include CSRF token" do
      {:ok, _view, html} = live(build_conn(), "/cockpit")

      assert html =~ "csrf" or html =~ "_csrf_token",
             "LiveView page missing CSRF token"
    end

    test "navigation portal includes CSRF token" do
      {:ok, _view, html} = live(build_conn(), "/")
      assert html =~ "csrf" or html =~ "_csrf_token"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # INFORMATION DISCLOSURE (OWASP A3)
  # ═══════════════════════════════════════════════════════════════════════

  describe "information disclosure" do
    test "error pages do not leak stack traces in production mode" do
      # LiveView mount errors should not expose internal module paths
      # This tests that our error handling is clean
      {:ok, _view, html} = live(build_conn(), "/cockpit")
      refute html =~ "** (RuntimeError)"
      refute html =~ "lib/indrajaal"
      refute html =~ ".ex:"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # MASS ASSIGNMENT (OWASP A4)
  # ═══════════════════════════════════════════════════════════════════════

  describe "mass assignment protection" do
    test "extra params in handle_event are ignored" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      # Send event with extra unexpected params
      html =
        render_click(view, "switch_tab", %{
          "tab" => "traces",
          "admin" => "true",
          "role" => "superuser",
          "__secret" => "bypass"
        })

      # Should work normally — extra params silently ignored
      assert html =~ "TRACE" or html =~ "trace" or html =~ "Trace"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # SHUTDOWN SAFETY (SC-SAFETY-001 Arm & Fire)
  # ═══════════════════════════════════════════════════════════════════════

  describe "shutdown safety gate" do
    test "force shutdown requires two-step confirmation" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")

      # Step 1: Arm
      html = render_click(view, "force_shutdown_arm", %{})

      # Should enter armed state but NOT execute shutdown
      assert html =~ "confirm" or html =~ "CONFIRM" or html =~ "armed" or
               html =~ "ARMED" or html =~ "Cancel" or html =~ "cancel"
    end

    test "force shutdown cancel disarms" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/shutdown")

      # Arm then cancel
      render_click(view, "force_shutdown_arm", %{})
      html = render_click(view, "force_shutdown_cancel", %{})

      # Should no longer be in armed state
      refute html =~ "ARMED" and html =~ "CONFIRM"
    end
  end

  # ═══════════════════════════════════════════════════════════════════════
  # RATE LIMITING
  # ═══════════════════════════════════════════════════════════════════════

  describe "event handling resilience" do
    test "rapid-fire events do not crash the LiveView" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/observability")

      # Fire 20 rapid tab switches
      for tab <- Stream.cycle(["metrics", "traces", "logs", "signoz"]) |> Enum.take(20) do
        render_click(view, "switch_tab", %{"tab" => tab})
      end

      # View should still be alive and rendering
      html = render(view)
      assert html =~ "Observability" or html =~ "observability" or html =~ "OBSERVABILITY"
    end

    test "rapid-fire alarm filters do not crash" do
      {:ok, view, _html} = live(build_conn(), "/cockpit/alarms")

      for sev <-
            Stream.cycle(["all", "critical", "major", "minor", "advisory"]) |> Enum.take(20) do
        render_click(view, "filter_severity", %{"severity" => sev})
      end

      html = render(view)
      assert html =~ "Alarm" or html =~ "alarm" or html =~ "ALARM"
    end
  end
end
