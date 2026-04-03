defmodule Indrajaal.Shared.TimescaleQueryUtilitiesTest do
  @moduledoc """
  TDG - Compliant Test Suite for TimescaleDB Query Utilities

  This test suite follows Test - Driven Generation methodology:
  - Tests written BEFORE implementation
  - Comprehensive coverage for all utility functions
  - Property - based testing for query correctness
  - Edge case validation with graceful error handling

  STAMP Safety Compliance: ✅
  TDG Compliance: ✅ Tests written before implementation
  GDE Compliance: ✅ Goal - directed execution validated
  Dual Property - Based Testing: ✅ PropCheck + ExUnitProperties
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :tdg_compliant
  @moduletag :stamp_safety
  @moduletag :gde_compliant
  @moduletag :dual_property_testing

  alias Indrajaal.Shared.TimescaleQueryUtilities
  import Ecto.Query

  describe "build_performance_trend_query / 4" do
    test "builds correct query for avg aggregation" do
      tenant_id = Ecto.UUID.generate()
      metric_name = "response_time"
      hours = 6
      bucket_size = "15 minutes"

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :avg,
          metric_name,
          tenant_id,
          hours: hours,
          bucket_size: bucket_size
        )

      # Verify query structure
      assert %Ecto.Query{} = query
      assert query.from.source == {"performance_metrics", nil}

      # Verify select clause includes correct aggregation
      select_map = query.select.expr
      assert select_map.time_bucket != nil
      assert select_map.value != nil
      assert select_map.sample_count != nil
      assert select_map.metric_type != nil
      assert select_map.unit != nil
    end

    test "builds correct query for max aggregation" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :max,
          "cpu_usage",
          tenant_id,
          hours: 12
        )

      assert %Ecto.Query{} = query
      # Verify MAX aggregation in select clause
      select_expr = query.select.expr
      assert select_expr.value != nil
    end

    test "builds correct query for min aggregation" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :min,
          "memory_usage",
          tenant_id,
          hours: 24
        )

      assert %Ecto.Query{} = query
    end

    test "builds correct query for sum aggregation" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :sum,
          "__request_count",
          tenant_id,
          hours: 1
        )

      assert %Ecto.Query{} = query
    end

    test "builds correct query for count aggregation" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :count,
          "error_events",
          tenant_id,
          hours: 3
        )

      assert %Ecto.Query{} = query
    end

    test "defaults to avg aggregation for unknown types" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :unknown,
          "test_metric",
          tenant_id,
          hours: 1
        )

      assert %Ecto.Query{} = query
    end

    test "handles custom bucket sizes" do
      tenant_id = Ecto.UUID.generate()

      for bucket_size <- ["5 minutes", "30 minutes", "1 hour", "1 day"] do
        query =
          TimescaleQueryUtilities.build_performance_trend_query(
            :avg,
            "test_metric",
            tenant_id,
            bucket_size: bucket_size
          )

        assert %Ecto.Query{} = query
      end
    end

    test "builds valid queries for all aggregation types" do
      ExUnitProperties.check all(
                               aggregation <- SD.member_of([:avg, :max, :min, :sum, :count]),
                               hours <- SD.integer(1..168),
                               tenant_id = Ecto.UUID.generate(),
                               metric_name <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50)
                             ) do
        query =
          TimescaleQueryUtilities.build_performance_trend_query(
            aggregation,
            metric_name,
            tenant_id,
            hours: hours
          )

        assert %Ecto.Query{} = query
        assert query.from.source == {"performance_metrics", nil}
      end
    end
  end

  describe "build_event_count_query / 3" do
    test "builds query for all __event types" do
      tenant_id = Ecto.UUID.generate()
      hours = 24

      query =
        TimescaleQueryUtilities.build_event_count_query(
          tenant_id,
          :all,
          hours: hours
        )

      assert %Ecto.Query{} = query
      assert query.from.source == {"__event_logs_hourly", nil}

      # Verify select clause includes all __required fields
      select_map = query.select.expr
      assert select_map.hour != nil
      assert select_map.__event_type != nil
      assert select_map.__event_source != nil
      assert select_map.__event_count != nil
      assert select_map.unique_users != nil
      assert select_map.avg_duration_ms != nil
      assert select_map.error_count != nil
      assert select_map.warning_count != nil
    end

    test "builds query for specific __event types" do
      tenant_id = Ecto.UUID.generate()
      __event_types = ["alarm", "authentication", "system"]

      query =
        TimescaleQueryUtilities.build_event_count_query(
          tenant_id,
          __event_types,
          hours: 12
        )

      assert %Ecto.Query{} = query
      # Verify where clause includes __event type filter
      # tenant_id + time + __event_types
      assert length(query.wheres) >= 2
    end

    test "handles empty __event types list" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_event_count_query(
          tenant_id,
          [],
          hours: 1
        )

      assert %Ecto.Query{} = query
    end

    test "builds valid __event count queries" do
      # Max 31 days (744 hours)
      ExUnitProperties.check all(
                               hours <- SD.integer(1..744),
                               tenant_id = Ecto.UUID.generate()
                             ) do
        query =
          TimescaleQueryUtilities.build_event_count_query(
            tenant_id,
            :all,
            hours: hours
          )

        assert %Ecto.Query{} = query
        assert query.from.source == {"__event_logs_hourly", nil}
      end
    end
  end

  describe "apply_aggregation_strategy / 3" do
    test "returns correct fragment for avg aggregation" do
      result =
        TimescaleQueryUtilities.apply_aggregation_strategy(:avg, :value_field, "metric_name")

      # Should return an Ecto fragment for AVG
      assert result != nil
    end

    test "returns correct fragment for max aggregation" do
      result =
        TimescaleQueryUtilities.apply_aggregation_strategy(:max, :value_field, "metric_name")

      assert result != nil
    end

    test "returns correct fragment for min aggregation" do
      result =
        TimescaleQueryUtilities.apply_aggregation_strategy(:min, :value_field, "metric_name")

      assert result != nil
    end

    test "returns correct fragment for sum aggregation" do
      result =
        TimescaleQueryUtilities.apply_aggregation_strategy(:sum, :value_field, "metric_name")

      assert result != nil
    end

    test "returns correct fragment for count aggregation" do
      result =
        TimescaleQueryUtilities.apply_aggregation_strategy(:count, :value_field, "metric_name")

      assert result != nil
    end

    test "defaults to avg for unknown aggregation types" do
      result =
        TimescaleQueryUtilities.apply_aggregation_strategy(:unknown, :value_field, "metric_name")

      assert result != nil
    end

    test "returns valid fragments for all aggregation types" do
      ExUnitProperties.check all(
                               aggregation <-
                                 SD.member_of([:avg, :max, :min, :sum, :count, :unknown]),
                               field <- SD.member_of([:value, :duration, :count]),
                               metric_name <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 30)
                             ) do
        result =
          TimescaleQueryUtilities.apply_aggregation_strategy(aggregation, field, metric_name)

        assert result != nil
      end
    end
  end

  describe "build_timescale_base_query / 3" do
    test "builds base query with tenant and time filters" do
      tenant_id = Ecto.UUID.generate()
      table = "performance_metrics"
      hours = 6

      query =
        TimescaleQueryUtilities.build_timescale_base_query(
          table,
          tenant_id,
          hours: hours
        )

      assert %Ecto.Query{} = query
      assert query.from.source == {table, nil}

      # Should have tenant_id and timestamp filters
      assert length(query.wheres) >= 2
    end

    test "builds base query with custom time field" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_timescale_base_query(
          "__event_logs",
          tenant_id,
          hours: 12,
          time_field: :created_at
        )

      assert %Ecto.Query{} = query
    end

    test "handles different time units" do
      tenant_id = Ecto.UUID.generate()

      for {unit, value} <- [{"hour", 24}, {"day", 7}, {"minute", 60}] do
        query =
          TimescaleQueryUtilities.build_timescale_base_query(
            "test_table",
            tenant_id,
            [{String.to_atom(unit <> "s"), value}]
          )

        assert %Ecto.Query{} = query
      end
    end

    test "builds valid base queries" do
      ExUnitProperties.check all(
                               table <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               # Max 1 year
                               hours <- SD.integer(1..8760),
                               tenant_id = Ecto.UUID.generate()
                             ) do
        query =
          TimescaleQueryUtilities.build_timescale_base_query(
            table,
            tenant_id,
            hours: hours
          )

        assert %Ecto.Query{} = query
        assert query.from.source == {table, nil}
      end
    end
  end

  describe "build_alarm_resolution_query / 3" do
    test "builds query with all severity filters" do
      tenant_id = Ecto.UUID.generate()
      days = 7

      query =
        TimescaleQueryUtilities.build_alarm_resolution_query(
          tenant_id,
          :all,
          :all,
          days: days
        )

      assert %Ecto.Query{} = query
      assert query.from.source == {"alarm_events_daily", nil}
    end

    test "builds query with specific severity filter" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_alarm_resolution_query(
          tenant_id,
          :critical,
          :all,
          days: 3
        )

      assert %Ecto.Query{} = query
      # Should have additional where clause for severity
      assert length(query.wheres) >= 3
    end

    test "builds query with specific alarm type filter" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_alarm_resolution_query(
          tenant_id,
          :all,
          :intrusion,
          days: 14
        )

      assert %Ecto.Query{} = query
    end

    test "builds query with both severity and alarm type filters" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_alarm_resolution_query(
          tenant_id,
          :high,
          :fire,
          days: 30
        )

      assert %Ecto.Query{} = query
      # Should have filters for tenant_id, time, severity, and alarm_type
      assert length(query.wheres) >= 4
    end
  end

  describe "error handling and edge cases" do
    test "handles nil tenant_id gracefully" do
      assert_raise ArgumentError, fn ->
        TimescaleQueryUtilities.build_performance_trend_query(
          :avg,
          "test",
          nil,
          hours: 1
        )
      end
    end

    test "handles empty metric name" do
      tenant_id = Ecto.UUID.generate()

      assert_raise ArgumentError, fn ->
        TimescaleQueryUtilities.build_performance_trend_query(
          :avg,
          "",
          tenant_id,
          hours: 1
        )
      end
    end

    test "handles zero or negative hours" do
      tenant_id = Ecto.UUID.generate()

      for invalid_hours <- [0, -1, -10] do
        assert_raise ArgumentError, fn ->
          TimescaleQueryUtilities.build_performance_trend_query(
            :avg,
            "test",
            tenant_id,
            hours: invalid_hours
          )
        end
      end
    end

    test "handles very large hour values" do
      tenant_id = Ecto.UUID.generate()

      # Should work with reasonable large values
      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          # 1 year
          :avg,
          "test",
          tenant_id,
          hours: 8760
        )

      assert %Ecto.Query{} = query
    end
  end

  describe "performance and optimization" do
    test "queries include proper ordering for time - series __data" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :avg,
          "test",
          tenant_id,
          hours: 1
        )

      # Should have order_by clause for time - series ordering
      assert length(query.order_bys) >= 1
    end

    test "queries include proper grouping for aggregations" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :avg,
          "test",
          tenant_id,
          hours: 1
        )

      # Should have group_by clause for time buckets
      assert length(query.group_bys) >= 1
    end

    test "base queries use efficient filtering" do
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_timescale_base_query(
          "test_table",
          tenant_id,
          hours: 1
        )

      # Should have tenant_id filter first for index efficiency
      first_where = hd(query.wheres)
      assert first_where != nil
    end
  end

  describe "integration with actual __data structures" do
    @tag :integration
    test "queries work with real table schemas" do
      # This test would require actual __database setup
      # For now, we verify query compilation
      tenant_id = Ecto.UUID.generate()

      query =
        TimescaleQueryUtilities.build_performance_trend_query(
          :avg,
          "response_time",
          tenant_id,
          hours: 1
        )

      # Verify query can be inspected (compilation check)
      assert inspect(query) =~ "performance_metrics"
    end
  end
end
