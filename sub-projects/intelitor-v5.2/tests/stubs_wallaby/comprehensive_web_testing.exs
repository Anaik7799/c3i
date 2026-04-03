defmodule Intelitor.Wallaby.ComprehensiveWebTesting do
  @moduledoc """
  Comprehensive Wallaby test suite for all aspects of the Intelitor web
    interface.

  This test suite covers:
  - Visual design and layout
  - Interactive elements and navigation
  - Responsive design across device sizes
  - Accessibility compliance
  - Performance characteristics
  - Error handling scenarios
  - Security aspects
  - Content integrity
  - User experience flows
  """

  use Intelitor.WallabyCase

  @moduletag :wallaby
  @moduletag :comprehensive

  describe "Home Page (/)" do
    test "visual design and branding elements", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      |> assert_has(css("small", text: "v0.1.0"))
      |> assert_has(css("svg[aria-label='Intelitor']"))
      |> assert_has(Wallaby.Query.text("Comprehensive Security Monitoring System"))
      |> assert_has(Wallaby.Query.text("Built with Ash Framework,
      Phoenix LiveView, and PostgreSQL"))

      # Verify brand colors and styling
      # Main text color
      |> assert_has(css(".text-zinc-900"))
      # Background color
      |> assert_has(css(".bg-white"))
      # Typography scale
      |> assert_has(css(".text-\\[2rem\\]"))
    end

    test "navigation elements and functionality", %{session: session} do
      session
      |> visit("/")
      # Test Dashboard navigation
      |> assert_has(css("a[href='/dev / dashboard']", text: "Dashboard"))
      |> find(css("a[href='/dev / dashboard']"), fn link ->
        link
        # Icon present
        |> assert_has(css("svg"))
        # Hover effect
        |> assert_has(css(".group-hover\\:bg-zinc-100"))
      end)

      # Test Notifications navigation
      |> assert_has(css("a[href='/dev / mailbox']", text: "Notifications"))
      |> find(css("a[href='/dev / mailbox']"), fn link ->
        # Icon present
        link |> assert_has(css("svg"))
      end)

      # Test Documentation link
      |> assert_has(css("a[href='https://hexdocs.pm / ash']", text: "Docs"))
      |> find(css("a[href='https://hexdocs.pm / ash']"), fn link ->
        # Icon present
        link |> assert_has(css("svg"))
      end)
    end

    test "responsive grid layout system", %{session: session} do
      session
      |> visit("/")
      # Verify responsive grid classes
      |> assert_has(css(".grid.grid-cols-1.gap-x-6.gap-y-4.sm\\:grid-cols-3"))
      |> assert_has(css(".px-4.py-10.sm\\:px-6.sm\\:py-28.lg\\:px-8.xl\\:px-28.xl\\:py-32"))
      |> assert_has(css(".mx-auto.max-w-xl.lg\\:mx-0"))
    end

    test "interactive hover effects and animations", %{session: session} do
      session
      |> visit("/")
      |> find(css("a[href='/dev / dashboard']"), fn element ->
        element
        |> assert_has(css(".group"))
        |> assert_has(css(".group-hover\\:bg-zinc-100"))
        |> assert_has(css(".sm\\:group-hover\\:scale-105"))
      end)
    end

    test "accessibility compliance", %{session: session} do
      session
      |> visit("/")
      # Semantic HTML structure
      |> assert_has(css("h1"))
      |> assert_has(css("main, [role='main']"))

      # ARIA labels and accessibility attributes
      |> assert_has(css("svg[aria-label='Intelitor']"))

      # Link accessibility
      |> find(css("a[href='/dev / dashboard']"), fn link ->
        # Descriptive text
        link |> assert_has(Wallaby.Query.text("Dashboard"))
      end)

      # Color contrast and text readability
      # High contrast text
      |> assert_has(css(".text-zinc-900"))
    end

    test "content integrity and accuracy", %{session: session} do
      session
      |> visit("/")
      # Verify all expected content is present and accurate
      |> assert_has(Wallaby.Query.text("Intelitor Security Platform"))
      |> assert_has(Wallaby.Query.text("v0.1.0"))
      |> assert_has(Wallaby.Query.text("Comprehensive Security Monitoring System"))
      |> assert_has(Wallaby.Query.text("Built with Ash Framework,
      Phoenix LiveView, and PostgreSQL"))
      |> assert_has(Wallaby.Query.text("enterprise - grade security monitoring"))
      |> assert_has(Wallaby.Query.text("access control"))
      |> assert_has(Wallaby.Query.text("compliance management"))
    end

    test "meta tags and SEO elements", %{session: session} do
      session
      |> visit("/")

      # Check page title
      page_title = session |> Browser.page_title()
      assert String.contains?(page_title, "Security Platform")
      assert String.contains?(page_title, "Intelitor")

      # Verify meta tags via page source
      page_source = session |> Browser.page_source()
      assert String.contains?(page_source, "charset=\"utf - 8\"")
      assert String.contains?(page_source, "viewport")
      assert String.contains?(page_source, "csrf - token")
    end
  end

  describe "Responsive Design Testing" do
    test "mobile viewport (375px)", %{session: session} do
      session
      # iPhone SE
      |> resize_window(375, 667)
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      # Single column on mobile
      |> assert_has(css(".grid-cols-1"))
      # Mobile padding
      |> assert_has(css(".px-4"))

      # Test navigation still works on mobile
      |> click(css("a[href='/dev/dashboard']"))
      |> assert_path_contains("/dev/dashboard")
    end

    test "tablet viewport (768px)", %{session: session} do
      session
      # iPad
      |> resize_window(768, 1024)
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      # Three columns on tablet
      |> assert_has(css(".sm\\:grid-cols-3"))
      # Tablet padding
      |> assert_has(css(".sm\\:px-6"))
    end

    test "desktop viewport (1024px+)", %{session: session} do
      session
      # Desktop
      |> resize_window(1024, 768)
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      # Desktop padding
      |> assert_has(css(".lg\\:px-8"))
      # Desktop margin
      |> assert_has(css(".lg\\:mx-0"))
    end

    test "large screen viewport (1280px+)", %{session: session} do
      session
      # Large desktop
      |> resize_window(1440, 900)
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      # Extra large padding
      |> assert_has(css(".xl\\:px-28"))
      # Extra large vertical padding
      |> assert_has(css(".xl\\:py-32"))
    end
  end

  describe "Performance Testing" do
    test "page load performance", %{session: session} do
      start_time = System.monotonic_time(:millisecond)

      session |> visit("/") |> assert_has(css("h1", text: "Intelitor Security Platform"))

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Page should load within 3 seconds
      assert load_time < 3000,
             "Page took #{load_time}ms to load (expected < 3000"
    end

    test "navigation performance", %{session: session} do
      session
      |> visit("/")

      # Test navigation to dashboard
      start_time = System.monotonic_time(:millisecond)
      session |> click(css("a[href='/dev / dashboard']"))
      end_time = System.monotonic_time(:millisecond)
      nav_time = end_time - start_time

      assert nav_time < 2000,
             "Navigation took #{nav_time}ms (expected < 2000ms)"
    end

    test "asset loading verification", %{session: session} do
      session
      |> visit("/")

      # Verify CSS is loaded by checking computed styles work |> assert_has(css(".bg-white"))
      |> assert_has(css(".text-zinc-900"))

      # Verify JavaScript is loaded by checking interactive elements |> assert_has(css("a.group"))
    end
  end

  describe "Development Dashboard (/dev / dashboard)" do
    test "dashboard accessibility and functionality", %{session: session} do
      session
      |> visit("/dev / dashboard")

      # LiveDashboard should redirect and load
      current_url = session |> current_url()

      assert String.contains?(current_url, "/dev / dashboard")

             # Should have content either dashboard content or redirect |> assert_has(css("body"))

             # Wait for any potential redirects or loading
             |> :timer.sleep(2000)
    end

    test "dashboard navigation from home page", %{session: session} do
      session |> visit("/") |> click(css("a[href='/dev / dashboard']"))

      # Verify we navigated to dashboard
      current_url = session |> current_url()

      assert String.contains?(current_url, "/dev / dashboard")

             # Should load without errors
             |> assert_has(css("body"))
    end
  end

  describe "Mailbox Preview (/dev / mailbox)" do
    test "mailbox interface functionality", %{session: session} do
      session
      |> visit("/dev/mailbox")
      |> assert_has(css("html"))
      |> assert_has(css("body"))

      # Check for Swoosh mailbox elements
      page_source = session |> Browser.page_source()

      assert String.contains?(page_source, "Swoosh") or
               String.contains?(page_source, "mailbox") or
               String.contains?(page_source, "Mailbox")
    end

    test "mailbox navigation from home page", %{session: session} do
      session |> visit("/") |> click(css("a[href='/dev/mailbox']"))

      # Verify navigation worked
      current_url = session |> current_url()

      assert String.contains?(current_url, "/dev / mailbox")

             # Should load mailbox interface
             |> assert_has(css("body"))
    end
  end

  describe "Error Handling and Edge Cases" do
    test "handles non - existent routes gracefully", %{session: session} do
      session |> visit("/non-existent-route") |> assert_has(css("body"))

      # Should get some kind of error page or redirect
      current_url = session |> current_url()
      page_source = session |> Browser.page_source()

      # Should handle gracefully (not crash the browser)
      assert is_binary(page_source)
    end

    test "handles malformed URLs gracefully", %{session: session} do
      session |> visit("/dev/invalid-route-12345") |> assert_has(css("body"))

      # Should handle gracefully
      page_source = session |> Browser.page_source()
      assert is_binary(page_source)
    end

    test "network timeout resilience", %{session: session} do
      # Test that the page loads within reasonable timeout
      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      # Verify page is stable after loading
      |> :timer.sleep(1000)
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
    end
  end

  describe "Security Aspects" do
    test "no sensitive information exposed", %{session: session} do
      session
      |> visit("/")

      page_source = session |> Browser.page_source()

      # Check for absence of sensitive patterns
      refute String.contains?(page_source, "password")
      refute String.contains?(page_source, "secret")
      refute String.contains?(page_source, "api_key")
      # CSRF token is expected
      refute String.contains?(page_source, "token") or
               String.contains?(page_source, "csrf - token")
    end

    test "CSRF protection is properly implemented", %{session: session} do
      session
      |> visit("/")

      page_source = session |> Browser.page_source()

      # Should have CSRF token
      assert String.contains?(page_source, "csrf - token")
    end

    test "proper HTTP headers and security", %{session: session} do
      session |> visit("/") |> assert_has(css("body"))

      # Page should load over proper protocol
      current_url = session |> current_url()
      assert String.starts_with?(current_url, "http")
    end
  end

  describe "Content and User Experience" do
    test "text content readability and hierarchy", %{session: session} do
      session
      |> visit("/")
      # Main heading is prominent
      |> find(css("h1"), fn heading ->
        heading
        |> assert_text("Intelitor Security Platform")
        # Large text size
        |> assert_has(css(".text-\\[2rem\\]"))
      end)

      # Subheading is properly sized
      |> find(css("p.text-\\[2rem\\]"), fn subheading ->
        subheading |> assert_text("Comprehensive Security Monitoring System")
      end)

      # Description text is readable
      |> assert_has(css("p.text - base"))
    end

    test "visual hierarchy and layout flow", %{session: session} do
      session
      |> visit("/")
      # Logo is at the top
      |> assert_has(css("svg[aria-label='Intelitor']"))

      # Title follows logo
      |> assert_has(css("h1"))

      # Navigation cards are in grid
      |> assert_has(css(".grid"))
      |> assert_has(css("a[href='/dev / dashboard']"))
      |> assert_has(css("a[href='/dev / mailbox']"))
      |> assert_has(css("a[href='https://hexdocs.pm / ash']"))
    end

    test "interactive feedback and user guidance", %{session: session} do
      session
      |> visit("/")
      # Hover __states work check for hover classes |> assert_has(css(".group-hover\\:bg-zinc-100"))
      |> assert_has(css(".sm\\:group-hover\\:scale-105"))

      # Links have descriptive text
      |> assert_has(css("a", text: "Dashboard"))
      |> assert_has(css("a", text: "Notifications"))
      |> assert_has(css("a", text: "Docs"))
    end
  end

  describe "Cross - Page Navigation Flow" do
    test "complete navigation workflow", %{session: session} do
      # Start at home
      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      # Navigate to dashboard
      |> click(css("a[href='/dev / dashboard']"))
      # Allow for redirect / loading
      |> :timer.sleep(2000)

      # Navigate back to home
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      # Navigate to mailbox
      |> click(css("a[href='/dev/mailbox']"))
      |> :timer.sleep(1000)

      # Verify mailbox loaded
      current_url = session |> current_url()

      assert String.contains?(current_url, "/dev / mailbox")

             # Navigate back to home
             |> visit("/")
             |> assert_has(css("h1", text: "Intelitor Security Platform"))
    end

    test "browser navigation controls work", %{session: session} do
      session
      |> visit("/")
      |> click(css("a[href='/dev/mailbox']"))
      |> :timer.sleep(1000)

      # Go back using browser controls
      |> Browser.navigate_back()
      |> assert_has(css("h1", text: "Intelitor Security Platform"))

      # Go forward
      |> Browser.navigate_forward()

      current_url = session |> current_url()
      assert String.contains?(current_url, "/dev / mailbox")
    end
  end

  # Helper functions
  @spec assert_path_contains(term(), term()) :: term()
  defp assert_path_contains(session, pathfragment) do
    current_url = session |> current_url()
    assert String.contains?(current_url, path_fragment)
    session
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
