defmodule Intelitor.Wallaby.SecurityWorkflowsTest do
  @moduledoc """
  Comprehensive E2E tests for security-related workflows.

  Tests cover:
  - Access control and permissions
  - Role-based access control (RBAC)
  - Device security management
  - Alarm and incident response
  - Security monitoring dashboards
  """

  use Intelitor.WallabyCase
  use Intelitor.WallabyPageObjects

  alias Intelitor.WallabyPageObjects.{
    AccessControlPage,
    AccessRulesPage,
    RolesPage,
    PermissionsPage,
    DevicesPage,
    AlarmsPage,
    DashboardPage
  }

  @moduletag :wallaby
  @moduletag :security

  setup %{session: session, tenant: tenant} do
    admin_user = get_admin_user_for_tenant(tenant)
    session = session |> authenticate_user(admin_user)

    %{session: session, admin_user: admin_user}
  end

  describe "Access Control Management" do
    test "admin can create new access credential", %{session: session, tenant: tenant} do
      user = insert(:user, tenant: tenant)

      credential_data = %{
        type: "card",
        card_number: "1234567890",
        user: user.email,
        valid_from: Date.utc_today() |> Date.to_string(),
        valid_until: Date.utc_today() |> Date.add(365) |> Date.to_string(),
        access_levels: ["building_entry", "office_areas"]
      }

      session
      |> navigate_to_domain("access-control", tenant.id)
      |> click(AccessControlPage.new_credential_button())
      |> fill_form("[data-test='credential-form']", credential_data)
      |> click(css("[data-test='save-credential']"))
      |> assert_flash_message("success", "Access credential created successfully")
      |> assert_has(Wallaby.Query.text(credentialdata.card_number))
      |> validate_table_data(AccessControlPage.credentials_table(), 1)
    end

    test "credential creation validates required fields", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("access-control", tenant.id)
      |> click(AccessControlPage.new_credential_button())
      |> click(css("[data-test='save-credential']"))
      |> assert_validation_errors(%{
        type: "Credential type is required",
        user: "User assignment is required",
        valid_from: "Valid from date is required"
      })
    end

    test "card number uniqueness is enforced within tenant", %{session: session, tenant: tenant} do
      existing_credential =
        insert(:access_credential, tenant: tenant, card_number: "DUPLICATE123")

      user = insert(:user, tenant: tenant)

      duplicate_data = %{
        type: "card",
        card_number: existing_credential.card_number,
        user: user.email
      }

      session
      |> navigate_to_domain("access-control", tenant.id)
      |> click(AccessControlPage.new_credential_button())
      |> fill_form("[data-test='credential-form']", duplicate_data)
      |> click(css("[data-test='save-credential']"))
      |> assert_validation_errors(%{
        card_number: "Card number already exists"
      })
    end

    test "access logs show real-time credential usage", %{session: session, tenant: tenant} do
      credential = insert(:access_credential, tenant: tenant)

      # Simulate access __event
      access_log =
        insert(:access_log,
          tenant: tenant,
          credential: credential,
          __event_type: "entry",
          location: "Main Entrance",
          timestamp: DateTime.utc_now()
        )

      session
      |> navigate_to_domain("access-control", tenant.id)
      |> click(css("[data-test='access-logs-tab']"))
      |> assert_has(Wallaby.Query.text(credential.card_number))
      |> assert_has(Wallaby.Query.text("Main Entrance"))
      |> assert_has(Wallaby.Query.text("entry"))
      |> assert_has(css("[data-test='real-time-indicator']"))
    end

    test "access credential can be temporarily suspended", %{session: session, tenant: tenant} do
      credential = insert(:access_credential, tenant: tenant, status: "active")

      session
      |> navigate_to_domain("access-control", tenant.id)
      |> click(css("[data-test='suspend-credential-#{credential.id}']"))
      |> fill_in(css("[data-test='suspension-reason']"), with: "Security concern")
      |> click(css("[data-test='confirm-suspension']"))
      |> assert_flash_message("success", "Credential suspended successfully")
      |> assert_has(css("[data-test='credential-status'][data-status='suspended']"))
    end

    test "bulk credential operations work correctly", %{session: session, tenant: tenant} do
      credentials = Intelitor.Factory.insert_list(5, :access_credential, tenant: tenant)

      session
      |> navigate_to_domain("access-control", tenant.id)
      |> check(css("[data-test='select-all-credentials']"))
      |> click(css("[data-test='bulk-actions-menu']"))
      |> click(css("[data-test='bulk-suspend']"))
      |> click(css("[data-test='confirm-bulk-action']"))
      |> assert_flash_message("success", "5 credentials suspended successfully")
    end
  end

  describe "Access Rules Management" do
    test "admin can create complex access rule", %{session: session, tenant: tenant} do
      rule_data = %{
        name: "Executive Access Rule",
        resource: "executive_floor",
        action: "entry",
        priority: "high"
      }

      session
      |> navigate_to_domain("access-rules", tenant.id)
      |> click(AccessRulesPage.new_rule_button())
      |> fill_form("[data-test='access-rule-form']", rule_data)
      |> click(AccessRulesPage.add_condition_button())
      |> Wallaby.Browser.select(css("[data-test='condition-type']"), option: "role")
      |> Wallaby.Browser.select(css("[data-test='condition-operator']"), option: "equals")
      |> fill_in(css("[data-test='condition-value']"), with: "executive")
      |> click(css("[data-test='save-rule']"))
      |> assert_flash_message("success", "Access rule created successfully")
      |> assert_has(Wallaby.Query.text(ruledata.name))
    end

    test "access rule validation prevents conflicts", %{session: session, tenant: tenant} do
      # Create conflicting rule scenario
      existing_rule =
        insert(:access_rule,
          tenant: tenant,
          resource: "server_room",
          action: "entry",
          priority: "high"
        )

      conflicting_data = %{
        name: "Conflicting Server Room Rule",
        resource: "server_room",
        action: "entry",
        priority: "high"
      }

      session
      |> navigate_to_domain("access-rules", tenant.id)
      |> click(AccessRulesPage.new_rule_button())
      |> fill_form("[data-test='access-rule-form']", conflicting_data)
      |> click(css("[data-test='save-rule']"))
      |> assert_has(css("[data-test='rule-conflict-warning']"))
      |> assert_has(Wallaby.Query.text("This rule may conflict with existing rule"))
    end

    test "rule conditions builder supports complex logic", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("access-rules", tenant.id)
      |> click(AccessRulesPage.new_rule_button())
      |> click(AccessRulesPage.add_condition_button())
      |> Wallaby.Browser.select(css("[data-test='condition-type-1']"), option: "time")
      |> Wallaby.Browser.select(css("[data-test='condition-operator-1']"), option: "between")
      |> fill_in(css("[data-test='condition-value-1']"), with: "09:00-17:00")
      |> click(css("[data-test='add-condition-group']"))
      |> Wallaby.Browser.select(css("[data-test='condition-logic']"), option: "AND")
      |> click(AccessRulesPage.add_condition_button())
      |> Wallaby.Browser.select(css("[data-test='condition-type-2']"), option: "day_of_week")
      |> Wallaby.Browser.select(css("[data-test='condition-operator-2']"), option: "in")
      |> fill_in(css("[data-test='condition-value-2']"),
        with: "Monday,Tuesday,Wednesday,Thursday,Friday"
      )
      |> assert_has(css("[data-test='condition-preview']"))
      |> assert_has(
        Wallaby.Query.text(
          "Between 09:00-17:00 AND Day of week in Monday,Tuesday,Wednesday,Thursday,Friday"
        )
      )
    end

    test "access rule testing and simulation works", %{session: session, tenant: tenant} do
      rule = insert(:access_rule, tenant: tenant, name: "Test Rule")
      user = insert(:user, tenant: tenant, role: "employee")

      session
      |> navigate_to_domain("access-rules", tenant.id)
      |> click(css("[data-test='test-rule-#{rule.id}']"))
      |> Wallaby.Browser.select(css("[data-test='test-user']"), option: user.email)
      |> Wallaby.Browser.select(css("[data-test='test-resource']"), option: "office_floor")
      |> click(css("[data-test='run-test']"))
      |> assert_has(css("[data-test='test-result']"))
      |> assert_has(
        css(
          "[data-test='test-result'][data-outcome='allowed'], [data-test='test-result'][data-outcome='denied']"
        )
      )
    end
  end

  describe "Role-Based Access Control (RBAC)" do
    test "admin can create new role with permissions", %{session: session, tenant: tenant} do
      role_data = %{
        name: "Security Manager",
        description: "Manages security operations and personnel"
      }

      permissions = ["view_cameras", "manage_access_control", "respond_to_alarms"]

      session
      |> navigate_to_domain("roles", tenant.id)
      |> click(RolesPage.new_role_button())
      |> fill_form("[data-test='role-form']", role_data)
      |> then(fn session ->
        Enum.reduce(permissions, session, fn permission, acc_session ->
          acc_session |> check(RolesPage.permission_checkbox(permission))
        end)
      end)
      |> click(css("[data-test='save-role']"))
      |> assert_flash_message("success", "Role created successfully")
      |> assert_has(Wallaby.Query.text(roledata.name))
    end

    test "role hierarchy and inheritance works correctly", %{session: session, tenant: tenant} do
      # Create parent role
      parent_role = insert(:role, tenant: tenant, name: "Base Security Role")
      base_permissions = Intelitor.Factory.insert_list(3, :permission, tenant: tenant)

      # Associate base permissions with parent role
      Enum.each(base_permissions, fn permission ->
        insert(:role_permission, role: parent_role, permission: permission)
      end)

      child_role_data = %{
        name: "Advanced Security Role",
        parent_role: parent_role.name,
        description: "Inherits from base security role with additional permissions"
      }

      session
      |> navigate_to_domain("roles", tenant.id)
      |> click(RolesPage.new_role_button())
      |> fill_form("[data-test='role-form']", child_role_data)
      |> Wallaby.Browser.select(css("[data-test='parent-role']"), option: parent_role.name)
      |> click(css("[data-test='save-role']"))
      |> assert_has(Wallaby.Query.text("Inherits #{length(base_permissions)} permissions"))
      |> assert_has(css("[data-test='inherited-permissions']"))
    end

    test "user role assignment and management", %{session: session, tenant: tenant} do
      role = insert(:role, tenant: tenant, name: "Operator")
      user = insert(:user, tenant: tenant)

      session
      |> navigate_to_domain("users", tenant.id)
      |> click(css("[data-test='edit-user-#{user.id}']"))
      |> click(css("[data-test='roles-tab']"))
      |> click(css("[data-test='add-role']"))
      |> Wallaby.Browser.select(css("[data-test='role-select']"), option: role.name)
      |> fill_in(css("[data-test='assignment-reason']"), with: "Promoted to operator position")
      |> click(css("[data-test='assign-role']"))
      |> assert_flash_message("success", "Role assigned successfully")
      |> assert_has(Wallaby.Query.text(role.name))
      |> assert_has(css("[data-test='role-assignment'][data-role='#{role.id}']"))
    end

    test "role-based dashboard customization", %{session: session, tenant: tenant} do
      # Test different dashboard views based on roles
      operator_role = insert(:role, tenant: tenant, name: "Operator")
      admin_role = insert(:role, tenant: tenant, name: "Administrator")

      operator_user = insert(:user, tenant: tenant, role: "operator")

      # Login as operator
      session
      |> visit("/logout")
      |> authenticate_user(operator_user)
      |> visit("/dashboard")
      |> assert_has(css("[data-test='operator-dashboard']"))
      |> assert_has(css("[data-test='live-cameras-widget']"))
      |> assert_has(css("[data-test='active-alarms-widget']"))
      |> refute_has(css("[data-test='admin-controls']"))
      |> refute_has(css("[data-test='system-config-widget']"))
    end
  end

  describe "Device Security Management" do
    test "device security status monitoring", %{session: session, tenant: tenant} do
      secure_device = insert(:device, tenant: tenant, security_status: "secure")
      compromised_device = insert(:device, tenant: tenant, security_status: "compromised")

      session
      |> navigate_to_domain("devices", tenant.id)
      |> click(css("[data-test='security-view']"))
      |> assert_has(css("[data-test='device-#{secure_device.id}'][data-security='secure']"))
      |> assert_has(
        css("[data-test='device-#{compromised_device.id}'][data-security='compromised']")
      )
      |> click(css("[data-test='filter-compromised']"))
      |> assert_has(Wallaby.Query.text(compromised_device.name))
      |> refute_has(Wallaby.Query.text(secure_device.name))
    end

    test "device certificate management", %{session: session, tenant: tenant} do
      device = insert(:device, tenant: tenant)

      session
      |> navigate_to_domain("devices", tenant.id)
      |> click(css("[data-test='view-device-#{device.id}']"))
      |> click(css("[data-test='security-tab']"))
      |> click(css("[data-test='manage-certificates']"))
      |> assert_has(css("[data-test='current-certificate']"))
      |> click(css("[data-test='renew-certificate']"))
      |> assert_flash_message("success", "Certificate renewal initiated")
      |> assert_has(css("[data-test='certificate-status'][data-status='renewing']"))
    end

    test "device firmware security validation", %{session: session, tenant: tenant} do
      device = insert(:device, tenant: tenant, firmware_version: "1.2.3")

      session
      |> navigate_to_domain("devices", tenant.id)
      |> click(css("[data-test='view-device-#{device.id}']"))
      |> click(css("[data-test='security-tab']"))
      |> assert_has(css("[data-test='firmware-security-status']"))
      |> click(css("[data-test='check-firmware-security']"))
      |> wait_for_ajax()
      |> assert_has(css("[data-test='security-scan-result']"))
      |> assert_has(Wallaby.Query.text("No known vulnerabilities"))
      |> refute_has(Wallaby.Query.text("Security vulnerabilities detected"))
    end

    test "device isolation and quarantine", %{session: session, tenant: tenant} do
      suspicious_device = insert(:device, tenant: tenant, status: "online")

      session
      |> navigate_to_domain("devices", tenant.id)
      |> click(css("[data-test='view-device-#{suspicious_device.id}']"))
      |> click(css("[data-test='security-actions']"))
      |> click(css("[data-test='quarantine-device']"))
      |> fill_in(css("[data-test='quarantine-reason']"), with: "Suspected security breach")
      |> click(css("[data-test='confirm-quarantine']"))
      |> assert_flash_message("success", "Device quarantined successfully")
      |> assert_has(css("[data-test='device-status'][data-status='quarantined']"))
    end
  end

  describe "Alarm and Incident Response" do
    test "security alarm workflow from trigger to resolution", %{session: session, tenant: tenant} do
      device = insert(:device, tenant: tenant, type: "motion_sensor")

      # Simulate alarm trigger
      alarm =
        insert(:alarm_event,
          tenant: tenant,
          device: device,
          type: "motion_detected",
          priority: "high",
          status: "active"
        )

      session
      |> navigate_to_domain("alarms", tenant.id)
      |> assert_has(css("[data-test='active-alarm-#{alarm.id}']"))
      |> assert_has(css("[data-test='alarm-priority'][data-priority='high']"))
      |> click(AlarmsPage.acknowledge_button(alarm.id))
      |> fill_in(css("[data-test='acknowledgment-note']"),
        with: "Investigating motion detection"
      )
      |> click(css("[data-test='confirm-acknowledge']"))
      |> assert_flash_message("success", "Alarm acknowledged")
      |> assert_has(css("[data-test='alarm-status'][data-status='acknowledged']"))
    end

    test "incident escalation workflow", %{session: session, tenant: tenant} do
      alarm = insert(:alarm_event, tenant: tenant, priority: "medium", status: "active")

      session
      |> navigate_to_domain("alarms", tenant.id)
      |> click(css("[data-test='view-alarm-#{alarm.id}']"))
      |> click(css("[data-test='escalate-alarm']"))
      |> Wallaby.Browser.select(css("[data-test='escalation-level']"), option: "high")
      |> Wallaby.Browser.select(css("[data-test='escalation-target']"),
        option: "security_manager"
      )
      |> fill_in(css("[data-test='escalation-reason']"), with: "Requires immediate attention")
      |> click(css("[data-test='confirm-escalation']"))
      |> assert_flash_message("success", "Alarm escalated successfully")
      |> assert_has(css("[data-test='alarm-priority'][data-priority='high']"))
    end

    test "mass notification during security incidents", %{session: session, tenant: tenant} do
      incident = insert(:incident, tenant: tenant, type: "security_breach", status: "active")

      session
      |> navigate_to_domain("incidents", tenant.id)
      |> click(css("[data-test='view-incident-#{incident.id}']"))
      |> click(css("[data-test='send-notification']"))
      |> check(css("[data-test='notify-all-security']"))
      |> check(css("[data-test='notify-building-occupants']"))
      |> Wallaby.Browser.select(css("[data-test='notification-urgency']"), option: "immediate")
      |> fill_in(css("[data-test='notification-message']"),
        with: "Security incident in progress. Please follow evacuation procedures."
      )
      |> click(css("[data-test='send-notifications']"))
      |> assert_flash_message("success", "Emergency notifications sent")
    end

    test "security incident report generation", %{session: session, tenant: tenant} do
      incident =
        insert(:incident,
          tenant: tenant,
          type: "unauthorized_access",
          status: "resolved",
          resolved_at: DateTime.utc_now()
        )

      session
      |> navigate_to_domain("incidents", tenant.id)
      |> click(css("[data-test='view-incident-#{incident.id}']"))
      |> click(css("[data-test='generate-report']"))
      |> Wallaby.Browser.select(css("[data-test='report-type']"), option: "detailed")
      |> check(css("[data-test='include-timeline']"))
      |> check(css("[data-test='include-evidence']"))
      |> check(css("[data-test='include-witness-__statements']"))
      |> click(css("[data-test='generate-report-submit']"))
      |> assert_flash_message("success", "Incident report generated")
      |> assert_has(css("[data-test='download-report']"))
    end
  end

  describe "Security Monitoring Dashboard" do
    test "real-time security status overview", %{session: session, tenant: tenant} do
      # Create various security-related data
      active_alarms =
        Intelitor.Factory.insert_list(3, :alarm_event, tenant: tenant, status: "active")

      online_devices =
        Intelitor.Factory.insert_list(10, :device, tenant: tenant, status: "online")

      offline_devices =
        Intelitor.Factory.insert_list(2, :device, tenant: tenant, status: "offline")

      session
      |> navigate_to_domain("security-dashboard", tenant.id)
      |> assert_has(css("[data-test='active-alarms-count'][data-count='3']"))
      |> assert_has(css("[data-test='online-devices-count'][data-count='10']"))
      |> assert_has(css("[data-test='offline-devices-count'][data-count='2']"))
      |> assert_has(css("[data-test='security-status'][data-status='alert']"))
    end

    test "security metrics and trends visualization", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("security-dashboard", tenant.id)
      |> assert_has(css("[data-test='security-metrics-chart']"))
      |> click(css("[data-test='time-range-selector']"))
      |> click(css("[data-test='last-7-days']"))
      |> wait_for_ajax()
      |> assert_has(css("[data-test='chart-data'][data-period='7-days']"))
      |> assert_has(css("[data-test='trend-indicator']"))
    end

    test "security alert prioritization and filtering", %{session: session, tenant: tenant} do
      high_alarm = insert(:alarm_event, tenant: tenant, priority: "high", type: "intrusion")
      medium_alarm = insert(:alarm_event, tenant: tenant, priority: "medium", type: "motion")
      low_alarm = insert(:alarm_event, tenant: tenant, priority: "low", type: "maintenance")

      session
      |> navigate_to_domain("security-dashboard", tenant.id)
      |> click(css("[data-test='filter-high-priority']"))
      |> assert_has(css("[data-test='alarm-#{high_alarm.id}']"))
      |> refute_has(css("[data-test='alarm-#{medium_alarm.id}']"))
      |> refute_has(css("[data-test='alarm-#{low_alarm.id}']"))
      |> click(css("[data-test='filter-all-priorities']"))
      |> assert_has(css("[data-test='alarm-#{high_alarm.id}']"))
      |> assert_has(css("[data-test='alarm-#{medium_alarm.id}']"))
      |> assert_has(css("[data-test='alarm-#{low_alarm.id}']"))
    end

    test "security dashboard auto-refresh and real-time updates", %{
      session: session,
      tenant: tenant
    } do
      session
      |> navigate_to_domain("security-dashboard", tenant.id)
      |> assert_has(css("[data-test='auto-refresh-enabled']"))
      |> assert_has(css("[data-test='last-updated']"))

      # Test real-time update simulation
      |> execute_script("""
        window.testAlarmCreated = true;
        if (window.phoenixSocket) {
          window.phoenixSocket.channels[0].push('new_alarm', {
            id: 'test-alarm-123',
            type: 'test_alarm',
            priority: 'high'
          });
        }
      """)
      # Wait for real-time update
      |> :timer.sleep(2000)
      |> assert_has(css("[data-test='realtime-update-indicator']"))
    end
  end

  describe "Security Compliance and Auditing" do
    test "security compliance status monitoring", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("compliance", tenant.id)
      |> click(css("[data-test='security-compliance-tab']"))
      |> assert_has(css("[data-test='compliance-score']"))
      |> assert_has(css("[data-test='iso27001-status']"))
      |> assert_has(css("[data-test='soc2-status']"))
      |> click(css("[data-test='view-compliance-details']"))
      |> assert_has(css("[data-test='compliance-__requirements-list']"))
    end

    test "security audit trail comprehensive logging", %{session: session, tenant: tenant} do
      session
      |> navigate_to_domain("audit-logs", tenant.id)
      |> click(css("[data-test='security-events-filter']"))
      |> assert_has(css("[data-test='security-audit-entries']"))
      |> click(css("[data-test='advanced-search']"))
      |> Wallaby.Browser.select(css("[data-test='__event-category']"), option: "access_control")
      |> fill_in(css("[data-test='date-range-start']"),
        with: Date.utc_today() |> Date.add(-7) |> Date.to_string()
      )
      |> fill_in(css("[data-test='date-range-end']"),
        with: Date.utc_today() |> Date.to_string()
      )
      |> click(css("[data-test='apply-filter']"))
      |> assert_has(css("[data-test='filtered-audit-results']"))
    end
  end
end

# Agent: Helper-2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cybernetic coordination
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordination
# Multi-Agent Architecture: Integrated with 11-agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
