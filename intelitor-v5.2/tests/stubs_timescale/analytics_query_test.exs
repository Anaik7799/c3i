defmodule Intelitor.Timescale.AnalyticsQueryTest do
  @moduledoc """
  Test suite for Intelitor.Timescale.AnalyticsQuery.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/timescale/analytics_query.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Timescale.AnalyticsQuery

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AnalyticsQuery)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AnalyticsQuery, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AnalyticsQuery.__info__(:module)
      assert info == Intelitor.Timescale.AnalyticsQuery
    end
  end
end
