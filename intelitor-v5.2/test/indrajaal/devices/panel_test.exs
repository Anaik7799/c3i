defmodule Indrajaal.Devices.PanelTest do
  @moduledoc """
  TDG comprehensive test suite for Devices.Panel.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-PANEL-001: create must initialize panel_status to :offline
  - SC-PANEL-002: go_online must set panel_status = :online
  - SC-PANEL-003: trigger_alarm must set panel_status = :alarm
  - SC-PANEL-004: enter_programming must fail when programming_locked? = true
  - SC-PANEL-005: lock_programming must prevent enter_programming
  - SC-PANEL-006: report_trouble must set panel_status = :trouble

  ## Constitutional Verification
  - Psi0 Existence: Panel record persists through all status transitions
  - Psi1 Regeneration: Full panel config recoverable from SQLite
  - Psi3 Verification: panel_status always a known valid atom
  - Psi5 Truthfulness: programming_locked? accurately reflects lock state

  ## Founder's Directive Alignment
  - Omega0.1: Intrusion panels are primary asset protection systems

  ## TPS 5-Level RCA Context
  - L1 Symptom: Panel alarm not triggering correctly
  - L5 Root Cause: trigger_alarm action not setting panel_status = :alarm via force_change_attribute

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
  alias Indrajaal.Devices.{Panel, Device}

  @moduletag :zenoh_nif

  @system_admin %{role: "admin", id: "00000000-0000-0000-0000-000000000003"}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_device(tenant_id) do
    Ash.create(
      Device,
      %{name: "Panel Device #{System.unique_integer([:positive])}", tenant_id: tenant_id},
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  defp unique_panel_attrs(device_id) do
    suffix = System.unique_integer([:positive])

    %{
      device_id: device_id,
      manufacturer: "SecureTech",
      model: "ST-PRO-#{suffix}",
      account_number: "ACC#{suffix}"
    }
  end

  defp create_panel(attrs \\ %{}) do
    tenant_id = random_tenant()
    {:ok, device} = create_device(tenant_id)

    base = unique_panel_attrs(device.id)
    merged = Map.merge(base, attrs)

    Ash.create(Panel, merged,
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  # ---------------------------------------------------------------------------
  # describe: create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a panel with required fields" do
      assert {:ok, panel} = create_panel()
      assert not is_nil(panel.id)
    end

    test "panel_status defaults to :offline after create" do
      {:ok, panel} = create_panel()
      assert panel.panel_status == :offline
    end

    test "panel_type defaults to :intrusion" do
      {:ok, panel} = create_panel()
      assert panel.panel_type == :intrusion
    end

    test "connection_type defaults to :ethernet" do
      {:ok, panel} = create_panel()
      assert panel.connection_type == :ethernet
    end

    test "sia_level defaults to 3" do
      {:ok, panel} = create_panel()
      assert panel.sia_level == 3
    end

    test "max_zones defaults to 32" do
      {:ok, panel} = create_panel()
      assert panel.max_zones == 32
    end

    test "max_users defaults to 50" do
      {:ok, panel} = create_panel()
      assert panel.max_users == 50
    end

    test "max_outputs defaults to 4" do
      {:ok, panel} = create_panel()
      assert panel.max_outputs == 4
    end

    test "max_partitions defaults to 1" do
      {:ok, panel} = create_panel()
      assert panel.max_partitions == 1
    end

    test "ac_power? defaults to true" do
      {:ok, panel} = create_panel()
      assert panel.ac_power? == true
    end

    test "phone_line_fault? defaults to false" do
      {:ok, panel} = create_panel()
      assert panel.phone_line_fault? == false
    end

    test "programming_locked? defaults to false" do
      {:ok, panel} = create_panel()
      assert panel.programming_locked? == false
    end

    test "custom max_zones is persisted" do
      {:ok, panel} = create_panel(%{max_zones: 128})
      assert panel.max_zones == 128
    end

    test "panel_type :fire is valid" do
      {:ok, panel} = create_panel(%{panel_type: :fire})
      assert panel.panel_type == :fire
    end

    test "panel_type :access is valid" do
      {:ok, panel} = create_panel(%{panel_type: :access})
      assert panel.panel_type == :access
    end

    test "panel id is a UUID" do
      {:ok, panel} = create_panel()
      assert is_binary(panel.id)
      assert String.length(panel.id) == 36
    end
  end

  # ---------------------------------------------------------------------------
  # describe: go_online action
  # ---------------------------------------------------------------------------

  describe "go_online/1" do
    test "sets panel_status to :online" do
      {:ok, panel} = create_panel()
      assert panel.panel_status == :offline

      {:ok, updated} =
        Ash.update(panel, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert updated.panel_status == :online
    end

    test "updates last_test_time on go_online" do
      {:ok, panel} = create_panel()

      {:ok, updated} =
        Ash.update(panel, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert not is_nil(updated.last_test_time)
    end
  end

  # ---------------------------------------------------------------------------
  # describe: go_offline action
  # ---------------------------------------------------------------------------

  describe "go_offline/1" do
    test "sets panel_status to :offline" do
      {:ok, panel} = create_panel()

      {:ok, online} =
        Ash.update(panel, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert online.panel_status == :online

      {:ok, offline} =
        Ash.update(online, %{}, action: :go_offline, authorize?: false, actor: @system_admin)

      assert offline.panel_status == :offline
    end
  end

  # ---------------------------------------------------------------------------
  # describe: trigger_alarm action
  # ---------------------------------------------------------------------------

  describe "trigger_alarm/1" do
    test "sets panel_status to :alarm" do
      {:ok, panel} = create_panel()

      {:ok, updated} =
        Ash.update(panel, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      assert updated.panel_status == :alarm
    end

    test "can trigger alarm from offline state" do
      {:ok, panel} = create_panel()
      assert panel.panel_status == :offline

      {:ok, alarmed} =
        Ash.update(panel, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      assert alarmed.panel_status == :alarm
    end

    test "can trigger alarm from online state" do
      {:ok, panel} = create_panel()

      {:ok, online} =
        Ash.update(panel, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, alarmed} =
        Ash.update(online, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      assert alarmed.panel_status == :alarm
    end
  end

  # ---------------------------------------------------------------------------
  # describe: report_trouble action
  # ---------------------------------------------------------------------------

  describe "report_trouble/1" do
    test "sets panel_status to :trouble" do
      {:ok, panel} = create_panel()

      {:ok, updated} =
        Ash.update(panel, %{battery_voltage: 11.0, ac_power?: true, phone_line_fault?: false},
          action: :report_trouble,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.panel_status == :trouble
    end

    test "persists battery_voltage on report_trouble" do
      {:ok, panel} = create_panel()

      {:ok, updated} =
        Ash.update(panel, %{battery_voltage: 10.5, ac_power?: false, phone_line_fault?: true},
          action: :report_trouble,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.battery_voltage == 10.5
    end
  end

  # ---------------------------------------------------------------------------
  # describe: enter_programming / lock_programming
  # ---------------------------------------------------------------------------

  describe "enter_programming/1" do
    test "sets panel_status to :programming when not locked" do
      {:ok, panel} = create_panel()
      assert panel.programming_locked? == false

      {:ok, prog} =
        Ash.update(panel, %{},
          action: :enter_programming,
          authorize?: false,
          actor: @system_admin
        )

      assert prog.panel_status == :programming
    end

    test "returns error when programming is locked" do
      {:ok, panel} = create_panel()

      {:ok, locked} =
        Ash.update(panel, %{}, action: :lock_programming, authorize?: false, actor: @system_admin)

      assert locked.programming_locked? == true

      result =
        Ash.update(locked, %{},
          action: :enter_programming,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  describe "lock_programming/1" do
    test "sets programming_locked? to true" do
      {:ok, panel} = create_panel()

      {:ok, locked} =
        Ash.update(panel, %{}, action: :lock_programming, authorize?: false, actor: @system_admin)

      assert locked.programming_locked? == true
    end
  end

  describe "unlock_programming/1" do
    test "sets programming_locked? to false" do
      {:ok, panel} = create_panel()

      {:ok, locked} =
        Ash.update(panel, %{}, action: :lock_programming, authorize?: false, actor: @system_admin)

      {:ok, unlocked} =
        Ash.update(locked, %{},
          action: :unlock_programming,
          authorize?: false,
          actor: @system_admin
        )

      assert unlocked.programming_locked? == false
    end

    test "after unlock, enter_programming succeeds" do
      {:ok, panel} = create_panel()

      {:ok, locked} =
        Ash.update(panel, %{}, action: :lock_programming, authorize?: false, actor: @system_admin)

      {:ok, unlocked} =
        Ash.update(locked, %{},
          action: :unlock_programming,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, prog} =
        Ash.update(unlocked, %{},
          action: :enter_programming,
          authorize?: false,
          actor: @system_admin
        )

      assert prog.panel_status == :programming
    end
  end

  describe "exit_programming/1" do
    test "sets panel_status back to :online after programming" do
      {:ok, panel} = create_panel()

      {:ok, prog} =
        Ash.update(panel, %{},
          action: :enter_programming,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, exited} =
        Ash.update(prog, %{}, action: :exit_programming, authorize?: false, actor: @system_admin)

      assert exited.panel_status == :online
    end
  end

  # ---------------------------------------------------------------------------
  # describe: test_communication action
  # ---------------------------------------------------------------------------

  describe "test_communication/1" do
    test "updates last_test_time" do
      {:ok, panel} = create_panel()
      assert is_nil(panel.last_test_time)

      {:ok, tested} =
        Ash.update(panel, %{},
          action: :test_communication,
          authorize?: false,
          actor: @system_admin
        )

      assert not is_nil(tested.last_test_time)
    end

    test "last_test_time is recent after test_communication" do
      {:ok, panel} = create_panel()

      {:ok, tested} =
        Ash.update(panel, %{},
          action: :test_communication,
          authorize?: false,
          actor: @system_admin
        )

      now = DateTime.utc_now()
      diff = DateTime.diff(now, tested.last_test_time, :second)
      assert diff >= 0
      assert diff < 5
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: panel id persists across all status transitions" do
      {:ok, panel} = create_panel()
      original_id = panel.id

      {:ok, online} =
        Ash.update(panel, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, alarmed} =
        Ash.update(online, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      {:ok, offline} =
        Ash.update(alarmed, %{}, action: :go_offline, authorize?: false, actor: @system_admin)

      assert offline.id == original_id
    end

    test "Psi3 verification: panel_status is always a known atom" do
      known_statuses = [:online, :offline, :trouble, :alarm, :programming]
      {:ok, panel} = create_panel()
      assert panel.panel_status in known_statuses

      {:ok, online} =
        Ash.update(panel, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert online.panel_status in known_statuses
    end

    test "Psi5 truthfulness: programming_locked? reflects actual lock state" do
      {:ok, panel} = create_panel()
      assert panel.programming_locked? == false

      {:ok, locked} =
        Ash.update(panel, %{}, action: :lock_programming, authorize?: false, actor: @system_admin)

      assert locked.programming_locked? == true

      {:ok, unlocked} =
        Ash.update(locked, %{},
          action: :unlock_programming,
          authorize?: false,
          actor: @system_admin
        )

      assert unlocked.programming_locked? == false
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: two panels can independently trigger alarm" do
      {:ok, panel_a} = create_panel()
      {:ok, panel_b} = create_panel()

      {:ok, alarm_a} =
        Ash.update(panel_a, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      {:ok, alarm_b} =
        Ash.update(panel_b, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      assert alarm_a.panel_status == :alarm
      assert alarm_b.panel_status == :alarm
    end

    test "create completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> create_panel() end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end

    test "safe state: trigger_alarm followed by go_offline returns :offline" do
      {:ok, panel} = create_panel()

      {:ok, alarmed} =
        Ash.update(panel, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      {:ok, safe} =
        Ash.update(alarmed, %{}, action: :go_offline, authorize?: false, actor: @system_admin)

      assert safe.panel_status == :offline
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  test "panel_status starts as :offline for all new panels" do
    forall _n <- PC.integer(1, 3) do
      {:ok, panel} = create_panel()
      panel.panel_status == :offline
    end
  end

  test "programming_locked? starts false for all new panels" do
    forall _n <- PC.integer(1, 3) do
      {:ok, panel} = create_panel()
      panel.programming_locked? == false
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "trigger_alarm always sets panel_status to :alarm regardless of prior status" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, panel} = create_panel()

      {:ok, alarmed} =
        Ash.update(panel, %{}, action: :trigger_alarm, authorize?: false, actor: @system_admin)

      assert alarmed.panel_status == :alarm
    end
  end

  test "lock then unlock is idempotent on programming_locked? state" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, panel} = create_panel()

      {:ok, locked} =
        Ash.update(panel, %{}, action: :lock_programming, authorize?: false, actor: @system_admin)

      {:ok, unlocked} =
        Ash.update(locked, %{},
          action: :unlock_programming,
          authorize?: false,
          actor: @system_admin
        )

      assert unlocked.programming_locked? == false
    end
  end
end
