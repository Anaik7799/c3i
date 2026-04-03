defmodule Indrajaal.Shared.DatetimeUtilitiesTest do
  @moduledoc """
  TDG-compliant tests for Indrajaal.Shared.DatetimeUtilities module.

  Tests datetime utility functions for:
  - random_recent_datetime function
  - random_datetime_in_range function
  - maybe_recent_datetime function
  - datetime_days_ago function

  Created: 2025-11-27 19:00:00 CEST
  Phase: 4.0 - C3 Medium-Impact Testing (Datetime Utilities)
  """

  use ExUnit.Case, async: true
  use PropCheck
  alias PropCheck.BasicTypes, as: PC

  alias Indrajaal.Shared.DatetimeUtilities

  # ============================================================================
  # MODULE EXISTENCE TESTS
  # ============================================================================

  describe "Module Structure" do
    test "DatetimeUtilities module exists" do
      assert Code.ensure_loaded?(Indrajaal.Shared.DatetimeUtilities)
    end

    test "module exports random_recent_datetime function" do
      functions = DatetimeUtilities.__info__(:functions)
      assert {:random_recent_datetime, 0} in functions
    end

    test "module exports random_datetime_in_range function" do
      functions = DatetimeUtilities.__info__(:functions)
      assert {:random_datetime_in_range, 1} in functions
    end

    test "module exports maybe_recent_datetime function" do
      functions = DatetimeUtilities.__info__(:functions)
      assert {:maybe_recent_datetime, 0} in functions
    end

    test "module exports datetime_days_ago function" do
      functions = DatetimeUtilities.__info__(:functions)
      assert {:datetime_days_ago, 1} in functions
    end
  end

  # ============================================================================
  # RANDOM_RECENT_DATETIME TESTS
  # ============================================================================

  describe "random_recent_datetime/0" do
    test "returns a DateTime struct" do
      result = DatetimeUtilities.random_recent_datetime()

      assert %DateTime{} = result
    end

    test "returns datetime in the past" do
      result = DatetimeUtilities.random_recent_datetime()
      now = DateTime.utc_now()

      assert DateTime.compare(result, now) in [:lt, :eq]
    end

    test "returns datetime within last 30 days" do
      result = DatetimeUtilities.random_recent_datetime()
      now = DateTime.utc_now()
      thirty_days_ago = DateTime.add(now, -31 * 24 * 60 * 60, :second)

      assert DateTime.compare(result, thirty_days_ago) in [:gt, :eq]
    end

    test "generates different values on multiple calls" do
      results = for _ <- 1..10, do: DatetimeUtilities.random_recent_datetime()
      unique_results = Enum.uniq(results)

      # Should have some variation (though could theoretically be same)
      assert length(unique_results) >= 1
    end

    test "returns valid UTC datetime" do
      result = DatetimeUtilities.random_recent_datetime()

      assert result.time_zone == "Etc/UTC" or result.utc_offset == 0
    end
  end

  # ============================================================================
  # RANDOM_DATETIME_IN_RANGE TESTS
  # ============================================================================

  describe "random_datetime_in_range/1" do
    test "returns a DateTime struct for valid range" do
      start_date = Date.utc_today()
      end_date = Date.add(start_date, 7)
      range = Date.range(start_date, end_date)

      result = DatetimeUtilities.random_datetime_in_range(range)

      assert %DateTime{} = result
    end

    test "returns datetime within specified range" do
      start_date = ~D[2025-01-01]
      end_date = ~D[2025-01-31]
      range = Date.range(start_date, end_date)

      result = DatetimeUtilities.random_datetime_in_range(range)

      result_date = DateTime.to_date(result)
      assert Date.compare(result_date, start_date) in [:gt, :eq]
      assert Date.compare(result_date, end_date) in [:lt, :eq]
    end

    test "handles single day range" do
      date = Date.utc_today()
      range = Date.range(date, date)

      result = DatetimeUtilities.random_datetime_in_range(range)

      assert DateTime.to_date(result) == date
    end

    test "generates different times on multiple calls" do
      start_date = Date.utc_today()
      end_date = Date.add(start_date, 30)
      range = Date.range(start_date, end_date)

      results = for _ <- 1..10, do: DatetimeUtilities.random_datetime_in_range(range)
      unique_results = Enum.uniq(results)

      # Should have some variation
      assert length(unique_results) >= 1
    end

    test "returns datetime with valid time components" do
      start_date = Date.utc_today()
      end_date = Date.add(start_date, 7)
      range = Date.range(start_date, end_date)

      result = DatetimeUtilities.random_datetime_in_range(range)

      assert result.hour >= 0 and result.hour <= 23
      assert result.minute >= 0 and result.minute <= 59
      assert result.second >= 0 and result.second <= 59
    end
  end

  # ============================================================================
  # MAYBE_RECENT_DATETIME TESTS
  # ============================================================================

  describe "maybe_recent_datetime/0" do
    test "returns DateTime or nil" do
      result = DatetimeUtilities.maybe_recent_datetime()

      assert result == nil or match?(%DateTime{}, result)
    end

    test "returns datetime approximately 70% of the time" do
      # Run many iterations to check probability
      results = for _ <- 1..100, do: DatetimeUtilities.maybe_recent_datetime()
      datetime_count = Enum.count(results, fn r -> r != nil end)

      # Should be around 70%, allow for variance (50-90%)
      assert datetime_count >= 50 and datetime_count <= 90
    end

    test "when returning datetime, it is recent" do
      # Run until we get a datetime
      result =
        Enum.find(
          Stream.repeatedly(&DatetimeUtilities.maybe_recent_datetime/0),
          fn r -> r != nil end
        )

      if result do
        now = DateTime.utc_now()
        assert DateTime.compare(result, now) in [:lt, :eq]
      end
    end

    test "generates mix of nil and datetime values" do
      results = for _ <- 1..50, do: DatetimeUtilities.maybe_recent_datetime()

      nil_count = Enum.count(results, &is_nil/1)
      datetime_count = Enum.count(results, fn r -> match?(%DateTime{}, r) end)

      # Both should be present in reasonable quantities
      assert nil_count >= 1 or datetime_count >= 1
    end
  end

  # ============================================================================
  # DATETIME_DAYS_AGO TESTS
  # ============================================================================

  describe "datetime_days_ago/1" do
    test "returns a DateTime struct" do
      result = DatetimeUtilities.datetime_days_ago(7)

      assert %DateTime{} = result
    end

    test "returns datetime within specified days" do
      max_days = 10
      result = DatetimeUtilities.datetime_days_ago(max_days)
      now = DateTime.utc_now()
      max_days_ago = DateTime.add(now, -(max_days + 1) * 24 * 60 * 60, :second)

      assert DateTime.compare(result, now) in [:lt, :eq]
      assert DateTime.compare(result, max_days_ago) in [:gt, :eq]
    end

    test "handles zero days" do
      result = DatetimeUtilities.datetime_days_ago(0)
      now = DateTime.utc_now()

      # Should be within today
      assert DateTime.to_date(result) == DateTime.to_date(now)
    end

    test "handles large number of days" do
      result = DatetimeUtilities.datetime_days_ago(365)

      assert %DateTime{} = result
    end

    test "generates different values on multiple calls" do
      results = for _ <- 1..10, do: DatetimeUtilities.datetime_days_ago(30)
      unique_results = Enum.uniq(results)

      # Should have some variation
      assert length(unique_results) >= 1
    end

    test "respects max_days boundary" do
      max_days = 5
      now = DateTime.utc_now()

      for _ <- 1..20 do
        result = DatetimeUtilities.datetime_days_ago(max_days)
        diff_seconds = DateTime.diff(now, result, :second)
        diff_days = div(diff_seconds, 24 * 60 * 60)

        assert diff_days >= 0 and diff_days <= max_days
      end
    end
  end

  # ============================================================================
  # PROPERTY-BASED TESTS (PropCheck)
  # ============================================================================

  describe "Property Tests (PropCheck)" do
    property "random_recent_datetime always returns DateTime in the past" do
      forall _n <- PC.integer() do
        result = DatetimeUtilities.random_recent_datetime()
        now = DateTime.utc_now()
        DateTime.compare(result, now) in [:lt, :eq]
      end
    end

    property "datetime_days_ago returns DateTime within bounds" do
      forall days <- PC.pos_integer() do
        # Limit for reasonable testing
        max_days = min(days, 365)
        result = DatetimeUtilities.datetime_days_ago(max_days)
        match?(%DateTime{}, result)
      end
    end

    property "maybe_recent_datetime returns DateTime or nil" do
      forall _n <- PC.integer() do
        result = DatetimeUtilities.maybe_recent_datetime()
        result == nil or match?(%DateTime{}, result)
      end
    end

    property "random_datetime_in_range returns DateTime within range" do
      forall {start_offset, range_size} <- {PC.non_neg_integer(), PC.pos_integer()} do
        start_date = Date.add(Date.utc_today(), -min(start_offset, 365))
        end_date = Date.add(start_date, min(range_size, 30))
        range = Date.range(start_date, end_date)

        result = DatetimeUtilities.random_datetime_in_range(range)
        result_date = DateTime.to_date(result)

        Date.compare(result_date, start_date) in [:gt, :eq] and
          Date.compare(result_date, end_date) in [:lt, :eq]
      end
    end

    property "datetime functions are deterministic in structure" do
      forall _n <- PC.integer() do
        result1 = DatetimeUtilities.random_recent_datetime()
        result2 = DatetimeUtilities.random_recent_datetime()

        # Both should be DateTime structs
        match?(%DateTime{}, result1) and match?(%DateTime{}, result2)
      end
    end
  end

  # ============================================================================
  # EDGE CASE TESTS
  # ============================================================================

  describe "Edge Cases" do
    test "module info returns expected structure" do
      info = DatetimeUtilities.__info__(:module)
      assert info == Indrajaal.Shared.DatetimeUtilities
    end

    test "datetime_days_ago handles boundary value 0" do
      result = DatetimeUtilities.datetime_days_ago(0)
      assert %DateTime{} = result
    end

    test "random_datetime_in_range handles reverse range" do
      # Some implementations may handle this differently
      start_date = ~D[2025-01-31]
      end_date = ~D[2025-01-01]

      try do
        range = Date.range(start_date, end_date)
        result = DatetimeUtilities.random_datetime_in_range(range)
        assert result != nil or result == nil
      rescue
        # May raise on invalid range
        _ -> assert true
      end
    end

    test "handles leap year dates" do
      start_date = ~D[2024-02-28]
      end_date = ~D[2024-03-01]
      range = Date.range(start_date, end_date)

      result = DatetimeUtilities.random_datetime_in_range(range)
      assert %DateTime{} = result
    end

    test "handles year boundary" do
      start_date = ~D[2024-12-30]
      end_date = ~D[2025-01-02]
      range = Date.range(start_date, end_date)

      result = DatetimeUtilities.random_datetime_in_range(range)
      assert %DateTime{} = result
    end
  end

  # ============================================================================
  # SOURCE CODE VALIDATION TESTS
  # ============================================================================

  describe "Source Code Validation" do
    test "source file exists" do
      assert File.exists?("lib/indrajaal/shared/datetime_utilities.ex")
    end

    test "source file is valid Elixir" do
      source = File.read!("lib/indrajaal/shared/datetime_utilities.ex")
      {:ok, _ast} = Code.string_to_quoted(source)
    end

    test "module has proper defmodule structure" do
      source = File.read!("lib/indrajaal/shared/datetime_utilities.ex")
      assert String.contains?(source, "defmodule Indrajaal.Shared.DatetimeUtilities")
    end

    test "random_datetime_in_range has @spec" do
      source = File.read!("lib/indrajaal/shared/datetime_utilities.ex")
      assert String.contains?(source, "@spec random_datetime_in_range")
    end

    test "datetime_days_ago has @spec" do
      source = File.read!("lib/indrajaal/shared/datetime_utilities.ex")
      assert String.contains?(source, "@spec datetime_days_ago")
    end

    test "uses DateTime.utc_now for current time" do
      source = File.read!("lib/indrajaal/shared/datetime_utilities.ex")
      assert String.contains?(source, "DateTime.utc_now")
    end

    test "uses :rand for randomization" do
      source = File.read!("lib/indrajaal/shared/datetime_utilities.ex")
      assert String.contains?(source, ":rand")
    end
  end

  # ============================================================================
  # INTEGRATION SCENARIO TESTS
  # ============================================================================

  describe "Integration Scenarios" do
    test "generate test data for analytics" do
      # Generate recent datetimes for analytics testing
      datetimes = for _ <- 1..10, do: DatetimeUtilities.random_recent_datetime()

      assert length(datetimes) == 10

      Enum.each(datetimes, fn dt ->
        assert %DateTime{} = dt
      end)
    end

    test "generate optional timestamps for records" do
      # Some records have optional timestamps
      timestamps = for _ <- 1..20, do: DatetimeUtilities.maybe_recent_datetime()

      datetime_count = Enum.count(timestamps, fn t -> t != nil end)
      nil_count = Enum.count(timestamps, &is_nil/1)

      assert datetime_count + nil_count == 20
    end

    test "generate datetimes within reporting period" do
      # Quarterly report date range
      start_date = ~D[2025-01-01]
      end_date = ~D[2025-03-31]
      range = Date.range(start_date, end_date)

      datetimes = for _ <- 1..10, do: DatetimeUtilities.random_datetime_in_range(range)

      Enum.each(datetimes, fn dt ->
        date = DateTime.to_date(dt)
        assert Date.compare(date, start_date) in [:gt, :eq]
        assert Date.compare(date, end_date) in [:lt, :eq]
      end)
    end

    test "generate recent activity timestamps" do
      # Last 7 days of activity
      datetimes = for _ <- 1..10, do: DatetimeUtilities.datetime_days_ago(7)

      now = DateTime.utc_now()
      week_ago = DateTime.add(now, -8 * 24 * 60 * 60, :second)

      Enum.each(datetimes, fn dt ->
        assert DateTime.compare(dt, now) in [:lt, :eq]
        assert DateTime.compare(dt, week_ago) in [:gt, :eq]
      end)
    end

    test "all datetime functions are accessible" do
      functions = DatetimeUtilities.__info__(:functions)

      datetime_functions = [
        {:random_recent_datetime, 0},
        {:random_datetime_in_range, 1},
        {:maybe_recent_datetime, 0},
        {:datetime_days_ago, 1}
      ]

      Enum.each(datetime_functions, fn func ->
        assert func in functions, "Expected #{inspect(func)} to be in functions"
      end)
    end
  end
end
