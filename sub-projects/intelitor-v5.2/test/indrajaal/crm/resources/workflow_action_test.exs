defmodule Indrajaal.Crm.WorkflowRuleActionTest do
  @moduledoc """
  ## TDG Compliance - Sprint 54
  Tests for WorkflowRule action execution and trigger logic.
  Covers the pure functions: should_trigger?/3 and execute/3.

  ## STAMP Compliance
  - SC-TDG: Tests exist before code modification
  - SC-AUTO-001: Max 50 rules per object type
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.WorkflowRule

  describe "module existence" do
    test "WorkflowRule module is loaded" do
      assert Code.ensure_loaded?(WorkflowRule)
    end

    test "module exports pure function should_trigger?" do
      fns = WorkflowRule.__info__(:functions)
      assert Keyword.has_key?(fns, :should_trigger?)
    end

    test "module exports pure function execute" do
      fns = WorkflowRule.__info__(:functions)
      assert Keyword.has_key?(fns, :execute)
    end
  end

  describe "should_trigger?/3" do
    test "returns false for inactive rule" do
      rule = %{active: false, trigger_type: :on_create, criteria: %{}}
      refute WorkflowRule.should_trigger?(rule, :on_create, %{})
    end

    test "matches exact trigger type" do
      rule = %{active: true, trigger_type: :on_create, criteria: %{}}
      assert WorkflowRule.should_trigger?(rule, :on_create, %{})
    end

    test "on_create_or_update matches :on_create event" do
      rule = %{active: true, trigger_type: :on_create_or_update, criteria: %{}}
      assert WorkflowRule.should_trigger?(rule, :on_create, %{})
    end

    test "on_create_or_update matches :on_update event" do
      rule = %{active: true, trigger_type: :on_create_or_update, criteria: %{}}
      assert WorkflowRule.should_trigger?(rule, :on_update, %{})
    end

    test "on_create does not match :on_update event" do
      rule = %{active: true, trigger_type: :on_create, criteria: %{}}
      refute WorkflowRule.should_trigger?(rule, :on_update, %{})
    end

    test "criteria conditions filter records" do
      rule = %{active: true, trigger_type: :on_create, criteria: %{status: :new}}
      assert WorkflowRule.should_trigger?(rule, :on_create, %{status: :new})
      refute WorkflowRule.should_trigger?(rule, :on_create, %{status: :old})
    end

    test "all criteria conditions must match (AND semantics)" do
      rule = %{active: true, trigger_type: :on_create, criteria: %{status: :new, source: :web}}
      assert WorkflowRule.should_trigger?(rule, :on_create, %{status: :new, source: :web})
      refute WorkflowRule.should_trigger?(rule, :on_create, %{status: :new, source: :email})
    end

    test "returns false for nil record" do
      rule = %{active: true, trigger_type: :on_create, criteria: %{}}
      refute WorkflowRule.should_trigger?(rule, :on_create, nil)
    end

    test "returns false for non-map rule" do
      refute WorkflowRule.should_trigger?(nil, :on_create, %{})
    end
  end

  describe "execute/3" do
    test "applies field_update actions" do
      rule = %{
        actions: [
          %{"type" => "field_update", "field" => "status", "value" => :qualified}
        ]
      }

      record = %{status: :new}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated.status == :qualified
    end

    test "applies atom-keyed field_update actions" do
      rule = %{
        actions: [
          %{type: :field_update, field: :priority, value: :high}
        ]
      }

      record = %{priority: :low}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated.priority == :high
    end

    test "email_alert action passes through without modifying record" do
      rule = %{actions: [%{"type" => "email_alert"}]}
      record = %{status: :new}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "create_task action passes through without modifying record" do
      rule = %{actions: [%{"type" => "create_task"}]}
      record = %{status: :new}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "unknown action type passes through without modifying record" do
      rule = %{actions: [%{"type" => "unknown_action"}]}
      record = %{status: :new}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "applies multiple actions in sequence" do
      rule = %{
        actions: [
          %{type: :field_update, field: :status, value: :qualified},
          %{type: :field_update, field: :priority, value: :high}
        ]
      }

      record = %{status: :new, priority: :low}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated.status == :qualified
      assert updated.priority == :high
    end

    test "empty actions list returns record unchanged" do
      rule = %{actions: []}
      record = %{status: :new}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "field_update without field key skips gracefully" do
      rule = %{actions: [%{"type" => "field_update", "value" => :qualified}]}
      record = %{status: :new}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end
  end
end
