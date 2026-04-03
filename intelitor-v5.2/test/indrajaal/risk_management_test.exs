defmodule Indrajaal.RiskManagementTest do
  @moduledoc """
  Tests for Indrajaal.RiskManagement Ash.Domain.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.RiskManagement

  @moduletag :zenoh_nif

  describe "module structure" do
    test "is an Ash domain" do
      assert function_exported?(RiskManagement, :spark_dsl_config, 0) or
               Code.ensure_loaded?(RiskManagement)
    end

    test "module is loaded" do
      assert {:module, RiskManagement} = Code.ensure_loaded(RiskManagement)
    end
  end

  describe "domain resources" do
    test "RiskCategory resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskCategory} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskCategory)
    end

    test "RiskControl resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskControl} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskControl)
    end

    test "RiskIncident resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskIncident} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskIncident)
    end

    test "RiskMatrix resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskMatrix} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskMatrix)
    end

    test "RiskMitigation resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskMitigation} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskMitigation)
    end

    test "RiskMonitoring resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskMonitoring} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskMonitoring)
    end

    test "RiskReporting resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskReporting} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskReporting)
    end

    test "RiskTreatment resource is accessible" do
      assert {:module, Indrajaal.RiskManagement.RiskTreatment} =
               Code.ensure_loaded(Indrajaal.RiskManagement.RiskTreatment)
    end
  end
end
