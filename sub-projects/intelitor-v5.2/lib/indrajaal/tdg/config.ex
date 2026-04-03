defmodule TDGConfig do
  @moduledoc """
  Comprehensive TDG (Test-Driven Generation) Configuration

  This configuration ensures ALL AI code generation follows TDG methodology:
  - Test-first __requirements (MANDATORY)
  - Dual property testing integration
  - STAMP safety constraints
  - False positive pr_evention
  - Patient Mode execution support
  """

  # TDG Core Requirements
  @test_first_required true
  @dual_property_testing_required true
  @stamp_constraints_required true
  @false_positive_pr_evention_required true
  @patient_mode_support_required true

  # Validation Thresholds
  @minimum_test_coverage 95.0
  # 100% method agreement __required
  @consensus_threshold 100
  # All constraints must be satisfied
  @stamp_constraint_satisfaction 100

  # Property Testing Configuration
  @propcheck_max_runs 1000
  @exunit_properties_max_runs 1000
  # Patient Mode support
  @property_test_timeout :infinity

  # False Positive Pr_evention (EP-110/EP-111)
  @validation_methods_required 5
  @pattern_coverage_required 100
  @drift_detection_enabled true

  def get_config do
    %{
      core_requirements: %{
        test_first_required: @test_first_required,
        dual_property_testing_required: @dual_property_testing_required,
        stamp_constraints_required: @stamp_constraints_required,
        false_positive_pr_evention_required: @false_positive_pr_evention_required,
        patient_mode_support_required: @patient_mode_support_required
      },
      validation_thresholds: %{
        minimum_test_coverage: @minimum_test_coverage,
        consensus_threshold: @consensus_threshold,
        stamp_constraint_satisfaction: @stamp_constraint_satisfaction
      },
      property_testing: %{
        propcheck_max_runs: @propcheck_max_runs,
        exunit_properties_max_runs: @exunit_properties_max_runs,
        property_test_timeout: @property_test_timeout
      },
      false_positive_pr_evention: %{
        validation_methods_required: @validation_methods_required,
        pattern_coverage_required: @pattern_coverage_required,
        drift_detection_enabled: @drift_detection_enabled
      }
    }
  end

  def validate_tdg_requirements(generation_request) do
    config = get_config()
    violations = []

    # Check test-first __requirement
    violations =
      if config.core_requirements.test_first_required &&
           !Map.get(generation_request, :tests_exist, false) do
        [
          "Test-first __requirement violated: Tests must exist before code generation"
          | violations
        ]
      else
        violations
      end

    # Check dual property testing __requirement
    violations =
      if config.core_requirements.dual_property_testing_required &&
           !Map.get(generation_request, :dual_property_tests, false) do
        [
          "Dual property testing __required: Both PropCheck and ExUnitProperties tests needed"
          | violations
        ]
      else
        violations
      end

    # Check STAMP constraints
    violations =
      if config.core_requirements.stamp_constraints_required &&
           !Map.get(generation_request, :stamp_validated, false) do
        ["STAMP constraint validation __required before generation" | violations]
      else
        violations
      end

    if Enum.empty?(violations) do
      {:ok, :__requirements_satisfied}
    else
      {:error, violations}
    end
  end

  def get_validation_config do
    %{
      pre_generation: [
        :test_existence_check,
        :test_coverage_validation,
        :stamp_constraint_check,
        :property_test_readiness
      ],
      post_generation: [
        :compilation_validation,
        :test_execution_validation,
        :dual_property_test_execution,
        :false_positive_check,
        :stamp_safety_verification
      ],
      continuous: [
        :consensus_monitoring,
        :drift_detection,
        :performance_tracking,
        :compliance_reporting
      ]
    }
  end
end
