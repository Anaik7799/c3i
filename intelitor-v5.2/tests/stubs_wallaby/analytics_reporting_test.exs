defmodule Intelitor.Wallaby.AnalyticsReportingTest do
  @moduledoc """
  Comprehensive E2E tests for Analytics and Reporting functionality.

  Tests cover:
  - Real-time analytics dashboards
  - Custom report generation
  - Data visualization and charts
  - Performance metrics monitoring
  - Export functionality
  - Advanced filtering and search
  """

  use Intelitor.WallabyCase
  use Intelitor.WallabyPageObjects

  alias Intelitor.WallabyPageObjects.{AnalyticsPage, ReportsPage, DashboardPage}

  @moduletag :wallaby
  @moduletag :analytics

  setup %{session: session, tenant: tenant} do
    admin_user = get_admin_user_for_tenant(tenant)
    session = session |> authenticate_user(admin_user)

    # Create comprehensive test data for analytics
    analytics_data = create_analytics_test_data(tenant)

    %{session: session, admin_user: admin_user, analytics_data: analytics_data}
  end

  describe "Real-Time Analytics Dashboard" do
    test "analytics dashboard loads with key performance indicators", %{
      session: session,
      tenant: tenant
    } do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> assert_page_loaded()
      |> assert_has(AnalyticsPage.analytics_dashboard())
      |> assert_has(AnalyticsPage.kpi_widget("total_users"))
      |> assert_has(AnalyticsPage.kpi_widget("active_devices"))
      |> assert_has(AnalyticsPage.kpi_widget("security_events"))
      |> assert_has(AnalyticsPage.kpi_widget("system_uptime"))
      |> assert_page_performance(3_000)
    end

    test "real-time data updates automatically", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> assert_has(css("[data-test='last-updated-timestamp']"))
      |> execute_script(
        "window.initialTimestamp = document.querySelector('[data-test=\"last-updated-timestamp\"]').textContent;"
      )
      # Wait for auto-refresh
      |> :timer.sleep(5000)
      |> execute_script("""
        const newTimestamp = document.querySelector('[data-test="last-updated-timestamp"]').textContent;
        return newTimestamp !== window.initialTimestamp;
      """)
      # Verify timestamp has updated
      |> assert()
    end

    test "date range filtering affects all dashboard widgets", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(AnalyticsPage.date_range_picker())
      |> click(css("[data-test='last-7-days']"))
      |> wait_for_ajax()
      |> assert_has(css("[data-test='date-range-applied'][data-range='7-days']"))
      |> assert_has(css("[data-test='kpi-data-period'][data-period='7-days']"))
      |> click(AnalyticsPage.date_range_picker())
      |> click(css("[data-test='last-30-days']"))
      |> wait_for_ajax()
      |> assert_has(css("[data-test='date-range-applied'][data-range='30-days']"))
    end

    test "interactive charts support drill-down functionality", %{
      session: session,
      tenant: tenant
    } do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(AnalyticsPage.chart_container("device-status"))
      |> click(css("[data-test='chart-segment'][data-category='cameras']"))
      |> assert_has(css("[data-test='drill-down-view']"))
      |> assert_has(Wallaby.Query.text("Camera Device Details"))
      |> assert_has(css("[data-test='camera-breakdown-chart']"))
      |> click(css("[data-test='back-to-overview']"))
      |> assert_has(AnalyticsPage.analytics_dashboard())
    end

    test "dashboard customization and widget arrangement", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(css("[data-test='customize-dashboard']"))
      |> drag_and_drop(
        css("[data-test='widget-active-devices']"),
        css("[data-test='drop-zone-top-right']")
      )
      |> click(css("[data-test='save-layout']"))
      |> assert_flash_message("success", "Dashboard layout saved")
      # Verify persistence
      |> refresh()
      |> assert_has(css("[data-test='widget-active-devices'][data-position='top-right']"))
    end
  end

  describe "Custom Report Generation" do
    test "user can create comprehensive custom report", %{session: session, tenant: tenant} do
      report_data = %{
        name: "Monthly Security Analysis",
        type: "security_summary",
        description: "Comprehensive monthly security metrics and incidents",
        schedule: "monthly",
        format: "pdf"
      }

      session
      |> navigate_to_domain("reports", tenant.id)
      |> click(ReportsPage.new_report_button())
      |> fill_form("[data-test='report-form']", report_data)
      |> check(css("[data-test='include-alarm-trends']"))
      |> check(css("[data-test='include-device-performance']"))
      |> check(css("[data-test='include-user-activity']"))
      |> click(css("[data-test='save-report']"))
      |> assert_flash_message("success", "Report template created successfully")
      |> assert_has(Wallaby.Query.text(report_data.name))
    end

    test "report data source selection and validation", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("reports", tenant.id)
      |> click(ReportsPage.new_report_button())
      |> click(css("[data-test='data-sources-tab']"))
      |> check(css("[data-test='data-source-devices']"))
      |> check(css("[data-test='data-source-alarms']"))
      |> check(css("[data-test='data-source-users']"))
      |> assert_has(css("[data-test='estimated-data-volume']"))
      |> assert_has(Wallaby.Query.text("Approximately"))
      |> click(css("[data-test='preview-data']"))
      |> assert_has(css("[data-test='data-preview-table']"))
      |> validate_table_data("[data-test='data-preview-table']", 5)
    end

    test "report template library and sharing", %{session: session, tenant: tenant} do
      template = insert(:report_template, tenant: tenant, name: "Device Performance Template")

      session
      |> navigate_to_domain("reports", tenant.id)
      |> click(css("[data-test='template-library']"))
      |> assert_has(Wallaby.Query.text(template.name))
      |> click(css("[data-test='use-template-#{template.id}']"))
      |> assert_has(css("[data-test='report-form']"))
      |> assert_has(css("input[value='#{template.name}']"))
      |> click(css("[data-test='share-template']"))
      |> Wallaby.Browser.select(Wallaby.Query.css("[data-test='share-with']"), option: "team")
      |> click(css("[data-test='confirm-share']"))
      |> assert_flash_message("success", "Template shared with team")
    end

    test "automated report scheduling and delivery", %{session: session, tenant: tenant} do
      report = insert(:report, tenant: tenant, name: "Weekly Status Report")

      session
      |> navigate_to_domain("reports", tenant.id)
      |> click(css("[data-test='view-report-#{report.id}']"))
      |> click(css("[data-test='schedule-tab']"))
      |> select(css("[data-test='schedule-f_requency']"), option: "weekly")
      |> select(css("[data-test='schedule-day']"), option: "monday")
      |> fill_in(css("[data-test='schedule-time']"), with: "09:00")
      |> fill_in(css("[data-test='delivery-emails']"),
        with: "manager@example.com,team@example.com"
      )
      |> click(css("[data-test='save-schedule']"))
      |> assert_flash_message("success", "Report schedule configured")
      |> assert_has(css("[data-test='next-run-time']"))
    end

    test "report generation with real-time progress tracking", %{session: session, tenant: tenant} do
      report = insert(:report, tenant: tenant, name: "Large Dataset Report")

      session
      |> navigate_to_domain("reports", tenant.id)
      |> click(css("[data-test='view-report-#{report.id}']"))
      |> click(ReportsPage.generate_button())
      |> assert_has(css("[data-test='generation-progress']"))
      |> assert_has(css("[data-test='progress-bar']"))
      |> wait_for_element("[data-test='generation-complete']", 30_000)
      |> assert_has(css("[data-test='download-ready']"))
      |> click(ReportsPage.download_button(report.id))
      # Allow download to start
      |> :timer.sleep(2000)
    end
  end

  describe "Data Visualization and Charts" do
    test "interactive time-series charts with zoom and pan", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(AnalyticsPage.chart_container("device-metrics-timeline"))
      |> execute_script("""
        const chart = document.querySelector('[data-test="chart-device-metrics-timeline"] canvas');
        const rect = chart.getBoundingClientRect();
        const event = new MouseEvent('mousedown', {
          clientX: rect.left + 100,
          clientY: rect.top + 100
        });
        chart.dispatchEvent(event);
      """)
      |> drag_from_to(
        css("[data-test='chart-device-metrics-timeline'] canvas"),
        100,
        100,
        200,
        100
      )
      |> assert_has(css("[data-test='chart-zoomed']"))
      |> click(css("[data-test='reset-zoom']"))
      |> assert_has(css("[data-test='chart-full-view']"))
    end

    test "chart type switching and customization", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(AnalyticsPage.chart_container("alarm-trends"))
      |> click(css("[data-test='chart-options']"))
      |> select(css("[data-test='chart-type']"), option: "bar")
      |> click(css("[data-test='apply-chart-type']"))
      |> assert_has(css("[data-test='chart-type-bar']"))
      |> click(css("[data-test='chart-options']"))
      |> select(css("[data-test='chart-type']"), option: "line")
      |> click(css("[data-test='apply-chart-type']"))
      |> assert_has(css("[data-test='chart-type-line']"))
    end

    test "multi-dimensional data filtering on charts", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(AnalyticsPage.filter_panel())
      |> select(css("[data-test='filter-location']"), option: "Building A")
      |> select(css("[data-test='filter-device-type']"), option: "cameras")
      |> select(css("[data-test='filter-status']"), option: "online")
      |> click(css("[data-test='apply-filters']"))
      |> wait_for_ajax()
      |> assert_has(css("[data-test='active-filters'][data-count='3']"))
      |> assert_has(Wallaby.Query.text("Building A"))
      |> assert_has(Wallaby.Query.text("cameras"))
      |> assert_has(Wallaby.Query.text("online"))
    end

    test "data export from charts in multiple formats", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(AnalyticsPage.chart_container("user-activity"))
      |> click(css("[data-test='export-chart-data']"))
      |> select(css("[data-test='export-format']"), option: "csv")
      |> click(css("[data-test='confirm-export']"))
      |> assert_flash_message("success", "Chart data exported successfully")
      |> click(css("[data-test='export-chart-data']"))
      |> select(css("[data-test='export-format']"), option: "excel")
      |> click(css("[data-test='confirm-export']"))
      |> assert_flash_message("success", "Chart data exported successfully")
    end
  end

  describe "Performance Metrics Monitoring" do
    test "system performance dashboard shows key metrics", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("performance", tenant.id)
      |> assert_has(css("[data-test='cpu-usage-gauge']"))
      |> assert_has(css("[data-test='memory-usage-gauge']"))
      |> assert_has(css("[data-test='network-throughput-chart']"))
      |> assert_has(css("[data-test='response-time-chart']"))
      |> assert_has(css("[data-test='error-rate-indicator']"))
    end

    test "performance alerting and threshold management", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("performance", tenant.id)
      |> click(css("[data-test='configure-alerts']"))
      |> fill_in(css("[data-test='cpu-threshold']"), with: "80")
      |> fill_in(css("[data-test='memory-threshold']"), with: "85")
      |> fill_in(css("[data-test='response-time-threshold']"), with: "2000")
      |> check(css("[data-test='enable-email-alerts']"))
      |> click(css("[data-test='save-thresholds']"))
      |> assert_flash_message("success", "Performance thresholds configured")
      |> assert_has(css("[data-test='alert-configuration-active']"))
    end

    test "historical performance trend analysis", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("performance", tenant.id)
      |> click(css("[data-test='historical-trends']"))
      |> select(css("[data-test='trend-period']"), option: "last-month")
      |> assert_has(css("[data-test='performance-trend-chart']"))
      |> assert_has(css("[data-test='trend-analysis-summary']"))
      |> click(css("[data-test='compare-periods']"))
      |> select(css("[data-test='comparison-period']"), option: "previous-month")
      |> assert_has(css("[data-test='comparison-chart']"))
      |> assert_has(css("[data-test='performance-delta']"))
    end

    test "device-specific performance monitoring", %{session: session, tenant: tenant} do
      device = insert(:device, tenant: tenant, name: "Test Camera")

      session
      |> navigate_to_domain("performance", tenant.id)
      |> click(css("[data-test='device-performance']"))
      |> search_and_validate(device.name, 1)
      |> click(css("[data-test='view-device-performance-#{device.id}']"))
      |> assert_has(css("[data-test='device-uptime']"))
      |> assert_has(css("[data-test='device-error-rate']"))
      |> assert_has(css("[data-test='device-network-stats']"))
      |> assert_has(css("[data-test='device-health-score']"))
    end
  end

  describe "Advanced Filtering and Search" do
    test "complex multi-criteria search across analytics data", %{
      session: session,
      tenant: tenant
    } do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(css("[data-test='advanced-search']"))
      |> fill_in(css("[data-test='search-query']"), with: "alarm AND camera")
      |> select(css("[data-test='search-timeframe']"), option: "last-week")
      |> select(css("[data-test='search-severity']"), option: "high")
      |> click(css("[data-test='add-search-filter']"))
      |> select(css("[data-test='filter-field']"), option: "location")
      |> select(css("[data-test='filter-operator']"), option: "contains")
      |> fill_in(css("[data-test='filter-value']"), with: "Building")
      |> click(css("[data-test='execute-search']"))
      |> assert_has(css("[data-test='search-results']"))
      |> validate_table_data("[data-test='search-results-table']", 1)
    end

    test "saved searches and quick filters", %{session: session, tenant: tenant} do
      search_criteria = %{
        name: "High Priority Security Events",
        query: "priority:high AND type:security",
        timeframe: "last-24-hours"
      }

      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(css("[data-test='advanced-search']"))
      |> fill_in(css("[data-test='search-query']"), with: search_criteria.query)
      |> select(css("[data-test='search-timeframe']"), option: search_criteria.timeframe)
      |> click(css("[data-test='save-search']"))
      |> fill_in(css("[data-test='search-name']"), with: search_criteria.name)
      |> click(css("[data-test='confirm-save-search']"))
      |> assert_flash_message("success", "Search saved successfully")
      |> click(css("[data-test='saved-searches']"))
      |> click(css("[data-test='load-search'][data-name='#{search_criteria.name}']"))
      |> assert_has(css("input[value='#{search_criteria.query}']"))
    end

    test "real-time search with auto-complete suggestions", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(css("[data-test='quick-search']"))
      |> fill_in(css("[data-test='quick-search-input']"), with: "cam")
      |> wait_for_element("[data-test='search-suggestions']", 3_000)
      |> assert_has(css("[data-test='suggestion-camera']"))
      |> assert_has(css("[data-test='suggestion-campaign']"))
      |> click(css("[data-test='suggestion-camera']"))
      |> assert_has(css("[data-test='search-results-camera']"))
    end

    test "search result export and sharing", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> click(css("[data-test='advanced-search']"))
      |> fill_in(css("[data-test='search-query']"), with: "device status")
      |> click(css("[data-test='execute-search']"))
      |> assert_has(css("[data-test='search-results']"))
      |> click(css("[data-test='export-results']"))
      |> select(css("[data-test='export-format']"), option: "csv")
      |> check(css("[data-test='include-metadata']"))
      |> click(css("[data-test='confirm-export']"))
      |> assert_flash_message("success", "Search results exported")
      |> assert_has(css("[data-test='download-export']"))
    end
  end

  describe "Data Integration and APIs" do
    test "external data source integration", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("data-sources", tenant.id)
      |> click(css("[data-test='add-data-source']"))
      |> select(css("[data-test='source-type']"), option: "rest_api")
      |> fill_in(css("[data-test='api-endpoint']"), with: "https://api.example.com/metrics")
      |> fill_in(css("[data-test='api-key']"), with: "test-api-key-123")
      |> select(css("[data-test='refresh-interval']"), option: "hourly")
      |> click(css("[data-test='test-connection']"))
      |> assert_has(css("[data-test='connection-success']"))
      |> click(css("[data-test='save-data-source']"))
      |> assert_flash_message("success", "Data source configured successfully")
    end

    test "data quality monitoring and validation", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("data-quality", tenant.id)
      |> assert_has(css("[data-test='data-quality-score']"))
      |> assert_has(css("[data-test='completeness-metric']"))
      |> assert_has(css("[data-test='accuracy-metric']"))
      |> assert_has(css("[data-test='timeliness-metric']"))
      |> click(css("[data-test='quality-issues']"))
      |> assert_has(css("[data-test='quality-issues-list']"))
      |> click(css("[data-test='resolve-issue']"))
      |> assert_flash_message("success", "Data quality issue resolved")
    end
  end

  describe "Mobile Responsiveness and Accessibility" do
    test "analytics dashboard is fully responsive", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      |> test_responsive_design([1920, 1024, 768, 375])
      |> assert_responsive_elements()
    end

    test "charts are accessible and screen reader friendly", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("analytics", tenant.id)
      # Charts have proper ARIA labels
      |> assert_has(css("[role='img'][aria-label]"))
      # Alternative data table
      |> assert_has(css("[data-test='chart-data-table']"))
      |> click(css("[data-test='toggle-data-view']"))
      |> assert_has(css("[data-test='accessible-data-table']"))
    end
  end

  # Private helper functions

  defp create_analytics_test_data(tenant) do
    # Create comprehensive test data for analytics
    devices = Intelitor.Factory.insert_list(20, :device, tenant: tenant)
    users = Intelitor.Factory.insert_list(50, :user, tenant: tenant)
    alarms = Intelitor.Factory.insert_list(100, :alarm_event, tenant: tenant)

    # Create time-series data for trends
    Enum.each(1..30, fn days_ago ->
      date = Date.utc_today() |> Date.add(-days_ago)

      # Create daily metrics
      insert(:daily_metric,
        tenant: tenant,
        date: date,
        device_uptime: :rand.uniform(100),
        alarm_count: :rand.uniform(10),
        __user_activity: :rand.uniform(500)
      )
    end)

    %{
      devices: devices,
      users: users,
      alarms: alarms
    }
  end

  defp drag_from_to(session, selector, startx, start_y, end_x, end_y) do
    session
    |> execute_script("""
      const element = document.querySelector('#{selector}');
      const rect = element.getBoundingClientRect();

      const startEvent = new MouseEvent('mousedown', {
        clientX: rect.left + #{start_x},
        clientY: rect.top + #{start_y},
        bubbles: true
      });

      const endEvent = new MouseEvent('mouseup', {
        clientX: rect.left + #{end_x},
        clientY: rect.top + #{end_y},
        bubbles: true
      });

      element.dispatchEvent(startEvent);
      element.dispatchEvent(endEvent);
    """)
  end

  defp drag_and_drop(session, sourceselector, target_selector) do
    session
    |> execute_script("""
      const source = document.querySelector('#{source_selector}');
      const target = document.querySelector('#{target_selector}');

      const dragStart = new DragEvent('dragstart', { bubbles: true });
      const dragOver = new DragEvent('dragover', { bubbles: true });
      const drop = new DragEvent('drop', { bubbles: true });

      source.dispatchEvent(dragStart);
      target.dispatchEvent(dragOver);
      target.dispatchEvent(drop);
    """)
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
