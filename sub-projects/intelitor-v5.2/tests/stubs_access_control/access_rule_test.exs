defmodule Intelitor.AccessControl.AccessRuleTest do
  @moduledoc """
  Test suite for Intelitor.AccessControl.AccessRule.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/access_control/access_rule.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AccessControl.AccessRule

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AccessRule)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AccessRule, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AccessRule.__info__(:module)
      assert info == Intelitor.AccessControl.AccessRule
    end
  end
end
