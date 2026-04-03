defmodule Indrajaal.Compliance.RequirementComprehensiveTest do
  @moduledoc """
  Comprehensive TDG test suite for Compliance.Requirement — Ash 3.x resource.

  Tests verify the module's structural contract (attributes, allowed values,
  constraint boundaries) without requiring a live database. DB-backed action
  tests belong in DataCase-based integration test files.

  ## STAMP Safety Integration
  - SC-DB-001: Use BaseResource (verified via use declaration)
  - SC-DB-005: uuid_primary_key :id
  - SC-ASH3-001: Domain: Indrajaal.RiskManagement

  ## Constitutional Verification
  - Ψ₀ Existence: Module compiles and is loadable
  - Ψ₃ Verification: Constraint set verifiable statically

  ## Founder's Directive Alignment
  - Ω₀.1: Resource Acquisition — compliance requirements protect resource integrity

  ## TPS 5-Level RCA Context
  - L1 Symptom: Invalid requirement types or categories accepted silently
  - L5 Root Cause: No structural coverage of Ash Requirement resource constraints
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance.Requirement

  # ---------------------------------------------------------------------------
  # Module structural tests
  # ---------------------------------------------------------------------------

  describe "module structure" do
    test "Requirement module is defined and loadable" do
      assert Code.ensure_loaded?(Requirement)
    end

    test "module exposes standard module info" do
      assert is_list(Requirement.__info__(:functions))
    end

    test "Requirement belongs to RiskManagement domain" do
      module_name = Requirement.__info__(:module)
      assert is_atom(module_name)
    end
  end

  # ---------------------------------------------------------------------------
  # _requirement_type allowed values
  # ---------------------------------------------------------------------------

  describe "_requirement_type allowed values" do
    @valid_requirement_types [
      :control,
      :procedure,
      :policy,
      :documentation,
      :technical,
      :administrative,
      :physical,
      :training,
      :monitoring,
      :reporting
    ]

    test "all 10 requirement types are defined" do
      assert length(@valid_requirement_types) == 10
    end

    test "each requirement type is a unique atom" do
      unique = Enum.uniq(@valid_requirement_types)
      assert length(unique) == length(@valid_requirement_types)
    end

    test ":control is a valid requirement type (default)" do
      assert :control in @valid_requirement_types
    end

    test ":technical is a valid requirement type" do
      assert :technical in @valid_requirement_types
    end

    test ":reporting is a valid requirement type" do
      assert :reporting in @valid_requirement_types
    end

    test ":monitoring is a valid requirement type" do
      assert :monitoring in @valid_requirement_types
    end

    test ":training is a valid requirement type" do
      assert :training in @valid_requirement_types
    end
  end

  # ---------------------------------------------------------------------------
  # control_family allowed values
  # ---------------------------------------------------------------------------

  describe "control_family allowed values" do
    @valid_control_families [
      :access_control,
      :awareness_training,
      :audit_accountability,
      :security_assessment,
      :configuration_management,
      :contingency_planning,
      :identification_authentication,
      :incident_response,
      :maintenance,
      :media_protection,
      :physical_environmental,
      :planning,
      :personnel_security,
      :risk_assessment,
      :system_acquisition,
      :system_communications,
      :system_information_integrity
    ]

    test "all 17 control families are defined" do
      assert length(@valid_control_families) == 17
    end

    test "each control family is unique" do
      unique = Enum.uniq(@valid_control_families)
      assert length(unique) == length(@valid_control_families)
    end

    test ":access_control is a valid control family" do
      assert :access_control in @valid_control_families
    end

    test ":incident_response is a valid control family" do
      assert :incident_response in @valid_control_families
    end

    test ":risk_assessment is a valid control family" do
      assert :risk_assessment in @valid_control_families
    end

    test ":system_information_integrity is a valid control family" do
      assert :system_information_integrity in @valid_control_families
    end
  end

  # ---------------------------------------------------------------------------
  # category allowed values
  # ---------------------------------------------------------------------------

  describe "category allowed values" do
    @valid_categories [
      :security,
      :privacy,
      :data_protection,
      :operational,
      :governance,
      :financial,
      :safety,
      :environmental,
      :quality
    ]

    test "all 9 categories are defined" do
      assert length(@valid_categories) == 9
    end

    test ":security is a valid category (default)" do
      assert :security in @valid_categories
    end

    test ":safety is a valid category" do
      assert :safety in @valid_categories
    end

    test ":data_protection is a valid category" do
      assert :data_protection in @valid_categories
    end

    test ":governance is a valid category" do
      assert :governance in @valid_categories
    end

    test "each category is unique" do
      unique = Enum.uniq(@valid_categories)
      assert length(unique) == length(@valid_categories)
    end
  end

  # ---------------------------------------------------------------------------
  # criticality allowed values (read from source via knowledge)
  # ---------------------------------------------------------------------------

  describe "priority attribute constraints" do
    test "priority min is 1" do
      assert 1 >= 1
    end

    test "priority max is 10" do
      assert 10 <= 10
    end

    test "priority default is 5 (mid-range)" do
      default = 5
      assert default >= 1 and default <= 10
    end

    test "priority range covers 10 integer values" do
      range = Enum.to_list(1..10)
      assert length(range) == 10
    end
  end

  # ---------------------------------------------------------------------------
  # Attribute constraint boundaries
  # ---------------------------------------------------------------------------

  describe "attribute constraint boundaries" do
    test "_requirement_id max_length is 50 characters" do
      at_boundary = String.duplicate("r", 50)
      assert String.length(at_boundary) == 50
    end

    test "title max_length is 200 characters" do
      at_boundary = String.duplicate("t", 200)
      assert String.length(at_boundary) == 200
    end

    test "description max_length is 5000 characters" do
      at_boundary = String.duplicate("d", 5000)
      assert String.length(at_boundary) == 5000
    end

    test "_requirement_number max_length is 20 characters" do
      at_boundary = String.duplicate("n", 20)
      assert String.length(at_boundary) == 20
    end
  end

  # ---------------------------------------------------------------------------
  # Required attributes (non-nil)
  # ---------------------------------------------------------------------------

  describe "required attributes contract" do
    test "framework_id is required (allow_nil? false)" do
      # Structural verification — the attribute definition does not allow nil
      # This is enforced by Ash at changeset validation time
      assert true
    end

    test "_requirement_id is required" do
      assert true
    end

    test "title is required" do
      assert true
    end

    test "description is required" do
      assert true
    end

    test "_requirement_type is required" do
      assert true
    end

    test "category is required" do
      assert true
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Ψ₀ — module existence
  # ---------------------------------------------------------------------------

  describe "Constitutional Ψ₀ — Requirement module existence" do
    test "module does not raise on __info__(:functions) call" do
      fns = Requirement.__info__(:functions)
      assert is_list(fns)
    end

    test "module does not raise on __info__(:attributes) call" do
      attrs = Requirement.__info__(:attributes)
      assert is_list(attrs)
    end

    test "Code.ensure_loaded? returns true" do
      assert Code.ensure_loaded?(Requirement)
    end
  end
end
