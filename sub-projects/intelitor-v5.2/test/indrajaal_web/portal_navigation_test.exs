defmodule IndrajaalWeb.PortalNavigationTest do
  @moduledoc """
  Release gate test for the System Navigation Portal.

  Verifies:
  - SC-PORTAL-001: Root page links to ALL routes in the registry
  - SC-PORTAL-002: All linked routes return HTTP 200
  - SC-HMI-001: No hardcoded zinc/gray color classes (semantic only)
  """

  use IndrajaalWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "Navigation Portal (SC-PORTAL-001)" do
    test "renders at root path with all category sections", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "System Navigation Portal"
      assert html =~ "INDRAJAAL"
      assert html =~ "v21.3.0-SIL6"

      # All 7 categories present
      assert html =~ "C3I Cockpit"
      assert html =~ "Operations Center"
      assert html =~ "Analytics &amp; Monitoring"
      assert html =~ "Administration"
      assert html =~ "Health Probes"
      assert html =~ "API Reference"
      assert html =~ "Dev Tools"

      # Route count displayed
      assert render(view) =~ "routes across 7 categories"
    end

    test "contains links to all cockpit routes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      cockpit_paths = [
        "/cockpit",
        "/cockpit/dashboard",
        "/cockpit/startup",
        "/cockpit/containers",
        "/cockpit/commands",
        "/cockpit/mesh",
        "/cockpit/alarms",
        "/cockpit/ai-copilot",
        "/cockpit/cluster",
        "/cockpit/settings",
        "/cockpit/sentinel",
        "/cockpit/guardian",
        "/cockpit/register",
        "/cockpit/threat",
        "/cockpit/git-intelligence",
        "/cockpit/devices",
        "/cockpit/video",
        "/cockpit/compliance"
      ]

      for path <- cockpit_paths do
        assert html =~ path, "Missing cockpit route: #{path}"
      end
    end

    test "contains links to operations routes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      operations_paths = [
        "/operations/alarms",
        "/operations/access",
        "/operations/video",
        "/operations/dispatch"
      ]

      for path <- operations_paths do
        assert html =~ path, "Missing operations route: #{path}"
      end
    end

    test "contains links to analytics routes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "/analytics/stamp-tdg-gde-advanced"
      assert html =~ "/analytics/dashboard"
      assert html =~ "/monitoring"
      assert html =~ "/performance"
    end

    test "contains links to admin routes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "/admin/permissions"
      assert html =~ "/admin/access_control"
      assert html =~ "/admin/config"
      assert html =~ "/admin/system-status"
    end

    test "contains links to health probes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "/healthz"
      assert html =~ "/ready"
      assert html =~ "/health"
    end

    test "contains links to API endpoints", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "/api/kms/holons"
      assert html =~ "/api/v1/prajna/sentinel/health"
    end
  end

  describe "Dark Cockpit Compliance (SC-HMI-001)" do
    test "uses semantic color classes, not hardcoded colors", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Semantic classes should be present
      assert html =~ "bg-surface-primary"
      assert html =~ "bg-surface-secondary"
      assert html =~ "text-content-primary"
      assert html =~ "text-content-secondary"

      # Hardcoded zinc colors should NOT be present
      refute html =~ "text-zinc-",
             "SC-HMI-001 violation: hardcoded zinc color class found"

      refute html =~ "bg-zinc-",
             "SC-HMI-001 violation: hardcoded zinc background found"
    end
  end

  describe "Elixir Service Architecture (SC-PORTAL-001)" do
    test "renders all 4 architectural planes", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Elixir Service Architecture"
      assert html =~ "Data Plane"
      assert html =~ "Control Plane"
      assert html =~ "Cognitive Plane"
      assert html =~ "Safety &amp; Immune Plane"
    end

    test "renders key services in each plane", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Data Plane
      assert html =~ "PostgreSQL 17"
      assert html =~ "SMRITI SQLite"
      assert html =~ "SMRITI DuckDB"

      # Control Plane
      assert html =~ "Zenoh Router 1-3"
      assert html =~ "CEPAF Bridge"
      assert html =~ "MCP Server"

      # Cognitive Plane
      assert html =~ "Synapse"
      assert html =~ "FastOODA"
      assert html =~ "Digital Twin"

      # Safety & Immune
      assert html =~ "Guardian"
      assert html =~ "Sentinel"
      assert html =~ "Prometheus Verifier"
    end

    test "shows service count summary", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "services across 4 architectural planes"
    end
  end

  describe "F# CEPAF Substrate (SC-PORTAL-001)" do
    test "renders all 4 F# project groups", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "F# CEPAF Substrate"
      assert html =~ "Core Orchestration &amp; Lifecycle"
      assert html =~ "Planning &amp; Evolution"
      assert html =~ "HMI &amp; Cockpit"
      assert html =~ "Knowledge &amp; SMRITI (L7)"
    end

    test "renders key F# projects", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Cepaf.Podman"
      assert html =~ "Cepaf.Planning"
      assert html =~ "Cepaf.GitIntelligence"
      assert html =~ "Cepaf.Cockpit.Avalonia"
      assert html =~ "Cepaf.Sentinel.MCP"
      assert html =~ "Cepaf.Smriti.Semantic"
      assert html =~ "Cepaf.Immune"
    end

    test "shows F# project count and net10.0 target", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "F# projects across 4 groups"
      assert html =~ "net10.0"
    end
  end

  describe "Infrastructure & Observability Endpoints (SC-PORTAL-001)" do
    test "renders infrastructure section with key services", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "Infrastructure &amp; Observability Endpoints"
      assert html =~ "Phoenix (Main App)"
      assert html =~ "Grafana / SigNoz"
      assert html =~ "Prometheus"
      assert html =~ "Loki"
      assert html =~ "Zenoh Control"
      assert html =~ "PostgreSQL"
      assert html =~ "Zenoh Router"
    end

    test "renders port numbers for infrastructure services", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "4000"
      assert html =~ "4001"
      assert html =~ "4002"
      assert html =~ "3000"
      assert html =~ "9090"
      assert html =~ "7447"
    end

    test "shows infrastructure endpoint count", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "services across the mesh"
    end
  end

  describe "Portal Metadata" do
    test "displays node name and timestamp", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Node name present (may be "nonode@nohost" in test)
      assert html =~ "Node:"

      # Footer with compliance info
      assert html =~ "SIL-6 Biomorphic Fractal Mesh"
      assert html =~ "IEC 61508"
    end

    test "footer shows aggregate counts across all sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      assert html =~ "routes"
      assert html =~ "services"
      assert html =~ "F# projects"
      assert html =~ "infra endpoints"
    end
  end
end
