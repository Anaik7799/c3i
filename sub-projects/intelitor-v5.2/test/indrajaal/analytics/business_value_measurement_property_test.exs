defmodule Indrajaal.Analytics.BusinessValueMeasurementPropertyTest do
  @moduledoc """
  Property-based tests for Indrajaal.Analytics.BusinessValueMeasurement module.

  This test suite follows TDG (Test-Driven Generation) methodology - tests are written BEFORE
  any implementation changes. Uses dual property-based testing framework combining PropCheck
  (advanced shrinking) and ExUnitProperties (StreamData integration).

  STAMP Safety Constraints (SC-BVM-XXX):
  - SC-BVM-001: Business value calculations SHALL maintain financial accuracy and auditability
  - SC-BVM-002: ROI measurements SHALL preserve temporal consistency across time periods
  - SC-BVM-003: Value attribution SHALL maintain traceability to source business activities
  - SC-BVM-004: Cost-benefit analysis SHALL scale accurately with business complexity
  - SC-BVM-005: Value metrics SHALL align with enterprise financial reporting standards
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

  alias Indrajaal.Analytics.BusinessValueMeasurement

  # Test data generators
  @value_categories [
    :cost_reduction,
    :revenue_increase,
    :risk_mitigation,
    :efficiency_improvement,
    :customer_satisfaction
  ]
  @measurement_periods [:monthly, :quarterly, :yearly, :project_lifecycle, :real_time]
  @currency_types [:usd, :eur, :gbp, :jpy, :cad, :aud]
  @business_units [:operations, :sales, :marketing, :it, :finance, :hr, :legal, :manufacturing]
  @roi_calculation_methods [:simple_roi, :irr, :npv, :payback_period, :profitability_index]

  # Financial ranges
  @cost_ranges [
    # Small projects
    {1_000, 50_000},
    # Medium projects
    {50_000, 500_000},
    # Large projects
    {500_000, 5_000_000},
    # Enterprise projects
    {5_000_000, 50_000_000}
  ]

  # Time periods (in months)
  @evaluation_periods [1, 3, 6, 12, 18, 24, 36, 48, 60]

  # Risk factors
  @risk_levels [:low, :medium, :high, :critical]
  @confidence_intervals [0.80, 0.85, 0.90, 0.95, 0.99]

  describe "calculate_roi/3 - Return on Investment calculations" do
    test "propcheck: calculate_roi/3 maintains financial accuracy with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {investment_amount, benefits, calculation_method} <- {
                        PC.float(1000.0, 10_000_000.0),
                        PC.list(PC.float(0.0, 1_000_000.0)),
                        PC.oneof(@roi_calculation_methods)
                      } do
                 time_periods = Enum.map(1..length(benefits), fn i -> i end)

                 result =
                   BusinessValueMeasurement.calculate_roi(
                     investment_amount,
                     benefits,
                     calculation_method,
                     %{
                       time_periods: time_periods,
                       discount_rate: 0.08,
                       currency: :usd
                     }
                   )

                 # Validate ROI calculation structure
                 assert is_map(result)
                 assert Map.has_key?(result, :roi_percentage)
                 assert Map.has_key?(result, :net_present_value)
                 assert Map.has_key?(result, :payback_period_months)
                 assert Map.has_key?(result, :calculation_method)
                 assert Map.has_key?(result, :financial_accuracy)

                 # Mathematical consistency validations
                 assert is_number(result.roi_percentage)
                 assert is_number(result.net_present_value)
                 assert result.calculation_method == calculation_method

                 # Financial accuracy requirements
                 assert result.financial_accuracy.precision >= 0.99
                 assert Map.has_key?(result.financial_accuracy, :rounding_applied)
                 assert Map.has_key?(result.financial_accuracy, :calculation_audit_trail)

                 # ROI should be reasonable range (-100% to 10_000%)
                 assert result.roi_percentage >= -1.0 and result.roi_percentage <= 100.0
               end
             )
    end

    test "exunitproperties: calculate_roi/3 respects different calculation methodologies" do
      ExUnitProperties.check all(
                               calculation_method <- SD.member_of(@roi_calculation_methods),
                               investment <- SD.float(min: 10_000.0, max: 1_000_000.0),
                               # 6 months to 5 years
                               benefit_count <- SD.integer(6..60),
                               max_runs: 50
                             ) do
        # Generate realistic benefit stream
        benefits =
          Enum.map(1..benefit_count, fn month ->
            # 2% monthly return base
            base_benefit = investment * 0.02
            # ±25% volatility
            volatility = (:rand.uniform() - 0.5) * 0.5
            base_benefit * (1 + volatility)
          end)

        params = %{
          time_periods: Enum.to_list(1..benefit_count),
          discount_rate: 0.08,
          risk_adjustment: 0.05,
          currency: :usd
        }

        result =
          BusinessValueMeasurement.calculate_roi(investment, benefits, calculation_method, params)

        # Method-specific validations
        case calculation_method do
          :simple_roi ->
            total_benefits = Enum.sum(benefits)
            expected_simple_roi = (total_benefits - investment) / investment * 100
            # 1% tolerance
            tolerance = abs(expected_simple_roi * 0.01)
            assert abs(result.roi_percentage - expected_simple_roi) <= tolerance

          :irr ->
            # IRR should be reasonable for the cash flows
            assert result.irr_percentage >= -50.0 and result.irr_percentage <= 200.0
            assert Map.has_key?(result, :irr_calculation_details)

          :npv ->
            # NPV should consider discount rate
            assert Map.has_key?(result, :discount_rate_applied)
            assert result.discount_rate_applied == params.discount_rate

          :payback_period ->
            # Payback period should be in reasonable range
            assert result.payback_period_months >= 0
            assert result.payback_period_months <= benefit_count

          :profitability_index ->
            # PI should be positive for profitable investments
            assert Map.has_key?(result, :profitability_index)
            pi = result.profitability_index
            assert pi >= 0.0
        end
      end
    end
  end

  describe "measure_cost_benefits/4 - Comprehensive cost-benefit analysis" do
    test "propcheck: measure_cost_benefits/4 maintains cost-benefit consistency" do
      assert PropCheck.quickcheck(
               forall {costs, benefits, business_context, analysis_params} <- {
                        PC.map(PC.atom(), PC.float(1000.0, 1_000_000.0)),
                        PC.map(PC.atom(), PC.float(0.0, 2_000_000.0)),
                        PC.map(PC.atom(), PC.any()),
                        PC.map(PC.atom(), PC.any())
                      } do
                 result =
                   BusinessValueMeasurement.measure_cost_benefits(
                     costs,
                     benefits,
                     business_context,
                     analysis_params
                   )

                 # Validate cost-benefit analysis structure
                 assert is_map(result)
                 assert Map.has_key?(result, :total_costs)
                 assert Map.has_key?(result, :total_benefits)
                 assert Map.has_key?(result, :net_benefit)
                 assert Map.has_key?(result, :benefit_cost_ratio)
                 assert Map.has_key?(result, :cost_breakdown)
                 assert Map.has_key?(result, :benefit_breakdown)

                 # Mathematical consistency
                 total_costs = costs |> Map.values() |> Enum.sum()
                 total_benefits = benefits |> Map.values() |> Enum.sum()

                 # Floating point tolerance
                 assert abs(result.total_costs - total_costs) < 0.01
                 assert abs(result.total_benefits - total_benefits) < 0.01
                 assert abs(result.net_benefit - (total_benefits - total_costs)) < 0.01

                 # Benefit-cost ratio validation
                 if result.total_costs > 0 do
                   expected_bcr = result.total_benefits / result.total_costs
                   assert abs(result.benefit_cost_ratio - expected_bcr) < 0.01
                 end

                 # Breakdown completeness
                 assert is_map(result.cost_breakdown)
                 assert is_map(result.benefit_breakdown)
                 assert result.cost_breakdown |> Map.keys() |> length() > 0
                 assert result.benefit_breakdown |> Map.keys() |> length() > 0
               end
             )
    end

    test "exunitproperties: measure_cost_benefits/4 handles different business complexities" do
      ExUnitProperties.check all(
                               business_unit <- SD.member_of(@business_units),
                               project_size <- SD.member_of(@cost_ranges),
                               evaluation_period <- SD.member_of(@evaluation_periods),
                               max_runs: 30
                             ) do
        {min_cost, max_cost} = project_size

        # Generate realistic cost structure
        costs = %{
          implementation: :rand.uniform() * (max_cost - min_cost) + min_cost,
          training: (max_cost - min_cost) * 0.1 * :rand.uniform(),
          maintenance: (max_cost - min_cost) * 0.15 * :rand.uniform(),
          opportunity_cost: (max_cost - min_cost) * 0.05 * :rand.uniform()
        }

        # Generate corresponding benefits
        cost_total = costs |> Map.values() |> Enum.sum()

        benefits = %{
          efficiency_gains: cost_total * 0.3 * (1 + :rand.uniform()),
          cost_savings: cost_total * 0.2 * (1 + :rand.uniform()),
          revenue_increase: cost_total * 0.4 * :rand.uniform(),
          risk_reduction: cost_total * 0.1 * :rand.uniform()
        }

        business_context = %{
          business_unit: business_unit,
          project_size_category: classify_project_size(project_size),
          industry_context: :technology,
          regulatory_requirements: business_unit in [:finance, :legal, :hr]
        }

        analysis_params = %{
          evaluation_period_months: evaluation_period,
          confidence_level: 0.90,
          include_intangible_benefits: true,
          risk_adjustment: get_risk_adjustment(business_unit)
        }

        result =
          BusinessValueMeasurement.measure_cost_benefits(
            costs,
            benefits,
            business_context,
            analysis_params
          )

        # Business unit specific validations
        case business_unit do
          :finance ->
            assert Map.has_key?(result, :regulatory_compliance_value)
            assert Map.has_key?(result, :audit_trail)

          :sales ->
            assert Map.has_key?(result, :revenue_attribution)
            assert result.revenue_attribution.confidence >= 0.8

          :it ->
            assert Map.has_key?(result, :technical_debt_reduction)
            assert Map.has_key?(result, :system_reliability_improvement)

          :operations ->
            assert Map.has_key?(result, :efficiency_metrics)
            assert Map.has_key?(result, :process_improvement_value)

          _ ->
            # General validations for all business units
            assert result.total_costs > 0
            assert result.total_benefits >= 0
        end

        # Evaluation period impact
        if evaluation_period >= 12 do
          assert Map.has_key?(result, :long_term_projections)
          assert Map.has_key?(result, :compound_benefits)
        end

        # Project size impact on analysis depth
        complexity_score = get_complexity_score(project_size)

        if complexity_score >= 3 do
          assert Map.has_key?(result, :detailed_risk_analysis)
          assert Map.has_key?(result, :sensitivity_analysis)
        end
      end
    end
  end

  # Helper functions for measure_cost_benefits tests
  defp classify_project_size({_min, max}) when max <= 50_000, do: :small
  defp classify_project_size({_min, max}) when max <= 500_000, do: :medium
  defp classify_project_size({_min, max}) when max <= 5_000_000, do: :large
  defp classify_project_size(_), do: :enterprise

  defp get_risk_adjustment(:finance), do: 0.02
  defp get_risk_adjustment(:legal), do: 0.03
  defp get_risk_adjustment(:it), do: 0.05
  defp get_risk_adjustment(_), do: 0.04

  defp get_complexity_score({_min, max}) when max <= 50_000, do: 1
  defp get_complexity_score({_min, max}) when max <= 500_000, do: 2
  defp get_complexity_score({_min, max}) when max <= 5_000_000, do: 3
  defp get_complexity_score(_), do: 4

  describe "track_value_attribution/3 - Value source tracking and attribution" do
    test "propcheck: track_value_attribution/3 maintains traceability with advanced shrinking" do
      assert PropCheck.quickcheck(
               forall {value_sources, attribution_rules, tracking_config} <- {
                        PC.list(PC.map(PC.atom(), PC.any())),
                        PC.map(PC.atom(), PC.any()),
                        PC.map(PC.atom(), PC.any())
                      } do
                 result =
                   BusinessValueMeasurement.track_value_attribution(
                     value_sources,
                     attribution_rules,
                     tracking_config
                   )

                 # Validate attribution tracking structure
                 assert is_map(result)
                 assert Map.has_key?(result, :attributed_value)
                 assert Map.has_key?(result, :source_contributions)
                 assert Map.has_key?(result, :attribution_confidence)
                 assert Map.has_key?(result, :traceability_chain)

                 # Validate source contributions
                 source_contributions = result.source_contributions
                 assert is_map(source_contributions)

                 # Total attribution should equal 100% (within tolerance)
                 if map_size(source_contributions) > 0 do
                   total_attribution = source_contributions |> Map.values() |> Enum.sum()
                   # 1% tolerance for rounding
                   assert abs(total_attribution - 1.0) <= 0.01
                 end

                 # Validate traceability chain
                 traceability = result.traceability_chain
                 assert is_list(traceability)

                 Enum.each(traceability, fn trace_entry ->
                   assert Map.has_key?(trace_entry, :source_id)
                   assert Map.has_key?(trace_entry, :value_amount)
                   assert Map.has_key?(trace_entry, :attribution_method)
                   assert Map.has_key?(trace_entry, :confidence_score)

                   assert trace_entry.confidence_score >= 0.0 and
                            trace_entry.confidence_score <= 1.0
                 end)
               end
             )
    end

    test "exunitproperties: track_value_attribution/3 handles complex attribution scenarios" do
      ExUnitProperties.check all(
                               value_category <- SD.member_of(@value_categories),
                               source_count <- SD.integer(2..8),
                               confidence_level <- SD.member_of(@confidence_intervals),
                               max_runs: 40
                             ) do
        # Generate multiple value sources
        value_sources =
          Enum.map(1..source_count, fn i ->
            %{
              source_id: "source_#{i}",
              source_type: Enum.random([:direct, :indirect, :catalytic, :enabling]),
              value_category: value_category,
              measured_value: :rand.uniform() * 100_000,
              # 70-100% confidence
              measurement_confidence: 0.7 + :rand.uniform() * 0.3,
              time_period: Enum.random(@measurement_periods)
            }
          end)

        attribution_rules = %{
          direct_attribution_weight: 0.7,
          indirect_attribution_weight: 0.2,
          catalytic_attribution_weight: 0.1,
          minimum_confidence_threshold: confidence_level,
          attribution_method: determine_attribution_method(value_category)
        }

        tracking_config = %{
          enable_cross_source_analysis: true,
          require_audit_trail: true,
          confidence_level: confidence_level,
          time_period_normalization: true
        }

        result =
          BusinessValueMeasurement.track_value_attribution(
            value_sources,
            attribution_rules,
            tracking_config
          )

        # Validate attribution by category
        case value_category do
          :cost_reduction ->
            assert Map.has_key?(result, :cost_reduction_sources)
            assert Map.has_key?(result, :baseline_cost_analysis)

          :revenue_increase ->
            assert Map.has_key?(result, :revenue_attribution_model)
            assert Map.has_key?(result, :revenue_source_analysis)

          :risk_mitigation ->
            assert Map.has_key?(result, :risk_reduction_quantification)
            assert Map.has_key?(result, :probability_impact_analysis)

          :efficiency_improvement ->
            assert Map.has_key?(result, :efficiency_metrics)
            assert Map.has_key?(result, :productivity_attribution)

          :customer_satisfaction ->
            assert Map.has_key?(result, :satisfaction_value_mapping)
            assert Map.has_key?(result, :customer_lifetime_value_impact)
        end

        # Confidence level compliance
        overall_confidence = result.attribution_confidence
        # Allow 10% confidence degradation
        assert overall_confidence >= confidence_level * 0.9,
               "Confidence #{overall_confidence} below expected #{confidence_level * 0.9}"

        # Source count impact on attribution granularity
        if source_count >= 5 do
          assert Map.has_key?(result, :multi_source_interaction_analysis)
          assert Map.has_key?(result, :attribution_complexity_score)
        end

        # Audit trail completeness
        if tracking_config.require_audit_trail do
          assert Map.has_key?(result, :audit_trail)
          audit_trail = result.audit_trail
          assert length(audit_trail.decision_points) >= source_count
          assert Map.has_key?(audit_trail, :methodology_documentation)
        end
      end
    end
  end

  # Helper function moved from inside test block
  defp determine_attribution_method(:cost_reduction), do: :baseline_comparison
  defp determine_attribution_method(:revenue_increase), do: :incremental_analysis
  defp determine_attribution_method(:risk_mitigation), do: :probability_modeling
  defp determine_attribution_method(:efficiency_improvement), do: :productivity_measurement
  defp determine_attribution_method(:customer_satisfaction), do: :correlation_analysis

  defp calculate_manual_npv(investment, benefits, discount_rate) do
    monthly_rate = discount_rate / 12

    discounted_benefits =
      benefits
      |> Enum.with_index(1)
      |> Enum.map(fn {benefit, month} ->
        benefit / :math.pow(1 + monthly_rate, month)
      end)
      |> Enum.sum()

    discounted_benefits - investment
  end

  defp generate_affected_kpis(:simple), do: ["revenue", "cost"]
  defp generate_affected_kpis(:moderate), do: ["revenue", "cost", "efficiency", "quality"]

  defp generate_affected_kpis(:complex),
    do: [
      "revenue",
      "cost",
      "efficiency",
      "quality",
      "customer_satisfaction",
      "employee_productivity",
      "risk_exposure"
    ]

  defp determine_traceability_depth(:simple), do: 2
  defp determine_traceability_depth(:moderate), do: 3
  defp determine_traceability_depth(:complex), do: 5

  # Helper functions for business complexity cost-benefit analysis (SC-BVM-004)
  defp generate_costs_by_complexity(complexity) do
    {min_cost, max_cost} = complexity.cost_range
    base_cost = min_cost + :rand.uniform(max_cost - min_cost)

    %{
      implementation: base_cost * 0.4,
      training: base_cost * 0.1,
      maintenance: base_cost * 0.15,
      infrastructure: base_cost * 0.2,
      consulting: base_cost * 0.15
    }
  end

  defp generate_benefits_by_complexity(complexity) do
    {min_cost, max_cost} = complexity.cost_range
    base_benefit = (min_cost + max_cost) / 2 * 1.5

    categories = complexity.benefit_categories
    benefit_per_category = base_benefit / categories

    1..categories
    |> Enum.map(fn i ->
      {String.to_atom("benefit_category_#{i}"),
       benefit_per_category * (0.8 + :rand.uniform() * 0.4)}
    end)
    |> Map.new()
  end

  defp calculate_org_complexity(complexity) do
    case complexity.name do
      :startup -> 1.0
      :small_business -> 2.0
      :mid_market -> 3.5
      :enterprise -> 5.0
    end
  end

  defp get_regulatory_complexity(company_size) do
    case company_size do
      :startup -> :low
      :small_business -> :moderate
      :mid_market -> :high
      :enterprise -> :critical
    end
  end

  describe "generate_value_report/3 - Comprehensive value reporting" do
    test "propcheck: generate_value_report/3 produces comprehensive business reports" do
      assert PropCheck.quickcheck(
               forall {value_data, report_config, stakeholder_requirements} <- {
                        PC.map(PC.atom(), PC.any()),
                        PC.map(PC.atom(), PC.any()),
                        PC.list(PC.map(PC.atom(), PC.any()))
                      } do
                 result =
                   BusinessValueMeasurement.generate_value_report(
                     value_data,
                     report_config,
                     stakeholder_requirements
                   )

                 # Validate report structure
                 assert is_map(result)
                 assert Map.has_key?(result, :executive_summary)
                 assert Map.has_key?(result, :detailed_analysis)
                 assert Map.has_key?(result, :financial_metrics)
                 assert Map.has_key?(result, :recommendations)
                 assert Map.has_key?(result, :appendices)

                 # Validate executive summary
                 executive_summary = result.executive_summary
                 assert is_map(executive_summary)
                 assert Map.has_key?(executive_summary, :key_findings)
                 assert Map.has_key?(executive_summary, :roi_summary)
                 assert Map.has_key?(executive_summary, :strategic_impact)

                 # Validate detailed analysis
                 detailed_analysis = result.detailed_analysis
                 assert is_map(detailed_analysis)
                 assert Map.has_key?(detailed_analysis, :methodology)
                 assert Map.has_key?(detailed_analysis, :data_sources)
                 assert Map.has_key?(detailed_analysis, :assumptions)

                 # Validate financial metrics
                 financial_metrics = result.financial_metrics
                 assert is_map(financial_metrics)
                 assert Map.has_key?(financial_metrics, :primary_metrics)
                 assert Map.has_key?(financial_metrics, :supporting_metrics)
                 assert Map.has_key?(financial_metrics, :confidence_intervals)
               end
             )
    end

    test "exunitproperties: generate_value_report/3 adapts to different stakeholder needs" do
      ExUnitProperties.check all(
                               business_unit <- SD.member_of(@business_units),
                               reporting_period <- SD.member_of(@measurement_periods),
                               stakeholder_count <- SD.integer(1..6),
                               max_runs: 25
                             ) do
        # Generate realistic value data
        value_data = %{
          # $100K - $1M
          investment_amount: 100_000 + :rand.uniform() * 900_000,
          # $150K - $1.5M
          realized_benefits: 150_000 + :rand.uniform() * 1_350_000,
          measurement_period: reporting_period,
          business_unit: business_unit,
          project_category:
            Enum.random([:cost_optimization, :revenue_generation, :risk_management, :innovation])
        }

        # Generate different stakeholder requirements
        stakeholders =
          Enum.map(1..stakeholder_count, fn i ->
            %{
              stakeholder_id: "stakeholder_#{i}",
              role: Enum.random([:ceo, :cfo, :cto, :business_owner, :project_manager, :auditor]),
              information_needs:
                Enum.random([
                  [:executive_summary, :roi_metrics],
                  [:detailed_analysis, :risk_assessment],
                  [:financial_breakdown, :audit_trail],
                  [:strategic_impact, :recommendations]
                ]),
              report_format: Enum.random([:pdf, :dashboard, :presentation, :detailed_document])
            }
          end)

        report_config = %{
          reporting_period: reporting_period,
          include_projections: reporting_period in [:quarterly, :yearly],
          compliance_requirements: business_unit in [:finance, :legal],
          confidentiality_level: Enum.random([:public, :internal, :confidential, :restricted])
        }

        result =
          BusinessValueMeasurement.generate_value_report(value_data, report_config, stakeholders)

        # Stakeholder-specific content validation
        Enum.each(stakeholders, fn stakeholder ->
          stakeholder_section = result.stakeholder_specific_content[stakeholder.stakeholder_id]
          assert stakeholder_section != nil

          case stakeholder.role do
            :ceo ->
              assert Map.has_key?(stakeholder_section, :strategic_summary)
              assert Map.has_key?(stakeholder_section, :competitive_advantage)

            :cfo ->
              assert Map.has_key?(stakeholder_section, :financial_analysis)
              assert Map.has_key?(stakeholder_section, :budget_impact)
              assert Map.has_key?(stakeholder_section, :cash_flow_analysis)

            :cto ->
              assert Map.has_key?(stakeholder_section, :technical_value_delivery)
              assert Map.has_key?(stakeholder_section, :innovation_metrics)

            :auditor ->
              assert Map.has_key?(stakeholder_section, :audit_trail)
              assert Map.has_key?(stakeholder_section, :compliance_validation)
              assert Map.has_key?(stakeholder_section, :methodology_documentation)

            _ ->
              # General stakeholder requirements
              assert Map.has_key?(stakeholder_section, :relevant_metrics)
              assert Map.has_key?(stakeholder_section, :action_items)
          end
        end)

        # Reporting period specific content
        case reporting_period do
          :monthly ->
            assert Map.has_key?(result, :month_over_month_analysis)
            assert Map.has_key?(result, :short_term_trends)

          :quarterly ->
            assert Map.has_key?(result, :quarterly_projections)
            assert Map.has_key?(result, :seasonal_adjustments)

          :yearly ->
            assert Map.has_key?(result, :annual_strategic_impact)
            assert Map.has_key?(result, :long_term_value_trajectory)

          _ ->
            assert Map.has_key?(result, :period_specific_analysis)
        end

        # Business unit specific requirements
        case business_unit do
          :finance ->
            assert Map.has_key?(result, :regulatory_compliance_report)
            assert Map.has_key?(result, :financial_controls_validation)

          :sales ->
            assert Map.has_key?(result, :sales_performance_impact)
            assert Map.has_key?(result, :customer_value_analysis)

          :it ->
            assert Map.has_key?(result, :technical_roi_analysis)
            assert Map.has_key?(result, :system_improvement_metrics)

          _ ->
            assert Map.has_key?(result, :business_unit_specific_metrics)
        end
      end
    end
  end

  describe "STAMP Safety Constraints Validation" do
    test "SC-BVM-001: Business value calculations SHALL maintain financial accuracy and auditability" do
      ExUnitProperties.check all(
                               investment <- SD.float(min: 50_000.0, max: 5_000_000.0),
                               calculation_method <- SD.member_of(@roi_calculation_methods),
                               precision_requirement <- SD.member_of([0.99, 0.995, 0.999]),
                               max_runs: 20
                             ) do
        # Generate multi-year benefit stream
        # 3 years
        benefits =
          Enum.map(1..36, fn month ->
            # 1.5% with ±5% variation
            monthly_benefit = investment * 0.015 * (1 + (:rand.uniform() - 0.5) * 0.1)
            # Ensure non-negative
            max(0, monthly_benefit)
          end)

        params = %{
          time_periods: Enum.to_list(1..36),
          discount_rate: 0.06,
          currency: :usd,
          precision_requirement: precision_requirement,
          audit_trail_required: true
        }

        result =
          BusinessValueMeasurement.calculate_roi(investment, benefits, calculation_method, params)

        # Financial accuracy validation
        assert result.financial_accuracy.precision >= precision_requirement
        assert Map.has_key?(result.financial_accuracy, :calculation_steps)
        assert Map.has_key?(result.financial_accuracy, :intermediate_results)

        # Auditability requirements
        assert Map.has_key?(result, :audit_trail)
        audit_trail = result.audit_trail
        assert Map.has_key?(audit_trail, :calculation_methodology)
        assert Map.has_key?(audit_trail, :input_validation)
        assert Map.has_key?(audit_trail, :assumption_documentation)

        # Mathematical consistency validation
        case calculation_method do
          :simple_roi ->
            total_benefits = Enum.sum(benefits)
            manual_roi = (total_benefits - investment) / investment * 100
            tolerance = abs(manual_roi * (1 - precision_requirement))
            assert abs(result.roi_percentage - manual_roi) <= tolerance

          :npv ->
            # Validate NPV calculation accuracy
            manual_npv = calculate_manual_npv(investment, benefits, params.discount_rate)
            tolerance = abs(manual_npv * (1 - precision_requirement))
            assert abs(result.net_present_value - manual_npv) <= tolerance

          _ ->
            # Ensure calculation steps are documented for audit
            assert length(audit_trail.calculation_steps) > 0
        end

        # Precision metadata validation
        assert result.financial_accuracy.decimal_places >= 2
        assert Map.has_key?(result.financial_accuracy, :rounding_method)
        assert result.financial_accuracy.rounding_method in [:banker, :half_up, :truncate]
      end
    end

    test "SC-BVM-002: ROI measurements SHALL preserve temporal consistency across time periods" do
      ExUnitProperties.check all(
                               base_period_months <- SD.integer(12..48),
                               measurement_frequency <-
                                 SD.member_of([:monthly, :quarterly, :annually]),
                               max_runs: 15
                             ) do
        # Generate consistent time-series data
        investment_amount = 500_000.0
        base_monthly_benefit = 25_000.0

        # Create benefits across different time granularities
        monthly_benefits =
          Enum.map(1..base_period_months, fn month ->
            # 6-month cycle
            seasonal_factor = 1 + 0.1 * :math.sin(month * :math.pi() / 6)
            base_monthly_benefit * seasonal_factor
          end)

        # Calculate ROI at different frequencies
        monthly_roi =
          BusinessValueMeasurement.calculate_roi(
            investment_amount,
            monthly_benefits,
            :simple_roi,
            %{time_periods: Enum.to_list(1..base_period_months), frequency: :monthly}
          )

        # Aggregate to quarterly
        quarterly_benefits =
          monthly_benefits
          |> Enum.chunk_every(3)
          |> Enum.map(&Enum.sum/1)

        quarterly_roi =
          BusinessValueMeasurement.calculate_roi(
            investment_amount,
            quarterly_benefits,
            :simple_roi,
            %{time_periods: Enum.to_list(1..div(base_period_months, 3)), frequency: :quarterly}
          )

        # Aggregate to annual
        annual_benefits =
          monthly_benefits
          |> Enum.chunk_every(12)
          |> Enum.map(&Enum.sum/1)

        annual_roi =
          BusinessValueMeasurement.calculate_roi(
            investment_amount,
            annual_benefits,
            :simple_roi,
            %{time_periods: Enum.to_list(1..div(base_period_months, 12)), frequency: :annually}
          )

        # Temporal consistency validation
        # All calculations should yield similar ROI percentages (within 5% tolerance)
        # 5% tolerance for aggregation effects
        tolerance = 5.0

        assert abs(monthly_roi.roi_percentage - quarterly_roi.roi_percentage) <= tolerance,
               "Monthly vs Quarterly ROI inconsistency: #{monthly_roi.roi_percentage} vs #{quarterly_roi.roi_percentage}"

        if length(annual_benefits) > 0 do
          assert abs(monthly_roi.roi_percentage - annual_roi.roi_percentage) <= tolerance,
                 "Monthly vs Annual ROI inconsistency: #{monthly_roi.roi_percentage} vs #{annual_roi.roi_percentage}"
        end

        # Temporal metadata consistency
        assert Map.has_key?(monthly_roi, :temporal_metadata)
        assert Map.has_key?(quarterly_roi, :temporal_metadata)

        monthly_metadata = monthly_roi.temporal_metadata
        quarterly_metadata = quarterly_roi.temporal_metadata

        assert monthly_metadata.base_period_months == base_period_months
        assert quarterly_metadata.base_period_months == base_period_months
        assert monthly_metadata.measurement_frequency == :monthly
        assert quarterly_metadata.measurement_frequency == :quarterly
      end
    end

    test "SC-BVM-003: Value attribution SHALL maintain traceability to source business activities" do
      ExUnitProperties.check all(
                               activity_count <- SD.integer(5..15),
                               attribution_complexity <-
                                 SD.member_of([:simple, :moderate, :complex]),
                               max_runs: 12
                             ) do
        # Generate business activities with measurable value
        business_activities =
          Enum.map(1..activity_count, fn i ->
            %{
              activity_id: "activity_#{i}",
              activity_type:
                Enum.random([
                  :process_improvement,
                  :automation,
                  :training,
                  :system_upgrade,
                  :policy_change
                ]),
              business_unit: Enum.random(@business_units),
              start_date: DateTime.add(DateTime.utc_now(), -(365 + i * 30) * 24 * 3600, :second),
              investment: 10_000 + :rand.uniform() * 90_000,
              direct_value: 15_000 + :rand.uniform() * 135_000,
              participants: for(j <- 1..(:rand.uniform(20) + 5), do: "user_#{j}"),
              kpis_affected: generate_affected_kpis(attribution_complexity)
            }
          end)

        attribution_config = %{
          complexity_level: attribution_complexity,
          traceability_depth: determine_traceability_depth(attribution_complexity),
          cross_activity_analysis: true,
          temporal_correlation: true
        }

        tracking_config = %{
          maintain_participant_tracking: true,
          kpi_correlation_analysis: true,
          causal_chain_documentation: true
        }

        result =
          BusinessValueMeasurement.track_value_attribution(
            business_activities,
            attribution_config,
            tracking_config
          )

        # Traceability validation
        assert Map.has_key?(result, :traceability_matrix)
        traceability_matrix = result.traceability_matrix

        # Each activity should be traceable
        Enum.each(business_activities, fn activity ->
          activity_trace = traceability_matrix[activity.activity_id]
          assert activity_trace != nil

          # Validate traceability depth
          assert Map.has_key?(activity_trace, :direct_impact)
          assert Map.has_key?(activity_trace, :participant_attribution)
          assert Map.has_key?(activity_trace, :kpi_correlation)

          # Participant traceability
          participant_attribution = activity_trace.participant_attribution
          assert length(participant_attribution) == length(activity.participants)

          Enum.each(participant_attribution, fn participant_impact ->
            assert Map.has_key?(participant_impact, :participant_id)
            assert Map.has_key?(participant_impact, :value_contribution)
            assert Map.has_key?(participant_impact, :confidence_score)
          end)

          # KPI correlation traceability
          kpi_correlation = activity_trace.kpi_correlation

          Enum.each(activity.kpis_affected, fn kpi ->
            kpi_impact = kpi_correlation[kpi]
            assert kpi_impact != nil
            assert Map.has_key?(kpi_impact, :baseline_value)
            assert Map.has_key?(kpi_impact, :post_activity_value)
            assert Map.has_key?(kpi_impact, :attribution_confidence)
          end)
        end)

        # Cross-activity traceability for complex scenarios
        if attribution_complexity == :complex do
          assert Map.has_key?(result, :cross_activity_interactions)
          interactions = result.cross_activity_interactions

          # Should identify synergistic effects
          if length(business_activities) >= 3 do
            assert Map.has_key?(interactions, :synergy_analysis)
            assert Map.has_key?(interactions, :overlap_detection)
          end
        end

        # Temporal correlation validation
        assert Map.has_key?(result, :temporal_correlation_analysis)
        temporal_analysis = result.temporal_correlation_analysis
        assert Map.has_key?(temporal_analysis, :time_lag_analysis)
        assert Map.has_key?(temporal_analysis, :value_realization_timeline)
      end
    end

    test "SC-BVM-004: Cost-benefit analysis SHALL scale accurately with business complexity" do
      business_complexities = [
        %{name: :startup, cost_range: {10_000, 100_000}, benefit_categories: 3, stakeholders: 5},
        %{
          name: :small_business,
          cost_range: {100_000, 500_000},
          benefit_categories: 5,
          stakeholders: 10
        },
        %{
          name: :mid_market,
          cost_range: {500_000, 2_000_000},
          benefit_categories: 8,
          stakeholders: 25
        },
        %{
          name: :enterprise,
          cost_range: {2_000_000, 10_000_000},
          benefit_categories: 12,
          stakeholders: 50
        }
      ]

      Enum.each(business_complexities, fn complexity ->
        {min_cost, max_cost} = complexity.cost_range

        # Generate costs proportional to complexity
        costs = generate_costs_by_complexity(complexity)
        benefits = generate_benefits_by_complexity(complexity)

        business_context = %{
          company_size: complexity.name,
          stakeholder_count: complexity.stakeholders,
          organizational_complexity: calculate_org_complexity(complexity),
          regulatory_complexity: get_regulatory_complexity(complexity.name)
        }

        analysis_params = %{
          complexity_scaling: true,
          stakeholder_analysis_depth: complexity.stakeholders,
          benefit_category_analysis: complexity.benefit_categories,
          scenario_modeling: complexity.name in [:mid_market, :enterprise]
        }

        start_time = System.monotonic_time(:millisecond)

        result =
          BusinessValueMeasurement.measure_cost_benefits(
            costs,
            benefits,
            business_context,
            analysis_params
          )

        end_time = System.monotonic_time(:millisecond)

        analysis_time = end_time - start_time

        # Scaling validation - analysis time should scale sublinearly
        max_analysis_time =
          case complexity.name do
            # 1 second
            :startup -> 1000
            # 2 seconds
            :small_business -> 2000
            # 4 seconds
            :mid_market -> 4000
            # 8 seconds
            :enterprise -> 8000
          end

        assert analysis_time <= max_analysis_time,
               "Analysis time #{analysis_time}ms exceeds limit #{max_analysis_time}ms for #{complexity.name}"

        # Complexity-appropriate analysis depth
        case complexity.name do
          :startup ->
            assert Map.has_key?(result, :simplified_analysis)
            assert map_size(result.cost_breakdown) >= 3

          :small_business ->
            assert Map.has_key?(result, :stakeholder_impact_analysis)
            assert length(result.stakeholder_impact_analysis) == complexity.stakeholders

          :mid_market ->
            assert Map.has_key?(result, :scenario_analysis)
            assert Map.has_key?(result, :risk_sensitivity_analysis)
            assert length(result.scenario_analysis.scenarios) >= 3

          :enterprise ->
            assert Map.has_key?(result, :comprehensive_modeling)
            assert Map.has_key?(result, :monte_carlo_simulation)
            assert Map.has_key?(result, :portfolio_impact_analysis)
            assert result.monte_carlo_simulation.iterations >= 1000
        end

        # Benefit category scaling
        assert map_size(result.benefit_breakdown) >= complexity.benefit_categories

        # Analysis quality should improve with complexity
        complexity_score = result.analysis_quality.complexity_score

        expected_min_score =
          case complexity.name do
            :startup -> 0.7
            :small_business -> 0.8
            :mid_market -> 0.9
            :enterprise -> 0.95
          end

        assert complexity_score >= expected_min_score,
               "Complexity score #{complexity_score} below expected #{expected_min_score} for #{complexity.name}"
      end)
    end

    test "SC-BVM-005: Value metrics SHALL align with enterprise financial reporting standards" do
      ExUnitProperties.check all(
                               reporting_standard <-
                                 SD.member_of([:gaap, :ifrs, :sox, :internal]),
                               currency <- SD.member_of(@currency_types),
                               # Month
                               fiscal_year_end <- SD.member_of([1, 3, 6, 9, 12]),
                               max_runs: 15
                             ) do
        # Generate financial data that requires compliance
        investment_data = %{
          capital_expenditure: 1_000_000.0,
          operational_expenditure: 500_000.0,
          depreciation_period_years: 5,
          salvage_value: 100_000.0,
          currency: currency,
          fiscal_year_end_month: fiscal_year_end
        }

        benefits_data = %{
          recurring_annual_savings: 400_000.0,
          one_time_benefits: 200_000.0,
          intangible_benefits: 150_000.0,
          revenue_uplift: 300_000.0,
          currency: currency
        }

        reporting_config = %{
          standard: reporting_standard,
          compliance_level: :full,
          audit_requirements: reporting_standard in [:gaap, :ifrs, :sox],
          currency_conversion_required: currency != :usd
        }

        result =
          BusinessValueMeasurement.generate_compliance_report(
            investment_data,
            benefits_data,
            reporting_config
          )

        # Standard-specific validations
        case reporting_standard do
          :gaap ->
            assert Map.has_key?(result, :gaap_compliance_metrics)
            gaap_metrics = result.gaap_compliance_metrics
            assert Map.has_key?(gaap_metrics, :depreciation_schedule)
            assert Map.has_key?(gaap_metrics, :revenue_recognition)
            assert Map.has_key?(gaap_metrics, :matching_principle_adherence)

            # GAAP depreciation validation
            depreciation = gaap_metrics.depreciation_schedule

            annual_depreciation =
              (investment_data.capital_expenditure - investment_data.salvage_value) /
                investment_data.depreciation_period_years

            assert abs(depreciation.annual_depreciation - annual_depreciation) < 0.01

          :ifrs ->
            assert Map.has_key?(result, :ifrs_compliance_metrics)
            ifrs_metrics = result.ifrs_compliance_metrics
            assert Map.has_key?(ifrs_metrics, :fair_value_assessment)
            assert Map.has_key?(ifrs_metrics, :impairment_testing)
            assert Map.has_key?(ifrs_metrics, :disclosure_requirements)

          :sox ->
            assert Map.has_key?(result, :sox_compliance_metrics)
            sox_metrics = result.sox_compliance_metrics
            assert Map.has_key?(sox_metrics, :internal_controls_validation)
            assert Map.has_key?(sox_metrics, :financial_reporting_controls)
            assert Map.has_key?(sox_metrics, :audit_trail_completeness)

            # SOX audit trail validation
            assert sox_metrics.audit_trail_completeness >= 0.99
            assert Map.has_key?(sox_metrics, :control_testing_results)

          :internal ->
            assert Map.has_key?(result, :internal_reporting_metrics)
            internal_metrics = result.internal_reporting_metrics
            assert Map.has_key?(internal_metrics, :management_reporting)
            assert Map.has_key?(internal_metrics, :performance_dashboards)
        end

        # Currency compliance
        if reporting_config.currency_conversion_required do
          assert Map.has_key?(result, :currency_conversion_details)
          conversion_details = result.currency_conversion_details
          assert conversion_details.base_currency == currency
          assert conversion_details.reporting_currency == :usd
          assert Map.has_key?(conversion_details, :exchange_rates_used)
          assert Map.has_key?(conversion_details, :conversion_methodology)
        end

        # Fiscal year alignment
        assert Map.has_key?(result, :fiscal_period_alignment)
        fiscal_alignment = result.fiscal_period_alignment
        assert fiscal_alignment.fiscal_year_end_month == fiscal_year_end
        assert Map.has_key?(fiscal_alignment, :period_boundary_adjustments)

        # Financial statement integration
        assert Map.has_key?(result, :financial_statement_integration)
        fs_integration = result.financial_statement_integration
        assert Map.has_key?(fs_integration, :balance_sheet_impact)
        assert Map.has_key?(fs_integration, :income_statement_impact)
        assert Map.has_key?(fs_integration, :cash_flow_impact)

        # Audit readiness
        if reporting_config.audit_requirements do
          assert Map.has_key?(result, :audit_readiness_checklist)
          audit_checklist = result.audit_readiness_checklist
          assert audit_checklist.documentation_completeness >= 0.95
          assert audit_checklist.calculation_traceability >= 0.99
          assert Map.has_key?(audit_checklist, :supporting_evidence)
        end
      end
    end
  end

  describe "Integration and End-to-End Testing" do
    test "complete business value measurement lifecycle" do
      # End-to-end pipeline: investment → measurement → attribution → reporting

      # Step 1: Investment definition
      investment_portfolio = %{
        digital_transformation: 2_000_000,
        process_automation: 800_000,
        employee_training: 300_000,
        infrastructure_upgrade: 1_200_000
      }

      # Step 2: ROI calculation for each investment
      map_results =
        Enum.map(investment_portfolio, fn {investment_name, amount} ->
          benefits = generate_realistic_benefits(amount, investment_name)

          roi_result =
            BusinessValueMeasurement.calculate_roi(
              amount,
              benefits,
              :npv,
              %{time_periods: Enum.to_list(1..36), discount_rate: 0.08}
            )

          {investment_name, roi_result}
        end)

      roi_results = map_results |> Enum.into(%{})

      # Step 3: Cost-benefit analysis
      total_costs = investment_portfolio |> Map.values() |> Enum.sum()

      total_benefits =
        roi_results
        |> Map.values()
        |> Enum.map(fn roi -> roi.total_benefits end)
        |> Enum.sum()

      cost_benefit_result =
        BusinessValueMeasurement.measure_cost_benefits(
          investment_portfolio,
          %{total_realized_benefits: total_benefits},
          %{portfolio_analysis: true, enterprise_context: true},
          %{evaluation_period_months: 36}
        )

      # Step 4: Value attribution
      value_sources =
        Enum.map(investment_portfolio, fn {name, amount} ->
          %{
            source_id: name,
            investment_amount: amount,
            realized_benefits: roi_results[name].total_benefits,
            attribution_confidence: 0.9
          }
        end)

      attribution_result =
        BusinessValueMeasurement.track_value_attribution(
          value_sources,
          %{attribution_method: :proportional, confidence_threshold: 0.8},
          %{enable_cross_source_analysis: true}
        )

      # Step 5: Comprehensive reporting
      report_result =
        BusinessValueMeasurement.generate_value_report(
          %{
            portfolio_investment: total_costs,
            portfolio_benefits: total_benefits,
            individual_roi_results: roi_results,
            attribution_analysis: attribution_result
          },
          %{report_type: :executive_summary, include_projections: true},
          [
            %{role: :ceo, information_needs: [:strategic_impact, :roi_summary]},
            %{role: :cfo, information_needs: [:financial_analysis, :audit_trail]}
          ]
        )

      # Validate complete pipeline
      assert map_size(roi_results) == map_size(investment_portfolio)
      assert cost_benefit_result.total_costs == total_costs
      assert attribution_result.attributed_value != nil
      assert report_result.executive_summary != nil

      # Cross-component consistency
      portfolio_roi = (total_benefits - total_costs) / total_costs * 100
      # 5% tolerance for aggregation
      tolerance = 5.0

      Enum.each(roi_results, fn {investment_name, roi_result} ->
        assert roi_result.roi_percentage >= -50.0 and roi_result.roi_percentage <= 500.0
        assert roi_result.net_present_value != nil
      end)

      # Attribution consistency
      total_attributed =
        attribution_result.source_contributions
        |> Map.values()
        |> Enum.sum()

      # Should sum to 100%
      assert abs(total_attributed - 1.0) <= 0.01

      # Report completeness
      assert Map.has_key?(report_result, :stakeholder_specific_content)
      assert map_size(report_result.stakeholder_specific_content) == 2
    end

    test "multi-currency enterprise value measurement" do
      currencies = [:usd, :eur, :gbp, :jpy]

      # Create multi-currency investment scenario
      regional_investments =
        Enum.map(currencies, fn currency ->
          base_investment =
            case currency do
              :usd -> 1_000_000
              # ~1M USD
              :eur -> 850_000
              # ~1M USD
              :gbp -> 750_000
              # ~1M USD
              :jpy -> 110_000_000
            end

          benefits =
            Enum.map(1..24, fn month ->
              # 2.5% ±10% monthly
              base_investment * 0.025 * (0.9 + :rand.uniform() * 0.2)
            end)

          %{
            currency: currency,
            investment: base_investment,
            benefits: benefits,
            region: get_region_for_currency(currency)
          }
        end)

      # Calculate ROI for each currency
      currency_map_results =
        Enum.map(regional_investments, fn regional_data ->
          roi_result =
            BusinessValueMeasurement.calculate_roi(
              regional_data.investment,
              regional_data.benefits,
              :simple_roi,
              %{
                currency: regional_data.currency,
                time_periods: Enum.to_list(1..24),
                currency_normalization: true
              }
            )

          {regional_data.currency, roi_result}
        end)

      multi_currency_results = currency_map_results |> Enum.into(%{})

      # Generate consolidated enterprise report
      consolidated_report =
        BusinessValueMeasurement.generate_value_report(
          %{multi_currency_investments: regional_investments},
          %{
            currency_consolidation: :usd,
            exchange_rate_source: :market_rates,
            consolidation_method: :weighted_average
          },
          [%{role: :cfo, information_needs: [:multi_currency_analysis, :exchange_rate_risk]}]
        )

      # Validate multi-currency handling
      assert Map.has_key?(consolidated_report, :currency_consolidation_details)
      consolidation = consolidated_report.currency_consolidation_details

      # Exchange rate consistency
      Enum.each(currencies, fn currency ->
        if currency != :usd do
          assert Map.has_key?(consolidation.exchange_rates, currency)
          rate = consolidation.exchange_rates[currency]
          assert rate > 0
        end
      end)

      # ROI consistency across currencies
      roi_values =
        multi_currency_results |> Map.values() |> Enum.map(fn r -> r.roi_percentage end)

      roi_std_dev = calculate_standard_deviation(roi_values)

      # ROI should be relatively consistent when normalized (< 20% standard deviation)
      roi_mean = Enum.sum(roi_values) / length(roi_values)
      # Coefficient of variation
      roi_cv = roi_std_dev / roi_mean
      assert roi_cv <= 0.3, "ROI coefficient of variation #{roi_cv} too high across currencies"

      # Currency risk assessment
      assert Map.has_key?(consolidated_report, :exchange_rate_risk_analysis)
      risk_analysis = consolidated_report.exchange_rate_risk_analysis
      assert Map.has_key?(risk_analysis, :volatility_assessment)
      assert Map.has_key?(risk_analysis, :hedging_recommendations)
    end
  end

  # Additional helper functions for integration tests
  defp generate_realistic_benefits(amount, _investment_name) do
    # Generate 36 months of benefits with realistic pattern
    # 3% monthly return baseline
    monthly_return = amount * 0.03

    1..36
    |> Enum.map(fn month ->
      # Ramp-up in first 6 months, then stabilize
      ramp_factor = min(month / 6, 1.0)
      volatility = 0.8 + :rand.uniform() * 0.4
      monthly_return * ramp_factor * volatility
    end)
  end

  defp calculate_standard_deviation(values) when length(values) < 2, do: 0.0

  defp calculate_standard_deviation(values) do
    mean = Enum.sum(values) / length(values)

    variance =
      values
      |> Enum.map(fn x -> :math.pow(x - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values))

    :math.sqrt(variance)
  end

  defp get_region_for_currency(currency) do
    case currency do
      :usd -> :north_america
      :eur -> :europe
      :gbp -> :uk
      :jpy -> :asia_pacific
      :cad -> :north_america
      :aud -> :asia_pacific
      _ -> :global
    end
  end
end
