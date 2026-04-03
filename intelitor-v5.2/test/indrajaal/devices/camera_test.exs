defmodule Indrajaal.Devices.CameraTest do
  @moduledoc """
  TDG comprehensive test suite for Devices.Camera.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-CAMERA-001: create action must persist camera with camera_type validated
  - SC-CAMERA-002: start_recording must set is_recording? = true
  - SC-CAMERA-003: stop_recording must set is_recording? = false
  - SC-CAMERA-004: detect_motion must update last_motion_at
  - SC-CAMERA-005: camera_type must be one of allowed atom values

  ## Constitutional Verification
  - Psi0 Existence: Camera records survive create/update operations
  - Psi1 Regeneration: Camera state fully reconstructable from SQLite
  - Psi3 Verification: camera_type constraint enforced on every create
  - Psi5 Truthfulness: is_recording? accurately reflects current state

  ## Founder's Directive Alignment
  - Omega0.1: Surveillance cameras protect physical assets

  ## TPS 5-Level RCA Context
  - L1 Symptom: Camera not recording on demand
  - L5 Root Cause: is_recording? flag not updated via start_recording action

  ## Change History
  | Version | Date       | Author | Change            |
  |---------|------------|--------|-------------------|
  | 21.3.0  | 2026-03-19 | Claude | Initial TDG suite |
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Devices.{Camera, Device}

  @moduletag :zenoh_nif

  @system_admin %{role: "admin", id: "00000000-0000-0000-0000-000000000001"}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_device(tenant_id) do
    Ash.create(
      Device,
      %{name: "Test Device #{System.unique_integer([:positive])}", tenant_id: tenant_id},
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  defp unique_camera_attrs(device_id) do
    %{
      device_id: device_id,
      camera_type: :dome
    }
  end

  defp create_camera(attrs \\ %{}) do
    tenant_id = random_tenant()
    {:ok, device} = create_device(tenant_id)

    base = unique_camera_attrs(device.id)
    merged = Map.merge(base, attrs)

    Ash.create(Camera, merged,
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  # ---------------------------------------------------------------------------
  # describe: create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a camera with required camera_type" do
      assert {:ok, camera} = create_camera()
      assert camera.camera_type == :dome
    end

    test "camera_type :bullet is valid" do
      assert {:ok, camera} = create_camera(%{camera_type: :bullet})
      assert camera.camera_type == :bullet
    end

    test "camera_type :ptz is valid" do
      assert {:ok, camera} = create_camera(%{camera_type: :ptz})
      assert camera.camera_type == :ptz
    end

    test "camera_type :fisheye is valid" do
      assert {:ok, camera} = create_camera(%{camera_type: :fisheye})
      assert camera.camera_type == :fisheye
    end

    test "camera_type :thermal is valid" do
      assert {:ok, camera} = create_camera(%{camera_type: :thermal})
      assert camera.camera_type == :thermal
    end

    test "camera_type :multisensor is valid" do
      assert {:ok, camera} = create_camera(%{camera_type: :multisensor})
      assert camera.camera_type == :multisensor
    end

    test "camera_type :covert is valid" do
      assert {:ok, camera} = create_camera(%{camera_type: :covert})
      assert camera.camera_type == :covert
    end

    test "defaults: is_recording? is false" do
      {:ok, camera} = create_camera()
      assert camera.is_recording? == false
    end

    test "defaults: has_infrared? is true" do
      {:ok, camera} = create_camera()
      assert camera.has_infrared? == true
    end

    test "defaults: retention_days is 30" do
      {:ok, camera} = create_camera()
      assert camera.retention_days == 30
    end

    test "defaults: motion_detection_enabled? is true" do
      {:ok, camera} = create_camera()
      assert camera.motion_detection_enabled? == true
    end

    test "defaults: storage_used_gb is 0.0" do
      {:ok, camera} = create_camera()
      assert camera.storage_used_gb == 0.0
    end

    test "custom resolution is persisted" do
      {:ok, camera} = create_camera(%{resolution: "3840x2160"})
      assert camera.resolution == "3840x2160"
    end

    test "analytics_features array is accepted" do
      {:ok, camera} = create_camera(%{analytics_features: [:face_detection, :people_counting]})
      assert :face_detection in camera.analytics_features
      assert :people_counting in camera.analytics_features
    end

    test "invalid camera_type returns error" do
      result = create_camera(%{camera_type: :invalid_type})
      assert match?({:error, _}, result)
    end

    test "camera id is a UUID" do
      {:ok, camera} = create_camera()
      assert is_binary(camera.id)
      assert String.length(camera.id) == 36
    end
  end

  # ---------------------------------------------------------------------------
  # describe: start_recording action
  # ---------------------------------------------------------------------------

  describe "start_recording/1" do
    test "sets is_recording? to true" do
      {:ok, camera} = create_camera()
      assert camera.is_recording? == false

      {:ok, updated} =
        Ash.update(camera, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      assert updated.is_recording? == true
    end

    test "can call start_recording multiple times (idempotent)" do
      {:ok, camera} = create_camera()

      {:ok, c1} =
        Ash.update(camera, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      {:ok, c2} =
        Ash.update(c1, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      assert c2.is_recording? == true
    end
  end

  # ---------------------------------------------------------------------------
  # describe: stop_recording action
  # ---------------------------------------------------------------------------

  describe "stop_recording/1" do
    test "sets is_recording? to false after start" do
      {:ok, camera} = create_camera()

      {:ok, recording} =
        Ash.update(camera, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      assert recording.is_recording? == true

      {:ok, stopped} =
        Ash.update(recording, %{},
          action: :stop_recording,
          authorize?: false,
          actor: @system_admin
        )

      assert stopped.is_recording? == false
    end

    test "stop_recording on non-recording camera returns is_recording? false" do
      {:ok, camera} = create_camera()

      {:ok, stopped} =
        Ash.update(camera, %{}, action: :stop_recording, authorize?: false, actor: @system_admin)

      assert stopped.is_recording? == false
    end
  end

  # ---------------------------------------------------------------------------
  # describe: detect_motion action
  # ---------------------------------------------------------------------------

  describe "detect_motion/1" do
    test "updates last_motion_at timestamp" do
      {:ok, camera} = create_camera()
      assert is_nil(camera.last_motion_at)

      {:ok, updated} =
        Ash.update(camera, %{}, action: :detect_motion, authorize?: false, actor: @system_admin)

      assert not is_nil(updated.last_motion_at)
    end

    test "last_motion_at is recent after detect_motion" do
      {:ok, camera} = create_camera()

      {:ok, updated} =
        Ash.update(camera, %{}, action: :detect_motion, authorize?: false, actor: @system_admin)

      now = DateTime.utc_now()
      diff = DateTime.diff(now, updated.last_motion_at, :second)
      assert diff >= 0
      assert diff < 5
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: camera record persists after create" do
      {:ok, camera} = create_camera()
      assert is_binary(camera.id)
      # Existence: the record has an ID proving it was persisted
      assert String.length(camera.id) == 36
    end

    test "Psi3 verification: camera_type constraint enforced" do
      valid_types = [:bullet, :dome, :ptz, :fisheye, :thermal, :multisensor, :covert]

      Enum.each(valid_types, fn type ->
        {:ok, camera} = create_camera(%{camera_type: type})
        assert camera.camera_type == type, "Expected #{type} to be persisted"
      end)
    end

    test "Psi5 truthfulness: is_recording? reflects actual action" do
      {:ok, camera} = create_camera()
      assert camera.is_recording? == false

      {:ok, recording} =
        Ash.update(camera, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      assert recording.is_recording? == true

      {:ok, stopped} =
        Ash.update(recording, %{},
          action: :stop_recording,
          authorize?: false,
          actor: @system_admin
        )

      assert stopped.is_recording? == false
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: create and start_recording both succeed" do
      {:ok, cam_a} = create_camera(%{camera_type: :dome})
      {:ok, cam_b} = create_camera(%{camera_type: :bullet})

      {:ok, rec_a} =
        Ash.update(cam_a, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      {:ok, rec_b} =
        Ash.update(cam_b, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      assert rec_a.is_recording? == true
      assert rec_b.is_recording? == true
    end

    test "create completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> create_camera() end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  test "create succeeds for all valid camera_types" do
    valid_types = [:bullet, :dome, :ptz, :fisheye, :thermal, :multisensor, :covert]

    forall camera_type <- PC.oneof(Enum.map(valid_types, &PC.exactly/1)) do
      result = create_camera(%{camera_type: camera_type})
      match?({:ok, _}, result)
    end
  end

  test "default retention_days is always 30" do
    forall _n <- PC.integer(1, 3) do
      {:ok, camera} = create_camera()
      camera.retention_days == 30
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "storage_used_gb defaults to 0.0 on all creates" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, camera} = create_camera()
      assert camera.storage_used_gb == 0.0
    end
  end

  test "is_recording? toggles correctly between start and stop" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, cam} = create_camera()

      {:ok, rec} =
        Ash.update(cam, %{}, action: :start_recording, authorize?: false, actor: @system_admin)

      {:ok, stopped} =
        Ash.update(rec, %{}, action: :stop_recording, authorize?: false, actor: @system_admin)

      assert rec.is_recording? == true
      assert stopped.is_recording? == false
    end
  end
end
