defmodule Indrajaal.ObservabilityDashboardTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ObservabilityDashboard

  test "module exists" do
    assert Code.ensure_loaded?(ObservabilityDashboard)
  end

  test "get_system_health_score/0 is exported" do
    assert function_exported?(ObservabilityDashboard, :get_system_health_score, 0)
  end

  test "start_link/1 is exported" do
    assert function_exported?(ObservabilityDashboard, :start_link, 1)
  end

  test "get_system_health_score/0 returns an integer" do
    result = ObservabilityDashboard.get_system_health_score()
    assert is_integer(result)
    assert result >= 0 and result <= 100
  end
end
