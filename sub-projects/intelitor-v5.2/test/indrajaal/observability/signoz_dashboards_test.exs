defmodule Indrajaal.Observability.SigNozDashboardsTest do
  use ExUnit.Case, async: true
  alias Indrajaal.Observability.SigNozDashboards

  describe "system_overview_dashboard/0" do
    test "returns valid dashboard configuration with all __required panels" do
      dashboard = SigNozDashboards.system_overview_dashboard()

      assert dashboard.title == "Indrajaal System Overview"
      assert dashboard.description =~ "High-level system health"
      assert dashboard.refresh == "5s"
      assert dashboard.time == %{from: "now-1h", to: "now"}

      # Verify panels exist
      panel_titles = Enum.map(dashboard.panels, & &1.title)

      assert "Request Rate" in panel_titles
      assert "Error Rate" in panel_titles
      assert "P99 Latency" in panel_titles
      assert "Active Users" in panel_titles
      assert "CPU Usage" in panel_titles
      assert "Memory Usage" in panel_titles
      assert "Database Connections" in panel_titles
      assert "Phoenix Channel Connections" in panel_titles
    end

    test "each panel has valid query configuration" do
      dashboard = SigNozDashboards.system_overview_dashboard()

      Enum.each(dashboard.panels, fn panel ->
        assert panel.type in ["graph", "stat", "gauge"]
        assert is_map(panel.targets)
        assert panel.gridPos.w > 0
        assert panel.gridPos.h > 0
        assert panel.gridPos.x >= 0
        assert panel.gridPos.y >= 0
      end)
    end
  end

  describe "domain_dashboard/1" do
    test "returns valid dashboard for accounts domain" do
      dashboard = SigNozDashboards.domain_dashboard(:accounts)

      assert dashboard.title == "Accounts Domain Dashboard"
      assert dashboard.description =~ "metrics for Accounts"
      assert dashboard.tags == ["domain", "accounts"]

      # Check for domain-specific panels
      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Login Success Rate" in panel_titles
      assert "User Registration Rate" in panel_titles
      assert "Active Sessions" in panel_titles
      assert "Authentication Errors" in panel_titles
    end

    test "returns valid dashboard for alarms domain" do
      dashboard = SigNozDashboards.domain_dashboard(:alarms)

      assert dashboard.title == "Alarms Domain Dashboard"
      assert dashboard.description =~ "metrics for Alarms"
      assert dashboard.tags == ["domain", "alarms"]

      # Check for domain-specific panels
      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Active Alarms" in panel_titles
      assert "Alarm Response Time" in panel_titles
      assert "Alarm Processing Rate" in panel_titles
      assert "Escalation Rate" in panel_titles
    end

    test "returns valid dashboard for analytics domain" do
      dashboard = SigNozDashboards.domain_dashboard(:analytics)

      assert dashboard.title == "Analytics Domain Dashboard"
      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Report Generation Time" in panel_titles
      assert "Active Reports" in panel_titles
    end

    test "returns valid dashboard for all supported domains" do
      domains = [
        :accounts,
        :alarms,
        :analytics,
        :access_control,
        :communication,
        :devices,
        :guard_tours,
        :sites,
        :visitor_management
      ]

      Enum.each(domains, fn domain ->
        dashboard = SigNozDashboards.domain_dashboard(domain)
        assert dashboard.title =~ to_string(domain)
        assert is_list(dashboard.panels)
        assert length(dashboard.panels) > 0
      end)
    end
  end

  describe "executive_dashboard/0" do
    test "returns dashboard with business metrics" do
      dashboard = SigNozDashboards.executive_dashboard()

      assert dashboard.title == "Executive Dashboard"
      assert dashboard.description =~ "Business metrics"
      assert dashboard.refresh == "1m"

      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Total Revenue" in panel_titles
      assert "Customer Satisfaction" in panel_titles
      assert "System Uptime" in panel_titles
      assert "Security Score" in panel_titles
      assert "Active Licenses" in panel_titles
      assert "Compliance Status" in panel_titles
    end
  end

  describe "infrastructure_dashboard/0" do
    test "returns dashboard with infrastructure metrics" do
      dashboard = SigNozDashboards.infrastructure_dashboard()

      assert dashboard.title == "Infrastructure Dashboard"
      assert dashboard.tags == ["infrastructure", "containers"]

      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Container Health" in panel_titles
      assert "Database Performance" in panel_titles
      assert "Network Latency" in panel_titles
      assert "Disk Usage" in panel_titles
    end
  end

  describe "performance_dashboard/0" do
    test "returns dashboard with performance metrics" do
      dashboard = SigNozDashboards.performance_dashboard()

      assert dashboard.title == "Performance Dashboard"

      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Response Time Distribution" in panel_titles
      assert "Throughput by Endpoint" in panel_titles
      assert "Slow Queries" in panel_titles
      assert "Cache Hit Rate" in panel_titles
    end
  end

  describe "security_dashboard/0" do
    test "returns dashboard with security metrics" do
      dashboard = SigNozDashboards.security_dashboard()

      assert dashboard.title == "Security Dashboard"
      assert dashboard.tags == ["security", "compliance"]

      panel_titles = Enum.map(dashboard.panels, & &1.title)
      assert "Failed Login Attempts" in panel_titles
      assert "Suspicious Activities" in panel_titles
      assert "Access Violations" in panel_titles
      assert "API Key Usage" in panel_titles
    end
  end

  describe "all_dashboards/0" do
    test "returns list of all dashboard configurations" do
      dashboards = SigNozDashboards.all_dashboards()

      assert is_list(dashboards)
      assert length(dashboards) >= 6

      titles = Enum.map(dashboards, & &1.title)
      assert "Indrajaal System Overview" in titles
      assert "Executive Dashboard" in titles
      assert "Infrastructure Dashboard" in titles
      assert "Performance Dashboard" in titles
      assert "Security Dashboard" in titles
    end

    test "includes domain dashboards for all domains" do
      dashboards = SigNozDashboards.all_dashboards()

      domain_dashboards =
        Enum.filter(dashboards, fn d ->
          "domain" in (d[:tags] || [])
        end)

      assert length(domain_dashboards) >= 9
    end
  end

  describe "export_dashboards/1" do
    test "exports dashboards to specified directory" do
      # Create a temp directory for testing
      temp_dir = System.tmp_dir!() <> "/signoz_test_#{:rand.uniform(10_000)}"
      File.mkdir_p!(temp_dir)

      assert :ok = SigNozDashboards.export_dashboards(temp_dir)

      # Check files were created
      files = File.ls!(temp_dir)
      assert "system_overview.json" in files
      assert "executive.json" in files
      assert "accounts_domain.json" in files

      # Verify JSON is valid
      system_json = File.read!(Path.join(temp_dir, "system_overview.json"))
      assert {:ok, _} = Jason.decode(system_json)

      # Cleanup
      File.rm_rf!(temp_dir)
    end
  end

  describe "panel creation helpers" do
    test "creates valid graph panel" do
      panel =
        SigNozDashboards.create_graph_panel(
          "Test Graph",
          %{query: "test_metric", legend: "{{label}}"},
          %{x: 0, y: 0, w: 12, h: 8}
        )

      assert panel.type == "graph"
      assert panel.title == "Test Graph"
      assert panel.targets.query == "test_metric"
      assert panel.gridPos == %{x: 0, y: 0, w: 12, h: 8}
    end

    test "creates valid stat panel" do
      panel =
        SigNozDashboards.create_stat_panel(
          "Test Stat",
          %{query: "count(test)"},
          %{x: 12, y: 0, w: 6, h: 4}
        )

      assert panel.type == "stat"
      assert panel.title == "Test Stat"
    end

    test "creates valid gauge panel" do
      panel =
        SigNozDashboards.create_gauge_panel(
          "Test Gauge",
          %{query: "avg(metric)"},
          %{x: 18, y: 0, w: 6, h: 4},
          %{min: 0, max: 100, thresholds: [50, 80]}
        )

      assert panel.type == "gauge"
      assert panel.title == "Test Gauge"
      assert panel.options.min == 0
      assert panel.options.max == 100
    end
  end
end
