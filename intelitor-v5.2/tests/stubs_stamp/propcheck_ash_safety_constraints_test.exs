defmodule Intelitor.Stamp.PropCheckAshSafetyConstraintsTest do
  @moduledoc """
  Comprehensive tests for PropCheck and Ash changeset safety constraints.

  SOPv5.11 Compliance Tests for:
  - SC-PROP-021 to SC-PROP-025: PropCheck generator safety constraints
  - SC-ASH-001 to SC-ASH-010: Ash changeset pattern constraints
  - AOR-PROP-013 to AOR-PROP-016: PropCheck generator agent rules
  - TDG-PROP-016 to TDG-PROP-020: PropCheck generator TDG rules

  Created: 2025-12-10 12:50 CET
  Author: Claude Code (Opus 4.5)
  """

  use ExUnit.Case, async: true

  alias Intelitor.Stamp.PropertyTestingSafetyConstraints
  alias Intelitor.Stamp.AshChangesetSafetyConstraints
  alias Intelitor.AOR.PropertyTestingAgentRules
  alias Intelitor.TDG.PropertyTestingGenerationRules

  # =============================================================================
  # SC-PROP CONSTRAINT TESTS
  # =============================================================================

  describe "SC-PROP-021: Raw utf8() prohibition" do
    test "detects raw utf8() generator usage" do
      violating_code = """
      property "bad example" do
        forall str <- utf8() do
          is_binary(str)
        end
      end
      """

      result =
        PropertyTestingSafetyConstraints.validate_propcheck_generators_content(violating_code)

      assert {:violation, _details} = result
    end

    test "accepts safe let/vector/range pattern" do
      safe_code = """
      defp valid_string_generator do
        let chars <- vector(20, range(?a, ?z)) do
          List.to_string(chars)
        end
      end

      property "good example" do
        forall str <- valid_string_generator() do
          is_binary(str)
        end
      end
      """

      result = PropertyTestingSafetyConstraints.validate_propcheck_generators_content(safe_code)
      # Should not have SC-PROP-021 violation
      case result do
        {:ok, _} ->
          assert true

        {:violation, %{violations: violations}} ->
          refute Enum.any?(violations, fn {id, _, _} -> id == "SC-PROP-021" end)
      end
    end
  end

  describe "SC-PROP-023: such_that utf8() prohibition" do
    test "detects such_that with utf8()" do
      violating_code = """
      property "bad such_that" do
        forall str <- such_that(s <- utf8(), when: String.printable?(s)) do
          is_binary(str)
        end
      end
      """

      result =
        PropertyTestingSafetyConstraints.validate_propcheck_generators_content(violating_code)

      # Check for violation
      case result do
        {:violation, _} -> assert true
        _ -> flunk("Expected violation for such_that(utf8())")
      end
    end
  end

  # =============================================================================
  # SC-ASH CONSTRAINT TESTS
  # =============================================================================

  describe "SC-ASH-001: force_change_attribute in before_action" do
    test "detects change_attribute in before_action" do
      violating_code = """
      create :create do
        accept [:name]
        before_action fn changeset ->
          Ash.Changeset.change_attribute(changeset, :status, :pending)
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_changeset_hooks_content(violating_code)
      assert {:violation, %{constraint: "SC-ASH-001"}} = result
    end

    test "accepts force_change_attribute in before_action" do
      safe_code = """
      create :create do
        accept [:name]
        before_action fn changeset ->
          Ash.Changeset.force_change_attribute(changeset, :status, :pending)
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_changeset_hooks_content(safe_code)
      assert {:ok, :compliant} = result
    end
  end

  describe "SC-ASH-004: require_atomic? false for function changes" do
    test "detects missing require_atomic? false" do
      violating_code = """
      update :process do
        accept [:status]
        change fn changeset, _context ->
          changeset
          |> Ash.Changeset.change_attribute(:processed_at, DateTime.utc_now())
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_atomic_requirement_content(violating_code)
      assert {:violation, %{constraint: "SC-ASH-004"}} = result
    end

    test "accepts require_atomic? false with function changes" do
      safe_code = """
      update :process do
        require_atomic? false
        accept [:status]
        change fn changeset, _context ->
          changeset
          |> Ash.Changeset.change_attribute(:processed_at, DateTime.utc_now())
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_atomic_requirement_content(safe_code)
      assert {:ok, :compliant} = result
    end
  end

  describe "SC-ASH-005: BaseResource code_interface duplicates" do
    test "detects duplicate :list definition with BaseResource" do
      violating_code = """
      defmodule MyApp.MyResource do
        use Intelitor.BaseResource

        code_interface do
          define :list, action: :read
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_code_interface_content(violating_code)
      assert {:violation, %{constraint: "SC-ASH-005"}} = result
    end

    test "accepts custom actions only in code_interface" do
      safe_code = """
      defmodule MyApp.MyResource do
        use Intelitor.BaseResource

        code_interface do
          define :custom_action, action: :my_action
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_code_interface_content(safe_code)
      assert {:ok, :compliant} = result
    end

    test "ignores resources not using BaseResource" do
      code = """
      defmodule MyApp.MyResource do
        use Ash.Resource

        code_interface do
          define :list, action: :read
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_code_interface_content(code)
      assert {:ok, :not_using_base_resource} = result
    end
  end

  describe "SC-ASH-008: opts parameter in plain functions" do
    test "detects Ash API calls without opts parameter" do
      violating_code = """
      def verify_signature(webhook_id, payload, signature) when is_binary(webhook_id) do
        case Ash.get(WebhookEndpoint, webhook_id) do
          {:ok, webhook} -> verify(webhook, payload, signature)
          error -> error
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_authorization_opts_content(violating_code)
      assert {:violation, %{constraint: "SC-ASH-008"}} = result
    end

    test "accepts functions with opts parameter" do
      safe_code = """
      def verify_signature(webhook_id, payload, signature, opts \\\\ []) when is_binary(webhook_id) do
        case Ash.get(WebhookEndpoint, webhook_id, opts) do
          {:ok, webhook} -> verify(webhook, payload, signature)
          error -> error
        end
      end
      """

      result = AshChangesetSafetyConstraints.validate_authorization_opts_content(safe_code)
      assert {:ok, :compliant} = result
    end
  end

  # =============================================================================
  # COMPREHENSIVE RESOURCE VALIDATION TESTS
  # =============================================================================

  describe "comprehensive resource validation" do
    test "validates all constraints for a resource file" do
      resource_code = """
      defmodule MyApp.CleanResource do
        use Intelitor.BaseResource

        code_interface do
          define :custom_action, action: :my_action
        end

        actions do
          create :create do
            accept [:name]
            before_action fn changeset ->
              Ash.Changeset.force_change_attribute(changeset, :status, :pending)
            end
          end

          update :process do
            require_atomic? false
            accept [:status]
            change fn changeset, _context ->
              changeset
            end
          end
        end
      end
      """

      # Create temp file for full validation
      path =
        Path.join(System.tmp_dir!(), "test_resource_#{:erlang.unique_integer([:positive])}.ex")

      File.write!(path, resource_code)

      try do
        result = AshChangesetSafetyConstraints.validate_resource(path)
        # Debug: print violations if any
        if result.status != :compliant do
          IO.puts("Violations found: #{inspect(result.violations)}")
          IO.puts("Checks: #{inspect(result.checks)}")
        end

        assert result.status == :compliant, "Expected compliant, got: #{inspect(result)}"
        assert result.violation_count == 0
      after
        File.rm(path)
      end
    end
  end

  # =============================================================================
  # AOR RULES TESTS
  # =============================================================================

  describe "AOR PropertyTesting rules" do
    test "all_rules returns expected count" do
      rules = PropertyTestingAgentRules.all_rules()
      # Should have at least 16 rules (12 original + 4 new)
      assert map_size(rules) >= 16
    end

    test "propcheck generator rules exist" do
      rules = PropertyTestingAgentRules.all_rules()
      assert Map.has_key?(rules, "AOR-PROP-013")
      assert Map.has_key?(rules, "AOR-PROP-014")
      assert Map.has_key?(rules, "AOR-PROP-015")
      assert Map.has_key?(rules, "AOR-PROP-016")
    end

    test "AOR-PROP-013 prohibits raw utf8()" do
      rules = PropertyTestingAgentRules.all_rules()
      rule = rules["AOR-PROP-013"]
      assert rule.formal == "F(RawUtf8Generator)"
      assert rule.stamp_mapping == "SC-PROP-021"
    end

    test "AOR-PROP-014 requires let/vector/range" do
      rules = PropertyTestingAgentRules.all_rules()
      rule = rules["AOR-PROP-014"]
      assert rule.formal =~ "O("
      assert is_binary(rule.template)
      assert rule.template =~ "let chars"
    end
  end

  # =============================================================================
  # TDG RULES TESTS
  # =============================================================================

  describe "TDG PropertyTesting rules" do
    test "all_rules returns expected count" do
      rules = PropertyTestingGenerationRules.all_rules()
      # Should have at least 20 rules (15 original + 5 new)
      assert map_size(rules) >= 20
    end

    test "propcheck generator rules exist" do
      rules = PropertyTestingGenerationRules.all_rules()
      assert Map.has_key?(rules, "TDG-PROP-016")
      assert Map.has_key?(rules, "TDG-PROP-017")
      assert Map.has_key?(rules, "TDG-PROP-018")
      assert Map.has_key?(rules, "TDG-PROP-019")
      assert Map.has_key?(rules, "TDG-PROP-020")
    end

    test "TDG-PROP-016 requires let/vector/range pattern" do
      rules = PropertyTestingGenerationRules.all_rules()
      rule = rules["TDG-PROP-016"]
      assert rule.severity == :critical
      assert is_list(rule.forbidden_patterns)
    end

    test "TDG-PROP-020 addresses dual-library conflicts" do
      rules = PropertyTestingGenerationRules.all_rules()
      rule = rules["TDG-PROP-020"]
      assert rule.rationale =~ "PropCheck"
      assert rule.rationale =~ "StreamData"
    end

    test "validates PropCheck generators in test content" do
      violating_content = """
      use PropCheck

      property "bad" do
        forall str <- utf8() do
          is_binary(str)
        end
      end
      """

      result =
        PropertyTestingGenerationRules.validate_propcheck_generators_content(violating_content)

      assert {:violation, _} = result
    end

    test "accepts safe PropCheck generator patterns" do
      safe_content = """
      use PropCheck

      defp valid_string_generator do
        let chars <- vector(20, range(?a, ?z)) do
          List.to_string(chars)
        end
      end

      property "good" do
        forall str <- valid_string_generator() do
          is_binary(str)
        end
      end
      """

      result = PropertyTestingGenerationRules.validate_propcheck_generators_content(safe_content)
      assert {:ok, _} = result
    end
  end

  # =============================================================================
  # STAMP CONSTRAINT COUNT TESTS
  # =============================================================================

  describe "STAMP constraint coverage" do
    test "PropertyTestingSafetyConstraints has expected constraint count" do
      constraints = PropertyTestingSafetyConstraints.all_constraints()
      # Should have at least 25 constraints (20 original + 5 new PropCheck)
      assert map_size(constraints) >= 25
    end

    test "AshChangesetSafetyConstraints has 10 constraints" do
      constraints = AshChangesetSafetyConstraints.all_constraints()
      assert map_size(constraints) == 10
    end

    test "all constraint modules are loadable" do
      assert Code.ensure_loaded?(PropertyTestingSafetyConstraints)
      assert Code.ensure_loaded?(AshChangesetSafetyConstraints)
      assert Code.ensure_loaded?(PropertyTestingAgentRules)
      assert Code.ensure_loaded?(PropertyTestingGenerationRules)
    end
  end

  # =============================================================================
  # AUTO-FIX TESTS
  # =============================================================================

  describe "auto-fix functionality" do
    test "auto_fix_before_action fixes change_attribute" do
      violating_code = """
      before_action fn changeset ->
        Ash.Changeset.change_attribute(changeset, :status, :pending)
      end
      """

      path =
        Path.join(System.tmp_dir!(), "test_autofix_#{:erlang.unique_integer([:positive])}.ex")

      File.write!(path, violating_code)

      try do
        {:ok, :fixed, ^path} = AshChangesetSafetyConstraints.auto_fix_before_action(path)

        fixed_content = File.read!(path)
        assert fixed_content =~ "force_change_attribute"

        # Use negative lookbehind to ensure change_attribute is NOT present (except as part of force_change_attribute)
        refute fixed_content =~ ~r/(?<!force_)change_attribute\(/
      after
        File.rm(path)
      end
    end

    test "auto_fix returns no_changes_needed when already correct" do
      correct_code = """
      before_action fn changeset ->
        Ash.Changeset.force_change_attribute(changeset, :status, :pending)
      end
      """

      path =
        Path.join(System.tmp_dir!(), "test_correct_#{:erlang.unique_integer([:positive])}.ex")

      File.write!(path, correct_code)

      try do
        {:ok, :no_changes_needed, ^path} =
          AshChangesetSafetyConstraints.auto_fix_before_action(path)
      after
        File.rm(path)
      end
    end
  end
end
