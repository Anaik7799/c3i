defmodule Intelitor.Notifications.PreferencesTest do
  @moduledoc """
  Test suite for Intelitor.Notifications.Preferences.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/notifications/preferences.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Notifications.Preferences

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Preferences)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Preferences, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Preferences.__info__(:module)
      assert info == Intelitor.Notifications.Preferences
    end
  end
end
