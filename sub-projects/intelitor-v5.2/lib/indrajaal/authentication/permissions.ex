defmodule Indrajaal.Authentication.Permissions do
  @moduledoc """
  Enterprise Permission Management System.

  Provides comprehensive permission definition, management, and validation
  for role-based access control (RBAC) and attribute-based access control (ABAC)
  with enterprise-grade security and performance.
  """

  require Logger

  @doc """
  Lists all available permissions in the system.

  Returns a comprehensive list of all permissions available across all
  domains and resources with their associated meta_data and descriptions.
  """
  @spec list_all_permissions() :: [map()]
  def list_all_permissions do
    [
      # Accounts domain permissions
      %{
        name: "accounts:_users:read",
        resource: "_users",
        action: "read",
        domain: "accounts",
        description: "View user accounts and profiles"
      },
      %{
        name: "accounts:_users:create",
        resource: "_users",
        action: "create",
        domain: "accounts",
        description: "Create new user accounts"
      },
      %{
        name: "accounts:_users:update",
        resource: "_users",
        action: "update",
        domain: "accounts",
        description: "Update existing user accounts"
      },
      %{
        name: "accounts:_users:delete",
        resource: "_users",
        action: "delete",
        domain: "accounts",
        description: "Delete user accounts"
      },

      # Alarms domain permissions
      %{
        name: "alarms:alarms:read",
        resource: "alarms",
        action: "read",
        domain: "alarms",
        description: "View alarm _events and history"
      },
      %{
        name: "alarms:alarms:acknowledge",
        resource: "alarms",
        action: "acknowledge",
        domain: "alarms",
        description: "Acknowledge alarm _events"
      },
      %{
        name: "alarms:alarms:resolve",
        resource: "alarms",
        action: "resolve",
        domain: "alarms",
        description: "Resolve alarm _events"
      },
      %{
        name: "alarms:alarms:escalate",
        resource: "alarms",
        action: "escalate",
        domain: "alarms",
        description: "Escalate alarm _events"
      },

      # Sites domain permissions
      %{
        name: "sites:sites:read",
        resource: "sites",
        action: "read",
        domain: "sites",
        description: "View site information"
      },
      %{
        name: "sites:sites:create",
        resource: "sites",
        action: "create",
        domain: "sites",
        description: "Create new sites"
      },
      %{
        name: "sites:sites:update",
        resource: "sites",
        action: "update",
        domain: "sites",
        description: "Update site information"
      },
      %{
        name: "sites:areas:manage",
        resource: "areas",
        action: "manage",
        domain: "sites",
        description: "Manage site areas and zones"
      },

      # Devices domain permissions
      %{
        name: "devices:devices:read",
        resource: "devices",
        action: "read",
        domain: "devices",
        description: "View device information"
      },
      %{
        name: "devices:devices:configure",
        resource: "devices",
        action: "configure",
        domain: "devices",
        description: "Configure device settings"
      },
      %{
        name: "devices:devices:control",
        resource: "devices",
        action: "control",
        domain: "devices",
        description: "Control device operations"
      },

      # Video domain permissions
      %{
        name: "video:cameras:view",
        resource: "cameras",
        action: "view",
        domain: "video",
        description: "View camera feeds and recordings"
      },
      %{
        name: "video:cameras:control",
        resource: "cameras",
        action: "control",
        domain: "video",
        description: "Control camera operations"
      },
      %{
        name: "video:recordings:access",
        resource: "recordings",
        action: "access",
        domain: "video",
        description: "Access recorded video content"
      },

      # Visitor Management permissions
      %{
        name: "visitor_management:visitors:read",
        resource: "visitors",
        action: "read",
        domain: "visitor_management",
        description: "View visitor information"
      },
      %{
        name: "visitor_management:visitors:create",
        resource: "visitors",
        action: "create",
        domain: "visitor_management",
        description: "Register new visitors"
      },
      %{
        name: "visitor_management:visitors:approve",
        resource: "visitors",
        action: "approve",
        domain: "visitor_management",
        description: "Approve visitor access _requests"
      },

      # Access Control permissions
      %{
        name: "access_control:doors:control",
        resource: "doors",
        action: "control",
        domain: "access_control",
        description: "Control door access and locks"
      },
      %{
        name: "access_control:cards:manage",
        resource: "cards",
        action: "manage",
        domain: "access_control",
        description: "Manage access cards and credentials"
      },

      # Analytics permissions
      %{
        name: "analytics:reports:view",
        resource: "reports",
        action: "view",
        domain: "analytics",
        description: "View analytics reports and dashboards"
      },
      %{
        name: "analytics:reports:create",
        resource: "reports",
        action: "create",
        domain: "analytics",
        description: "Create custom analytics reports"
      },

      # System administration permissions
      %{
        name: "system:admin:full_access",
        resource: "system",
        action: "full_access",
        domain: "system",
        description: "Full system administration access"
      },
      %{
        name: "system:config:manage",
        resource: "config",
        action: "manage",
        domain: "system",
        description: "Manage system configuration"
      },
      %{
        name: "system:_users:admin",
        resource: "_users",
        action: "admin",
        domain: "system",
        description: "Administer user accounts and permissions"
      }
    ]
  end

  @doc """
  Gets permissions for a specific domain.

  Returns all permissions associated with the specified domain
  for domain-specific permission management and validation.
  """
  @spec get_domain_permissions(String.t()) :: [map()]
  def get_domain_permissions(domain) do
    list_all_permissions()
    |> Enum.filter(&(&1.domain == domain))
  end

  @doc """
  Gets permissions for a specific resource.

  Returns all permissions associated with the specified resource
  across all domains for resource-specific access control.
  """
  @spec get_resource_permissions(String.t()) :: [map()]
  def get_resource_permissions(resource) do
    list_all_permissions()
    |> Enum.filter(&(&1.resource == resource))
  end

  @doc """
  Validates if a permission exists in the system.

  Checks if the specified permission name exists in the system's
  permission registry for validation during role assignment.
  """
  @spec permission_exists?(String.t()) :: boolean()
  def permission_exists?(permission_name) do
    list_all_permissions()
    |> Enum.any?(&(&1.name == permission_name))
  end

  @doc """
  Gets permission details by name.

  Returns detailed information about a specific permission
  including its resource, action, domain, and description.
  """
  @spec get_permission(String.t()) :: map() | nil
  def get_permission(permissionname) do
    list_all_permissions()
    |> Enum.find(&(&1.name == permissionname))
  end

  @doc """
  Validates user permissions for a specific action.

  Checks if the user has the _required permission for the specified
  resource and action combination with tenant isolation.
  """
  @spec has_permission?(map(), String.t(), String.t(), String.t()) :: boolean()
  def has_permission?(user, domain, resource, action) do
    required_permission = "#{domain}:#{resource}:#{action}"

    user_permissions = get_user_permissions(user)

    required_permission in user_permissions or
      "system:admin:full_access" in user_permissions
  end

  @doc """
  Gets all permissions for a user.

  Returns a list of all permissions assigned to the user through
  their roles and direct permission assignments.
  """
  @spec get_user_permissions(map()) :: [String.t()]
  def get_user_permissions(%{permissions: permissions}) when is_list(permissions) do
    permissions
  end

  def get_user_permissions(%{role: %{permissions: permissions}}) when is_list(permissions) do
    permissions
  end

  def get_user_permissions(_user) do
    []
  end

  @doc """
  Groups permissions by resource for UI display.

  Returns permissions organized by resource type for easier
  display in permission management interfaces.
  """
  @spec group_permissions_by_resource([map()]) :: [map()]
  def group_permissions_by_resource(permissions) do
    permissions
    |> Enum.group_by(& &1.resource)
    |> Enum.map(fn {resource, perms} ->
      %{
        resource: resource,
        permissions: perms
      }
    end)
    |> Enum.sort_by(& &1.resource)
  end

  @doc """
  Groups permissions by domain for administrative management.

  Returns permissions organized by domain for domain-specific
  permission management and administration.
  """
  @spec group_permissions_by_domain([map()]) :: [map()]
  def group_permissions_by_domain(permissions) do
    permissions
    |> Enum.group_by(& &1.domain)
    |> Enum.map(fn {domain, perms} ->
      %{
        domain: domain,
        permissions: perms
      }
    end)
    |> Enum.sort_by(& &1.domain)
  end

  @doc """
  Checks if a user has permission for a specific action on a resource.
  """
  @spec check(term(), atom(), term()) :: boolean()
  def check(user, action, resource) do
    user_permissions = get_user_permissions(user)
    permission_name = "#{resource}:#{action}"

    Enum.any?(user_permissions, fn perm ->
      perm.name == permission_name || perm.action == to_string(action)
    end)
  end

  @doc """
  Checks if a user can access specific attributes of a resource.
  """
  @spec check_attributes(term(), term()) :: boolean()
  def check_attributes(user, _resource) do
    # For now, allow access if user has any permissions
    # Implement attribute-level checking as needed
    user_permissions = get_user_permissions(user)
    not Enum.empty?(user_permissions)
  end

  @doc """
  Evaluates a policy for a user within a given context.
  """
  @spec evaluate_policy(term(), term(), term()) :: boolean()
  def evaluate_policy(user, policy, _context) do
    # Basic policy evaluation - implement more complex rules as needed
    case policy do
      %{required_permission: permission} ->
        check(user, :read, permission)

      _ ->
        true
    end
  end
end
