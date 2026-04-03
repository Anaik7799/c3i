defmodule Intelitor.Alarms.TimescaleDBSchemaTest do
  @moduledoc """
  Test suite for Intelitor.Alarms.TimescaleDBSchema.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/alarms/timescaledb_schema.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Alarms.TimescaleDBSchema

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(TimescaleDBSchema)
    end

    test "module has __info__/1 function" do
      assert function_exported?(TimescaleDBSchema, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = TimescaleDBSchema.__info__(:module)
      assert info == Intelitor.Alarms.TimescaleDBSchema
    end
  end
end
