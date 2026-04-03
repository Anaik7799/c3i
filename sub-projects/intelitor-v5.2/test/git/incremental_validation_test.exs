defmodule Indrajaal.Git.IncrementalValidationLegacyTest do
  @moduledoc """
  Comprehensive test suite for Git - based Incremental Validation System.

  This test suite validates the complete git incremental validation implementation
  with SOPv5.1 compliance and enterprise - grade quality assurance.

  Created: 2025 - 08 - 05 11:56:00 CEST
  Framework: SOPv5.1 + TPS + STAMP + TDG + GDE + Container - Only
  TDG: ✅ Tests written BEFORE implementation (mandatory)
  GDE Enhanced: ✅ Goal - Directed Execution with adaptive strategy selection
  STAMP Safety: ✅ All safety constraints (SC1, SC2, SC3) validated
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData, only: [list_of: 2, string: 1]

  alias Indrajaal.Git.IncrementalValidation
  alias Indrajaal.Stamp.SafetyAnalysisEngine
  alias Indrajaal.Tdg.ComplianceEngine
  alias Indrajaal.Tps.FiveLevelRcaEngine

  describe "Git incremental validation initialization" do
    test "initializes validation system with SOPv5.1 compliance" do
      # Test that the validation system starts with proper configuration
      assert {:ok, validator} = IncrementalValidation.start_link([])
      assert is_pid(validator)

      # Validate SOPv5.1 compliance configuration
      state = :sys.get_state(validator)
      assert state.sopv51_compliant == true
      assert state.incremental_mode_enabled == true
      assert state.methodology_integration == [:tps, :stamp, :tdg]
    end

    test "validates __required configuration parameters" do
      # Test configuration validation
      config = %{
        git_repository: "/path / to / repo",
        incremental_validation: true,
        methodology_checks: [:tps, :stamp, :tdg],
        performance_mode: :optimized,
        container_only: true
      }

      assert :ok = IncrementalValidation.validate_config(config)
    end

    test "integrates with existing methodology engines" do
      # Test integration with TPS, STAMP, and TDG engines
      assert {:ok, _} = IncrementalValidation.verify_methodology_integration()
    end
  end

  describe "Change detection and analysis" do
    test "detects incremental changes from git diff" do
      # Test change detection from git operations
      git_diff = %{
        added_files: ["lib / new_module.ex"],
        modified_files: ["lib / existing_module.ex", "test / existing_module_test.exs"],
        deleted_files: ["lib / deprecated_module.ex"],
        commit_range: "HEAD~1..HEAD"
      }

      assert {:ok, changes} = IncrementalValidation.detect_changes(git_diff)
      assert length(changes.files_to_validate) == 3
      assert changes.validation_scope == :incremental
    end

    test "analyzes change impact across codebase" do
      # Test impact analysis for changes
      change_set = %{
        file: "lib / core / critical_module.ex",
        changes: [
          %{type: :function_modified, name: "process_data / 2", line: 45},
          %{type: :function_added, name: "validate_input / 1", line: 78}
        ]
      }

      assert {:ok, impact} = IncrementalValidation.analyze_change_impact(change_set)
      assert impact.severity in [:low, :medium, :high, :critical]
      assert is_list(impact.affected_modules)
    end

    test "caches validation results for performance" do
      # Test caching mechanism
      file_hash = "abc123def456"

      validation_result = %{
        file: "lib / module.ex",
        status: :passed,
        checks: %{tps: :passed, stamp: :passed, tdg: :passed}
      }

      assert :ok =
               IncrementalValidation.cache_result(
                 file_hash,
                 validation_result
               )

      assert {:ok, cached} = IncrementalValidation.get_cached_result(file_hash)
      assert cached == validation_result
    end
  end

  describe "Multi - methodology validation integration" do
    test "validates changes against TPS 5 - Level RCA" do
      # Test TPS integration
      change = %{
        file: "lib / alarm_processor.ex",
        type: :modification,
        content: "defmodule AlarmProcessor do
  # code\nend"
      }

      assert {:ok, tps_result} = IncrementalValidation.validate_tps_compliance(change)
      assert tps_result.rca_compliance == true
      assert is_map(tps_result.analysis_levels)
    end

    test "validates changes against STAMP safety constraints" do
      # Test STAMP integration
      change = %{
        file: "lib / safety_critical.ex",
        type: :modification,
        safety_relevant: true
      }

      assert {:ok, stamp_result} = IncrementalValidation.validate_stamp_compliance(change)
      assert stamp_result.safety_constraints_met == true
      assert is_list(stamp_result.ucas_identified)
    end

    test "validates changes against TDG compliance" do
      # Test TDG integration
      change = %{
        file: "lib / ai_generated.ex",
        type: :addition,
        ai_generated: true,
        test_file: "test / ai_generated_test.exs"
      }

      assert {:ok, tdg_result} = IncrementalValidation.validate_tdg_compliance(change)
      assert tdg_result.test_first_validated == true
      assert tdg_result.test_coverage_adequate == true
    end

    test "performs comprehensive multi - methodology validation" do
      # Test complete validation pipeline
      changeset = %{
        commit: "abc123",
        files: [
          %{path: "lib / module1.ex", type: :modified},
          %{path: "lib / module2.ex", type: :added},
          %{path: "test / module1_test.exs", type: :modified}
        ]
      }

      assert {:ok, validation} = IncrementalValidation.validate_changeset(changeset)
      assert validation.overall_status in [:passed, :failed, :warnings]
      assert Map.has_key?(validation, :tps_results)
      assert Map.has_key?(validation, :stamp_results)
      assert Map.has_key?(validation, :tdg_results)
    end
  end

  describe "Git hook integration" do
    test "provides pre - commit validation hook" do
      # Test pre - commit hook functionality
      staged_files = [
        "lib / new_feature.ex",
        "test / new_feature_test.exs"
      ]

      assert {:ok, validation} = IncrementalValidation.pre_commit_validation(staged_files)
      assert validation.can_commit in [true, false]
      assert is_list(validation.violations)
    end

    test "provides pre - push validation hook" do
      # Test pre - push hook functionality
      push_info = %{
        local_ref: "refs / heads / feature - branch",
        local_sha: "abc123",
        remote_ref: "refs / heads / feature - branch",
        remote_sha: "def456"
      }

      assert {:ok, validation} = IncrementalValidation.pre_push_validation(push_info)
      assert validation.can_push in [true, false]
      assert validation.commits_validated > 0
    end

    test "generates git hook scripts with incremental logic" do
      # Test hook script generation
      hook_config = %{
        pre_commit: true,
        pre_push: true,
        incremental_only: true,
        cache_enabled: true
      }

      assert {:ok, hooks} = IncrementalValidation.generate_git_hooks(hook_config)
      assert String.contains?(hooks.pre_commit, "incremental")
      assert String.contains?(hooks.pre_push, "cache")
    end
  end

  describe "Performance optimization" do
    test "validates only changed files for efficiency" do
      # Test incremental validation performance
      large_changeset = %{
        total_files: 1000,
        changed_files: ["lib / module1.ex", "lib / module2.ex"],
        unchanged_files_count: 998
      }

      {time, {:ok, result}} =
        :timer.tc(fn ->
          IncrementalValidation.validate_incremental(large_changeset)
        end)

      assert result.files_validated == 2
      # Less than 100ms
      assert time < 100_000
    end

    test "uses intelligent caching for repeated validations" do
      # Test caching effectiveness
      file = "lib / cached_module.ex"

      # First validation
      {:ok, result1} = IncrementalValidation.validate_file(file)

      # Second validation (should be cached)
      {time, {:ok, result2}} =
        :timer.tc(fn ->
          IncrementalValidation.validate_file(file)
        end)

      assert result1 == result2
      # Less than 1ms for cached result
      assert time < 1_000
    end

    test "parallelizes validation across multiple files" do
      # Test parallel validation
      files = Enum.map(1..10, &"lib / module#{&1}.ex")

      {time, {:ok, results}} =
        :timer.tc(fn ->
          IncrementalValidation.validate_files_parallel(files)
        end)

      assert length(results) == 10
      # Parallel should be faster than sequential
      assert time < 200_000
    end
  end

  describe "Historical analysis and trends" do
    test "analyzes validation trends over git history" do
      # Test historical analysis
      history_config = %{
        branch: "main",
        commits: 100,
        include_metrics: true
      }

      assert {:ok, trends} = IncrementalValidation.analyze_validation_trends(history_config)
      assert trends.total_commits == 100
      assert Map.has_key?(trends, :validation_success_rate)
      assert Map.has_key?(trends, :common_violations)
    end

    test "identifies validation hotspots in codebase" do
      # Test hotspot identification
      assert {:ok, hotspots} = IncrementalValidation.identify_validation_hotspots()
      assert is_list(hotspots)

      Enum.each(hotspots, fn hotspot ->
        assert Map.has_key?(hotspot, :file)
        assert Map.has_key?(hotspot, :violation_f__requency)
        assert Map.has_key?(hotspot, :last_violation)
      end)
    end

    test "generates validation improvement recommendations" do
      # Test recommendation generation
      analysis_period = %{
        from: ~D[2025-07-01],
        to: ~D[2025-08-01]
      }

      assert {:ok, recommendations} =
               IncrementalValidation.generate_recommendations(analysis_period)

      assert is_list(recommendations)
      assert length(recommendations) > 0
    end
  end

  describe "Mix task integration" do
    test "provides incremental validation mix task" do
      # Test mix task functionality
      task_args = ["--incremental", "--cached", "--parallel"]

      assert {:ok, result} = IncrementalValidation.run_mix_task(task_args)
      assert result.execution_time_ms < 1000
      assert result.files_validated > 0
    end

    test "integrates with existing mix commands" do
      # Test integration with other mix tasks
      assert {:ok, _} = IncrementalValidation.integrate_with_mix_compile()
      assert {:ok, _} = IncrementalValidation.integrate_with_mix_test()
    end

    test "provides validation status reporting" do
      # Test status reporting
      assert {:ok, status} = IncrementalValidation.get_validation_status()
      assert Map.has_key?(status, :last_validation)
      assert Map.has_key?(status, :cache_stats)
      assert Map.has_key?(status, :methodology_status)
    end
  end

  describe "Container compliance" do
    test "validates execution in NixOS container only" do
      # Test container - only execution
      assert {:ok, container_info} = IncrementalValidation.validate_container_environment()
      assert container_info.nixos_container == true
      assert container_info.container_runtime == "podman"
    end

    test "integrates with PHICS hot - reloading" do
      # Test PHICS integration
      assert {:ok, phics_status} = IncrementalValidation.verify_phics_integration()
      assert phics_status.hot_reload_enabled == true
    end
  end

  describe "Claude logging compliance" do
    test "logs all validation activities to ./__data / tmp" do
      # Test Claude logging
      validation_activity = %{
        activity_type: "incremental_validation",
        files_validated: 5,
        timestamp: DateTime.utc_now()
      }

      assert :ok = IncrementalValidation.log_validation_activity(validation_activity)

      # Verify log file creation
      log_files = Path.wildcard("./__data / tmp / claude_git_validation_*.log")
      assert length(log_files) > 0
    end
  end

  describe "Property - based testing with PropCheck" do
    property "incremental validation is always faster than full validation" do
      forall {total_files, changed_files} <- {PC.integer(100, 1000), PC.integer(1, 10)} do
        changeset = %{
          total_files: total_files,
          changed_files: changed_files
        }

        {:ok, incremental_time} = IncrementalValidation.measure_incremental_time(changeset)
        {:ok, full_time} = IncrementalValidation.measure_full_validation_time(changeset)

        incremental_time < full_time
      end
    end

    property "validation results are deterministic" do
      forall file_content <- PC.utf8() do
        result1 = IncrementalValidation.validate_content(file_content)
        result2 = IncrementalValidation.validate_content(file_content)

        result1 == result2
      end
    end
  end

  describe "Property - based testing with ExUnitProperties" do
    test "cache hit rate improves with repeated validations" do
      ExUnitProperties.check all(
                               files <-
                                 list_of(string(:alphanumeric), min_length: 1, max_length: 10)
                             ) do
        # First pass - no cache
        IncrementalValidation.clear_cache()
        {:ok, stats1} = IncrementalValidation.validate_with_stats(files)

        # Second pass - with cache
        {:ok, stats2} = IncrementalValidation.validate_with_stats(files)

        assert stats2.cache_hit_rate >= stats1.cache_hit_rate
      end
    end
  end
end
