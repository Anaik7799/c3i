defmodule Indrajaal.Analytics.ExecutiveDashboardEnginePropertyTest do
  @moduledoc """
  Property-based testing for Executive Dashboard Engine module using dual testing frameworks.

  This module validates executive dashboard generation, KPI aggregation, strategic metrics
  calculation, and executive reporting functionality using Test-Driven Generation (TDG)
  methodology with comprehensive STAMP safety constraints.

  Testing Framework: Dual PropCheck + ExUnitProperties
  STAMP Constraints: SC-EDE-001 through SC-EDE-005
  Coverage: Core functions, integration, end-to-end workflows

  Key Functions Tested:
  - generate_executive_dashboard/3: Comprehensive C-level dashboard generation
  - calculate_strategic_kpis/4: Strategic key performance indicators calculation
  - create_board_report/3: Board of directors reporting with fiduciary requirements
  - aggregate_business_metrics/3: Multi-dimensional business intelligence aggregation
  - generate_forecast_analysis/2: Predictive analytics for executive decision-making
  """

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

  alias Indrajaal.Analytics.ExecutiveDashboardEngine

  # Test data generators for comprehensive property testing
  @dashboard_types [:ceo, :cfo, :coo, :cto, :board_of_directors, :strategic_planning]
  @kpi_categories [:financial, :operational, :strategic, :compliance, :risk_management, :growth]
  @report_periods [:monthly, :quarterly, :annually, :ytd, :rolling_12_months]
  @metric_aggregation_methods [:sum, :average, :weighted_average, :median, :percentile_90]
  @forecast_horizons [:"1_month", :"3_months", :"6_months", :"12_months", :"24_months"]

  # ==========================================
  # CORE FUNCTION TESTING: generate_executive_dashboard/3
  # ==========================================

  describe "generate_executive_dashboard/3 - C-level executive dashboard generation" do
    # PropCheck property test - Advanced shrinking capabilities
    test "propcheck: executive dashboard generation maintains strategic consistency" do
      assert PropCheck.quickcheck(
               forall {tenant_id, dashboard_config, executive_role} <- {
                        tenant_id_generator(),
                        dashboard_config_generator(),
                        PC.oneof(@dashboard_types)
                      } do
                 result =
                   ExecutiveDashboardEngine.generate_executive_dashboard(
                     tenant_id,
                     dashboard_config,
                     executive_role
                   )

                 # Core dashboard properties
                 result.executive_role == executive_role and
                   is_list(result.strategic_kpis) and
                   is_map(result.financial_summary) and
                   is_map(result.operational_metrics) and
                   Map.has_key?(result, :risk_indicators) and
                   Map.has_key?(result, :performance_trends) and
                   Map.has_key?(result, :generated_at) and
                   Map.has_key?(result, :data_freshness)
               end
             )
    end

    # ExUnitProperties test - StreamData integration
    test "exunitproperties: executive dashboard handles role-specific requirements" do
      ExUnitProperties.check all(
                               tenant_id <- tenant_id_generator(),
                               dashboard_config <- dashboard_config_generator(),
                               executive_role <- SD.member_of(@dashboard_types),
                               max_runs: 100
                             ) do
        result =
          ExecutiveDashboardEngine.generate_executive_dashboard(
            tenant_id,
            dashboard_config,
            executive_role
          )

        # Role-specific validation
        assert result.executive_role == executive_role
        assert Map.has_key?(result, :role_specific_metrics)
        assert length(result.strategic_kpis) > 0
        assert Map.has_key?(result, :actionable_insights)
        assert Map.has_key?(result, :executive_summary)
      end
    end

    # Integration test with multi-tenant isolation
    test "generate_executive_dashboard respects tenant isolation and data boundaries" do
      tenant_alpha = "executive_tenant_alpha"
      tenant_beta = "executive_tenant_beta"

      dashboard_config = %{
        time_period: :quarterly,
        include_forecasts: true,
        detail_level: :executive_summary,
        kpi_categories: [:financial, :operational, :strategic]
      }

      # Generate dashboards for different tenants
      dashboard_alpha =
        ExecutiveDashboardEngine.generate_executive_dashboard(
          tenant_alpha,
          dashboard_config,
          :ceo
        )

      dashboard_beta =
        ExecutiveDashboardEngine.generate_executive_dashboard(tenant_beta, dashboard_config, :ceo)

      # Tenant isolation verification
      assert dashboard_alpha.tenant_id == tenant_alpha
      assert dashboard_beta.tenant_id == tenant_beta
      assert dashboard_alpha.tenant_id != dashboard_beta.tenant_id

      # Data boundaries verification
      refute dashboard_alpha.financial_summary == dashboard_beta.financial_summary
      assert Map.has_key?(dashboard_alpha, :tenant_security_context)
      assert Map.has_key?(dashboard_beta, :tenant_security_context)
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: calculate_strategic_kpis/4
  # ==========================================

  describe "calculate_strategic_kpis/4 - Strategic key performance indicators calculation" do
    # PropCheck property test
    test "propcheck: strategic KPI calculation maintains business logic consistency" do
      assert PropCheck.quickcheck(
               forall {tenant_id, kpi_definitions, data_sources, calculation_period} <- {
                        tenant_id_generator(),
                        kpi_definitions_generator(),
                        data_sources_generator(),
                        report_period_generator()
                      } do
                 result =
                   ExecutiveDashboardEngine.calculate_strategic_kpis(
                     tenant_id,
                     kpi_definitions,
                     data_sources,
                     calculation_period
                   )

                 # Strategic KPI properties
                 is_list(result.kpis) and
                   length(result.kpis) > 0 and
                   result.calculation_period == calculation_period and
                   Map.has_key?(result, :benchmark_comparisons) and
                   Map.has_key?(result, :trend_analysis) and
                   Map.has_key?(result, :target_achievement) and
                   Map.has_key?(result, :calculation_metadata)
               end
             )
    end

    # ExUnitProperties test
    test "exunitproperties: strategic KPI calculation handles complex aggregations" do
      ExUnitProperties.check all(
                               tenant_id <- tenant_id_generator(),
                               kpi_definitions <- kpi_definitions_generator(),
                               data_sources <- data_sources_generator(),
                               calculation_period <- report_period_generator(),
                               max_runs: 100
                             ) do
        result =
          ExecutiveDashboardEngine.calculate_strategic_kpis(
            tenant_id,
            kpi_definitions,
            data_sources,
            calculation_period
          )

        # KPI calculation validation
        assert is_list(result.kpis)
        assert length(result.kpis) > 0
        assert Map.has_key?(result, :aggregation_summary)
        assert result.tenant_id == tenant_id

        # Validate each KPI structure
        Enum.each(result.kpis, fn kpi ->
          assert Map.has_key?(kpi, :name)
          assert Map.has_key?(kpi, :value)
          assert Map.has_key?(kpi, :target)
          assert Map.has_key?(kpi, :variance)
        end)
      end
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: create_board_report/3
  # ==========================================

  describe "create_board_report/3 - Board of directors reporting with fiduciary requirements" do
    # PropCheck property test
    test "propcheck: board report creation maintains fiduciary compliance" do
      assert PropCheck.quickcheck(
               forall {tenant_id, board_report_config, reporting_period} <- {
                        tenant_id_generator(),
                        board_report_config_generator(),
                        report_period_generator()
                      } do
                 result =
                   ExecutiveDashboardEngine.create_board_report(
                     tenant_id,
                     board_report_config,
                     reporting_period
                   )

                 # Fiduciary compliance properties
                 result.reporting_period == reporting_period and
                   Map.has_key?(result, :fiduciary_compliance) and
                   Map.has_key?(result, :governance_metrics) and
                   Map.has_key?(result, :risk_disclosures) and
                   Map.has_key?(result, :regulatory_compliance) and
                   Map.has_key?(result, :executive_compensation) and
                   Map.has_key?(result, :audit_trail)
               end
             )
    end

    # ExUnitProperties test
    test "exunitproperties: board report creation handles comprehensive governance requirements" do
      ExUnitProperties.check all(
                               tenant_id <- tenant_id_generator(),
                               board_report_config <- board_report_config_generator(),
                               reporting_period <- report_period_generator(),
                               max_runs: 100
                             ) do
        result =
          ExecutiveDashboardEngine.create_board_report(
            tenant_id,
            board_report_config,
            reporting_period
          )

        # Board report validation
        assert Map.has_key?(result, :financial_performance)
        assert Map.has_key?(result, :strategic_initiatives)
        assert Map.has_key?(result, :risk_management)
        assert Map.has_key?(result, :compliance_status)
        assert result.tenant_id == tenant_id
        assert result.reporting_period == reporting_period

        # Governance requirements
        assert Map.has_key?(result.governance_metrics, :board_effectiveness)
        assert Map.has_key?(result.governance_metrics, :director_independence)
        assert Map.has_key?(result.governance_metrics, :committee_performance)
      end
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: aggregate_business_metrics/3
  # ==========================================

  describe "aggregate_business_metrics/3 - Multi-dimensional business intelligence aggregation" do
    # PropCheck property test
    test "propcheck: business metrics aggregation maintains dimensional consistency" do
      assert PropCheck.quickcheck(
               forall {metric_definitions, aggregation_rules, time_dimensions} <- {
                        business_metrics_generator(),
                        aggregation_rules_generator(),
                        time_dimensions_generator()
                      } do
                 result =
                   ExecutiveDashboardEngine.aggregate_business_metrics(
                     metric_definitions,
                     aggregation_rules,
                     time_dimensions
                   )

                 # Aggregation consistency properties
                 is_map(result.aggregated_metrics) and
                   Map.has_key?(result, :dimension_breakdowns) and
                   Map.has_key?(result, :aggregation_summary) and
                   result.time_dimensions == time_dimensions and
                   Map.has_key?(result, :data_quality_metrics)
               end
             )
    end

    # ExUnitProperties test
    test "exunitproperties: business metrics aggregation handles large datasets efficiently" do
      ExUnitProperties.check all(
                               metric_definitions <- business_metrics_generator(),
                               aggregation_rules <- aggregation_rules_generator(),
                               time_dimensions <- time_dimensions_generator(),
                               max_runs: 100
                             ) do
        result =
          ExecutiveDashboardEngine.aggregate_business_metrics(
            metric_definitions,
            aggregation_rules,
            time_dimensions
          )

        # Aggregation efficiency validation
        assert is_map(result.aggregated_metrics)
        assert Map.has_key?(result, :performance_statistics)
        # Should complete within 10 seconds
        assert result.performance_statistics.processing_time_ms < 10_000

        # Data quality validation
        assert result.data_quality_metrics.completeness_score >= 0.8
        assert result.data_quality_metrics.accuracy_score >= 0.9
      end
    end
  end

  # ==========================================
  # INTEGRATION TESTING
  # ==========================================

  describe "Integration Testing - End-to-end executive dashboard workflows" do
    test "complete executive dashboard generation with strategic analysis" do
      tenant_id = "executive_analytics_tenant"

      # Step 1: Define comprehensive dashboard configuration
      dashboard_config = %{
        time_period: :quarterly,
        include_forecasts: true,
        detail_level: :comprehensive,
        kpi_categories: [:financial, :operational, :strategic, :risk_management],
        benchmark_comparisons: true,
        trend_analysis_months: 12
      }

      # Step 2: Generate CEO dashboard
      ceo_dashboard =
        ExecutiveDashboardEngine.generate_executive_dashboard(tenant_id, dashboard_config, :ceo)

      assert ceo_dashboard.executive_role == :ceo
      assert Map.has_key?(ceo_dashboard, :strategic_initiatives)
      assert Map.has_key?(ceo_dashboard, :competitive_analysis)

      # Step 3: Calculate strategic KPIs
      kpi_definitions = [
        %{name: "Revenue Growth Rate", category: :financial, target: 15.0, weight: 0.3},
        %{name: "Customer Acquisition Cost", category: :operational, target: 250.0, weight: 0.2},
        %{name: "Market Share Growth", category: :strategic, target: 5.0, weight: 0.25},
        %{
          name: "Regulatory Compliance Score",
          category: :risk_management,
          target: 95.0,
          weight: 0.25
        }
      ]

      data_sources = %{
        financial: ["revenue_tracking", "cost_analysis"],
        operational: ["customer_analytics", "sales_funnel"],
        strategic: ["market_research", "competitive_intelligence"],
        risk_management: ["compliance_monitoring", "risk_assessment"]
      }

      strategic_kpis =
        ExecutiveDashboardEngine.calculate_strategic_kpis(
          tenant_id,
          kpi_definitions,
          data_sources,
          :quarterly
        )

      assert length(strategic_kpis.kpis) == 4
      assert Map.has_key?(strategic_kpis, :weighted_performance_score)

      # Step 4: Create board report
      board_config = %{
        include_financials: true,
        include_governance: true,
        include_risk_management: true,
        include_strategic_initiatives: true,
        detail_level: :board_appropriate,
        fiduciary_requirements: [:sox_compliance, :audit_committee_oversight]
      }

      board_report =
        ExecutiveDashboardEngine.create_board_report(tenant_id, board_config, :quarterly)

      assert Map.has_key?(board_report, :executive_summary)
      assert Map.has_key?(board_report, :financial_highlights)
      assert Map.has_key?(board_report, :strategic_progress)

      # Step 5: Aggregate comprehensive business metrics
      metric_definitions = %{
        revenue_metrics: %{
          aggregation_method: :sum,
          dimensions: [:time, :geography, :product_line]
        },
        customer_metrics: %{aggregation_method: :average, dimensions: [:time, :segment, :channel]},
        operational_metrics: %{
          aggregation_method: :weighted_average,
          dimensions: [:time, :department, :efficiency_type]
        }
      }

      aggregation_rules = %{
        time_grain: :monthly,
        geographic_rollup: :country_to_region,
        product_rollup: :sku_to_category,
        missing_data_handling: :interpolation
      }

      time_dimensions = %{
        start_date: ~D[2024-01-01],
        end_date: ~D[2024-12-31],
        granularity: :monthly
      }

      aggregated_metrics =
        ExecutiveDashboardEngine.aggregate_business_metrics(
          metric_definitions,
          aggregation_rules,
          time_dimensions
        )

      assert Map.has_key?(aggregated_metrics, :revenue_metrics)
      assert Map.has_key?(aggregated_metrics, :customer_metrics)
      assert Map.has_key?(aggregated_metrics, :operational_metrics)

      # Integration validation
      assert ceo_dashboard.tenant_id == tenant_id
      assert strategic_kpis.tenant_id == tenant_id
      assert board_report.tenant_id == tenant_id

      # Cross-component consistency
      assert ceo_dashboard.financial_summary.revenue_growth in strategic_kpis.kpis

      assert board_report.financial_highlights.revenue_performance ==
               aggregated_metrics.aggregated_metrics.revenue_metrics.total_revenue
    end
  end

  # ==========================================
  # STAMP SAFETY CONSTRAINTS (SC-EDE-001 through SC-EDE-005)
  # ==========================================

  describe "STAMP Safety Constraints - Executive Dashboard Engine Safety" do
    test "SC-EDE-001: System SHALL ensure executive dashboard data accuracy and real-time freshness" do
      # Test data accuracy and freshness across multiple dashboard generations
      tenant_id = "accuracy_test_tenant"

      dashboard_config = %{
        time_period: :monthly,
        include_forecasts: false,
        detail_level: :detailed,
        # 5 minutes max staleness
        data_freshness_requirement: 300
      }

      # Generate dashboard and validate data freshness
      ceo_dashboard =
        ExecutiveDashboardEngine.generate_executive_dashboard(tenant_id, dashboard_config, :ceo)

      # Data freshness validation
      data_age_seconds =
        DateTime.diff(DateTime.utc_now(), ceo_dashboard.data_freshness.last_updated, :second)

      assert data_age_seconds <= dashboard_config.data_freshness_requirement

      # Data accuracy validation
      # 98% accuracy minimum
      assert ceo_dashboard.data_quality.accuracy_score >= 0.98
      assert Map.has_key?(ceo_dashboard.data_quality, :validation_checksum)
      assert Map.has_key?(ceo_dashboard.data_quality, :source_verification)

      # Real-time freshness indicators
      assert Map.has_key?(ceo_dashboard, :refresh_indicators)
      assert ceo_dashboard.refresh_indicators.auto_refresh_enabled == true
      assert ceo_dashboard.refresh_indicators.refresh_interval_seconds <= 300
    end

    test "SC-EDE-002: System SHALL maintain executive privilege security and access control compliance" do
      # Test executive-level security and access controls
      tenant_id = "security_test_tenant"

      # Test different executive role access levels
      roles_and_clearance = [
        {:ceo, :level_1_top_secret},
        {:cfo, :level_2_confidential},
        {:coo, :level_2_confidential},
        {:board_of_directors, :level_1_top_secret}
      ]

      Enum.each(roles_and_clearance, fn {role, expected_clearance} ->
        dashboard_config = %{
          security_classification: expected_clearance,
          access_logging: true,
          data_masking_level: :executive_appropriate
        }

        dashboard =
          ExecutiveDashboardEngine.generate_executive_dashboard(tenant_id, dashboard_config, role)

        # Security clearance validation
        assert dashboard.security_context.clearance_level == expected_clearance
        assert dashboard.security_context.role_authorized == role

        # Access logging validation
        assert Map.has_key?(dashboard, :access_log)
        assert dashboard.access_log.user_role == role
        assert Map.has_key?(dashboard.access_log, :access_timestamp)
        assert Map.has_key?(dashboard.access_log, :data_classification)

        # Data sensitivity handling
        case expected_clearance do
          :level_1_top_secret ->
            assert Map.has_key?(dashboard, :sensitive_financials)
            assert Map.has_key?(dashboard, :strategic_initiatives_detailed)

          :level_2_confidential ->
            assert Map.get(dashboard, :sensitive_financials) == :redacted
            assert Map.has_key?(dashboard, :strategic_initiatives_summary)
        end
      end)
    end

    test "SC-EDE-003: System SHALL provide audit trail compliance for all executive dashboard activities" do
      # Test comprehensive audit trail for executive activities
      tenant_id = "audit_compliance_tenant"

      dashboard_config = %{
        audit_level: :comprehensive,
        compliance_requirements: [:sox_404, :gdpr, :audit_committee_oversight]
      }

      # Generate dashboard with audit tracking
      board_dashboard =
        ExecutiveDashboardEngine.generate_executive_dashboard(
          tenant_id,
          dashboard_config,
          :board_of_directors
        )

      # Audit trail completeness validation
      audit_trail = board_dashboard.audit_trail

      assert Map.has_key?(audit_trail, :data_access_log)
      assert Map.has_key?(audit_trail, :calculation_audit)
      assert Map.has_key?(audit_trail, :security_events)
      assert Map.has_key?(audit_trail, :compliance_checkpoints)

      # SOX 404 compliance validation
      sox_compliance = audit_trail.compliance_checkpoints.sox_404
      assert Map.has_key?(sox_compliance, :internal_controls_validated)
      assert Map.has_key?(sox_compliance, :data_integrity_verified)
      assert Map.has_key?(sox_compliance, :access_controls_audited)

      # GDPR compliance validation
      gdpr_compliance = audit_trail.compliance_checkpoints.gdpr
      assert Map.has_key?(gdpr_compliance, :data_processing_documented)
      assert Map.has_key?(gdpr_compliance, :consent_verification)
      assert Map.has_key?(gdpr_compliance, :data_retention_compliance)

      # Audit committee oversight
      audit_committee = audit_trail.compliance_checkpoints.audit_committee_oversight
      assert Map.has_key?(audit_committee, :board_notification_sent)
      assert Map.has_key?(audit_committee, :material_changes_flagged)
      assert audit_committee.audit_committee_review_required in [true, false]

      # Immutable audit trail
      assert Map.has_key?(audit_trail, :trail_hash)
      assert Map.has_key?(audit_trail, :digital_signature)
      assert Map.has_key?(audit_trail, :timestamp_authority)
    end

    test "SC-EDE-004: System SHALL ensure executive dashboard performance meets C-level expectations" do
      # Test performance requirements for executive dashboards
      tenant_id = "performance_test_tenant"

      # Test large enterprise dataset performance
      large_dashboard_config = %{
        time_period: :annually,
        include_forecasts: true,
        detail_level: :comprehensive,
        # Millions of records
        data_volume: :enterprise_scale,
        kpi_categories: [
          :financial,
          :operational,
          :strategic,
          :compliance,
          :risk_management,
          :growth
        ],
        geographic_scope: :global,
        business_units: :all_subsidiaries
      }

      # Measure dashboard generation performance
      start_time = System.monotonic_time(:millisecond)

      ceo_dashboard =
        ExecutiveDashboardEngine.generate_executive_dashboard(
          tenant_id,
          large_dashboard_config,
          :ceo
        )

      generation_time = System.monotonic_time(:millisecond) - start_time

      # Performance expectations for C-level
      # Must complete within 5 seconds
      assert generation_time <= 5000
      # Query execution under 3 seconds
      assert ceo_dashboard.performance_metrics.query_time_ms <= 3000
      # Processing under 2 seconds
      assert ceo_dashboard.performance_metrics.data_processing_time_ms <= 2000

      # Memory efficiency validation
      # Under 512MB memory usage
      assert ceo_dashboard.performance_metrics.memory_usage_mb <= 512
      # 80%+ cache hit rate
      assert ceo_dashboard.performance_metrics.cache_hit_rate >= 0.8

      # Dashboard responsiveness
      assert Map.has_key?(ceo_dashboard, :interactive_elements)
      # Sub-second drill-down
      assert ceo_dashboard.interactive_elements.drill_down_response_time_ms <= 500
      # Quick chart rendering
      assert ceo_dashboard.interactive_elements.chart_rendering_time_ms <= 200

      # Scalability indicators
      assert ceo_dashboard.scalability_metrics.concurrent_user_capacity >= 100
      assert ceo_dashboard.scalability_metrics.data_throughput_mbps >= 10
    end

    test "SC-EDE-005: System SHALL maintain strategic KPI consistency and benchmark accuracy across time periods" do
      # Test strategic consistency across multiple time periods and benchmarks
      tenant_id = "consistency_test_tenant"

      # Define consistent KPIs across different periods
      kpi_definitions = [
        %{
          name: "Return on Assets",
          category: :financial,
          formula: "net_income / total_assets",
          benchmark: :industry_average
        },
        %{
          name: "Employee Productivity",
          category: :operational,
          formula: "revenue / employee_count",
          benchmark: :best_in_class
        },
        %{
          name: "Market Penetration Rate",
          category: :strategic,
          formula: "customers / total_addressable_market",
          benchmark: :competitor_median
        }
      ]

      data_sources = %{
        financial: ["balance_sheet", "income_statement", "cash_flow"],
        operational: ["hr_metrics", "productivity_tracking"],
        strategic: ["market_intelligence", "customer_analytics"]
      }

      # Calculate KPIs for different periods
      periods = [:monthly, :quarterly, :annually]

      period_results =
        Enum.map(periods, fn period ->
          ExecutiveDashboardEngine.calculate_strategic_kpis(
            tenant_id,
            kpi_definitions,
            data_sources,
            period
          )
        end)

      # Strategic consistency validation across periods
      [monthly, quarterly, annually] = period_results

      # ROA consistency: annual should be average of quarterly, quarterly should align with monthly trends
      monthly_roa = get_kpi_by_name(monthly.kpis, "Return on Assets")
      quarterly_roa = get_kpi_by_name(quarterly.kpis, "Return on Assets")
      annual_roa = get_kpi_by_name(annually.kpis, "Return on Assets")

      # Validate mathematical consistency (within tolerance for seasonal variations)
      # 10% tolerance
      assert abs(quarterly_roa.value - monthly_roa.value * 3) <= quarterly_roa.value * 0.1
      # 15% tolerance for annual
      assert abs(annual_roa.value - quarterly_roa.value * 4) <= annual_roa.value * 0.15

      # Benchmark accuracy validation
      Enum.each(period_results, fn result ->
        Enum.each(result.kpis, fn kpi ->
          assert Map.has_key?(kpi, :benchmark_comparison)
          benchmark = kpi.benchmark_comparison

          assert Map.has_key?(benchmark, :benchmark_value)
          assert Map.has_key?(benchmark, :performance_vs_benchmark)
          assert Map.has_key?(benchmark, :percentile_ranking)
          assert Map.has_key?(benchmark, :benchmark_source)
          assert Map.has_key?(benchmark, :last_updated)

          # Benchmark data freshness (should be updated at least quarterly)
          benchmark_age_days = Date.diff(Date.utc_today(), benchmark.last_updated)
          # Benchmark data not older than 90 days
          assert benchmark_age_days <= 90
        end)
      end)

      # Cross-period trend analysis consistency
      Enum.each(period_results, fn result ->
        assert Map.has_key?(result, :trend_analysis)
        trend = result.trend_analysis

        # :improving, :declining, :stable
        assert Map.has_key?(trend, :trend_direction)
        # :strong, :moderate, :weak
        assert Map.has_key?(trend, :trend_strength)
        # Statistical confidence level
        assert Map.has_key?(trend, :trend_confidence)
        # 80% confidence minimum
        assert trend.trend_confidence >= 0.8
      end)
    end
  end

  # ==========================================
  # HELPER FUNCTIONS FOR TEST DATA GENERATION
  # ==========================================

  defp tenant_id_generator do
    PC.oneof([
      "enterprise_corp_001",
      "fortune_500_company_002",
      "multinational_org_003",
      "public_company_004",
      "private_equity_portfolio_005"
    ])
  end

  defp dashboard_config_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      time_period: PC.oneof(@report_periods),
      include_forecasts: PC.boolean(),
      detail_level: PC.oneof([:summary, :detailed, :comprehensive, :executive_summary]),
      kpi_categories: PC.list(PC.oneof(@kpi_categories)),
      benchmark_comparisons: PC.boolean(),
      trend_analysis_months: PC.integer(3, 24),
      geographic_scope: PC.oneof([:local, :regional, :national, :global]),
      business_units: PC.oneof([:primary, :all_subsidiaries, :selected_divisions])
    })
  end

  defp kpi_definitions_generator do
    PC.list(
      Indrajaal.PropCheckHelpers.fixed_map(%{
        name: PC.utf8(),
        category: PC.oneof(@kpi_categories),
        target: PC.float(0.0, 1000.0),
        weight: PC.float(0.1, 1.0),
        formula: PC.utf8(),
        benchmark_type:
          PC.oneof([
            :industry_average,
            :best_in_class,
            :competitor_median,
            :historical_performance
          ])
      })
    )
  end

  defp data_sources_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      financial: PC.list(PC.utf8()),
      operational: PC.list(PC.utf8()),
      strategic: PC.list(PC.utf8()),
      compliance: PC.list(PC.utf8()),
      risk_management: PC.list(PC.utf8())
    })
  end

  defp report_period_generator do
    PC.oneof(@report_periods)
  end

  defp board_report_config_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      include_financials: PC.boolean(),
      include_governance: PC.boolean(),
      include_risk_management: PC.boolean(),
      include_strategic_initiatives: PC.boolean(),
      detail_level: PC.oneof([:board_appropriate, :detailed, :comprehensive]),
      fiduciary_requirements:
        PC.list(
          PC.oneof([
            :sox_compliance,
            :audit_committee_oversight,
            :director_independence,
            :executive_compensation
          ])
        ),
      confidentiality_level:
        PC.oneof([:board_confidential, :executive_confidential, :management_confidential])
    })
  end

  defp business_metrics_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      revenue_metrics: metric_definition_generator(),
      customer_metrics: metric_definition_generator(),
      operational_metrics: metric_definition_generator(),
      financial_metrics: metric_definition_generator()
    })
  end

  defp metric_definition_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      aggregation_method: PC.oneof(@metric_aggregation_methods),
      dimensions:
        PC.list(
          PC.oneof([:time, :geography, :product_line, :customer_segment, :channel, :department])
        ),
      filters: PC.list(PC.utf8()),
      weights: SD.map_of(SD.atom(:alphanumeric), SD.float(min: 0.1, max: 1.0))
    })
  end

  defp aggregation_rules_generator do
    Indrajaal.PropCheckHelpers.fixed_map(%{
      time_grain: PC.oneof([:daily, :weekly, :monthly, :quarterly, :annually]),
      geographic_rollup:
        PC.oneof([:city_to_state, :state_to_country, :country_to_region, :region_to_global]),
      product_rollup: PC.oneof([:sku_to_category, :category_to_division, :division_to_company]),
      missing_data_handling: PC.oneof([:ignore, :interpolation, :zero_fill, :previous_value])
    })
  end

  defp time_dimensions_generator do
    start_date = ~D[2024-01-01]
    end_date = ~D[2024-12-31]

    Indrajaal.PropCheckHelpers.fixed_map(%{
      start_date: SD.constant(start_date),
      end_date: SD.constant(end_date),
      granularity: PC.oneof([:daily, :weekly, :monthly, :quarterly])
    })
  end

  # Helper function to extract KPI by name for validation
  defp get_kpi_by_name(kpis, name) do
    Enum.find(kpis, fn kpi -> kpi.name == name end)
  end

  defp sublist_of(list, opts \\ []) do
    min_length = Keyword.get(opts, :min_length, 0)
    max_length = Keyword.get(opts, :max_length, length(list))
    len = min_length + :rand.uniform(max(1, max_length - min_length + 1)) - 1

    list
    |> Enum.shuffle()
    |> Enum.take(len)
    |> PC.exactly()
  end
end
