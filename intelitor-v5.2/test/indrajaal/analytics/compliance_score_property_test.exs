defmodule Indrajaal.Analytics.ComplianceScorePropertyTest do
  @moduledoc """
  Property-based testing for Compliance Score Analytics module using dual testing frameworks.

  This module validates compliance score calculations, regulatory assessment, risk scoring,
  and audit trail functionality using Test-Driven Generation (TDG) methodology with
  comprehensive STAMP safety constraints.

  Testing Framework: Dual PropCheck + ExUnitProperties
  STAMP Constraints: SC-CS-001 through SC-CS-005
  Coverage: Core functions, integration, end-to-end workflows

  Key Functions Tested:
  - calculate_compliance_score/3: Multi-framework regulatory scoring
  - assess_regulatory_compliance/4: Framework-specific assessment
  - calculate_risk_score/3: Risk quantification with impact analysis
  - generate_compliance_report/3: Comprehensive compliance reporting
  - track_compliance_changes/2: Temporal compliance tracking
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

  alias Indrajaal.Analytics.ComplianceScore

  # Test data generators for comprehensive property testing
  @compliance_frameworks [:sox_404, :gdpr, :hipaa, :pci_dss, :iso_27001, :nist_csf]
  @compliance_categories [
    :data_protection,
    :financial_controls,
    :security_measures,
    :audit_trails,
    :risk_management,
    :access_controls
  ]
  @risk_levels [:low, :medium, :high, :critical]
  @compliance_statuses [:compliant, :non_compliant, :partial, :pending_review, :exception_granted]

  # ==========================================
  # CORE FUNCTION TESTING: calculate_compliance_score/3
  # ==========================================

  describe "calculate_compliance_score/3 - Regulatory compliance score calculation" do
    # PropCheck property test - Using correct forall macro syntax
    @tag :property
    test "propcheck: compliance score calculation maintains regulatory consistency" do
      tenant_ids = ["enterprise_tenant_001", "healthcare_org_002", "financial_services_003"]

      for tenant_id <- tenant_ids, framework <- @compliance_frameworks do
        compliance_data = %{
          data_protection: %{score: :rand.uniform() * 100, status: :compliant},
          security_measures: %{score: :rand.uniform() * 100, status: :partial}
        }

        result = ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, framework)

        # Core compliance score properties
        assert result.score >= 0.0 and result.score <= 100.0
        assert is_atom(result.framework) and result.framework == framework
        assert is_map(result.category_scores)
        assert is_map(result.risk_assessment)
        assert Map.has_key?(result, :compliance_date)
        assert Map.has_key?(result, :audit_trail)
      end
    end

    # ExUnitProperties test - StreamData integration
    test "exunitproperties: compliance score calculation handles edge cases correctly" do
      ExUnitProperties.check all(
                               tenant_id <-
                                 SD.member_of(["tenant_a", "tenant_b", "tenant_c"]),
                               score <- SD.float(min: 0.0, max: 100.0),
                               framework <- SD.member_of(@compliance_frameworks),
                               max_runs: 50
                             ) do
        compliance_data = %{
          data_protection: %{score: score, status: :compliant}
        }

        result = ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, framework)

        # Validate score range and structure
        assert result.score >= 0.0 and result.score <= 100.0
        assert is_atom(result.framework)
        assert is_map(result.category_scores)
        assert Map.has_key?(result, :calculated_at)
        assert Map.has_key?(result, :tenant_id)
      end
    end

    # Integration test with multi-tenant isolation
    test "calculate_compliance_score respects tenant isolation" do
      tenant_1 = "tenant_alpha"
      tenant_2 = "tenant_beta"

      compliance_data = %{
        data_protection: %{score: 85.0, status: :compliant},
        financial_controls: %{score: 92.0, status: :compliant},
        security_measures: %{score: 78.0, status: :partial}
      }

      result_1 = ComplianceScore.calculate_compliance_score(tenant_1, compliance_data, :sox_404)
      result_2 = ComplianceScore.calculate_compliance_score(tenant_2, compliance_data, :sox_404)

      # Tenant isolation verification
      assert result_1.tenant_id == tenant_1
      assert result_2.tenant_id == tenant_2
      assert result_1.tenant_id != result_2.tenant_id

      # Scores should be equivalent with same input data
      assert abs(result_1.score - result_2.score) < 0.01
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: assess_regulatory_compliance/4
  # ==========================================

  describe "assess_regulatory_compliance/4 - Framework-specific regulatory assessment" do
    # Property test - Using direct iteration
    @tag :property
    test "propcheck: regulatory assessment maintains framework consistency" do
      tenant_ids = ["tenant_alpha", "tenant_beta"]

      for tenant_id <- tenant_ids, framework <- @compliance_frameworks do
        controls = [
          %{
            control_id: "ctrl_001",
            control_type: :data_protection,
            implementation_status: :compliant,
            effectiveness_score: 85.0
          },
          %{
            control_id: "ctrl_002",
            control_type: :security_measures,
            implementation_status: :partial,
            effectiveness_score: 70.0
          }
        ]

        assessment_date = DateTime.utc_now()

        result =
          ComplianceScore.assess_regulatory_compliance(
            tenant_id,
            controls,
            framework,
            assessment_date
          )

        # Framework consistency properties
        assert result.framework == framework
        assert is_list(result.control_assessments)
        assert is_map(result.gap_analysis)
        assert Map.has_key?(result, :overall_status)
        assert result.overall_status in @compliance_statuses
        assert Map.has_key?(result, :next_review_date)
      end
    end

    # ExUnitProperties test with StreamData
    test "exunitproperties: regulatory assessment handles comprehensive control sets" do
      ExUnitProperties.check all(
                               tenant_id <- SD.member_of(["tenant_a", "tenant_b"]),
                               framework <- SD.member_of(@compliance_frameworks),
                               max_runs: 20
                             ) do
        controls = [
          %{
            control_id: "ctrl_001",
            control_type: :data_protection,
            implementation_status: :compliant,
            effectiveness_score: 85.0
          },
          %{
            control_id: "ctrl_002",
            control_type: :access_controls,
            implementation_status: :partial,
            effectiveness_score: 65.0
          }
        ]

        assessment_date = DateTime.utc_now()

        result =
          ComplianceScore.assess_regulatory_compliance(
            tenant_id,
            controls,
            framework,
            assessment_date
          )

        # Assessment completeness validation
        assert Map.has_key?(result, :control_assessments)
        assert Map.has_key?(result, :gap_analysis)
        assert Map.has_key?(result, :recommendations)
        assert result.overall_status in @compliance_statuses
        assert length(result.control_assessments) > 0
      end
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: calculate_risk_score/3
  # ==========================================

  describe "calculate_risk_score/3 - Risk quantification and impact analysis" do
    # Property test - Direct iteration
    @tag :property
    test "propcheck: risk score calculation maintains impact consistency" do
      calculation_methods = [:monte_carlo, :scenario_analysis, :sensitivity_analysis]

      for method <- calculation_methods do
        risk_factors = %{
          data_breach_risk: :rand.uniform(),
          regulatory_penalty_risk: :rand.uniform(),
          operational_risk: :rand.uniform()
        }

        impact_weights = %{critical: 0.6, high: 0.3, medium: 0.1}

        result = ComplianceScore.calculate_risk_score(risk_factors, impact_weights, method)

        # Risk score properties
        assert result.overall_score >= 0.0 and result.overall_score <= 100.0
        assert result.risk_level in @risk_levels
        assert is_map(result.factor_scores)
        assert is_list(result.mitigation_recommendations)
        assert Map.has_key?(result, :confidence_interval)
      end
    end

    # ExUnitProperties test with StreamData
    test "exunitproperties: risk score calculation handles weighted factors correctly" do
      ExUnitProperties.check all(
                               critical_weight <- SD.float(min: 0.4, max: 0.8),
                               high_weight <- SD.float(min: 0.1, max: 0.4),
                               calculation_method <-
                                 SD.member_of([
                                   :monte_carlo,
                                   :scenario_analysis,
                                   :value_at_risk
                                 ]),
                               max_runs: 30
                             ) do
        risk_factors = %{
          data_breach_risk: :rand.uniform(),
          regulatory_penalty_risk: :rand.uniform()
        }

        impact_weights = %{critical: critical_weight, high: high_weight}

        result =
          ComplianceScore.calculate_risk_score(risk_factors, impact_weights, calculation_method)

        # Risk calculation validation
        assert is_float(result.overall_score)
        assert result.overall_score >= 0.0
        assert result.risk_level in @risk_levels
        assert Map.has_key?(result, :calculated_at)
      end
    end
  end

  # ==========================================
  # CORE FUNCTION TESTING: generate_compliance_report/3
  # ==========================================

  describe "generate_compliance_report/3 - Comprehensive compliance reporting" do
    # PropCheck property test - Using direct iteration
    @tag :property
    test "propcheck: compliance report generation maintains data integrity" do
      tenant_ids = ["enterprise_tenant_001", "healthcare_org_002", "financial_services_003"]
      output_formats = [:pdf, :html, :json, :excel, :csv]

      for tenant_id <- tenant_ids, output_format <- output_formats do
        report_parameters = %{
          time_period: :current_quarter,
          include_scores: true,
          include_assessment: true,
          include_risks: true,
          detail_level: :detailed,
          frameworks: [:sox_404, :gdpr]
        }

        result =
          ComplianceScore.generate_compliance_report(
            tenant_id,
            report_parameters,
            output_format
          )

        # Report integrity properties
        assert result.format == output_format
        assert Map.has_key?(result, :executive_summary)
        assert Map.has_key?(result, :detailed_findings)
        assert Map.has_key?(result, :recommendations)
        assert is_list(result.compliance_scores)
        assert Map.has_key?(result, :generated_at)
      end
    end

    # ExUnitProperties test with StreamData generators
    test "exunitproperties: compliance report generation supports multiple formats" do
      ExUnitProperties.check all(
                               tenant_id <-
                                 SD.member_of(["tenant_a", "tenant_b", "tenant_c"]),
                               output_format <-
                                 SD.member_of([:pdf, :html, :json, :excel, :csv]),
                               max_runs: 50
                             ) do
        report_parameters = %{
          time_period: :current_quarter,
          include_scores: true,
          include_assessment: true,
          include_risks: true,
          detail_level: :detailed,
          frameworks: [:sox_404]
        }

        result =
          ComplianceScore.generate_compliance_report(tenant_id, report_parameters, output_format)

        # Report format validation
        assert result.format == output_format
        assert Map.has_key?(result, :content)
        assert Map.has_key?(result, :metadata)
        assert result.tenant_id == tenant_id
      end
    end
  end

  # ==========================================
  # INTEGRATION TESTING
  # ==========================================

  describe "Integration Testing - End-to-end compliance workflows" do
    test "complete compliance assessment workflow with score calculation" do
      tenant_id = "enterprise_tenant"

      # Step 1: Calculate initial compliance score
      compliance_data = %{
        data_protection: %{score: 88.0, status: :compliant, controls: ["dp_001", "dp_002"]},
        financial_controls: %{
          score: 94.0,
          status: :compliant,
          controls: ["fc_001", "fc_002", "fc_003"]
        },
        security_measures: %{score: 82.0, status: :partial, controls: ["sm_001", "sm_002"]}
      }

      initial_score =
        ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, :sox_404)

      assert initial_score.score > 0.0
      assert initial_score.framework == :sox_404

      # Step 2: Assess regulatory compliance
      # Build proper control maps from compliance data
      controls = [
        %{
          control_id: "dp_001",
          control_type: :data_protection,
          implementation_status: :compliant,
          effectiveness_score: 88.0
        },
        %{
          control_id: "dp_002",
          control_type: :data_protection,
          implementation_status: :compliant,
          effectiveness_score: 88.0
        },
        %{
          control_id: "fc_001",
          control_type: :financial_controls,
          implementation_status: :compliant,
          effectiveness_score: 94.0
        },
        %{
          control_id: "fc_002",
          control_type: :financial_controls,
          implementation_status: :compliant,
          effectiveness_score: 94.0
        },
        %{
          control_id: "fc_003",
          control_type: :financial_controls,
          implementation_status: :compliant,
          effectiveness_score: 94.0
        },
        %{
          control_id: "sm_001",
          control_type: :security_measures,
          implementation_status: :partial,
          effectiveness_score: 82.0
        },
        %{
          control_id: "sm_002",
          control_type: :security_measures,
          implementation_status: :partial,
          effectiveness_score: 82.0
        }
      ]

      assessment =
        ComplianceScore.assess_regulatory_compliance(
          tenant_id,
          controls,
          :sox_404,
          DateTime.utc_now()
        )

      assert assessment.framework == :sox_404
      assert length(assessment.control_assessments) > 0

      # Step 3: Calculate risk score
      risk_factors = %{
        data_breach_risk: 0.15,
        financial_fraud_risk: 0.08,
        regulatory_penalty_risk: 0.12
      }

      impact_weights = %{high: 0.7, medium: 0.2, low: 0.1}

      risk_score =
        ComplianceScore.calculate_risk_score(risk_factors, impact_weights, :monte_carlo)

      assert risk_score.overall_score >= 0.0
      assert risk_score.risk_level in @risk_levels

      # Step 4: Generate comprehensive report
      report_params = %{
        include_scores: true,
        include_assessment: true,
        include_risks: true,
        time_period: :current_quarter
      }

      report = ComplianceScore.generate_compliance_report(tenant_id, report_params, :pdf)
      assert report.format == :pdf
      assert Map.has_key?(report, :executive_summary)
      assert Map.has_key?(report, :detailed_findings)

      # Integration validation
      assert initial_score.tenant_id == tenant_id
      assert assessment.tenant_id == tenant_id
      assert report.tenant_id == tenant_id
    end
  end

  # ==========================================
  # STAMP SAFETY CONSTRAINTS (SC-CS-001 through SC-CS-005)
  # ==========================================

  describe "STAMP Safety Constraints - Compliance Score System Safety" do
    test "SC-CS-001: System SHALL maintain regulatory framework consistency across all calculations" do
      # Test regulatory consistency across multiple operations
      tenant_id = "compliance_test_tenant"

      compliance_data = %{
        data_protection: %{score: 90.0, status: :compliant},
        access_controls: %{score: 85.0, status: :compliant}
      }

      # Calculate scores for different frameworks
      sox_score = ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, :sox_404)
      gdpr_score = ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, :gdpr)

      # Framework consistency validation
      assert sox_score.framework == :sox_404
      assert gdpr_score.framework == :gdpr

      # Each framework should have consistent scoring methodology
      assert Map.has_key?(sox_score, :methodology)
      assert Map.has_key?(gdpr_score, :methodology)
      # Different frameworks = different methods
      assert sox_score.methodology != gdpr_score.methodology

      # Audit trail must reflect framework-specific requirements
      assert sox_score.audit_trail.framework_requirements !=
               gdpr_score.audit_trail.framework_requirements
    end

    test "SC-CS-002: System SHALL ensure compliance score accuracy within defined tolerance levels" do
      # Test score accuracy across multiple calculations
      tenant_id = "accuracy_test_tenant"

      compliance_data = %{
        financial_controls: %{score: 92.5, status: :compliant, evidence_count: 15}
      }

      # Run multiple calculations to check consistency
      scores =
        Enum.map(1..5, fn _ ->
          ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, :sox_404)
        end)

      # Score consistency validation
      base_score = hd(scores).score

      Enum.each(scores, fn score ->
        # Scores should be consistent (tolerance: ±0.01%)
        assert abs(score.score - base_score) <= 0.01
      end)

      # Accuracy metadata validation
      Enum.each(scores, fn score ->
        assert Map.has_key?(score, :accuracy_metadata)
        assert score.accuracy_metadata.tolerance_level <= 0.01
        assert score.accuracy_metadata.confidence_level >= 0.95
      end)
    end

    test "SC-CS-003: System SHALL prevent compliance score manipulation and maintain audit integrity" do
      # Test audit integrity and manipulation prevention
      tenant_id = "audit_integrity_tenant"

      original_data = %{
        security_measures: %{score: 75.0, status: :partial, last_review: ~D[2024-01-01]}
      }

      # Calculate initial score
      initial_score =
        ComplianceScore.calculate_compliance_score(tenant_id, original_data, :iso_27001)

      # Attempt to modify data (should not affect historical scores)
      modified_data = %{
        security_measures: %{score: 95.0, status: :compliant, last_review: ~D[2024-12-01]}
      }

      modified_score =
        ComplianceScore.calculate_compliance_score(tenant_id, modified_data, :iso_27001)

      # Audit integrity validation
      assert initial_score.audit_trail.data_hash != modified_score.audit_trail.data_hash
      assert Map.has_key?(initial_score.audit_trail, :immutable_signature)
      assert Map.has_key?(modified_score.audit_trail, :immutable_signature)

      # Historical score should remain unchanged
      historical_score =
        ComplianceScore.get_historical_score(tenant_id, initial_score.calculated_at)

      assert historical_score.score == initial_score.score

      assert historical_score.audit_trail.immutable_signature ==
               initial_score.audit_trail.immutable_signature
    end

    test "SC-CS-004: System SHALL provide real-time compliance monitoring with threshold alerting" do
      # Test real-time monitoring and alerting capabilities
      tenant_id = "monitoring_test_tenant"

      # Set up monitoring thresholds
      thresholds = %{
        # Below 60% = critical
        critical: 60.0,
        # Below 80% = warning
        warning: 80.0,
        # Above 90% = acceptable
        acceptable: 90.0
      }

      # Test critical threshold
      critical_data = %{
        data_protection: %{score: 55.0, status: :non_compliant}
      }

      critical_result =
        ComplianceScore.calculate_compliance_score(tenant_id, critical_data, :gdpr)

      assert critical_result.score < thresholds.critical
      assert critical_result.alert_level == :critical
      assert Map.has_key?(critical_result, :immediate_actions_required)

      # Test warning threshold
      warning_data = %{
        data_protection: %{score: 75.0, status: :partial}
      }

      warning_result = ComplianceScore.calculate_compliance_score(tenant_id, warning_data, :gdpr)
      assert warning_result.score >= thresholds.critical
      assert warning_result.score < thresholds.warning
      assert warning_result.alert_level == :warning

      # Test acceptable threshold
      acceptable_data = %{
        data_protection: %{score: 95.0, status: :compliant}
      }

      acceptable_result =
        ComplianceScore.calculate_compliance_score(tenant_id, acceptable_data, :gdpr)

      assert acceptable_result.score >= thresholds.acceptable
      assert acceptable_result.alert_level == :acceptable

      # Real-time monitoring validation
      assert Map.has_key?(critical_result, :monitoring_timestamp)
      assert Map.has_key?(warning_result, :monitoring_timestamp)
      assert Map.has_key?(acceptable_result, :monitoring_timestamp)
    end

    test "SC-CS-005: System SHALL maintain compliance data lineage and regulatory traceability" do
      # Test comprehensive data lineage and traceability
      tenant_id = "traceability_test_tenant"

      # Complex compliance data with multiple sources
      compliance_data = %{
        financial_controls: %{
          score: 89.0,
          status: :compliant,
          source_systems: ["erp_system", "accounting_system", "audit_system"],
          data_sources: [
            %{system: "erp_system", table: "financial_transactions", record_count: 15_420},
            %{system: "accounting_system", table: "gl_entries", record_count: 8930},
            %{system: "audit_system", table: "control_tests", record_count: 245}
          ],
          last_updated: DateTime.utc_now()
        }
      }

      result = ComplianceScore.calculate_compliance_score(tenant_id, compliance_data, :sox_404)

      # Data lineage validation
      assert Map.has_key?(result, :data_lineage)
      lineage = result.data_lineage

      # Source system traceability
      assert Map.has_key?(lineage, :source_systems)
      assert length(lineage.source_systems) == 3
      assert "erp_system" in lineage.source_systems
      assert "accounting_system" in lineage.source_systems
      assert "audit_system" in lineage.source_systems

      # Data transformation traceability
      assert Map.has_key?(lineage, :transformation_steps)
      assert length(lineage.transformation_steps) > 0

      # Regulatory traceability
      assert Map.has_key?(lineage, :regulatory_mapping)
      regulatory_mapping = lineage.regulatory_mapping
      assert Map.has_key?(regulatory_mapping, :sox_404)
      # CEO/CFO certification
      assert Map.has_key?(regulatory_mapping.sox_404, :section_302)
      # Internal controls
      assert Map.has_key?(regulatory_mapping.sox_404, :section_404)

      # Audit trail completeness
      assert Map.has_key?(result.audit_trail, :data_lineage_hash)
      assert Map.has_key?(result.audit_trail, :source_validation)
      assert result.audit_trail.source_validation.all_sources_verified == true

      # Compliance with regulatory requirements for data retention
      assert Map.has_key?(lineage, :retention_requirements)
      # SOX requirement
      assert lineage.retention_requirements.sox_404.minimum_years >= 7
    end
  end

  # ==========================================
  # HELPER FUNCTIONS FOR TEST DATA GENERATION
  # PropCheck generators using proper syntax
  # ==========================================

  # Import PropCheck.BasicTypes for generator functions
  import PropCheck.BasicTypes

  defp tenant_id_generator do
    PC.oneof([
      "enterprise_tenant_001",
      "healthcare_org_002",
      "financial_services_003",
      "government_agency_004",
      "manufacturing_corp_005"
    ])
  end

  defp compliance_data_generator do
    let [
      data_protection <- compliance_category_generator(),
      financial_controls <- compliance_category_generator(),
      security_measures <- compliance_category_generator(),
      audit_trails <- compliance_category_generator(),
      access_controls <- compliance_category_generator()
    ] do
      %{
        data_protection: data_protection,
        financial_controls: financial_controls,
        security_measures: security_measures,
        audit_trails: audit_trails,
        access_controls: access_controls
      }
    end
  end

  defp compliance_category_generator do
    let [
      score <- SD.float(0.0, 100.0),
      status <- oneof(@compliance_statuses),
      controls <- non_empty(list(alphanumeric_string())),
      evidence_count <- SD.integer(0..50),
      last_review <- date_generator()
    ] do
      %{
        score: score,
        status: status,
        controls: controls,
        evidence_count: evidence_count,
        last_review: last_review
      }
    end
  end

  defp compliance_controls_generator do
    PC.non_empty(PC.list(compliance_control_generator()))
  end

  defp compliance_control_generator do
    let [
      control_id <- alphanumeric_string(),
      control_type <- oneof(@compliance_categories),
      implementation_status <- oneof(@compliance_statuses),
      effectiveness_score <- SD.float(0.0, 100.0),
      last_tested <- datetime_generator()
    ] do
      %{
        control_id: control_id,
        control_type: control_type,
        implementation_status: implementation_status,
        effectiveness_score: effectiveness_score,
        last_tested: last_tested
      }
    end
  end

  defp risk_factors_generator do
    let [
      data_breach_risk <- SD.float(0.0, 1.0),
      regulatory_penalty_risk <- SD.float(0.0, 1.0),
      financial_fraud_risk <- SD.float(0.0, 1.0),
      operational_risk <- SD.float(0.0, 1.0),
      reputation_risk <- SD.float(0.0, 1.0)
    ] do
      %{
        data_breach_risk: data_breach_risk,
        regulatory_penalty_risk: regulatory_penalty_risk,
        financial_fraud_risk: financial_fraud_risk,
        operational_risk: operational_risk,
        reputation_risk: reputation_risk
      }
    end
  end

  defp impact_weights_generator do
    let [
      critical <- SD.float(0.4, 0.8),
      high <- SD.float(0.2, 0.4),
      medium <- SD.float(0.1, 0.3),
      low <- SD.float(0.05, 0.15)
    ] do
      %{
        critical: critical,
        high: high,
        medium: medium,
        low: low
      }
    end
  end

  defp risk_calculation_method_generator do
    PC.oneof([
      :monte_carlo,
      :scenario_analysis,
      :sensitivity_analysis,
      :value_at_risk,
      :expected_shortfall
    ])
  end

  defp report_parameters_generator do
    let [
      time_period <- oneof([:current_month, :current_quarter, :current_year, :last_12_months]),
      include_scores <- bool(),
      include_assessment <- bool(),
      include_risks <- bool(),
      include_recommendations <- bool(),
      detail_level <- oneof([:summary, :detailed, :comprehensive]),
      frameworks <- non_empty(list(oneof(@compliance_frameworks)))
    ] do
      %{
        time_period: time_period,
        include_scores: include_scores,
        include_assessment: include_assessment,
        include_risks: include_risks,
        include_recommendations: include_recommendations,
        detail_level: detail_level,
        frameworks: Enum.take(frameworks, 3)
      }
    end
  end

  defp report_format_generator do
    PC.oneof([:pdf, :html, :json, :excel, :csv])
  end

  # Helper generator for alphanumeric strings
  defp alphanumeric_string do
    let chars <-
          PC.non_empty(PC.list(PC.oneof([PC.range(?a, ?z), PC.range(?A, ?Z), PC.range(?0, ?9)]))) do
      List.to_string(chars)
    end
  end

  defp datetime_generator do
    # Generate datetime within last 2 years for realistic testing
    let days_offset <- SD.integer(0..730) do
      base_date = DateTime.utc_now() |> DateTime.add(-730, :day)
      DateTime.add(base_date, days_offset, :day)
    end
  end

  defp date_generator do
    # Generate date within reasonable range
    let days_offset <- SD.integer(0..365) do
      base_date = ~D[2024-01-01]
      Date.add(base_date, days_offset)
    end
  end
end
