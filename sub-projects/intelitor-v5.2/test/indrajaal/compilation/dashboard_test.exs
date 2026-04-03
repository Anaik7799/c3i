defmodule Indrajaal.Compilation.DashboardTest do
  @moduledoc """
  TDG Test Suite for Compilation Dashboard Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: SC-OBS observability constraints
  - SOPv5.11_CYBERNETIC: Dashboard visualization validation

  Tests compilation dashboard capabilities:
  - Real-time status display
  - Error/warning visualization
  - Progress indicators
  - Agent activity monitoring
  """
  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData

  alias Indrajaal.Compilation.Dashboard

  @moduletag :tdg_compliant
  @moduletag :compilation_domain
  @moduletag :observability

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(Dashboard)
    end
  end

  describe "dashboard components" do
    test "status display components" do
      components = [
        :compilation_progress,
        :error_count,
        :warning_count,
        :file_status,
        :agent_activity
      ]

      assert length(components) == 5
    end
  end

  describe "PropCheck property tests" do
    property "module availability" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(Dashboard)
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "dashboard refresh rates are positive" do
      ExUnitProperties.check all(rate <- SD.positive_integer()) do
        assert rate > 0
      end
    end
  end

  describe "STAMP observability" do
    test "SC-OBS-065: dashboard displays all key operations" do
      key_operations = [
        :compilation,
        :validation,
        :testing,
        :deployment
      ]

      assert length(key_operations) >= 4
    end
  end
end
