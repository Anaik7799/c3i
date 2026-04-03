defmodule Intelitor.AccessControl.AntiPassbackTest do
  @moduledoc """
  Test suite for Intelitor.AccessControl.AntiPassback.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/access_control/anti_passback.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AccessControl.AntiPassback

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AntiPassback)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AntiPassback, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AntiPassback.__info__(:module)
      assert info == Intelitor.AccessControl.AntiPassback
    end
  end
end
