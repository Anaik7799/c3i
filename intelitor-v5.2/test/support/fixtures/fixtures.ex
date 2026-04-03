defmodule Indrajaal.Fixtures do
  @moduledoc """
  Test fixtures for complex test scenarios.
  """

  @doc """
  Creates a complete test environment with all domains
  """
  @spec create_test_environment() :: any()
  def create_test_environment do
    # Create tenant
    tenant = Indrajaal.Factory.insert(:tenant, name: "Test Environment")

    # Create users and teams
    admin_user = create_admin_user(tenant)
    operator_user = create_operator_user(tenant)
    customer_user = create_customer_user(tenant)

    # Create sites and devices
    site = create_test_site(tenant)
    devices = create_test_devices(site)

    # Create initial configuration
    create_system_config(tenant)

    %{
      tenant: tenant,
      users: %{
        admin: admin_user,
        operator: operator_user,
        customer: customer_user
      },
      site: site,
      devices: devices
    }
  end

  @spec create_admin_user(term()) :: term()
  defp create_admin_user(tenant) do
    user =
      Indrajaal.Factory.insert(:user,
        tenant_id: tenant.id,
        email: "admin@test.com"
      )

    admin_role =
      Indrajaal.Factory.insert(:role,
        name: "Admin",
        permissions: ["*"]
      )

    Indrajaal.Factory.insert(:role_assignment,
      user_id: user.id,
      role_id: admin_role.id
    )

    user
  end

  @spec create_operator_user(term()) :: term()
  defp create_operator_user(tenant) do
    user =
      Indrajaal.Factory.insert(:user,
        tenant_id: tenant.id,
        email: "operator@test.com"
      )

    operator_role =
      Indrajaal.Factory.insert(:role,
        name: "Operator",
        permissions: ["alarms:view", "alarms:acknowledge", "devices:view"]
      )

    Indrajaal.Factory.insert(:role_assignment,
      user_id: user.id,
      role_id: operator_role.id
    )

    user
  end

  @spec create_customer_user(term()) :: term()
  defp create_customer_user(tenant) do
    Indrajaal.Factory.insert(:user,
      tenant_id: tenant.id,
      email: "customer@test.com"
    )
  end

  @spec create_test_site(term()) :: term()
  defp create_test_site(tenant) do
    Indrajaal.Factory.insert(:site,
      tenant_id: tenant.id,
      name: "Test Facility",
      address: "123 Test St"
    )
  end

  @spec create_test_devices(term()) :: term()
  defp create_test_devices(site) do
    [
      Indrajaal.Factory.insert(:panel, site_id: site.id),
      Indrajaal.Factory.insert(:sensor, site_id: site.id, type: "motion"),
      Indrajaal.Factory.insert(:sensor, site_id: site.id, type: "door"),
      Indrajaal.Factory.insert(:camera, site_id: site.id)
    ]
  end

  @spec create_system_config(term()) :: term()
  defp create_system_config(tenant) do
    configs = [
      %{key: "alarm.auto_close_timeout", value: "300", type: "integer"},
      %{key: "video.retention_days", value: "30", type: "integer"},
      %{key: "dispatch.sla_minutes", value: "15", type: "integer"}
    ]

    Enum.each(configs, fn config ->
      Indrajaal.Factory.insert(:system_config, Map.put(config, :tenant_id, tenant.id))
    end)
  end
end
