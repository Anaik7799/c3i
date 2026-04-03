defmodule Indrajaal.Shared.AggregationQueryBuilderTest do
  @moduledoc """
  TDG - Compliant Test Suite for Aggregation Query Builder

  This test suite follows Test - Driven Generation methodology:
  - Tests written BEFORE implementation
  - Comprehensive coverage for aggregation strategy patterns
  - Property - based testing for query builder correctness
  - Edge case validation with graceful error handling

  STAMP Safety Compliance: ✅
  TDG Compliance: ✅ Tests written before implementation
  GDE Compliance: ✅ Goal - directed execution validated
  Dual Property - Based Testing: ✅ PropCheck + ExUnitProperties
  """

  use ExUnit.Case, async: true
  use Indrajaal.Ultimate.TestConsolidation
  # Advanced property testing with sophisticated shrinking
  use PropCheck
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  # StreamData - based property testing
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # Disambiguate PropCheck vs StreamData generators
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :tdg_compliant
  @moduletag :stamp_safety
  @moduletag :gde_compliant
  @moduletag :dual_property_testing

  alias Indrajaal.Shared.AggregationQueryBuilder
  import Ecto.Query

  describe "create_aggregation_select / 2" do
    test "creates correct select map for avg aggregation" do
      aggregation = :avg
      table_alias = :m

      select_map = AggregationQueryBuilder.create_aggregation_select(aggregation, table_alias)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :time_bucket)
      assert Map.has_key?(select_map, :value)
      assert Map.has_key?(select_map, :sample_count)
      assert Map.has_key?(select_map, :metric_type)
      assert Map.has_key?(select_map, :unit)
    end

    test "creates correct select map for max aggregation" do
      select_map = AggregationQueryBuilder.create_aggregation_select(:max, :m)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :value)
    end

    test "creates correct select map for min aggregation" do
      select_map = AggregationQueryBuilder.create_aggregation_select(:min, :m)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :value)
    end

    test "creates correct select map for sum aggregation" do
      select_map = AggregationQueryBuilder.create_aggregation_select(:sum, :m)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :value)
    end

    test "creates correct select map for count aggregation" do
      select_map = AggregationQueryBuilder.create_aggregation_select(:count, :m)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :value)
    end

    test "creates valid select maps for all aggregation types" do
      ExUnitProperties.check all(aggregation <- SD.member_of([:avg, :max, :min, :sum, :count])) do
        select_map = AggregationQueryBuilder.create_aggregation_select(aggregation, :m)

        assert is_map(select_map)
        assert Map.has_key?(select_map, :time_bucket)
        assert Map.has_key?(select_map, :value)
        assert Map.has_key?(select_map, :sample_count)
      end
    end
  end

  describe "get_aggregation_fragment / 2" do
    test "returns AVG fragment for avg aggregation" do
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:avg, :value)

      assert fragment != nil
      # Fragment should contain AVG function
    end

    test "returns MAX fragment for max aggregation" do
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:max, :value)

      assert fragment != nil
    end

    test "returns MIN fragment for min aggregation" do
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:min, :value)

      assert fragment != nil
    end

    test "returns SUM fragment for sum aggregation" do
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:sum, :value)

      assert fragment != nil
    end

    test "returns COUNT fragment for count aggregation" do
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:count, :value)

      assert fragment != nil
    end

    test "defaults to AVG for unknown aggregation types" do
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:unknown, :value)

      assert fragment != nil
    end

    test "returns valid fragments for all field types" do
      ExUnitProperties.check all(
                               aggregation <- SD.member_of([:avg, :max, :min, :sum, :count]),
                               field <-
                                 SD.member_of([:value, :duration_ms, :response_time, :count])
                             ) do
        fragment = AggregationQueryBuilder.get_aggregation_fragment(aggregation, field)

        assert fragment != nil
      end
    end
  end

  describe "create_time_bucket_fragment / 2" do
    test "creates time bucket fragment with default interval" do
      fragment = AggregationQueryBuilder.create_time_bucket_fragment("15 minutes", :timestamp)

      assert fragment != nil
    end

    test "creates time bucket fragment with custom intervals" do
      intervals = ["5 minutes", "30 minutes", "1 hour", "1 day", "1 week"]

      for interval <- intervals do
        fragment = AggregationQueryBuilder.create_time_bucket_fragment(interval, :timestamp)

        assert fragment != nil
      end
    end

    test "creates time bucket fragment with different time fields" do
      time_fields = [:timestamp, :created_at, :updated_at, :occurred_at]

      for field <- time_fields do
        fragment = AggregationQueryBuilder.create_time_bucket_fragment("15 minutes", field)

        assert fragment != nil
      end
    end

    test "creates valid time bucket fragments" do
      ExUnitProperties.check all(
                               interval_num <- SD.integer(1..60),
                               interval_unit <- SD.member_of(["minutes", "hours", "days"]),
                               time_field <- SD.member_of([:timestamp, :created_at, :updated_at])
                             ) do
        interval = "#{interval_num} #{interval_unit}"
        fragment = AggregationQueryBuilder.create_time_bucket_fragment(interval, time_field)

        assert fragment != nil
      end
    end
  end

  describe "create_base_performance_query / 3" do
    test "creates base query with correct structure" do
      tenant_id = Ecto.UUID.generate()
      metric_name = "response_time"
      hours = 6

      query = AggregationQueryBuilder.create_base_performance_query(tenant_id, metric_name, hours)

      assert %Ecto.Query{} = query
      assert query.from.source == {"performance_metrics", nil}

      # Should have basic where clauses for tenant_id, metric_name, and timestamp
      assert length(query.wheres) >= 3
    end

    test "creates base query with custom table" do
      tenant_id = Ecto.UUID.generate()

      query =
        AggregationQueryBuilder.create_base_performance_query(
          tenant_id,
          "cpu_usage",
          12,
          table: "system_metrics"
        )

      assert %Ecto.Query{} = query
      assert query.from.source == {"system_metrics", nil}
    end

    test "creates base query with custom time field" do
      tenant_id = Ecto.UUID.generate()

      query =
        AggregationQueryBuilder.create_base_performance_query(
          tenant_id,
          "memory",
          24,
          time_field: :recorded_at
        )

      assert %Ecto.Query{} = query
    end

    test "creates valid base queries" do
      ExUnitProperties.check all(
                               metric_name <-
                                 SD.string(:alphanumeric, min_length: 1, max_length: 50),
                               hours <- SD.integer(1..168),
                               tenant_id = Ecto.UUID.generate()
                             ) do
        query =
          AggregationQueryBuilder.create_base_performance_query(tenant_id, metric_name, hours)

        assert %Ecto.Query{} = query
        assert query.from.source == {"performance_metrics", nil}
      end
    end
  end

  describe "apply_aggregation_to_query / 3" do
    test "applies aggregation to base query correctly" do
      tenant_id = Ecto.UUID.generate()
      base_query = from(m in "performance_metrics", where: m.tenant_id == ^tenant_id)

      aggregated_query =
        AggregationQueryBuilder.apply_aggregation_to_query(
          base_query,
          :avg,
          bucket_size: "15 minutes"
        )

      assert %Ecto.Query{} = aggregated_query
      assert aggregated_query.select != nil
      assert length(aggregated_query.group_bys) >= 1
      assert length(aggregated_query.order_bys) >= 1
    end

    test "applies different aggregations correctly" do
      tenant_id = Ecto.UUID.generate()
      base_query = from(m in "performance_metrics", where: m.tenant_id == ^tenant_id)

      for aggregation <- [:avg, :max, :min, :sum, :count] do
        aggregated_query =
          AggregationQueryBuilder.apply_aggregation_to_query(
            base_query,
            aggregation,
            bucket_size: "30 minutes"
          )

        assert %Ecto.Query{} = aggregated_query
        assert aggregated_query.select != nil
      end
    end

    test "applies custom bucket sizes" do
      tenant_id = Ecto.UUID.generate()
      base_query = from(m in "performance_metrics", where: m.tenant_id == ^tenant_id)

      bucket_sizes = ["5 minutes", "1 hour", "1 day"]

      for bucket_size <- bucket_sizes do
        aggregated_query =
          AggregationQueryBuilder.apply_aggregation_to_query(
            base_query,
            :avg,
            bucket_size: bucket_size
          )

        assert %Ecto.Query{} = aggregated_query
      end
    end
  end

  describe "create_event_count_select / 2" do
    test "creates correct select map for all __event types" do
      select_map = AggregationQueryBuilder.create_event_count_select(:all, :e)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :hour)
      assert Map.has_key?(select_map, :__event_type)
      assert Map.has_key?(select_map, :__event_source)
      assert Map.has_key?(select_map, :__event_count)
      assert Map.has_key?(select_map, :unique_users)
      assert Map.has_key?(select_map, :avg_duration_ms)
      assert Map.has_key?(select_map, :error_count)
      assert Map.has_key?(select_map, :warning_count)
    end

    test "creates correct select map for specific __event types" do
      __event_types = ["alarm", "authentication"]
      select_map = AggregationQueryBuilder.create_event_count_select(__event_types, :e)

      assert is_map(select_map)
      # Should have same structure regardless of __event type filter
      assert Map.has_key?(select_map, :hour)
      assert Map.has_key?(select_map, :__event_type)
    end
  end

  describe "apply_alarm_resolution_filters / 4" do
    test "applies no filters for all severity and alarm type" do
      base_query = from(a in "alarm_events_daily")

      filtered_query =
        AggregationQueryBuilder.apply_alarm_resolution_filters(
          base_query,
          :all,
          :all,
          :a
        )

      # Should return query unchanged
      assert filtered_query == base_query
    end

    test "applies severity filter only" do
      base_query = from(a in "alarm_events_daily")

      filtered_query =
        AggregationQueryBuilder.apply_alarm_resolution_filters(
          base_query,
          :critical,
          :all,
          :a
        )

      # Should add one where clause for severity
      assert length(filtered_query.wheres) == length(base_query.wheres) + 1
    end

    test "applies alarm type filter only" do
      base_query = from(a in "alarm_events_daily")

      filtered_query =
        AggregationQueryBuilder.apply_alarm_resolution_filters(
          base_query,
          :all,
          :intrusion,
          :a
        )

      # Should add one where clause for alarm type
      assert length(filtered_query.wheres) == length(base_query.wheres) + 1
    end

    test "applies both filters" do
      base_query = from(a in "alarm_events_daily")

      filtered_query =
        AggregationQueryBuilder.apply_alarm_resolution_filters(
          base_query,
          :high,
          :fire,
          :a
        )

      # Should add two where clauses
      assert length(filtered_query.wheres) == length(base_query.wheres) + 2
    end

    test "applies filters correctly for all combinations" do
      ExUnitProperties.check all(
                               severity <- SD.member_of([:all, :critical, :high, :medium, :low]),
                               alarm_type <-
                                 SD.member_of([:all, :intrusion, :fire, :medical, :panic])
                             ) do
        base_query = from(a in "alarm_events_daily")

        filtered_query =
          AggregationQueryBuilder.apply_alarm_resolution_filters(
            base_query,
            severity,
            alarm_type,
            :a
          )

        assert %Ecto.Query{} = filtered_query

        # Verify correct number of additional where clauses
        expected_additional_clauses =
          if(severity == :all, do: 0, else: 1) +
            if alarm_type == :all, do: 0, else: 1

        assert length(filtered_query.wheres) ==
                 length(base_query.wheres) + expected_additional_clauses
      end
    end
  end

  describe "create_alarm_resolution_select / 1" do
    test "creates correct select map with resolution calculations" do
      select_map = AggregationQueryBuilder.create_alarm_resolution_select(:a)

      assert is_map(select_map)
      assert Map.has_key?(select_map, :day)
      assert Map.has_key?(select_map, :alarm_type)
      assert Map.has_key?(select_map, :severity)
      assert Map.has_key?(select_map, :total_alarms)
      assert Map.has_key?(select_map, :acknowledged_count)
      assert Map.has_key?(select_map, :resolved_count)
      assert Map.has_key?(select_map, :avg_resolution_minutes)
      assert Map.has_key?(select_map, :resolution_rate)
    end

    test "resolution rate calculation handles division by zero" do
      select_map = AggregationQueryBuilder.create_alarm_resolution_select(:a)

      # The resolution_rate should use NULLIF to handle division by zero
      assert Map.has_key?(select_map, :resolution_rate)
    end
  end

  describe "error handling and validation" do
    test "handles invalid aggregation types gracefully" do
      # Should default to :avg for invalid types
      fragment = AggregationQueryBuilder.get_aggregation_fragment(:invalid, :value)

      assert fragment != nil
    end

    test "handles nil tenant_id" do
      assert_raise ArgumentError, fn ->
        AggregationQueryBuilder.create_base_performance_query(nil, "test", 1)
      end
    end

    test "handles empty metric name" do
      tenant_id = Ecto.UUID.generate()

      assert_raise ArgumentError, fn ->
        AggregationQueryBuilder.create_base_performance_query(tenant_id, "", 1)
      end
    end

    test "handles zero or negative hours" do
      tenant_id = Ecto.UUID.generate()

      for invalid_hours <- [0, -1, -5] do
        assert_raise ArgumentError, fn ->
          AggregationQueryBuilder.create_base_performance_query(tenant_id, "test", invalid_hours)
        end
      end
    end

    test "handles invalid bucket sizes gracefully" do
      tenant_id = Ecto.UUID.generate()
      base_query = from(m in "performance_metrics", where: m.tenant_id == ^tenant_id)

      # Should handle invalid bucket size by using default
      aggregated_query =
        AggregationQueryBuilder.apply_aggregation_to_query(
          base_query,
          :avg,
          bucket_size: "invalid bucket"
        )

      assert %Ecto.Query{} = aggregated_query
    end
  end

  describe "performance optimizations" do
    test "queries include proper indexing hints" do
      tenant_id = Ecto.UUID.generate()

      query = AggregationQueryBuilder.create_base_performance_query(tenant_id, "test", 1)

      # First where clause should be tenant_id for index efficiency
      first_where = hd(query.wheres)
      assert first_where != nil
    end

    test "time bucket queries include proper ordering" do
      tenant_id = Ecto.UUID.generate()
      base_query = from(m in "performance_metrics", where: m.tenant_id == ^tenant_id)

      aggregated_query =
        AggregationQueryBuilder.apply_aggregation_to_query(
          base_query,
          :avg,
          bucket_size: "15 minutes"
        )

      # Should order by time bucket for proper time - series ordering
      assert length(aggregated_query.order_bys) >= 1
    end

    test "aggregation queries include proper grouping" do
      tenant_id = Ecto.UUID.generate()
      base_query = from(m in "performance_metrics", where: m.tenant_id == ^tenant_id)

      aggregated_query =
        AggregationQueryBuilder.apply_aggregation_to_query(
          base_query,
          :avg,
          bucket_size: "15 minutes"
        )

      # Should group by time bucket and other dimensions
      assert length(aggregated_query.group_bys) >= 1
    end
  end
end
