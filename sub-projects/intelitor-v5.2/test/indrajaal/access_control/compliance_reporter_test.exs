defmodule Indrajaal.AccessControl.ComplianceReporterTest do
  @moduledoc """
  TDG-compliant test suite for AccessControl.ComplianceReporter.

  Tests cover compliance report generation for all supported frameworks
  (SOX, GDPR, HIPAA, ISO 27001, PCI DSS, NIST), validation logic, scoring,
  and violation analysis. All tests use actual module functions with no mocking.

  ## STAMP Safety Integration
  - SC-SEC-044: Compliance audit trail generation and validation
  - SC-PRAJNA-003: State mutations logged to Immutable Register

  ## Constitutional Verification
  - Ψ₃ Verification: Compliance scores are verifiable against known thresholds
  - Ψ₅ Truthfulness: Reports reflect actual compliance data without distortion

  ## TPS 5-Level RCA Context
  - L1 Symptom: Missing compliance report causes audit failure
  - L5 Root Cause: Unvalidated framework names bypass compliance pipeline

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude Sonnet 4.6 | Sprint 54 W1 TDG generation |
  """

  use ExUnit.Case, async: true

  alias Indrajaal.AccessControl.ComplianceReporter

  @moduletag :zenoh_nif

  @valid_tenant_id "550e8400-e29b-41d4-a716-446655440000"

  # ============================================================
  # get_available_frameworks/0
  # ============================================================

  describe "get_available_frameworks/0" do
    test "returns a map" do
      result = ComplianceReporter.get_available_frameworks()
      assert is_map(result)
    end

    test "contains :sox framework" do
      frameworks = ComplianceReporter.get_available_frameworks()
      assert Map.has_key?(frameworks, :sox)
    end

    test "contains :gdpr framework" do
      frameworks = ComplianceReporter.get_available_frameworks()
      assert Map.has_key?(frameworks, :gdpr)
    end

    test "contains :hipaa framework" do
      frameworks = ComplianceReporter.get_available_frameworks()
      assert Map.has_key?(frameworks, :hipaa)
    end

    test "contains :iso27001 framework" do
      frameworks = ComplianceReporter.get_available_frameworks()
      assert Map.has_key?(frameworks, :iso27001)
    end

    test "contains :pci_dss framework" do
      frameworks = ComplianceReporter.get_available_frameworks()
      assert Map.has_key?(frameworks, :pci_dss)
    end

    test "contains :nist framework" do
      frameworks = ComplianceReporter.get_available_frameworks()
      assert Map.has_key?(frameworks, :nist)
    end

    test "each framework entry has a :name key" do
      frameworks = ComplianceReporter.get_available_frameworks()

      Enum.each(frameworks, fn {_key, config} ->
        assert Map.has_key?(config, :name)
        assert is_binary(config.name)
      end)
    end
  end

  # ============================================================
  # generate_analytics_report/3
  # ============================================================

  describe "generate_analytics_report/3" do
    test "returns {:ok, report} for sox framework" do
      assert {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert is_map(report)
    end

    test "returns {:ok, report} for gdpr framework" do
      assert {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :gdpr)
      assert is_map(report)
    end

    test "returns {:ok, report} for hipaa framework" do
      assert {:ok, report} =
               ComplianceReporter.generate_analytics_report(@valid_tenant_id, :hipaa)

      assert is_map(report)
    end

    test "returns {:ok, report} for iso27001 framework" do
      assert {:ok, report} =
               ComplianceReporter.generate_analytics_report(@valid_tenant_id, :iso27001)

      assert is_map(report)
    end

    test "returns {:ok, report} for nist framework" do
      assert {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :nist)
      assert is_map(report)
    end

    test "returns error for unknown framework" do
      result = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :unknown_framework)
      assert {:error, {:invalidframework, :unknown_framework}} = result
    end

    test "report contains framework key" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert Map.has_key?(report, :framework)
      assert report.framework == :sox
    end

    test "report contains generated_at timestamp" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert %DateTime{} = report.generated_at
    end

    test "report contains compliance_score" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert Map.has_key?(report, :compliance_score)
      score = report.compliance_score
      assert is_number(score)
      assert score >= 0 and score <= 100
    end

    test "report contains findings list" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert is_list(report.findings)
    end

    test "report contains violations list" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert is_list(report.violations)
    end

    test "report contains recommendations list" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert is_list(report.recommendations)
    end

    test "report contains executive_summary string" do
      {:ok, report} = ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox)
      assert is_binary(report.executive_summary)
    end

    test "accepts :json format option (default)" do
      {:ok, report} =
        ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox, %{format: :json})

      assert is_map(report)
    end

    test "accepts :pdf format option" do
      {:ok, result} =
        ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox, %{format: :pdf})

      assert result.format == :pdf
    end

    test "accepts :csv format option" do
      {:ok, result} =
        ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox, %{format: :csv})

      assert result.format == :csv
    end

    test "accepts :xml format option" do
      {:ok, result} =
        ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox, %{format: :xml})

      assert result.format == :xml
    end

    test "returns error for unsupported format" do
      result =
        ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox, %{format: :docx})

      assert {:error, {:unsupportedformat, :docx}} = result
    end

    test "accepts include_recommendations option" do
      {:ok, report} =
        ComplianceReporter.generate_analytics_report(@valid_tenant_id, :sox, %{
          include_recommendations: true
        })

      assert is_map(report)
    end
  end

  # ============================================================
  # get_compliance_score/2
  # ============================================================

  describe "get_compliance_score/2" do
    test "returns {:ok, score_map} for valid framework" do
      assert {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :sox)
      assert is_map(score)
    end

    test "score map contains tenant_id" do
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :sox)
      assert score.tenant_id == @valid_tenant_id
    end

    test "score map contains framework" do
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :sox)
      assert score.framework == :sox
    end

    test "score is numeric in range 0-100" do
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :gdpr)
      assert is_number(score.score)
      assert score.score >= 0 and score.score <= 100
    end

    test "level is a valid compliance atom" do
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :gdpr)
      assert score.level in [:excellent, :good, :acceptable, :needs_improvement, :poor]
    end

    test "last_updated is DateTime" do
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :hipaa)
      assert %DateTime{} = score.last_updated
    end

    test "components map is present" do
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :sox)
      assert is_map(score.components)
    end

    test "returns error for invalid framework" do
      result = ComplianceReporter.get_compliance_score(@valid_tenant_id, :bogus)
      assert {:error, {:invalidframework, :bogus}} = result
    end

    test "score >=95 gives :excellent level" do
      # The module computes score internally — we verify the level mapping is consistent
      # by checking that level is one of the valid atoms
      {:ok, score} = ComplianceReporter.get_compliance_score(@valid_tenant_id, :sox)
      level = score.level
      numeric_score = score.score

      expected_level =
        cond do
          numeric_score >= 95 -> :excellent
          numeric_score >= 85 -> :good
          numeric_score >= 75 -> :acceptable
          numeric_score >= 60 -> :needs_improvement
          true -> :poor
        end

      assert level == expected_level
    end
  end

  # ============================================================
  # analyze_violations/2
  # ============================================================

  describe "analyze_violations/2" do
    test "returns {:ok, analysis} with no opts" do
      assert {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert is_map(analysis)
    end

    test "analysis contains tenant_id" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert analysis.tenant_id == @valid_tenant_id
    end

    test "analysis contains total_violations count" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert is_integer(analysis.total_violations)
      assert analysis.total_violations >= 0
    end

    test "analysis contains violation_categories map" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert is_map(analysis.violation_categories)
    end

    test "analysis contains severity_breakdown" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert is_map(analysis.severity_breakdown)
    end

    test "analysis contains trends map" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert is_map(analysis.trends)
    end

    test "analysis contains recommendations list" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert is_list(analysis.recommendations)
    end

    test "analysis contains generated_at timestamp" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert %DateTime{} = analysis.generated_at
    end

    test "accepts custom time range" do
      time_range = %{
        start_date: Date.add(Date.utc_today(), -7),
        end_date: Date.utc_today()
      }

      assert {:ok, _analysis} =
               ComplianceReporter.analyze_violations(@valid_tenant_id, time_range)
    end

    test "analysis contains analysis_period" do
      {:ok, analysis} = ComplianceReporter.analyze_violations(@valid_tenant_id)
      assert Map.has_key?(analysis, :analysis_period)
      assert Map.has_key?(analysis.analysis_period, :start)
      assert Map.has_key?(analysis.analysis_period, :end)
    end
  end

  # ============================================================
  # generate_comprehensive_report/2
  # ============================================================

  describe "generate_comprehensive_report/2" do
    test "returns {:ok, report} with default frameworks" do
      assert {:ok, report} = ComplianceReporter.generate_comprehensive_report(@valid_tenant_id)
      assert is_map(report)
    end

    test "report contains tenant_id" do
      {:ok, report} = ComplianceReporter.generate_comprehensive_report(@valid_tenant_id)
      assert report.tenant_id == @valid_tenant_id
    end

    test "report contains report_type" do
      {:ok, report} = ComplianceReporter.generate_comprehensive_report(@valid_tenant_id)
      assert report.report_type == "comprehensive_compliance"
    end

    test "report contains generated_at timestamp" do
      {:ok, report} = ComplianceReporter.generate_comprehensive_report(@valid_tenant_id)
      assert %DateTime{} = report.generated_at
    end

    test "report contains individual_reports map" do
      {:ok, report} = ComplianceReporter.generate_comprehensive_report(@valid_tenant_id)
      assert is_map(report.individual_reports)
    end

    test "report contains overall_compliance_score" do
      {:ok, report} = ComplianceReporter.generate_comprehensive_report(@valid_tenant_id)
      assert is_number(report.overall_compliance_score)
    end

    test "accepts custom frameworks list" do
      {:ok, report} =
        ComplianceReporter.generate_comprehensive_report(@valid_tenant_id, %{
          frameworks: [:sox, :gdpr]
        })

      assert Map.has_key?(report.individual_reports, :sox)
      assert Map.has_key?(report.individual_reports, :gdpr)
    end
  end

  # ============================================================
  # schedule_automated_reports/2
  # ============================================================

  describe "schedule_automated_reports/2" do
    test "returns {:ok, schedule} with basic config" do
      config = %{frameworks: [:sox], recipients: ["audit@example.com"]}

      assert {:ok, schedule} =
               ComplianceReporter.schedule_automated_reports(@valid_tenant_id, config)

      assert is_map(schedule)
    end

    test "schedule contains schedule_id" do
      {:ok, schedule} =
        ComplianceReporter.schedule_automated_reports(@valid_tenant_id, %{frameworks: [:sox]})

      assert Map.has_key?(schedule, :schedule_id)
      assert is_binary(schedule.schedule_id)
    end

    test "schedule contains tenant_id" do
      {:ok, schedule} =
        ComplianceReporter.schedule_automated_reports(@valid_tenant_id, %{frameworks: [:sox]})

      assert schedule.tenant_id == @valid_tenant_id
    end

    test "schedule contains status :active" do
      {:ok, schedule} =
        ComplianceReporter.schedule_automated_reports(@valid_tenant_id, %{frameworks: [:gdpr]})

      assert schedule.status == :active
    end

    test "schedule contains next_execution datetime" do
      {:ok, schedule} =
        ComplianceReporter.schedule_automated_reports(@valid_tenant_id, %{frameworks: [:sox]})

      assert %DateTime{} = schedule.next_execution
    end
  end

  # ============================================================
  # validate_report_data/2
  # ============================================================

  describe "validate_report_data/2" do
    test "returns {:ok, :valid} for valid framework" do
      assert {:ok, :valid} = ComplianceReporter.validate_report_data(%{data: "test"}, :sox)
    end

    test "returns {:ok, :valid} for gdpr" do
      assert {:ok, :valid} = ComplianceReporter.validate_report_data(%{}, :gdpr)
    end

    test "returns {:ok, :valid} for hipaa" do
      assert {:ok, :valid} = ComplianceReporter.validate_report_data(%{}, :hipaa)
    end

    test "returns error for unknown framework" do
      result = ComplianceReporter.validate_report_data(%{}, :unknown)
      assert {:error, _errors} = result
    end
  end
end
