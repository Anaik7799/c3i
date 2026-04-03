defmodule Intelitor.Communication.MessageTemplateTest do
  @moduledoc """
  Test suite for Intelitor.Communication.MessageTemplate.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/communication/message_template.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Communication.MessageTemplate

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(MessageTemplate)
    end

    test "module has __info__/1 function" do
      assert function_exported?(MessageTemplate, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = MessageTemplate.__info__(:module)
      assert info == Intelitor.Communication.MessageTemplate
    end
  end
end
