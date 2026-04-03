defmodule Indrajaal.MCP.Domains.Video.Handler do
  @moduledoc """
  MCP Handler for Video domain.

  WHAT: Provides 14 tools for video surveillance, streaming, recordings, analytics,
        and privacy zones — wired to simulated camera/stream health data with
        realistic uptime, fps, resolution, and storage metrics.
  WHY: Enables AI assistants to manage video streams and query recording status
       with health metrics included in every response.
  CONSTRAINTS: SC-MCP-070, SC-MCP-071, SC-MCP-072, SC-VIDEO-001, SC-VIDEO-002,
               SC-VIDEO-003, SC-VIDEO-004, SC-VIDEO-005

  ## Tools Provided
  - indrajaal.video.cameras.list       - List cameras with health metrics
  - indrajaal.video.cameras.get        - Get camera details with uptime/fps/resolution
  - indrajaal.video.cameras.configure  - Configure camera settings (Guardian required)
  - indrajaal.video.stream.start       - Start a live stream
  - indrajaal.video.stream.stop        - Stop a live stream
  - indrajaal.video.recordings.list    - List recordings
  - indrajaal.video.recordings.get     - Get recording details
  - indrajaal.video.recordings.export  - Export recording (Guardian required)
  - indrajaal.video.snapshot           - Capture snapshot
  - indrajaal.video.analytics.status   - Get AI analytics status
  - indrajaal.video.analytics.configure - Configure analytics (Guardian required)
  - indrajaal.video.analytics.events   - Get analytics events
  - indrajaal.video.privacy_zones.list - List privacy zones (SC-VIDEO-002)
  - indrajaal.video.privacy_zones.set  - Set privacy zones (Guardian required)

  ## AOR Rules
  - AOR-VIDEO-001: Respect privacy zones in all operations
  - AOR-MCP-070: Register all tools on load

  ## Change History
  | Version | Date       | Author            | Change                                              |
  |---------|------------|-------------------|-----------------------------------------------------|
  | 21.3.0  | 2026-03-23 | Claude Sonnet 4.6 | Migrate to atom-dispatch; wire stream/recording health |
  | 21.2.0  | 2026-03-01 | Claude Sonnet 4.6 | Initial string-dispatch with Types.Tool struct      |
  """

  use Indrajaal.MCP.Domains.Handler, domain: :video

  alias Indrajaal.MCP.Foundation.Types

  require Logger

  # ETS table for active streams (session-scoped)
  @streams_table :mcp_video_streams

  # ---------------------------------------------------------------------------
  # list_tools/0
  # ---------------------------------------------------------------------------

  @impl true
  def list_tools do
    ns = "indrajaal.video"

    [
      # Camera Management
      Types.new_tool_schema(
        "#{ns}.cameras.list",
        "List all cameras with health metrics (uptime, fps, resolution)",
        %{
          type: "object",
          properties: %{
            "site_id" => %{type: "string", description: "Filter by site ID (optional)"},
            "zone_id" => %{type: "string", description: "Filter by zone ID (optional)"},
            "status" => %{
              type: "string",
              description: "Filter: online | offline | recording | error (optional)"
            },
            "limit" => %{type: "integer", description: "Max results (default 50)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{ns}.cameras.get",
        "Get detailed camera information including uptime, fps, resolution",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"}
          },
          required: ["camera_id"]
        }
      ),
      Types.new_tool_schema(
        "#{ns}.cameras.configure",
        "Configure camera settings (requires Guardian approval)",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"},
            "resolution" => %{
              type: "string",
              description: "Resolution: 720p | 1080p | 4k"
            },
            "fps" => %{type: "integer", description: "Frames per second (1-60)"},
            "compression" => %{
              type: "string",
              description: "Codec: h264 | h265 | mjpeg"
            },
            "night_mode" => %{type: "boolean", description: "Enable night mode"}
          },
          required: ["camera_id"]
        },
        requires_guardian: true
      ),

      # Streaming
      Types.new_tool_schema(
        "#{ns}.stream.start",
        "Start a live stream from a camera",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"},
            "quality" => %{
              type: "string",
              description: "Quality: low | medium | high | original"
            },
            "protocol" => %{type: "string", description: "Protocol: rtsp | hls | webrtc"}
          },
          required: ["camera_id"]
        }
      ),
      Types.new_tool_schema(
        "#{ns}.stream.stop",
        "Stop a live stream by stream ID",
        %{
          type: "object",
          properties: %{
            "stream_id" => %{type: "string", description: "Stream ID"}
          },
          required: ["stream_id"]
        }
      ),

      # Recordings
      Types.new_tool_schema(
        "#{ns}.recordings.list",
        "List recordings with filtering and storage metrics",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Filter by camera (optional)"},
            "from" => %{
              type: "string",
              description: "ISO 8601 start datetime (optional)"
            },
            "to" => %{
              type: "string",
              description: "ISO 8601 end datetime (optional)"
            },
            "has_events" => %{
              type: "boolean",
              description: "Only recordings with analytics events"
            },
            "limit" => %{type: "integer", description: "Max results (default 50)"}
          },
          required: []
        }
      ),
      Types.new_tool_schema(
        "#{ns}.recordings.get",
        "Get recording details and playback URL",
        %{
          type: "object",
          properties: %{
            "recording_id" => %{type: "string", description: "Recording ID"}
          },
          required: ["recording_id"]
        }
      ),
      Types.new_tool_schema(
        "#{ns}.recordings.export",
        "Export recording to file (requires Guardian approval)",
        %{
          type: "object",
          properties: %{
            "recording_id" => %{type: "string", description: "Recording ID"},
            "format" => %{type: "string", description: "Format: mp4 | mkv | avi"},
            "quality" => %{type: "string", description: "Quality: original | compressed"}
          },
          required: ["recording_id"]
        },
        requires_guardian: true
      ),

      # Snapshots
      Types.new_tool_schema(
        "#{ns}.snapshot",
        "Capture a snapshot from a camera",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"},
            "resolution" => %{
              type: "string",
              description: "Resolution: thumbnail | medium | full"
            }
          },
          required: ["camera_id"]
        }
      ),

      # Video Analytics
      Types.new_tool_schema(
        "#{ns}.analytics.status",
        "Get video analytics status and event counts for a camera",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"}
          },
          required: ["camera_id"]
        }
      ),
      Types.new_tool_schema(
        "#{ns}.analytics.configure",
        "Configure video analytics features (requires Guardian approval)",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"},
            "features" => %{
              type: "array",
              description:
                "Features: motion_detection | person_detection | vehicle_detection | " <>
                  "face_recognition | object_left | line_crossing | loitering"
            },
            "sensitivity" => %{type: "number", description: "Sensitivity 0.0-1.0"}
          },
          required: ["camera_id", "features"]
        },
        requires_guardian: true
      ),
      Types.new_tool_schema(
        "#{ns}.analytics.events",
        "Get analytics events detected by AI",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID (optional)"},
            "event_type" => %{type: "string", description: "Event type filter (optional)"},
            "from" => %{type: "string", description: "ISO 8601 start datetime (optional)"},
            "to" => %{type: "string", description: "ISO 8601 end datetime (optional)"},
            "limit" => %{type: "integer", description: "Max results (default 100)"}
          },
          required: []
        }
      ),

      # Privacy Zones (SC-VIDEO-002)
      Types.new_tool_schema(
        "#{ns}.privacy_zones.list",
        "List privacy zones for a camera (SC-VIDEO-002 compliance)",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"}
          },
          required: ["camera_id"]
        }
      ),
      Types.new_tool_schema(
        "#{ns}.privacy_zones.set",
        "Set privacy zones for a camera (requires Guardian approval — SC-VIDEO-002)",
        %{
          type: "object",
          properties: %{
            "camera_id" => %{type: "string", description: "Camera ID"},
            "zones" => %{
              type: "array",
              description: "Array of zone objects with name and polygon"
            }
          },
          required: ["camera_id", "zones"]
        },
        requires_guardian: true
      )
    ]
  end

  # ---------------------------------------------------------------------------
  # handle/3 — :cameras  (tool sub-action determined by args)
  # The dispatcher maps "indrajaal.video.cameras.list" -> :cameras_list etc.
  # but the Handler behaviour dispatches on the 3rd segment only (:cameras).
  # We implement separate actions for each sub-path.
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:cameras_list, args, context) do
    audit_log(@domain, :cameras_list, args, context)

    status_filter = Map.get(args, "status")
    limit = Map.get(args, "limit", 50)

    cameras =
      simulated_cameras()
      |> maybe_filter_status(status_filter)
      |> Enum.take(limit)

    success(%{
      cameras: cameras,
      total: length(cameras),
      filters: Map.take(args, ["site_id", "zone_id", "status"]),
      data_source: "simulated",
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @impl true
  def handle(:cameras_get, args, context) do
    audit_log(@domain, :cameras_get, args, context)

    with :ok <- validate_required(args, ["camera_id"]) do
      camera_id = Map.get(args, "camera_id")
      camera = build_camera_detail(camera_id)

      success(
        Map.merge(camera, %{
          data_source: "simulated",
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      )
    end
  end

  @impl true
  def handle(:cameras_configure, args, context) do
    audit_log(@domain, :cameras_configure, args, context)

    with :ok <- validate_required(args, ["camera_id"]) do
      camera_id = Map.get(args, "camera_id")
      settings = Map.drop(args, ["camera_id"])

      Logger.info("[Video.Handler] Camera #{camera_id} reconfigured: #{inspect(settings)}")

      success(%{
        camera_id: camera_id,
        configured: true,
        applied_settings: settings,
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  # ---------------------------------------------------------------------------
  # handle/3 — streams
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:stream_start, args, context) do
    audit_log(@domain, :stream_start, args, context)

    with :ok <- validate_required(args, ["camera_id"]) do
      camera_id = Map.get(args, "camera_id")
      stream_id = generate_id()
      ensure_ets_table(@streams_table)

      stream = %{
        stream_id: stream_id,
        camera_id: camera_id,
        url: "rtsp://localhost:8554/#{camera_id}",
        quality: Map.get(args, "quality", "high"),
        protocol: Map.get(args, "protocol", "rtsp"),
        started_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        fps: 30,
        resolution: "1080p",
        bitrate_kbps: 4096
      }

      :ets.insert(@streams_table, {stream_id, stream})
      Logger.info("[Video.Handler] Stream started: #{stream_id} for camera #{camera_id}")

      success(
        Map.merge(stream, %{
          data_source: "simulated",
          generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
        })
      )
    end
  end

  @impl true
  def handle(:stream_stop, args, context) do
    audit_log(@domain, :stream_stop, args, context)

    with :ok <- validate_required(args, ["stream_id"]) do
      stream_id = Map.get(args, "stream_id")
      ensure_ets_table(@streams_table)
      :ets.delete(@streams_table, stream_id)

      Logger.info("[Video.Handler] Stream stopped: #{stream_id}")

      success(%{
        stream_id: stream_id,
        stopped: true,
        stopped_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  # ---------------------------------------------------------------------------
  # handle/3 — recordings
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:recordings_list, args, context) do
    audit_log(@domain, :recordings_list, args, context)

    limit = Map.get(args, "limit", 50)
    recordings = simulated_recordings(Map.get(args, "camera_id"), limit)

    success(%{
      recordings: recordings,
      total: length(recordings),
      storage: storage_metrics(),
      filters: Map.take(args, ["camera_id", "from", "to", "has_events"]),
      data_source: "simulated",
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @impl true
  def handle(:recordings_get, args, context) do
    audit_log(@domain, :recordings_get, args, context)

    with :ok <- validate_required(args, ["recording_id"]) do
      recording_id = Map.get(args, "recording_id")
      now = DateTime.utc_now()
      start_time = DateTime.add(now, -3600, :second)

      success(%{
        id: recording_id,
        camera_id: "cam-001",
        duration_seconds: 3600,
        start_time: DateTime.to_iso8601(start_time),
        end_time: DateTime.to_iso8601(now),
        size_bytes: 1_073_741_824,
        resolution: "1080p",
        fps: 30,
        has_events: false,
        playback_url: "/api/v1/recordings/#{recording_id}/stream",
        thumbnail_url: "/api/v1/recordings/#{recording_id}/thumbnail",
        data_source: "simulated",
        generated_at: DateTime.to_iso8601(now)
      })
    end
  end

  @impl true
  def handle(:recordings_export, args, context) do
    audit_log(@domain, :recordings_export, args, context)

    with :ok <- validate_required(args, ["recording_id"]) do
      recording_id = Map.get(args, "recording_id")
      export_id = generate_id()

      Logger.info("[Video.Handler] Export initiated: #{export_id} for recording #{recording_id}")

      success(%{
        recording_id: recording_id,
        export_id: export_id,
        format: Map.get(args, "format", "mp4"),
        quality: Map.get(args, "quality", "original"),
        status: :processing,
        estimated_size_bytes: 524_288_000,
        download_url: "/api/v1/exports/#{export_id}/download",
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  # ---------------------------------------------------------------------------
  # handle/3 — snapshot
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:snapshot, args, context) do
    audit_log(@domain, :snapshot, args, context)

    with :ok <- validate_required(args, ["camera_id"]) do
      camera_id = Map.get(args, "camera_id")
      now = DateTime.utc_now()
      ts = DateTime.to_unix(now)

      success(%{
        camera_id: camera_id,
        snapshot_url: "/api/v1/snapshots/#{camera_id}/#{ts}.jpg",
        resolution: Map.get(args, "resolution", "full"),
        captured_at: DateTime.to_iso8601(now),
        width: 1920,
        height: 1080,
        size_bytes: 245_760,
        data_source: "simulated",
        generated_at: DateTime.to_iso8601(now)
      })
    end
  end

  # ---------------------------------------------------------------------------
  # handle/3 — analytics
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:analytics_status, args, context) do
    audit_log(@domain, :analytics_status, args, context)

    with :ok <- validate_required(args, ["camera_id"]) do
      camera_id = Map.get(args, "camera_id")

      success(%{
        camera_id: camera_id,
        enabled: true,
        features: ["motion_detection", "person_detection", "vehicle_detection"],
        sensitivity: 0.7,
        events_today: :rand.uniform(100),
        events_last_hour: :rand.uniform(20),
        model_version: "v2.4.1",
        inference_fps: 5.0,
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:analytics_configure, args, context) do
    audit_log(@domain, :analytics_configure, args, context)

    with :ok <- validate_required(args, ["camera_id", "features"]) do
      camera_id = Map.get(args, "camera_id")
      features = Map.get(args, "features")

      Logger.info(
        "[Video.Handler] Analytics configured for #{camera_id}: features=#{inspect(features)}"
      )

      success(%{
        camera_id: camera_id,
        features: features,
        sensitivity: Map.get(args, "sensitivity", 0.5),
        configured: true,
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:analytics_events, args, context) do
    audit_log(@domain, :analytics_events, args, context)

    limit = Map.get(args, "limit", 100)

    events =
      simulated_analytics_events(Map.get(args, "camera_id"), Map.get(args, "event_type"), limit)

    success(%{
      events: events,
      total: length(events),
      filters: Map.take(args, ["camera_id", "event_type", "from", "to"]),
      data_source: "simulated",
      generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  # ---------------------------------------------------------------------------
  # handle/3 — privacy zones (SC-VIDEO-002)
  # ---------------------------------------------------------------------------

  @impl true
  def handle(:privacy_zones_list, args, context) do
    audit_log(@domain, :privacy_zones_list, args, context)

    with :ok <- validate_required(args, ["camera_id"]) do
      camera_id = Map.get(args, "camera_id")

      success(%{
        camera_id: camera_id,
        zones: [],
        total: 0,
        note: "No privacy zones configured — SC-VIDEO-002 compliant",
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  @impl true
  def handle(:privacy_zones_set, args, context) do
    audit_log(@domain, :privacy_zones_set, args, context)

    with :ok <- validate_required(args, ["camera_id", "zones"]) do
      camera_id = Map.get(args, "camera_id")
      zones = Map.get(args, "zones", [])

      Logger.info(
        "[Video.Handler] Privacy zones updated for #{camera_id}: #{length(zones)} zones"
      )

      success(%{
        camera_id: camera_id,
        zones_count: length(zones),
        configured: true,
        note: "SC-VIDEO-002 privacy zone enforcement active",
        data_source: "simulated",
        generated_at: DateTime.utc_now() |> DateTime.to_iso8601()
      })
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers — simulated data
  # ---------------------------------------------------------------------------

  defp simulated_cameras do
    [
      %{
        id: "cam-001",
        name: "Main Entrance",
        site_id: "site-001",
        zone_id: "zone-entry",
        status: "recording",
        resolution: "1080p",
        fps: 30,
        uptime_seconds: 86_400,
        uptime_hours: 24.0,
        bitrate_kbps: 4096,
        compression: "h264",
        night_mode: false,
        analytics_enabled: true,
        ip: "192.168.1.100"
      },
      %{
        id: "cam-002",
        name: "Perimeter North",
        site_id: "site-001",
        zone_id: "zone-perimeter",
        status: "recording",
        resolution: "4k",
        fps: 25,
        uptime_seconds: 172_800,
        uptime_hours: 48.0,
        bitrate_kbps: 12_288,
        compression: "h265",
        night_mode: true,
        analytics_enabled: true,
        ip: "192.168.1.101"
      },
      %{
        id: "cam-003",
        name: "Server Room",
        site_id: "site-001",
        zone_id: "zone-secure",
        status: "online",
        resolution: "1080p",
        fps: 15,
        uptime_seconds: 604_800,
        uptime_hours: 168.0,
        bitrate_kbps: 2048,
        compression: "h264",
        night_mode: false,
        analytics_enabled: false,
        ip: "192.168.1.102"
      },
      %{
        id: "cam-004",
        name: "Parking Lot",
        site_id: "site-001",
        zone_id: "zone-external",
        status: "offline",
        resolution: "720p",
        fps: 0,
        uptime_seconds: 0,
        uptime_hours: 0.0,
        bitrate_kbps: 0,
        compression: "h264",
        night_mode: false,
        analytics_enabled: false,
        ip: "192.168.1.103"
      }
    ]
  end

  defp build_camera_detail(camera_id) do
    base =
      Enum.find(simulated_cameras(), &(&1.id == camera_id)) ||
        %{
          id: camera_id,
          name: "Camera #{camera_id}",
          site_id: "site-001",
          zone_id: "zone-unknown",
          status: "online",
          resolution: "1080p",
          fps: 30,
          uptime_seconds: 3600,
          uptime_hours: 1.0,
          bitrate_kbps: 4096,
          compression: "h264",
          night_mode: false,
          analytics_enabled: false,
          ip: "192.168.1.0"
        }

    Map.merge(base, %{
      last_seen: DateTime.utc_now() |> DateTime.to_iso8601(),
      storage_used_gb: 128.5,
      storage_total_gb: 1024.0,
      recordings_count: 720,
      firmware_version: "v3.2.1"
    })
  end

  defp maybe_filter_status(cameras, nil), do: cameras
  defp maybe_filter_status(cameras, status), do: Enum.filter(cameras, &(&1.status == status))

  defp simulated_recordings(camera_id, limit) do
    base_cameras = if camera_id, do: [camera_id], else: ["cam-001", "cam-002", "cam-003"]
    now = DateTime.utc_now()

    0..(min(limit, 10) - 1)
    |> Enum.map(fn i ->
      cam = Enum.at(base_cameras, rem(i, length(base_cameras)))
      start = DateTime.add(now, -(i + 1) * 3600, :second)
      stop = DateTime.add(now, -i * 3600, :second)

      %{
        id: "rec_#{cam}_#{i}",
        camera_id: cam,
        start_time: DateTime.to_iso8601(start),
        end_time: DateTime.to_iso8601(stop),
        duration_seconds: 3600,
        size_bytes: 1_073_741_824,
        resolution: "1080p",
        fps: 30,
        has_events: rem(i, 3) == 0
      }
    end)
  end

  defp storage_metrics do
    %{
      total_gb: 10_240.0,
      used_gb: 4_096.0,
      free_gb: 6_144.0,
      utilization_pct: 40.0,
      oldest_recording:
        DateTime.add(DateTime.utc_now(), -30 * 86_400, :second) |> DateTime.to_iso8601(),
      retention_days: 30
    }
  end

  defp simulated_analytics_events(camera_id, event_type, limit) do
    types = ["motion_detected", "person_detected", "vehicle_detected"]
    effective_type = event_type || "motion_detected"
    effective_camera = camera_id || "cam-001"
    now = DateTime.utc_now()

    0..(min(limit, 5) - 1)
    |> Enum.map(fn i ->
      t = Enum.at(types, rem(i, length(types)), effective_type)

      %{
        id: "evt_#{i}",
        camera_id: effective_camera,
        event_type: t,
        confidence: Float.round(0.7 + :rand.uniform() * 0.3, 2),
        detected_at: DateTime.add(now, -i * 300, :second) |> DateTime.to_iso8601(),
        bounding_box: %{x: 0.2, y: 0.3, width: 0.15, height: 0.4}
      }
    end)
  end

  defp ensure_ets_table(table) do
    if :ets.whereis(table) == :undefined do
      :ets.new(table, [:named_table, :public, :set])
    end
  rescue
    _ -> :ok
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
