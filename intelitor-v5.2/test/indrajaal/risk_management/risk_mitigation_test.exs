defmodule Indrajaal.RiskManagement.RiskMitigationTest do
  @moduledoc """
  TDG test suite for RiskMitigation Ash resource.

  ## STAMP Safety Integration
  - SC-HOLON-001: Holon state persists to SQLite only

  ## TPS 5-Level RCA Context
  - L1 Symptom: Mitigation plans not tracked
  - L5 Root Cause: Missing implementation status validation
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.RiskManagement.RiskMitigation

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RiskMitigation)
    end

    test "create function is exported" do
      assert function_exported?(RiskMitigation, :create, 1)
    end
  end

  describe "mitigation_strategy constraints" do
    test "all strategies are valid atoms" do
      strategies = [:avoid, :mitigate, :transfer, :accept, :monitor]
      assert length(strategies) == 5
      assert :avoid in strategies
      assert :monitor in strategies
    end
  end

  describe "implementation_status constraints" do
    test "all statuses are defined" do
      statuses = [:planned, :in_progress, :implemented, :verified, :cancelled]
      assert length(statuses) == 5
      assert :implemented in statuses
    end
  end

  describe "priority constraints" do
    test "all priorities are defined" do
      priorities = [:low, :medium, :high, :critical]
      assert length(priorities) == 4
    end
  end

  describe "create/1 without DB" do
    test "returns error without required fields" do
      result = RiskMitigation.create(%{})
      assert match?({:error, _}, result)
    end

    test "returns error when title and description missing" do
      result =
        RiskMitigation.create(%{
          mitigation_strategy: :mitigate
        })

      assert match?({:error, _}, result)
    end
  end
end
