defmodule Indrajaal.Accounts.TeamTest do
  use Indrajaal.DataCase
  import Indrajaal.AccountsComprehensiveFactory
  alias Indrajaal.Accounts
  alias Indrajaal.Accounts.Team

  describe "team creation" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "creates team with valid attributes", %{tenant: tenant} do
      attrs = %{
        name: "Security Operations Team",
        description: "Main security monitoring team",
        tenant_id: tenant.id
      }

      assert {:ok, team} = Accounts.create_team(attrs)
      assert team.name == "Security Operations Team"
      assert team.description == "Main security monitoring team"
      assert team.tenant_id == tenant.id
      assert team.active == true
    end

    test "validates required fields", %{tenant: tenant} do
      assert {:error, error} = Accounts.create_team(%{tenant_id: tenant.id})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
    end

    test "validates name uniqueness within tenant", %{tenant: tenant} do
      attrs = %{
        name: "Unique Team",
        tenant_id: tenant.id
      }

      assert {:ok, _team1} = Accounts.create_team(attrs)
      assert {:error, error} = Accounts.create_team(attrs)
      assert Exception.message(error) =~ "name: has already been taken"
    end

    test "allows same name across tenants" do
      tenant1 = insert(:tenant)
      tenant2 = insert(:tenant)

      attrs1 = %{name: "Security Team", tenant_id: tenant1.id}
      attrs2 = %{name: "Security Team", tenant_id: tenant2.id}

      assert {:ok, team1} = Accounts.create_team(attrs1)
      assert {:ok, team2} = Accounts.create_team(attrs2)
      assert team1.name == team2.name
      assert team1.tenant_id != team2.tenant_id
    end

    test "creates team with type", %{tenant: tenant} do
      types = ["Security Operations", "Monitoring", "Response Team", "Administration"]

      for type <- types do
        attrs = %{
          name: "#{type} Team",
          type: type,
          tenant_id: tenant.id
        }

        assert {:ok, team} = Accounts.create_team(attrs)
        assert team.type == type
      end
    end

    test "creates team with settings", %{tenant: tenant} do
      settings = %{
        "shift_rotation" => true,
        "emergency_contact" => "+1 - 555 - 1234",
        "escalation_timeout" => 1800
      }

      attrs = %{
        name: "24 / 7 Operations",
        settings: settings,
        tenant_id: tenant.id
      }

      assert {:ok, team} = Accounts.create_team(attrs)
      assert team.settings["shift_rotation"] == true
      assert team.settings["escalation_timeout"] == 1800
    end

    test "creates team with permissions", %{tenant: tenant} do
      permissions = ["view_all", "acknowledge_alarms", "dispatch_units"]

      attrs = %{
        name: "Dispatcher Team",
        permissions: permissions,
        tenant_id: tenant.id
      }

      assert {:ok, team} = Accounts.create_team(attrs)
      assert "view_all" in team.permissions
      assert "dispatch_units" in team.permissions
    end

    test "creates hierarchical team", %{tenant: tenant} do
      # Create parent team
      {:ok, parent} =
        Accounts.create_team(%{
          name: "Global Security",
          tenant_id: tenant.id
        })

      # Create child team
      attrs = %{
        name: "Regional Operations",
        parent_team_id: parent.id,
        tenant_id: tenant.id
      }

      assert {:ok, child} = Accounts.create_team(attrs)
      assert child.parent_team_id == parent.id
    end

    test "validates max members", %{tenant: tenant} do
      attrs = %{
        name: "Small Team",
        max_members: 5,
        tenant_id: tenant.id
      }

      assert {:ok, team} = Accounts.create_team(attrs)
      assert team.max_members == 5

      # Test invalid max_members
      invalid_attrs = %{attrs | max_members: -1}
      assert {:error, _} = Accounts.create_team(invalid_attrs)
    end
  end

  describe "team updates" do
    setup do
      tenant = insert(:tenant)
      team = insert(:team, tenant_id: tenant.id)
      {:ok, tenant: tenant, team: team}
    end

    test "updates team details", %{team: team} do
      attrs = %{
        name: "Updated Team Name",
        description: "Updated description"
      }

      assert {:ok, updated} = Accounts.update_team(team, attrs)
      assert updated.name == "Updated Team Name"
      assert updated.description == "Updated description"
    end

    test "updates team settings", %{team: team} do
      settings = %{
        "shift_rotation" => false,
        "notification_channel" => "email"
      }

      assert {:ok, updated} = Accounts.update_team(team, %{settings: settings})
      assert updated.settings["shift_rotation"] == false
      assert updated.settings["notification_channel"] == "email"
    end

    test "deactivates team", %{team: team} do
      assert {:ok, updated} = Accounts.update_team(team, %{active: false})
      assert updated.active == false
    end

    test "changes parent team", %{tenant: tenant, team: team} do
      new_parent = insert(:team, tenant_id: tenant.id)

      assert {:ok, updated} =
               Accounts.update_team(team, %{
                 parent_team_id: new_parent.id
               })

      assert updated.parent_team_id == new_parent.id
    end

    test "prevents circular hierarchy", %{tenant: tenant, team: team} do
      # Create child team
      {:ok, child} =
        Accounts.create_team(%{
          name: "Child Team",
          parent_team_id: team.id,
          tenant_id: tenant.id
        })

      # Try to make parent a child of its child
      assert {:error, error} =
               Accounts.update_team(team, %{
                 parent_team_id: child.id
               })

      assert Exception.message(error) =~ "circular hierarchy"
    end
  end

  describe "team queries" do
    setup do
      tenant = insert(:tenant)
      teams = bulk_create_teams(tenant, 25)
      {:ok, tenant: tenant, teams: teams}
    end

    test "lists all teams for tenant", %{tenant: tenant, teams: teams} do
      result = Accounts.list_teams!(tenant_id: tenant.id)
      assert length(result) >= length(teams)
      assert Enum.all?(result, &(&1.tenant_id == tenant.id))
    end

    test "filters active teams", %{tenant: tenant} do
      # Create inactive team
      insert(:team, tenant_id: tenant.id, active: false)

      active_teams =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          filter: [active: true]
        )

      assert Enum.all?(active_teams, &(&1.active == true))
    end

    test "filters by type", %{tenant: tenant} do
      # Create specific type
      security_team =
        insert(:team,
          tenant_id: tenant.id,
          type: "Security Operations"
        )

      security_teams =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          filter: [type: "Security Operations"]
        )

      assert Enum.any?(security_teams, &(&1.id == security_team.id))
    end

    test "searches by name", %{tenant: tenant} do
      team =
        insert(:team,
          tenant_id: tenant.id,
          name: "Special Response Unit"
        )

      results =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          filter: [name: {:ilike, "%Response%"}]
        )

      assert Enum.any?(results, &(&1.id == team.id))
    end

    test "filters by parent team", %{tenant: tenant} do
      parent = insert(:team, tenant_id: tenant.id)
      child1 = insert(:team, tenant_id: tenant.id, parent_team_id: parent.id)
      child2 = insert(:team, tenant_id: tenant.id, parent_team_id: parent.id)
      other = insert(:team, tenant_id: tenant.id)

      children =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          filter: [parent_team_id: parent.id]
        )

      child_ids = Enum.map(children, & &1.id)
      assert child1.id in child_ids
      assert child2.id in child_ids
      refute other.id in child_ids
    end

    test "gets root teams only", %{tenant: tenant} do
      root_teams =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          filter: [parent_team_id: nil]
        )

      assert Enum.all?(root_teams, &(&1.parent_team_id == nil))
    end

    test "sorts by name", %{tenant: tenant} do
      teams =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          sort: [name: :asc]
        )

      names = Enum.map(teams, & &1.name)
      assert names == Enum.sort(names)
    end

    test "includes team statistics", %{tenant: tenant} do
      team = insert(:team, tenant_id: tenant.id)

      # Add some members
      users =
        Enum.map(1..5, fn _ ->
          insert(:user, tenant_id: tenant.id)
        end)

      Enum.each(users, fn user ->
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: user.id
        })
      end)

      teams_with_stats =
        Accounts.list_teams!(
          tenant_id: tenant.id,
          load: [:member_count]
        )

      team_with_stats = Enum.find(teams_with_stats, &(&1.id == team.id))
      assert team_with_stats.member_count == 5
    end
  end

  describe "team membership" do
    setup do
      tenant = insert(:tenant)
      team = insert(:team, tenant_id: tenant.id)
      user = insert(:user, tenant_id: tenant.id)
      {:ok, tenant: tenant, team: team, user: user}
    end

    test "adds user to team", %{team: team, user: user} do
      attrs = %{
        team_id: team.id,
        user_id: user.id,
        role: :member
      }

      assert {:ok, membership} = Accounts.create_team_membership(attrs)
      assert membership.team_id == team.id
      assert membership.user_id == user.id
      assert membership.role == :member
      assert membership.active == true
    end

    test "validates unique membership", %{team: team, user: user} do
      attrs = %{
        team_id: team.id,
        user_id: user.id,
        role: "member"
      }

      assert {:ok, _} = Accounts.create_team_membership(attrs)
      assert {:error, error} = Accounts.create_team_membership(attrs)
      assert Exception.message(error) =~ "already a member"
    end

    test "assigns team roles", %{team: team} do
      users = Indrajaal.Factory.insert_list(5, :user, tenant_id: team.tenant_id)

      # Assign different roles (valid: :member, :lead, :admin)
      roles = [:lead, :admin, :member, :member, :member]

      memberships =
        users
        |> Enum.zip(roles)
        |> Enum.map(fn {user, role} ->
          {:ok, membership} =
            Accounts.create_team_membership(%{
              team_id: team.id,
              user_id: user.id,
              role: role
            })

          membership
        end)

      # Verify role distribution
      lead_count = Enum.count(memberships, &(&1.role == :lead))
      admin_count = Enum.count(memberships, &(&1.role == :admin))

      assert lead_count == 1
      assert admin_count == 1
    end

    test "enforces max members limit", %{tenant: tenant, user: user} do
      # Create team with low limit
      {:ok, team} =
        Accounts.create_team(%{
          name: "Small Team",
          max_members: 3,
          tenant_id: tenant.id
        })

      # Add members up to limit
      users = Indrajaal.Factory.insert_list(3, :user, tenant_id: tenant.id)

      Enum.each(users, fn u ->
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: u.id
        })
      end)

      # Try to add one more
      assert {:error, error} =
               Accounts.create_team_membership(%{
                 team_id: team.id,
                 user_id: user.id
               })

      assert Exception.message(error) =~ "team is full"
    end

    test "removes user from team", %{team: team, user: user} do
      {:ok, membership} =
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: user.id
        })

      assert {:ok, removed} = Accounts.remove_team_member(membership)
      assert removed.active == false
      assert removed.removed_at != nil
    end

    test "updates membership role", %{team: team, user: user} do
      {:ok, membership} =
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: user.id,
          role: :member
        })

      assert {:ok, updated} =
               Accounts.update_team_membership(membership, %{
                 role: :lead
               })

      assert updated.role == :lead
    end
  end

  describe "team hierarchy" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "builds team hierarchy tree", %{tenant: tenant} do
      # Create hierarchy
      {:ok, global} =
        Accounts.create_team(%{
          name: "Global",
          tenant_id: tenant.id
        })

      {:ok, regional} =
        Accounts.create_team(%{
          name: "Regional",
          parent_team_id: global.id,
          tenant_id: tenant.id
        })

      {:ok, site} =
        Accounts.create_team(%{
          name: "Site",
          parent_team_id: regional.id,
          tenant_id: tenant.id
        })

      # Get hierarchy
      tree = Accounts.get_team_hierarchy(global.id)

      assert tree.id == global.id
      assert length(tree.children) == 1
      assert List.first(tree.children).id == regional.id
      assert List.first(List.first(tree.children).children).id == site.id
    end

    test "gets team ancestors", %{tenant: tenant} do
      # Create hierarchy
      {:ok, level1} =
        Accounts.create_team(%{
          name: "Level 1",
          tenant_id: tenant.id
        })

      {:ok, level2} =
        Accounts.create_team(%{
          name: "Level 2",
          parent_team_id: level1.id,
          tenant_id: tenant.id
        })

      {:ok, level3} =
        Accounts.create_team(%{
          name: "Level 3",
          parent_team_id: level2.id,
          tenant_id: tenant.id
        })

      ancestors = Accounts.get_team_ancestors(level3.id)
      assert length(ancestors) == 2
      assert Enum.any?(ancestors, &(&1.id == level1.id))
      assert Enum.any?(ancestors, &(&1.id == level2.id))
    end

    test "gets team descendants", %{tenant: tenant} do
      # Create hierarchy
      {:ok, root} =
        Accounts.create_team(%{
          name: "Root",
          tenant_id: tenant.id
        })

      child_teams =
        Enum.map(1..3, fn i ->
          {:ok, child} =
            Accounts.create_team(%{
              name: "Child #{i}",
              parent_team_id: root.id,
              tenant_id: tenant.id
            })

          child
        end)

      # Add grandchildren
      grandchildren =
        Enum.flat_map(child_teams, fn child ->
          Enum.map(1..2, fn i ->
            {:ok, gc} =
              Accounts.create_team(%{
                name: "#{child.name} - GC #{i}",
                parent_team_id: child.id,
                tenant_id: tenant.id
              })

            gc
          end)
        end)

      descendants = Accounts.get_team_descendants(root.id)
      # 3 children + 6 grandchildren
      assert length(descendants) == 9
    end

    test "calculates team depth", %{tenant: tenant} do
      # Create deep hierarchy
      teams =
        Enum.reduce(1..5, [], fn i, acc ->
          parent_id = if acc == [], do: nil, else: List.last(acc).id

          {:ok, team} =
            Accounts.create_team(%{
              name: "Level #{i}",
              parent_team_id: parent_id,
              tenant_id: tenant.id
            })

          acc ++ [team]
        end)

      deepest = List.last(teams)
      depth = Accounts.get_team_depth(deepest.id)
      # 0 - indexed, so 5 levels = depth 4
      assert depth == 4
    end
  end

  describe "team permissions" do
    setup do
      tenant = insert(:tenant)
      team = insert(:team, tenant_id: tenant.id)
      user = insert(:user, tenant_id: tenant.id)

      {:ok, _} =
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: user.id,
          role: "member"
        })

      {:ok, tenant: tenant, team: team, user: user}
    end

    test "inherits permissions from team", %{team: team, user: user} do
      # Set team permissions
      {:ok, _} =
        Accounts.update_team(team, %{
          permissions: ["view_devices", "acknowledge_alarms"]
        })

      # Get user's effective permissions
      permissions = Accounts.get_user_permissions(user.id)

      assert "view_devices" in permissions
      assert "acknowledge_alarms" in permissions
    end

    test "combines permissions from multiple teams",
         %{tenant: tenant, user: user} do
      # Create another team
      {:ok, team2} =
        Accounts.create_team(%{
          name: "Admin Team",
          permissions: ["manage_users", "system_config"],
          tenant_id: tenant.id
        })

      # Add user to second team
      {:ok, _} =
        Accounts.create_team_membership(%{
          team_id: team2.id,
          user_id: user.id,
          role: "member"
        })

      # Get combined permissions
      permissions = Accounts.get_user_permissions(user.id)

      # From first team
      assert "view_devices" in permissions
      # From second team
      assert "manage_users" in permissions
    end

    test "role - based permissions within team", %{team: team, tenant: tenant} do
      # Create users with different roles
      leader = insert(:user, tenant_id: tenant.id)
      member = insert(:user, tenant_id: tenant.id)

      {:ok, _} =
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: leader.id,
          role: "leader"
        })

      {:ok, _} =
        Accounts.create_team_membership(%{
          team_id: team.id,
          user_id: member.id,
          role: "member"
        })

      # Leaders should have additional permissions
      leader_perms = Accounts.get_user_permissions(leader.id)
      member_perms = Accounts.get_user_permissions(member.id)

      assert "manage_team" in leader_perms
      refute "manage_team" in member_perms
    end
  end

  describe "team statistics" do
    setup do
      tenant = insert(:tenant)
      teams = bulk_create_teams(tenant, 10)
      users = bulk_create_users(tenant, 50)
      memberships = bulk_create_team_memberships(teams, users)
      {:ok, tenant: tenant, teams: teams, users: users, memberships: memberships}
    end

    test "counts team members", %{teams: teams} do
      team = List.first(teams)

      member_count = Accounts.count_team_members(team.id)
      assert member_count > 0

      # Count active members only
      active_count = Accounts.count_team_members(team.id, active_only: true)
      assert active_count <= member_count
    end

    test "gets team utilization", %{teams: teams} do
      # Set max_members for a team
      team = List.first(teams)
      {:ok, _} = Accounts.update_team(team, %{max_members: 20})

      utilization = Accounts.get_team_utilization(team.id)
      assert utilization > 0 && utilization <= 100
    end

    test "aggregates team statistics", %{tenant: tenant} do
      stats = Accounts.team_statistics(tenant_id: tenant.id)

      assert stats.total_teams > 0
      assert stats.active_teams > 0
      assert stats.total_members > 0
      assert Map.has_key?(stats, :teams_by_type)
      assert Map.has_key?(stats, :average_team_size)
    end

    test "identifies understaffed teams", %{teams: teams} do
      # Set minimum members for some teams
      team = List.first(teams)

      {:ok, _} =
        Accounts.update_team(team, %{
          min_members: 10,
          max_members: 20
        })

      understaffed = Accounts.find_understaffed_teams(tenant_id: team.tenant_id)

      # Should include team if it has less than 10 members
      current_members = Accounts.count_team_members(team.id)

      if current_members < 10 do
        assert Enum.any?(understaffed, &(&1.id == team.id))
      end
    end
  end

  describe "bulk team operations" do
    setup do
      tenant = insert(:tenant)
      {:ok, tenant: tenant}
    end

    test "bulk creates teams", %{tenant: tenant} do
      teams = bulk_create_teams(tenant, 25)

      assert length(teams) == 25
      assert Enum.all?(teams, &(&1.tenant_id == tenant.id))

      # Verify diversity
      types = teams |> Enum.map(& &1.type) |> Enum.uniq()
      assert length(types) >= 5
    end

    test "bulk updates teams", %{tenant: tenant} do
      teams = bulk_create_teams(tenant, 10)
      team_ids = Enum.map(teams, & &1.id)

      assert {:ok, count} =
               Accounts.bulk_update_teams(
                 filter: [id: {:in, team_ids}],
                 attributes: %{
                   settings: %{"bulk_updated" => true}
                 }
               )

      assert count == 10

      # Verify update
      updated = Accounts.list_teams!(filter: [id: {:in, team_ids}])
      assert Enum.all?(updated, &(&1.settings["bulk_updated"] == true))
    end

    test "bulk deactivates teams", %{tenant: tenant} do
      teams = bulk_create_teams(tenant, 5)
      team_ids = Enum.map(teams, & &1.id)

      assert {:ok, count} =
               Accounts.bulk_update_teams(
                 filter: [id: {:in, team_ids}],
                 attributes: %{active: false}
               )

      assert count == 5

      # Verify all inactive
      updated = Accounts.list_teams!(filter: [id: {:in, team_ids}])
      assert Enum.all?(updated, &(&1.active == false))
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
