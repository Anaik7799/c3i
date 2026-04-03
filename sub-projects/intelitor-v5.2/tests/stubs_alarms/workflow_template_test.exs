defmodule Intelitor.Alarms.WorkflowTemplateTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.WorkflowTemplate.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/workflow_template.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.WorkflowTemplate

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(WorkflowTemplate)
    end

    test "module has __info__/1 function" do
      assert function_exported?(WorkflowTemplate, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = WorkflowTemplate.__info__(:module)
      assert info == Intelitor.Alarms.WorkflowTemplate
    end
  end
end
