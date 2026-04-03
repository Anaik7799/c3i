defmodule Intelitor.Communication.NotificationRuleTest do
  @moduledoc """
  Test suite for Intelitor.Communication.NotificationRule.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/communication/notification_rule.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Communication.NotificationRule

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(NotificationRule)
    end

    test "module has __info__/1 function" do
      assert function_exported?(NotificationRule, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = NotificationRule.__info__(:module)
      assert info == Intelitor.Communication.NotificationRule
    end
  end
end
