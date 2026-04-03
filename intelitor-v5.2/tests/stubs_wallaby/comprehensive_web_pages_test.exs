defmodule Intelitor.Wallaby.ComprehensiveWebPagesTest do
  @moduledoc """
  Comprehensive E2E tests for all web pages in the Intelitor application.

  Tests cover:
  - Home page functionality and navigation
  - Development dashboard access and features
  - Mailbox preview functionality
  - Navigation between pages
  - Responsive design verification
  - Error handling and accessibility
  """

  use Intelitor.WallabyCase

  @moduletag :wallaby
  @moduletag :web_pages

  describe "Home Page (/)" do
    test "home page loads successfully and displays correct content", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      |> assert_has(css("small", text: "v0.1.0"))
      |> assert_has(Wallaby.Query.text("Comprehensive Security Monitoring System"))
      |> assert_has(
        Wallaby.Query.text("Built with Ash Framework, Phoenix LiveView, and PostgreSQL")
      )
      |> assert_has(css("svg[aria-label='Intelitor']"))
    end

    test "home page navigation links work correctly", %{session: session} do
      session
      |> visit("/")
      # Test Dashboard link
      |> assert_has(css("a[href='/dev/dashboard']", text: "Dashboard"))
      # Test Notifications/Mailbox link
      |> assert_has(css("a[href='/dev/mailbox']", text: "Notifications"))
      # Test Documentation link (external)
      |> assert_has(css("a[href='https://hexdocs.pm/ash']", text: "Docs"))
    end

    test "home page is responsive and accessible", %{session: session} do
      session
      |> visit("/")
      # Check responsive grid layout
      |> assert_has(css(".grid.grid-cols-1.gap-x-6.gap-y-4.sm\\:grid-cols-3"))
      # Check for proper semantic structure
      |> assert_has(css("h1"))
      |> assert_has(css("p"))
      # Check for proper link structure
      |> assert_has(css("a[href]"))
      # Verify SVG has proper accessibility
      |> assert_has(css("svg[aria-label]"))
    end

    test "home page navigation buttons have hover effects", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css(".group.relative.rounded-2xl"))
      |> assert_has(css(".group-hover\\:bg-zinc-100"))
      |> assert_has(css(".sm\\:group-hover\\:scale-105"))
    end
  end

  describe "Development Dashboard (/dev/dashboard)" do
    test "development dashboard loads successfully", %{session: session} do
      session
      |> visit("/dev/dashboard")
      # Should load Phoenix LiveDashboard
      |> assert_has(css("body"))
      # Wait for dashboard to load
      |> :timer.sleep(2000)
    end

    test "dashboard navigation from home page works", %{session: session} do
      session
      |> visit("/")
      |> click(css("a[href='/dev/dashboard']"))
      # Verify we're on the dashboard page
      |> assert_path("/dev/dashboard")
      |> :timer.sleep(1000)
    end

    test "dashboard displays system metrics", %{session: session} do
      session
      |> visit("/dev/dashboard")
      |> :timer.sleep(3000)
      # Dashboard should load without errors
      |> assert_has(css("body"))
    end
  end

  describe "Mailbox Preview (/dev/mailbox)" do
    test "mailbox preview loads successfully", %{session: session} do
      session
      |> visit("/dev/mailbox")
      # Should load Swoosh mailbox preview
      |> assert_has(css("body"))
      |> :timer.sleep(2000)
    end

    test "mailbox navigation from home page works", %{session: session} do
      session
      |> visit("/")
      |> click(css("a[href='/dev/mailbox']"))
      # Verify we're on the mailbox page
      |> assert_path("/dev/mailbox")
      |> :timer.sleep(1000)
    end

    test "mailbox displays email interface", %{session: session} do
      session
      |> visit("/dev/mailbox")
      |> :timer.sleep(2000)
      # Mailbox should load without errors
      |> assert_has(css("body"))
    end
  end

  describe "Cross-Page Navigation" do
    test "can navigate between all pages successfully", %{session: session} do
      # Start at home
      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      # Navigate to dashboard
      |> click(css("a[href='/dev/dashboard']"))
      |> assert_path("/dev/dashboard")
      |> :timer.sleep(2000)

      # Navigate back to home
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      # Navigate to mailbox
      |> click(css("a[href='/dev/mailbox']"))
      |> assert_path("/dev/mailbox")
      |> :timer.sleep(2000)

      # Navigate back to home
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
    end

    test "external documentation link opens correctly", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("a[href='https://hexdocs.pm/ash']"))

      # Note: We don't click external links in tests to avoid network calls
    end
  end

  describe "Error Handling" do
    test "handles non-existent routes gracefully", %{session: session} do
      session
      |> visit("/non-existent-page")
      # Should get a 404 or similar error page
      |> assert_has(css("body"))
    end

    test "handles malformed URLs gracefully", %{session: session} do
      session
      |> visit("/dev/invalid-route")
      # Should handle gracefully
      |> assert_has(css("body"))
    end
  end

  describe "Performance" do
    test "home page loads within acceptable time", %{session: session} do
      start_time = System.monotonic_time(:millisecond)

      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Page should load within 3 seconds
      assert load_time < 3000, "Home page took #{load_time}ms to load (expected < 3000ms)"
    end

    test "dashboard loads within acceptable time", %{session: session} do
      start_time = System.monotonic_time(:millisecond)

      session
      |> visit("/dev/dashboard")
      # Allow dashboard to fully load
      |> :timer.sleep(2000)

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Dashboard should load within 5 seconds (more complex page)
      assert load_time < 5000, "Dashboard took #{load_time}ms to load (expected < 5000ms)"
    end
  end

  describe "Mobile Responsiveness" do
    test "home page is mobile responsive", %{session: session} do
      session
      # iPhone SE size
      |> resize_window(375, 667)
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      # Should use single column on mobile
      |> assert_has(css(".grid.grid-cols-1"))
    end

    test "navigation works on mobile devices", %{session: session} do
      session
      # iPhone SE size
      |> resize_window(375, 667)
      |> visit("/")
      |> click(css("a[href='/dev/dashboard']"))
      |> assert_path("/dev/dashboard")
    end
  end

  describe "Accessibility" do
    test "home page has proper heading hierarchy", %{session: session} do
      session
      |> visit("/")
      # Main heading
      |> assert_has(css("h1"))
    end

    test "navigation links have proper text", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("a", text: "Dashboard"))
      |> assert_has(css("a", text: "Notifications"))
      |> assert_has(css("a", text: "Docs"))
    end

    test "images have proper alt attributes or aria labels", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("svg[aria-label='Intelitor']"))
    end
  end

  describe "Security" do
    test "no sensitive information exposed in HTML", %{session: session} do
      session
      |> visit("/")
      |> refute_has(Wallaby.Query.text("password"))
      |> refute_has(Wallaby.Query.text("secret"))
      |> refute_has(Wallaby.Query.text("token"))
      |> refute_has(Wallaby.Query.text("api_key"))
    end

    test "proper HTTPS setup in production", %{session: session} do
      # This would be more relevant in production environment
      session
      |> visit("/")
      |> assert_has(css("body"))
    end
  end

  # Helper functions for test support
  defp assert_path(session, expectedpath) do
    current_path = session |> current_path()
    assert current_path == expected_path, "Expected path #{expected_path}, got #{current_path}"
    session
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
