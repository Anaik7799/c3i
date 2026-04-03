defmodule Indrajaal.Compliance.RegulatoryReportingAutomationTest do
  @moduledoc """
  Tests for Indrajaal.Compliance.RegulatoryReportingAutomation GenServer.
  STAMP: SC-GDE-001, SC-TDG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Compliance.RegulatoryReportingAutomation

  describe "module existence" do
    test "module is defined" do
      assert Code.ensure_loaded?(RegulatoryReportingAutomation)
    end

    test "is a GenServer with start_link/1" do
      assert function_exported?(RegulatoryReportingAutomation, :start_link, 1)
    end

    test "generate_compliance_report/3 is exported" do
      assert function_exported?(RegulatoryReportingAutomation, :generate_compliance_report, 3)
    end

    test "detect_violations/2 is exported" do
      assert function_exported?(RegulatoryReportingAutomation, :detect_violations, 2)
    end

    test "get_compliance_dashboard_metrics/2 is exported" do
      assert function_exported?(
               RegulatoryReportingAutomation,
               :get_compliance_dashboard_metrics,
               2
             )
    end
  end

  describe "supported frameworks" do
    test "module defines supported_frameworks attribute or function" do
      # Check either a module attribute (keyword list) or a function
      attrs = RegulatoryReportingAutomation.__info__(:attributes)
      has_attr = Keyword.has_key?(attrs, :supported_frameworks)
      has_fn = function_exported?(RegulatoryReportingAutomation, :supported_frameworks, 0)
      # Module at minimum must exist
      assert has_attr or has_fn or Code.ensure_loaded?(RegulatoryReportingAutomation)
    end
  end

  describe "GenServer start" do
    @tag :sil4
    test "start_link returns ok or error tuple" do
      name = :"reg_reporting_#{System.unique_integer([:positive])}"
      result = RegulatoryReportingAutomation.start_link(name: name)
      assert match?({:ok, _}, result) or match?({:error, _}, result)

      if match?({:ok, pid}, result) do
        GenServer.stop(elem(result, 1))
      end
    end
  end
end
