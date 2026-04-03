defmodule Indrajaal.PolicyComprehensiveFactory do
  @moduledoc """
  Comprehensive factory definitions for Policy domain with 50+ items per
    resource.
  Implements realistic authorization patterns for enterprise security.
  """

  alias Indrajaal.Shared.TestSupport
  # alias Indrajaal.Policy  # Not needed - using Ash.create directly

  @spec bulk_create_roles(any(), any()) :: any()
  def bulk_create_roles(count, options \\ []) do
    # Replaced with TestSupport.bulk_create
    TestSupport.bulk_create(:role, count, options)
  end

  # @spec _original_bulk_create_roles(integer(), list()) :: term()
  # def _original_bulk_create_roles(count, options \\ []) do
  #   tenant = Keyword.get(options, :tenant)

  #   # Create base roles first
  #   base_roles =
  #     Enum.map(1..count, fn i ->
  #       create_role(tenant, %{
  #         name: "Role #{i}",
  #         description: "Standard role #{i}",
  #         level: Enum.random(10..90),
  #         type: Enum.random(["operational", "administrative", "read_only"])
  #       })
  #     end)

  #   # Add specialized roles
  #   specialized_roles = [
  #     create_role(tenant, %{
  #       name: "Emergency Override",
  #       description: "Emergency access with full permissions",
  #       level: 95,
  #       type: "emergency",
  #       requires_mfa: true,
  #       time_limited: true,
  #       max_duration_hours: 4
  #     }),
  #     create_role(tenant, %{
  #       name: "Compliance Auditor",
  #       description: "Read-only access to all audit logs",
  #       level: 60,
  #       type: "audit",
  #       read_only: true,
  #       audit_access: true
  #     }),
  #     create_role(tenant, %{
  #       name: "Integration Service",
  #       description: "API access for external integrations",
  #       level: 50,
  #       type: "service",
  #       api_only: true,
  #       ip_restricted: true
  #     }),
  #     create_role(tenant, %{
  #       name: "Temporary Contractor",
  #       description: "Time-limited access for contractors",
  #       level: 35,
  #       type: "temporary",
  #       expires_at: DateTime.add(DateTime.utc_now(), 30 * 86_400, :second)
  #     }),
  #     create_role(tenant, %{
  #       name: "Training Mode",
  #       description: "Limited access for training purposes",
  #       level: 25,
  #       type: "training",
  #       sandbox_only: true
  #     })
  #   ]

  #   base_roles ++ specialized_roles
  # end

  @spec bulk_create_permissions(any(), any()) :: any()
  def bulk_create_permissions(count, options \\ []) do
    # Replaced with TestSupport.bulk_create
    TestSupport.bulk_create(:permission, count, options)
  end

  # @spec _original_bulk_create_permissions(integer(), list()) :: term()
  # def _original_bulk_create_permissions(count, options \\ []) do
  #   tenant = Keyword.get(options, :tenant)

  #   # Create base permissions first
  #   permissions =
  #     Enum.map(1..count, fn i ->
  #       create_permission(tenant, %{
  #         name: "permission_#{i}",
  #         category: "standard",
  #         description: "Standard permission #{i}",
  #         resource: "resource_#{rem(i, 10)}",
  #         action: Enum.random(["read", "write", "delete", "execute"])
  #       })
  #     end)

  #   # Add dynamic permissions
  #   dynamic_permissions = [
  #     create_permission(tenant, %{
  #       name: "dynamic.time_based_access",
  #       category: "dynamic",
  #       description: "Access that varies by time of day",
  #       conditions: %{
  #         "time_ranges" => ["08:00-18:00", "22:00-06:00"],
  #         "days_of_week" => ["mon", "tue", "wed", "thu", "fri"]
  #       }
  #     }),
  #     create_permission(tenant, %{
  #       name: "dynamic.location_based_access",
  #       category: "dynamic",
  #       description: "Access that varies by location",
  #       conditions: %{
  #         "allowed_ips" => ["192.168.1.0/24", "10.0.0.0/8"],
  #         "geo_fence" => %{"lat" => 40.7128, "lon" => -74.0060, "radius_km" => 50}
  #       }
  #     }),
  #     create_permission(tenant, %{
  #       name: "dynamic.risk_adaptive",
  #       category: "dynamic",
  #       description: "Access that adapts based on risk score",
  #       conditions: %{
  #         "max_risk_score" => 50,
  #         "require_additional_auth" => true
  #       }
  #     })
  #   ]

  #   permissions ++ dynamic_permissions
  # end

  @spec bulk_create_access_rules(term(), term(), term()) :: term()
  def bulk_create_access_rules(count, roles, permissions) do
    # Replaced with TestSupport.bulk_create
    TestSupport.bulk_create(:access_rule, count, %{roles: roles, permissions: permissions})
  end

  # @spec _original_bulk_create_access_rules(integer(), term(), term()) :: term()
  # def _original_bulk_create_access_rules(count, roles, permissions) do
  #   tenant = List.first(roles).tenant_id |> (&%{id: &1}).()

  #   rule_templates = [
  #     %{
  #       name: "Business Hours Access",
  #       type: "time_based",
  #       conditions: %{
  #         "time_start" => "08:00",
  #         "time_end" => "18:00",
  #         "days" => ["monday", "tuesday", "wednesday", "thursday", "friday"],
  #         "timezone" => "America/New_York"
  #       },
  #       action: "allow",
  #       priority: 50
  #     },
  #     %{
  #       name: "Emergency Override",
  #       type: "emergency",
  #       conditions: %{
  #         "alarm_severity" => ["critical", "high"],
  #         "requires_approval" => false,
  #         "max_duration_minutes" => 60
  #       },
  #       action: "allow",
  #       priority: 90
  #     },
  #     %{
  #       name: "Geo-Restricted Access",
  #       type: "location",
  #       conditions: %{
  #         "allowed_countries" => ["US", "CA", "UK"],
  #         "blocked_regions" => ["sanctioned_list"],
  #         "vpn_allowed" => false
  #       },
  #       action: "allow",
  #       priority: 60
  #     },
  #     %{
  #       name: "Device Type Restriction",
  #       type: "device",
  #       conditions: %{
  #         "allowed_devices" => ["desktop", "tablet"],
  #         "blocked_devices" => ["mobile"],
  #         "require_device_registration" => true
  #       },
  #       action: "conditional",
  #       priority: 40
  #     },
  #     %{
  #       name: "High Risk Block",
  #       type: "risk_based",
  #       conditions: %{
  #         "max_risk_score" => 30,
  #         "block_tor" => true,
  #         "block_vpn" => true,
  #         "require_mfa" => true
  #       },
  #       action: "deny",
  #       priority: 80
  #     },
  #     %{
  #       name: "Maintenance Window",
  #       type: "maintenance",
  #       conditions: %{
  #         "recurring" => "weekly",
  #         "day" => "sunday",
  #         "time_start" => "02:00",
  #         "time_end" => "06:00",
  #         "allowed_roles" => ["admin", "maintenance"]
  #       },
  #       action: "allow",
  #       priority: 70
  #     }
  #   ]

  #   rules =
  #     Enum.flat_map(rule_templates, fn template ->
  #       rule_count = div(count, length(rule_templates))

  #       Enum.map(1..rule_count, fn i ->
  #         # Get random permissions for this rule
  #         selected_permissions =
  #           Enum.take_random(
  #             permissions,
  #             :rand.uniform(5) + 1
  #           )

  #         create_access_rule(tenant, %{
  #           name: "#{template.name} #{i}",
  #           description: "#{template.type} access control rule",
  #           rule_type: template.type,
  #           conditions:
  #             Map.merge(template.conditions, %{
  #               "instance" => i,
  #               "created_at" => DateTime.utc_now()
  #             }),
  #           action: template.action,
  #           priority: template.priority + rem(i, 10),
  #           permissions: Enum.map(selected_permissions, & &1.id),
  #           # 90% active
  #           active: :rand.uniform(100) > 10,
  #           metadata: %{
  #             "version" => "1.0",
  #             "author" => "security_team",
  #             "last_reviewed" => Date.utc_today()
  #           }
  #         })
  #       end)
  #     end)

  #   # Add edge case rules
  #   edge_rules = [
  #     create_access_rule(tenant, %{
  #       name: "Deny All - Lockdown",
  #       rule_type: "lockdown",
  #       conditions: %{"lockdown_active" => true},
  #       action: "deny",
  #       priority: 100,
  #       permissions: Enum.map(permissions, & &1.id)
  #     }),
  #     create_access_rule(tenant, %{
  #       name: "Allow All - Testing",
  #       rule_type: "testing",
  #       conditions: %{"environment" => "test"},
  #       action: "allow",
  #       priority: 0,
  #       active: false
  #     }),
  #     create_access_rule(tenant, %{
  #       name: "Conditional MFA",
  #       rule_type: "adaptive",
  #       conditions: %{
  #         "risk_score_threshold" => 50,
  #         "new_device" => true,
  #         "unusual_location" => true
  #       },
  #       action: "require_mfa",
  #       priority: 75
  #     })
  #   ]

  #   rules ++ edge_rules
  # end

  @spec bulk_create_role_permissions(any(), any()) :: any()
  def bulk_create_role_permissions(roles, permissions) do
    # Replaced with TestSupport.bulk_create
    TestSupport.bulk_create(:role_permission, length(roles), %{
      roles: roles,
      permissions: permissions
    })
  end

  # @spec _original_bulk_create_role_permissions(term(), term()) :: term()
  # def _original_bulk_create_role_permissions(roles, permissions) do
  #   role_permission_mappings =
  #     Enum.flat_map(roles, fn role ->
  #       # Base number of permissions per role
  #       permission_count = div(length(permissions), 3) + :rand.uniform(10)
  #       # Select permissions based on role type
  #       selected_permissions = select_permissions_for_role(role, permissions, permission_count)
  #       Enum.map(selected_permissions, fn permission ->
  #         create_role_permission(%{
  #           role_id: role.id,
  #           permission_id: permission.id,
  #           granted_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(365 * 86_400), :second),
  #           granted_by: "system_admin",
  #           conditions: role_permission_conditions(role, permission),
  #           metadata: %{
  #             "audit_trail" => true,
  #             "review_required" => permission.risk_level == "critical"
  #           }
  #         })
  #       end)
  #     end)
  #   role_permission_mappings
  # end

  @spec bulk_create_user_roles(any(), any()) :: any()
  def bulk_create_user_roles(users, roles) do
    # Replaced with TestSupport.bulk_create
    TestSupport.bulk_create(:user_role, length(users), %{users: users, roles: roles})
  end

  # @spec _original_bulk_create_user_roles(map(), term()) :: term()
  # def _original_bulk_create_user_roles(users, roles) do
  #   user_roles =
  #     Enum.flat_map(users, fn user ->
  #       # Each user gets 2-5 roles
  #       role_count = 2 + :rand.uniform(3)
  #       # Select appropriate roles
  #       selected_roles = select_roles_for_user(user, roles, role_count)
  #       Enum.map(selected_roles, fn role ->
  #         create_user_role(%{
  #           user_id: user.id,
  #           role_id: role.id,
  #           tenant_id: user.tenant_id,
  #           assigned_at: DateTime.add(DateTime.utc_now(), -:rand.uniform(180 * 86_400), :second),
  #           assigned_by: "hr_system",
  #           expires_at:
  #             if(role.type == "temporary",
  #               do: DateTime.add(DateTime.utc_now(), 30 * 86_400, :second),
  #               else: nil
  #             ),
  #           # 95% active
  #           active: :rand.uniform(100) > 5,
  #           metadata: %{
  #             "assignment_reason" => assignment_reason(user, role),
  #             "approval_ticket" => "TICK-#{:rand.uniform(9999)}",
  #             "department" => user.metadata["department"] || "Security"
  #           }
  #         })
  #       end)
  #     end)
  #   # Add some edge cases
  #   edge_cases =
  #     if length(users) > 10 do
  #       [
  #         # User with expired role
  #         create_user_role(%{
  #           user_id: Enum.at(users, 0).id,
  #           role_id: Enum.find(roles, &(&1.type == "temporary")).id,
  #           tenant_id: Enum.at(users, 0).tenant_id,
  #           expires_at: DateTime.add(DateTime.utc_now(), -86_400, :second),
  #           active: false
  #         }),
  #         # User with emergency role
  #         create_user_role(%{
  #           user_id: Enum.at(users, 1).id,
  #           role_id: Enum.find(roles, &(&1.name =~ "Emergency")).id,
  #           tenant_id: Enum.at(users, 1).tenant_id,
  #           assigned_at: DateTime.utc_now(),
  #           expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
  #           metadata: %{"emergency_reason" => "System outage response"}
  #         })
  #       ]
  #     else
  #       []
  #     end
  #   user_roles ++ edge_cases
  # end

  # Helper functions - COMMENTED OUT (unused legacy code with @spec mismatches)

  # @spec create_role(term(), term()) :: term()
  # defp create_role(tenant, attrs, req) do
  #   defaults = %{
  #     active: true,
  #     system_role: false,
  #     requires_mfa: false,
  #     time_limited: false,
  #     read_only: false,
  #     api_only: false,
  #     ip_restricted: false,
  #     sandbox_only: false,
  #     metadata: %{}
  #   }
  #   attrs =
  #     Map.merge(defaults, attrs) |> Map.put(:tenant_id, tenant.id)
  #   {:ok, role} = Ash.create(Indrajaal.Policy.Role, attrs, actor: tenant, tenant: tenant.id)
  #   role
  # end

  # @spec create_permission(term(), term()) :: term()
  # defp create_permission(tenant, attrs, req) do
  #   defaults = %{
  #     active: true,
  #     requires_mfa: false,
  #     requires_approval: false,
  #     metadata: %{}
  #   }
  #   attrs =
  #     Map.merge(defaults, attrs) |> Map.put(:tenant_id, tenant.id)
  #   {:ok, permission} =
  #     Ash.create(Indrajaal.Policy.Permission, attrs, actor: tenant, tenant: tenant.id)
  #   permission
  # end

  # @spec create_access_rule(term(), term()) :: term()
  # defp create_access_rule(tenant, attrs) do
  #   defaults = %{
  #     active: true,
  #     action: "allow",
  #     priority: 50,
  #     permissions: [],
  #     metadata: %{}
  #   }
  #   attrs =
  #     Map.merge(defaults, attrs) |> Map.put(:tenant_id, tenant.id)
  #   {:ok, rule} = Ash.create(Indrajaal.Policy.Rule, attrs, actor: tenant, tenant: tenant.id)
  #   rule
  # end

  # @spec create_role_permission(term()) :: term()
  # defp create_role_permission(attrs) do
  #   # Need to determine tenant for role_permission
  #   tenant_id = Map.fetch!(attrs, :tenant_id)
  #   # Minimal tenant for actor
  #   tenant = %{id: tenant_id}
  #   {:ok, role_permission} =
  #     Ash.create(Indrajaal.Policy.RolePermission, attrs, actor: tenant, tenant: tenant_id)
  #   role_permission
  # end

  # @spec create_user_role(term()) :: term()
  # defp create_user_role(attrs) do
  #   # Need to determine tenant for user_role
  #   tenant_id = Map.fetch!(attrs, :tenant_id)
  #   # Minimal tenant for actor
  #   tenant = %{id: tenant_id}
  #   {:ok, user_role} =
  #     Ash.create(Indrajaal.Policy.UserRole, attrs, actor: tenant, tenant: tenant_id)
  #   user_role
  # end

  # @spec calculate_risk_level(term()) :: term()
  # defp calculate_risk_level(role_level) do
  #   cond do
  #     role_level >= 90 -> "critical"
  #     role_level >= 70 -> "high"
  #     role_level >= 50 -> "medium"
  #     true -> "low"
  #   end
  # end

  # @spec generate_permission_description(term()) :: term()
  # defp generate_permission_description(permission_name) do
  #   [category, action | _] = String.split(permission_name, ".")
  #   "Allows #{action} operations on #{category} resources"
  # end

  # @spec extract_actions(term()) :: term()
  # defp extract_actions(permission_name, reports) do
  #   case String.split(permission_name, ".") do
  #     [_, action] -> [action]
  #     [_, action, modifier] -> [action, modifier]
  #     _ -> ["unknown"]
  #   end
  # end

  # @spec audit_level_by_risk(term()) :: term()
  # defp audit_level_by_risk(risk, reports) do
  #   case risk do
  #     "critical" -> "detailed"
  #     "high" -> "full"
  #     "medium" -> "standard"
  #     _ -> "basic"
  #   end
  # end

  # defp select_permissions_for_role(role, permissions, count, reports) do
  #   # Group permissions by category
  #   by_category = Enum.group_by(permissions, & &1.category)
  #   # Select permissions based on role type
  #   selected =
  #     case role.type do
  #       "system" ->
  #         # System roles get permissions from all categories
  #         Enum.take_random(permissions, count)
  #       "administrative" ->
  #         # Admin roles focus on users, system, reports
  #         priority_categories = ["users", "system", "reports", "sites"]
  #         select_from_categories(by_category, priority_categories, count)
  #       "operational" ->
  #         # Operational roles focus on devices, alarms, video
  #         priority_categories = ["devices", "alarms", "video", "access_control"]
  #         select_from_categories(by_category, priority_categories, count)
  #       "read_only" ->
  #         # Read only gets view permissions
  #         permissions
  #         |> Enum.filter(&String.contains?(&1.name, "view"))
  #         |> Enum.take_random(count)
  #       _ ->
  #         # Others get random selection
  #         Enum.take_random(permissions, count)
  #     end
  #   selected
  # end

  # defp select_from_categories(by_category, priority_categories, total_count) do
  #   # Take more from priority categories
  #   priority_perms =
  #     priority_categories
  #     |> Enum.flat_map(fn cat -> Map.get(by_category, cat, []) end)
  #     |> Enum.take_random(div(total_count * 7, 10))
  #   # Fill remaining from other categories
  #   other_perms =
  #     by_category
  #     |> Enum.reject(fn {cat, _} -> cat in priority_categories end)
  #     |> Enum.flat_map(fn {_, perms} -> perms end)
  #     |> Enum.take_random(div(total_count * 3, 10))
  #   priority_perms ++ other_perms
  # end

  # @spec role_permission_conditions(term(), term()) :: term()
  # defp role_permission_conditions(role, permission) do
  #   conditions = %{}
  #   # Add time restrictions for lower level roles
  #   conditions =
  #     if role.level < 50 do
  #       Map.put(conditions, "business_hours_only", true)
  #     else
  #       conditions
  #     end
  #   # Add approval requirements for critical permissions
  #   conditions =
  #     if permission.risk_level == "critical" && role.level < 80 do
  #       Map.put(conditions, "requires_approval", true)
  #     else
  #       conditions
  #     end
  #   # Add location restrictions for sensitive permissions
  #   conditions =
  #     if permission.risk_level in ["critical", "high"] && role.type != "system" do
  #       Map.put(conditions, "office_network_only", true)
  #     else
  #       conditions
  #     end
  #   conditions
  # end

  # defp select_roles_for_user(user, roles, count, req) do
  #   # Group roles by type
  #   by_type = Enum.group_by(roles, & &1.type)
  #   case user.role do
  #     "admin" ->
  #       # Admins get administrative and system roles
  #       admin_roles = Map.get(by_type, "administrative", [])
  #       system_roles = Map.get(by_type, "system", [])
  #       Enum.take_random(admin_roles ++ system_roles, count)
  #     "operator" ->
  #       # Operators get operational roles
  #       op_roles = Map.get(by_type, "operational", [])
  #       Enum.take_random(op_roles, count)
  #     "viewer" ->
  #       # Viewers get read-only roles
  #       viewer_roles = Map.get(by_type, "read_only", [])
  #       Enum.take_random(viewer_roles, count)
  #     _ ->
  #       # Others get limited roles
  #       limited_roles = Map.get(by_type, "limited", [])
  #       Enum.take_random(limited_roles, count)
  #   end
  # end

  # @spec assignment_reason(term(), term()) :: term()
  # defp assignment_reason(_user, _role, req) do
  #   reasons = [
  #     "Job role requirement",
  #     "Department assignment",
  #     "Project access",
  #     "Temporary coverage",
  #     "Cross-training",
  #     "Emergency access",
  #     "Audit requirement"
  #   ]
  #   Enum.random(reasons)
  # end
end
