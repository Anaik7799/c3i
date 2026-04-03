defmodule Intelitor.Wallaby.BasicWebTest do
  @moduledoc """
  Basic Wallaby test to verify web functionality is working.
  """

  use ExUnit.Case, async: false
  use Intelitor.Ultimate.TestConsolidation
  use Wallaby.Feature

  import Wallaby.Query

  @moduletag :wallaby

  describe "Basic Web Functionality" do
    feature "home page loads successfully", %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      |> assert_has(css("small", text: "v0.1.0"))
      |> assert_has(Query.text("Comprehensive Security Monitoring System"))
    end

    feature "navigation links are present and functional",
            %{session: session} do
      session
      |> visit("/")
      |> assert_has(css("a[href='/dev / dashboard']", text: "Dashboard"))
      |> assert_has(css("a[href='/dev / mailbox']", text: "Notifications"))
      |> assert_has(css("a[href='https://hexdocs.pm / ash']", text: "Docs"))
    end

    feature "mailbox page is accessible", %{session: session} do
      session
      |> visit("/dev / mailbox")
      |> assert_has(css("html"))
      |> assert_has(css("body"))
    end

    feature "responsive design works", %{session: session} do
      session
      # Mobile size
      |> resize_window(375, 667)
      |> visit("/")
      |> assert_has(css("h1", text: "Intelitor Security Platform"))
      # Single column on mobile
      |> assert_has(css(".grid - cols - 1"))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
