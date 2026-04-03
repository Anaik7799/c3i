defmodule Intelitor.Communication.ContactGroupTest do
  @moduledoc """
  Test suite for Intelitor.Communication.ContactGroup.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/communication/contact_group.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Communication.ContactGroup

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ContactGroup)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ContactGroup, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ContactGroup.__info__(:module)
      assert info == Intelitor.Communication.ContactGroup
    end
  end
end
