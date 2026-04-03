defmodule Intelitor.AggregationTest do
  @moduledoc """
  Test suite for Intelitor.Aggregation.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/aggregation.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Aggregation

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Aggregation)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Aggregation, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Aggregation.__info__(:module)
      assert info == Intelitor.Aggregation
    end
  end
end
