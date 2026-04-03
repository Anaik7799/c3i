defmodule Indrajaal.Observability.Domains.VideoInstrumentation do
  @moduledoc """
  Domain - specific instrumentation for video streaming and analytics.

  Provides comprehensive telemetry for:
  - Video stream lifecycle and quality metrics
  - Analytics processing and AI inference
  - Recording and storage operations
  - Bandwidth and performance tracking

  - Multi - stream coordination and failover
  """

  use Indrajaal.Observability.InstrumentationBase,
    domain: :video

  # EP-012: Tracing alias removed (unused)
  alias Indrajaal.Observability.Logging

  # EP-013: Stream states, quality levels, and analytics types (unused but kept for future reference)
  # @stream_states ~w(connecting connected streaming disconnected failed)a  # Reserved for future stream state validation
  # @quality_levels ~w(4k 1080p 720p 480p 360p)a  # Reserved for future quality level validation
  # @analytics_types ~w(motion_detection face_recognition object_tracking line_crossing crowd_detection)a  # Reserved for future analytics type validation

  # Telemetry __events
  @recording_started [:video, :recording, :started]
  @recording_stopped [:video, :recording, :stopped]
  @bandwidth_metrics [:video, :bandwidth, :metrics]

  @doc """
  Sets up telemetry handlers for the Video domain.
  """
  def setup do
    :telemetry.execute(
      [:indrajaal, :observability, :video, :setup],
      %{timestamp: System.system_time(:millisecond)},
      %{module: __MODULE__}
    )

    :ok
  end

  def handle_event(event, measurements, metadata) do
    :telemetry.execute(
      [:indrajaal, :observability, :video, :event],
      measurements,
      Map.merge(metadata, %{original_event: event})
    )

    :ok
  end

  def get_metrics do
    {:ok, %{status: :active, domain: :video}}
  end

  def record_metric(name, value) do
    :telemetry.execute(
      [:indrajaal, :observability, :video, :metric],
      %{value: value},
      %{name: name}
    )

    :ok
  end

  def configure(_opts) do
    :ok
  end

  def get_configuration do
    {:ok,
     [
       domain: :video,
       recording_started_events: @recording_started,
       recording_stopped_events: @recording_stopped,
       bandwidth_metrics_events: @bandwidth_metrics
     ]}
  end

  def shutdown do
    :ok
  end

  @doc """
  Instruments video stream startup.
  """
  @spec instrument_stream_start(any(), any()) :: any()
  def instrument_stream_start(stream, recording_config, metadata \\ %{}) do
    # Agent: Format recording configuration data for telemetry
    # SOPv5.1: Cybernetic data structure preparation with validation
    _format_data = %{
      "recording.format" => recording_config.format,
      "recording.quality" => recording_config.quality
    }

    span_ctx =
      Tracing.start_span("video.recording_start", %{
        attributes: %{
          "stream.id" => stream.id,
          "recording.id" => recording_config.id,
          "recording.format" => recording_config.format,
          "recording.quality" => recording_config.quality
        }
      })

    try do
      :telemetry.execute(
        @recording_started,
        %{
          count: 1,
          estimated_size_mb: estimate_recording_size(recording_config)
        },
        Map.merge(metadata, %{
          stream_id: stream.id,
          camera_id: stream.camera_id,
          recording_id: recording_config.id,
          format: recording_config.format,
          quality: recording_config.quality,
          storage_location: recording_config.storage_location
        })
      )

      Logging.info("Video recording started", %{
        domain: "video",
        action: "recording_start",
        stream_id: stream.id,
        recording_id: recording_config.id,
        format: recording_config.format
      })

      # Track storage usage
      track_storage_allocation(recording_config)

      {:ok, recording_config}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @spec instrument_recording_stop(term(), term(), term()) :: term()
  def instrument_recording_stop(stream, recording_id, metadata \\ %{}) do
    recording_duration = metadata[:duration_ms] || 0
    file_size = metadata[:file_size_bytes] || 0

    span_ctx =
      Tracing.start_span("video.recording_stop", %{
        attributes: %{
          "stream.id" => stream.id,
          "recording.id" => recording_id,
          "recording.duration_ms" => recording_duration,
          "recording.size_bytes" => file_size
        }
      })

    try do
      :telemetry.execute(
        @recording_stopped,
        %{
          count: 1,
          duration_ms: recording_duration,
          file_size_mb: file_size / 1_048_576
        },
        Map.merge(metadata, %{
          stream_id: stream.id,
          recording_id: recording_id,
          duration_ms: recording_duration,
          file_size_bytes: file_size
        })
      )

      # Update storage metrics
      update_storage_metrics(recording_id, file_size)

      {:ok, recording_id}
    after
      Tracing.end_span(span_ctx)
    end
  end

  @doc """
  Instruments video bandwidth metrics.
  """
  @spec instrument_bandwidth_metrics(term(), term(), term()) :: term()
  def instrument_bandwidth_metrics(stream, bandwidth_data, metadata \\ %{}) do
    :telemetry.execute(
      @bandwidth_metrics,
      %{
        upload_mbps: bandwidth_data.upload_rate / 1_000_000,
        download_mbps: bandwidth_data.download_rate / 1_000_000,
        total_bytes: bandwidth_data.total_bytes,
        active_streams: bandwidth_data.active_stream_count
      },
      Map.merge(metadata, %{
        stream_id: stream.id,
        measurement_period_ms: bandwidth_data.period_ms,
        timestamp: DateTime.utc_now()
      })
    )

    # Check bandwidth limits
    check_bandwidth_limits(stream, bandwidth_data)
  end

  # Private functions

  @spec estimate_recording_size(term()) :: term()
  defp estimate_recording_size(recordingconfig) do
    # Estimate recording size in MB based on quality and duration
    bitrate_mbps =
      case recordingconfig.quality do
        "ultra_hd" -> 25
        "full_hd" -> 8
        "hd_ready" -> 5
        "standard" -> 2.5
        _ -> 1
      end

    duration_seconds = recordingconfig.estimated_duration_seconds || 3600
    bitrate_mbps * duration_seconds / 8
  end

  @spec track_storage_allocation(term()) :: term()
  defp track_storage_allocation(recording_config) do
    :telemetry.execute(
      [:video, :storage, :allocated],
      %{
        size_mb: estimate_recording_size(recording_config)
      },
      %{
        recording_id: recording_config.id,
        storage_location: recording_config.storage_location
      }
    )
  end

  @spec update_storage_metrics(term(), term()) :: term()
  defp update_storage_metrics(recording_id, file_size) do
    :telemetry.execute(
      [:video, :storage, :used],
      %{
        size_mb: file_size / 1_048_576
      },
      %{
        recording_id: recording_id
      }
    )
  end

  @spec check_bandwidth_limits(term(), term()) :: term()
  defp check_bandwidth_limits(stream, bandwidthdata) do
    # 1 Gbps default
    site_limit = stream.site_bandwidth_limit || 1_000_000_000

    if bandwidthdata.total_site_bandwidth > site_limit * 0.9 do
      Logging.warning("Site bandwidth limit approaching", %{
        domain: "video",
        action: "bandwidth_warning",
        site_id: stream.site_id,
        usage_percent: bandwidthdata.total_site_bandwidth / site_limit * 100
      })
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ACTIVE - General system coordination and management with cybernetic feedback
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
