defmodule Indrajaal.Performance.SOPv51CyberneticIntegrationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Performance.SOPv51CyberneticIntegration

  test "module exists" do
    assert Code.ensure_loaded?(SOPv51CyberneticIntegration)
  end

  test "start_link/1 is exported" do
    assert function_exported?(SOPv51CyberneticIntegration, :start_link, 1)
  end

  test "get_metrics/0 is exported" do
    assert function_exported?(SOPv51CyberneticIntegration, :get_metrics, 0)
  end

  test "analyze/1 is exported" do
    assert function_exported?(SOPv51CyberneticIntegration, :analyze, 1)
  end
end
