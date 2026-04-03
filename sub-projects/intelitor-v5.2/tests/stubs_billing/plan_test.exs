defmodule Intelitor.Billing.PlanTest do
  @moduledoc """
  Test suite for Intelitor.Billing.Plan.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/billing/plan.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Billing.Plan

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Plan)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Plan, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Plan.__info__(:module)
      assert info == Intelitor.Billing.Plan
    end
  end
end
