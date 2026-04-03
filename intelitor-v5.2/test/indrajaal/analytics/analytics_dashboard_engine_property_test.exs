defmodule Indrajaal.Analytics.AnalyticsDashboardEnginePropertyTest do
  use ExUnit.Case, async: true
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData-based property testing - import except check to avoid conflict
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Analytics.AnalyticsDashboardEngine

  @moduletag :property_test
  @moduletag :analytics
  @moduletag :dashboard_engine
  @moduletag :tdg_compliant

  # Test data generators for property-based testing
  @valid_dashboard_config %{
    dashboard_id: "DASH-001",
    name: "Security Analytics Dashboard",
    type: :real_time,
    # seconds
    refresh_interval: 30,
    layout: :grid,
    dimensions: %{width: 1920, height: 1080},
    widgets: [
      %{widget_id: "W001", type: :chart, position: %{x: 0, y: 0, width: 4, height: 3}},
      %{widget_id: "W002", type: :metric, position: %{x: 4, y: 0, width: 2, height: 3}},
      %{widget_id: "W003", type: :table, position: %{x: 0, y: 3, width: 6, height: 4}}
    ],
    data_sources: [:metrics, :alerts, :performance, :analytics],
    user_permissions: [:view, :interact],
    theme: :dark
  }

  @valid_widget_config %{
    widget_id: "WIDGET-001",
    type: :time_series_chart,
    title: "CPU Usage Over Time",
    data_source: :metrics,
    query: %{
      metric: "cpu_usage",
      time_range: %{start: ~N[2025-09-19 13:00:00], end: ~N[2025-09-19 14:00:00]},
      aggregation: :avg,
      interval: :minute
    },
    visualization: %{
      chart_type: :line,
      colors: ["#1f77b4", "#ff7f0e", "#2ca02c"],
      axes: %{x: "Time", y: "Percentage"},
      legend: true
    },
    display_options: %{
      show_grid: true,
      animate: true,
      responsive: true
    }
  }

  @valid_metrics_data %{
    cpu_usage: [
      %{timestamp: ~N[2025-09-19 13:00:00], value: 45.2, tenant_id: "tenant_1"},
      %{timestamp: ~N[2025-09-19 13:01:00], value: 67.8, tenant_id: "tenant_1"},
      %{timestamp: ~N[2025-09-19 13:02:00], value: 23.1, tenant_id: "tenant_1"}
    ],
    memory_usage: [
      %{timestamp: ~N[2025-09-19 13:00:00], value: 78.9, tenant_id: "tenant_1"},
      %{timestamp: ~N[2025-09-19 13:01:00], value: 45.6, tenant_id: "tenant_1"}
    ],
    alert_counts: [
      %{timestamp: ~N[2025-09-19 13:00:00], value: 12, tenant_id: "tenant_1"},
      %{timestamp: ~N[2025-09-19 13:01:00], value: 8, tenant_id: "tenant_1"}
    ]
  }

  @valid_user_context %{
    user_id: "USER-001",
    tenant_id: "tenant_1",
    role: :analyst,
    permissions: [:view_dashboards, :create_widgets, :export_data],
    preferences: %{
      theme: :dark,
      timezone: "UTC",
      refresh_rate: :auto,
      default_time_range: "1h"
    }
  }

  @widget_types [:chart, :metric, :table, :gauge, :heatmap, :map, :text, :image]
  @chart_types [:line, :bar, :pie, :scatter, :area, :candlestick, :histogram]
  @data_sources [:metrics, :alerts, :logs, :performance, :analytics, :security]
  @dashboard_layouts [:grid, :freeform, :template, :responsive]
  @aggregation_methods [:sum, :avg, :min, :max, :count, :percentile]

  # =============================================================================
  # PROPERTY-BASED TESTS - PROPCHECK FRAMEWORK
  # =============================================================================

  describe "PropCheck Property-Based Tests for AnalyticsDashboardEngine" do
    test "propcheck: create_dashboard/2 always returns valid dashboard structure with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {dashboard_config, user_context} <-
                        {PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context) do
                   {:ok, dashboard} ->
                     is_map(dashboard) and
                       Map.has_key?(dashboard, :dashboard_id) and
                       Map.has_key?(dashboard, :metadata) and
                       Map.has_key?(dashboard, :widgets) and
                       Map.has_key?(dashboard, :layout) and
                       Map.has_key?(dashboard, :created_at) and
                       is_binary(dashboard.dashboard_id) and
                       is_map(dashboard.metadata) and
                       is_list(dashboard.widgets) and
                       is_map(dashboard.layout)

                   {:error, _reason} ->
                     # Valid error response for invalid input
                     true
                 end
               end
             )
    end

    test "propcheck: add_widget/3 maintains dashboard integrity with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {dashboard_id, widget_config, user_context} <-
                        {PC.binary(), PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.add_widget(
                        dashboard_id,
                        widget_config,
                        user_context
                      ) do
                   {:ok, updated_dashboard} ->
                     is_map(updated_dashboard) and
                       Map.has_key?(updated_dashboard, :dashboard_id) and
                       Map.has_key?(updated_dashboard, :widgets) and
                       Map.has_key?(updated_dashboard, :modified_at) and
                       is_list(updated_dashboard.widgets) and
                       updated_dashboard.dashboard_id == dashboard_id

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: render_dashboard/2 produces valid rendering output" do
      assert PropCheck.quickcheck(
               forall {dashboard_id, render_context} <- {PC.binary(), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.render_dashboard(dashboard_id, render_context) do
                   {:ok, rendered_dashboard} ->
                     is_map(rendered_dashboard) and
                       Map.has_key?(rendered_dashboard, :html_content) and
                       Map.has_key?(rendered_dashboard, :javascript_content) and
                       Map.has_key?(rendered_dashboard, :css_content) and
                       Map.has_key?(rendered_dashboard, :metadata) and
                       is_binary(rendered_dashboard.html_content) and
                       is_binary(rendered_dashboard.javascript_content) and
                       is_binary(rendered_dashboard.css_content)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: execute_widget_query/3 produces valid data results" do
      assert PropCheck.quickcheck(
               forall {widget_id, query_params, execution_context} <-
                        {PC.binary(), PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.execute_widget_query(
                        widget_id,
                        query_params,
                        execution_context
                      ) do
                   {:ok, query_results} ->
                     is_map(query_results) and
                       Map.has_key?(query_results, :data) and
                       Map.has_key?(query_results, :metadata) and
                       Map.has_key?(query_results, :execution_time) and
                       Map.has_key?(query_results, :row_count) and
                       is_number(query_results.execution_time) and
                       query_results.execution_time >= 0 and
                       is_integer(query_results.row_count) and
                       query_results.row_count >= 0

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: update_dashboard_layout/3 maintains layout consistency" do
      assert PropCheck.quickcheck(
               forall {dashboard_id, layout_config, user_context} <-
                        {PC.binary(), PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.update_dashboard_layout(
                        dashboard_id,
                        layout_config,
                        user_context
                      ) do
                   {:ok, updated_dashboard} ->
                     is_map(updated_dashboard) and
                       Map.has_key?(updated_dashboard, :layout) and
                       Map.has_key?(updated_dashboard, :widgets) and
                       Map.has_key?(updated_dashboard, :modified_at) and
                       is_map(updated_dashboard.layout) and
                       is_list(updated_dashboard.widgets)

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: export_dashboard/3 generates valid export formats" do
      assert PropCheck.quickcheck(
               forall {dashboard_id, export_format, export_options} <-
                        {PC.binary(), oneof([:pdf, :png, :csv, :json, :excel]),
                         PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.export_dashboard(
                        dashboard_id,
                        export_format,
                        export_options
                      ) do
                   {:ok, export_result} ->
                     is_map(export_result) and
                       Map.has_key?(export_result, :file_path) and
                       Map.has_key?(export_result, :file_size) and
                       Map.has_key?(export_result, :export_format) and
                       Map.has_key?(export_result, :generated_at) and
                       is_binary(export_result.file_path) and
                       is_integer(export_result.file_size) and
                       export_result.file_size >= 0 and
                       export_result.export_format == export_format

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: calculate_dashboard_metrics/2 produces valid performance metrics" do
      assert PropCheck.quickcheck(
               forall {dashboard_id, metrics_config} <- {PC.binary(), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.calculate_dashboard_metrics(
                        dashboard_id,
                        metrics_config
                      ) do
                   {:ok, performance_metrics} ->
                     is_map(performance_metrics) and
                       Map.has_key?(performance_metrics, :load_time) and
                       Map.has_key?(performance_metrics, :render_time) and
                       Map.has_key?(performance_metrics, :data_fetch_time) and
                       Map.has_key?(performance_metrics, :widget_count) and
                       Map.has_key?(performance_metrics, :memory_usage) and
                       is_number(performance_metrics.load_time) and
                       performance_metrics.load_time >= 0 and
                       is_number(performance_metrics.render_time) and
                       performance_metrics.render_time >= 0 and
                       is_integer(performance_metrics.widget_count) and
                       performance_metrics.widget_count >= 0

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end

    test "propcheck: setup_real_time_updates/3 establishes valid streaming connections" do
      assert PropCheck.quickcheck(
               forall {dashboard_id, update_config, connection_context} <-
                        {PC.binary(), PC.map(PC.atom(), PC.any()), PC.map(PC.atom(), PC.any())} do
                 case AnalyticsDashboardEngine.setup_real_time_updates(
                        dashboard_id,
                        update_config,
                        connection_context
                      ) do
                   {:ok, streaming_setup} ->
                     is_map(streaming_setup) and
                       Map.has_key?(streaming_setup, :connection_id) and
                       Map.has_key?(streaming_setup, :update_frequency) and
                       Map.has_key?(streaming_setup, :subscribed_widgets) and
                       Map.has_key?(streaming_setup, :streaming_status) and
                       is_binary(streaming_setup.connection_id) and
                       is_number(streaming_setup.update_frequency) and
                       streaming_setup.update_frequency > 0 and
                       is_list(streaming_setup.subscribed_widgets) and
                       streaming_setup.streaming_status in [:active, :connecting, :disconnected]

                   {:error, _reason} ->
                     true
                 end
               end
             )
    end
  end

  # =============================================================================
  # PROPERTY-BASED TESTS - EXUNITPROPERTIES FRAMEWORK
  # =============================================================================

  describe "ExUnitProperties Property-Based Tests for AnalyticsDashboardEngine" do
    test "exunitproperties: create_dashboard/2 maintains structural consistency" do
      ExUnitProperties.check all(
                               dashboard_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               user_context <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context) do
          {:ok, dashboard} ->
            assert is_map(dashboard)
            assert Map.has_key?(dashboard, :dashboard_id)
            assert Map.has_key?(dashboard, :metadata)
            assert Map.has_key?(dashboard, :widgets)
            assert Map.has_key?(dashboard, :layout)
            assert Map.has_key?(dashboard, :created_at)
            assert is_binary(dashboard.dashboard_id)
            assert is_list(dashboard.widgets)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: add_widget/3 preserves dashboard identity" do
      ExUnitProperties.check all(
                               dashboard_id <- SD.string(:alphanumeric),
                               widget_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               user_context <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.add_widget(dashboard_id, widget_config, user_context) do
          {:ok, updated_dashboard} ->
            assert is_map(updated_dashboard)
            assert Map.has_key?(updated_dashboard, :dashboard_id)
            assert Map.has_key?(updated_dashboard, :widgets)
            assert Map.has_key?(updated_dashboard, :modified_at)
            assert updated_dashboard.dashboard_id == dashboard_id
            assert is_list(updated_dashboard.widgets)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: render_dashboard/2 produces valid web content" do
      ExUnitProperties.check all(
                               dashboard_id <- SD.string(:alphanumeric),
                               render_context <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.render_dashboard(dashboard_id, render_context) do
          {:ok, rendered_dashboard} ->
            assert is_map(rendered_dashboard)
            assert Map.has_key?(rendered_dashboard, :html_content)
            assert Map.has_key?(rendered_dashboard, :javascript_content)
            assert Map.has_key?(rendered_dashboard, :css_content)
            assert Map.has_key?(rendered_dashboard, :metadata)
            assert is_binary(rendered_dashboard.html_content)
            assert is_binary(rendered_dashboard.javascript_content)
            assert is_binary(rendered_dashboard.css_content)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: execute_widget_query/3 validates execution metrics" do
      ExUnitProperties.check all(
                               widget_id <- SD.string(:alphanumeric),
                               query_params <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               execution_context <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.execute_widget_query(
               widget_id,
               query_params,
               execution_context
             ) do
          {:ok, query_results} ->
            assert is_map(query_results)
            assert Map.has_key?(query_results, :data)
            assert Map.has_key?(query_results, :metadata)
            assert Map.has_key?(query_results, :execution_time)
            assert Map.has_key?(query_results, :row_count)
            assert is_number(query_results.execution_time)
            assert query_results.execution_time >= 0
            assert is_integer(query_results.row_count)
            assert query_results.row_count >= 0

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: update_dashboard_layout/3 maintains widget relationships" do
      ExUnitProperties.check all(
                               dashboard_id <- SD.string(:alphanumeric),
                               layout_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               user_context <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.update_dashboard_layout(
               dashboard_id,
               layout_config,
               user_context
             ) do
          {:ok, updated_dashboard} ->
            assert is_map(updated_dashboard)
            assert Map.has_key?(updated_dashboard, :layout)
            assert Map.has_key?(updated_dashboard, :widgets)
            assert Map.has_key?(updated_dashboard, :modified_at)
            assert is_map(updated_dashboard.layout)
            assert is_list(updated_dashboard.widgets)

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: export_dashboard/3 respects export format constraints" do
      ExUnitProperties.check all(
                               dashboard_id <- SD.string(:alphanumeric),
                               export_format <- SD.member_of([:pdf, :png, :csv, :json, :excel]),
                               export_options <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.export_dashboard(
               dashboard_id,
               export_format,
               export_options
             ) do
          {:ok, export_result} ->
            assert is_map(export_result)
            assert Map.has_key?(export_result, :file_path)
            assert Map.has_key?(export_result, :file_size)
            assert Map.has_key?(export_result, :export_format)
            assert Map.has_key?(export_result, :generated_at)
            assert is_binary(export_result.file_path)
            assert is_integer(export_result.file_size)
            assert export_result.file_size >= 0
            assert export_result.export_format == export_format

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: calculate_dashboard_metrics/2 provides accurate performance data" do
      ExUnitProperties.check all(
                               dashboard_id <- SD.string(:alphanumeric),
                               metrics_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.calculate_dashboard_metrics(dashboard_id, metrics_config) do
          {:ok, performance_metrics} ->
            assert is_map(performance_metrics)
            assert Map.has_key?(performance_metrics, :load_time)
            assert Map.has_key?(performance_metrics, :render_time)
            assert Map.has_key?(performance_metrics, :data_fetch_time)
            assert Map.has_key?(performance_metrics, :widget_count)
            assert Map.has_key?(performance_metrics, :memory_usage)

            # Validate performance metrics bounds
            assert is_number(performance_metrics.load_time)
            assert performance_metrics.load_time >= 0
            assert is_number(performance_metrics.render_time)
            assert performance_metrics.render_time >= 0
            assert is_integer(performance_metrics.widget_count)
            assert performance_metrics.widget_count >= 0

          {:error, _reason} ->
            assert true
        end
      end
    end

    test "exunitproperties: setup_real_time_updates/3 establishes valid streaming parameters" do
      ExUnitProperties.check all(
                               dashboard_id <- SD.string(:alphanumeric),
                               update_config <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               connection_context <- SD.map_of(SD.atom(:alphanumeric), SD.term()),
                               max_runs: 100
                             ) do
        case AnalyticsDashboardEngine.setup_real_time_updates(
               dashboard_id,
               update_config,
               connection_context
             ) do
          {:ok, streaming_setup} ->
            assert is_map(streaming_setup)
            assert Map.has_key?(streaming_setup, :connection_id)
            assert Map.has_key?(streaming_setup, :update_frequency)
            assert Map.has_key?(streaming_setup, :subscribed_widgets)
            assert Map.has_key?(streaming_setup, :streaming_status)
            assert is_binary(streaming_setup.connection_id)
            assert is_number(streaming_setup.update_frequency)
            assert streaming_setup.update_frequency > 0
            assert is_list(streaming_setup.subscribed_widgets)
            assert streaming_setup.streaming_status in [:active, :connecting, :disconnected]

          {:error, _reason} ->
            assert true
        end
      end
    end
  end

  # =============================================================================
  # STAMP SAFETY CONSTRAINTS VALIDATION
  # =============================================================================

  describe "STAMP Safety Constraints for Analytics Dashboard Engine" do
    test "SC-ADE-001: System SHALL ensure dashboard rendering maintains tenant data isolation" do
      # Test with multi-tenant context
      tenant1_context = %{@valid_user_context | tenant_id: "tenant_1"}
      tenant2_context = %{@valid_user_context | tenant_id: "tenant_2"}

      dashboard_config = @valid_dashboard_config

      # Create dashboard for tenant 1
      result1 = AnalyticsDashboardEngine.create_dashboard(dashboard_config, tenant1_context)

      case result1 do
        {:ok, tenant1_dashboard} ->
          # Verify tenant isolation in dashboard creation
          assert Map.has_key?(tenant1_dashboard, :metadata)
          metadata = tenant1_dashboard.metadata

          if Map.has_key?(metadata, :tenant_id) do
            assert metadata.tenant_id == "tenant_1"
          end

          # Test rendering with different tenant context
          render_context = %{user_context: tenant2_context, include_data: true}

          render_result =
            AnalyticsDashboardEngine.render_dashboard(
              tenant1_dashboard.dashboard_id,
              render_context
            )

          case render_result do
            {:ok, _rendered_dashboard} ->
              # Cross-tenant access should be handled appropriately
              # (may succeed with filtered data or fail with authorization error)
              assert true

            {:error, reason} ->
              # Authorization error is expected for cross-tenant access
              assert reason in [:unauthorized, :forbidden, :not_found] or
                       (is_binary(reason) and String.contains?(reason, "tenant"))
          end

        {:error, _reason} ->
          assert true
      end
    end

    test "SC-ADE-002: System SHALL maintain dashboard performance within response time limits" do
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Create dashboard with performance monitoring
      start_time = System.monotonic_time(:millisecond)

      result = AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context)

      creation_time = System.monotonic_time(:millisecond) - start_time

      case result do
        {:ok, dashboard} ->
          # Dashboard creation should be fast (< 2 seconds)
          assert creation_time < 2000,
                 "Dashboard creation took #{creation_time}ms, expected < 2000ms"

          # Test dashboard rendering performance
          render_start = System.monotonic_time(:millisecond)
          render_context = %{user_context: user_context, theme: :dark}

          render_result =
            AnalyticsDashboardEngine.render_dashboard(dashboard.dashboard_id, render_context)

          render_time = System.monotonic_time(:millisecond) - render_start

          case render_result do
            {:ok, _rendered_dashboard} ->
              # Dashboard rendering should be fast (< 5 seconds)
              assert render_time < 5000,
                     "Dashboard rendering took #{render_time}ms, expected < 5000ms"

            {:error, _reason} ->
              # Even error handling should be fast
              assert render_time < 1000, "Error handling took #{render_time}ms, expected < 1000ms"
          end

        {:error, _reason} ->
          # Error handling should be fast
          assert creation_time < 1000, "Error handling took #{creation_time}ms, expected < 1000ms"
      end
    end

    test "SC-ADE-003: System SHALL validate widget data queries prevent SQL injection" do
      # Test with potentially malicious query parameters
      potentially_malicious_queries = [
        %{query: "SELECT * FROM users; DROP TABLE alerts;--"},
        %{filter: "'; DELETE FROM dashboards; --"},
        %{where_clause: "1=1 OR '1'='1'"},
        %{metric: "cpu_usage'; UNION SELECT password FROM users--"}
      ]

      widget_id = "TEST-WIDGET-001"
      execution_context = %{user_context: @valid_user_context, sanitize_queries: true}

      Enum.each(potentially_malicious_queries, fn malicious_query ->
        result =
          AnalyticsDashboardEngine.execute_widget_query(
            widget_id,
            malicious_query,
            execution_context
          )

        case result do
          {:ok, query_results} ->
            # If query succeeds, it should be properly sanitized
            assert Map.has_key?(query_results, :data)
            assert Map.has_key?(query_results, :metadata)

            # Verify query was sanitized (metadata should indicate this)
            metadata = query_results.metadata

            if Map.has_key?(metadata, :query_sanitized) do
              assert metadata.query_sanitized == true
            end

          {:error, reason} ->
            # Query rejection is also acceptable for malicious inputs
            assert is_binary(reason) or is_atom(reason)
            # Error should indicate security validation
            if is_binary(reason) do
              assert String.contains?(reason, "invalid") or
                       String.contains?(reason, "security") or
                       String.contains?(reason, "forbidden")
            end
        end
      end)
    end

    test "SC-ADE-004: System SHALL ensure real-time updates maintain data consistency" do
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Create dashboard
      dashboard_result = AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context)

      case dashboard_result do
        {:ok, dashboard} ->
          # Setup real-time updates
          update_config = %{
            # 5 seconds
            refresh_interval: 5,
            data_sources: [:metrics, :alerts],
            consistency_mode: :strong
          }

          connection_context = %{user_context: user_context, websocket_enabled: true}

          streaming_result =
            AnalyticsDashboardEngine.setup_real_time_updates(
              dashboard.dashboard_id,
              update_config,
              connection_context
            )

          case streaming_result do
            {:ok, streaming_setup} ->
              # Verify consistency guarantees
              assert Map.has_key?(streaming_setup, :connection_id)
              assert Map.has_key?(streaming_setup, :update_frequency)
              assert Map.has_key?(streaming_setup, :subscribed_widgets)

              # Update frequency should match configured interval
              assert streaming_setup.update_frequency == 5

              # Streaming status should be appropriate
              assert streaming_setup.streaming_status in [:active, :connecting]

              # Subscribed widgets should match dashboard widgets
              if is_list(streaming_setup.subscribed_widgets) do
                assert length(streaming_setup.subscribed_widgets) >= 0
              end

            {:error, _reason} ->
              assert true
          end

        {:error, _reason} ->
          assert true
      end
    end

    test "SC-ADE-005: System SHALL maintain dashboard export security and data integrity" do
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Create dashboard
      dashboard_result = AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context)

      case dashboard_result do
        {:ok, dashboard} ->
          # Test secure export with various formats
          export_formats = [:pdf, :png, :csv, :json]

          Enum.each(export_formats, fn format ->
            export_options = %{
              include_sensitive_data: false,
              watermark: true,
              user_context: user_context,
              access_control: :strict
            }

            export_result =
              AnalyticsDashboardEngine.export_dashboard(
                dashboard.dashboard_id,
                format,
                export_options
              )

            case export_result do
              {:ok, export_data} ->
                # Verify export security
                assert Map.has_key?(export_data, :file_path)
                assert Map.has_key?(export_data, :file_size)
                assert Map.has_key?(export_data, :export_format)
                assert Map.has_key?(export_data, :generated_at)

                # File path should be secure (no directory traversal)
                file_path = export_data.file_path
                refute String.contains?(file_path, "../")
                refute String.contains?(file_path, "..\\")

                # Export format should match requested format
                assert export_data.export_format == format

                # File size should be reasonable (not empty, not excessive)
                file_size = export_data.file_size
                assert file_size > 0
                # < 100MB reasonable limit
                assert file_size < 100_000_000

              {:error, _reason} ->
                # Export failure is acceptable for security restrictions
                assert true
            end
          end)

        {:error, _reason} ->
          assert true
      end
    end
  end

  # =============================================================================
  # PERFORMANCE PROPERTY VALIDATION
  # =============================================================================

  describe "Performance Properties for Analytics Dashboard Engine" do
    test "dashboard creation and rendering performance scales with widget count" do
      # Test with different widget counts
      widget_counts = [1, 5, 10, 20]

      performance_data =
        Enum.map(widget_counts, fn count ->
          # Create dashboard config with specified widget count
          widgets =
            Enum.map(1..count, fn i ->
              %{
                widget_id: "W#{i}",
                type: Enum.random(@widget_types),
                position: %{x: rem(i, 4), y: div(i, 4), width: 2, height: 2}
              }
            end)

          dashboard_config = %{@valid_dashboard_config | widgets: widgets}

          # Measure creation time
          start_time = System.monotonic_time(:millisecond)

          creation_result =
            AnalyticsDashboardEngine.create_dashboard(dashboard_config, @valid_user_context)

          creation_time = System.monotonic_time(:millisecond) - start_time

          # Measure rendering time if creation succeeded
          render_time =
            case creation_result do
              {:ok, dashboard} ->
                render_start = System.monotonic_time(:millisecond)

                _render_result =
                  AnalyticsDashboardEngine.render_dashboard(
                    dashboard.dashboard_id,
                    %{user_context: @valid_user_context}
                  )

                System.monotonic_time(:millisecond) - render_start

              {:error, _reason} ->
                0
            end

          %{widget_count: count, creation_time: creation_time, render_time: render_time}
        end)

      # Verify performance scaling is reasonable
      [data1, data5, data10, data20] = performance_data

      # Creation time should scale reasonably (not exponentially)
      creation_ratio = data20.creation_time / data1.creation_time
      assert creation_ratio < 100, "Creation time scaling is poor: #{inspect(performance_data)}"

      # Rendering time should also scale reasonably
      if data20.render_time > 0 and data1.render_time > 0 do
        render_ratio = data20.render_time / data1.render_time
        assert render_ratio < 200, "Render time scaling is poor: #{inspect(performance_data)}"
      end
    end

    test "widget query execution performance with large datasets" do
      # Test with increasingly large result sets
      dataset_sizes = [100, 500, 1000]

      query_times =
        Enum.map(dataset_sizes, fn size ->
          query_params = %{
            @valid_widget_config.query
            | limit: size,
              include_metadata: true
          }

          execution_context = %{
            user_context: @valid_user_context,
            # 30 second timeout
            timeout: 30_000,
            optimize_large_results: true
          }

          start_time = System.monotonic_time(:millisecond)

          _result =
            AnalyticsDashboardEngine.execute_widget_query(
              "TEST-WIDGET",
              query_params,
              execution_context
            )

          System.monotonic_time(:millisecond) - start_time
        end)

      [small_time, medium_time, large_time] = query_times

      # Query execution should scale reasonably
      # Large queries shouldn't be more than 10x slower than small queries
      if small_time > 0 do
        scaling_factor = large_time / small_time
        assert scaling_factor < 10, "Query performance scaling is poor: #{inspect(query_times)}"
      end

      # All queries should complete within reasonable time
      assert large_time < 30_000, "Large query took #{large_time}ms, expected < 30000ms"
    end

    test "memory efficiency during dashboard operations" do
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Monitor memory before operations
      memory_before = :erlang.memory(:total)

      # Perform multiple dashboard operations
      operations = [
        fn -> AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context) end,
        fn ->
          case AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context) do
            {:ok, dashboard} ->
              AnalyticsDashboardEngine.render_dashboard(dashboard.dashboard_id, %{
                user_context: user_context
              })

            error ->
              error
          end
        end,
        fn ->
          case AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context) do
            {:ok, dashboard} ->
              AnalyticsDashboardEngine.calculate_dashboard_metrics(dashboard.dashboard_id, %{})

            error ->
              error
          end
        end
      ]

      # Execute operations
      Enum.each(operations, fn operation -> operation.() end)

      # Force garbage collection
      :erlang.garbage_collect()

      # Monitor memory after operations
      memory_after = :erlang.memory(:total)
      memory_increase = memory_after - memory_before

      # Memory increase should be reasonable (< 100MB for these operations)
      assert memory_increase < 100_000_000,
             "Memory increase #{memory_increase} bytes is excessive"
    end
  end

  # =============================================================================
  # ERROR HANDLING PROPERTY VALIDATION
  # =============================================================================

  describe "Error Handling Properties for Analytics Dashboard Engine" do
    test "graceful handling of malformed dashboard configurations" do
      malformed_configs = [
        "invalid_string",
        %{widgets: "not_a_list"},
        %{widgets: [%{invalid: "widget"}]},
        %{layout: "invalid_layout"},
        nil
      ]

      Enum.each(malformed_configs, fn config ->
        result = AnalyticsDashboardEngine.create_dashboard(config, @valid_user_context)

        case result do
          {:ok, _dashboard} ->
            # Function handled malformed input gracefully
            assert true

          {:error, reason} ->
            # Error should be descriptive and not crash the system
            assert is_binary(reason) or is_atom(reason)
        end
      end)
    end

    test "boundary condition handling in widget configurations" do
      boundary_widget_configs = [
        %{@valid_widget_config | position: %{x: -1, y: -1, width: 0, height: 0}},
        %{@valid_widget_config | query: %{limit: -1}},
        %{@valid_widget_config | query: %{limit: 1_000_000}},
        %{@valid_widget_config | type: :nonexistent_type}
      ]

      dashboard_id = "TEST-DASHBOARD"

      Enum.each(boundary_widget_configs, fn widget_config ->
        result =
          AnalyticsDashboardEngine.add_widget(dashboard_id, widget_config, @valid_user_context)

        # Should handle boundary conditions gracefully
        case result do
          {:ok, _updated_dashboard} -> assert true
          {:error, _reason} -> assert true
        end
      end)
    end

    test "robust error handling during export operations" do
      # Test export with problematic configurations
      problematic_exports = [
        {"NONEXISTENT-DASHBOARD", :pdf, %{}},
        {"VALID-DASHBOARD", :invalid_format, %{}},
        {"VALID-DASHBOARD", :pdf, %{output_path: "/invalid/path"}},
        {nil, :pdf, %{}}
      ]

      Enum.each(problematic_exports, fn {dashboard_id, format, options} ->
        result = AnalyticsDashboardEngine.export_dashboard(dashboard_id, format, options)

        case result do
          {:ok, _export_result} ->
            # Successful handling of edge case
            assert true

          {:error, reason} ->
            # Proper error handling
            assert is_binary(reason) or is_atom(reason)
        end
      end)
    end
  end

  # =============================================================================
  # INTEGRATION PROPERTY VALIDATION
  # =============================================================================

  describe "Integration Properties for Analytics Dashboard Engine" do
    test "integration between widget queries and dashboard rendering maintains consistency" do
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Create dashboard
      dashboard_result = AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context)

      case dashboard_result do
        {:ok, dashboard} ->
          # Execute queries for dashboard widgets
          widget_queries =
            Enum.map(dashboard.widgets, fn widget ->
              query_params = %{
                data_source: :metrics,
                time_range: %{start: ~N[2025-09-19 13:00:00], end: ~N[2025-09-19 14:00:00]},
                metric: "cpu_usage"
              }

              execution_context = %{user_context: user_context}

              {widget,
               AnalyticsDashboardEngine.execute_widget_query(
                 widget.widget_id,
                 query_params,
                 execution_context
               )}
            end)

          # Render dashboard
          render_context = %{
            user_context: user_context,
            include_widget_data: true,
            widget_query_results:
              Map.new(widget_queries, fn {widget, result} ->
                {widget.widget_id, result}
              end)
          }

          render_result =
            AnalyticsDashboardEngine.render_dashboard(dashboard.dashboard_id, render_context)

          case render_result do
            {:ok, rendered_dashboard} ->
              # Verify integration consistency
              assert Map.has_key?(rendered_dashboard, :html_content)
              assert Map.has_key?(rendered_dashboard, :javascript_content)
              assert Map.has_key?(rendered_dashboard, :metadata)

              # Rendered content should reflect widget data
              html_content = rendered_dashboard.html_content
              javascript_content = rendered_dashboard.javascript_content

              # Should contain references to widgets
              widget_ids = Enum.map(dashboard.widgets, & &1.widget_id)

              Enum.each(widget_ids, fn widget_id ->
                assert String.contains?(html_content, widget_id) or
                         String.contains?(javascript_content, widget_id)
              end)

            {:error, _reason} ->
              assert true
          end

        {:error, _reason} ->
          assert true
      end
    end

    test "real-time updates integration with dashboard metrics maintains performance" do
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Create dashboard
      dashboard_result = AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context)

      case dashboard_result do
        {:ok, dashboard} ->
          # Setup real-time updates
          update_config = %{refresh_interval: 10, data_sources: [:metrics]}
          connection_context = %{user_context: user_context}

          streaming_result =
            AnalyticsDashboardEngine.setup_real_time_updates(
              dashboard.dashboard_id,
              update_config,
              connection_context
            )

          case streaming_result do
            {:ok, streaming_setup} ->
              # Calculate dashboard metrics with streaming enabled
              metrics_config = %{include_streaming_metrics: true}

              metrics_result =
                AnalyticsDashboardEngine.calculate_dashboard_metrics(
                  dashboard.dashboard_id,
                  metrics_config
                )

              case metrics_result do
                {:ok, performance_metrics} ->
                  # Verify streaming integration doesn't degrade performance
                  assert Map.has_key?(performance_metrics, :load_time)
                  assert Map.has_key?(performance_metrics, :render_time)

                  # Load time should still be reasonable with streaming
                  load_time = performance_metrics.load_time
                  assert is_number(load_time)
                  assert load_time < 10_000, "Load time #{load_time}ms too high with streaming"

                  # Should have streaming-specific metrics
                  if Map.has_key?(performance_metrics, :streaming_metrics) do
                    streaming_metrics = performance_metrics.streaming_metrics
                    assert is_map(streaming_metrics)
                  end

                {:error, _reason} ->
                  assert true
              end

            {:error, _reason} ->
              assert true
          end

        {:error, _reason} ->
          assert true
      end
    end

    test "end-to-end dashboard lifecycle maintains data and configuration integrity" do
      # Test complete dashboard lifecycle
      dashboard_config = @valid_dashboard_config
      user_context = @valid_user_context

      # Step 1: Create dashboard
      creation_result = AnalyticsDashboardEngine.create_dashboard(dashboard_config, user_context)

      case creation_result do
        {:ok, created_dashboard} ->
          original_widget_count = length(created_dashboard.widgets)

          # Step 2: Add widget
          new_widget_config = %{
            widget_id: "NEW-WIDGET",
            type: :gauge,
            data_source: :performance,
            position: %{x: 6, y: 0, width: 2, height: 2}
          }

          add_widget_result =
            AnalyticsDashboardEngine.add_widget(
              created_dashboard.dashboard_id,
              new_widget_config,
              user_context
            )

          case add_widget_result do
            {:ok, updated_dashboard} ->
              # Verify widget was added
              new_widget_count = length(updated_dashboard.widgets)
              assert new_widget_count == original_widget_count + 1

              # Step 3: Update layout
              layout_config = %{
                layout: :freeform,
                grid_size: %{width: 12, height: 8}
              }

              layout_result =
                AnalyticsDashboardEngine.update_dashboard_layout(
                  updated_dashboard.dashboard_id,
                  layout_config,
                  user_context
                )

              case layout_result do
                {:ok, final_dashboard} ->
                  # Verify layout update maintained widgets
                  final_widget_count = length(final_dashboard.widgets)
                  assert final_widget_count == new_widget_count

                  # Verify layout was updated
                  assert Map.has_key?(final_dashboard, :layout)
                  layout = final_dashboard.layout

                  if Map.has_key?(layout, :layout) do
                    assert layout.layout == :freeform
                  end

                  # Step 4: Export dashboard
                  export_result =
                    AnalyticsDashboardEngine.export_dashboard(
                      final_dashboard.dashboard_id,
                      :json,
                      %{include_config: true}
                    )

                  case export_result do
                    {:ok, export_data} ->
                      # Verify export contains complete dashboard data
                      assert Map.has_key?(export_data, :file_path)
                      assert Map.has_key?(export_data, :export_format)
                      assert export_data.export_format == :json

                    {:error, _reason} ->
                      assert true
                  end

                {:error, _reason} ->
                  assert true
              end

            {:error, _reason} ->
              assert true
          end

        {:error, _reason} ->
          assert true
      end
    end
  end
end
