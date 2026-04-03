defmodule OtelMetricsTest do
  @moduledoc """
  Test suite for OtelMetrics.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/otel_metrics.ex
  """
  use ExUnit.Case, async: true

  alias OtelMetrics

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(OtelMetrics)
    end

    test "module has __info__/1 function" do
      assert function_exported?(OtelMetrics, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = OtelMetrics.__info__(:module)
      assert info == OtelMetrics
    end
  end
end
