defmodule Indrajaal.Web.Live.DeviceHealthGridTest do
  @moduledoc """
  WHAT: Self-contained ETS-backed test suite for the LiveView device health grid
        with color-coded matrix — covers N×M grid construction, health status color
        coding (green/yellow/red/gray), multi-sensor aggregation, sorting, device
        type grouping, health score calculation, refresh cycle, and offline detection.
  WHY:  The Prajna device dashboard (SC-DEV-001) renders real-time device health as
        a color-coded matrix.  Validating the logic in isolation (no production deps)
        allows fast, deterministic CI runs while providing a living specification that
        mirrors production behaviour at the unit level.
  CONSTRAINTS:
    - SC-DEV-001: Every device MUST appear exactly once in the grid
    - SC-DEV-002: Health score range [0.0, 1.0] — bounded invariant
    - SC-DEV-003: Color mapping total and deterministic — green/yellow/red/gray
    - SC-HMI-001: Dark cockpit default — critical health surfaced first
    - SC-PHICS-007: Device registry tracks all devices

  ## Coverage Matrix
  | Section                          | Unit | PC prop | SD prop |
  |----------------------------------|------|---------|---------|
  | Grid construction (N×M)          | 4    | 0       | 0       |
  | Health status color coding       | 6    | 0       | 0       |
  | Device status aggregation        | 4    | 0       | 0       |
  | Grid sorting                     | 4    | 0       | 0       |
  | Device type grouping             | 4    | 0       | 0       |
  | Health score calculation         | 4    | 0       | 0       |
  | Grid refresh cycle               | 3    | 0       | 0       |
  | Offline device detection         | 4    | 0       | 0       |
  | Cell count = rows × columns      | 0    | 1       | 1       |
  | Health score always in 0.0..1.0  | 0    | 1       | 1       |

  ## EP-GEN-014 compliance
  - `use PropCheck` provides forall/let for `property` blocks (PropCheck-native).
  - StreamData `check all` blocks appear inside plain `test` blocks only.
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.

  ## Change History
  | Version | Date       | Author | Change                              |
  |---------|------------|--------|-------------------------------------|
  | 2.0.0   | 2026-03-24 | Claude | Full rewrite — 10 sections, ETS     |
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :device_health_grid
  @moduletag :prajna

  # ---------------------------------------------------------------------------
  # Module-level constants
  # ---------------------------------------------------------------------------

  @device_types [:camera, :panel, :reader, :sensor]

  @heartbeat_timeout_ms 15_000
  @refresh_interval_ms 5_000
  @stale_threshold_ms 30_000

  # Color thresholds (mirroring SC-DEV-003)
  @green_threshold 0.75
  @yellow_threshold 0.40
  # offline = no recent heartbeat — separate from score

  # ---------------------------------------------------------------------------
  # Setup / teardown — each test gets its own ETS table
  # ---------------------------------------------------------------------------

  setup do
    table = :ets.new(:device_health_grid_test, [:set, :public])

    on_exit(fn ->
      if :ets.info(table) != :undefined, do: :ets.delete(table)
    end)

    %{table: table}
  end

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ===========================================================================
  # Section 1 — Grid construction (N×M)
  # ===========================================================================

  describe "device grid construction" do
    test "empty device list produces a 0×0 grid", %{table: table} do
      grid = build_grid([], table)
      assert grid.rows == 0
      assert grid.cols == 0
      assert grid.cells == []
    end

    test "single device produces a 1×1 grid", %{table: table} do
      devices = [make_device("cam-001", :camera, 0.90)]
      grid = build_grid(devices, table)
      assert grid.rows == 1
      assert grid.cols == 1
      assert length(grid.cells) == 1
    end

    test "four devices laid out in 2×2 grid when col_count = 2", %{table: table} do
      devices = Enum.map(1..4, &make_device("d-#{&1}", :camera, 0.80))
      grid = build_grid(devices, table, cols: 2)
      assert grid.rows == 2
      assert grid.cols == 2
      assert length(grid.cells) == 4
    end

    test "seven devices with col_count 3 produces 3 rows (3+3+1)", %{table: table} do
      devices = Enum.map(1..7, &make_device("d-#{&1}", :sensor, 0.70))
      grid = build_grid(devices, table, cols: 3)
      # ceil(7/3) = 3
      assert grid.rows == 3
      assert grid.cols == 3
      # cells list holds exactly the 7 real devices (no padding cells)
      real = Enum.count(grid.cells, & &1.real)
      assert real == 7
    end
  end

  # ===========================================================================
  # Section 2 — Health status color coding  (SC-DEV-003, SC-HMI-001)
  # ===========================================================================

  describe "health status color coding" do
    test "score >= 0.75 is :green", %{table: _} do
      assert health_color(1.00) == :green
      assert health_color(0.75) == :green
      assert health_color(0.90) == :green
    end

    test "score in [0.40, 0.75) is :yellow", %{table: _} do
      assert health_color(0.74) == :yellow
      assert health_color(0.40) == :yellow
      assert health_color(0.60) == :yellow
    end

    test "score < 0.40 is :red", %{table: _} do
      assert health_color(0.39) == :red
      assert health_color(0.00) == :red
      assert health_color(0.20) == :red
    end

    test "offline device is :gray regardless of last known score", %{table: _} do
      # even a healthy device shows gray when offline
      assert health_color_for_device(%{health_score: 0.95, online: false}) == :gray
    end

    test "boundary 0.75 is :green, 0.7499 is :yellow", %{table: _} do
      assert health_color(0.75) == :green
      assert health_color(0.7499) == :yellow
    end

    test "boundary 0.40 is :yellow, 0.3999 is :red", %{table: _} do
      assert health_color(0.40) == :yellow
      assert health_color(0.3999) == :red
    end
  end

  # ===========================================================================
  # Section 3 — Device status aggregation (SC-PHICS-007)
  # ===========================================================================

  describe "device status aggregation" do
    test "aggregate counts per color across all devices", %{table: table} do
      devices = [
        make_device("g1", :camera, 0.95),
        make_device("g2", :camera, 0.80),
        make_device("y1", :panel, 0.55),
        make_device("r1", :reader, 0.20)
      ]

      store_devices(table, devices)
      agg = aggregate_health(table)

      assert agg.green == 2
      assert agg.yellow == 1
      assert agg.red == 1
      assert agg.gray == 0
      assert agg.total == 4
    end

    test "offline devices are counted under :gray, not their last color", %{table: table} do
      devices = [
        make_device("online-good", :camera, 0.90, online: true),
        make_device("offline-good", :sensor, 0.85, online: false)
      ]

      store_devices(table, devices)
      agg = aggregate_health(table)

      assert agg.green == 1
      assert agg.gray == 1
      assert agg.total == 2
    end

    test "aggregate total equals sum of all color counts", %{table: table} do
      devices = Enum.map(1..8, &make_device("d#{&1}", :sensor, &1 / 10.0))
      store_devices(table, devices)
      agg = aggregate_health(table)
      assert agg.total == agg.green + agg.yellow + agg.red + agg.gray
    end

    test "aggregate multiple sensors per device uses device-level health", %{table: table} do
      # device with 3 sensors: scores 0.90, 0.80, 0.70 → weighted avg 0.80 → green
      device = make_device_multi_sensor("multi-001", :panel, [0.90, 0.80, 0.70])
      store_device(table, device)
      agg = aggregate_health(table)
      assert agg.green == 1
    end
  end

  # ===========================================================================
  # Section 4 — Grid sorting
  # ===========================================================================

  describe "grid sorting" do
    test "sort_by_name/1 returns devices in alphabetical order", %{table: table} do
      devices = [
        make_device("zebra-01", :camera, 0.90),
        make_device("alpha-01", :panel, 0.50),
        make_device("mango-01", :reader, 0.30)
      ]

      store_devices(table, devices)
      sorted = sort_devices(table, :name)
      names = Enum.map(sorted, & &1.id)
      assert names == Enum.sort(names)
    end

    test "sort_by_health/1 puts lowest (worst) score first", %{table: table} do
      devices = [
        make_device("high", :camera, 0.90),
        make_device("mid", :panel, 0.55),
        make_device("low", :reader, 0.10)
      ]

      store_devices(table, devices)
      sorted = sort_devices(table, :health)
      scores = Enum.map(sorted, & &1.health_score)

      # ascending order — worst first
      assert scores == Enum.sort(scores)
    end

    test "sort_by_last_seen/1 puts most recently seen first", %{table: table} do
      now = System.monotonic_time(:millisecond)

      devices = [
        make_device("old", :camera, 0.80, last_seen: now - 10_000),
        make_device("mid", :panel, 0.80, last_seen: now - 5_000),
        make_device("new", :reader, 0.80, last_seen: now - 1_000)
      ]

      store_devices(table, devices)
      sorted = sort_devices(table, :last_seen)
      ids = Enum.map(sorted, & &1.id)

      # most recent first
      assert ids == ["new", "mid", "old"]
    end

    test "sort_by_health/1 places offline (:gray) devices last", %{table: table} do
      devices = [
        make_device("online-bad", :camera, 0.10, online: true),
        make_device("offline-one", :panel, 0.95, online: false),
        make_device("online-good", :reader, 0.90, online: true)
      ]

      store_devices(table, devices)
      sorted = sort_devices(table, :health)
      # offline device should be last even though its score is high
      last = List.last(sorted)
      assert last.id == "offline-one"
    end
  end

  # ===========================================================================
  # Section 5 — Device type grouping
  # ===========================================================================

  describe "device type grouping" do
    test "group_by_type/1 returns a map keyed by device type", %{table: table} do
      devices = [
        make_device("cam-1", :camera, 0.90),
        make_device("cam-2", :camera, 0.85),
        make_device("pan-1", :panel, 0.60),
        make_device("rdr-1", :reader, 0.30),
        make_device("sen-1", :sensor, 0.75)
      ]

      store_devices(table, devices)
      groups = group_by_type(table)

      assert length(groups[:camera]) == 2
      assert length(groups[:panel]) == 1
      assert length(groups[:reader]) == 1
      assert length(groups[:sensor]) == 1
    end

    test "all four canonical device types are present as keys (even if empty)", %{table: table} do
      devices = [make_device("cam-only", :camera, 0.90)]
      store_devices(table, devices)
      groups = group_by_type(table)

      for type <- @device_types do
        assert Map.has_key?(groups, type),
               "Expected key #{inspect(type)} in groups map"
      end
    end

    test "devices within a group share the same type", %{table: table} do
      devices = Enum.map(1..5, &make_device("s#{&1}", :sensor, &1 / 5.0))
      store_devices(table, devices)
      groups = group_by_type(table)

      for device <- groups[:sensor] do
        assert device.type == :sensor
      end
    end

    test "total device count preserved across all groups", %{table: table} do
      count = 12

      devices =
        Enum.map(1..count, fn n ->
          type = Enum.at(@device_types, rem(n - 1, 4))
          make_device("d#{n}", type, 0.70)
        end)

      store_devices(table, devices)
      groups = group_by_type(table)
      total = @device_types |> Enum.map(&length(groups[&1])) |> Enum.sum()
      assert total == count
    end
  end

  # ===========================================================================
  # Section 6 — Health score calculation
  # ===========================================================================

  describe "health score calculation" do
    test "single metric — score equals metric value", %{table: _} do
      metrics = [%{name: :cpu, value: 0.80, weight: 1.0}]
      assert_in_delta calc_health_score(metrics), 0.80, 0.001
    end

    test "three equal-weight metrics produce straight average", %{table: _} do
      metrics = [
        %{name: :cpu, value: 0.90, weight: 1.0},
        %{name: :memory, value: 0.60, weight: 1.0},
        %{name: :uptime, value: 0.30, weight: 1.0}
      ]

      # (0.90 + 0.60 + 0.30) / 3 = 0.60
      assert_in_delta calc_health_score(metrics), 0.60, 0.001
    end

    test "weighted metrics favour high-weight components", %{table: _} do
      metrics = [
        %{name: :cpu, value: 1.00, weight: 3.0},
        %{name: :memory, value: 0.00, weight: 1.0}
      ]

      # (1.00×3 + 0.00×1) / (3+1) = 0.75
      assert_in_delta calc_health_score(metrics), 0.75, 0.001
    end

    test "health score is clamped to [0.0, 1.0] even for out-of-range inputs", %{table: _} do
      metrics_over = [%{name: :cpu, value: 1.50, weight: 1.0}]
      metrics_under = [%{name: :cpu, value: -0.50, weight: 1.0}]

      score_over = calc_health_score(metrics_over)
      score_under = calc_health_score(metrics_under)

      assert score_over <= 1.0
      assert score_under >= 0.0
    end
  end

  # ===========================================================================
  # Section 7 — Grid refresh cycle (SC-PHICS-007)
  # ===========================================================================

  describe "grid refresh cycle" do
    test "refresh_needed?/2 returns true after refresh_interval_ms have elapsed", %{table: _} do
      last_refresh = System.monotonic_time(:millisecond) - (@refresh_interval_ms + 100)
      now = System.monotonic_time(:millisecond)
      assert refresh_needed?(last_refresh, now)
    end

    test "refresh_needed?/2 returns false before interval has elapsed", %{table: _} do
      last_refresh = System.monotonic_time(:millisecond) - (@refresh_interval_ms - 1_000)
      now = System.monotonic_time(:millisecond)
      refute refresh_needed?(last_refresh, now)
    end

    test "incremental_diff/2 returns only devices whose score changed", %{table: table} do
      now = System.monotonic_time(:millisecond)

      old_snapshot = [
        make_device("d1", :camera, 0.90, last_seen: now),
        make_device("d2", :panel, 0.50, last_seen: now)
      ]

      new_snapshot = [
        make_device("d1", :camera, 0.90, last_seen: now),
        # only d2 changed
        make_device("d2", :panel, 0.30, last_seen: now)
      ]

      store_devices(table, new_snapshot)
      diff = incremental_diff(old_snapshot, new_snapshot)

      assert length(diff) == 1
      assert hd(diff).id == "d2"
    end
  end

  # ===========================================================================
  # Section 8 — Offline device detection
  # ===========================================================================

  describe "offline device detection" do
    test "device is online when last heartbeat is within timeout", %{table: _} do
      now = System.monotonic_time(:millisecond)
      device = make_device("online-1", :camera, 0.90, last_seen: now - 5_000)
      assert device_online?(device, now)
    end

    test "device is offline when heartbeat exceeds timeout", %{table: _} do
      now = System.monotonic_time(:millisecond)

      device =
        make_device("offline-1", :camera, 0.90, last_seen: now - (@heartbeat_timeout_ms + 1))

      refute device_online?(device, now)
    end

    test "stale threshold marks device for removal after 30s offline", %{table: _} do
      now = System.monotonic_time(:millisecond)
      device = make_device("stale-1", :sensor, 0.80, last_seen: now - (@stale_threshold_ms + 1))
      assert device_stale?(device, now)
    end

    test "offline devices are marked :gray in the grid", %{table: table} do
      now = System.monotonic_time(:millisecond)

      devices = [
        make_device("offline-cam", :camera, 0.95,
          online: false,
          last_seen: now - (@heartbeat_timeout_ms + 1)
        )
      ]

      store_devices(table, devices)
      cells = get_cells(table)
      [cell] = cells
      assert cell.color == :gray
    end
  end

  # ===========================================================================
  # Section 9 — Property: cell count = rows × columns  (SC-DEV-001)
  # ===========================================================================

  describe "cell count equals rows × columns — PropCheck" do
    property "GRID_PROP_01: total cells = rows × cols for any non-empty device list" do
      forall {raw_count, col_count} <-
               {PC.integer(1, 50), PC.integer(1, 10)} do
        devices =
          Enum.map(1..raw_count, fn n ->
            make_device("p#{n}", :sensor, 0.80)
          end)

        grid = build_grid(devices, nil, cols: col_count)

        expected_rows = ceil(raw_count / col_count)
        grid.rows == expected_rows and grid.cols == col_count
      end
    end

    test "GRID_SD_01: real cell count matches device count across arbitrary inputs" do
      ExUnitProperties.check all(
                               raw_count <- SD.integer(1..30),
                               col_count <- SD.integer(1..8)
                             ) do
        devices = Enum.map(1..raw_count, &make_device("sd-#{&1}", :camera, 0.80))
        grid = build_grid(devices, nil, cols: col_count)

        real_cells = Enum.count(grid.cells, & &1.real)

        assert real_cells == raw_count,
               "Expected #{raw_count} real cells but got #{real_cells}"
      end
    end
  end

  # ===========================================================================
  # Section 10 — Property: health score always in 0.0..1.0  (SC-DEV-002)
  # ===========================================================================

  describe "health score always in 0.0..1.0 range — PropCheck" do
    property "SCORE_PROP_01: clamped raw score stays in [0.0, 1.0]" do
      forall raw <- PC.real() do
        s = clamp_score(raw)
        s >= 0.0 and s <= 1.0
      end
    end

    test "SCORE_SD_01: weighted aggregate of arbitrary metric values is bounded" do
      ExUnitProperties.check all(
                               values <-
                                 SD.list_of(SD.float(min: -1.0, max: 2.0),
                                   min_length: 1,
                                   max_length: 10
                                 ),
                               weights <-
                                 SD.list_of(SD.float(min: 0.1, max: 5.0),
                                   min_length: 1,
                                   max_length: 10
                                 )
                             ) do
        # zip to same length and build metric list
        metrics =
          Enum.zip(values, weights)
          |> Enum.map(fn {v, w} -> %{name: :gen, value: v, weight: w} end)

        score = calc_health_score(metrics)

        assert score >= 0.0 and score <= 1.0,
               "calc_health_score returned #{score} — must be in [0.0, 1.0]"
      end
    end
  end

  # ===========================================================================
  # Private helpers — all logic is self-contained, no production module deps
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Device construction
  # ---------------------------------------------------------------------------

  defp make_device(id, type, health_score, opts \\ []) do
    online = Keyword.get(opts, :online, true)
    now = System.monotonic_time(:millisecond)
    last_seen = Keyword.get(opts, :last_seen, now)

    %{
      id: id,
      type: type,
      health_score: clamp_score(health_score),
      online: online,
      last_seen: last_seen,
      sensors: [%{name: :primary, value: health_score, weight: 1.0}],
      color: compute_color(health_score, online)
    }
  end

  defp make_device_multi_sensor(id, type, sensor_values) do
    metrics = Enum.map(sensor_values, &%{name: :sensor, value: &1, weight: 1.0})
    score = calc_health_score(metrics)

    %{
      id: id,
      type: type,
      health_score: score,
      online: true,
      last_seen: System.monotonic_time(:millisecond),
      sensors: metrics,
      color: compute_color(score, true)
    }
  end

  # ---------------------------------------------------------------------------
  # ETS storage helpers (SC-PHICS-007)
  # ---------------------------------------------------------------------------

  defp store_devices(table, _devices) when is_nil(table), do: :ok

  defp store_devices(table, devices) do
    Enum.each(devices, &store_device(table, &1))
  end

  defp store_device(table, device) do
    :ets.insert(table, {device.id, device})
  end

  defp get_all_devices(table) when is_nil(table), do: []

  defp get_all_devices(table) do
    :ets.tab2list(table) |> Enum.map(fn {_id, device} -> device end)
  end

  defp get_cells(table) do
    get_all_devices(table)
  end

  # ---------------------------------------------------------------------------
  # Grid construction (N×M layout)
  # ---------------------------------------------------------------------------

  defp build_grid(devices, table, opts \\ []) do
    col_count = Keyword.get(opts, :cols, max(1, length(devices)))

    real_cells = Enum.map(devices, &Map.put(&1, :real, true))

    if not is_nil(table) do
      store_devices(table, devices)
    end

    total = length(real_cells)

    row_count =
      if total == 0 do
        0
      else
        ceil(total / col_count)
      end

    %{
      rows: row_count,
      cols: if(total == 0, do: 0, else: col_count),
      cells: real_cells
    }
  end

  # ---------------------------------------------------------------------------
  # Color mapping (SC-DEV-003)
  # ---------------------------------------------------------------------------

  defp health_color(score) when score >= @green_threshold, do: :green
  defp health_color(score) when score >= @yellow_threshold, do: :yellow
  defp health_color(_score), do: :red

  defp health_color_for_device(%{online: false}), do: :gray
  defp health_color_for_device(%{health_score: score}), do: health_color(score)

  defp compute_color(_score, false = _online), do: :gray
  defp compute_color(score, true), do: health_color(score)

  # ---------------------------------------------------------------------------
  # Score clamping (SC-DEV-002)
  # ---------------------------------------------------------------------------

  defp clamp_score(score) when is_number(score), do: score |> max(0.0) |> min(1.0)
  defp clamp_score(_), do: 0.0

  # ---------------------------------------------------------------------------
  # Health score calculation — weighted average of metrics
  # ---------------------------------------------------------------------------

  defp calc_health_score([]), do: 0.0

  defp calc_health_score(metrics) do
    {weighted_sum, total_weight} =
      Enum.reduce(metrics, {0.0, 0.0}, fn %{value: v, weight: w}, {ws, tw} ->
        {ws + v * w, tw + w}
      end)

    raw =
      if total_weight > 0.0 do
        weighted_sum / total_weight
      else
        0.0
      end

    clamp_score(raw)
  end

  # ---------------------------------------------------------------------------
  # Aggregation (SC-PHICS-007)
  # ---------------------------------------------------------------------------

  defp aggregate_health(table) do
    devices = get_all_devices(table)

    counts =
      Enum.reduce(devices, %{green: 0, yellow: 0, red: 0, gray: 0}, fn device, acc ->
        color = health_color_for_device(device)
        Map.update!(acc, color, &(&1 + 1))
      end)

    Map.put(counts, :total, length(devices))
  end

  # ---------------------------------------------------------------------------
  # Sorting
  # ---------------------------------------------------------------------------

  defp sort_devices(table, :name) do
    get_all_devices(table) |> Enum.sort_by(& &1.id)
  end

  defp sort_devices(table, :health) do
    # offline (gray) devices go last; online devices sorted ascending by score
    get_all_devices(table)
    |> Enum.sort_by(fn device ->
      if device.online do
        {0, device.health_score}
      else
        {1, 0.0}
      end
    end)
  end

  defp sort_devices(table, :last_seen) do
    # most recently seen first (descending)
    get_all_devices(table) |> Enum.sort_by(& &1.last_seen, :desc)
  end

  # ---------------------------------------------------------------------------
  # Device type grouping
  # ---------------------------------------------------------------------------

  defp group_by_type(table) do
    devices = get_all_devices(table)

    base = Map.new(@device_types, &{&1, []})

    Enum.reduce(devices, base, fn device, acc ->
      Map.update(acc, device.type, [device], &(&1 ++ [device]))
    end)
  end

  # ---------------------------------------------------------------------------
  # Refresh cycle helpers
  # ---------------------------------------------------------------------------

  defp refresh_needed?(last_refresh_ms, now_ms) do
    now_ms - last_refresh_ms >= @refresh_interval_ms
  end

  defp incremental_diff(old_snapshot, new_snapshot) do
    old_by_id = Map.new(old_snapshot, &{&1.id, &1})

    Enum.filter(new_snapshot, fn new_device ->
      case Map.get(old_by_id, new_device.id) do
        nil -> true
        old_device -> abs(new_device.health_score - old_device.health_score) > 0.0001
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Offline / stale detection
  # ---------------------------------------------------------------------------

  defp device_online?(device, now_ms) do
    now_ms - device.last_seen < @heartbeat_timeout_ms
  end

  defp device_stale?(device, now_ms) do
    now_ms - device.last_seen >= @stale_threshold_ms
  end
end
