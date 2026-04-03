defmodule Indrajaal.Timescale.AnalyticsQueryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Timescale.AnalyticsQuery

  test "module exists" do
    assert Code.ensure_loaded?(AnalyticsQuery)
  end

  test "hourly_event_counts/2 is exported" do
    assert function_exported?(AnalyticsQuery, :hourly_event_counts, 2)
  end

  test "alarm_resolution_times/2 is exported" do
    assert function_exported?(AnalyticsQuery, :alarm_resolution_times, 2)
  end

  test "performance_trend/3 is exported" do
    assert function_exported?(AnalyticsQuery, :performance_trend, 3)
  end

  test "real_time_system_status/1 is exported" do
    assert function_exported?(AnalyticsQuery, :real_time_system_status, 1)
  end
end
