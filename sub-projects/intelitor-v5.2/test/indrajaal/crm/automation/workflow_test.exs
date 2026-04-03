defmodule Indrajaal.Crm.Automation.WorkflowTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Crm.Automation.Workflow.

  Sprint 54 — 100% module coverage.

  ## STAMP Compliance
  - SC-COV-001: Module coverage
  - SC-AUTO-001 to SC-AUTO-004: Workflow automation
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Crm.Automation.Workflow
  alias Indrajaal.Crm.Automation.Workflow.WorkflowRule
  alias Indrajaal.Crm.Automation.Workflow.Action

  @moduletag :zenoh_nif

  describe "module existence" do
    test "Workflow module is loaded" do
      assert Code.ensure_loaded?(Workflow)
    end

    test "WorkflowRule struct is loaded" do
      assert Code.ensure_loaded?(WorkflowRule)
    end

    test "Action struct is loaded" do
      assert Code.ensure_loaded?(Action)
    end
  end

  describe "public API exports" do
    test "start_link/1" do
      assert function_exported?(Workflow, :start_link, 1)
    end

    test "execute_workflows/2" do
      assert function_exported?(Workflow, :execute_workflows, 2)
    end

    test "get_matching_workflows/2" do
      assert function_exported?(Workflow, :get_matching_workflows, 2)
    end

    test "execute_actions/2" do
      assert function_exported?(Workflow, :execute_actions, 2)
    end
  end

  describe "WorkflowRule struct" do
    test "has required fields with defaults" do
      rule = %WorkflowRule{}
      assert rule.active == true
      assert Map.has_key?(rule, :id)
      assert Map.has_key?(rule, :name)
      assert Map.has_key?(rule, :object_type)
      assert Map.has_key?(rule, :trigger_type)
      assert Map.has_key?(rule, :criteria)
      assert Map.has_key?(rule, :actions)
    end
  end

  describe "Action struct" do
    test "has type and config fields" do
      action = %Action{type: :field_update, config: %{"field" => "status"}}
      assert action.type == :field_update
      assert action.config == %{"field" => "status"}
    end

    test "supports all action types" do
      types = [
        :field_update,
        :email_alert,
        :create_task,
        :invoke_flow,
        :outbound_message,
        :webhook
      ]

      Enum.each(types, fn type ->
        action = %Action{type: type, config: %{}}
        assert action.type == type
      end)
    end
  end

  describe "execute_actions/2" do
    test "returns {:ok, results} for field_update action" do
      actions = [%Action{type: :field_update, config: %{"updates" => %{"status" => "active"}}}]
      record = %{id: "rec-1"}
      assert {:ok, results} = Workflow.execute_actions(record, actions)
      assert length(results) == 1
    end

    test "limits actions to max 10" do
      actions = Enum.map(1..15, fn _ -> %Action{type: :field_update, config: %{}} end)
      record = %{id: "rec-1"}
      assert {:ok, results} = Workflow.execute_actions(record, actions)
      assert length(results) == 10
    end
  end
end
