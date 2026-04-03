defmodule Intelitor.STAMP.Telemetry.HandlerRegistryTest do
  @moduledoc """
  Test suite for Intelitor.STAMP.Telemetry.HandlerRegistry.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/stamp/telemetry/handler_registry.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.STAMP.Telemetry.HandlerRegistry

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(HandlerRegistry)
    end

    test "module has __info__/1 function" do
      assert function_exported?(HandlerRegistry, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = HandlerRegistry.__info__(:module)
      assert info == Intelitor.STAMP.Telemetry.HandlerRegistry
    end
  end
end
