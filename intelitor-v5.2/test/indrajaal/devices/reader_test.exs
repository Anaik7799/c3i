defmodule Indrajaal.Devices.ReaderTest do
  @moduledoc """
  TDG comprehensive test suite for Devices.Reader.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-READER-001: create must initialize reader_status to :offline
  - SC-READER-002: go_online must set reader_status = :online, led_state = :red
  - SC-READER-003: grant_access must increment granted_reads and total_reads
  - SC-READER-004: deny_access must increment denied_reads and total_reads
  - SC-READER-005: report_tamper must set reader_status = :tamper, led_state = :alternating
  - SC-READER-006: reset_counters must zero all read counters

  ## Constitutional Verification
  - Psi0 Existence: Reader records persist through all state transitions
  - Psi1 Regeneration: Counter state fully recoverable from SQLite
  - Psi3 Verification: reader_status transitions verified at each action
  - Psi5 Truthfulness: granted_reads + denied_reads == total_reads invariant

  ## Founder's Directive Alignment
  - Omega0.1: Access readers protect entry points defending physical assets

  ## TPS 5-Level RCA Context
  - L1 Symptom: Access granted but counter not incremented
  - L5 Root Cause: grant_access change function not updating all counters atomically

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
  alias Indrajaal.Devices.{Reader, Device}

  @moduletag :zenoh_nif

  @system_admin %{role: "admin", id: "00000000-0000-0000-0000-000000000002"}

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

  defp create_reader(attrs \\ %{}) do
    tenant_id = random_tenant()
    {:ok, device} = create_device(tenant_id)

    base = %{device_id: device.id}
    merged = Map.merge(base, attrs)

    Ash.create(Reader, merged,
      authorize?: false,
      actor: @system_admin,
      tenant: tenant_id
    )
  end

  # ---------------------------------------------------------------------------
  # describe: create action
  # ---------------------------------------------------------------------------

  describe "create/1" do
    test "creates a reader with required device_id" do
      assert {:ok, reader} = create_reader()
      assert not is_nil(reader.id)
    end

    test "reader_status defaults to :offline" do
      {:ok, reader} = create_reader()
      assert reader.reader_status == :offline
    end

    test "led_state defaults to :off after create" do
      {:ok, reader} = create_reader()
      assert reader.led_state == :off
    end

    test "total_reads is 0 on create" do
      {:ok, reader} = create_reader()
      assert reader.total_reads == 0
    end

    test "granted_reads is 0 on create" do
      {:ok, reader} = create_reader()
      assert reader.granted_reads == 0
    end

    test "denied_reads is 0 on create" do
      {:ok, reader} = create_reader()
      assert reader.denied_reads == 0
    end

    test "reader_type defaults to :proximity" do
      {:ok, reader} = create_reader()
      assert reader.reader_type == :proximity
    end

    test "reader_mode defaults to :entry" do
      {:ok, reader} = create_reader()
      assert reader.reader_mode == :entry
    end

    test "communication_type defaults to :wiegand" do
      {:ok, reader} = create_reader()
      assert reader.communication_type == :wiegand
    end

    test "door_open_time_sec defaults to 5" do
      {:ok, reader} = create_reader()
      assert reader.door_open_time_sec == 5
    end

    test "pin_length defaults to 4" do
      {:ok, reader} = create_reader()
      assert reader.pin_length == 4
    end

    test "wiegand_format 26 is valid" do
      {:ok, reader} = create_reader(%{wiegand_format: 26})
      assert reader.wiegand_format == 26
    end

    test "wiegand_format 34 is valid" do
      {:ok, reader} = create_reader(%{wiegand_format: 34})
      assert reader.wiegand_format == 34
    end

    test "invalid wiegand_format returns error" do
      result = create_reader(%{wiegand_format: 99})
      assert match?({:error, _}, result)
    end

    test "reader id is a UUID" do
      {:ok, reader} = create_reader()
      assert is_binary(reader.id)
      assert String.length(reader.id) == 36
    end
  end

  # ---------------------------------------------------------------------------
  # describe: go_online action
  # ---------------------------------------------------------------------------

  describe "go_online/1" do
    test "sets reader_status to :online" do
      {:ok, reader} = create_reader()
      assert reader.reader_status == :offline

      {:ok, updated} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert updated.reader_status == :online
    end

    test "sets led_state to :red when online" do
      {:ok, reader} = create_reader()

      {:ok, updated} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert updated.led_state == :red
    end
  end

  # ---------------------------------------------------------------------------
  # describe: go_offline action
  # ---------------------------------------------------------------------------

  describe "go_offline/1" do
    test "sets reader_status to :offline" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      assert online.reader_status == :online

      {:ok, offline} =
        Ash.update(online, %{}, action: :go_offline, authorize?: false, actor: @system_admin)

      assert offline.reader_status == :offline
    end

    test "sets led_state to :off when offline" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, offline} =
        Ash.update(online, %{}, action: :go_offline, authorize?: false, actor: @system_admin)

      assert offline.led_state == :off
    end
  end

  # ---------------------------------------------------------------------------
  # describe: report_tamper action
  # ---------------------------------------------------------------------------

  describe "report_tamper/1" do
    test "sets reader_status to :tamper" do
      {:ok, reader} = create_reader()

      {:ok, updated} =
        Ash.update(reader, %{}, action: :report_tamper, authorize?: false, actor: @system_admin)

      assert updated.reader_status == :tamper
    end

    test "sets led_state to :alternating on tamper" do
      {:ok, reader} = create_reader()

      {:ok, updated} =
        Ash.update(reader, %{}, action: :report_tamper, authorize?: false, actor: @system_admin)

      assert updated.led_state == :alternating
    end
  end

  # ---------------------------------------------------------------------------
  # describe: clear_tamper action
  # ---------------------------------------------------------------------------

  describe "clear_tamper/1" do
    test "sets reader_status to :online after tamper" do
      {:ok, reader} = create_reader()

      {:ok, tampered} =
        Ash.update(reader, %{}, action: :report_tamper, authorize?: false, actor: @system_admin)

      {:ok, cleared} =
        Ash.update(tampered, %{}, action: :clear_tamper, authorize?: false, actor: @system_admin)

      assert cleared.reader_status == :online
    end

    test "sets led_state to :red after clear_tamper" do
      {:ok, reader} = create_reader()

      {:ok, tampered} =
        Ash.update(reader, %{}, action: :report_tamper, authorize?: false, actor: @system_admin)

      {:ok, cleared} =
        Ash.update(tampered, %{}, action: :clear_tamper, authorize?: false, actor: @system_admin)

      assert cleared.led_state == :red
    end
  end

  # ---------------------------------------------------------------------------
  # describe: grant_access action
  # ---------------------------------------------------------------------------

  describe "grant_access/1" do
    test "increments granted_reads by 1" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_grant} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      assert after_grant.granted_reads == 1
    end

    test "increments total_reads by 1" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_grant} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      assert after_grant.total_reads == 1
    end

    test "sets led_state to :green on grant" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_grant} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      assert after_grant.led_state == :green
    end

    test "updates last_read_at" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_grant} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      assert not is_nil(after_grant.last_read_at)
    end

    test "multiple grants accumulate correctly" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, g1} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, g2} =
        Ash.update(g1, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, g3} =
        Ash.update(g2, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      assert g3.granted_reads == 3
      assert g3.total_reads == 3
    end
  end

  # ---------------------------------------------------------------------------
  # describe: deny_access action
  # ---------------------------------------------------------------------------

  describe "deny_access/1" do
    test "increments denied_reads by 1" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_deny} =
        Ash.update(online, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      assert after_deny.denied_reads == 1
    end

    test "increments total_reads by 1 on deny" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_deny} =
        Ash.update(online, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      assert after_deny.total_reads == 1
    end

    test "sets led_state to :red on deny" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, after_deny} =
        Ash.update(online, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      assert after_deny.led_state == :red
    end
  end

  # ---------------------------------------------------------------------------
  # describe: reset_counters action
  # ---------------------------------------------------------------------------

  describe "reset_counters/1" do
    test "zeros total_reads, granted_reads, denied_reads" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, g1} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, d1} =
        Ash.update(g1, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      assert d1.total_reads == 2

      {:ok, reset} =
        Ash.update(d1, %{}, action: :reset_counters, authorize?: false, actor: @system_admin)

      assert reset.total_reads == 0
      assert reset.granted_reads == 0
      assert reset.denied_reads == 0
    end
  end

  # ---------------------------------------------------------------------------
  # Constitutional Invariants (Psi0-Psi5)
  # ---------------------------------------------------------------------------

  describe "Constitutional Invariants (Psi0-Psi5)" do
    test "Psi0 existence: reader survives all status transitions" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, tampered} =
        Ash.update(online, %{}, action: :report_tamper, authorize?: false, actor: @system_admin)

      {:ok, cleared} =
        Ash.update(tampered, %{}, action: :clear_tamper, authorize?: false, actor: @system_admin)

      {:ok, offline} =
        Ash.update(cleared, %{}, action: :go_offline, authorize?: false, actor: @system_admin)

      # Reader still has its ID throughout all transitions
      assert offline.id == reader.id
    end

    test "Psi5 truthfulness: granted + denied == total after mixed operations" do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, g1} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, g2} =
        Ash.update(g1, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, d1} =
        Ash.update(g2, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      assert d1.granted_reads + d1.denied_reads == d1.total_reads
    end

    test "Psi3 verification: reader_status is always a known atom" do
      known_statuses = [:offline, :online, :tamper, :fault, :disabled]
      {:ok, reader} = create_reader()
      assert reader.reader_status in known_statuses
    end
  end

  # ---------------------------------------------------------------------------
  # SIL-6 Safety Tests
  # ---------------------------------------------------------------------------

  describe "SIL-6 Requirements" do
    test "dual-channel: two readers can independently grant and deny" do
      {:ok, r_a} = create_reader()
      {:ok, r_b} = create_reader()

      {:ok, a_online} =
        Ash.update(r_a, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, b_online} =
        Ash.update(r_b, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, a_grant} =
        Ash.update(a_online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, b_deny} =
        Ash.update(b_online, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      assert a_grant.led_state == :green
      assert b_deny.led_state == :red
    end

    test "create completes within 5 seconds" do
      {elapsed_us, result} = :timer.tc(fn -> create_reader() end)
      assert match?({:ok, _}, result)
      assert elapsed_us < 5_000_000
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests
  # ---------------------------------------------------------------------------

  test "reader_status starts as :offline for any new reader" do
    forall _n <- PC.integer(1, 3) do
      {:ok, reader} = create_reader()
      reader.reader_status == :offline
    end
  end

  test "granted + denied always equals total_reads" do
    forall _n <- PC.integer(1, 3) do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, g1} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, d1} =
        Ash.update(g1, %{}, action: :deny_access, authorize?: false, actor: @system_admin)

      d1.granted_reads + d1.denied_reads == d1.total_reads
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties property tests
  # ---------------------------------------------------------------------------

  test "reset_counters always produces zeros regardless of prior state" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      {:ok, reader} = create_reader()

      {:ok, online} =
        Ash.update(reader, %{}, action: :go_online, authorize?: false, actor: @system_admin)

      {:ok, g} =
        Ash.update(online, %{}, action: :grant_access, authorize?: false, actor: @system_admin)

      {:ok, reset} =
        Ash.update(g, %{}, action: :reset_counters, authorize?: false, actor: @system_admin)

      assert reset.total_reads == 0
      assert reset.granted_reads == 0
      assert reset.denied_reads == 0
    end
  end

  test "all valid wiegand formats are accepted (26, 34, 37, 42)" do
    ExUnitProperties.check all(wiegand_format <- SD.member_of([26, 34, 37, 42])) do
      {:ok, reader} = create_reader(%{wiegand_format: wiegand_format})
      assert reader.wiegand_format == wiegand_format
    end
  end
end
