defmodule Indrajaal.System.ResourceMonitorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.System.ResourceMonitor

  test "module exists" do
    assert Code.ensure_loaded?(ResourceMonitor)
  end

  test "start_link/1 is exported" do
    assert function_exported?(ResourceMonitor, :start_link, 1)
  end

  test "get_metrics/0 is exported" do
    assert function_exported?(ResourceMonitor, :get_metrics, 0)
  end
end
