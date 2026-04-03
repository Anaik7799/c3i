defmodule OtelMetricsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(OtelMetrics)
  end

  test "record/3 is exported" do
    assert function_exported?(OtelMetrics, :record, 3)
  end

  test "record/3 returns :ok (stub)" do
    assert :ok = OtelMetrics.record(:counter, "test.metric", 1)
  end
end
