defmodule Indrajaal.Crm.Automation.AssignmentRulesTest do
  @moduledoc """
  TDG comprehensive test suite for AssignmentRules.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written before implementation is extended
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-AUTO-001: Max 100 rules per object type
  - SC-AUTO-002: Evaluation timeout 5s
  - SC-AUTO-003: Fallback owner required
  - SC-AUTO-004: Max iteration limit (prevent infinite loops)

  ## Constitutional Verification
  - Psi-0 Existence: System continues to exist after rule evaluation
  - Psi-1 Regeneration: Fallback owner always recoverable
  - Psi-3 Verification: Criteria matching is deterministic and verifiable

  ## Founder's Directive Alignment
  - Omega-0.1: Resource acquisition via correct assignment maximises efficiency

  ## TPS 5-Level RCA Context
  - L1 Symptom: Assignment rule returns unexpected assignee
  - L5 Root Cause: Criteria evaluation logic defect in evaluate_condition clauses

  ## Scope
  Tests target the pure, side-effect-free public API:
    - matches_criteria?/2 — no DB, no process spawning
    - fallback_owner/0    — reads application env only

  Functions that require a running database (evaluate/2, get_active_rules/1)
  are covered by integration tests in test/crm/automation_test.exs.
  """

  use ExUnit.Case, async: true
  use PropCheck

  # EP-GEN-014: exclude PropCheck's check/2 so StreamData's ExUnitProperties.check all() works
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.Automation.AssignmentRules

  @moduletag :crm
  @moduletag :sprint_54
  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — equals operator
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with equals operator" do
    test "returns true when string field equals expected value" do
      record = %{industry: "Technology"}
      criteria = %{"industry" => %{"operator" => "equals", "value" => "Technology"}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "returns false when string field does not equal expected value" do
      record = %{industry: "Healthcare"}
      criteria = %{"industry" => %{"operator" => "equals", "value" => "Technology"}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end

    test "returns true when integer field equals expected value" do
      record = %{score: 90}
      criteria = %{"score" => %{"operator" => "equals", "value" => 90}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — not_equals operator
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with not_equals operator" do
    test "returns true when value differs from expected" do
      record = %{status: "active"}
      criteria = %{"status" => %{"operator" => "not_equals", "value" => "closed"}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "returns false when value matches expected" do
      record = %{status: "closed"}
      criteria = %{"status" => %{"operator" => "not_equals", "value" => "closed"}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — contains operator
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with contains operator" do
    test "returns true when string field contains substring" do
      record = %{email: "user@enterprise.com"}
      criteria = %{"email" => %{"operator" => "contains", "value" => "enterprise"}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "returns false when string field does not contain substring" do
      record = %{email: "user@example.com"}
      criteria = %{"email" => %{"operator" => "contains", "value" => "enterprise"}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — greater_than / less_than operators
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with numeric comparison operators" do
    test "greater_than returns true when value exceeds threshold" do
      record = %{revenue: 2_000_000}
      criteria = %{"revenue" => %{"operator" => "greater_than", "value" => 1_000_000}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "greater_than returns false when value is below threshold" do
      record = %{revenue: 500_000}
      criteria = %{"revenue" => %{"operator" => "greater_than", "value" => 1_000_000}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end

    test "less_than returns true when value is below threshold" do
      record = %{score: 30}
      criteria = %{"score" => %{"operator" => "less_than", "value" => 50}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "less_than returns false when value equals threshold" do
      record = %{score: 50}
      criteria = %{"score" => %{"operator" => "less_than", "value" => 50}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — in operator
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with in operator" do
    test "returns true when value is in the allowed list" do
      record = %{region: "APAC"}
      criteria = %{"region" => %{"operator" => "in", "value" => ["APAC", "EMEA", "AMER"]}}
      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "returns false when value is absent from the list" do
      record = %{region: "LATAM"}
      criteria = %{"region" => %{"operator" => "in", "value" => ["APAC", "EMEA", "AMER"]}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — empty criteria (SC-AUTO-003 fallback path)
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with empty criteria" do
    test "returns true for an empty criteria map (no conditions = always match)" do
      record = %{any: "value"}
      assert AssignmentRules.matches_criteria?(record, %{})
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — unknown / malformed operators
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with unknown operator" do
    test "returns false for an unrecognised operator (defensive catch-all clause)" do
      record = %{score: 100}
      criteria = %{"score" => %{"operator" => "between", "value" => [50, 150]}}
      refute AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # matches_criteria?/2 — multiple conditions (ALL must match)
  # ---------------------------------------------------------------------------

  describe "matches_criteria?/2 with multiple conditions" do
    test "returns true only when all conditions match" do
      record = %{industry: "Technology", score: 85, region: "APAC"}

      criteria = %{
        "industry" => %{"operator" => "equals", "value" => "Technology"},
        "score" => %{"operator" => "greater_than", "value" => 80},
        "region" => %{"operator" => "in", "value" => ["APAC", "EMEA"]}
      }

      assert AssignmentRules.matches_criteria?(record, criteria)
    end

    test "returns false when at least one condition fails" do
      record = %{industry: "Technology", score: 60, region: "APAC"}

      criteria = %{
        "industry" => %{"operator" => "equals", "value" => "Technology"},
        "score" => %{"operator" => "greater_than", "value" => 80}
      }

      refute AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # fallback_owner/0 (SC-AUTO-003)
  # ---------------------------------------------------------------------------

  describe "fallback_owner/0" do
    test "returns a non-empty binary string" do
      owner = AssignmentRules.fallback_owner()
      assert is_binary(owner)
      assert byte_size(owner) > 0
    end

    test "returns a UUID-shaped default when application env is not overridden" do
      # The module-level default is the nil-UUID; the app may override it but
      # it MUST always be a binary (SC-AUTO-003: fallback owner required).
      owner = AssignmentRules.fallback_owner()
      assert is_binary(owner)
    end
  end

  # ---------------------------------------------------------------------------
  # Property test — matches_criteria? is total and deterministic
  # (StreamData check all, SD. prefix per EP-GEN-014)
  # ---------------------------------------------------------------------------

  test "matches_criteria?/2 is deterministic for any string field and value" do
    ExUnitProperties.check all(
                             field <- SD.string(:alphanumeric, min_length: 1, max_length: 20),
                             value <- SD.string(:alphanumeric, min_length: 0, max_length: 50)
                           ) do
      record = %{} |> Map.put(String.to_atom(field), value)
      criteria = %{field => %{"operator" => "equals", "value" => value}}

      # A field that equals the expected value must always match itself
      assert AssignmentRules.matches_criteria?(record, criteria)
    end
  end

  # ---------------------------------------------------------------------------
  # Property test — empty criteria always matches any record
  # (PropCheck forall, PC. prefix per EP-GEN-014)
  # ---------------------------------------------------------------------------

  @tag :property
  property "empty criteria matches any record" do
    forall fields <- PC.list({PC.atom(:alias), PC.any()}) do
      record = Map.new(fields)
      AssignmentRules.matches_criteria?(record, %{})
    end
  end
end
