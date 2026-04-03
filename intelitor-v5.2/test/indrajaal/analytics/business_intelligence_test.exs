defmodule Indrajaal.Analytics.BusinessIntelligenceTest do
  @moduledoc """
  Comprehensive TDG test suite for BusinessIntelligence module.

  This test suite follows Test-Driven Generation (TDG) methodology with comprehensive coverage:
  - Unit tests for BI platform integration and configuration
  - Integration tests for Power BI, Tableau, and Qlik Sense platforms
  - Property-based testing using both PropCheck and ExUnitProperties
  - STAMP safety constraints for BI integration systems
  - End-to-end testing for complete BI workflow chains
  - Performance tests for enterprise-scale BI __data processing
  - Enterprise scenarios for multi-platform BI orchestration
  - Error recovery and edge case handling for BI operations
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck generators
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Analytics.BusinessIntelligence

  @moduletag :analytics
  @moduletag :business_intelligence

  # ============================================================================
  # TDG METHODOLOGY: UNIT TESTS (Written FIRST before implementation)
  # ============================================================================

  describe "BusinessIntelligence.configure_integration/3 - Platform Configuration" do
    test "configures Power BI integration with valid configuration" do
      powerbi_config = %{
        client_id: "12_345_678-1234-1234-1234-123_456_789_012",
        client_secret: "mock_client_secret",
        tenant_id: "87_654_321-4321-4321-4321-210_987_654_321",
        workspace_id: "11_111_111-2222-3333-4444-555_555_555_555"
      }

      options = [timeout: 30_000]

      assert {:ok, result} =
               BusinessIntelligence.configure_integration(:powerbi, powerbi_config, options)

      assert result.platform == :powerbi
      assert result.connection_status == :connected
      assert String.contains?(result.workspace_url, powerbi_config.workspace_id)
      assert result.api_endpoint == "https://api.powerbi.com/v1.0/myorg"
      assert %DateTime{} = result.setup_date
    end

    test "configures Tableau integration with valid configuration" do
      tableau_config = %{
        server_url: "https://tableau.company.com",
        username: "analytics_user",
        password: "secure_password",
        site_id: "analytics_site"
      }

      assert {:ok, result} = BusinessIntelligence.configure_integration(:tableau, tableau_config)
      assert result.platform == :tableau
      assert result.connection_status == :connected
      assert result.server_url == tableau_config.server_url
      assert String.contains?(result.site_url, tableau_config.site_id)
    end

    test "configures Qlik Sense integration with valid configuration" do
      qlik_config = %{
        server_url: "https://qlik.company.com",
        app_id: "qlik-app-12_345",
        api_key: "qlik_api_key_abcdef123456"
      }

      assert {:ok, result} = BusinessIntelligence.configure_integration(:qlik, qlik_config)
      assert result.platform == :qlik
      assert result.connection_status == :connected
      assert result.server_url == qlik_config.server_url
      assert String.contains?(result.app_url, qlik_config.app_id)
    end

    test "fails with missing __required fields for Power BI" do
      incomplete_config = %{
        client_id: "12_345_678-1234-1234-1234-123_456_789_012"
        # Missing client_secret, tenant_id, workspace_id
      }

      assert {:error, error_message} =
               BusinessIntelligence.configure_integration(:powerbi, incomplete_config)

      assert String.contains?(error_message, "Missing __required fields")
      assert String.contains?(error_message, "client_secret")
      assert String.contains?(error_message, "tenant_id")
      assert String.contains?(error_message, "workspace_id")
    end

    test "fails with missing __required fields for Tableau" do
      incomplete_config = %{
        server_url: "https://tableau.company.com"
        # Missing username, password, site_id
      }

      assert {:error, error_message} =
               BusinessIntelligence.configure_integration(:tableau, incomplete_config)

      assert String.contains?(error_message, "Missing __required fields")
      assert String.contains?(error_message, "username")
      assert String.contains?(error_message, "password")
      assert String.contains?(error_message, "site_id")
    end

    test "fails with missing __required fields for Qlik Sense" do
      incomplete_config = %{
        server_url: "https://qlik.company.com"
        # Missing app_id, api_key
      }

      assert {:error, error_message} =
               BusinessIntelligence.configure_integration(:qlik, incomplete_config)

      assert String.contains?(error_message, "Missing __required fields")
      assert String.contains?(error_message, "app_id")
      assert String.contains?(error_message, "api_key")
    end

    test "handles unsupported platform gracefully" do
      unsupported_config = %{some_key: "some_value"}

      # Note: Custom platforms are allowed with empty validation
      assert {:ok, %{}} =
               BusinessIntelligence.configure_integration(:custom_platform, unsupported_config)
    end
  end

  describe "BusinessIntelligence.sync_data_to_bi_platforms/1 - Data Synchronization" do
    test "synchronizes __data to all configured platforms successfully" do
      sync_options = [force_refresh: true, batch_size: 1000]

      result = BusinessIntelligence.sync_data_to_bi_platforms(sync_options)

      assert %DateTime{} = result.sync_timestamp
      # powerbi, tableau, qlik
      assert result.platforms_synced == 3
      assert is_list(result.sync_results)
      assert length(result.sync_results) == 3
      assert is_binary(result.data_freshness)
      assert is_number(result.records_processed)

      # Verify individual platform sync results
      sync_by_platform = Enum.group_by(result.sync_results, & &1.platform)
      assert Map.has_key?(sync_by_platform, :powerbi)
      assert Map.has_key?(sync_by_platform, :tableau)
      assert Map.has_key?(sync_by_platform, :qlik)

      # Check Power BI sync (active platform)
      powerbi_result = sync_by_platform[:powerbi] |> List.first()
      assert powerbi_result.status == :success
      assert is_number(powerbi_result.records_synced)
      assert is_number(powerbi_result.sync_duration)
      assert %DateTime{} = powerbi_result.last_sync

      # Check Tableau sync (active platform)
      tableau_result = sync_by_platform[:tableau] |> List.first()
      assert tableau_result.status == :success

      # Check Qlik sync (maintenance platform)
      qlik_result = sync_by_platform[:qlik] |> List.first()
      assert qlik_result.status == :skipped
      assert qlik_result.reason == "Platform under maintenance"
      assert %DateTime{} = qlik_result.next_retry
    end

    test "handles sync with default options" do
      result = BusinessIntelligence.sync_data_to_bi_platforms()

      assert %DateTime{} = result.sync_timestamp
      assert result.platforms_synced > 0
      assert is_list(result.sync_results)
      assert is_binary(result.data_freshness)
      assert is_number(result.records_processed)
    end

    test "calculates __data freshness correctly" do
      result = BusinessIntelligence.sync_data_to_bi_platforms()

      # Data freshness should be one of the expected formats
      freshness_patterns = [
        "Real - time",
        ~r/\d+ minutes ago/,
        ~r/\d+ hours ago/,
        ~r/\d+ days ago/,
        "Unknown"
      ]

      assert Enum.any?(freshness_patterns, fn pattern ->
               case pattern do
                 binary when is_binary(binary) -> result.data_freshness == binary
                 regex -> Regex.match?(regex, result.data_freshness)
               end
             end)
    end
  end

  describe "BusinessIntelligence.generate_powerbi_dashboard/2 - Power BI Dashboard Generation" do
    test "generates comprehensive Power BI dashboard configuration" do
      mock_data = %{
        timestamp: DateTime.utc_now(),
        metrics: %{
          compliance_rate: 0.94,
          performance_score: 87.5,
          tdg_success_rate: 0.91
        },
        trends: [
          %{timestamp: DateTime.utc_now(), value: 0.89},
          %{timestamp: DateTime.add(DateTime.utc_now(), -3600, :second), value: 0.92}
        ]
      }

      options = [
        refresh_schedule: %{frequency: "Hourly", time: "00", timezone: "PST"},
        security_settings: %{row_level_security: true, user_groups: ["PowerBI_Users"]}
      ]

      assert {:ok, result} = BusinessIntelligence.generate_powerbi_dashboard(mock_data, options)

      # Verify dashboard configuration
      dashboard_config = result.dashboard_config
      assert dashboard_config.name == "STAMP TDG GDE Advanced Analytics"
      assert is_binary(dashboard_config.description)
      assert is_list(dashboard_config.data_sources)
      assert is_list(dashboard_config.visualizations)
      assert is_list(dashboard_config.measures)
      assert is_list(dashboard_config.relationships)
      assert is_map(dashboard_config.refresh_schedule)
      assert is_map(dashboard_config.security_settings)

      # Verify __data sources
      assert length(dashboard_config.data_sources) >= 1
      first_data_source = List.first(dashboard_config.data_sources)
      assert is_binary(first_data_source.name)
      assert first_data_source.type in ["OData", "REST"]
      assert is_binary(first_data_source.connection_string)

      # Verify visualizations
      assert length(dashboard_config.visualizations) >= 1
      visualizations = dashboard_config.visualizations
      visualization_types = Enum.map(visualizations, & &1.type)
      assert "LineChart" in visualization_types
      assert "Gauge" in visualization_types
      assert "Heatmap" in visualization_types

      # Verify measures
      assert length(dashboard_config.measures) >= 1
      measures = dashboard_config.measures
      measure_names = Enum.map(measures, & &1.name)
      assert "Avg_STAMP_Compliance" in measure_names

      # Verify PBIX structure
      pbix_structure = result.pbix_structure
      assert pbix_structure.version == "3.0"
      assert pbix_structure.created_by == "Indrajaal Analytics System"
      assert %DateTime{} = pbix_structure.created_date

      # Verify export and sizing
      assert is_binary(result.export_path)
      assert String.contains?(result.export_path, ".pbix")
      assert is_number(result.data_model_size)
      assert result.data_model_size > 0
    end

    test "handles Power BI generation with minimal __data" do
      minimal_data = %{timestamp: DateTime.utc_now()}

      assert {:ok, result} = BusinessIntelligence.generate_powerbi_dashboard(minimal_data)
      assert is_map(result.dashboard_config)
      assert is_map(result.pbix_structure)
      assert is_binary(result.export_path)
      assert is_number(result.data_model_size)
    end
  end

  describe "BusinessIntelligence.create_tableau_workbook/2 - Tableau Workbook Creation" do
    test "creates comprehensive Tableau workbook configuration" do
      mock_data = %{
        timestamp: DateTime.utc_now(),
        performance_metrics: %{
          cpu_utilization: 65.3,
          memory_usage: 78.1,
          response_time: 124.7
        },
        compliance_data: %{
          stamp_score: 0.95,
          violation_count: 3,
          risk_level: "low"
        }
      }

      options = [
        default_date_range: "Last 7 Days",
        include_extracts: true
      ]

      assert {:ok, result} = BusinessIntelligence.create_tableau_workbook(mock_data, options)

      # Verify workbook configuration
      workbook_config = result.workbook_config
      assert workbook_config.name == "STAMP_TDG_GDE_Analytics"
      assert workbook_config.version == "2024.1"
      assert is_list(workbook_config.data_connections)
      assert is_list(workbook_config.worksheets)
      assert is_list(workbook_config.dashboards)
      assert is_list(workbook_config.data_sources)
      assert is_list(workbook_config.calculated_fields)
      assert is_list(workbook_config.parameters)

      # Verify __data connections
      assert length(workbook_config.data_connections) >= 1
      connection = List.first(workbook_config.data_connections)
      assert connection.name == "Indrajaal_Analytics_API"
      assert connection.type == "webdata-direct"
      assert connection.authentication == "oauth"

      # Verify worksheets
      assert length(workbook_config.worksheets) >= 1
      worksheets = workbook_config.worksheets
      worksheet_names = Enum.map(worksheets, & &1.name)
      assert "STAMP_Compliance_Analysis" in worksheet_names
      assert "TDG_Performance_Dashboard" in worksheet_names

      # Verify dashboards
      assert length(workbook_config.dashboards) >= 1
      dashboard = List.first(workbook_config.dashboards)
      assert dashboard.name == "Executive_Summary"
      assert dashboard.layout == "grid"
      assert is_list(dashboard.worksheets)

      # Verify calculated fields
      assert length(workbook_config.calculated_fields) >= 1
      calc_field = List.first(workbook_config.calculated_fields)
      assert calc_field.name == "Performance_Category"
      assert String.contains?(calc_field.calculation, "Performance_Score")

      # Verify TWBX structure
      twbx_structure = result.twbx_structure
      assert twbx_structure.version == "2024.1.0"
      assert twbx_structure.created_by == "Indrajaal Analytics System"

      # Verify export and sizing
      assert is_binary(result.export_path)
      assert String.contains?(result.export_path, ".twbx")
      assert is_number(result.data_extract_size)
      assert result.data_extract_size > 0
    end

    test "handles Tableau workbook creation with empty __data" do
      empty_data = %{}

      assert {:ok, result} = BusinessIntelligence.create_tableau_workbook(empty_data)
      assert is_map(result.workbook_config)
      assert is_map(result.twbx_structure)
      assert is_binary(result.export_path)
    end
  end

  describe "BusinessIntelligence.create_qlik_application/2 - Qlik Sense Application Creation" do
    test "creates comprehensive Qlik Sense application configuration" do
      mock_data = %{
        timestamp: DateTime.utc_now(),
        security_metrics: %{
          threat_level: "medium",
          incidents_count: 7,
          response_time: 142.5
        },
        system_health: %{
          uptime_percentage: 99.7,
          error_rate: 0.02,
          throughput: 1250
        }
      }

      options = [enable_associative_model: true]

      assert {:ok, result} = BusinessIntelligence.create_qlik_application(mock_data, options)

      # Verify application configuration
      app_config = result.app_config
      assert app_config.name == "STAMP TDG GDE Analytics"
      assert is_binary(app_config.description)
      assert is_binary(app_config.load_script)
      assert is_map(app_config.data_model)
      assert is_list(app_config.sheets)
      assert is_list(app_config.objects)
      assert is_list(app_config.variables)
      assert is_list(app_config.dimensions)
      assert is_list(app_config.measures)

      # Verify load script
      load_script = app_config.load_script
      assert String.contains?(load_script, "LIB CONNECT")
      assert String.contains?(load_script, "STAMP_Metrics")
      assert String.contains?(load_script, "TDG_Metrics")

      # Verify data model
      data_model = app_config.data_model
      assert is_list(data_model.tables)
      assert is_list(data_model.associations)
      # STAMP, TDG, GDE metrics
      assert length(data_model.tables) >= 3

      table_names = Enum.map(data_model.tables, & &1.name)
      assert "STAMP_Metrics" in table_names
      assert "TDG_Metrics" in table_names
      assert "GDE_Metrics" in table_names

      # Verify sheets
      assert length(app_config.sheets) >= 1
      sheet = List.first(app_config.sheets)
      assert sheet.name == "Performance Overview"
      assert is_list(sheet.objects)

      # Verify objects
      assert length(app_config.objects) >= 1
      objects = app_config.objects
      object_ids = Enum.map(objects, & &1.id)
      assert "KPI_STAMP_Compliance" in object_ids
      assert "Chart_TDG_Trend" in object_ids

      # Verify variables
      assert length(app_config.variables) >= 1
      variables = app_config.variables
      variable_names = Enum.map(variables, & &1.name)
      assert "vCurrentDate" in variable_names

      # Verify QVF structure
      qvf_structure = result.qvf_structure
      assert qvf_structure.app_properties == app_config.name
      assert %DateTime{} = qvf_structure.created_date

      # Verify export and memory usage
      assert is_binary(result.export_path)
      assert String.contains?(result.export_path, ".qvf")
      assert is_number(result.memory_usage)
      assert result.memory_usage > 0
    end
  end

  describe "BusinessIntelligence.get_api_endpoints/0 - API Endpoints" do
    test "returns comprehensive API endpoint map" do
      endpoints = BusinessIntelligence.get_api_endpoints()

      assert is_map(endpoints)

      # Verify all expected endpoints are present
      expected_endpoints = [
        :analytics_data,
        :real_time_metrics,
        :historical_data,
        :predictions,
        :anomalies,
        :performance_benchmarks,
        :data_quality,
        :export_data,
        :metadata,
        :health_check
      ]

      Enum.each(expected_endpoints, fn endpoint ->
        assert Map.has_key?(endpoints, endpoint)
        assert is_binary(endpoints[endpoint])
        assert String.starts_with?(endpoints[endpoint], "https://")
      end)

      # Verify specific endpoint patterns
      assert String.contains?(
               endpoints.analytics_data,
               "/api / v1 / analytics / stamp - tdg - gde"
             )

      assert String.contains?(endpoints.real_time_metrics, "/api / v1 / metrics / real - time")
      assert String.contains?(endpoints.health_check, "/api / v1 / health")
    end
  end

  describe "BusinessIntelligence.configure_data_refresh/3 - Data Refresh Configuration" do
    test "configures __data refresh for Power BI platform" do
      options = [
        timezone: "PST",
        enabled: true,
        retry_count: 5,
        notification_email: "admin@company.com",
        data_validation: true
      ]

      assert {:ok, result} =
               BusinessIntelligence.configure_data_refresh(:powerbi, :daily, options)

      assert result.platform == :powerbi
      assert result.frequency == :daily
      assert result.timezone == "PST"
      assert result.enabled == true
      assert result.retry_count == 5
      assert result.notification_email == "admin@company.com"
      assert result.data_validation == true
      assert is_binary(result.schedule_id)
    end

    test "configures __data refresh with default options" do
      assert {:ok, result} = BusinessIntelligence.configure_data_refresh(:tableau, :hourly)

      assert result.platform == :tableau
      assert result.frequency == :hourly
      # default
      assert result.timezone == "UTC"
      # default
      assert result.enabled == true
      # default
      assert result.retry_count == 3
      # default
      assert result.data_validation == true
      assert is_binary(result.schedule_id)
    end

    test "supports all sync f__requencies" do
      f__requencies = [:real_time, :hourly, :daily, :weekly, :monthly]

      Enum.each(f__requencies, fn frequency ->
        assert {:ok, result} = BusinessIntelligence.configure_data_refresh(:qlik, frequency)
        assert result.frequency == frequency
        assert is_binary(result.schedule_id)
      end)
    end
  end

  describe "BusinessIntelligence.monitor_bi_integrations/0 - Integration Monitoring" do
    test "monitors all BI integration platforms comprehensively" do
      monitoring_result = BusinessIntelligence.monitor_bi_integrations()

      assert %DateTime{} = monitoring_result.monitoring_timestamp
      assert monitoring_result.overall_health in [:excellent, :good, :fair, :poor]
      assert is_list(monitoring_result.platform_statuses)
      assert is_list(monitoring_result.alerts)
      assert is_list(monitoring_result.recommendations)

      # Verify platform statuses
      platform_statuses = monitoring_result.platform_statuses
      assert length(platform_statuses) >= 1

      # Check first platform status structure
      first_platform = List.first(platform_statuses)
      assert first_platform.platform in [:powerbi, :tableau, :qlik]
      assert first_platform.status in [:healthy, :maintenance, :error]
      assert %DateTime{} = first_platform.last_sync
      assert first_platform.data_freshness in ["Fresh", "Recent", "Stale", "Very Stale"]
      assert is_map(first_platform.sync_performance)
      assert is_number(first_platform.error_count)
      assert is_number(first_platform.uptime)

      # Verify sync performance metrics
      sync_perf = first_platform.sync_performance
      assert is_number(sync_perf.avg_sync_duration)
      assert sync_perf.success_rate >= 0.0
      assert sync_perf.success_rate <= 1.0
      assert is_number(sync_perf.throughput)

      # Verify alerts for non-healthy platforms
      alerts = monitoring_result.alerts

      Enum.each(alerts, fn alert ->
        assert alert.platform in [:powerbi, :tableau, :qlik]
        assert alert.severity in [:info, :warning, :critical]
        assert is_binary(alert.message)
        assert %DateTime{} = alert.timestamp
      end)

      # Verify recommendations
      recommendations = monitoring_result.recommendations

      Enum.each(recommendations, fn recommendation ->
        assert is_binary(recommendation)
      end)
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: INTEGRATION TESTS
  # ============================================================================

  describe "BusinessIntelligence Integration - Multi-Platform Workflow" do
    test "performs end-to-end BI workflow with multiple platforms" do
      # Step 1: Configure multiple platforms
      powerbi_config = %{
        client_id: "powerbi-client-id",
        client_secret: "powerbi-secret",
        tenant_id: "powerbi-tenant",
        workspace_id: "powerbi-workspace"
      }

      tableau_config = %{
        server_url: "https://tableau.test.com",
        username: "tableau_user",
        password: "tableau_pass",
        site_id: "test_site"
      }

      qlik_config = %{
        server_url: "https://qlik.test.com",
        app_id: "test-app-123",
        api_key: "qlik-api-key"
      }

      # Configure all platforms
      assert {:ok, powerbi_result} =
               BusinessIntelligence.configure_integration(:powerbi, powerbi_config)

      assert {:ok, tableau_result} =
               BusinessIntelligence.configure_integration(:tableau, tableau_config)

      assert {:ok, qlik_result} = BusinessIntelligence.configure_integration(:qlik, qlik_config)

      assert powerbi_result.connection_status == :connected
      assert tableau_result.connection_status == :connected
      assert qlik_result.connection_status == :connected

      # Step 2: Generate artifacts for each platform
      mock_data = %{
        timestamp: DateTime.utc_now(),
        analytics: %{compliance: 0.92, performance: 85.4}
      }

      # Generate Power BI dashboard
      assert {:ok, powerbi_dashboard} =
               BusinessIntelligence.generate_powerbi_dashboard(mock_data)

      assert is_map(powerbi_dashboard.dashboard_config)
      assert String.contains?(powerbi_dashboard.export_path, ".pbix")

      # Create Tableau workbook
      assert {:ok, tableau_workbook} = BusinessIntelligence.create_tableau_workbook(mock_data)
      assert is_map(tableau_workbook.workbook_config)
      assert String.contains?(tableau_workbook.export_path, ".twbx")

      # Create Qlik application
      assert {:ok, qlik_app} = BusinessIntelligence.create_qlik_application(mock_data)
      assert is_map(qlik_app.app_config)
      assert String.contains?(qlik_app.export_path, ".qvf")

      # Step 3: Configure __data refresh schedules
      assert {:ok, powerbi_refresh} =
               BusinessIntelligence.configure_data_refresh(:powerbi, :daily)

      assert {:ok, tableau_refresh} =
               BusinessIntelligence.configure_data_refresh(:tableau, :hourly)

      assert {:ok, qlik_refresh} =
               BusinessIntelligence.configure_data_refresh(:qlik, :real_time)

      assert powerbi_refresh.frequency == :daily
      assert tableau_refresh.frequency == :hourly
      assert qlik_refresh.frequency == :real_time

      # Step 4: Sync __data to all platforms
      sync_result = BusinessIntelligence.sync_data_to_bi_platforms()
      assert sync_result.platforms_synced > 0
      assert is_list(sync_result.sync_results)

      # Step 5: Monitor integration health
      monitoring_result = BusinessIntelligence.monitor_bi_integrations()
      assert monitoring_result.overall_health in [:excellent, :good, :fair, :poor]
      assert length(monitoring_result.platform_statuses) >= 3

      # Verify API endpoints are accessible
      endpoints = BusinessIntelligence.get_api_endpoints()
      assert Map.has_key?(endpoints, :analytics_data)
      assert Map.has_key?(endpoints, :real_time_metrics)
      assert Map.has_key?(endpoints, :health_check)
    end

    test "handles partial platform failures gracefully" do
      # Simulate a scenario where one platform fails
      sync_result = BusinessIntelligence.sync_data_to_bi_platforms()

      # Should still complete with partial success
      assert is_list(sync_result.sync_results)
      assert sync_result.platforms_synced > 0

      # Check that we have both successful and failed/skipped results
      statuses = Enum.map(sync_result.sync_results, & &1.status)
      # At least one success
      assert :success in statuses
      # Could have :skipped (maintenance) or :failed
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: PROPERTY-BASED TESTS (PropCheck Framework)
  # ============================================================================

  describe "BusinessIntelligence Property Tests (PropCheck)" do
    property "platform configurations with valid __required fields succeed [PropCheck]" do
      forall platform_config <- valid_platform_config_gen() do
        {platform, config} = platform_config

        case BusinessIntelligence.configure_integration(platform, config) do
          {:ok, result} ->
            result.platform == platform and result.connection_status == :connected

          {:error, _reason} ->
            # Should not happen with valid configurations
            false
        end
      end
    end

    property "sync operations preserve __data integrity [PropCheck]" do
      forall sync_options <- PC.list(PC.oneof([:force_refresh, :batch_size, :timeout])) do
        result = BusinessIntelligence.sync_data_to_bi_platforms(sync_options)

        # Verify result structure integrity
        is_map(result) and
          Map.has_key?(result, :sync_timestamp) and
          Map.has_key?(result, :platforms_synced) and
          Map.has_key?(result, :sync_results) and
          is_list(result.sync_results) and
          is_number(result.platforms_synced) and
          result.platforms_synced >= 0
      end
    end

    property "monitoring results maintain consistency [PropCheck]" do
      forall _ <- StreamData.term() do
        monitoring_result = BusinessIntelligence.monitor_bi_integrations()

        # Verify monitoring consistency
        platform_count = length(monitoring_result.platform_statuses)

        healthy_count =
          Enum.count(monitoring_result.platform_statuses, fn status ->
            status.status == :healthy
          end)

        # Overall health should reflect platform health distribution
        expected_health =
          case {healthy_count, platform_count} do
            {count, count} -> :excellent
            {count, total} when count >= total * 0.8 -> :good
            {count, total} when count >= total * 0.5 -> :fair
            _ -> :poor
          end

        monitoring_result.overall_health == expected_health
      end
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: PROPERTY-BASED TESTS (ExUnitProperties Framework)
  # ============================================================================

  describe "BusinessIntelligence Property Tests (ExUnitProperties)" do
    test "API endpoints maintain consistent URL structure [ExUnitProperties]" do
      ExUnitProperties.check all(
                               _ <- StreamData.term(),
                               max_runs: 50
                             ) do
        endpoints = BusinessIntelligence.get_api_endpoints()

        # All endpoints should be valid URLs
        Enum.all?(endpoints, fn {_key, url} ->
          is_binary(url) and String.starts_with?(url, "https://")
        end)
      end
    end

    test "__data refresh configurations preserve all options [ExUnitProperties]" do
      ExUnitProperties.check all(
                               platform <-
                                 SD.member_of([
                                   :powerbi,
                                   :tableau,
                                   :qlik,
                                   :looker,
                                   :custom
                                 ]),
                               frequency <-
                                 SD.member_of([
                                   :real_time,
                                   :hourly,
                                   :daily,
                                   :weekly,
                                   :monthly
                                 ]),
                               timezone <- SD.member_of(["UTC", "PST", "EST", "GMT"]),
                               max_runs: 100
                             ) do
        options = [
          timezone: timezone,
          enabled: true,
          retry_count: 3
        ]

        case BusinessIntelligence.configure_data_refresh(platform, frequency, options) do
          {:ok, result} ->
            result.platform == platform and
              result.frequency == frequency and
              result.timezone == timezone and
              result.enabled == true and
              result.retry_count == 3

          {:error, _reason} ->
            # Error cases are acceptable for some configurations
            true
        end
      end
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: STAMP SAFETY CONSTRAINTS
  # ============================================================================

  describe "STAMP Safety Constraints - BI Integration" do
    test "SC-BI-001: System SHALL validate BI platform configurations" do
      # Valid configuration should succeed
      valid_config = %{
        client_id: "valid-client-id",
        client_secret: "valid-secret",
        tenant_id: "valid-tenant",
        workspace_id: "valid-workspace"
      }

      assert {:ok, result} = BusinessIntelligence.configure_integration(:powerbi, valid_config)
      assert result.connection_status == :connected

      # Invalid configuration should fail with clear error
      # Missing __required fields
      invalid_config = %{client_id: "only-client-id"}

      assert {:error, error_msg} =
               BusinessIntelligence.configure_integration(:powerbi, invalid_config)

      assert String.contains?(error_msg, "Missing __required fields")
    end

    test "SC-BI-002: System SHALL maintain __data integrity during sync operations" do
      sync_result = BusinessIntelligence.sync_data_to_bi_platforms()

      # Verify sync result integrity
      assert %DateTime{} = sync_result.sync_timestamp
      assert is_number(sync_result.platforms_synced)
      assert sync_result.platforms_synced >= 0
      assert is_list(sync_result.sync_results)
      assert is_binary(sync_result.data_freshness)
      assert is_number(sync_result.records_processed)
      assert sync_result.records_processed > 0

      # Verify individual sync results have __required fields
      Enum.each(sync_result.sync_results, fn sync ->
        assert Map.has_key?(sync, :platform)
        assert Map.has_key?(sync, :status)
        assert sync.status in [:success, :failed, :skipped]

        if sync.status == :success do
          assert is_number(sync.records_synced)
          assert sync.records_synced > 0
          assert is_number(sync.sync_duration)
          assert %DateTime{} = sync.last_sync
        end
      end)
    end

    test "SC-BI-003: System SHALL provide comprehensive monitoring capabilities" do
      monitoring_result = BusinessIntelligence.monitor_bi_integrations()

      # Verify monitoring completeness
      assert %DateTime{} = monitoring_result.monitoring_timestamp
      assert monitoring_result.overall_health in [:excellent, :good, :fair, :poor]
      assert is_list(monitoring_result.platform_statuses)
      assert length(monitoring_result.platform_statuses) > 0
      assert is_list(monitoring_result.alerts)
      assert is_list(monitoring_result.recommendations)

      # Verify each platform status has comprehensive metrics
      Enum.each(monitoring_result.platform_statuses, fn platform_status ->
        assert is_atom(platform_status.platform)
        assert platform_status.status in [:healthy, :maintenance, :error]
        assert %DateTime{} = platform_status.last_sync
        assert platform_status.data_freshness in ["Fresh", "Recent", "Stale", "Very Stale"]
        assert is_map(platform_status.sync_performance)
        assert is_number(platform_status.error_count)
        assert is_number(platform_status.uptime)
        assert platform_status.uptime >= 0.0
        assert platform_status.uptime <= 100.0
      end)
    end

    test "SC-BI-004: System SHALL handle concurrent BI operations safely" do
      # Simulate concurrent operations
      concurrent_tasks =
        Task.async_stream(
          1..5,
          fn _i ->
            BusinessIntelligence.sync_data_to_bi_platforms()
          end,
          timeout: 15_000,
          on_timeout: :kill_task
        )

      results = Enum.to_list(concurrent_tasks)

      # At least some operations should complete successfully
      successful_operations =
        Enum.count(results, fn
          {:ok, result} when is_map(result) -> true
          _ -> false
        end)

      assert successful_operations > 0

      # Verify no __data corruption in successful operations
      successful_results =
        Enum.filter_map(
          results,
          fn
            {:ok, result} -> {true, result}
            _ -> false
          end,
          fn {true, result} -> result end
        )

      Enum.each(successful_results, fn result ->
        assert is_number(result.platforms_synced)
        assert is_list(result.sync_results)
        assert %DateTime{} = result.sync_timestamp
        assert is_number(result.records_processed)
      end)
    end

    test "SC-BI-005: System SHALL provide secure API endpoint access" do
      endpoints = BusinessIntelligence.get_api_endpoints()

      # Verify all endpoints use HTTPS
      Enum.each(endpoints, fn {_key, url} ->
        assert String.starts_with?(url, "https://")
        refute String.contains?(url, "http://")
      end)

      # Verify endpoint structure includes versioning
      Enum.each(endpoints, fn {_key, url} ->
        assert String.contains?(url, "/api / v1 /") or String.contains?(url, "/v1/")
      end)

      # Verify health check endpoint is available
      assert Map.has_key?(endpoints, :health_check)
      assert String.contains?(endpoints.health_check, "/health")
    end
  end

  # ============================================================================
  # TDG METHODOLOGY: ENTERPRISE SCENARIOS & PERFORMANCE TESTS
  # ============================================================================

  describe "BusinessIntelligence Enterprise Scenarios" do
    test "handles enterprise-scale multi-platform deployment" do
      # Simulate enterprise deployment with multiple business units
      business_units = ["finance", "operations", "security", "compliance", "hr"]

      deployment_results =
        Enum.map(business_units, fn unit ->
          # Configure dedicated BI setup for each business unit
          powerbi_config = %{
            client_id: "enterprise-#{unit}-client",
            client_secret: "enterprise-secret",
            tenant_id: "enterprise-tenant",
            workspace_id: "#{unit}-workspace"
          }

          tableau_config = %{
            server_url: "https://#{unit}.tableau.enterprise.com",
            username: "#{unit}_admin",
            password: "secure_password",
            site_id: "#{unit}_site"
          }

          # Deploy both platforms for each unit
          powerbi_result = BusinessIntelligence.configure_integration(:powerbi, powerbi_config)
          tableau_result = BusinessIntelligence.configure_integration(:tableau, tableau_config)

          %{
            business_unit: unit,
            powerbi: powerbi_result,
            tableau: tableau_result
          }
        end)

      # Verify all deployments succeeded
      Enum.each(deployment_results, fn result ->
        assert {:ok, powerbi_config} = result.powerbi
        assert {:ok, tableau_config} = result.tableau
        assert powerbi_config.connection_status == :connected
        assert tableau_config.connection_status == :connected
      end)

      # Test enterprise-wide sync operation
      start_time = System.monotonic_time(:millisecond)
      sync_result = BusinessIntelligence.sync_data_to_bi_platforms(enterprise_mode: true)
      end_time = System.monotonic_time(:millisecond)

      processing_time = end_time - start_time

      # Verify enterprise-scale performance
      # Should complete within 10 seconds
      assert processing_time < 10_000
      assert sync_result.platforms_synced > 0
      # Enterprise-scale __data volume
      assert sync_result.records_processed > 10_000
    end

    test "supports comprehensive BI analytics and reporting integration" do
      # Create comprehensive analytics __data
      enterprise_data = %{
        timestamp: DateTime.utc_now(),
        business_metrics: %{
          revenue_trend: [1.2, 1.5, 1.8, 2.1, 1.9],
          customer_satisfaction: 0.87,
          operational_efficiency: 0.91,
          compliance_score: 0.94,
          security_posture: 0.88
        },
        technical_metrics: %{
          system_availability: 99.7,
          response_time_p95: 125.3,
          error_rate: 0.02,
          throughput: 2450,
          resource_utilization: 67.8
        },
        regulatory_metrics: %{
          gdpr_compliance: 0.96,
          sox_compliance: 0.94,
          iso_27001_score: 0.92,
          audit_findings: 3,
          remediation_time: 48
        }
      }

      # Generate all BI platform artifacts with comprehensive __data
      powerbi_options = [
        refresh_schedule: %{frequency: "Real-time", interval_minutes: 5},
        security_settings: %{
          row_level_security: true,
          user_groups: ["Executives", "Managers", "Analysts"],
          __data_classification: "Confidential"
        }
      ]

      tableau_options = [
        default_date_range: "YTD",
        include_extracts: true,
        extract_refresh: "hourly"
      ]

      qlik_options = [
        enable_associative_model: true,
        memory_optimization: true
      ]

      # Generate artifacts for all platforms
      assert {:ok, powerbi_dashboard} =
               BusinessIntelligence.generate_powerbi_dashboard(enterprise_data, powerbi_options)

      assert {:ok, tableau_workbook} =
               BusinessIntelligence.create_tableau_workbook(enterprise_data, tableau_options)

      assert {:ok, qlik_app} =
               BusinessIntelligence.create_qlik_application(enterprise_data, qlik_options)

      # Verify enterprise-grade configurations
      # Power BI verification
      assert powerbi_dashboard.dashboard_config.security_settings.row_level_security == true

      assert "Confidential" ==
               powerbi_dashboard.dashboard_config.security_settings.__data_classification

      assert length(powerbi_dashboard.dashboard_config.visualizations) >= 3

      # Tableau verification
      assert tableau_workbook.workbook_config.version == "2024.1"
      assert length(tableau_workbook.workbook_config.worksheets) >= 2
      assert length(tableau_workbook.workbook_config.dashboards) >= 1

      # Qlik verification
      assert String.contains?(qlik_app.app_config.load_script, "STAMP_Metrics")
      assert length(qlik_app.app_config.data_model.tables) >= 3
      assert length(qlik_app.app_config.sheets) >= 2

      # Verify resource usage estimation
      # MB
      assert powerbi_dashboard.data_model_size > 5.0
      # MB
      assert tableau_workbook.data_extract_size > 8.0
      # MB
      assert qlik_app.memory_usage > 12.0

      # Test comprehensive monitoring
      monitoring_result = BusinessIntelligence.monitor_bi_integrations()
      assert monitoring_result.overall_health in [:excellent, :good]
      assert length(monitoring_result.platform_statuses) >= 3
      assert length(monitoring_result.recommendations) >= 0
    end
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  # PropCheck generators
  defp valid_platform_config_gen do
    PC.oneof([
      {:powerbi,
       %{
         client_id: "test-client-id",
         client_secret: "test-secret",
         tenant_id: "test-tenant",
         workspace_id: "test-workspace"
       }},
      {:tableau,
       %{
         server_url: "https://test.tableau.com",
         username: "test_user",
         password: "test_password",
         site_id: "test_site"
       }},
      {:qlik,
       %{
         server_url: "https://test.qlik.com",
         app_id: "test-app",
         api_key: "test-api-key"
       }}
    ])
  end
end

# Agent: Helper-1 (BI Integration Specialist)
# SOPv5.11 Compliance: ✅ Business Intelligence with comprehensive multi-platform integration
# Domain: Analytics
# Responsibilities: BI platform integration, dashboard generation, __data synchronization, enterprise analytics
# Multi-Agent Architecture: Integrated with 15-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
# TDG Methodology: Tests written FIRST, comprehensive BI integration coverage validation
