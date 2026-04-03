defmodule Indrajaal.AnalyticsContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AnalyticsContext

  test "module exists" do
    assert Code.ensure_loaded?(AnalyticsContext)
  end

  test "list_reports/1 is exported" do
    assert function_exported?(AnalyticsContext, :list_reports, 1)
  end

  test "create_report/1 is exported" do
    assert function_exported?(AnalyticsContext, :create_report, 1)
  end
end
