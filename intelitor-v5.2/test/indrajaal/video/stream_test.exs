defmodule Indrajaal.Video.StreamTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.Tenant
  alias Indrajaal.Sites.Site
  alias Indrajaal.Video.{Stream, Camera, Recording}

  describe "Stream resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)
      camera = insert(:camera, tenant: tenant, site: site)

      {:ok, tenant: tenant, organization: organization, site: site, camera: camera}
    end

    test "creates a stream with valid attributes",
         %{tenant: tenant, camera: camera} do
      attrs = %{
        name: "Main Stream",
        stream_type: :primary,
        status: :active,
        url: "rtsp://192.168.1.100:554 / stream1",
        resolution: "1920x1080",
        fps: 30,
        bitrate: 2000,
        codec: "H.264",
        audio_enabled: true,
        quality: :high,
        camera_id: camera.id,
        tenant_id: tenant.id
      }

      {:ok, stream} = Stream.create(attrs)

      assert stream.name == "Main Stream"
      assert stream.stream_type == :primary
      assert stream.status == :active
      assert stream.url == "rtsp://192.168.1.100:554 / stream1"
      assert stream.resolution == "1920x1080"
      assert stream.fps == 30
      assert stream.bitrate == 2000
      assert stream.codec == "H.264"
      assert stream.audio_enabled == true
      assert stream.quality == :high
      assert stream.camera_id == camera.id
      assert stream.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Stream.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:stream_type]
      assert changeset.errors[:url]
      assert changeset.errors[:camera_id]
    end

    test "validates stream URL format", %{tenant: tenant, camera: camera} do
      valid_urls = [
        "rtsp://192.168.1.100:554 / stream1",
        "rtmps://secure.example.com / live / stream",
        "http://192.168.1.100:8080 / mjpeg",
        "https://streaming.example.com / hls / stream.m3u8"
      ]

      invalid_urls = [
        "not - a-url",
        "ftp://invalid.com / stream",
        "invalid://format",
        ""
      ]

      for url <- valid_urls do
        {:ok, _stream} =
          Stream.create(%{
            name: "Test Stream",
            stream_type: :primary,
            url: url,
            camera_id: camera.id,
            tenant_id: tenant.id
          })
      end

      for url <- invalid_urls do
        {:error, changeset} =
          Stream.create(%{
            name: "Test Stream",
            stream_type: :primary,
            url: url,
            camera_id: camera.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:url]
      end
    end

    test "validates stream type constraints",
         %{tenant: tenant, camera: camera} do
      # Create primary stream first
      {:ok, _primary} =
        Stream.create(%{
          name: "Primary Stream",
          stream_type: :primary,
          url: "rtsp://192.168.1.100:554 / stream1",
          camera_id: camera.id,
          tenant_id: tenant.id
        })

      # Should be able to create secondary stream
      {:ok, _secondary} =
        Stream.create(%{
          name: "Secondary Stream",
          stream_type: :secondary,
          url: "rtsp://192.168.1.100:554 / stream2",
          camera_id: camera.id,
          tenant_id: tenant.id
        })

      # Should NOT be able to create another primary stream for same camera
      {:error, changeset} =
        Stream.create(%{
          name: "Another Primary",
          stream_type: :primary,
          url: "rtsp://192.168.1.100:554 / stream3",
          camera_id: camera.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:stream_type]
    end

    test "starts and stops streaming", %{tenant: tenant, camera: camera} do
      stream =
        insert(:stream,
          camera: camera,
          tenant: tenant,
          status: :inactive
        )

      {:ok, started_stream} = Stream.start_streaming(stream)
      assert started_stream.status == :active
      assert started_stream.metadata["stream_started_at"]

      {:ok, stopped_stream} = Stream.stop_streaming(started_stream)
      assert stopped_stream.status == :inactive
      assert stopped_stream.metadata["stream_stopped_at"]
    end

    test "adjusts stream quality", %{tenant: tenant, camera: camera} do
      stream =
        insert(:stream,
          camera: camera,
          tenant: tenant,
          quality: :medium,
          resolution: "1280x720",
          fps: 15,
          bitrate: 1000
        )

      {:ok, hq_stream} = Stream.adjust_quality(stream, %{quality: :high})

      assert hq_stream.quality == :high
      assert hq_stream.resolution == "1920x1080"
      assert hq_stream.fps == 30
      assert hq_stream.bitrate == 2000

      {:ok, lq_stream} = Stream.adjust_quality(hq_stream, %{quality: :low})

      assert lq_stream.quality == :low
      assert lq_stream.resolution == "640x480"
      assert lq_stream.fps == 10
      assert lq_stream.bitrate == 500
    end

    test "tracks stream health and performance",
         %{tenant: tenant, camera: camera} do
      # Active healthy stream
      healthy_stream =
        insert(:stream,
          camera: camera,
          tenant: tenant,
          status: :active,
          last_frame_at: DateTime.utc_now() |> DateTime.add(-5, :second),
          metadata: %{
            "bitrate_actual" => 1950,
            "fps_actual" => 29,
            "frame_drops" => 2,
            "total_frames" => 1800
          }
        )

      healthy_with_calc = Stream.read!(healthy_stream.id, load: [:is_healthy?, :frame_drop_rate])
      assert healthy_with_calc.is_healthy? == true
      # Less than 1% drop rate
      assert healthy_with_calc.frame_drop_rate < 0.01

      # Unhealthy stream (high frame drops)
      unhealthy_stream =
        insert(:stream,
          camera: camera,
          tenant: tenant,
          status: :active,
          # 5 minutes ago
          last_frame_at: DateTime.utc_now() |> DateTime.add(-300, :second),
          metadata: %{
            "bitrate_actual" => 800,
            "fps_actual" => 15,
            "frame_drops" => 200,
            "total_frames" => 1000
          }
        )

      unhealthy_with_calc =
        Stream.read!(unhealthy_stream.id, load: [:is_healthy?, :frame_drop_rate])

      assert unhealthy_with_calc.is_healthy? == false
      # More than 10% drop rate
      assert unhealthy_with_calc.frame_drop_rate > 0.1
    end

    test "handles stream reconnection", %{tenant: tenant, camera: camera} do
      stream =
        insert(:stream,
          camera: camera,
          tenant: tenant,
          status: :error,
          metadata: %{
            "connection_failures" => 3,
            "last_error" => "Connection timeout"
          }
        )

      {:ok, reconnected_stream} =
        Stream.reconnect(stream, %{
          force_restart: true,
          timeout: 30
        })

      assert reconnected_stream.status == :active
      assert reconnected_stream.metadata["reconnection_attempts"]
      assert reconnected_stream.metadata["last_reconnect_at"]
    end

    test "configures adaptive bitrate", %{tenant: tenant, camera: camera} do
      stream = insert(:stream, camera: camera, tenant: tenant)

      {:ok, adaptive_stream} =
        Stream.configure_adaptive_bitrate(stream, %{
          enabled: true,
          min_bitrate: 500,
          max_bitrate: 3000,
          target_latency: 100
        })

      assert adaptive_stream.metadata["adaptive_bitrate"]["enabled"] == true
      assert adaptive_stream.metadata["adaptive_bitrate"]["min_bitrate"] == 500
      assert adaptive_stream.metadata["adaptive_bitrate"]["max_bitrate"] == 3000
    end

    test "manages stream recording configuration",
         %{tenant: tenant, camera: camera} do
      stream = insert(:stream, camera: camera, tenant: tenant)

      recording_config = %{
        auto_record: true,
        retention_days: 30,
        motion_triggered: true,
        continuous: false,
        pre_record_duration: 10,
        post_record_duration: 5
      }

      {:ok, configured_stream} =
        Stream.configure_recording(stream, %{
          recording_config: recording_config
        })

      assert configured_stream.recording_config["auto_record"] == true
      assert configured_stream.recording_config["retention_days"] == 30
      assert configured_stream.recording_config["motion_triggered"] == true
    end

    test "tracks bandwidth usage", %{tenant: tenant, camera: camera} do
      stream =
        insert(:stream,
          camera: camera,
          tenant: tenant,
          bitrate: 2000,
          metadata: %{
            # 1MB
            "bytes_transmitted" => 1_024_000,
            # 1 hour
            "transmission_duration" => 3600
          }
        )

      stream_with_calc = Stream.read!(stream.id, load: [:bandwidth_usage_mbps])

      # Should calculate bandwidth usage
      assert stream_with_calc.bandwidth_usage_mbps
      assert is_float(stream_with_calc.bandwidth_usage_mbps)
      assert stream_with_calc.bandwidth_usage_mbps > 0
    end

    test "enforces tenant isolation", %{camera: camera} do
      tenant1 = camera.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: organization2)
      camera2 = insert(:camera, tenant: tenant2, site: site2)

      stream1 = insert(:stream, tenant: tenant1, camera: camera)
      stream2 = insert(:stream, tenant: tenant2, camera: camera2)

      tenant1_streams = Stream.read!(tenant: tenant1)
      tenant2_streams = Stream.read!(tenant: tenant2)

      assert length(tenant1_streams) == 1
      assert length(tenant2_streams) == 1
      assert Enum.any?(tenant1_streams, &(&1.id == stream1.id))
      assert Enum.any?(tenant2_streams, &(&1.id == stream2.id))
      refute Enum.any?(tenant1_streams, &(&1.id == stream2.id))
      refute Enum.any?(tenant2_streams, &(&1.id == stream1.id))
    end

    test "validates stream encryption settings",
         %{tenant: tenant, camera: camera} do
      stream = insert(:stream, camera: camera, tenant: tenant)

      encryption_config = %{
        enabled: true,
        protocol: "SRTP",
        key_exchange: "DTLS",
        cipher_suite: "AES_128_CM_HMAC_SHA1_80"
      }

      {:ok, encrypted_stream} =
        Stream.configure_encryption(stream, %{
          encryption_config: encryption_config
        })

      assert encrypted_stream.encryption_config["enabled"] == true
      assert encrypted_stream.encryption_config["protocol"] == "SRTP"
      assert encrypted_stream.encryption_config["cipher_suite"] == "AES_128_CM_HMAC_SHA1_80"
    end

    test "handles stream analytics integration",
         %{tenant: tenant, camera: camera} do
      stream = insert(:stream, camera: camera, tenant: tenant)

      analytics_config = %{
        motion_detection: true,
        object_detection: true,
        facial_recognition: false,
        license_plate_recognition: true,
        crowd_detection: false
      }

      {:ok, analytics_stream} =
        Stream.configure_analytics(stream, %{
          analytics_config: analytics_config
        })

      assert analytics_stream.analytics_config["motion_detection"] == true
      assert analytics_stream.analytics_config["object_detection"] == true
      assert analytics_stream.analytics_config["facial_recognition"] == false
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
