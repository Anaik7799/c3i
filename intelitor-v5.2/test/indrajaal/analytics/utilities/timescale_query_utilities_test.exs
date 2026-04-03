defmodule TimescaleQueryUtilitiesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(TimescaleQueryUtilities)
  end

  test "build_event_count_query/3 is exported" do
    assert function_exported?(TimescaleQueryUtilities, :build_event_count_query, 3)
  end

  test "build_alarm_resolution_query/4 is exported" do
    assert function_exported?(TimescaleQueryUtilities, :build_alarm_resolution_query, 4)
  end
end
