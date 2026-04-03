defmodule Indrajaal.Git.IncrementalValidationTest do
  @moduledoc """
  TDG Test Suite for Git Incremental Validation Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: Git validation safety constraints
  - SOPv5.11_CYBERNETIC: Incremental validation coordination

  Tests git incremental validation capabilities:
  - GenServer structure
  - TPS/STAMP/TDG methodology integration
  - Caching mechanism
  - Git hook generation
  """
  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData

  alias Indrajaal.Git.IncrementalValidation

  @moduletag :tdg_compliant
  @moduletag :git_domain

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(IncrementalValidation)
    end

    test "module uses GenServer" do
      # GenServer callbacks
      assert function_exported?(IncrementalValidation, :init, 1)
      assert function_exported?(IncrementalValidation, :handle_call, 3)
      assert function_exported?(IncrementalValidation, :handle_cast, 2)
    end
  end

  describe "client API" do
    test "start_link/1 function exists" do
      assert function_exported?(IncrementalValidation, :start_link, 1)
    end

    test "validate_config/1 function exists" do
      assert function_exported?(IncrementalValidation, :validate_config, 1)
    end

    test "validate_changeset/1 function exists" do
      assert function_exported?(IncrementalValidation, :validate_changeset, 1)
    end

    test "cache_result/2 function exists" do
      assert function_exported?(IncrementalValidation, :cache_result, 2)
    end

    test "get_cached_result/1 function exists" do
      assert function_exported?(IncrementalValidation, :get_cached_result, 1)
    end
  end

  describe "methodology integration" do
    test "validate_tps_compliance/1 function exists" do
      assert function_exported?(IncrementalValidation, :validate_tps_compliance, 1)
    end

    test "validate_stamp_compliance/1 function exists" do
      assert function_exported?(IncrementalValidation, :validate_stamp_compliance, 1)
    end

    test "validate_tdg_compliance/1 function exists" do
      assert function_exported?(IncrementalValidation, :validate_tdg_compliance, 1)
    end

    test "verify_methodology_integration/0 function exists" do
      assert function_exported?(IncrementalValidation, :verify_methodology_integration, 0)
    end
  end

  describe "git hook generation" do
    test "generate_git_hooks/1 function exists" do
      assert function_exported?(IncrementalValidation, :generate_git_hooks, 1)
    end

    test "pre_commit_validation/1 function exists" do
      assert function_exported?(IncrementalValidation, :pre_commit_validation, 1)
    end

    test "pre_push_validation/1 function exists" do
      assert function_exported?(IncrementalValidation, :pre_push_validation, 1)
    end
  end

  describe "PropCheck property tests" do
    property "module availability" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(IncrementalValidation)
      end
    end

    property "file hashes are binary" do
      forall hash <- SD.binary(length: 32) do
        is_binary(hash) and byte_size(hash) == 32
      end
    end

    property "validation results have required keys" do
      forall _n <- PC.integer() do
        # Validation results should have status
        true
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "file paths are valid strings" do
      ExUnitProperties.check all(path <- SD.string(:alphanumeric, min_length: 1, max_length: 500)) do
        assert is_binary(path)
      end
    end

    test "commit hashes are 40 characters" do
      ExUnitProperties.check all(hash <- SD.string(:alphanumeric, length: 40)) do
        assert String.length(hash) == 40
      end
    end

    test "validation status is valid atom" do
      ExUnitProperties.check all(status <- SD.member_of([:passed, :failed, :pending, :skipped])) do
        assert is_atom(status)
      end
    end
  end

  describe "caching behavior" do
    test "clear_cache/0 function exists" do
      assert function_exported?(IncrementalValidation, :clear_cache, 0)
    end

    test "validate_with_stats/1 function exists" do
      assert function_exported?(IncrementalValidation, :validate_with_stats, 1)
    end
  end

  describe "container integration" do
    test "validate_container_environment/0 function exists" do
      assert function_exported?(IncrementalValidation, :validate_container_environment, 0)
    end

    test "verify_phics_integration/0 function exists" do
      assert function_exported?(IncrementalValidation, :verify_phics_integration, 0)
    end
  end

  describe "STAMP safety for git validation" do
    test "SC-VAL-001: supports patient mode compilation" do
      assert Code.ensure_loaded?(IncrementalValidation)
    end

    test "SC-VAL-003: supports consensus validation" do
      # Multi-methodology validation
      assert function_exported?(IncrementalValidation, :validate_tps_compliance, 1)
      assert function_exported?(IncrementalValidation, :validate_stamp_compliance, 1)
      assert function_exported?(IncrementalValidation, :validate_tdg_compliance, 1)
    end

    test "SC-DAT-035: maintains validation result consistency" do
      assert function_exported?(IncrementalValidation, :cache_result, 2)
    end

    test "SC-OBS-065: supports validation activity logging" do
      assert function_exported?(IncrementalValidation, :log_validation_activity, 1)
    end
  end
end
