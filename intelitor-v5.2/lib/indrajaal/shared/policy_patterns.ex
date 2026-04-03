defmodule Indrajaal.Shared.PolicyPatterns do
  @moduledoc """
  Shared policy authorization patterns to eliminate duplication across
    policy domain.

  This module extracts common authorization patterns used by:
  - Policy.AccessRule (mass: 35)
  - Policy.RolePermission (mass: 35)
  - Policy.UserRole (mass: 30)
  - Policy.Permission (mass: 22)
  - Other policy resources with similar patterns

  Following Toyota TPS principles to eliminate duplicate code waste.
  """

  require Ash.Query

  defmacro admin_and_security_admin_policies do
    quote do
      policy action_type(:read) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "security_admin")
      end

      policy action_type(:create) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "security_admin")
      end

      policy action_type(:update) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "security_admin")
      end

      policy action_type(:destroy) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "security_admin")
      end
    end
  end

  @doc """
  Creates standard admin authorization policies.

  ## Parameters
    - `additional_roles` - Additional roles that can perform admin actions
      (default: [])

  ## Returns
  Map with policy configuration for admin access.

  ## Example
      policies do
        use Indrajaal.Shared.PolicyPatterns.admin_policies()
      end

      # Or with additional roles
      policies do
        use Indrajaal.Shared.PolicyPatterns.admin_policies(["security_admin",
          "system_admin"])
      end
  """
  @spec admin_policies(list(String.t())) :: map()
  def admin_policies(additional_roles \\ []) do
    base_roles = ["admin"]
    all_roles = base_roles ++ additional_roles

    %{
      read: create_role_policy(:read, all_roles),
      create: create_role_policy(:create, all_roles),
      update: create_role_policy(:update, all_roles),
      destroy: create_role_policy(:destroy, all_roles)
    }
  end

  @doc """
  Creates a role - based policy for specific action types.

  ## Parameters
    - `action_type` - The action type (:read, :create, :update, :destroy)
    - `allowed_roles` - List of roles that can perform the action

  ## Returns
  Policy configuration map.
  """
  @spec create_role_policy(atom(), list(String.t())) :: map()
  def create_role_policy(action_type, allowed_roles) do
    %{
      action_type: action_type,
      conditions:
        Enum.map(allowed_roles, fn role ->
          {:authorize_if, {:actor_attribute_equals, [:role, role]}}
        end)
    }
  end

  @doc """
  Creates tenant - based authorization policy.

  ## Parameters
    - `action_type` - The action type
    - `tenant_field` - Field name for tenant ID (default: :tenant_id)

  ## Returns
  Policy configuration for tenant isolation.
  """
  def tenantpolicy(action_type, tenant_field \\ :tenant_id) do
    %{
      action_type: action_type,
      conditions: [
        {:authorize_if, {:relates_to_actor_via, [tenant_field]}}
      ]
    }
  end

  @doc """
  Creates a combined role and tenant policy.

  ## Parameters
    - `action_type` - The action type
    - `allowed_roles` - List of roles that can perform the action
    - `tenant_field` - Field name for tenant ID (default: :tenant_id)

  ## Returns
  Policy configuration combining role and tenant checks.
  """
  def roleand_tenant_policy(action_type, allowed_roles, tenant_field \\ :tenantid) do
    role_conditions =
      Enum.map(allowed_roles, fn role ->
        {:authorize_if, {:actor_attribute_equals, [:role, role]}}
      end)

    tenant_condition = {:authorize_if, {:relates_to_actor_via, [tenant_field]}}

    %{
      action_type: action_type,
      conditions: role_conditions ++ [tenant_condition]
    }
  end

  @doc """
  Creates time - based expiration validation.

  ## Parameters
    - `expires_field` - Field name for expiration (default: :expires_at)
    - `allow_nil` - Whether nil expiration is allowed (default: true)

  ## Returns
  Validation function for expiration dates.
  """
  def expirationvalidation(expires_field \\ :expiresat, allow_nil \\ true) do
    fn changeset ->
      expires_at = Ash.Changeset.get_attribute(changeset, expires_field)

      cond do
        is_nil(expires_at) and allow_nil ->
          {:ok, changeset}

        is_nil(expires_at) and not allow_nil ->
          {:error, field: expires_field, message: "expiration date is _required"}

        DateTime.compare(expires_at, DateTime.utc_now()) == :lt ->
          {:error, field: expires_field, message: "must be in the future"}

        true ->
          {:ok, changeset}
      end
    end
  end

  @doc """
  Creates conditional rule validation.

  ## Parameters
    - `rule_type_field` - Field name for rule type (default: :rule_type)
    - `conditions_field` - Field name for conditions (default: :conditions)

  ## Returns
  Validation function for conditional rules.
  """
  def conditionalrule_validation(
        rule_type_field \\ :ruletype,
        conditions_field \\ :conditions
      ) do
    fn changeset ->
      rule_type = Ash.Changeset.get_attribute(changeset, rule_type_field)
      conditions = Ash.Changeset.get_attribute(changeset, conditions_field)

      case {rule_type, conditions} do
        {:conditional, c} when c == %{} ->
          {:error, field: conditions_field, message: "_required for conditional rules"}

        _ ->
          {:ok, changeset}
      end
    end
  end

  @doc """
  Creates a resource ownership policy.

  ## Parameters
    - `action_type` - The action type
    - `owner_field` - Field name for owner ID (default: :user_id)

  ## Returns
  Policy configuration for resource ownership.
  """
  def ownershippolicy(action_type, owner_field \\ :userid) do
    %{
      action_type: action_type,
      conditions: [
        {:authorize_if, {:actor_attribute_equals, [owner_field, {:actor, :id}]}}
      ]
    }
  end

  @doc """
  Creates hierarchical permission policy (parent - child relationships).

  ## Parameters
    - `action_type` - The action type
    - `parent_field` - Field name for parent resource (default: :parent_id)
    - `allowed_roles` - Roles that can manage hierarchy

  ## Returns
  Policy configuration for hierarchical access.
  """
  def hierarchicalpolicy(
        action_type,
        parent_field \\ :parentid,
        allowed_roles \\ ["admin", "manager"]
      ) do
    role_conditions =
      Enum.map(allowed_roles, fn role ->
        {:authorize_if, {:actor_attribute_equals, [:role, role]}}
      end)

    parent_condition = {:authorize_if, {:relates_to_actor_via, [parent_field]}}

    %{
      action_type: action_type,
      conditions: role_conditions ++ [parent_condition]
    }
  end

  @doc """
  Creates a time - window based policy (e.g., business hours).

  ## Parameters
    - `action_type` - The action type
    - `start_hour` - Start hour (24h format, default: 9)
    - `end_hour` - End hour (24h format, default: 17)
    - `allowed_roles` - Roles that can override time restrictions

  ## Returns
  Policy configuration for time - based access.
  """
  @spec time_window_policy(atom(), integer(), integer(), list(String.t())) :: map()
  def time_window_policy(action_type, start_hour \\ 9, end_hour \\ 17, allowed_roles \\ ["admin"]) do
    %{
      action_type: action_type,
      conditions: [
        {:authorize_if,
         {:satisfies,
          fn _actor, __context ->
            current_hour = DateTime.utc_now().hour
            current_hour >= start_hour and current_hour < end_hour
          end}},
        # Or if user has override role
        {:authorize_if, {:actor_attribute_in, [:role, allowed_roles]}}
      ]
    }
  end

  @doc """
  Creates a quota - based policy (e.g., max resources per user).

  ## Parameters
    - `action_type` - The action type (typically :create)
    - `resource_module` - The resource module to count
    - `max_count` - Maximum allowed resources
    - `count_field` - Field to count by (default: :user_id)

  ## Returns
  Policy configuration for quota enforcement.
  """
  def quotapolicy(action_type, resource_module, max_count, _count_field \\ :userid) do
    %{
      action_type: action_type,
      conditions: [
        {:authorize_if,
         {:satisfies,
          fn actor, __context ->
            case actor do
              %{id: user_id} ->
                count =
                  resource_module
                  |> Ash.Query.filter(user_id: user_id)
                  |> Ash.read!()
                  |> length()

                count < max_count

              _ ->
                false
            end
          end}}
      ]
    }
  end

  @doc """
  Creates a feature flag based policy.

  ## Parameters
    - `action_type` - The action type
    - `feature_flag` - Name of the feature flag
    - `fallback_roles` - Roles that can access when feature is disabled

  ## Returns
  Policy configuration for feature flag access.
  """
  @spec feature_flag_policy(atom(), String.t(), list(String.t())) :: map()
  def feature_flag_policy(action_type, feature_flag, fallback_roles \\ ["admin"]) do
    %{
      action_type: action_type,
      conditions: [
        {:authorize_if,
         {:satisfies,
          fn _actor, context ->
            # Check if feature flag is enabled for tenant
            case Map.get(context, :tenant) do
              %{feature_flags: flags} when is_map(flags) ->
                Map.get(flags, feature_flag, false)

              _ ->
                false
            end
          end}},
        # Or if user has fallback role
        {:authorize_if, {:actor_attribute_in, [:role, fallback_roles]}}
      ]
    }
  end

  @doc """
  Macro to generate common policy patterns.

  ## Example
      defmodule MyResource do
        use Ash.Resource
        use Indrajaal.Shared.PolicyPatterns

        policies do
          standard_admin_policies()
          tenant_isolation_policy()
          time_window_restriction(:create, 9, 17)
        end
      end
  """
  defmacro standard_admin_policies(additional_roles \\ []) do
    quote do
      policy action_type(:read) do
        authorize_if actor_attribute_equals(:role, "admin")
        authorize_if actor_attribute_equals(:role, "security_admin")

        unquote(
          for role <- additional_roles do
            quote do
              authorize_if actor_attribute_equals(:role, unquote(role))
            end
          end
        )
      end

      policy action_type(:create) do
        authorize_if actor_attribute_equals(:role, "admin")

        unquote(
          for role <- additional_roles do
            quote do
              authorize_if actor_attribute_equals(:role, unquote(role))
            end
          end
        )
      end

      policy action_type(:update) do
        authorize_if actor_attribute_equals(:role, "admin")

        unquote(
          for role <- additional_roles do
            quote do
              authorize_if actor_attribute_equals(:role, unquote(role))
            end
          end
        )
      end

      policy action_type(:destroy) do
        authorize_if actor_attribute_equals(:role, "admin")

        unquote(
          for role <- additional_roles do
            quote do
              authorize_if actor_attribute_equals(:role, unquote(role))
            end
          end
        )
      end
    end
  end

  defmacro tenant_isolation_policy(tenant_field \\ :tenant_id) do
    quote do
      policy action_type([:read, :create, :update, :destroy]) do
        authorize_if relates_to_actor_via(unquote(tenant_field))
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__),
        only: [
          standard_admin_policies: 0,
          standard_admin_policies: 1,
          tenant_isolation_policy: 0,
          tenant_isolation_policy: 1
        ]
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
