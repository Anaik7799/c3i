defmodule Indrajaal.Devices.DeviceTypeTest do
  @moduledoc """
  TDG comprehensive test suite for Devices.DeviceType.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-DT-001: create must validate :code matches ^[A-Z][A-Z0-9_-]*$ pattern
  - SC-DT-002: :camera category requires "video_capture" capability
  - SC-DT-003: :sensor category requires "detection" capability
  - SC-DT-004: :panel category requires "alarm_control" capability
  - SC-DT-005: :reader category requires "access_control" capability
  - SC-DT-006: archive action is soft delete (sets active? = false)

  ## Constitutional Verification
  - Psi0 Existence: DeviceType record persists after all lifecycle actions
  - Psi3 Verification: Category+capability constraint is always enforced
  - Psi5 Truthfulness: active? accurately reflects archive/activate state

  ## Founder's Directive Alignment
  - Omega0.1: Device type taxonomy enables systematic security coverage

  ## TPS 5-Level RCA Context
  - L1 Symptom: Camera DeviceType created without required video_capture capability
  - L5 Root Cause: Category capability validation not applied on create

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
  alias Indrajaal.Devices.DeviceType

  @moduletag :zenoh_nif

  @system_admin %{role: "admin", id: "00000000-0000-0000-0000-000000000004"}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_code do
    # Code must match ^[A-Z][A-Z0-9_-]*$ and be >= 2 chars
    "DT#{System.unique_integer([:positive]) |> Integer.to_string() |> String.upcase()}"
  end

  defp create_device_type(attrs \\ %{}) do
    tenant_id = random_tenant()

    base = %{
      name: "Test Device Type #{System.unique_integer([:positive])}",
      code: unique_code(),
      category: :other,
      tenant_id: tenant_id
    }

    merged = Map.merge(base, attrs)

    Ash.create(DeviceType, merged,
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  # ---------------------------------------------------------------------------
  # describe: create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a device_type with required fields" do
      assert {:ok, dt} = create_device_type()
      assert not is_nil(dt.id)
    end

    test "code is persisted correctly" do
      code = unique_code()
      {:ok, dt} = create_device_type(%{code: code})
      assert dt.code == code
    end

    test "name is persisted correctly" do
      {:ok, dt} = create_device_type(%{name: "IP Camera"})
      assert dt.name == "IP Camera"
    end

    test "active? defaults to true" do
      {:ok, dt} = create_device_type()
      assert dt.active? == true
    end

    test "capabilities defaults to []" do
      {:ok, dt} = create_device_type()
      assert dt.capabilities == []
    end

    test "category :sensor is valid" do
      {:ok, dt} =
        create_device_type(%{
          category: :sensor,
          capabilities: ["detection"]
        })

      assert dt.category == :sensor
    end

    test "category :camera is valid with video_capture capability" do
      {:ok, dt} =
        create_device_type(%{
          category: :camera,
          capabilities: ["video_capture"]
        })

      assert dt.category == :camera
    end

    test "category :panel is valid with alarm_control capability" do
      {:ok, dt} =
        create_device_type(%{
          category: :panel,
          capabilities: ["alarm_control"]
        })

      assert dt.category == :panel
    end

    test "category :reader is valid with access_control capability" do
      {:ok, dt} =
        create_device_type(%{
          category: :reader,
          capabilities: ["access_control"]
        })

      assert dt.category == :reader
    end

    test "category :controller requires no specific capability" do
      {:ok, dt} = create_device_type(%{category: :controller})
      assert dt.category == :controller
    end

    test "category :output requires no specific capability" do
      {:ok, dt} = create_device_type(%{category: :output})
      assert dt.category == :output
    end

    test "category :other requires no specific capability" do
      {:ok, dt} = create_device_type(%{category: :other})
      assert dt.category == :other
    end

    test "camera without video_capture capability fails" do
      result =
        create_device_type(%{
          category: :camera,
          capabilities: []
        })

      assert match?({:error, _}, result)
    end

    test "sensor without detection capability fails" do
      result =
        create_device_type(%{
          category: :sensor,
          capabilities: []
        })

      assert match?({:error, _}, result)
    end

    test "panel without alarm_control capability fails" do
      result =
        create_device_type(%{
          category: :panel,
          capabilities: []
        })

      assert match?({:error, _}, result)
    end

    test "reader without access_control capability fails" do
      result =
        create_device_type(%{
          category: :reader,
          capabilities: []
        })

      assert match?({:error, _}, result)
    end

    test "code not matching uppercase pattern fails" do
      result = create_device_type(%{code: "lowercase-code"})
      assert match?({:error, _}, result)
    end

    test "code starting with number fails" do
      result = create_device_type(%{code: "1INVALID"})
      assert match?({:error, _}, result)
    end

    test "code too short fails" do
      result = create_device_type(%{code: "A"})
      assert match?({:error, _}, result)
    end

    test "device_type id is a UUID" do
      {:ok, dt} = create_device_type()
      assert is_binary(dt.id)
      assert String.length(dt.id) == 36
    end
  end

  # ---------------------------------------------------------------------------
  # describe: activate action
  # ---------------------------------------------------------------------------

  describe "activate/1" do
    test "sets active? to true" do
      {:ok, dt} = create_device_type()

      {:ok, archived} =
        Ash.update(dt, %{}, action: :archive, authorize?: false, actor: @system_admin)

      assert archived.active? == false

      {:ok, active} =
        Ash.update(archived, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert active.active? == true
    end

    test "activate on already-active device_type is idempotent" do
      {:ok, dt} = create_device_type()
      assert dt.active? == true

      {:ok, activated} =
        Ash.update(dt, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.active? == true
    end
  end

  # ---------------------------------------------------------------------------
  # describe: archive action (soft destroy)
  # ---------------------------------------------------------------------------

  describe "archive/1" do
    test "sets active? to false (soft delete)" do
      {:ok, dt} = create_device_type()

      {:ok, archived} =
        Ash.update(dt, %{}, action: :archive, authorize?: false, actor: @system_admin)

      assert archived.active? == false
    end

    test "archived device_type still has its id" do
      {:ok, dt} = create_device_type()
      original_id = dt.id

      {:ok, archived} =
        Ash.update(dt, %{}, action: :archive, authorize?: false, actor: @system_admin)

      assert archived.id == original_id
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: device_type id persists through activate/archive cycle" do
      {:ok, dt} = create_device_type()
      original_id = dt.id

      {:ok, archived} =
        Ash.update(dt, %{}, action: :archive, authorize?: false, actor: @system_admin)

      {:ok, active} =
        Ash.update(archived, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert active.id == original_id
    end

    test "Psi3 verification: camera capability constraint always enforced" do
      bad = create_device_type(%{category: :camera, capabilities: []})
      good = create_device_type(%{category: :camera, capabilities: ["video_capture"]})

      assert match?({:error, _}, bad)
      assert match?({:ok, _}, good)
    end

    test "Psi5 truthfulness: active? reflects actual archive/activate state" do
      {:ok, dt} = create_device_type()
      assert dt.active? == true

      {:ok, archived} =
        Ash.update(dt, %{}, action: :archive, authorize?: false, actor: @system_admin)

      assert archived.active? == false

      {:ok, reactivated} =
        Ash.update(archived, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert reactivated.active? == true
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: two device_types can be created concurrently" do
      tasks = [
        Task.async(fn -> create_device_type(%{category: :other}) end),
        Task.async(fn -> create_device_type(%{category: :controller}) end)
      ]

      [r1, r2] = Task.await_many(tasks, 10_000)
      assert match?({:ok, _}, r1)
      assert match?({:ok, _}, r2)
    end

    test "create completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> create_device_type() end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "create succeeds for all non-capability-requiring categories" do
    no_cap_categories = [:controller, :output, :other]

    forall category <- PC.oneof(Enum.map(no_cap_categories, &PC.exactly/1)) do
      result = create_device_type(%{category: category})
      match?({:ok, _}, result)
    end
  end

  property "active? defaults to true for all new device_types" do
    forall _n <- PC.integer(1, 3) do
      {:ok, dt} = create_device_type()
      dt.active? == true
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "camera with video_capture always succeeds" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      result =
        create_device_type(%{
          category: :camera,
          capabilities: ["video_capture"]
        })

      assert match?({:ok, _}, result)
    end
  end

  test "archive always sets active? to false" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, dt} = create_device_type()

      {:ok, archived} =
        Ash.update(dt, %{}, action: :archive, authorize?: false, actor: @system_admin)

      assert archived.active? == false
    end
  end
end
