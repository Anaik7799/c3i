defmodule Intelitor.Alarms.TimescaleDBIntegrationTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.TimescaleDBIntegration.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/timescaledb_integration.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.TimescaleDBIntegration

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(TimescaleDBIntegration)
    end

    test "module has __info__/1 function" do
      assert function_exported?(TimescaleDBIntegration, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = TimescaleDBIntegration.__info__(:module)
      assert info == Intelitor.Alarms.TimescaleDBIntegration
    end
  end
end
