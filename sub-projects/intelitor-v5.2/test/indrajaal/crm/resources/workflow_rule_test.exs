defmodule Indrajaal.Crm.WorkflowRuleTest do
  @moduledoc """
  TDG tests for Indrajaal.Crm.WorkflowRule Ash resource.
  Tests real business logic in should_trigger?/3 and execute/3.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Crm.WorkflowRule

  describe "WorkflowRule resource schema" do
    test "is a valid Ash resource" do
      assert Code.ensure_loaded?(WorkflowRule)
    end

    test "has expected fields" do
      fields = WorkflowRule.__schema__(:fields)
      assert :id in fields
      assert :name in fields
      assert :object_type in fields
      assert :trigger_type in fields
      assert :criteria in fields
      assert :actions in fields
      assert :active in fields
      assert :order in fields
    end
  end

  describe "should_trigger?/3 - inactive rule" do
    test "returns false for inactive rule" do
      rule = %WorkflowRule{
        active: false,
        trigger_type: :on_create,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_create, %{}) == false
    end
  end

  describe "should_trigger?/3 - trigger matching" do
    test "returns true when trigger matches event" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_create, %{}) == true
    end

    test "returns false when trigger does not match event" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_update, %{}) == false
    end

    test "on_create_or_update triggers on on_create event" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create_or_update,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_create, %{}) == true
    end

    test "on_create_or_update triggers on on_update event" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create_or_update,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_update, %{}) == true
    end

    test "on_delete does not match on_create event" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_delete,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_create, %{}) == false
    end
  end

  describe "should_trigger?/3 - criteria matching" do
    test "returns true when criteria matches record fields (string keys)" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create,
        criteria: %{"status" => :active}
      }

      record = %{status: :active}
      assert WorkflowRule.should_trigger?(rule, :on_create, record) == true
    end

    test "returns false when criteria does not match record fields" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create,
        criteria: %{"status" => :active}
      }

      record = %{status: :inactive}
      assert WorkflowRule.should_trigger?(rule, :on_create, record) == false
    end

    test "returns false for non-existent atom key in criteria" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create,
        criteria: %{"nonexistent_atom_xyz_999" => :active}
      }

      record = %{}
      assert WorkflowRule.should_trigger?(rule, :on_create, record) == false
    end

    test "returns false for non-map record" do
      rule = %WorkflowRule{
        active: true,
        trigger_type: :on_create,
        criteria: %{}
      }

      assert WorkflowRule.should_trigger?(rule, :on_create, "not a map") == false
    end
  end

  describe "execute/3 - field_update action" do
    test "applies field_update action to record" do
      rule = %WorkflowRule{
        actions: [%{"type" => "field_update", "field" => "status", "value" => :active}]
      }

      record = %{status: :inactive}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated.status == :active
    end

    test "applies multiple field_update actions" do
      rule = %WorkflowRule{
        actions: [
          %{"type" => "field_update", "field" => "status", "value" => :active},
          %{"type" => "field_update", "field" => "priority", "value" => :high}
        ]
      }

      record = %{status: :inactive, priority: :low}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated.status == :active
      assert updated.priority == :high
    end

    test "applies field_update with atom type key" do
      rule = %WorkflowRule{
        actions: [%{type: :field_update, field: "status", value: :closed}]
      }

      record = %{status: :open}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated.status == :closed
    end

    test "skips field_update when field is nil" do
      rule = %WorkflowRule{
        actions: [%{"type" => "field_update", "field" => nil, "value" => :active}]
      }

      record = %{status: :inactive}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end
  end

  describe "execute/3 - other action types" do
    test "handles email_alert action without error" do
      rule = %WorkflowRule{
        actions: [%{"type" => "email_alert", "to" => "test@example.com"}]
      }

      record = %{status: :active}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "handles create_task action without error" do
      rule = %WorkflowRule{
        actions: [%{"type" => "create_task", "title" => "Follow up"}]
      }

      record = %{id: "123"}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "handles unknown action type without error" do
      rule = %WorkflowRule{
        actions: [%{"type" => "unknown_action"}]
      }

      record = %{status: :active}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end

    test "handles empty actions list" do
      rule = %WorkflowRule{actions: []}
      record = %{status: :active}
      assert {:ok, updated} = WorkflowRule.execute(rule, record)
      assert updated == record
    end
  end
end
