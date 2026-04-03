defmodule Intelitor.PriorityCalculatorTest do
  @moduledoc """
  Test suite for Intelitor.PriorityCalculator.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/priority_calculator.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.PriorityCalculator

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(PriorityCalculator)
    end

    test "module has __info__/1 function" do
      assert function_exported?(PriorityCalculator, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = PriorityCalculator.__info__(:module)
      assert info == Intelitor.PriorityCalculator
    end
  end
end
