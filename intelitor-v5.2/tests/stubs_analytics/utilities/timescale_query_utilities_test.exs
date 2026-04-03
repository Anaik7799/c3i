defmodule TimescaleQueryUtilitiesTest do
  @moduledoc """
  Test suite for TimescaleQueryUtilities.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/analytics/utilities/timescale_query_utilities.ex
  """
  use ExUnit.Case, async: true

  alias TimescaleQueryUtilities

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(TimescaleQueryUtilities)
    end

    test "module has __info__/1 function" do
      assert function_exported?(TimescaleQueryUtilities, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = TimescaleQueryUtilities.__info__(:module)
      assert info == TimescaleQueryUtilities
    end
  end
end
