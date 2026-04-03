defmodule Indrajaal.Video.CameraTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.Tenant
  alias Indrajaal.Sites.Site
  alias Indrajaal.Video.{Camera, Stream, Recording}

  describe "Camera resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)

      {:ok, tenant: tenant, organization: organization, site: site}
    end

    test "creates a camera with valid attributes",
         %{tenant: tenant, site: site} do
      attrs = %{
        name: "Main Entrance Camera",
        serial_number: "CAM - VID - 001",
        manufacturer: "VideoTech",
        model: "VT - 4K - PTZ",
        resolution: "4K",
        fps: 30,
        ptz_capable: true,
        night_vision: true,
        audio_enabled: true,
        stream_url: "rtsp://192.168.1.100 / stream1",
        backup_stream_url: "rtsp://192.168.1.100 / stream2",
        status: :online,
        position: %{
          "pan" => 0,
          "tilt" => 0,
          "zoom" => 1.0
        },
        field_of_view: %{
          "horizontal" => 110,
          "vertical" => 60
        },
        site_id: site.id,
        tenant_id: tenant.id
      }

      {:ok, camera} = Camera.create(attrs)

      assert camera.name == "Main Entrance Camera"
      assert camera.serial_number == "CAM - VID - 001"
      assert camera.resolution == "4K"
      assert camera.fps == 30
      assert camera.ptz_capable == true
      assert camera.status == :online
      assert camera.position["pan"] == 0
      assert camera.field_of_view["horizontal"] == 110
      assert camera.site_id == site.id
      assert camera.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Camera.create(%{tenant_id: tenant.id})

      assert changeset.errors[:name]
      assert changeset.errors[:serial_number]
      assert changeset.errors[:site_id]
      assert changeset.errors[:stream_url]
    end

    test "validates unique serial number per tenant",
         %{tenant: tenant, site: site} do
      insert(:camera,
        serial_number: "UNIQUE - CAM-123",
        tenant: tenant,
        site: site
      )

      {:error, changeset} =
        Camera.create(%{
          name: "Another Camera",
          serial_number: "UNIQUE - CAM-123",
          stream_url: "rtsp://192.168.1.101 / stream",
          site_id: site.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:serial_number]
    end

    test "validates stream URL format", %{tenant: tenant, site: site} do
      valid_urls = [
        "rtsp://192.168.1.100 / stream1",
        "rtmps://secure.example.com / live / stream",
        "http://192.168.1.100:8080 / mjpeg"
      ]

      invalid_urls = [
        "not - a-url",
        "ftp://invalid.com / stream",
        "invalid://format"
      ]

      for url <- valid_urls do
        {:ok, _camera} =
          Camera.create(%{
            name: "Test Camera",
            serial_number: "TEST-#{System.unique_integer()}",
            stream_url: url,
            site_id: site.id,
            tenant_id: tenant.id
          })
      end

      for url <- invalid_urls do
        {:error, changeset} =
          Camera.create(%{
            name: "Test Camera",
            serial_number: "TEST-#{System.unique_integer()}",
            stream_url: url,
            site_id: site.id,
            tenant_id: tenant.id
          })

        assert changeset.errors[:stream_url]
      end
    end

    test "controls PTZ movements", %{tenant: tenant, site: site} do
      camera =
        insert(:camera,
          ptz_capable: true,
          position: %{"pan" => 0, "tilt" => 0, "zoom" => 1.0},
          tenant: tenant,
          site: site
        )

      {:ok, moved_camera} =
        Camera.ptz_control(camera, %{
          pan: 45,
          tilt: -15,
          zoom: 2.5
        })

      assert moved_camera.position["pan"] == 45
      assert moved_camera.position["tilt"] == -15
      assert moved_camera.position["zoom"] == 2.5

      # Check movement history
      assert moved_camera.metadata["ptz_history"]
      history_entry = List.first(moved_camera.metadata["ptz_history"])
      assert history_entry["from_position"]
      assert history_entry["to_position"]
      assert history_entry["timestamp"]
    end

    test "sets camera presets", %{tenant: tenant, site: site} do
      camera =
        insert(:camera,
          ptz_capable: true,
          tenant: tenant,
          site: site
        )

      {:ok, camera_with_preset} =
        Camera.create_preset(camera, %{
          preset_name: "entrance_view",
          pan: 90,
          tilt: -10,
          zoom: 1.5,
          description: "View of main entrance"
        })

      assert camera_with_preset.metadata["presets"]
      preset = List.first(camera_with_preset.metadata["presets"])
      assert preset["name"] == "entrance_view"
      assert preset["pan"] == 90
      assert preset["description"] == "View of main entrance"

      # Test recall preset
      {:ok, recalled_camera} =
        Camera.recall_preset(camera_with_preset, %{
          preset_name: "entrance_view"
        })

      assert recalled_camera.position["pan"] == 90
      assert recalled_camera.position["tilt"] == -10
      assert recalled_camera.position["zoom"] == 1.5
    end

    test "starts and stops recording", %{tenant: tenant, site: site} do
      camera =
        insert(:camera,
          status: :online,
          tenant: tenant,
          site: site
        )

      {:ok, recording_camera} =
        Camera.start_recording(camera, %{
          recording_type: "motion_triggered",
          quality: "high",
          duration_limit: 3600
        })

      assert recording_camera.metadata["recording_active"] == true
      assert recording_camera.metadata["recording_config"]["type"] == "motion_triggered"

      {:ok, stopped_camera} = Camera.stop_recording(recording_camera)
      assert stopped_camera.metadata["recording_active"] == false
    end

    test "manages camera analytics settings", %{tenant: tenant, site: site} do
      camera = insert(:camera, tenant: tenant, site: site)

      analytics_config = %{
        "motion_detection" => %{
          "enabled" => true,
          "sensitivity" => 75,
          "zones" => [
            %{"name" => "entrance", "coordinates" => [[0, 0], [100, 100]]}
          ]
        },
        "object_detection" => %{
          "enabled" => true,
          "types" => ["person", "vehicle"],
          "confidence_threshold" => 0.8
        },
        "facial_recognition" => %{
          "enabled" => false,
          "database" => "employees"
        }
      }

      {:ok, analytics_camera} =
        Camera.configure_analytics(camera, %{
          analytics_config: analytics_config
        })

      assert analytics_camera.analytics_config["motion_detection"]["enabled"] ==
               true

      assert analytics_camera.analytics_config["object_detection"]["confidence_threshold"] ==
               0.8

      assert analytics_camera.analytics_config["facial_recognition"]["enabled"] ==
               false
    end

    test "tracks camera health and connectivity",
         %{tenant: tenant, site: site} do
      # Healthy camera
      healthy_camera =
        insert(:camera,
          status: :online,
          # 1 minute ago
          last_ping_at: DateTime.utc_now() |> DateTime.add(-60, :second),
          tenant: tenant,
          site: site
        )

      healthy_with_calc = Camera.read!(healthy_camera.id, load: [:is_healthy?])
      assert healthy_with_calc.is_healthy? == true

      # Unhealthy camera (offline for too long)
      unhealthy_camera =
        insert(:camera,
          status: :offline,
          # 1 hour ago
          last_ping_at: DateTime.utc_now() |> DateTime.add(-3600, :second),
          tenant: tenant,
          site: site
        )

      unhealthy_with_calc = Camera.read!(unhealthy_camera.id, load: [:is_healthy?])
      assert unhealthy_with_calc.is_healthy? == false
    end

    test "calculates uptime statistics", %{tenant: tenant, site: site} do
      camera =
        insert(:camera,
          status: :online,
          # 2 hours ago
          last_seen_at: DateTime.utc_now() |> DateTime.add(-7200, :second),
          tenant: tenant,
          site: site
        )

      camera_with_calc = Camera.read!(camera.id, load: [:uptime_percentage])
      assert is_float(camera_with_calc.uptime_percentage)
      assert camera_with_calc.uptime_percentage >= 0.0
      assert camera_with_calc.uptime_percentage <= 100.0
    end

    test "manages camera maintenance schedules",
         %{tenant: tenant, site: site} do
      camera = insert(:camera, tenant: tenant, site: site)

      {:ok, scheduled_camera} =
        Camera.schedule_maintenance(camera, %{
          maintenance_type: "lens_cleaning",
          # Tomorrow
          scheduled_for: DateTime.utc_now() |> DateTime.add(86_400, :second),
          estimated_duration: 30,
          notes: "Regular lens cleaning and calibration"
        })

      assert scheduled_camera.metadata["maintenance_schedule"]
      maintenance = List.first(scheduled_camera.metadata["maintenance_schedule"])
      assert maintenance["type"] == "lens_cleaning"
      assert maintenance["duration"] == 30
    end

    test "handles camera alerts and notifications",
         %{tenant: tenant, site: site} do
      camera = insert(:camera, tenant: tenant, site: site)

      {:ok, camera_with_alert} =
        Camera.add_alert(camera, %{
          alert_type: "connection_lost",
          severity: "critical",
          message: "Camera connection lost",
          auto_resolve: false
        })

      assert camera_with_alert.metadata["active_alerts"]
      alert = List.first(camera_with_alert.metadata["active_alerts"])
      assert alert["type"] == "connection_lost"
      assert alert["severity"] == "critical"

      {:ok, resolved_camera} =
        Camera.resolve_alert(camera_with_alert, %{
          alert_type: "connection_lost",
          resolution_notes: "Connection restored"
        })

      assert resolved_camera.metadata["resolved_alerts"]
      resolved_alert = List.first(resolved_camera.metadata["resolved_alerts"])
      assert resolved_alert["type"] == "connection_lost"
      assert resolved_alert["resolution_notes"] == "Connection restored"
    end

    test "configures camera stream quality", %{tenant: tenant, site: site} do
      camera = insert(:camera, tenant: tenant, site: site)

      stream_config = %{
        "primary_stream" => %{
          "resolution" => "1920x1080",
          "fps" => 30,
          "bitrate" => 2000,
          "codec" => "H.264"
        },
        "secondary_stream" => %{
          "resolution" => "640x480",
          "fps" => 15,
          "bitrate" => 500,
          "codec" => "H.264"
        }
      }

      {:ok, configured_camera} =
        Camera.configure_streams(camera, %{
          stream_config: stream_config
        })

      assert configured_camera.stream_config["primary_stream"]["resolution"] ==
               "1920x1080"

      assert configured_camera.stream_config["secondary_stream"]["fps"] == 15
    end

    test "enforces tenant isolation", %{site: site} do
      tenant1 = site.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: organization2)

      camera1 = insert(:camera, tenant: tenant1, site: site)
      camera2 = insert(:camera, tenant: tenant2, site: site2)

      tenant1_cameras = Camera.read!(tenant: tenant1)
      tenant2_cameras = Camera.read!(tenant: tenant2)

      assert length(tenant1_cameras) == 1
      assert length(tenant2_cameras) == 1
      assert Enum.any?(tenant1_cameras, &(&1.id == camera1.id))
      assert Enum.any?(tenant2_cameras, &(&1.id == camera2.id))
      refute Enum.any?(tenant1_cameras, &(&1.id == camera2.id))
      refute Enum.any?(tenant2_cameras, &(&1.id == camera1.id))
    end

    test "validates camera firmware updates", %{tenant: tenant, site: site} do
      camera =
        insert(:camera,
          firmware_version: "1.0.0",
          tenant: tenant,
          site: site
        )

      {:ok, updated_camera} =
        Camera.update_firmware(camera, %{
          firmware_version: "1.1.0",
          update_notes: "Security patches and new features",
          reboot_required: true
        })

      assert updated_camera.firmware_version == "1.1.0"
      assert updated_camera.metadata["firmware_update_history"]

      update_record = List.first(updated_camera.metadata["firmware_update_history"])
      assert update_record["from_version"] == "1.0.0"
      assert update_record["to_version"] == "1.1.0"
      assert update_record["reboot_required"] == true
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
