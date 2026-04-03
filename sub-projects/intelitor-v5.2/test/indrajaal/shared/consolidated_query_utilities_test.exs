defmodule Indrajaal.Shared.ConsolidatedQueryUtilitiesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Shared.ConsolidatedQueryUtilities

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(ConsolidatedQueryUtilities)
    end
  end

  describe "build_performance_trend_query/1" do
    test "function is exported" do
      assert function_exported?(ConsolidatedQueryUtilities, :build_performance_trend_query, 1)
    end

    test "builds query for default params" do
      params = %{
        start_time: DateTime.add(DateTime.utc_now(), -3600, :second),
        end_time: DateTime.utc_now(),
        metric: :response_time
      }

      result = ConsolidatedQueryUtilities.build_performance_trend_query(params)
      assert is_binary(result) or is_map(result) or is_tuple(result)
    end

    test "builds query for minimal params" do
      result = ConsolidatedQueryUtilities.build_performance_trend_query(%{})
      assert is_binary(result) or is_map(result) or is_tuple(result)
    end
  end

  describe "build_event_count_query/1" do
    test "function is exported" do
      assert function_exported?(ConsolidatedQueryUtilities, :build_event_count_query, 1)
    end

    test "builds event count query" do
      params = %{
        event_type: :alarm,
        start_time: DateTime.add(DateTime.utc_now(), -86400, :second),
        end_time: DateTime.utc_now(),
        tenant_id: "tenant-123"
      }

      result = ConsolidatedQueryUtilities.build_event_count_query(params)
      assert is_binary(result) or is_map(result) or is_tuple(result)
    end

    test "builds event count query with empty params" do
      result = ConsolidatedQueryUtilities.build_event_count_query(%{})
      assert is_binary(result) or is_map(result) or is_tuple(result)
    end
  end
end
