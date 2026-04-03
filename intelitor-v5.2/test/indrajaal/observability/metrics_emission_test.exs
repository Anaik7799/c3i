defmodule Indrajaal.Observability.MetricsEmissionTest do
  @moduledoc """
  Verifies that business metrics are correctly emitted for Alarms and Access Control domains.
  """

  use Indrajaal.DataCase
  use ExUnit.Case, async: false

  alias Indrajaal.Alarms.AlarmEvent
  alias Indrajaal.AccessControl.AccessGrant
  alias Indrajaal.AccessControl.AccessCredential
  alias Indrajaal.Observability.Metrics

  @moduletag :observability
  @moduletag :metrics

  setup do
    # Start telemetry collector for metrics
    telemetry_pid =
      start_telemetry_collector([
        [:indrajaal, :metrics, :counter],
        [:indrajaal, :metrics, :histogram],
        [:indrajaal, :metrics, :gauge]
      ])

    # Ensure Metrics GenServer is running
    # It is started by application startup, so we just need to ensure it's alive
    unless Process.whereis(Metrics) do
      {:ok, _} = Metrics.start_link([])
    end

    # Setup test data
    tenant = insert(:tenant, name: "Metrics Test Tenant")
    organization = insert(:organization, tenant: tenant, name: "Test Corp")
    site = insert(:site, tenant: tenant, organization: organization, name: "Test Site")

    device_type = insert(:device_type, tenant: tenant, name: "Sensor", category: :sensor)

    device =
      insert(:device, tenant: tenant, site: site, device_type: device_type, name: "Test Device")

    user = insert(:user, tenant: tenant, role: :admin)

    {:ok, tenant: tenant, site: site, device: device, user: user, telemetry_pid: telemetry_pid}
  end

  describe "Alarms Metrics" do
    test "emits metrics when an alarm is created", %{
      tenant: tenant,
      site: site,
      device: device,
      user: user,
      telemetry_pid: telemetry_pid
    } do
      # Create an alarm
      AlarmEvent.create!(
        %{
          site_id: site.id,
          device_id: device.id,
          event_type: :intrusion,
          event_code: "TEST001",
          severity: :high,
          description: "Test alarm"
        },
        actor: user
      )

      # Wait for metrics export
      Process.sleep(200)

      events = get_telemetry_events(telemetry_pid)

      # Check for creation metric
      creation_event = find_metric_event(events, :counter, "indrajaal.alarms.created_total")
      assert creation_event != nil
      assert creation_event.measurements.value == 1
      assert creation_event.metadata.tenant_id == tenant.id
    end

    test "emits metrics when an alarm is acknowledged and resolved", %{
      tenant: tenant,
      site: site,
      device: device,
      user: user,
      telemetry_pid: telemetry_pid
    } do
      alarm =
        AlarmEvent.create!(
          %{
            site_id: site.id,
            device_id: device.id,
            event_type: :fire,
            event_code: "FIRE001",
            severity: :critical,
            description: "Fire alarm",
            triggered_at: DateTime.add(DateTime.utc_now(), -10, :second)
          },
          actor: user
        )

      # Verify user exists
      _user_check = Ash.get!(Indrajaal.Accounts.User, user.id, actor: user)

      # Acknowledge
      AlarmEvent.acknowledge!(alarm, %{acknowledged_by: user.id}, actor: user)

      # Resolve
      AlarmEvent.resolve!(alarm, %{resolved_by: user.id, resolution: "Test resolved"},
        actor: user
      )

      # Wait for metrics export
      Process.sleep(500)

      events = get_telemetry_events(telemetry_pid)

      # Check acknowledged metric
      ack_count = find_metric_event(events, :counter, "indrajaal.alarms.acknowledged_total")
      assert ack_count != nil

      ack_timing =
        find_metric_event(events, :histogram, "indrajaal.business.alarm_response_time_seconds")

      assert ack_timing != nil
      assert ack_timing.measurements.value >= 10.0

      # Check resolved metric
      res_count = find_metric_event(events, :counter, "indrajaal.alarms.resolved_total")
      assert res_count != nil

      res_timing =
        find_metric_event(events, :histogram, "indrajaal.business.alarm_resolution_time_seconds")

      assert res_timing != nil
    end
  end

  # describe "Access Control Metrics" do
  #   test "emits metrics for security events", %{tenant: tenant, telemetry_pid: telemetry_pid} do
  #     # Mock some security events
  #     enriched = %{tenant_id: tenant.id, user_id: "test-user"}

  #     :telemetry.execute([:indrajaal, :access_control, :security, :access_granted], %{count: 1}, enriched)
  #     :telemetry.execute([:indrajaal, :access_control, :security, :access_denied], %{count: 1}, enriched)
  #     :telemetry.execute([:indrajaal, :access_control, :security, :credential_validation], %{count: 1}, enriched)

  #     # Wait for metrics export
  #     Process.sleep(200)

  #     events = get_telemetry_events(telemetry_pid)

  #     assert find_metric_event(events, :counter, "indrajaal.access_control.access_granted_total") != nil
  #     assert find_metric_event(events, :counter, "indrajaal.access_control.access_denied_total") != nil
  #     assert find_metric_event(events, :counter, "indrajaal.access_control.credentials_validated_total") != nil
  #   end

  #   test "emits metrics for resource creation", %{tenant: tenant, user: user, telemetry_pid: telemetry_pid} do
  #     # Create a credential
  #     credential = insert(:access_credential, tenant: tenant, user: user)

  #     # Create a grant
  #     AccessGrant.grant!(%{
  #       grant_type: :permanent,
  #       tenant_id: tenant.id,
  #       user_id: user.id,
  #       access_credential_id: credential.id,
  #       access_level_id: insert(:access_level, tenant: tenant).id,
  #       valid_from: DateTime.utc_now(),
  #       valid_until: DateTime.add(DateTime.utc_now(), 1, :day)
  #     }, actor: user)

  #     # Wait for metrics export
  #     Process.sleep(200)

  #     events = get_telemetry_events(telemetry_pid)

  #     assert find_metric_event(events, :counter, "indrajaal.access_control.credentials_created_total") != nil
  #     assert find_metric_event(events, :counter, "indrajaal.access_control.access_grants_created_total") != nil
  #   end
  # end

  # Helpers

  defp start_telemetry_collector(event_names) do
    {:ok, pid} = Agent.start_link(fn -> [] end)

    :telemetry.attach_many(
      "metrics-test-collector",
      event_names,
      fn name, measurements, metadata, _config ->
        Agent.update(pid, fn events ->
          [%{event: name, measurements: measurements, metadata: metadata} | events]
        end)
      end,
      nil
    )

    pid
  end

  defp get_telemetry_events(pid) do
    Agent.get(pid, & &1)
  end

  defp find_metric_event(events, type, name) do
    Enum.find(events, fn e ->
      e.event == [:indrajaal, :metrics, type] && e.metadata.name == name
    end)
  end
end
