defmodule Indrajaal.Crm.Automation.WorkflowRuleTest do
  @moduledoc """
  TDG comprehensive test suite for Indrajaal.Crm.WorkflowRule.

  Covers the two public pure functions `should_trigger?/3` and `execute/3`
  which require no database access and are therefore testable in isolation.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation (TDG-ZTEST-001)
  - FPPS Validation: 5-method consensus verification
  - Dual property tests (PropCheck + ExUnitProperties) per Ω₄

  ## STAMP Safety Integration
  - SC-AUTO-001: Max 50 workflow rules per object type
  - SC-AUTO-004: Max 10 actions per workflow rule
  - SC-COV-001: 100% critical-path coverage
  - SC-TDG-001: TDG compliance with dual property tests

  ## Constitutional Verification
  - Ψ₀ Existence: WorkflowRule module survives all test mutations
  - Ψ₁ Regeneration: Pure functions are fully reconstructable from spec
  - Ψ₃ Verification: All returned values are inspectable and deterministic

  ## Founder's Directive Alignment
  - Ω₀.6: Sentience via verified automation logic
  - Ω₄: TDG compliance with dual property tests mandatory

  ## TPS 5-Level RCA Context
  - L1 Symptom: Incorrect trigger decisions break automation workflows
  - L3 Root Cause: Criteria evaluation logic defects in `should_trigger?/3`
  - L5 Root Cause: Wrong field-update semantics in `execute/3` corrupt record state
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Crm.WorkflowRule

  @moduletag :crm
  @moduletag :sprint_54
  @moduletag :zenoh_nif

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  # Build a minimal active rule struct that satisfies should_trigger?/3
  defp active_rule(overrides \\ %{}) do
    Map.merge(
      %{
        active: true,
        trigger_type: :on_create,
        criteria: %{}
      },
      overrides
    )
  end

  # Build a minimal record map
  defp record(fields \\ %{}) do
    Map.merge(%{id: "rec-001", status: :new, priority: :normal}, fields)
  end

  # ---------------------------------------------------------------------------
  # should_trigger?/3 tests
  # ---------------------------------------------------------------------------

  describe "should_trigger?/3" do
    test "returns false when rule is inactive" do
      rule = active_rule(%{active: false, trigger_type: :on_create})
      refute WorkflowRule.should_trigger?(rule, :on_create, record())
    end

    test "returns true for exact trigger type match with no criteria" do
      rule = active_rule(%{trigger_type: :on_create, criteria: %{}})
      assert WorkflowRule.should_trigger?(rule, :on_create, record())
    end

    test "returns true for :on_create_or_update when event is :on_create" do
      rule = active_rule(%{trigger_type: :on_create_or_update, criteria: %{}})
      assert WorkflowRule.should_trigger?(rule, :on_create, record())
    end

    test "returns true for :on_create_or_update when event is :on_update" do
      rule = active_rule(%{trigger_type: :on_create_or_update, criteria: %{}})
      assert WorkflowRule.should_trigger?(rule, :on_update, record())
    end

    test "returns false when trigger type does not match event" do
      rule = active_rule(%{trigger_type: :on_create, criteria: %{}})
      refute WorkflowRule.should_trigger?(rule, :on_update, record())
    end

    test "returns false when trigger is :on_delete and event is :on_create" do
      rule = active_rule(%{trigger_type: :on_delete, criteria: %{}})
      refute WorkflowRule.should_trigger?(rule, :on_create, record())
    end

    test "returns true when all criteria match record fields" do
      rule =
        active_rule(%{
          trigger_type: :on_update,
          criteria: %{"status" => :contacted, "priority" => :high}
        })

      rec = record(%{status: :contacted, priority: :high})
      assert WorkflowRule.should_trigger?(rule, :on_update, rec)
    end

    test "returns false when any criterion does not match" do
      rule =
        active_rule(%{
          trigger_type: :on_update,
          criteria: %{"status" => :contacted}
        })

      rec = record(%{status: :new})
      refute WorkflowRule.should_trigger?(rule, :on_update, rec)
    end

    test "returns false for unknown atom field key via ArgumentError rescue" do
      # "nonexistent_field_xzy" cannot be converted to an existing atom safely
      # — should return false via rescue rather than crashing
      rule =
        active_rule(%{
          trigger_type: :on_create,
          criteria: %{"nonexistent_field_xzy_abc" => "value"}
        })

      # Must not raise; must return false (ArgumentError rescued)
      result = WorkflowRule.should_trigger?(rule, :on_create, record())
      refute result
    end

    test "returns false when rule arg is malformed (catch-all clause)" do
      refute WorkflowRule.should_trigger?(%{}, :on_create, record())
      refute WorkflowRule.should_trigger?(nil, :on_create, record())
    end
  end

  # ---------------------------------------------------------------------------
  # execute/3 tests
  # ---------------------------------------------------------------------------

  describe "execute/3" do
    test "returns {:ok, record} unchanged when no actions" do
      rule = %{actions: []}
      rec = record()
      assert {:ok, ^rec} = WorkflowRule.execute(rule, rec, [])
    end

    test "applies field_update action using string keys" do
      rule = %{
        actions: [
          %{"type" => "field_update", "field" => "status", "value" => :qualified}
        ]
      }

      rec = record(%{status: :new})
      assert {:ok, updated} = WorkflowRule.execute(rule, rec, [])
      assert updated.status == :qualified
    end

    test "applies field_update action using atom keys" do
      rule = %{
        actions: [
          %{type: :field_update, field: :priority, value: :high}
        ]
      }

      rec = record(%{priority: :normal})
      assert {:ok, updated} = WorkflowRule.execute(rule, rec, [])
      assert updated.priority == :high
    end

    test "applies multiple field_update actions sequentially" do
      rule = %{
        actions: [
          %{"type" => "field_update", "field" => "status", "value" => :contacted},
          %{"type" => "field_update", "field" => "priority", "value" => :urgent}
        ]
      }

      rec = record(%{status: :new, priority: :normal})
      assert {:ok, updated} = WorkflowRule.execute(rule, rec, [])
      assert updated.status == :contacted
      assert updated.priority == :urgent
    end

    test "email_alert action does not modify the record" do
      rule = %{
        actions: [
          %{"type" => "email_alert", "recipients" => ["a@b.com"], "template" => "welcome"}
        ]
      }

      rec = record()
      assert {:ok, ^rec} = WorkflowRule.execute(rule, rec, [])
    end

    test "create_task action does not modify the record" do
      rule = %{
        actions: [
          %{"type" => "create_task", "subject" => "Follow up"}
        ]
      }

      rec = record()
      assert {:ok, ^rec} = WorkflowRule.execute(rule, rec, [])
    end

    test "unsupported action type is silently skipped, record unchanged" do
      rule = %{
        actions: [
          %{"type" => "invoke_flow", "flow_name" => "some_flow"}
        ]
      }

      rec = record()
      assert {:ok, ^rec} = WorkflowRule.execute(rule, rec, [])
    end

    test "field_update with missing field key leaves record unchanged" do
      rule = %{
        actions: [
          # No "field" key — should not raise
          %{"type" => "field_update", "value" => "some_value"}
        ]
      }

      rec = record()
      assert {:ok, ^rec} = WorkflowRule.execute(rule, rec, [])
    end

    test "mixed action list applies only field_updates to record" do
      rule = %{
        actions: [
          %{"type" => "email_alert"},
          %{"type" => "field_update", "field" => "status", "value" => :closed},
          %{"type" => "create_task"}
        ]
      }

      rec = record(%{status: :new})
      assert {:ok, updated} = WorkflowRule.execute(rule, rec, [])
      assert updated.status == :closed
    end
  end

  # ---------------------------------------------------------------------------
  # Property tests
  # ---------------------------------------------------------------------------

  # PropCheck property: inactive rules never trigger regardless of event/criteria
  property "inactive rule never triggers for any event" do
    trigger_types = [:on_create, :on_update, :on_create_or_update, :on_delete]
    events = [:on_create, :on_update, :on_delete]

    forall {tt, ev} <-
             {PC.oneof(Enum.map(trigger_types, &PC.exactly/1)),
              PC.oneof(Enum.map(events, &PC.exactly/1))} do
      rule = %{active: false, trigger_type: tt, criteria: %{}}
      WorkflowRule.should_trigger?(rule, ev, %{}) == false
    end
  end

  # ExUnitProperties property: execute/3 always returns {:ok, map} for any list of
  # well-formed field_update actions with string keys pointing to known atoms
  test "execute always returns {:ok, map} for arbitrary field_update actions" do
    ExUnitProperties.check all(
                             values <-
                               SD.list_of(
                                 SD.fixed_map(%{
                                   "type" => SD.constant("field_update"),
                                   "field" => SD.member_of(["status", "priority"]),
                                   "value" =>
                                     SD.member_of([
                                       :new,
                                       :contacted,
                                       :qualified,
                                       :high,
                                       :normal,
                                       :low
                                     ])
                                 }),
                                 max_length: 6
                               )
                           ) do
      rule = %{actions: values}
      result = WorkflowRule.execute(rule, %{status: :new, priority: :normal}, [])
      assert match?({:ok, %{}}, result)
    end
  end
end
