defmodule Indrajaal.PolicyFactory do
  @moduledoc """
  Factory definitions for Policy domain.
  Aligned with Ash domain APIs per SOPv5.1 Task 8.4.1.
  """

  defmacro __using__(_) do
    quote do
      # AGENT NOTE: role_factory uses Ash.create (no custom API)
      @spec role_factory(any()) :: any()
      def role_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        role_attrs =
          %{
            name: sequence(:name, &"role_#{&1}"),
            code: sequence(:code, &"ROLE_CODE_#{&1}"),
            description: "Test role",
            system_role?: false,
            assignable?: true,
            level: 1,
            metadata: %{}
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.Policy.Role,
               role_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, role} ->
            role

          {:error, changeset} ->
            raise "Failed to create role: #{inspect(changeset)}"
        end
      end

      # AGENT NOTE: permission_factory for RBAC testing
      @spec permission_factory(any()) :: any()
      def permission_factory(attrs \\ %{}) do
        # Normalize attrs to map (handles both keyword list and map input)
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        permission_attrs =
          %{
            name: sequence(:name, &"permission_#{&1}"),
            # Must match exactly "#{resource}:#{action}"
            code: "resource:read",
            resource: "resource",
            action: "read",
            description: "Test permission",
            category: :crud,
            scope: :tenant,
            conditions: %{},
            risk_level: :low,
            requires_mfa?: false,
            active?: true
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.Policy.Permission,
               permission_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, permission} ->
            permission

          {:error, changeset} ->
            raise "Failed to create permission: #{inspect(changeset)}"
        end
      end

      unquote(policy_factory_part_2())
    end
  end

  defp policy_factory_part_2 do
    quote do
      # AGENT NOTE: user_role_factory links users to roles
      @spec user_role_factory(any()) :: any()
      def user_role_factory(attrs \\ %{}) do
        user = attrs[:user] || insert(:user)
        role = attrs[:role] || insert(:role, tenant: user.tenant)

        user_role_attrs =
          %{
            user_id: user.id,
            role_id: role.id,
            tenant_id: user.tenant_id
          }
          |> merge_attributes(attrs)
          |> Map.delete(:user)
          |> Map.delete(:role)

        case Ash.create(
               Indrajaal.Policy.UserRole,
               user_role_attrs,
               actor: user,
               tenant: user.tenant_id
             ) do
          {:ok, user_role} ->
            user_role

          {:error, changeset} ->
            raise "Failed to create user role: #{inspect(changeset)}"
        end
      end

      # Alias for backwards compatibility - some tests use :role_assignment
      @spec role_assignment_factory(any()) :: any()
      def role_assignment_factory(attrs \\ %{}) do
        user_role_factory(attrs)
      end

      # AGENT NOTE: access_rule_factory for authorization testing
      @spec access_rule_factory(any()) :: any()
      def access_rule_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        access_rule_attrs =
          %{
            name: sequence(:rule_name, &"Access Rule #{&1}"),
            code: sequence(:rule_code, &"access_rule_#{&1}"),
            description: "Test access rule",
            rule_type: :conditional,
            resource_type: "resource",
            action: "read",
            conditions: %{"type" => "always"},
            effect: :allow,
            priority: 100,
            scope: :tenant,
            active?: Map.get(attrs_map, :active, true),
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:active)

        admin_actor = Indrajaal.ActorHelpers.admin_actor(tenant.id)

        case Ash.create(
               Indrajaal.Policy.AccessRule,
               access_rule_attrs,
               actor: admin_actor,
               tenant: tenant.id
             ) do
          {:ok, access_rule} ->
            access_rule

          {:error, changeset} ->
            raise "Failed to create access rule: #{inspect(changeset)}"
        end
      end
    end
  end
end
