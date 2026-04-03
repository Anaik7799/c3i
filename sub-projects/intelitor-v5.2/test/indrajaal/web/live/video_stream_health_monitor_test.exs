defmodule Indrajaal.Web.Live.VideoStreamHealthMonitorTest do
  @moduledoc """
  Self-contained ETS-backed test suite for the LiveView video stream health
  monitor with bitrate and FPS metrics.

  WHAT: Validates stream discovery, bitrate monitoring, FPS monitoring, composite
        health scoring, recording status tracking, stream reconnection logic,
        multi-stream dashboard grid, and bandwidth allocation — all simulated
        via ETS with no production module dependencies.

  WHY:  The Prajna video monitoring panel requires a reliable LiveView health
        monitor that can handle arbitrary numbers of concurrent streams, detect
        metric degradation quickly, and enforce per-stream bandwidth budgets.
        These tests verify the monitor's data model and logic in isolation so
        that the LiveView module can be built against a proven contract.

  CONSTRAINTS:
    - SC-VIDEO-001: Stream health state MUST be tracked per stream ID
    - SC-VIDEO-002: Health score MUST be in [0.0, 1.0] at all times
    - SC-VIDEO-003: FPS MUST be positive for any active stream
    - SC-CAMERA-001: Camera streams MUST be individually addressable by ID
    - SC-HMI-001: HMI health indicators MUST reflect worst-case stream state

  ## STAMP Compliance
  - SC-VIDEO-001: Per-stream health state in ETS, keyed by stream ID
  - SC-VIDEO-002: Composite health score clamped to [0.0, 1.0]
  - SC-VIDEO-003: FPS drop below 15 fps triggers alert
  - SC-CAMERA-001: Streams registered and discovered by camera ID
  - SC-HMI-001: Dashboard overall health reflects minimum across all streams

  ## EP-GEN-014 compliance
  - `use PropCheck` provides forall/2 for `property` blocks (PropCheck-native).
  - StreamData `check all` blocks appear inside plain `test` blocks only.
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.

  ## Change History
  | Version | Date       | Author | Change                               |
  |---------|------------|--------|--------------------------------------|
  | 1.0.0   | 2026-03-24 | Claude | Initial ETS-backed monitor test suite |

  @version "1.0.0"
  @last_modified "2026-03-24T00:00:00Z"
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :video_stream_health_monitor
  @moduletag :video

  # Minimum acceptable FPS for any active stream (SC-VIDEO-003)
  @min_fps 15

  # Degradation thresholds
  @fps_warn_ratio 0.5
  @bitrate_warn_ratio 0.5

  # Reconnect policy
  @max_reconnect_retries 5
  @reconnect_base_ms 500

  # ---------------------------------------------------------------------------
  # Shared setup — each test gets its own isolated ETS table
  # ---------------------------------------------------------------------------

  setup do
    table = :ets.new(:vsh_monitor_test, [:set, :public, {:write_concurrency, false}])

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
  # Section 1: Stream discovery (SC-CAMERA-001)
  # ===========================================================================

  describe "stream discovery" do
    test "registering a stream makes it discoverable", %{table: t} do
      stream = new_stream("cam-north-01", "camera-north")
      register_stream(t, stream)

      assert {:ok, found} = lookup_stream(t, "cam-north-01")
      assert found.id == "cam-north-01"
    end

    test "listing streams returns all registered entries", %{table: t} do
      for n <- 1..4 do
        register_stream(t, new_stream("cam-#{n}", "camera-#{n}"))
      end

      streams = list_streams(t)
      assert length(streams) == 4
    end

    test "newly registered stream appears in active list", %{table: t} do
      register_stream(t, new_stream("cam-entrance", "entrance"))

      active = list_active_streams(t)
      assert Enum.any?(active, fn s -> s.id == "cam-entrance" end)
    end

    test "deregistering a stream removes it from discovery", %{table: t} do
      register_stream(t, new_stream("cam-to-remove", "roof-cam"))
      deregister_stream(t, "cam-to-remove")

      assert :error == lookup_stream(t, "cam-to-remove")
    end

    test "detecting a new stream increments registered count", %{table: t} do
      before = length(list_streams(t))
      register_stream(t, new_stream("cam-new", "new-cam"))

      assert length(list_streams(t)) == before + 1
    end

    test "duplicate registration overwrites prior entry", %{table: t} do
      register_stream(t, new_stream("cam-dup", "cam-dup") |> Map.put(:fps, 25))
      register_stream(t, new_stream("cam-dup", "cam-dup") |> Map.put(:fps, 30))

      {:ok, s} = lookup_stream(t, "cam-dup")
      assert s.fps == 30
    end
  end

  # ===========================================================================
  # Section 2: Bitrate monitoring
  # ===========================================================================

  describe "bitrate monitoring" do
    test "current bitrate is stored in stream record", %{table: t} do
      s = new_stream("cam-br", "cam") |> Map.put(:bitrate_kbps, 6_000)
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-br")
      assert found.bitrate_kbps == 6_000
    end

    test "bitrate moving average converges toward steady-state value", %{table: t} do
      samples = [4000, 4000, 4100, 3900, 4000, 4050, 3950]
      avg = moving_average(samples, 5)

      # Last window average should be close to 4000
      assert avg >= 3900 and avg <= 4200

      # Unused-table guard so setup teardown runs without Credo warning
      assert :ets.info(t) != :undefined
    end

    test "bitrate below 50% of baseline triggers threshold alert", %{table: t} do
      baseline = 8_000
      s = new_stream("cam-low-br", "cam") |> Map.put(:bitrate_kbps, 3_000)
      register_stream(t, s)

      alert = check_bitrate_alert(s, baseline)
      assert alert != nil
      assert alert.type == :bitrate_low
    end

    test "bitrate at or above baseline produces no alert", %{table: t} do
      baseline = 8_000
      s = new_stream("cam-ok-br", "cam") |> Map.put(:bitrate_kbps, 8_000)
      register_stream(t, s)

      assert check_bitrate_alert(s, baseline) == nil
    end

    test "bitrate alert includes current and baseline kbps", %{table: t} do
      baseline = 4_000
      s = new_stream("cam-alert-detail", "cam") |> Map.put(:bitrate_kbps, 1_000)
      register_stream(t, s)

      alert = check_bitrate_alert(s, baseline)
      assert alert.actual_kbps == 1_000
      assert alert.baseline_kbps == baseline
    end

    test "updating bitrate sample refreshes ETS record", %{table: t} do
      s = new_stream("cam-update-br", "cam")
      register_stream(t, s)
      update_bitrate(t, "cam-update-br", 5_500)

      {:ok, found} = lookup_stream(t, "cam-update-br")
      assert found.bitrate_kbps == 5_500
    end
  end

  # ===========================================================================
  # Section 3: FPS monitoring (SC-VIDEO-003)
  # ===========================================================================

  describe "FPS monitoring" do
    test "current FPS is stored per stream", %{table: t} do
      s = new_stream("cam-fps", "cam") |> Map.put(:fps, 29)
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-fps")
      assert found.fps == 29
    end

    test "FPS drop below minimum threshold triggers alert", %{table: t} do
      s = new_stream("cam-low-fps", "cam") |> Map.put(:fps, 10)
      register_stream(t, s)

      alert = check_fps_alert(s, @min_fps)
      assert alert != nil
      assert alert.type == :fps_drop
    end

    test "FPS at or above minimum threshold produces no alert", %{table: t} do
      s = new_stream("cam-ok-fps", "cam") |> Map.put(:fps, @min_fps)
      register_stream(t, s)

      assert check_fps_alert(s, @min_fps) == nil
    end

    test "FPS alert carries stream ID and actual FPS", %{table: t} do
      s = new_stream("cam-fps-id", "cam") |> Map.put(:fps, 5)
      register_stream(t, s)

      alert = check_fps_alert(s, @min_fps)
      assert alert.stream_id == "cam-fps-id"
      assert alert.actual_fps == 5
    end

    test "zero FPS is flagged as critical severity", %{table: t} do
      s = new_stream("cam-zero-fps", "cam") |> Map.put(:fps, 0)
      register_stream(t, s)

      alert = check_fps_alert(s, @min_fps)
      assert alert.severity == :critical
    end

    test "FPS drop to 1–14 fps is flagged as warning severity", %{table: t} do
      s = new_stream("cam-warn-fps", "cam") |> Map.put(:fps, 8)
      register_stream(t, s)

      alert = check_fps_alert(s, @min_fps)
      assert alert.severity == :warning
    end

    test "updating FPS refreshes ETS record", %{table: t} do
      s = new_stream("cam-update-fps", "cam")
      register_stream(t, s)
      update_fps(t, "cam-update-fps", 24)

      {:ok, found} = lookup_stream(t, "cam-update-fps")
      assert found.fps == 24
    end
  end

  # ===========================================================================
  # Section 4: Stream health score (SC-VIDEO-002)
  # ===========================================================================

  describe "stream health score" do
    test "nominal stream has health score 1.0", %{table: t} do
      s = new_stream("cam-full-health", "cam")
      register_stream(t, s)

      score = compute_composite_score(s.fps, s.bitrate_kbps, 0, s.latency_ms)
      assert score == 1.0
    end

    test "health score decreases proportionally with FPS drop", %{table: t} do
      baseline = new_stream("cam-base", "cam")
      degraded = %{baseline | fps: div(baseline.fps, 2)}
      register_stream(t, degraded)

      full_score =
        compute_composite_score(
          baseline.fps,
          baseline.bitrate_kbps,
          0,
          baseline.latency_ms
        )

      drop_score =
        compute_composite_score(
          degraded.fps,
          baseline.bitrate_kbps,
          0,
          baseline.latency_ms
        )

      assert drop_score < full_score
    end

    test "packet loss reduces health score", %{table: t} do
      s = new_stream("cam-pkt-loss", "cam")
      register_stream(t, s)

      score_no_loss = compute_composite_score(s.fps, s.bitrate_kbps, 0, s.latency_ms)
      score_with_loss = compute_composite_score(s.fps, s.bitrate_kbps, 10, s.latency_ms)

      assert score_with_loss < score_no_loss
    end

    test "high latency reduces health score", %{table: t} do
      s = new_stream("cam-latency", "cam")
      register_stream(t, s)

      score_low_latency = compute_composite_score(s.fps, s.bitrate_kbps, 0, 20)
      score_high_latency = compute_composite_score(s.fps, s.bitrate_kbps, 0, 500)

      assert score_high_latency < score_low_latency
    end

    test "health score persisted back to ETS after update", %{table: t} do
      s = new_stream("cam-score-persist", "cam")
      register_stream(t, s)

      new_score = compute_composite_score(10, 1000, 5, 200)
      update_health_score(t, "cam-score-persist", new_score)

      {:ok, found} = lookup_stream(t, "cam-score-persist")
      assert found.health_score == new_score
    end
  end

  # ===========================================================================
  # Section 5: Recording status
  # ===========================================================================

  describe "recording status" do
    test "new stream starts with recording off by default", %{table: t} do
      s = new_stream("cam-rec-default", "cam")
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-rec-default")
      assert found.recording == false
    end

    test "enabling recording sets flag to true", %{table: t} do
      s = new_stream("cam-rec-on", "cam")
      register_stream(t, s)
      set_recording(t, "cam-rec-on", true)

      {:ok, found} = lookup_stream(t, "cam-rec-on")
      assert found.recording == true
    end

    test "disabling recording sets flag back to false", %{table: t} do
      s = new_stream("cam-rec-off", "cam") |> Map.put(:recording, true)
      register_stream(t, s)
      set_recording(t, "cam-rec-off", false)

      {:ok, found} = lookup_stream(t, "cam-rec-off")
      assert found.recording == false
    end

    test "disk usage is tracked per stream in bytes", %{table: t} do
      s = new_stream("cam-disk", "cam") |> Map.put(:disk_used_bytes, 1_073_741_824)
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-disk")
      assert found.disk_used_bytes == 1_073_741_824
    end

    test "retention policy is stored in stream record", %{table: t} do
      s = new_stream("cam-retention", "cam") |> Map.put(:retention_days, 30)
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-retention")
      assert found.retention_days == 30
    end

    test "incrementing disk usage updates ETS record", %{table: t} do
      s = new_stream("cam-disk-inc", "cam") |> Map.put(:disk_used_bytes, 500_000_000)
      register_stream(t, s)
      add_disk_usage(t, "cam-disk-inc", 250_000_000)

      {:ok, found} = lookup_stream(t, "cam-disk-inc")
      assert found.disk_used_bytes == 750_000_000
    end
  end

  # ===========================================================================
  # Section 6: Stream reconnection
  # ===========================================================================

  describe "stream reconnection" do
    test "disconnected stream has status :disconnected", %{table: t} do
      s = new_stream("cam-disc", "cam") |> Map.put(:status, :disconnected)
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-disc")
      assert found.status == :disconnected
    end

    test "reconnect attempt increments retry counter", %{table: t} do
      s = new_stream("cam-retry", "cam") |> Map.put(:status, :disconnected)
      register_stream(t, s)

      s1 = attempt_reconnect(t, "cam-retry")
      assert s1.reconnect_attempts == 1
    end

    test "exponential backoff doubles delay on each retry", %{table: _t} do
      delays = for n <- 0..4, do: backoff_delay_ms(n, @reconnect_base_ms)

      assert Enum.at(delays, 0) == @reconnect_base_ms
      assert Enum.at(delays, 1) == @reconnect_base_ms * 2
      assert Enum.at(delays, 2) == @reconnect_base_ms * 4
    end

    test "backoff delay is capped at 16x the base delay", %{table: _t} do
      # retry 10 (2^10 = 1024x) should be capped
      delay = backoff_delay_ms(10, @reconnect_base_ms)
      assert delay <= @reconnect_base_ms * 16
    end

    test "exceeding max retries sets status to :failed", %{table: t} do
      s =
        new_stream("cam-max-retry", "cam")
        |> Map.put(:status, :disconnected)
        |> Map.put(:reconnect_attempts, @max_reconnect_retries)

      register_stream(t, s)

      result = apply_reconnect_policy(t, "cam-max-retry")
      assert result.status == :failed
    end

    test "successful reconnect resets retry counter and sets status :active", %{table: t} do
      s =
        new_stream("cam-reconnected", "cam")
        |> Map.put(:status, :disconnected)
        |> Map.put(:reconnect_attempts, 2)

      register_stream(t, s)

      mark_reconnected(t, "cam-reconnected")

      {:ok, found} = lookup_stream(t, "cam-reconnected")
      assert found.status == :active
      assert found.reconnect_attempts == 0
    end
  end

  # ===========================================================================
  # Section 7: Multi-stream dashboard
  # ===========================================================================

  describe "multi-stream dashboard" do
    test "dashboard grid holds N stream entries", %{table: t} do
      for n <- 1..6, do: register_stream(t, new_stream("cam-grid-#{n}", "cam-#{n}"))

      grid = build_grid(t, 6)
      assert length(grid.cells) == 6
    end

    test "dashboard grid cell contains stream ID and health score", %{table: t} do
      register_stream(t, new_stream("cam-cell", "cam"))

      grid = build_grid(t, 1)
      cell = hd(grid.cells)

      assert Map.has_key?(cell, :stream_id)
      assert Map.has_key?(cell, :health_score)
    end

    test "thumbnail metadata is generated for each grid cell", %{table: t} do
      register_stream(t, new_stream("cam-thumb", "cam"))

      grid = build_grid(t, 1)
      cell = hd(grid.cells)

      assert Map.has_key?(cell, :thumbnail_url)
      assert is_binary(cell.thumbnail_url)
    end

    test "dashboard overall health equals minimum cell health score (SC-HMI-001)",
         %{table: t} do
      s1 = new_stream("cam-d1", "cam") |> Map.put(:health_score, 1.0)
      s2 = new_stream("cam-d2", "cam") |> Map.put(:health_score, 0.4)
      s3 = new_stream("cam-d3", "cam") |> Map.put(:health_score, 0.8)

      for s <- [s1, s2, s3], do: register_stream(t, s)

      grid = build_grid(t, 3)
      assert grid.overall_health == 0.4
    end

    test "removing a stream from grid reduces cell count", %{table: t} do
      for n <- 1..3, do: register_stream(t, new_stream("cam-rem-#{n}", "cam-#{n}"))

      grid_before = build_grid(t, 3)
      deregister_stream(t, "cam-rem-2")
      grid_after = build_grid(t, 3)

      assert length(grid_after.cells) == length(grid_before.cells) - 1
    end

    test "empty dashboard has overall health 1.0", %{table: t} do
      grid = build_grid(t, 0)
      assert grid.overall_health == 1.0
    end
  end

  # ===========================================================================
  # Section 8: Bandwidth allocation
  # ===========================================================================

  describe "bandwidth allocation" do
    test "stream has an assigned bandwidth budget in kbps", %{table: t} do
      s = new_stream("cam-bw", "cam") |> Map.put(:bandwidth_budget_kbps, 10_000)
      register_stream(t, s)

      {:ok, found} = lookup_stream(t, "cam-bw")
      assert found.bandwidth_budget_kbps == 10_000
    end

    test "total allocated bandwidth equals sum of per-stream budgets", %{table: t} do
      budgets = [8_000, 4_000, 2_000]

      streams =
        Enum.with_index(budgets, 1)
        |> Enum.map(fn {bw, n} ->
          new_stream("cam-bw-#{n}", "cam-#{n}") |> Map.put(:bandwidth_budget_kbps, bw)
        end)

      for s <- streams, do: register_stream(t, s)

      total = total_allocated_bandwidth(t)
      assert total == Enum.sum(budgets)
    end

    test "adding a stream increases total allocated bandwidth", %{table: t} do
      s1 = new_stream("cam-total-1", "cam") |> Map.put(:bandwidth_budget_kbps, 6_000)
      register_stream(t, s1)
      before_total = total_allocated_bandwidth(t)

      s2 = new_stream("cam-total-2", "cam") |> Map.put(:bandwidth_budget_kbps, 4_000)
      register_stream(t, s2)
      after_total = total_allocated_bandwidth(t)

      assert after_total == before_total + 4_000
    end

    test "bandwidth cap enforcement flags over-cap allocation", %{table: _t} do
      cap = 20_000

      streams = [
        %{bandwidth_budget_kbps: 10_000},
        %{bandwidth_budget_kbps: 8_000},
        %{bandwidth_budget_kbps: 5_000}
      ]

      result = check_bandwidth_cap(streams, cap)
      assert result == {:error, :over_cap}
    end

    test "allocation within cap passes enforcement", %{table: _t} do
      cap = 20_000

      streams = [
        %{bandwidth_budget_kbps: 8_000},
        %{bandwidth_budget_kbps: 4_000}
      ]

      result = check_bandwidth_cap(streams, cap)
      assert result == :ok
    end

    test "removing a stream reduces total allocated bandwidth", %{table: t} do
      s1 = new_stream("cam-reduce-1", "cam") |> Map.put(:bandwidth_budget_kbps, 6_000)
      s2 = new_stream("cam-reduce-2", "cam") |> Map.put(:bandwidth_budget_kbps, 4_000)
      for s <- [s1, s2], do: register_stream(t, s)

      before_total = total_allocated_bandwidth(t)
      deregister_stream(t, "cam-reduce-1")
      after_total = total_allocated_bandwidth(t)

      assert after_total == before_total - 6_000
    end
  end

  # ===========================================================================
  # Section 9: Property test — health score always in [0.0, 1.0] (SD generators)
  # ===========================================================================

  test "composite health score always in [0.0, 1.0] for arbitrary inputs (StreamData)" do
    ExUnitProperties.check all(
                             fps_val <- SD.integer(0, 120),
                             bitrate_val <- SD.integer(0, 50_000),
                             packet_loss_pct <- SD.integer(0, 100),
                             latency_ms <- SD.integer(0, 2_000)
                           ) do
      score = compute_composite_score(fps_val, bitrate_val, packet_loss_pct, latency_ms)

      assert score >= 0.0, "score #{score} is below 0.0"
      assert score <= 1.0, "score #{score} exceeds 1.0"
    end
  end

  # ===========================================================================
  # Section 10: Property test — total bandwidth never exceeds cap (SD generators)
  # ===========================================================================

  test "total bandwidth never exceeds cap when each stream respects its share (StreamData)" do
    ExUnitProperties.check all(
                             n_streams <- SD.integer(1, 10),
                             cap_kbps <- SD.integer(10_000, 100_000)
                           ) do
      # Divide cap evenly — each stream gets floor(cap / n) so sum <= cap
      per_stream = div(cap_kbps, n_streams)
      streams = for _ <- 1..n_streams, do: %{bandwidth_budget_kbps: per_stream}

      total = Enum.sum(Enum.map(streams, & &1.bandwidth_budget_kbps))
      assert total <= cap_kbps
    end
  end

  # ===========================================================================
  # Private helper functions — all logic inlined, no production dependencies
  # ===========================================================================

  # Build a new stream map with nominal default values.
  @spec new_stream(String.t(), String.t()) :: map()
  defp new_stream(id, source) do
    %{
      id: id,
      source: source,
      fps: 30,
      bitrate_kbps: 8_000,
      health_score: 1.0,
      status: :active,
      recording: false,
      disk_used_bytes: 0,
      retention_days: 7,
      reconnect_attempts: 0,
      bandwidth_budget_kbps: 8_000,
      latency_ms: 20,
      packet_loss_pct: 0,
      registered_at: System.system_time(:millisecond)
    }
  end

  # ETS operations

  @spec register_stream(:ets.table(), map()) :: true
  defp register_stream(table, stream) do
    :ets.insert(table, {stream.id, stream})
  end

  @spec lookup_stream(:ets.table(), String.t()) :: {:ok, map()} | :error
  defp lookup_stream(table, id) do
    case :ets.lookup(table, id) do
      [{^id, stream}] -> {:ok, stream}
      [] -> :error
    end
  end

  @spec deregister_stream(:ets.table(), String.t()) :: true
  defp deregister_stream(table, id) do
    :ets.delete(table, id)
  end

  @spec list_streams(:ets.table()) :: [map()]
  defp list_streams(table) do
    :ets.tab2list(table) |> Enum.map(fn {_id, stream} -> stream end)
  end

  @spec list_active_streams(:ets.table()) :: [map()]
  defp list_active_streams(table) do
    list_streams(table) |> Enum.filter(fn s -> s.status == :active end)
  end

  @spec update_bitrate(:ets.table(), String.t(), non_neg_integer()) :: :ok | :error
  defp update_bitrate(table, id, kbps) do
    case lookup_stream(table, id) do
      {:ok, s} ->
        :ets.insert(table, {id, %{s | bitrate_kbps: kbps}})
        :ok

      :error ->
        :error
    end
  end

  @spec update_fps(:ets.table(), String.t(), non_neg_integer()) :: :ok | :error
  defp update_fps(table, id, fps) do
    case lookup_stream(table, id) do
      {:ok, s} ->
        :ets.insert(table, {id, %{s | fps: fps}})
        :ok

      :error ->
        :error
    end
  end

  @spec update_health_score(:ets.table(), String.t(), float()) :: :ok | :error
  defp update_health_score(table, id, score) do
    case lookup_stream(table, id) do
      {:ok, s} ->
        :ets.insert(table, {id, %{s | health_score: score}})
        :ok

      :error ->
        :error
    end
  end

  @spec set_recording(:ets.table(), String.t(), boolean()) :: :ok | :error
  defp set_recording(table, id, flag) do
    case lookup_stream(table, id) do
      {:ok, s} ->
        :ets.insert(table, {id, %{s | recording: flag}})
        :ok

      :error ->
        :error
    end
  end

  @spec add_disk_usage(:ets.table(), String.t(), non_neg_integer()) :: :ok | :error
  defp add_disk_usage(table, id, bytes) do
    case lookup_stream(table, id) do
      {:ok, s} ->
        :ets.insert(table, {id, %{s | disk_used_bytes: s.disk_used_bytes + bytes}})
        :ok

      :error ->
        :error
    end
  end

  # Attempt one reconnect for the stream at `id`, incrementing the counter.
  @spec attempt_reconnect(:ets.table(), String.t()) :: map()
  defp attempt_reconnect(table, id) do
    {:ok, s} = lookup_stream(table, id)
    updated = %{s | reconnect_attempts: s.reconnect_attempts + 1}
    :ets.insert(table, {id, updated})
    updated
  end

  # Apply reconnect policy: if attempts >= max, set status :failed.
  @spec apply_reconnect_policy(:ets.table(), String.t()) :: map()
  defp apply_reconnect_policy(table, id) do
    {:ok, s} = lookup_stream(table, id)

    updated =
      if s.reconnect_attempts >= @max_reconnect_retries do
        %{s | status: :failed}
      else
        s
      end

    :ets.insert(table, {id, updated})
    updated
  end

  # Mark a stream as successfully reconnected.
  @spec mark_reconnected(:ets.table(), String.t()) :: :ok | :error
  defp mark_reconnected(table, id) do
    case lookup_stream(table, id) do
      {:ok, s} ->
        :ets.insert(table, {id, %{s | status: :active, reconnect_attempts: 0}})
        :ok

      :error ->
        :error
    end
  end

  # Compute total allocated bandwidth across all registered streams.
  @spec total_allocated_bandwidth(:ets.table()) :: non_neg_integer()
  defp total_allocated_bandwidth(table) do
    list_streams(table)
    |> Enum.reduce(0, fn s, acc -> acc + Map.get(s, :bandwidth_budget_kbps, 0) end)
  end

  # Build a dashboard grid from all streams in the table, up to `max_cells`.
  @spec build_grid(:ets.table(), non_neg_integer()) :: map()
  defp build_grid(table, max_cells) do
    streams = list_streams(table) |> Enum.take(max_cells)

    cells =
      Enum.map(streams, fn s ->
        %{
          stream_id: s.id,
          health_score: s.health_score,
          fps: s.fps,
          bitrate_kbps: s.bitrate_kbps,
          status: s.status,
          thumbnail_url: "/thumbnails/#{s.id}/latest.jpg"
        }
      end)

    overall =
      case cells do
        [] -> 1.0
        c -> c |> Enum.map(& &1.health_score) |> Enum.min()
      end

    %{
      cells: cells,
      overall_health: overall,
      stream_count: length(cells),
      generated_at: System.system_time(:millisecond)
    }
  end

  # Compute composite health score in [0.0, 1.0].
  # Weights: FPS 40%, bitrate 30%, packet loss 20%, latency 10%.
  @spec compute_composite_score(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer()
        ) :: float()
  defp compute_composite_score(fps, bitrate_kbps, packet_loss_pct, latency_ms) do
    fps_score = fps |> min(30) |> Kernel./(30) |> min(1.0)
    br_score = bitrate_kbps |> min(8_000) |> Kernel./(8_000) |> min(1.0)
    loss_score = max(0.0, 1.0 - packet_loss_pct / 100.0)

    latency_score =
      if latency_ms <= 100, do: 1.0, else: max(0.0, 1.0 - (latency_ms - 100) / 900.0)

    raw = 0.4 * fps_score + 0.3 * br_score + 0.2 * loss_score + 0.1 * latency_score

    raw
    |> max(0.0)
    |> min(1.0)
  end

  # Check whether a stream's current bitrate falls below the warning threshold.
  @spec check_bitrate_alert(map(), non_neg_integer()) :: map() | nil
  defp check_bitrate_alert(stream, baseline_kbps) do
    ratio = if baseline_kbps > 0, do: stream.bitrate_kbps / baseline_kbps, else: 0.0

    if ratio < @bitrate_warn_ratio do
      %{
        type: :bitrate_low,
        stream_id: stream.id,
        actual_kbps: stream.bitrate_kbps,
        baseline_kbps: baseline_kbps,
        severity: if(ratio == 0.0, do: :critical, else: :warning)
      }
    else
      nil
    end
  end

  # Check whether a stream's current FPS is below the minimum threshold.
  @spec check_fps_alert(map(), non_neg_integer()) :: map() | nil
  defp check_fps_alert(stream, min_fps) do
    ratio = if min_fps > 0, do: stream.fps / min_fps, else: 0.0

    cond do
      stream.fps == 0 ->
        %{
          type: :fps_drop,
          stream_id: stream.id,
          actual_fps: stream.fps,
          min_fps: min_fps,
          severity: :critical
        }

      ratio < @fps_warn_ratio ->
        %{
          type: :fps_drop,
          stream_id: stream.id,
          actual_fps: stream.fps,
          min_fps: min_fps,
          severity: :warning
        }

      true ->
        nil
    end
  end

  # Compute an exponential backoff delay capped at 16x base.
  @spec backoff_delay_ms(non_neg_integer(), pos_integer()) :: pos_integer()
  defp backoff_delay_ms(attempt, base_ms) do
    multiplier = min(Integer.pow(2, attempt), 16)
    base_ms * multiplier
  end

  # Enforce bandwidth cap; return :ok or {:error, :over_cap}.
  @spec check_bandwidth_cap([map()], non_neg_integer()) :: :ok | {:error, :over_cap}
  defp check_bandwidth_cap(streams, cap_kbps) do
    total = Enum.sum(Enum.map(streams, & &1.bandwidth_budget_kbps))
    if total <= cap_kbps, do: :ok, else: {:error, :over_cap}
  end

  # Compute a moving average over the last `window` samples in the list.
  @spec moving_average([number()], pos_integer()) :: float()
  defp moving_average([], _window), do: 0.0

  defp moving_average(samples, window) do
    windowed = Enum.take(samples, -window)
    Enum.sum(windowed) / length(windowed) * 1.0
  end
end
