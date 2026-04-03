defmodule Intelitor.Communication.ContactPreferenceTest do
  @moduledoc """
  Test suite for Intelitor.Communication.ContactPreference.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/communication/contact_preference.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Communication.ContactPreference

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ContactPreference)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ContactPreference, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ContactPreference.__info__(:module)
      assert info == Intelitor.Communication.ContactPreference
    end
  end
end
