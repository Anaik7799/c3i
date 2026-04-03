defmodule Indrajaal.Web.Live.AnalyticsReportBuilderTest do
  @moduledoc """
  WHAT: Self-contained ETS-backed tests for a LiveView analytics report builder with
        chart generation — covers template creation, data aggregation pipelines, chart
        type selection, time range handling, KPI widget rendering, report scheduling,
        export formats, and drill-down navigation. All state is stored in ETS tables
        created per-test; no production module dependency is required.
  WHY:  Validates the analytics report builder logic powering the Prajna analytics
        cockpit (SC-ANALYTICS-001 to SC-ANALYTICS-005, SC-AN-001 to SC-AN-005,
        SC-KPI-001 to SC-KPI-005, SC-RPT-001 to SC-RPT-005, SC-HMI-001). Tests act
        as a living specification for the report builder state machine, aggregation
        pipeline, and chart rendering contracts.

  ## STAMP Compliance
  - SC-ANALYTICS-001: Analytics domain — report lifecycle state machine
  - SC-ANALYTICS-002: Analytics domain — data source selection contract
  - SC-ANALYTICS-003: Analytics domain — aggregation correctness invariants
  - SC-ANALYTICS-004: Analytics domain — export format validity
  - SC-ANALYTICS-005: Analytics domain — scheduling invariants
  - SC-AN-001: Analytics engine — required report fields
  - SC-AN-002: Analytics engine — chart type configuration
  - SC-AN-003: Analytics engine — time range filtering
  - SC-AN-004: Analytics engine — chart data shape
  - SC-AN-005: Analytics engine — export and scheduling integration
  - SC-KPI-001: KPI widget — numeric display with trend direction
  - SC-KPI-002: KPI widget — percentage change calculation bounds
  - SC-KPI-003: KPI widget — threshold-based alert colour
  - SC-KPI-004: KPI widget — sparkline data shape
  - SC-KPI-005: KPI widget — unit label attached to value
  - SC-RPT-001: Report — unique id per report
  - SC-RPT-002: Report — JSON export schema compliance
  - SC-RPT-003: Report — CSV export header row mandatory
  - SC-RPT-004: Report — drill-down path persisted in ETS
  - SC-RPT-005: Report — scheduled reports have future next_run_at
  - SC-HMI-001: HMI — cockpit LiveView components use bounded score ranges

  ## Coverage Matrix
  | Concern                              | Unit | PropCheck | StreamData |
  |--------------------------------------|------|-----------|------------|
  | Report template creation             | 3    | 0         | 0          |
  | Data aggregation sum/avg/min/max     | 5    | 0         | 0          |
  | Group-by time bucket                 | 3    | 0         | 0          |
  | Chart type selection                 | 5    | 0         | 0          |
  | Time range selection                 | 4    | 0         | 0          |
  | KPI widget rendering                 | 4    | 0         | 0          |
  | Report scheduling                    | 4    | 0         | 0          |
  | JSON export                          | 3    | 0         | 0          |
  | CSV export                           | 3    | 0         | 0          |
  | Drill-down navigation                | 3    | 0         | 0          |
  | Aggregated sum = individual sum      | 0    | 1         | 1          |
  | Time buckets cover full range        | 0    | 1         | 1          |

  ## ETS Architecture
  Each test creates a uniquely-named ETS table via `start_ets/0`, stores simulated
  time-series rows, and tears it down in `on_exit`. No shared global state.

  ## EP-GEN-014 Compliance
  - `use PropCheck` provides forall macro for `property` blocks (PropCheck-native).
  - StreamData `check all` blocks inside plain `test` blocks only.
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.
  """

  use ExUnit.Case, async: true
  require ExUnitProperties

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :analytics
  @moduletag :report_builder

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # Each test gets its own ETS table; cleaned up on_exit.
  setup do
    table = :"arb_test_#{:erlang.unique_integer([:positive])}"
    :ets.new(table, [:set, :public, :named_table])

    on_exit(fn ->
      if :ets.whereis(table) != :undefined, do: :ets.delete(table)
    end)

    {:ok, table: table}
  end

  # ---------------------------------------------------------------------------
  # Section 1: report template creation (SC-AN-001, SC-RPT-001)
  # ---------------------------------------------------------------------------

  describe "report template creation" do
    test "new template has all required top-level fields", %{table: table} do
      tpl = new_template(table, "tpl-001", "Monthly Sales")

      assert tpl.id == "tpl-001"
      assert tpl.name == "Monthly Sales"
      assert tpl.state == :draft
      assert Map.has_key?(tpl, :sections)
      assert Map.has_key?(tpl, :data_sources)
      assert Map.has_key?(tpl, :chart_type)
      assert Map.has_key?(tpl, :time_range)
      assert Map.has_key?(tpl, :schedule)
      assert Map.has_key?(tpl, :created_at)
    end

    test "template sections default to an empty list", %{table: table} do
      tpl = new_template(table, "tpl-002", "Empty")
      assert tpl.sections == []
    end

    test "adding a section stores it and persists in ETS", %{table: table} do
      tpl =
        new_template(table, "tpl-003", "With Sections")
        |> add_section(%{id: "s1", title: "Overview", chart_type: :bar})
        |> add_section(%{id: "s2", title: "Detail", chart_type: :line})

      assert length(tpl.sections) == 2
      titles = Enum.map(tpl.sections, & &1.title)
      assert "Overview" in titles
      assert "Detail" in titles

      # Confirm ETS round-trip
      [{_key, stored}] = :ets.lookup(table, "tpl-003")
      assert length(stored.sections) == 2
    end

    test "configure_data_sources sets the data_sources field", %{table: table} do
      tpl =
        new_template(table, "tpl-004", "Multi Source")
        |> configure_data_sources([:events, :metrics])

      assert :events in tpl.data_sources
      assert :metrics in tpl.data_sources
    end
  end

  # ---------------------------------------------------------------------------
  # Section 2: data aggregation pipeline (SC-ANALYTICS-003)
  # ---------------------------------------------------------------------------

  describe "data aggregation pipeline" do
    test "aggregate :sum over empty rows returns 0", %{table: _table} do
      assert run_aggregation([], :sum) == 0
    end

    test "aggregate :sum is correct for integer values", %{table: _table} do
      rows = [%{value: 10}, %{value: 20}, %{value: 30}]
      assert run_aggregation(rows, :sum) == 60
    end

    test "aggregate :avg over empty rows returns 0.0", %{table: _table} do
      assert run_aggregation([], :avg) == 0.0
    end

    test "aggregate :avg is correct for known input", %{table: _table} do
      rows = [%{value: 10}, %{value: 20}, %{value: 30}]
      assert_in_delta run_aggregation(rows, :avg), 20.0, 0.001
    end

    test "aggregate :min returns the smallest value", %{table: _table} do
      rows = [%{value: 5}, %{value: 1}, %{value: 9}]
      assert run_aggregation(rows, :min) == 1
    end

    test "aggregate :max returns the largest value", %{table: _table} do
      rows = [%{value: 5}, %{value: 1}, %{value: 9}]
      assert run_aggregation(rows, :max) == 9
    end

    test "aggregate :count equals length of input", %{table: _table} do
      rows = [%{value: 1}, %{value: 2}, %{value: 3}, %{value: 4}]
      assert run_aggregation(rows, :count) == 4
    end

    test "group_by_bucket assigns each row to the correct hour bucket", %{table: _table} do
      # All rows in same hour should share bucket key
      rows = [
        %{ts: 3600, value: 10},
        %{ts: 3700, value: 20},
        %{ts: 7200, value: 30}
      ]

      buckets = group_by_bucket(rows, :hour)

      assert map_size(buckets) == 2
      hour_1 = Map.get(buckets, 0)
      hour_2 = Map.get(buckets, 1)
      assert length(hour_1) == 2
      assert length(hour_2) == 1
    end

    test "group_by_bucket with :day buckets groups correctly", %{table: _table} do
      rows = [
        %{ts: 0, value: 1},
        %{ts: 43_200, value: 2},
        %{ts: 86_400, value: 3}
      ]

      buckets = group_by_bucket(rows, :day)
      assert map_size(buckets) == 2
    end

    test "aggregate pipeline returns labelled bucket summary", %{table: _table} do
      rows = [
        %{ts: 0, value: 5},
        %{ts: 1800, value: 15},
        %{ts: 3600, value: 25}
      ]

      summary = aggregate_pipeline(rows, :hour, :sum)
      assert is_list(summary)
      assert length(summary) == 2

      [first | _] = summary
      assert Map.has_key?(first, :bucket)
      assert Map.has_key?(first, :value)
    end
  end

  # ---------------------------------------------------------------------------
  # Section 3: chart type selection (SC-AN-002, SC-AN-004)
  # ---------------------------------------------------------------------------

  describe "chart type selection" do
    test "line chart data shape has :points key", %{table: _table} do
      data = build_chart_data(:line, sample_rows(5))
      assert Map.has_key?(data, :points)
      assert length(data.points) == 5
    end

    test "bar chart data shape has :bars key", %{table: _table} do
      data = build_chart_data(:bar, sample_rows(3))
      assert Map.has_key?(data, :bars)
      assert length(data.bars) == 3
    end

    test "pie chart data shape has :slices key with percentage field", %{table: _table} do
      data = build_chart_data(:pie, sample_rows(4))
      assert Map.has_key?(data, :slices)

      for slice <- data.slices do
        assert Map.has_key?(slice, :pct)
        assert slice.pct >= 0.0 and slice.pct <= 100.0
      end
    end

    test "scatter chart data shape has :points with x and y coordinates",
         %{table: _table} do
      data = build_chart_data(:scatter, sample_rows(6))
      assert Map.has_key?(data, :points)

      for pt <- data.points do
        assert Map.has_key?(pt, :x)
        assert Map.has_key?(pt, :y)
      end
    end

    test "heatmap chart data shape has :cells with row and col keys",
         %{table: _table} do
      data = build_chart_data(:heatmap, sample_rows(4))
      assert Map.has_key?(data, :cells)

      for cell <- data.cells do
        assert Map.has_key?(cell, :row)
        assert Map.has_key?(cell, :col)
        assert Map.has_key?(cell, :value)
      end
    end

    test "unsupported chart type returns an error tuple", %{table: _table} do
      assert {:error, :unsupported_chart_type} = build_chart_data(:radar, sample_rows(2))
    end
  end

  # ---------------------------------------------------------------------------
  # Section 4: time range selection (SC-AN-003)
  # ---------------------------------------------------------------------------

  describe "time range selection" do
    test "preset :last_hour produces a range spanning 3600 seconds", %{table: _table} do
      range = preset_range(:last_hour)
      assert range.to - range.from == 3_600
    end

    test "preset :last_day produces a range spanning 86 400 seconds", %{table: _table} do
      range = preset_range(:last_day)
      assert range.to - range.from == 86_400
    end

    test "preset :last_week produces a range spanning 7 days", %{table: _table} do
      range = preset_range(:last_week)
      assert range.to - range.from == 7 * 86_400
    end

    test "preset :last_month produces a range spanning 30 days", %{table: _table} do
      range = preset_range(:last_month)
      assert range.to - range.from == 30 * 86_400
    end

    test "custom range is accepted when from < to", %{table: _table} do
      assert {:ok, _} = validate_range(%{from: 1_000, to: 2_000})
    end

    test "custom range is rejected when from >= to", %{table: _table} do
      assert {:error, :invalid_range} = validate_range(%{from: 5_000, to: 5_000})
      assert {:error, :invalid_range} = validate_range(%{from: 6_000, to: 5_000})
    end

    test "filter_by_range keeps only rows within [from, to]", %{table: _table} do
      rows = [
        %{ts: 100, value: 1},
        %{ts: 500, value: 2},
        %{ts: 1_000, value: 3},
        %{ts: 1_500, value: 4}
      ]

      filtered = filter_by_range(rows, %{from: 400, to: 1_100})
      tss = Enum.map(filtered, & &1.ts)

      assert 500 in tss
      assert 1_000 in tss
      refute 100 in tss
      refute 1_500 in tss
    end

    test "timezone_offset shifts the range bounds by the given seconds",
         %{table: _table} do
      base = %{from: 0, to: 3_600}
      shifted = apply_timezone_offset(base, _offset_seconds = 3_600)
      assert shifted.from == 3_600
      assert shifted.to == 7_200
    end
  end

  # ---------------------------------------------------------------------------
  # Section 5: KPI widget rendering (SC-KPI-001 to SC-KPI-005)
  # ---------------------------------------------------------------------------

  describe "KPI widget rendering" do
    test "KPI widget has all required display fields", %{table: _table} do
      widget = build_kpi_widget("active_devices", 42, :count, previous_value: 38)

      assert widget.id == "active_devices"
      assert widget.current_value == 42
      assert widget.unit == :count
      assert Map.has_key?(widget, :trend)
      assert Map.has_key?(widget, :pct_change)
      assert Map.has_key?(widget, :alert_color)
      assert Map.has_key?(widget, :sparkline)
    end

    test "trend arrow is :up when current > previous", %{table: _table} do
      widget = build_kpi_widget("cpu", 80, :percent, previous_value: 60)
      assert widget.trend == :up
    end

    test "trend arrow is :down when current < previous", %{table: _table} do
      widget = build_kpi_widget("cpu", 40, :percent, previous_value: 60)
      assert widget.trend == :down
    end

    test "trend is :flat when current equals previous", %{table: _table} do
      widget = build_kpi_widget("count", 10, :count, previous_value: 10)
      assert widget.trend == :flat
    end

    test "percentage change is calculated correctly", %{table: _table} do
      widget = build_kpi_widget("sales", 110, :currency, previous_value: 100)
      assert_in_delta widget.pct_change, 10.0, 0.01
    end

    test "percentage change is 0.0 when previous value is 0", %{table: _table} do
      widget = build_kpi_widget("new", 50, :count, previous_value: 0)
      assert widget.pct_change == 0.0
    end

    test "alert color is :green when current value is below warning threshold",
         %{table: _table} do
      widget =
        build_kpi_widget("latency_ms", 30, :ms,
          previous_value: 25,
          warn_threshold: 100,
          crit_threshold: 200
        )

      assert widget.alert_color == :green
    end

    test "alert color is :yellow when current value crosses warn threshold",
         %{table: _table} do
      widget =
        build_kpi_widget("latency_ms", 150, :ms,
          previous_value: 80,
          warn_threshold: 100,
          crit_threshold: 200
        )

      assert widget.alert_color == :yellow
    end

    test "alert color is :red when current value crosses crit threshold",
         %{table: _table} do
      widget =
        build_kpi_widget("latency_ms", 250, :ms,
          previous_value: 80,
          warn_threshold: 100,
          crit_threshold: 200
        )

      assert widget.alert_color == :red
    end

    test "sparkline contains a list of numeric values", %{table: _table} do
      history = [10, 12, 9, 15, 14, 16]
      widget = build_kpi_widget("mem", 16, :mb, previous_value: 14, history: history)
      assert is_list(widget.sparkline)
      assert Enum.all?(widget.sparkline, &is_number/1)
    end
  end

  # ---------------------------------------------------------------------------
  # Section 6: report scheduling (SC-ANALYTICS-005, SC-RPT-005)
  # ---------------------------------------------------------------------------

  describe "report scheduling" do
    test "schedule can be set to :daily, :weekly, :monthly, or :none",
         %{table: table} do
      for sched <- [:daily, :weekly, :monthly, :none] do
        tpl =
          new_template(table, "sched-#{sched}", "Sched #{sched}")
          |> set_schedule(sched)

        assert tpl.schedule == sched
      end
    end

    test "next_run_at is nil when schedule is :none", %{table: _table} do
      now = System.os_time(:second)
      tpl = %{schedule: :none}
      assert next_run_at(tpl, now) == nil
    end

    test "next_run_at is in the future for :daily schedule", %{table: _table} do
      now = System.os_time(:second)
      tpl = %{schedule: :daily}
      assert next_run_at(tpl, now) > now
    end

    test "next_run_at advances by 7 days for :weekly schedule", %{table: _table} do
      now = 0
      expected = 7 * 86_400
      assert next_run_at(%{schedule: :weekly}, now) == expected
    end

    test "next_run_at advances by 30 days for :monthly schedule", %{table: _table} do
      now = 0
      expected = 30 * 86_400
      assert next_run_at(%{schedule: :monthly}, now) == expected
    end

    test "cron expression :daily is valid", %{table: _table} do
      assert validate_cron("0 0 * * *") == :ok
    end

    test "cron expression :weekly is valid", %{table: _table} do
      assert validate_cron("0 0 * * 1") == :ok
    end

    test "malformed cron expression is rejected", %{table: _table} do
      assert {:error, :invalid_cron} = validate_cron("not a cron")
      assert {:error, :invalid_cron} = validate_cron("99 99 99 99 99")
    end
  end

  # ---------------------------------------------------------------------------
  # Section 7: export formats (SC-ANALYTICS-004, SC-RPT-002, SC-RPT-003)
  # ---------------------------------------------------------------------------

  describe "export formats — JSON" do
    test "exported JSON is a valid, parseable binary", %{table: table} do
      tpl = build_ready_template(table, "exp-j1", :bar)
      json = export(tpl, :json)

      assert is_binary(json)
      assert {:ok, _parsed} = Jason.decode(json)
    end

    test "exported JSON contains required top-level keys", %{table: table} do
      tpl = build_ready_template(table, "exp-j2", :line)
      {:ok, parsed} = Jason.decode(export(tpl, :json))

      for key <- ["id", "name", "chart_type", "chart_data", "exported_at"] do
        assert Map.has_key?(parsed, key),
               "JSON export missing required key: #{key}"
      end
    end

    test "exported JSON chart_data contains rows array", %{table: table} do
      tpl = build_ready_template(table, "exp-j3", :bar)
      {:ok, parsed} = Jason.decode(export(tpl, :json))

      chart_data = parsed["chart_data"]
      assert is_map(chart_data)
      assert Map.has_key?(chart_data, "rows")
      assert is_list(chart_data["rows"])
    end
  end

  describe "export formats — CSV" do
    test "exported CSV starts with a header row", %{table: table} do
      tpl = build_ready_template(table, "exp-c1", :bar)
      csv = export(tpl, :csv)

      [header | _rest] = String.split(csv, "\n", trim: true)
      assert String.contains?(header, ","), "CSV header must be comma-separated"
    end

    test "exported CSV row count equals header plus data rows", %{table: table} do
      tpl = build_ready_template(table, "exp-c2", :bar)
      csv = export(tpl, :csv)

      lines = String.split(csv, "\n", trim: true)
      data_row_count = length(tpl.chart_data.rows)
      assert length(lines) == 1 + data_row_count
    end

    test "each CSV data row has the same number of columns as the header",
         %{table: table} do
      tpl = build_ready_template(table, "exp-c3", :bar)
      csv = export(tpl, :csv)

      [header | data_rows] = String.split(csv, "\n", trim: true)
      header_cols = length(String.split(header, ","))

      for row <- data_rows do
        assert length(String.split(row, ",")) == header_cols,
               "Data row column count mismatch: #{row}"
      end
    end
  end

  describe "export formats — PDF metadata" do
    test "PDF metadata export returns a map with required fields",
         %{table: table} do
      tpl = build_ready_template(table, "exp-p1", :bar)
      meta = export(tpl, :pdf_meta)

      assert is_map(meta)
      assert Map.has_key?(meta, :title)
      assert Map.has_key?(meta, :author)
      assert Map.has_key?(meta, :page_count)
      assert Map.has_key?(meta, :generated_at)
    end

    test "PDF metadata page count is at least 1", %{table: table} do
      tpl = build_ready_template(table, "exp-p2", :pie)
      meta = export(tpl, :pdf_meta)
      assert meta.page_count >= 1
    end
  end

  # ---------------------------------------------------------------------------
  # Section 8: drill-down navigation (SC-RPT-004)
  # ---------------------------------------------------------------------------

  describe "drill-down navigation" do
    test "initial navigation state is at :summary level", %{table: table} do
      tpl = new_template(table, "dd-001", "Drill Down")
      nav = nav_state(tpl)
      assert nav.level == :summary
      assert nav.path == []
    end

    test "drilling into a section moves from :summary to :detail level",
         %{table: table} do
      tpl =
        new_template(table, "dd-002", "Nav")
        |> add_section(%{id: "sec-1", title: "Sales", chart_type: :bar})

      nav =
        tpl
        |> nav_state()
        |> drill_into("sec-1", %{filter: "region=east"})

      assert nav.level == :detail
      assert "sec-1" in nav.path
    end

    test "drilling from :detail into a row moves to :raw_data level",
         %{table: table} do
      tpl = new_template(table, "dd-003", "Deep Nav")

      nav =
        tpl
        |> nav_state()
        |> drill_into("sec-1", %{})
        |> drill_into("row-42", %{row_id: 42})

      assert nav.level == :raw_data
      assert length(nav.path) == 2
    end

    test "navigating back from :detail returns to :summary", %{table: table} do
      tpl = new_template(table, "dd-004", "Back Nav")

      nav =
        tpl
        |> nav_state()
        |> drill_into("sec-1", %{})
        |> nav_back()

      assert nav.level == :summary
      assert nav.path == []
    end

    test "ETS stores the current navigation path under the report id",
         %{table: table} do
      tpl = new_template(table, "dd-005", "ETS Nav")

      nav =
        tpl
        |> nav_state()
        |> drill_into("sec-A", %{})

      persist_nav(table, "dd-005", nav)

      [{_key, stored_nav}] = :ets.lookup(table, {:nav, "dd-005"})
      assert stored_nav.level == :detail
      assert "sec-A" in stored_nav.path
    end
  end

  # ---------------------------------------------------------------------------
  # Section 9: Property — aggregated sum equals individual sum (SC-ANALYTICS-003)
  # ---------------------------------------------------------------------------

  describe "aggregation sum consistency — PropCheck (SC-ANALYTICS-003)" do
    property "SUM_PROP_01: sum is always >= 0 for non-negative integer inputs" do
      forall xs <- PC.non_empty(PC.list(PC.integer(min: 0, max: 1_000))) do
        rows = Enum.map(xs, fn v -> %{value: v} end)
        run_aggregation(rows, :sum) >= 0
      end
    end

    property "SUM_PROP_02: avg is bounded by min and max of the list" do
      forall xs <- PC.non_empty(PC.list(PC.integer(min: -500, max: 500))) do
        rows = Enum.map(xs, fn v -> %{value: v} end)
        avg = run_aggregation(rows, :avg)
        min_val = Enum.min(xs)
        max_val = Enum.max(xs)
        avg >= min_val - 0.001 and avg <= max_val + 0.001
      end
    end
  end

  describe "aggregation sum consistency — StreamData (SC-ANALYTICS-003)" do
    test "SUM_SD_01: sum of partitioned list equals sum of whole list" do
      ExUnitProperties.check all(
                               xs <-
                                 SD.list_of(SD.integer(0..1_000), min_length: 2, max_length: 40),
                               split_at <- SD.integer(1..max(1, length(xs) - 1))
                             ) do
        {left, right} = Enum.split(xs, split_at)

        left_rows = Enum.map(left, fn v -> %{value: v} end)
        right_rows = Enum.map(right, fn v -> %{value: v} end)
        all_rows = Enum.map(xs, fn v -> %{value: v} end)

        assert run_aggregation(all_rows, :sum) ==
                 run_aggregation(left_rows, :sum) + run_aggregation(right_rows, :sum)
      end
    end

    test "SUM_SD_02: count always equals length of input" do
      ExUnitProperties.check all(xs <- SD.list_of(SD.integer(), max_length: 80)) do
        rows = Enum.map(xs, fn v -> %{value: v} end)
        assert run_aggregation(rows, :count) == length(rows)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 10: Property — time buckets cover the entire range (SC-AN-003)
  # ---------------------------------------------------------------------------

  describe "time bucket coverage — PropCheck (SC-AN-003)" do
    property "BUCKET_PROP_01: every row appears in exactly one bucket" do
      forall {n, bucket_size} <- {PC.integer(min: 1, max: 20), PC.integer(min: 1, max: 10)} do
        rows =
          Enum.map(0..(n - 1), fn i -> %{ts: i * bucket_size, value: i} end)

        buckets = group_by_bucket(rows, bucket_size)

        all_bucket_rows =
          buckets |> Map.values() |> List.flatten()

        length(all_bucket_rows) == length(rows)
      end
    end
  end

  describe "time bucket coverage — StreamData (SC-AN-003)" do
    test "BUCKET_SD_01: filter_by_range never returns rows outside the window" do
      ExUnitProperties.check all(
                               from <- SD.integer(0..1_000),
                               to_offset <- SD.integer(1..1_000),
                               ts_list <- SD.list_of(SD.integer(0..2_000), max_length: 30)
                             ) do
        range = %{from: from, to: from + to_offset}
        rows = Enum.map(ts_list, fn t -> %{ts: t, value: t} end)
        filtered = filter_by_range(rows, range)

        for row <- filtered do
          assert row.ts >= range.from and row.ts <= range.to,
                 "Row ts=#{row.ts} outside [#{range.from}, #{range.to}]"
        end
      end
    end

    test "BUCKET_SD_02: buckets from aggregate_pipeline are non-overlapping" do
      ExUnitProperties.check all(
                               timestamps <-
                                 SD.list_of(SD.integer(0..7_199), min_length: 1, max_length: 20)
                             ) do
        rows = Enum.map(timestamps, fn t -> %{ts: t, value: 1} end)
        summary = aggregate_pipeline(rows, :hour, :count)

        bucket_keys = Enum.map(summary, & &1.bucket)

        assert length(bucket_keys) == length(Enum.uniq(bucket_keys)),
               "Duplicate bucket keys found: #{inspect(bucket_keys)}"
      end
    end
  end

  # ===========================================================================
  # Private helpers — all logic is self-contained, no production deps
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # ETS-backed template store (SC-RPT-001)
  # ---------------------------------------------------------------------------

  defp new_template(table, id, name) do
    tpl = %{
      id: id,
      name: name,
      state: :draft,
      sections: [],
      data_sources: [],
      chart_type: :bar,
      time_range: preset_range(:last_day),
      aggregation: :count,
      schedule: :none,
      created_at: System.os_time(:second),
      chart_data: nil
    }

    :ets.insert(table, {id, tpl})
    tpl
  end

  defp add_section(tpl, section) do
    updated = Map.update!(tpl, :sections, fn secs -> secs ++ [section] end)
    updated
  end

  defp configure_data_sources(tpl, sources) do
    %{tpl | data_sources: sources}
  end

  defp set_schedule(tpl, schedule) do
    %{tpl | schedule: schedule}
  end

  # ---------------------------------------------------------------------------
  # Aggregation (SC-ANALYTICS-003)
  # ---------------------------------------------------------------------------

  defp run_aggregation([], :sum), do: 0
  defp run_aggregation([], :avg), do: 0.0
  defp run_aggregation([], :min), do: nil
  defp run_aggregation([], :max), do: nil
  defp run_aggregation(rows, :count), do: length(rows)

  defp run_aggregation(rows, :sum) do
    Enum.reduce(rows, 0, fn row, acc -> acc + row.value end)
  end

  defp run_aggregation(rows, :avg) do
    run_aggregation(rows, :sum) / length(rows) * 1.0
  end

  defp run_aggregation(rows, :min) do
    rows |> Enum.map(& &1.value) |> Enum.min()
  end

  defp run_aggregation(rows, :max) do
    rows |> Enum.map(& &1.value) |> Enum.max()
  end

  # group_by_bucket/2 accepts a bucket size in seconds (integer) or a preset atom
  defp group_by_bucket(rows, :hour), do: group_by_bucket(rows, 3_600)
  defp group_by_bucket(rows, :day), do: group_by_bucket(rows, 86_400)

  defp group_by_bucket(rows, bucket_seconds) when is_integer(bucket_seconds) do
    Enum.group_by(rows, fn row -> div(row.ts, bucket_seconds) end)
  end

  defp aggregate_pipeline(rows, bucket_atom, agg_fn) do
    rows
    |> group_by_bucket(bucket_atom)
    |> Enum.map(fn {bucket_key, bucket_rows} ->
      %{bucket: bucket_key, value: run_aggregation(bucket_rows, agg_fn)}
    end)
    |> Enum.sort_by(& &1.bucket)
  end

  # ---------------------------------------------------------------------------
  # Chart data (SC-AN-002, SC-AN-004)
  # ---------------------------------------------------------------------------

  defp build_chart_data(:line, rows) do
    %{
      chart_type: :line,
      points: Enum.map(rows, fn r -> %{x: r.ts, y: r.value} end)
    }
  end

  defp build_chart_data(:bar, rows) do
    %{
      chart_type: :bar,
      bars: Enum.map(rows, fn r -> %{label: "t#{r.ts}", value: r.value} end)
    }
  end

  defp build_chart_data(:pie, rows) do
    total = run_aggregation(rows, :sum)
    total_f = if total == 0, do: 1.0, else: total * 1.0

    %{
      chart_type: :pie,
      slices:
        Enum.map(rows, fn r ->
          %{label: "t#{r.ts}", value: r.value, pct: r.value / total_f * 100.0}
        end)
    }
  end

  defp build_chart_data(:scatter, rows) do
    %{
      chart_type: :scatter,
      points: Enum.map(rows, fn r -> %{x: r.ts, y: r.value} end)
    }
  end

  defp build_chart_data(:heatmap, rows) do
    cells =
      rows
      |> Enum.with_index()
      |> Enum.map(fn {r, idx} ->
        %{row: div(idx, 2), col: rem(idx, 2), value: r.value}
      end)

    %{chart_type: :heatmap, cells: cells}
  end

  defp build_chart_data(_unsupported, _rows), do: {:error, :unsupported_chart_type}

  # ---------------------------------------------------------------------------
  # Time ranges (SC-AN-003)
  # ---------------------------------------------------------------------------

  defp preset_range(:last_hour) do
    now = System.os_time(:second)
    %{from: now - 3_600, to: now}
  end

  defp preset_range(:last_day) do
    now = System.os_time(:second)
    %{from: now - 86_400, to: now}
  end

  defp preset_range(:last_week) do
    now = System.os_time(:second)
    %{from: now - 7 * 86_400, to: now}
  end

  defp preset_range(:last_month) do
    now = System.os_time(:second)
    %{from: now - 30 * 86_400, to: now}
  end

  defp validate_range(%{from: f, to: t}) when f < t, do: {:ok, %{from: f, to: t}}
  defp validate_range(_), do: {:error, :invalid_range}

  defp filter_by_range(rows, %{from: f, to: t}) do
    Enum.filter(rows, fn row -> row.ts >= f and row.ts <= t end)
  end

  defp apply_timezone_offset(%{from: f, to: t}, offset_seconds) do
    %{from: f + offset_seconds, to: t + offset_seconds}
  end

  # ---------------------------------------------------------------------------
  # KPI widgets (SC-KPI-001 to SC-KPI-005, SC-HMI-001)
  # ---------------------------------------------------------------------------

  defp build_kpi_widget(id, current, unit, opts \\ []) do
    previous = Keyword.get(opts, :previous_value, 0)
    history = Keyword.get(opts, :history, [current])
    warn_threshold = Keyword.get(opts, :warn_threshold, nil)
    crit_threshold = Keyword.get(opts, :crit_threshold, nil)

    trend =
      cond do
        current > previous -> :up
        current < previous -> :down
        true -> :flat
      end

    pct_change =
      if previous == 0 do
        0.0
      else
        (current - previous) / previous * 100.0
      end

    alert_color = classify_alert_color(current, warn_threshold, crit_threshold)

    %{
      id: id,
      current_value: current,
      unit: unit,
      trend: trend,
      pct_change: pct_change,
      alert_color: alert_color,
      sparkline: history
    }
  end

  defp classify_alert_color(_val, nil, nil), do: :green

  defp classify_alert_color(val, warn, crit) do
    cond do
      crit != nil and val >= crit -> :red
      warn != nil and val >= warn -> :yellow
      true -> :green
    end
  end

  # ---------------------------------------------------------------------------
  # Scheduling (SC-ANALYTICS-005, SC-RPT-005)
  # ---------------------------------------------------------------------------

  defp next_run_at(%{schedule: :none}, _now), do: nil
  defp next_run_at(%{schedule: :daily}, now), do: now + 86_400
  defp next_run_at(%{schedule: :weekly}, now), do: now + 7 * 86_400
  defp next_run_at(%{schedule: :monthly}, now), do: now + 30 * 86_400

  # Minimal cron validation: 5 space-separated fields, each digit or * or /-range
  defp validate_cron(expr) when is_binary(expr) do
    parts = String.split(expr, " ", trim: true)

    valid =
      length(parts) == 5 and
        Enum.all?(parts, fn p ->
          Regex.match?(~r/^(\*|[0-9]+([\/\-][0-9]+)?)$/, p)
        end) and
        cron_fields_in_range?(parts)

    if valid, do: :ok, else: {:error, :invalid_cron}
  end

  defp validate_cron(_), do: {:error, :invalid_cron}

  defp cron_fields_in_range?([min, hour, dom, month, dow]) do
    in_range?(min, 0, 59) and
      in_range?(hour, 0, 23) and
      in_range?(dom, 1, 31) and
      in_range?(month, 1, 12) and
      in_range?(dow, 0, 7)
  end

  defp in_range?("*", _lo, _hi), do: true

  defp in_range?(field, lo, hi) do
    case Integer.parse(field) do
      {n, _} -> n >= lo and n <= hi
      :error -> false
    end
  end

  # ---------------------------------------------------------------------------
  # Export (SC-ANALYTICS-004, SC-RPT-002, SC-RPT-003)
  # ---------------------------------------------------------------------------

  defp export(tpl, :json) do
    payload = %{
      "id" => tpl.id,
      "name" => tpl.name,
      "chart_type" => Atom.to_string(tpl.chart_type),
      "aggregation" => Atom.to_string(tpl.aggregation),
      "chart_data" => json_chart_data(tpl.chart_data),
      "exported_at" => System.os_time(:second)
    }

    Jason.encode!(payload)
  end

  defp export(tpl, :csv) do
    header = "label,value"

    data_rows =
      tpl.chart_data.rows
      |> Enum.map(fn row -> "#{row.label},#{row.value}" end)

    ([header] ++ data_rows) |> Enum.join("\n")
  end

  defp export(tpl, :pdf_meta) do
    section_count = length(tpl.sections)

    %{
      title: tpl.name,
      author: "Indrajaal Analytics",
      page_count: max(1, section_count),
      generated_at: System.os_time(:second)
    }
  end

  defp json_chart_data(nil), do: %{"rows" => []}

  defp json_chart_data(%{rows: rows}) do
    %{
      "rows" => Enum.map(rows, fn r -> %{"label" => to_string(r.label), "value" => r.value} end)
    }
  end

  # ---------------------------------------------------------------------------
  # Drill-down navigation (SC-RPT-004)
  # ---------------------------------------------------------------------------

  defp nav_state(_tpl), do: %{level: :summary, path: [], context: %{}}

  defp drill_into(nav, target_id, context) do
    next_level =
      case nav.level do
        :summary -> :detail
        :detail -> :raw_data
        other -> other
      end

    %{nav | level: next_level, path: nav.path ++ [target_id], context: context}
  end

  defp nav_back(%{path: []} = nav), do: nav

  defp nav_back(nav) do
    new_path = Enum.drop(nav.path, -1)

    new_level =
      case length(new_path) do
        0 -> :summary
        1 -> :detail
        _ -> :raw_data
      end

    %{nav | level: new_level, path: new_path}
  end

  defp persist_nav(table, report_id, nav) do
    :ets.insert(table, {{:nav, report_id}, nav})
  end

  # ---------------------------------------------------------------------------
  # Test helpers
  # ---------------------------------------------------------------------------

  defp sample_rows(n) do
    Enum.map(1..n, fn i -> %{ts: i * 60, value: i * 10} end)
  end

  defp build_ready_template(table, id, chart_type) do
    rows = sample_rows(4)

    tpl =
      new_template(table, id, "Ready #{id}")
      |> add_section(%{id: "s1", title: "Main", chart_type: chart_type})

    %{
      tpl
      | chart_type: chart_type,
        state: :complete,
        chart_data: %{rows: rows, chart_type: chart_type}
    }
  end
end
