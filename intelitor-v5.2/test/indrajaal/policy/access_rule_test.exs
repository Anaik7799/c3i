defmodule Indrajaal.Policy.AccessRuleTest do
  use Indrajaal.DataCase
  import Indrajaal.PolicyComprehensiveFactory
  alias Indrajaal.Policy
  alias Indrajaal.Policy.AccessRule

  describe "access rule creation" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 10)
      {:ok, tenant: tenant, permissions: permissions}
    end

    test "creates access rule with valid attributes", %{tenant: tenant} do
      attrs = %{
        name: "Business Hours Access",
        description: "Allow access during business hours",
        rule_type: "time_based",
        conditions: %{
          "time_start" => "08:00",
          "time_end" => "18:00",
          "days" => ["monday", "tuesday", "wednesday", "thursday", "friday"]
        },
        action: "allow",
        priority: 50,
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert rule.name == "Business Hours Access"
      assert rule.rule_type == "time_based"
      assert rule.action == "allow"
      assert rule.priority == 50
      assert rule.active == true
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Policy.create_access_rule(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
      assert error_msg =~ "rule_type: is required"
    end

    test "validates name uniqueness within tenant", %{tenant: tenant} do
      attrs = %{
        name: "Unique Rule",
        rule_type: "general",
        action: "allow",
        tenant_id: tenant.id
      }

      assert {:ok, _rule1} = Policy.create_access_rule(attrs)
      assert {:error, error} = Policy.create_access_rule(attrs)
      assert Exception.message(error) =~ "name: has already been taken"
    end

    test "allows same name across tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs1 = %{
        name: "Standard Rule",
        rule_type: "general",
        action: "allow",
        tenant_id: tenant1.id
      }

      attrs2 = %{
        name: "Standard Rule",
        rule_type: "general",
        action: "allow",
        tenant_id: tenant2.id
      }

      assert {:ok, rule1} = Policy.create_access_rule(attrs1)
      assert {:ok, rule2} = Policy.create_access_rule(attrs2)
      assert rule1.name == rule2.name
      assert rule1.tenant_id != rule2.tenant_id
    end

    test "validates rule types", %{tenant: tenant} do
      valid_types = [
        "time_based",
        "location",
        "device",
        "risk_based",
        "emergency",
        "maintenance",
        "conditional",
        "adaptive"
      ]

      for type <- valid_types do
        attrs = %{
          name: "#{String.capitalize(type)} Rule",
          rule_type: type,
          action: "allow",
          tenant_id: tenant.id
        }

        assert {:ok, rule} = Policy.create_access_rule(attrs)
        assert rule.rule_type == type
      end

      # Invalid type
      attrs = %{
        name: "Invalid Type",
        rule_type: "invalid_type",
        action: "allow",
        tenant_id: tenant.id
      }

      assert {:error, _} = Policy.create_access_rule(attrs)
    end

    test "validates actions", %{tenant: tenant} do
      valid_actions = ["allow", "deny", "conditional", "__require_mfa"]

      for action <- valid_actions do
        attrs = %{
          name: "#{String.capitalize(action)} Action",
          rule_type: "general",
          action: action,
          tenant_id: tenant.id
        }

        assert {:ok, rule} = Policy.create_access_rule(attrs)
        assert rule.action == action
      end
    end

    test "validates priority range", %{tenant: tenant} do
      # Valid priorities (0 - 100)
      valid_priorities = [0, 25, 50, 75, 100]

      for priority <- valid_priorities do
        attrs = %{
          name: "Priority #{priority}",
          rule_type: "general",
          action: "allow",
          priority: priority,
          tenant_id: tenant.id
        }

        assert {:ok, rule} = Policy.create_access_rule(attrs)
        assert rule.priority == priority
      end

      # Invalid priorities
      invalid_priorities = [-1, 101, 150]

      for priority <- invalid_priorities do
        attrs = %{
          name: "Invalid Priority",
          rule_type: "general",
          action: "allow",
          priority: priority,
          tenant_id: tenant.id
        }

        assert {:error, _} = Policy.create_access_rule(attrs)
      end
    end

    test "creates rule with time - based conditions", %{tenant: tenant} do
      conditions = %{
        "time_start" => "09:00",
        "time_end" => "17:00",
        "days" => ["monday", "tuesday", "wednesday", "thursday", "friday"],
        "timezone" => "America / New_York",
        "exclude_holidays" => true
      }

      attrs = %{
        name: "Office Hours",
        rule_type: "time_based",
        conditions: conditions,
        action: "allow",
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert rule.conditions["time_start"] == "09:00"
      assert "monday" in rule.conditions["days"]
      assert rule.conditions["exclude_holidays"] == true
    end

    test "creates rule with location conditions", %{tenant: tenant} do
      conditions = %{
        "allowed_ips" => ["192.168.1.0 / 24", "10.0.0.0 / 8"],
        "blocked_ips" => ["192.168.1.100"],
        "allowed_countries" => ["US", "CA"],
        "blocked_countries" => ["CN", "RU"],
        "vpn_allowed" => false
      }

      attrs = %{
        name: "Geo Restriction",
        rule_type: "location",
        conditions: conditions,
        action: "conditional",
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert "192.168.1.0 / 24" in rule.conditions["allowed_ips"]
      assert rule.conditions["vpn_allowed"] == false
    end

    test "creates rule with device conditions", %{tenant: tenant} do
      conditions = %{
        "allowed_devices" => ["desktop", "laptop"],
        "blocked_devices" => ["mobile", "tablet"],
        "__require_device_registration" => true,
        "minimum_os_version" => %{
          "windows" => "10",
          "macos" => "12.0"
        }
      }

      attrs = %{
        name: "Device Policy",
        rule_type: "device",
        conditions: conditions,
        action: "conditional",
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert "desktop" in rule.conditions["allowed_devices"]
      assert rule.conditions["minimum_os_version"]["windows"] == "10"
    end

    test "creates rule with risk conditions", %{tenant: tenant} do
      conditions = %{
        "max_risk_score" => 50,
        "block_tor" => true,
        "block_vpn" => true,
        "__require_mfa" => true,
        "suspicious_behavior_threshold" => 3
      }

      attrs = %{
        name: "High Security",
        rule_type: "risk_based",
        conditions: conditions,
        action: "__require_mfa",
        priority: 80,
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert rule.conditions["max_risk_score"] == 50
      assert rule.conditions["block_tor"] == true
    end

    test "creates rule with permissions",
         %{tenant: tenant, permissions: permissions} do
      selected_perms = Enum.take(permissions, 3)
      perm_ids = Enum.map(selected_perms, & &1.id)

      attrs = %{
        name: "Permission Rule",
        rule_type: "general",
        action: "allow",
        permissions: perm_ids,
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)

      # Verify permissions associated
      rule_perms = Policy.get_rule_permissions(rule.id)
      assert length(rule_perms) == 3
    end

    test "creates emergency override rule", %{tenant: tenant} do
      conditions = %{
        "alarm_severity" => ["critical", "high"],
        "__requires_approval" => false,
        "max_duration_minutes" => 60,
        "auto_expire" => true
      }

      attrs = %{
        name: "Emergency Override",
        rule_type: "emergency",
        conditions: conditions,
        action: "allow",
        priority: 95,
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert rule.priority == 95
      assert "critical" in rule.conditions["alarm_severity"]
    end

    test "creates rule with metadata", %{tenant: tenant} do
      metadata = %{
        "version" => "2.0",
        "author" => "security_team",
        "approval_ticket" => "SEC - 1234",
        "compliance_tags" => ["SOC2", "ISO27001"],
        "review_date" => "2025 - 07 - 31"
      }

      attrs = %{
        name: "Compliance Rule",
        rule_type: "general",
        action: "allow",
        metadata: metadata,
        tenant_id: tenant.id
      }

      assert {:ok, rule} = Policy.create_access_rule(attrs)
      assert rule.metadata["version"] == "2.0"
      assert "SOC2" in rule.metadata["compliance_tags"]
    end
  end

  describe "access rule updates" do
    setup do
      tenant = insert(:tenant)
      rule = insert(:access_rule, tenant_id: tenant.id, rule_type: "general")
      {:ok, tenant: tenant, rule: rule}
    end

    test "updates rule details", %{rule: rule} do
      attrs = %{
        description: "Updated description",
        priority: 75,
        action: "conditional"
      }

      assert {:ok, updated} = Policy.update_access_rule(rule, attrs)
      assert updated.description == "Updated description"
      assert updated.priority == 75
      assert updated.action == "conditional"
    end

    test "updates conditions", %{rule: rule} do
      conditions = %{
        "new_condition" => true,
        "threshold" => 100
      }

      assert {:ok, updated} =
               Policy.update_access_rule(rule, %{
                 conditions: conditions
               })

      assert updated.conditions["new_condition"] == true
      assert updated.conditions["threshold"] == 100
    end

    test "deactivates rule", %{rule: rule} do
      assert {:ok, updated} = Policy.update_access_rule(rule, %{active: false})
      assert updated.active == false
    end

    test "validates priority changes", %{rule: rule} do
      # Valid update
      assert {:ok, updated} = Policy.update_access_rule(rule, %{priority: 90})
      assert updated.priority == 90

      # Invalid priority
      assert {:error, _} = Policy.update_access_rule(rule, %{priority: 150})
    end

    test "prevents changing rule type", %{rule: rule} do
      assert {:error, error} =
               Policy.update_access_rule(rule, %{
                 rule_type: "time_based"
               })

      assert Exception.message(error) =~ "cannot change rule type"
    end
  end

  describe "access rule queries" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 20)
      rules = bulk_create_access_rules(tenant, permissions, 75)
      {:ok, tenant: tenant, rules: rules, permissions: permissions}
    end

    test "lists all rules for tenant", %{tenant: tenant, rules: rules} do
      result = Policy.list_access_rules!(tenant_id: tenant.id)
      assert length(result) >= length(rules)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters active rules", %{tenant: tenant} do
      # Create inactive rule
      insert(:access_rule, tenant_id: tenant.id, active: false)

      active_rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      assert Enum.all?(active_rules, &(&1.active == true))
    end

    test "filters by rule type", %{tenant: tenant} do
      time_rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [rule_type: "time_based"]
        )

      assert Enum.all?(time_rules, &(&1.rule_type == "time_based"))
      assert length(time_rules) > 0
    end

    test "filters by action", %{tenant: tenant} do
      allow_rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [action: "allow"]
        )

      assert Enum.all?(allow_rules, &(&1.action == "allow"))

      # Get deny rules
      deny_rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [action: "deny"]
        )

      assert Enum.all?(deny_rules, &(&1.action == "deny"))
    end

    test "filters by priority range", %{tenant: tenant} do
      # High priority rules (>= 70)
      high_priority =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [priority: {:>=, 70}]
        )

      assert Enum.all?(high_priority, &(&1.priority >= 70))

      # Medium priority rules (40 - 60)
      medium_priority =
        Policy.list_access_rules!(
          tenant_id: tenant.id |> Enum.filter(&(&1.priority >= 40 && &1.priority <= 60))
        )

      assert length(medium_priority) > 0
    end

    test "searches by name pattern", %{tenant: tenant} do
      # Search for emergency rules
      emergency_rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%Emergency%"}]
        )

      assert Enum.all?(emergency_rules, &String.contains?(&1.name, "Emergency"))

      # Search for business hours rules
      business_rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%Business Hours%"}]
        )

      assert Enum.all?(business_rules, &String.contains?(&1.name, "Business Hours"))
    end

    test "sorts by priority descending", %{tenant: tenant} do
      rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          sort: [priority: :desc, name: :asc]
        )

      priorities = Enum.map(rules, & &1.priority)
      assert priorities == Enum.sort(priorities, :desc)
    end

    test "sorts by rule type and name", %{tenant: tenant} do
      rules =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          sort: [rule_type: :asc, name: :asc]
        )

      # Verify grouping by type
      grouped = Enum.group_by(rules, & &1.rule_type)

      for {_type, group} <- grouped do
        names = Enum.map(group, & &1.name)
        assert names == Enum.sort(names)
      end
    end

    test "paginates results", %{tenant: tenant} do
      page1 =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          page: [limit: 25, offset: 0]
        )

      page2 =
        Policy.list_access_rules!(
          tenant_id: tenant.id,
          page: [limit: 25, offset: 25]
        )

      assert length(page1) == 25
      assert length(page2) == 25

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "rule evaluation" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 10)
      {:ok, tenant: tenant, permissions: permissions}
    end

    test "evaluates time - based rules", %{tenant: tenant} do
      # Create rule for current time
      now = DateTime.utc_now()
      current_hour = now.hour

      {:ok, allow_rule} =
        Policy.create_access_rule(%{
          name: "Current Hour Allow",
          rule_type: "time_based",
          conditions: %{
            "time_start" => String.pad_leading(Integer.to_string(current_hour), 2, "0") <> ":00",
            "time_end" => String.pad_leading(Integer.to_string(current_hour + 1), 2, "0") <> ":00"
          },
          action: "allow",
          tenant_id: tenant.id
        })

      # Evaluate rule
      context = %{
        timestamp: now,
        user_id: Ecto.UUID.generate()
      }

      assert Policy.evaluate_rule(allow_rule, context) == :allow
    end

    test "evaluates location - based rules", %{tenant: tenant} do
      {:ok, rule} =
        Policy.create_access_rule(%{
          name: "IP Whitelist",
          rule_type: "location",
          conditions: %{
            "allowed_ips" => ["192.168.1.0 / 24", "10.0.0.0 / 8"]
          },
          action: "allow",
          tenant_id: tenant.id
        })

      # Test allowed IP
      context = %{ip_address: "192.168.1.100"}
      assert Policy.evaluate_rule(rule, context) == :allow

      # Test blocked IP
      context = %{ip_address: "172.16.0.100"}
      assert Policy.evaluate_rule(rule, context) == :no_match
    end

    test "evaluates risk - based rules", %{tenant: tenant} do
      {:ok, rule} =
        Policy.create_access_rule(%{
          name: "Risk Threshold",
          rule_type: "risk_based",
          conditions: %{
            "max_risk_score" => 50
          },
          action: "deny",
          tenant_id: tenant.id
        })

      # Low risk - no match
      context = %{risk_score: 30}
      assert Policy.evaluate_rule(rule, context) == :no_match

      # High risk - match
      context = %{risk_score: 70}
      assert Policy.evaluate_rule(rule, context) == :deny
    end

    test "evaluates rules with multiple conditions", %{tenant: tenant} do
      {:ok, rule} =
        Policy.create_access_rule(%{
          name: "Complex Rule",
          rule_type: "conditional",
          conditions: %{
            "__require_mfa" => true,
            "min_account_age_days" => 30,
            "trusted_device" => true
          },
          action: "allow",
          tenant_id: tenant.id
        })

      # All conditions met
      context = %{
        mfa_completed: true,
        account_age_days: 90,
        trusted_device: true
      }

      assert Policy.evaluate_rule(rule, context) == :allow

      # One condition not met
      context = %{
        mfa_completed: false,
        account_age_days: 90,
        trusted_device: true
      }

      assert Policy.evaluate_rule(rule, context) == :no_match
    end
  end

  describe "rule conflicts" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 10)
      {:ok, tenant: tenant, permissions: permissions}
    end

    test "detects conflicting rules",
         %{tenant: tenant, permissions: permissions} do
      perm_ids = Enum.map(Enum.take(permissions, 3), & &1.id)

      # Create allow rule
      {:ok, allow_rule} =
        Policy.create_access_rule(%{
          name: "Allow Access",
          rule_type: "general",
          action: "allow",
          priority: 50,
          permissions: perm_ids,
          tenant_id: tenant.id
        })

      # Create deny rule with same permissions
      {:ok, deny_rule} =
        Policy.create_access_rule(%{
          name: "Deny Access",
          rule_type: "general",
          action: "deny",
          priority: 50,
          permissions: perm_ids,
          tenant_id: tenant.id
        })

      conflicts = Policy.find_rule_conflicts(tenant_id: tenant.id)
      assert length(conflicts) > 0

      conflict = List.first(conflicts)
      assert allow_rule.id in [conflict.rule1_id, conflict.rule2_id]
      assert deny_rule.id in [conflict.rule1_id, conflict.rule2_id]
    end

    test "resolves conflicts by priority", %{tenant: tenant} do
      # Higher priority rule wins
      {:ok, high_priority} =
        Policy.create_access_rule(%{
          name: "High Priority",
          rule_type: "general",
          action: "allow",
          priority: 90,
          tenant_id: tenant.id
        })

      {:ok, low_priority} =
        Policy.create_access_rule(%{
          name: "Low Priority",
          rule_type: "general",
          action: "deny",
          priority: 30,
          tenant_id: tenant.id
        })

      # Evaluate with both rules
      winning_rule = Policy.resolve_rule_conflict([high_priority, low_priority])
      assert winning_rule.id == high_priority.id
    end

    test "identifies overlapping conditions", %{tenant: tenant} do
      # Create rules with overlapping time ranges
      {:ok, morning_rule} =
        Policy.create_access_rule(%{
          name: "Morning Hours",
          rule_type: "time_based",
          conditions: %{
            "time_start" => "06:00",
            "time_end" => "12:00"
          },
          action: "allow",
          tenant_id: tenant.id
        })

      {:ok, business_rule} =
        Policy.create_access_rule(%{
          name: "Business Hours",
          rule_type: "time_based",
          conditions: %{
            "time_start" => "09:00",
            "time_end" => "17:00"
          },
          action: "allow",
          tenant_id: tenant.id
        })

      overlaps = Policy.find_overlapping_rules(tenant_id: tenant.id)
      assert length(overlaps) > 0
    end
  end

  describe "rule statistics" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 20)
      rules = bulk_create_access_rules(tenant, permissions, 75)
      {:ok, tenant: tenant, rules: rules}
    end

    test "counts rules by type", %{tenant: tenant} do
      counts = Policy.count_rules_by_type(tenant_id: tenant.id)

      assert counts["time_based"] > 0
      assert counts["location"] > 0
      assert counts["risk_based"] > 0

      total = Enum.sum(Map.values(counts))
      assert total >= 75
    end

    test "counts rules by action", %{tenant: tenant} do
      counts = Policy.count_rules_by_action(tenant_id: tenant.id)

      assert counts["allow"] > 0
      assert counts["deny"] > 0
      assert Map.has_key?(counts, "conditional")
    end

    test "gets rule priority distribution", %{tenant: tenant} do
      distribution = Policy.get_rule_priority_distribution(tenant_id: tenant.id)

      # 90 - 100
      assert Map.has_key?(distribution, "critical")
      # 70 - 89
      assert Map.has_key?(distribution, "high")
      # 40 - 69
      assert Map.has_key?(distribution, "medium")
      # 0 - 39
      assert Map.has_key?(distribution, "low")
    end

    test "identifies most used rules", %{tenant: tenant, rules: rules} do
      # Log some rule evaluations
      selected_rules = Enum.take(rules, 5)

      for rule <- selected_rules do
        for _ <- 1..10 do
          Policy.log_rule_evaluation(%{
            rule_id: rule.id,
            result: Enum.random(["allow", "deny", "no_match"]),
            __context: %{__user_id: Ecto.UUID.generate()},
            evaluation_time_ms: :rand.uniform(100)
          })
        end
      end

      most_used =
        Policy.get_most_evaluated_rules(
          tenant_id: tenant.id,
          limit: 3
        )

      assert length(most_used) <= 3
    end
  end

  describe "bulk operations" do
    setup do
      tenant = insert(:tenant)
      permissions = bulk_create_permissions(tenant, 20)
      {:ok, tenant: tenant, permissions: permissions}
    end

    test "bulk creates rules", %{tenant: tenant, permissions: permissions} do
      rules = bulk_create_access_rules(tenant, permissions, 75)

      assert length(rules) >= 75
      assert Enum.all?(rules, &(&1.tenant_id == tenant.id))

      # Verify type distribution
      by_type = Enum.group_by(rules, & &1.rule_type)
      assert map_size(by_type) >= 5

      # Verify action distribution
      by_action = Enum.group_by(rules, & &1.action)
      assert Map.has_key?(by_action, "allow")
      assert Map.has_key?(by_action, "deny")
    end

    test "bulk updates rules", %{tenant: tenant, permissions: permissions} do
      rules = bulk_create_access_rules(tenant, permissions, 10)
      rule_ids = Enum.map(rules, & &1.id)

      assert {:ok, count} =
               Policy.bulk_update_access_rules(
                 filter: [id: {:in, rule_ids}],
                 attributes: %{
                   metadata: %{"bulk_update" => true, "updated_at" => DateTime.utc_now()}
                 }
               )

      assert count == 10

      # Verify update
      updated = Policy.list_access_rules!(filter: [id: {:in, rule_ids}])
      assert Enum.all?(updated, &(&1.metadata["bulk_update"] == true))
    end

    test "bulk deactivates rules",
         %{tenant: tenant, permissions: permissions} do
      # Create rules to deactivate
      rules =
        for i <- 1..5 do
          {:ok, rule} =
            Policy.create_access_rule(%{
              name: "Temp Rule #{i}",
              rule_type: "general",
              action: "allow",
              tenant_id: tenant.id
            })

          rule
        end

      rule_ids = Enum.map(rules, & &1.id)

      assert {:ok, count} =
               Policy.bulk_update_access_rules(
                 filter: [id: {:in, rule_ids}],
                 attributes: %{active: false}
               )

      assert count == 5

      # Verify all inactive
      inactive = Policy.list_access_rules!(filter: [id: {:in, rule_ids}])
      assert Enum.all?(inactive, &(&1.active == false))
    end
  end

  describe "rule validation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "validates condition format", %{tenant: tenant} do
      # Valid time format
      valid_conditions = %{
        "time_start" => "09:00",
        "time_end" => "17:00"
      }

      assert {:ok, _} =
               Policy.create_access_rule(%{
                 name: "Valid Time",
                 rule_type: "time_based",
                 conditions: valid_conditions,
                 action: "allow",
                 tenant_id: tenant.id
               })

      # Invalid time format
      invalid_conditions = %{
        # Invalid hour
        "time_start" => "25:00",
        "time_end" => "17:00"
      }

      assert {:error, _} =
               Policy.create_access_rule(%{
                 name: "Invalid Time",
                 rule_type: "time_based",
                 conditions: invalid_conditions,
                 action: "allow",
                 tenant_id: tenant.id
               })
    end

    test "validates IP address format", %{tenant: tenant} do
      # Valid IPs
      valid_conditions = %{
        "allowed_ips" => ["192.168.1.0 / 24", "10.0.0.0 / 8", "172.16.0.100"]
      }

      assert {:ok, _} =
               Policy.create_access_rule(%{
                 name: "Valid IPs",
                 rule_type: "location",
                 conditions: valid_conditions,
                 action: "allow",
                 tenant_id: tenant.id
               })

      # Invalid IPs
      invalid_conditions = %{
        "allowed_ips" => ["256.256.256.256", "not - an - ip"]
      }

      assert {:error, _} =
               Policy.create_access_rule(%{
                 name: "Invalid IPs",
                 rule_type: "location",
                 conditions: invalid_conditions,
                 action: "allow",
                 tenant_id: tenant.id
               })
    end

    test "validates rule consistency", %{tenant: tenant} do
      # Can't have both allow and high risk deny
      assert {:error, error} =
               Policy.create_access_rule(%{
                 name: "Inconsistent Rule",
                 rule_type: "risk_based",
                 conditions: %{"max_risk_score" => 20},
                 # Should be deny for high risk
                 action: "allow",
                 priority: 90,
                 tenant_id: tenant.id
               })

      assert Exception.message(error) =~ "inconsistent rule configuration"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
