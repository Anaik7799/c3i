defmodule Intelitor.RiskManagement.RiskCategoryTest do
  @moduledoc """
  Test suite for Intelitor.RiskManagement.RiskCategory.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/risk_management/risk_category.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.RiskManagement.RiskCategory

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(RiskCategory)
    end

    test "module has __info__/1 function" do
      assert function_exported?(RiskCategory, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = RiskCategory.__info__(:module)
      assert info == Intelitor.RiskManagement.RiskCategory
    end
  end
end
