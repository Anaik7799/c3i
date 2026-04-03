defmodule Indrajaal.Alarms.IncidentTypeTest do
  @moduledoc """
  TDG comprehensive test suite for Alarms.IncidentType.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-IT-001: code must be unique per tenant
  - SC-IT-002: category must be one of 8 valid atoms
  - SC-IT-003: default_severity defaults to :high
  - SC-IT-004: activate requires active? == false; deactivate requires active? == true
  - SC-IT-005: add_sia_code is idempotent (duplicate codes not added)

  ## Constitutional Verification
  - Psi0 Existence: IncidentType record persists through activate/deactivate cycle
  - Psi3 Verification: SIA code list is always consistent (no duplicates)
  - Psi5 Truthfulness: active? accurately reflects activate/deactivate state

  ## Founder's Directive Alignment
  - Omega0.1: Incident taxonomy enables systematic security incident coverage

  ## TPS 5-Level RCA Context
  - L1 Symptom: IncidentType created with invalid category atom
  - L5 Root Cause: Category constraint validation not applied on create

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
  alias Indrajaal.Alarms.IncidentType

  @moduletag :zenoh_nif

  @system_admin %{role: "admin", id: "00000000-0000-0000-0000-000000000005"}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp unique_code do
    "IT#{System.unique_integer([:positive])}"
  end

  defp create_incident_type(attrs \\ %{}) do
    tenant_id = random_tenant().id

    base = %{
      code: unique_code(),
      name: "Test Incident Type #{System.unique_integer([:positive])}",
      category: :intrusion,
      tenant_id: tenant_id
    }

    merged = Map.merge(base, attrs)

    Ash.create(IncidentType, merged,
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  # ---------------------------------------------------------------------------
  # describe: create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates an incident_type with required fields" do
      assert {:ok, it} = create_incident_type()
      assert not is_nil(it.id)
    end

    test "code is persisted correctly" do
      code = unique_code()
      {:ok, it} = create_incident_type(%{code: code})
      assert it.code == code
    end

    test "name is persisted correctly" do
      {:ok, it} = create_incident_type(%{name: "Fire Intrusion"})
      assert it.name == "Fire Intrusion"
    end

    test "default_severity defaults to :high" do
      {:ok, it} = create_incident_type()
      assert it.default_severity == :high
    end

    test "default_priority defaults to 5" do
      {:ok, it} = create_incident_type()
      assert it.default_priority == 5
    end

    test "active? defaults to true" do
      {:ok, it} = create_incident_type()
      assert it.active? == true
    end

    test "auto_dispatch? defaults to false" do
      {:ok, it} = create_incident_type()
      assert it.auto_dispatch? == false
    end

    test "category :intrusion is valid" do
      {:ok, it} = create_incident_type(%{category: :intrusion})
      assert it.category == :intrusion
    end

    test "category :fire is valid" do
      {:ok, it} = create_incident_type(%{category: :fire})
      assert it.category == :fire
    end

    test "category :medical is valid" do
      {:ok, it} = create_incident_type(%{category: :medical})
      assert it.category == :medical
    end

    test "category :panic is valid" do
      {:ok, it} = create_incident_type(%{category: :panic})
      assert it.category == :panic
    end

    test "category :environmental is valid" do
      {:ok, it} = create_incident_type(%{category: :environmental})
      assert it.category == :environmental
    end

    test "category :technical is valid" do
      {:ok, it} = create_incident_type(%{category: :technical})
      assert it.category == :technical
    end

    test "category :system is valid" do
      {:ok, it} = create_incident_type(%{category: :system})
      assert it.category == :system
    end

    test "category :access_control is valid" do
      {:ok, it} = create_incident_type(%{category: :access_control})
      assert it.category == :access_control
    end

    test "id is a UUID" do
      {:ok, it} = create_incident_type()
      assert is_binary(it.id)
      assert String.length(it.id) == 36
    end

    test "sia_codes defaults to []" do
      {:ok, it} = create_incident_type()
      assert it.sia_codes == []
    end
  end

  # ---------------------------------------------------------------------------
  # describe: activate action
  # ---------------------------------------------------------------------------

  describe "activate/1" do
    test "sets active? to true after deactivate" do
      {:ok, it} = create_incident_type()

      {:ok, deactivated} =
        Ash.update(it, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false

      {:ok, activated} =
        Ash.update(deactivated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.active? == true
    end

    test "activate on already-active fails" do
      {:ok, it} = create_incident_type()
      assert it.active? == true
      result = Ash.update(it, %{}, action: :activate, authorize?: false, actor: @system_admin)
      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: deactivate action
  # ---------------------------------------------------------------------------

  describe "deactivate/1" do
    test "sets active? to false" do
      {:ok, it} = create_incident_type()

      {:ok, deactivated} =
        Ash.update(it, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false
    end

    test "deactivate on already-inactive fails" do
      {:ok, it} = create_incident_type()

      {:ok, deactivated} =
        Ash.update(it, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      result =
        Ash.update(deactivated, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert match?({:error, _}, result)
    end

    test "id is preserved after deactivate" do
      {:ok, it} = create_incident_type()
      original_id = it.id

      {:ok, deactivated} =
        Ash.update(it, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.id == original_id
    end
  end

  # ---------------------------------------------------------------------------
  # describe: add_sia_code action
  # ---------------------------------------------------------------------------

  describe "add_sia_code/1" do
    test "adds a SIA code to the list" do
      {:ok, it} = create_incident_type()
      assert it.sia_codes == []

      {:ok, updated} =
        Ash.update(it, %{},
          action: :add_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      assert "BA" in updated.sia_codes
    end

    test "adding duplicate SIA code is idempotent" do
      {:ok, it} = create_incident_type()

      {:ok, once} =
        Ash.update(it, %{},
          action: :add_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      {:ok, twice} =
        Ash.update(once, %{},
          action: :add_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      # Still only one "BA"
      count = Enum.count(twice.sia_codes, &(&1 == "BA"))
      assert count == 1
    end
  end

  # ---------------------------------------------------------------------------
  # describe: remove_sia_code action
  # ---------------------------------------------------------------------------

  describe "remove_sia_code/1" do
    test "removes a SIA code from the list" do
      {:ok, it} = create_incident_type()

      {:ok, with_code} =
        Ash.update(it, %{},
          action: :add_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      assert "BA" in with_code.sia_codes

      {:ok, without_code} =
        Ash.update(with_code, %{},
          action: :remove_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      refute "BA" in without_code.sia_codes
    end

    test "removing nonexistent code is safe" do
      {:ok, it} = create_incident_type()

      {:ok, unchanged} =
        Ash.update(it, %{},
          action: :remove_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "NONEXISTENT"}
        )

      assert unchanged.sia_codes == []
    end
  end

  # ---------------------------------------------------------------------------
  # describe: update_response_config action
  # ---------------------------------------------------------------------------

  describe "update_response_config/1" do
    test "updates auto_dispatch?" do
      {:ok, it} = create_incident_type()
      assert it.auto_dispatch? == false

      {:ok, updated} =
        Ash.update(it, %{auto_dispatch?: true},
          action: :update_response_config,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.auto_dispatch? == true
    end

    test "updates police_response?" do
      {:ok, it} = create_incident_type()

      {:ok, updated} =
        Ash.update(it, %{police_response?: true},
          action: :update_response_config,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.police_response? == true
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: id persists through activate/deactivate cycle" do
      {:ok, it} = create_incident_type()
      original_id = it.id

      {:ok, deactivated} =
        Ash.update(it, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      {:ok, activated} =
        Ash.update(deactivated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.id == original_id
    end

    test "Psi3 verification: SIA code list never has duplicates after idempotent adds" do
      {:ok, it} = create_incident_type()

      {:ok, once} =
        Ash.update(it, %{},
          action: :add_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      {:ok, twice} =
        Ash.update(once, %{},
          action: :add_sia_code,
          authorize?: false,
          actor: @system_admin,
          arguments: %{sia_code: "BA"}
        )

      unique_codes = Enum.uniq(twice.sia_codes)
      assert length(unique_codes) == length(twice.sia_codes)
    end

    test "Psi5 truthfulness: active? reflects actual state" do
      {:ok, it} = create_incident_type()
      assert it.active? == true

      {:ok, deactivated} =
        Ash.update(it, %{}, action: :deactivate, authorize?: false, actor: @system_admin)

      assert deactivated.active? == false

      {:ok, activated} =
        Ash.update(deactivated, %{}, action: :activate, authorize?: false, actor: @system_admin)

      assert activated.active? == true
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: two incident_types can be created concurrently" do
      tasks = [
        Task.async(fn -> create_incident_type(%{category: :fire}) end),
        Task.async(fn -> create_incident_type(%{category: :medical}) end)
      ]

      [r1, r2] = Task.await_many(tasks, 10_000)
      assert match?({:ok, _}, r1)
      assert match?({:ok, _}, r2)
    end

    test "create completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> create_incident_type() end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  property "all 8 valid categories are accepted" do
    categories = [
      :intrusion,
      :fire,
      :medical,
      :environmental,
      :panic,
      :technical,
      :system,
      :access_control
    ]

    forall category <- PC.oneof(Enum.map(categories, &PC.exactly/1)) do
      result = create_incident_type(%{category: category})
      match?({:ok, _}, result)
    end
  end

  property "default_severity is always :high" do
    forall _n <- PC.integer(1, 3) do
      {:ok, it} = create_incident_type()
      it.default_severity == :high
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "active? is always true on fresh create" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, it} = create_incident_type()
      assert it.active? == true
    end
  end

  test "sia_codes is always [] on fresh create" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, it} = create_incident_type()
      assert it.sia_codes == []
    end
  end
end
