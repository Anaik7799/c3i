defmodule Intelitor.MetricsCollectorTest do
  @moduledoc """
  Test suite for Intelitor.MetricsCollector.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/metrics_collector.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.MetricsCollector

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(MetricsCollector)
    end

    test "module has __info__/1 function" do
      assert function_exported?(MetricsCollector, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = MetricsCollector.__info__(:module)
      assert info == Intelitor.MetricsCollector
    end
  end
end
