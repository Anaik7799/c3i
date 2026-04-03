defmodule Indrajaal.Web.Live.VideoStreamHealthTest do
  @moduledoc """
  WHAT: Self-contained tests for LiveView video stream health monitor patterns
        tracking bitrate, FPS, quality scoring, and degradation detection —
        no production module dependencies required.
  WHY:  Validates stream creation, per-stream health scoring, FPS and bitrate
        correlation, degradation detection, and multi-stream dashboard state
        for the Prajna video monitoring panel (SC-VIDEO-001 to SC-VIDEO-005).

  ## STAMP Compliance
  - SC-VIDEO-001: Stream health state MUST be tracked per stream ID
  - SC-VIDEO-002: Health score MUST be in [0.0, 1.0] at all times
  - SC-VIDEO-003: FPS MUST be positive for any active stream
  - SC-VIDEO-004: Bitrate MUST correlate with quality tier classification
  - SC-VIDEO-005: Degradation MUST be detected within one scoring window

  ## Coverage Matrix
  | Concern                           | Unit | PropCheck | StreamData |
  |-----------------------------------|------|-----------|------------|
  | Stream creation/registration      | 1    | 0         | 0          |
  | Stream fields completeness        | 1    | 0         | 0          |
  | Health score computation          | 1    | 0         | 0          |
  | Health score bounds [0,1]         | 0    | 1         | 1          |
  | Bitrate quality tier mapping      | 1    | 0         | 0          |
  | Bitrate–quality correlation       | 0    | 1         | 1          |
  | FPS positivity invariant          | 0    | 1         | 1          |
  | FPS tracking across samples       | 1    | 0         | 0          |
  | Degradation detection (FPS drop)  | 1    | 0         | 0          |
  | Degradation detection (bitrate)   | 1    | 0         | 0          |
  | Degradation alert structure       | 1    | 0         | 0          |
  | Multi-stream dashboard aggregation| 1    | 0         | 0          |
  | Dashboard worst-case health       | 1    | 0         | 0          |
  | Stream removal from dashboard     | 1    | 0         | 0          |
  | Checkpoint message structure      | 1    | 0         | 0          |

  ## EP-GEN-014 compliance
  - `use PropCheck` provides forall/2 for `property` blocks (PropCheck-native).
  - StreamData `check all` blocks appear inside plain `test` blocks only.
  - PC. prefix for all PropCheck generators.
  - SD. prefix for all StreamData generators.
  """

  use ExUnit.Case, async: true

  # EP-GEN-014: dual property testing import pattern — MANDATORY
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @moduletag :video_stream_health
  @moduletag :video

  setup_all do
    Application.ensure_all_started(:propcheck)
    :ok
  end

  # ---------------------------------------------------------------------------
  # Section 1: Stream creation and registration (SC-VIDEO-001)
  # ---------------------------------------------------------------------------

  describe "stream creation" do
    test "new stream has all required fields" do
      stream = build_stream("stream-01", "camera-north", 1080)

      assert Map.has_key?(stream, :id)
      assert Map.has_key?(stream, :source)
      assert Map.has_key?(stream, :resolution_p)
      assert Map.has_key?(stream, :fps)
      assert Map.has_key?(stream, :bitrate_kbps)
      assert Map.has_key?(stream, :health_score)
      assert Map.has_key?(stream, :status)
      assert Map.has_key?(stream, :samples)
      assert Map.has_key?(stream, :started_at)
    end

    test "new stream starts with healthy status and full score" do
      stream = build_stream("stream-02", "camera-south", 720)

      assert stream.status == :active
      assert stream.health_score == 1.0
      assert stream.fps > 0
      assert stream.bitrate_kbps > 0
    end

    test "stream ID is preserved from input" do
      id = "stream-perimeter-04"
      stream = build_stream(id, "camera-perimeter", 480)

      assert stream.id == id
    end

    test "source name is preserved from input" do
      stream = build_stream("s1", "entrance-cam-1", 1080)

      assert stream.source == "entrance-cam-1"
    end

    test "resolution is stored correctly" do
      stream = build_stream("s1", "cam", 4320)

      assert stream.resolution_p == 4320
    end
  end

  # ---------------------------------------------------------------------------
  # Section 2: Health score computation (SC-VIDEO-002)
  # ---------------------------------------------------------------------------

  describe "health score computation" do
    test "nominal FPS and bitrate yield score 1.0" do
      stream = build_stream("s1", "cam", 1080)

      score =
        compute_health(
          stream.fps,
          stream.bitrate_kbps,
          expected_fps(1080),
          baseline_bitrate(1080)
        )

      assert score == 1.0
    end

    test "zero FPS yields minimum score 0.0" do
      baseline = baseline_bitrate(1080)

      score = compute_health(0, baseline, expected_fps(1080), baseline)

      assert score == 0.0
    end

    test "very low bitrate reduces score proportionally" do
      expected_f = expected_fps(720)
      baseline = baseline_bitrate(720)

      full_score = compute_health(expected_f, baseline, expected_f, baseline)
      low_score = compute_health(expected_f, div(baseline, 4), expected_f, baseline)

      assert low_score < full_score
    end

    test "score is clamped to 1.0 when metrics exceed baseline" do
      expected_f = expected_fps(1080)
      baseline = baseline_bitrate(1080)

      score = compute_health(expected_f * 2, baseline * 2, expected_f, baseline)

      assert score <= 1.0
    end

    test "score is clamped to 0.0 for negative-effective inputs" do
      score = compute_health(0, 0, expected_fps(720), baseline_bitrate(720))

      assert score >= 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 3: Health score bounds property (SC-VIDEO-002) — PropCheck
  # ---------------------------------------------------------------------------

  property "health score is always in [0.0, 1.0] for any FPS/bitrate", [:verbose] do
    forall {fps_ratio, br_ratio} <- {PC.non_neg_integer(), PC.non_neg_integer()} do
      expected_f = 30
      baseline = 4000

      actual_fps = fps_ratio
      actual_br = br_ratio

      score = compute_health(actual_fps, actual_br, expected_f, baseline)

      score >= 0.0 and score <= 1.0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 4: Health score bounds — StreamData check all
  # ---------------------------------------------------------------------------

  test "health score stays in [0.0, 1.0] across arbitrary inputs (StreamData)" do
    ExUnitProperties.check all(
                             fps_val <- SD.integer(0, 200),
                             br_val <- SD.integer(0, 50_000)
                           ) do
      score = compute_health(fps_val, br_val, 30, 4000)

      assert score >= 0.0, "score #{score} is below 0.0"
      assert score <= 1.0, "score #{score} exceeds 1.0"
    end
  end

  # ---------------------------------------------------------------------------
  # Section 5: Bitrate quality tier mapping (SC-VIDEO-004)
  # ---------------------------------------------------------------------------

  describe "bitrate quality tier classification" do
    test "bitrate above 8000 kbps is classified as :high" do
      assert classify_bitrate(8001) == :high
      assert classify_bitrate(15000) == :high
    end

    test "bitrate 2000–8000 kbps is classified as :medium" do
      assert classify_bitrate(2000) == :medium
      assert classify_bitrate(5000) == :medium
      assert classify_bitrate(8000) == :medium
    end

    test "bitrate below 2000 kbps is classified as :low" do
      assert classify_bitrate(0) == :low
      assert classify_bitrate(500) == :low
      assert classify_bitrate(1999) == :low
    end

    test "quality tier matches expected resolution baseline" do
      assert classify_bitrate(baseline_bitrate(1080)) == :high
      assert classify_bitrate(baseline_bitrate(720)) == :medium
      assert classify_bitrate(baseline_bitrate(480)) == :low
    end
  end

  # ---------------------------------------------------------------------------
  # Section 6: Bitrate–quality correlation property (SC-VIDEO-004) — PropCheck
  # ---------------------------------------------------------------------------

  property "higher bitrate never yields lower quality tier than lower bitrate" do
    forall {low_br, high_br} <- {PC.pos_integer(), PC.pos_integer()} do
      implies low_br < high_br do
        tier_low = classify_bitrate(low_br)
        tier_high = classify_bitrate(high_br)

        tier_rank(tier_high) >= tier_rank(tier_low)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Section 7: Bitrate–quality correlation — StreamData check all
  # ---------------------------------------------------------------------------

  test "higher bitrate always has equal or better quality tier (StreamData)" do
    ExUnitProperties.check all(
                             low_br <- SD.integer(1, 20_000),
                             delta <- SD.integer(1, 10_000)
                           ) do
      high_br = low_br + delta

      assert tier_rank(classify_bitrate(high_br)) >=
               tier_rank(classify_bitrate(low_br))
    end
  end

  # ---------------------------------------------------------------------------
  # Section 8: FPS tracking (SC-VIDEO-003)
  # ---------------------------------------------------------------------------

  describe "FPS tracking across samples" do
    test "rolling average FPS converges over samples" do
      samples = [30, 30, 29, 31, 30, 30, 28, 30]

      avg = rolling_avg_fps(samples)

      assert avg >= 28.0
      assert avg <= 32.0
    end

    test "single sample returns that sample value" do
      assert rolling_avg_fps([25]) == 25.0
    end

    test "FPS average is positive when all samples are positive" do
      samples = [24, 25, 30, 29, 28]

      assert rolling_avg_fps(samples) > 0.0
    end

    test "FPS tracking records latest sample" do
      stream = build_stream("s1", "cam", 720)
      updated = record_fps_sample(stream, 28)

      assert hd(updated.samples).fps == 28
    end

    test "sample list grows with each recorded observation" do
      stream = build_stream("s1", "cam", 720)
      s1 = record_fps_sample(stream, 30)
      s2 = record_fps_sample(s1, 29)
      s3 = record_fps_sample(s2, 28)

      assert length(s3.samples) == 3
    end
  end

  # ---------------------------------------------------------------------------
  # Section 9: FPS positivity property (SC-VIDEO-003) — PropCheck
  # ---------------------------------------------------------------------------

  property "rolling average FPS is positive for any non-empty positive sample list" do
    forall samples <- PC.non_empty(PC.list(PC.pos_integer())) do
      rolling_avg_fps(samples) > 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 10: FPS positivity — StreamData check all
  # ---------------------------------------------------------------------------

  test "rolling average FPS positive for non-empty positive list (StreamData)" do
    ExUnitProperties.check all(samples <- SD.list_of(SD.integer(1, 120), min_length: 1)) do
      assert rolling_avg_fps(samples) > 0.0
    end
  end

  # ---------------------------------------------------------------------------
  # Section 11: Degradation detection (SC-VIDEO-005)
  # ---------------------------------------------------------------------------

  describe "degradation detection" do
    test "FPS drop below threshold triggers degradation alert" do
      stream = build_stream("s1", "cam", 1080) |> Map.put(:fps, 5)

      alert = check_degradation(stream, expected_fps(1080), baseline_bitrate(1080))

      assert alert != nil
      assert alert.type == :fps_drop
      assert alert.stream_id == "s1"
    end

    test "bitrate drop below 50% of baseline triggers degradation alert" do
      baseline = baseline_bitrate(1080)
      stream = build_stream("s1", "cam", 1080) |> Map.put(:bitrate_kbps, div(baseline, 3))

      alert = check_degradation(stream, expected_fps(1080), baseline)

      assert alert != nil
      assert alert.type == :bitrate_drop
    end

    test "nominal stream returns no degradation alert" do
      stream = build_stream("s1", "cam", 720)

      alert = check_degradation(stream, expected_fps(720), baseline_bitrate(720))

      assert alert == nil
    end

    test "degradation alert includes severity field" do
      stream = build_stream("s1", "cam", 1080) |> Map.put(:fps, 3)

      alert = check_degradation(stream, expected_fps(1080), baseline_bitrate(1080))

      assert Map.has_key?(alert, :severity)
      assert alert.severity in [:warning, :critical]
    end

    test "complete FPS loss triggers critical severity" do
      stream = build_stream("s1", "cam", 1080) |> Map.put(:fps, 0)

      alert = check_degradation(stream, expected_fps(1080), baseline_bitrate(1080))

      assert alert.severity == :critical
    end

    test "partial FPS drop triggers warning severity" do
      exp_fps = expected_fps(720)
      # Drop to 40% of expected (below 50% threshold but not zero)
      stream = build_stream("s1", "cam", 720) |> Map.put(:fps, round(exp_fps * 0.4))

      alert = check_degradation(stream, exp_fps, baseline_bitrate(720))

      assert alert.severity == :warning
    end
  end

  # ---------------------------------------------------------------------------
  # Section 12: Multi-stream dashboard aggregation (SC-VIDEO-001)
  # ---------------------------------------------------------------------------

  describe "multi-stream dashboard" do
    test "dashboard aggregates multiple streams" do
      streams = [
        build_stream("s1", "cam-north", 1080),
        build_stream("s2", "cam-south", 720),
        build_stream("s3", "cam-east", 480)
      ]

      dashboard = build_dashboard(streams)

      assert length(dashboard.streams) == 3
    end

    test "dashboard computes overall health as minimum of stream scores" do
      s1 = build_stream("s1", "cam-north", 1080)
      s2 = build_stream("s2", "cam-south", 720) |> Map.put(:health_score, 0.4)
      s3 = build_stream("s3", "cam-east", 480)

      dashboard = build_dashboard([s1, s2, s3])

      assert dashboard.overall_health == 0.4
    end

    test "dashboard overall health is 1.0 when all streams are nominal" do
      streams = [
        build_stream("s1", "cam-a", 1080),
        build_stream("s2", "cam-b", 1080)
      ]

      dashboard = build_dashboard(streams)

      assert dashboard.overall_health == 1.0
    end

    test "removing a stream decreases stream count" do
      streams = [
        build_stream("s1", "cam-north", 1080),
        build_stream("s2", "cam-south", 720)
      ]

      dashboard = build_dashboard(streams)
      updated = remove_stream(dashboard, "s1")

      assert length(updated.streams) == 1
    end

    test "removing a stream does not affect remaining stream data" do
      s1 = build_stream("s1", "cam-north", 1080)
      s2 = build_stream("s2", "cam-south", 720)

      dashboard = build_dashboard([s1, s2])
      updated = remove_stream(dashboard, "s1")

      remaining = hd(updated.streams)
      assert remaining.id == "s2"
    end

    test "dashboard reports count of degraded streams" do
      s1 = build_stream("s1", "cam-a", 1080)
      s2 = build_stream("s2", "cam-b", 1080) |> Map.put(:health_score, 0.3)
      s3 = build_stream("s3", "cam-c", 720) |> Map.put(:health_score, 0.2)

      dashboard = build_dashboard([s1, s2, s3])

      assert dashboard.degraded_count == 2
    end
  end

  # ---------------------------------------------------------------------------
  # Section 13: Checkpoint message structure (SC-VIDEO-001, SC-ZTEST-001)
  # ---------------------------------------------------------------------------

  describe "checkpoint message structure" do
    test "checkpoint message follows CP-VIDEO-NN format" do
      msg = build_checkpoint_message("s1", :stream_started, 1.0)

      assert String.starts_with?(msg.checkpoint_id, "CP-VIDEO-")
    end

    test "checkpoint message contains stream_id" do
      msg = build_checkpoint_message("stream-42", :fps_drop_detected, 0.6)

      assert msg.stream_id == "stream-42"
    end

    test "checkpoint message has ISO 8601 timestamp" do
      msg = build_checkpoint_message("s1", :health_update, 0.9)

      assert is_binary(msg.timestamp)
      assert String.contains?(msg.timestamp, "T")
    end

    test "checkpoint message includes health_score field" do
      msg = build_checkpoint_message("s1", :health_update, 0.75)

      assert msg.health_score == 0.75
    end

    test "checkpoint message type matches event atom" do
      msg = build_checkpoint_message("s1", :bitrate_drop_detected, 0.5)

      assert msg.event == :bitrate_drop_detected
    end
  end

  # ---------------------------------------------------------------------------
  # Private helper functions (SC-VIDEO-001 to SC-VIDEO-005)
  # All production logic is inlined here — no external module dependencies.
  # ---------------------------------------------------------------------------

  # Build a stream map with nominal baseline values for the given resolution.
  defp build_stream(id, source, resolution_p) do
    exp_fps = expected_fps(resolution_p)
    baseline = baseline_bitrate(resolution_p)

    %{
      id: id,
      source: source,
      resolution_p: resolution_p,
      fps: exp_fps,
      bitrate_kbps: baseline,
      health_score: 1.0,
      status: :active,
      samples: [],
      started_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # Expected FPS target for a given resolution tier.
  # Higher resolutions may tolerate lower FPS before degradation.
  defp expected_fps(resolution_p) when resolution_p >= 1080, do: 30
  defp expected_fps(resolution_p) when resolution_p >= 720, do: 25
  defp expected_fps(_resolution_p), do: 20

  # Nominal baseline bitrate (kbps) for a resolution.
  defp baseline_bitrate(resolution_p) when resolution_p >= 2160, do: 20_000
  defp baseline_bitrate(resolution_p) when resolution_p >= 1080, do: 8_000
  defp baseline_bitrate(resolution_p) when resolution_p >= 720, do: 4_000
  defp baseline_bitrate(_resolution_p), do: 1_500

  # Compute health score in [0.0, 1.0] from actual vs expected metrics.
  # Score = 0.6 * fps_ratio + 0.4 * bitrate_ratio, clamped.
  defp compute_health(_actual_fps, _actual_br, 0, _baseline_br), do: 0.0
  defp compute_health(_actual_fps, _actual_br, _exp_fps, 0), do: 0.0

  defp compute_health(actual_fps, actual_br, exp_fps, baseline_br) do
    fps_ratio = min(1.0, actual_fps / exp_fps)
    br_ratio = min(1.0, actual_br / baseline_br)

    raw = 0.6 * fps_ratio + 0.4 * br_ratio

    raw
    |> max(0.0)
    |> min(1.0)
  end

  # Classify a bitrate (kbps) into a quality tier atom.
  defp classify_bitrate(kbps) when kbps > 8_000, do: :high
  defp classify_bitrate(kbps) when kbps >= 2_000, do: :medium
  defp classify_bitrate(_kbps), do: :low

  # Numeric rank for quality tier comparison (higher is better).
  defp tier_rank(:high), do: 2
  defp tier_rank(:medium), do: 1
  defp tier_rank(:low), do: 0

  # Compute rolling average FPS from a list of integer samples.
  defp rolling_avg_fps([]), do: 0.0

  defp rolling_avg_fps(samples) do
    Enum.sum(samples) / length(samples) * 1.0
  end

  # Record a new FPS sample onto the stream's sample list (prepend for O(1)).
  defp record_fps_sample(stream, fps_value) do
    sample = %{fps: fps_value, recorded_at: DateTime.utc_now() |> DateTime.to_iso8601()}
    %{stream | samples: [sample | stream.samples]}
  end

  # Check a stream for degradation against its expected baselines.
  # Returns a degradation alert map or nil if nominal.
  defp check_degradation(stream, exp_fps, baseline_br) do
    fps_ratio = if exp_fps > 0, do: stream.fps / exp_fps, else: 0.0
    br_ratio = if baseline_br > 0, do: stream.bitrate_kbps / baseline_br, else: 0.0

    cond do
      fps_ratio == 0.0 ->
        %{
          type: :fps_drop,
          stream_id: stream.id,
          severity: :critical,
          actual_fps: stream.fps,
          expected_fps: exp_fps
        }

      fps_ratio < 0.5 ->
        %{
          type: :fps_drop,
          stream_id: stream.id,
          severity: :warning,
          actual_fps: stream.fps,
          expected_fps: exp_fps
        }

      br_ratio < 0.5 ->
        %{
          type: :bitrate_drop,
          stream_id: stream.id,
          severity: :warning,
          actual_kbps: stream.bitrate_kbps,
          baseline_kbps: baseline_br
        }

      true ->
        nil
    end
  end

  # Build a multi-stream dashboard map from a list of stream maps.
  defp build_dashboard(streams) do
    overall =
      streams
      |> Enum.map(& &1.health_score)
      |> case do
        [] -> 0.0
        scores -> Enum.min(scores)
      end

    degraded =
      Enum.count(streams, fn s -> s.health_score < 0.5 end)

    %{
      streams: streams,
      overall_health: overall,
      degraded_count: degraded,
      updated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  # Remove a stream by ID from a dashboard, recomputing aggregates.
  defp remove_stream(dashboard, stream_id) do
    remaining = Enum.reject(dashboard.streams, fn s -> s.id == stream_id end)
    build_dashboard(remaining)
  end

  # Build a checkpoint message following SC-ZTEST-013 (CP-{DOMAIN}-{NN} format).
  defp build_checkpoint_message(stream_id, event, health_score) do
    suffix =
      case event do
        :stream_started -> "01"
        :health_update -> "02"
        :fps_drop_detected -> "03"
        :bitrate_drop_detected -> "04"
        _ -> "05"
      end

    %{
      checkpoint_id: "CP-VIDEO-#{suffix}",
      stream_id: stream_id,
      event: event,
      health_score: health_score,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      schema_version: "1.0.0"
    }
  end
end
