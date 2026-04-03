defmodule Indrajaal.Support.Factories.AlarmsFactoryTest do
  use Indrajaal.DataCase, async: true

  @moduledoc """
  TDG Validation for AlarmsFactory.
  Verifies SC-FAC-001 through SC-FAC-012.
  """

  describe "alarm_event_factory/1" do
    test "creates a valid alarm event with default attributes" do
      alarm = insert(:alarm_event)
      assert alarm.id
      assert alarm.tenant_id
      assert alarm.device_id
      assert alarm.status == :active
    end

    test "supports attribute overrides" do
      alarm = insert(:alarm_event, priority: :high, type: :fire_alarm)
      assert alarm.priority == :high
      assert alarm.type == :fire_alarm
    end

    test "maintains tenant isolation" do
      tenant = insert(:tenant)
      alarm = insert(:alarm_event, tenant: tenant)
      assert alarm.tenant_id == tenant.id
    end

    test "handles device association correctly" do
      device = insert(:device)
      alarm = insert(:alarm_event, device: device)
      assert alarm.device_id == device.id
      assert alarm.tenant_id == device.tenant_id
    end
  end
end
