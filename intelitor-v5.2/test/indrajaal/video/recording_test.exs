defmodule Indrajaal.Video.RecordingTest do
  use Indrajaal.DataCase

  alias Indrajaal.Core.Tenant
  alias Indrajaal.Sites.Site
  alias Indrajaal.Video.{Recording, Stream, Camera, Clip}

  describe "Recording resource" do
    setup do
      tenant = insert(:tenant)
      organization = insert(:organization, tenant: tenant)
      site = insert(:site, tenant: tenant, organization: organization)
      camera = insert(:camera, tenant: tenant, site: site)
      stream = insert(:stream, tenant: tenant, camera: camera)

      {:ok,
       tenant: tenant, organization: organization, site: site, camera: camera, stream: stream}
    end

    test "creates a recording with valid attributes",
         %{tenant: tenant, stream: stream} do
      attrs = %{
        filename: "recording_20241207_143022.mp4",
        file_path: "/recordings / 2024 / 12 / 07 / recording_20241207_143022.mp4",
        file_size: 1_024_000,
        duration: 300,
        start_time: DateTime.utc_now() |> DateTime.add(-300, :second),
        end_time: DateTime.utc_now(),
        status: :completed,
        recording_type: :motion_triggered,
        quality: :high,
        codec: "H.264",
        resolution: "1920x1080",
        fps: 30,
        bitrate: 2000,
        audio_included: true,
        stream_id: stream.id,
        tenant_id: tenant.id
      }

      {:ok, recording} = Recording.create(attrs)

      assert recording.filename == "recording_20241207_143022.mp4"
      assert recording.file_size == 1_024_000
      assert recording.duration == 300
      assert recording.status == :completed
      assert recording.recording_type == :motion_triggered
      assert recording.quality == :high
      assert recording.codec == "H.264"
      assert recording.resolution == "1920x1080"
      assert recording.fps == 30
      assert recording.bitrate == 2000
      assert recording.audio_included == true
      assert recording.stream_id == stream.id
      assert recording.tenant_id == tenant.id
    end

    test "validates required fields", %{tenant: tenant} do
      {:error, changeset} = Recording.create(%{tenant_id: tenant.id})

      assert changeset.errors[:filename]
      assert changeset.errors[:file_path]
      assert changeset.errors[:start_time]
      assert changeset.errors[:recording_type]
      assert changeset.errors[:stream_id]
    end

    test "validates recording type", %{tenant: tenant, stream: stream} do
      valid_types = [
        :continuous,
        :motion_triggered,
        :scheduled,
        :manual,
        :alarm_triggered,
        :event_based
      ]

      for type <- valid_types do
        {:ok, _recording} =
          Recording.create(%{
            filename: "test_#{type}.mp4",
            file_path: "/recordings / test_#{type}.mp4",
            start_time: DateTime.utc_now(),
            recording_type: type,
            stream_id: stream.id,
            tenant_id: tenant.id
          })
      end

      {:error, changeset} =
        Recording.create(%{
          filename: "test_invalid.mp4",
          file_path: "/recordings / test_invalid.mp4",
          start_time: DateTime.utc_now(),
          recording_type: :invalid_type,
          stream_id: stream.id,
          tenant_id: tenant.id
        })

      assert changeset.errors[:recording_type]
    end

    test "calculates duration from start and end times",
         %{tenant: tenant, stream: stream} do
      # 10 minutes ago
      start_time = DateTime.utc_now() |> DateTime.add(-600, :second)
      end_time = DateTime.utc_now()

      {:ok, recording} =
        Recording.create(%{
          filename: "duration_test.mp4",
          file_path: "/recordings / duration_test.mp4",
          start_time: start_time,
          end_time: end_time,
          recording_type: :continuous,
          stream_id: stream.id,
          tenant_id: tenant.id
        })

      recording_with_calc = Recording.read!(recording.id, load: [:calculated_duration])

      # Should be approximately 600 seconds (10 minutes)
      assert recording_with_calc.calculated_duration >= 590
      assert recording_with_calc.calculated_duration <= 610
    end

    test "starts a new recording", %{tenant: tenant, stream: stream} do
      {:ok, recording} =
        Recording.start_recording(stream, %{
          recording_type: :manual,
          quality: :high,
          filename: "manual_recording.mp4",
          # 30 minutes
          expected_duration: 1800
        })

      assert recording.status == :recording
      assert recording.recording_type == :manual
      assert recording.quality == :high
      assert recording.start_time
      assert recording.stream_id == stream.id
      assert recording.metadata["expected_duration"] == 1800
    end

    test "stops an active recording", %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :recording,
          # 2 minutes ago
          start_time: DateTime.utc_now() |> DateTime.add(-120, :second)
        )

      {:ok, stopped_recording} = Recording.stop_recording(recording)

      assert stopped_recording.status == :completed
      assert stopped_recording.end_time
      assert stopped_recording.duration > 0
    end

    test "manages recording retention", %{tenant: tenant, stream: stream} do
      # Old recording that should be eligible for deletion
      old_recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed,
          # 45 days ago
          start_time: DateTime.utc_now() |> DateTime.add(-45 * 86_400, :second),
          metadata: %{"retention_days" => 30}
        )

      # Recent recording that should be kept
      recent_recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed,
          # 15 days ago
          start_time: DateTime.utc_now() |> DateTime.add(-15 * 86_400, :second),
          metadata: %{"retention_days" => 30}
        )

      old_with_calc = Recording.read!(old_recording.id, load: [:should_be_deleted?])
      recent_with_calc = Recording.read!(recent_recording.id, load: [:should_be_deleted?])

      assert old_with_calc.should_be_deleted? == true
      assert recent_with_calc.should_be_deleted? == false
    end

    test "archives old recordings", %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed,
          file_path: "/recordings / active / video.mp4"
        )

      {:ok, archived_recording} =
        Recording.archive(recording, %{
          archive_location: "s3://backup - bucket / archived / video.mp4",
          compression_ratio: 0.75
        })

      assert archived_recording.status == :archived

      assert archived_recording.metadata["archive_location"] ==
               "s3://backup - bucket / archived / video.mp4"

      assert archived_recording.metadata["compression_ratio"] == 0.75
      assert archived_recording.metadata["archived_at"]
    end

    test "exports recordings to different formats",
         %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed,
          codec: "H.264",
          resolution: "1920x1080"
        )

      {:ok, exported_recording} =
        Recording.export(recording, %{
          export_format: "MP4",
          quality: :medium,
          include_audio: true,
          watermark: true,
          export_path: "/exports / evidence_export.mp4"
        })

      assert exported_recording.metadata["exports"]
      export_info = List.first(exported_recording.metadata["exports"])
      assert export_info["format"] == "MP4"
      assert export_info["quality"] == :medium
      assert export_info["watermark"] == true
      assert export_info["path"] == "/exports / evidence_export.mp4"
    end

    test "extracts clips from recordings", %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed,
          # 30 minutes
          duration: 1800,
          start_time: DateTime.utc_now() |> DateTime.add(-1800, :second)
        )

      {:ok, clip_recording} =
        Recording.extract_clip(recording, %{
          # 5 minutes into recording
          clip_start: 300,
          # 1 minute clip
          clip_duration: 60,
          clip_name: "Important Event",
          clip_description: "Security incident captured"
        })

      assert clip_recording.metadata["clips"]
      clip_info = List.first(clip_recording.metadata["clips"])
      assert clip_info["start_offset"] == 300
      assert clip_info["duration"] == 60
      assert clip_info["name"] == "Important Event"
    end

    test "manages recording encryption", %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed
        )

      {:ok, encrypted_recording} =
        Recording.encrypt(recording, %{
          encryption_algorithm: "AES - 256",
          key_management: "PKI",
          compliance_level: "government"
        })

      assert encrypted_recording.metadata["encryption"]["algorithm"] ==
               "AES - 256"

      assert encrypted_recording.metadata["encryption"]["key_management"] ==
               "PKI"

      assert encrypted_recording.metadata["encryption"]["compliance_level"] ==
               "government"

      assert encrypted_recording.metadata["encryption"]["encrypted_at"]
    end

    test "validates recording file integrity",
         %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed,
          metadata: %{"checksum" => "abc123def456"}
        )

      {:ok, validated_recording} = Recording.validate_integrity(recording)

      assert validated_recording.metadata["integrity_check"]
      integrity = validated_recording.metadata["integrity_check"]
      assert integrity["validated_at"]
      assert integrity["checksum_match"] in [true, false]
    end

    test "tracks recording storage usage", %{tenant: tenant, stream: stream} do
      # Create multiple recordings
      recording1 =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          # 1MB
          file_size: 1_024_000
        )

      recording2 =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          # 2MB
          file_size: 2_048_000
        )

      recording1_with_calc = Recording.read!(recording1.id, load: [:storage_efficiency])
      recording2_with_calc = Recording.read!(recording2.id, load: [:storage_efficiency])

      assert is_float(recording1_with_calc.storage_efficiency)
      assert is_float(recording2_with_calc.storage_efficiency)
    end

    test "handles recording playback configuration",
         %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed
        )

      playback_config = %{
        allow_streaming: true,
        require_authentication: true,
        max_concurrent_viewers: 5,
        allowed_ip_ranges: ["192.168.1.0 / 24", "10.0.0.0 / 8"],
        session_timeout: 3600
      }

      {:ok, configured_recording} =
        Recording.configure_playback(recording, %{
          playback_config: playback_config
        })

      assert configured_recording.playback_config["allow_streaming"] == true
      assert configured_recording.playback_config["max_concurrent_viewers"] == 5
      assert configured_recording.playback_config["session_timeout"] == 3600
    end

    test "manages recording access permissions",
         %{tenant: tenant, stream: stream} do
      recording =
        insert(:recording,
          stream: stream,
          tenant: tenant,
          status: :completed
        )

      user = insert(:user, tenant: tenant)
      role = insert(:role, tenant: tenant, name: "Security Officer")

      {:ok, secured_recording} =
        Recording.set_access_permissions(recording, %{
          access_level: "restricted",
          authorized_users: [user.id],
          authorized_roles: [role.id],
          audit_access: true
        })

      assert secured_recording.metadata["access_permissions"]["level"] ==
               "restricted"

      assert secured_recording.metadata["access_permissions"]["authorized_users"] == [user.id]

      assert secured_recording.metadata["access_permissions"]["audit_access"] ==
               true
    end

    test "enforces tenant isolation", %{stream: stream} do
      tenant1 = stream.tenant
      tenant2 = insert(:tenant)
      organization2 = insert(:organization, tenant: tenant2)
      site2 = insert(:site, tenant: tenant2, organization: organization2)
      camera2 = insert(:camera, tenant: tenant2, site: site2)
      stream2 = insert(:stream, tenant: tenant2, camera: camera2)

      recording1 = insert(:recording, tenant: tenant1, stream: stream)
      recording2 = insert(:recording, tenant: tenant2, stream: stream2)

      tenant1_recordings = Recording.read!(tenant: tenant1)
      tenant2_recordings = Recording.read!(tenant: tenant2)

      assert length(tenant1_recordings) == 1
      assert length(tenant2_recordings) == 1
      assert Enum.any?(tenant1_recordings, &(&1.id == recording1.id))
      assert Enum.any?(tenant2_recordings, &(&1.id == recording2.id))
      refute Enum.any?(tenant1_recordings, &(&1.id == recording2.id))
      refute Enum.any?(tenant2_recordings, &(&1.id == recording1.id))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
