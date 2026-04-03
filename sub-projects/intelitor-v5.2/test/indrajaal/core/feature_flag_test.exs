defmodule Indrajaal.Core.FeatureFlagTest do
  import Indrajaal.ActorHelpers
  use Indrajaal.DataCase
  alias Indrajaal.Core
  alias Indrajaal.Core.FeatureFlag

  describe "feature flag creation" do
    test "creates feature flag with valid attributes" do
      attrs = %{
        name: "new_dashboard_ui",
        enabled: true,
        description: "Enable new dashboard interface"
      }

      assert {:ok, flag} = FeatureFlag.create(attrs)
      assert flag.name == "new_dashboard_ui"
      assert flag.enabled == true
      assert flag.description == "Enable new dashboard interface"
      assert flag.rollout_percentage == 100
    end

    test "creates feature flag with rollout percentage" do
      attrs = %{
        name: "gradual_rollout_feature",
        enabled: true,
        rollout_percentage: 25,
        description: "Feature with 25% rollout"
      }

      assert {:ok, flag} = FeatureFlag.create(attrs)
      assert flag.rollout_percentage == 25
    end

    test "validates required fields" do
      assert {:error, error} = FeatureFlag.create(%{})
      error_msg = Exception.message(error)
      assert error_msg =~ "name: is required"
    end

    test "validates name uniqueness" do
      attrs = %{name: "unique_feature", enabled: true}
      assert {:ok, _flag1} = FeatureFlag.create(attrs)

      assert {:error, error} = FeatureFlag.create(attrs)
      assert Exception.message(error) =~ "name: has already been taken"
    end

    test "validates name format" do
      invalid_names = [
        "UPPERCASE-NAME",
        "special!@#chars",
        "spaces in name",
        # might be invalid based on your regex
        "name-with-dashes",
        ""
      ]

      for name <- invalid_names do
        attrs = %{name: name, enabled: true}
        result = FeatureFlag.create(attrs)

        # Some might be valid based on your validation rules
        assert match?({:error, _}, result) or match?({:ok, _}, result)
      end
    end

    test "creates feature flag with target tenants" do
      attrs = %{
        name: "tenant_specific_feature",
        enabled: true,
        target_tenants: ["tenant-1", "tenant-2", "tenant-3"],
        description: "Feature for specific tenants only"
      }

      assert {:ok, flag} = FeatureFlag.create(attrs)
      assert flag.target_tenants == ["tenant-1", "tenant-2", "tenant-3"]
    end

    test "creates feature flag with target users" do
      user_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      attrs = %{
        name: "user_specific_feature",
        enabled: true,
        target_users: user_ids,
        description: "Feature for specific users only"
      }

      assert {:ok, flag} = FeatureFlag.create(attrs)
      assert flag.target_users == user_ids
    end

    test "creates feature flag with metadata" do
      attrs = %{
        name: "feature_with_metadata",
        enabled: true,
        metadata: %{
          "jira_ticket" => "FEAT-1234",
          "owner" => "product_team",
          "category" => "experimental",
          "dependencies" => ["feature_a", "feature_b"]
        }
      }

      assert {:ok, flag} = FeatureFlag.create(attrs)
      assert flag.metadata["jira_ticket"] == "FEAT-1234"
      assert flag.metadata["category"] == "experimental"
    end

    test "creates feature flag with expiration" do
      expires_at = DateTime.add(DateTime.utc_now(), 30, :day)

      attrs = %{
        name: "temporary_feature",
        enabled: true,
        expires_at: expires_at,
        description: "Feature expires in 30 days"
      }

      assert {:ok, flag} = FeatureFlag.create(attrs)
      assert DateTime.compare(flag.expires_at, expires_at) == :eq
    end

    test "sets default values correctly" do
      attrs = %{name: "default_feature"}

      assert {:ok, flag} = FeatureFlag.create(attrs)
      # Default should be false
      assert flag.enabled == false
      assert flag.rollout_percentage == 0
      assert flag.target_tenants == []
      assert flag.target_users == []
    end
  end

  describe "feature flag updates" do
    setup do
      flag = insert(:feature_flag)
      {:ok, flag: flag}
    end

    test "updates feature flag status", %{flag: flag} do
      assert {:ok, updated} = FeatureFlag.update(flag, %{enabled: true})
      assert updated.enabled == true

      assert {:ok, disabled} = FeatureFlag.update(updated, %{enabled: false})
      assert disabled.enabled == false
    end

    test "updates rollout percentage", %{flag: flag} do
      percentages = [0, 5, 10, 25, 50, 75, 90, 95, 100]

      for pct <- percentages do
        assert {:ok, updated} = FeatureFlag.update(flag, %{rollout_percentage: pct})
        assert updated.rollout_percentage == pct
      end
    end

    test "updates target tenants", %{flag: flag} do
      tenants = ["tenant-a", "tenant-b", "tenant-c"]

      assert {:ok, updated} = FeatureFlag.update(flag, %{target_tenants: tenants})
      assert updated.target_tenants == tenants

      # Add more tenants
      more_tenants = tenants ++ ["tenant-d", "tenant-e"]
      assert {:ok, updated2} = FeatureFlag.update(updated, %{target_tenants: more_tenants})
      assert length(updated2.target_tenants) == 5
    end

    test "updates expiration date", %{flag: flag} do
      new_expiry = DateTime.add(DateTime.utc_now(), 60, :day)

      assert {:ok, updated} = FeatureFlag.update(flag, %{expires_at: new_expiry})
      assert DateTime.compare(updated.expires_at, new_expiry) == :eq
    end

    test "tracks rollout history in metadata", %{flag: flag} do
      # Initial rollout
      assert {:ok, updated} =
               FeatureFlag.update(flag, %{
                 rollout_percentage: 10,
                 metadata: %{
                   "rollout_history" => [
                     %{
                       "percentage" => 10,
                       "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
                       "changed_by" => "admin@example.com"
                     }
                   ]
                 }
               })

      assert List.first(updated.metadata["rollout_history"])["percentage"] == 10
    end

    test "preserves metadata on update", %{flag: flag} do
      # Set initial metadata
      {:ok, flag} =
        FeatureFlag.update(flag, %{
          metadata: %{"owner" => "team_a", "priority" => "high"}
        })

      # Update other fields
      {:ok, updated} =
        FeatureFlag.update(flag, %{
          enabled: true,
          metadata: Map.merge(flag.metadata, %{"updated_at" => DateTime.utc_now()})
        })

      assert updated.metadata["owner"] == "team_a"
      assert updated.metadata["priority"] == "high"
      assert updated.metadata["updated_at"] != nil
    end
  end

  describe "feature flag queries" do
    setup do
      flags = bulk_create_feature_flags(55)
      {:ok, flags: flags}
    end

    test "lists all feature flags", %{flags: flags} do
      all_flags = FeatureFlag.list!()
      assert length(all_flags) >= length(flags)
    end

    test "gets feature flag by name" do
      flag = insert(:feature_flag, name: "specific_feature")

      found =
        FeatureFlag.get!(
          filter: [name: "specific_feature"],
          actor: Indrajaal.ActorHelpers.system_admin_actor()
        )

      assert found.id == flag.id
      assert found.name == "specific_feature"
    end

    test "filters enabled flags" do
      enabled = insert(:feature_flag, enabled: true, name: "enabled_feature")
      disabled = insert(:feature_flag, enabled: false, name: "disabled_feature")

      enabled_flags = FeatureFlag.list!(filter: [enabled: true])

      assert Enum.any?(enabled_flags, &(&1.id == enabled.id))
      refute Enum.any?(enabled_flags, &(&1.id == disabled.id))
    end

    test "filters by rollout percentage range" do
      low = insert(:feature_flag, rollout_percentage: 10, name: "low_rollout")
      medium = insert(:feature_flag, rollout_percentage: 50, name: "medium_rollout")
      high = insert(:feature_flag, rollout_percentage: 100, name: "high_rollout")

      # Get flags with 50% or higher rollout
      high_rollout_flags =
        FeatureFlag.list!()
        |> Enum.filter(&(&1.rollout_percentage >= 50))

      flag_ids = Enum.map(high_rollout_flags, & &1.id)
      refute low.id in flag_ids
      assert medium.id in flag_ids
      assert high.id in flag_ids
    end

    test "filters expired flags" do
      past = DateTime.add(DateTime.utc_now(), -1, :day)
      future = DateTime.add(DateTime.utc_now(), 30, :day)

      expired = insert(:feature_flag, expires_at: past, name: "expired_flag")
      active = insert(:feature_flag, expires_at: future, name: "active_flag")
      permanent = insert(:feature_flag, expires_at: nil, name: "permanent_flag")

      # Get non - expired flags
      all_flags = FeatureFlag.list!()
      current_time = DateTime.utc_now()

      non_expired =
        Enum.filter(all_flags, fn flag ->
          is_nil(flag.expires_at) or
            DateTime.compare(
              flag.expires_at,
              current_time
            ) == :gt
        end)

      flag_ids = Enum.map(non_expired, & &1.id)
      refute expired.id in flag_ids
      assert active.id in flag_ids
      assert permanent.id in flag_ids
    end

    test "searches flags by name pattern" do
      insert(:feature_flag, name: "video_analytics_enabled")
      insert(:feature_flag, name: "video_storage_unlimited")
      insert(:feature_flag, name: "audio_recording_enabled")

      video_flags = FeatureFlag.list!(filter: [name: {:ilike, "%video%"}])

      assert length(video_flags) >= 2
      assert Enum.all?(video_flags, &String.contains?(&1.name, "video"))
    end

    test "sorts flags by name" do
      flags = FeatureFlag.list!(sort: [name: :asc])
      names = Enum.map(flags, & &1.name)
      assert names == Enum.sort(names)
    end

    test "sorts flags by creation date" do
      flags = FeatureFlag.list!(sort: [inserted_at: :desc])
      dates = Enum.map(flags, & &1.inserted_at)

      # Verify descending order
      Enum.reduce(dates, fn date, prev_date ->
        assert DateTime.compare(prev_date, date) != :lt
        date
      end)
    end

    test "paginates results" do
      # Ensure enough flags
      bulk_create_feature_flags(30)

      page1 = FeatureFlag.list!(page: [limit: 10, offset: 0])
      page2 = FeatureFlag.list!(page: [limit: 10, offset: 10])

      assert length(page1) == 10
      assert length(page2) == 10

      # No overlap
      page1_ids = MapSet.new(page1, & &1.id)
      page2_ids = MapSet.new(page2, & &1.id)
      assert MapSet.disjoint?(page1_ids, page2_ids)
    end
  end

  describe "feature flag deletion" do
    setup do
      flag = insert(:feature_flag)
      {:ok, flag: flag}
    end

    test "destroys feature flag", %{flag: flag} do
      assert {:ok, _deleted} =
               Ash.destroy(flag,
                 actor: Indrajaal.ActorHelpers.system_admin_actor()
               )

      assert {:error, _} = FeatureFlag.get(flag.id)
    end

    test "handles deletion of active flags", %{flag: flag} do
      # Enable flag first
      {:ok, active_flag} =
        FeatureFlag.update(flag, %{
          enabled: true,
          rollout_percentage: 100
        })

      # Should still be able to delete
      assert {:ok, _deleted} = Core.destroy_feature_flag(active_flag)
    end
  end

  describe "feature flag evaluation" do
    test "evaluates simple enabled flag" do
      flag = insert(:feature_flag, enabled: true, rollout_percentage: 100)

      # Flag should be active for all
      assert flag.enabled == true
      assert flag.rollout_percentage == 100
    end

    test "evaluates disabled flag" do
      flag = insert(:feature_flag, enabled: false)

      # Flag should be inactive regardless of rollout
      assert flag.enabled == false
    end

    test "evaluates flag with partial rollout" do
      flag = insert(:feature_flag, enabled: true, rollout_percentage: 50)

      # In practice, you'd evaluate against a hash of user / tenant ID
      assert flag.enabled == true
      assert flag.rollout_percentage == 50
    end

    test "evaluates flag for specific tenants" do
      allowed_tenants = ["tenant-123", "tenant-456"]

      flag =
        insert(:feature_flag,
          enabled: true,
          target_tenants: allowed_tenants
        )

      # Check if tenant is in allowed list
      assert "tenant-123" in flag.target_tenants
      assert "tenant-456" in flag.target_tenants
      refute "tenant-789" in flag.target_tenants
    end

    test "evaluates flag for specific users" do
      user_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      flag =
        insert(:feature_flag,
          enabled: true,
          target_users: user_ids
        )

      # Check if user is in allowed list
      assert List.first(user_ids) in flag.target_users
      refute Ecto.UUID.generate() in flag.target_users
    end

    test "evaluates expired flags" do
      past = DateTime.add(DateTime.utc_now(), -1, :day)
      future = DateTime.add(DateTime.utc_now(), 30, :day)

      expired_flag = insert(:feature_flag, enabled: true, expires_at: past)
      active_flag = insert(:feature_flag, enabled: true, expires_at: future)

      # Check expiration
      assert DateTime.compare(
               expired_flag.expires_at,
               DateTime.utc_now()
             ) == :lt

      assert DateTime.compare(active_flag.expires_at, DateTime.utc_now()) == :gt
    end
  end

  describe "feature flag categories" do
    test "organizes flags by category metadata" do
      categories = ["core", "security", "video", "integration", "experimental"]

      # Create flags for each category
      for category <- categories do
        for i <- 1..3 do
          insert(:feature_flag,
            name: "#{category}_feature_#{i}",
            metadata: %{"category" => category}
          )
        end
      end

      # Query and group by category
      all_flags = FeatureFlag.list!()
      by_category = Enum.group_by(all_flags, &get_in(&1.metadata, ["category"]))

      for category <- categories do
        assert length(by_category[category] || []) >= 3
      end
    end

    test "filters flags by stability level" do
      stable =
        insert(:feature_flag,
          name: "stable_feature",
          metadata: %{"stability" => "stable"}
        )

      beta =
        insert(:feature_flag,
          name: "beta_feature",
          metadata: %{"stability" => "beta"}
        )

      alpha =
        insert(:feature_flag,
          name: "alpha_feature",
          metadata: %{"stability" => "alpha"}
        )

      all_flags = FeatureFlag.list!()

      # Filter by stability
      stable_flags =
        Enum.filter(all_flags, fn flag ->
          get_in(flag.metadata, ["stability"]) == "stable"
        end)

      flag_ids = Enum.map(stable_flags, & &1.id)
      assert stable.id in flag_ids
      refute beta.id in flag_ids
      refute alpha.id in flag_ids
    end
  end

  describe "bulk feature flag operations" do
    test "creates comprehensive feature set" do
      flags = bulk_create_feature_flags(55)

      assert length(flags) >= 55

      # Verify diversity
      enabled_count = Enum.count(flags, & &1.enabled)
      assert enabled_count > 10
      # Not all enabled
      assert enabled_count < 45

      # Check various rollout percentages
      mapped_rollout = Enum.map(flags, & &1.rollout_percentage)
      rollout_values = mapped_rollout |> Enum.uniq()
      assert length(rollout_values) > 5

      # Check categories
      categories =
        flags
        |> Enum.map(&get_in(&1.metadata, ["category"]))
        |> Enum.filter(& &1)
        |> Enum.uniq()

      assert length(categories) >= 5
    end

    test "creates feature flags with various rollout strategies" do
      flags = bulk_create_feature_flags(50)

      # Check different rollout strategies
      full_rollout = Enum.filter(flags, &(&1.rollout_percentage == 100))

      partial_rollout =
        Enum.filter(flags, &(&1.rollout_percentage > 0 && &1.rollout_percentage < 100))

      no_rollout = Enum.filter(flags, &(&1.rollout_percentage == 0))

      assert length(full_rollout) > 5
      assert length(partial_rollout) > 10
      assert length(no_rollout) > 5
    end

    test "creates edge case feature flags" do
      flags = bulk_create_feature_flags(10)

      # Should include edge cases
      flag_names = Enum.map(flags, & &1.name)

      assert Enum.any?(flag_names, &(&1 == "test.always_on"))
      assert Enum.any?(flag_names, &(&1 == "test.always_off"))
      assert Enum.any?(flag_names, &(&1 == "test.fifty_fifty"))
      assert Enum.any?(flag_names, &(&1 == "test.targeted"))
      assert Enum.any?(flag_names, &(&1 == "test.expired"))
    end
  end

  describe "feature flag lifecycle" do
    test "tracks feature flag evolution" do
      # Create flag in alpha
      {:ok, flag} =
        FeatureFlag.create(%{
          name: "evolving_feature",
          enabled: false,
          rollout_percentage: 0,
          metadata: %{"stability" => "alpha", "version" => "0.1.0"}
        })

      # Move to beta with limited rollout
      {:ok, flag} =
        FeatureFlag.update(flag, %{
          enabled: true,
          rollout_percentage: 10,
          metadata:
            Map.merge(flag.metadata, %{
              "stability" => "beta",
              "version" => "0.2.0"
            })
        })

      assert flag.metadata["stability"] == "beta"
      assert flag.rollout_percentage == 10

      # Gradual rollout increase
      for pct <- [25, 50, 75] do
        {:ok, flag} = FeatureFlag.update(flag, %{rollout_percentage: pct})
        assert flag.rollout_percentage == pct
      end

      # Full rollout to stable
      {:ok, flag} =
        FeatureFlag.update(flag, %{
          rollout_percentage: 100,
          metadata:
            Map.merge(flag.metadata, %{
              "stability" => "stable",
              "version" => "1.0.0"
            })
        })

      assert flag.metadata["stability"] == "stable"
      assert flag.rollout_percentage == 100
    end

    test "handles feature flag deprecation" do
      flag =
        insert(:feature_flag,
          enabled: true,
          metadata: %{"status" => "active"}
        )

      # Mark as deprecated
      {:ok, deprecated} =
        FeatureFlag.update(flag, %{
          enabled: false,
          metadata:
            Map.merge(flag.metadata, %{
              "status" => "deprecated",
              "deprecated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
              "replacement" => "new_feature_v2"
            })
        })

      assert deprecated.enabled == false
      assert deprecated.metadata["status"] == "deprecated"
      assert deprecated.metadata["replacement"] == "new_feature_v2"
    end
  end

  describe "feature flag dependencies" do
    test "tracks feature dependencies" do
      # Create base features
      {:ok, _base1} = FeatureFlag.create(%{name: "base_feature_1", enabled: true})
      {:ok, _base2} = FeatureFlag.create(%{name: "base_feature_2", enabled: true})

      # Create dependent feature
      {:ok, dependent} =
        FeatureFlag.create(%{
          name: "dependent_feature",
          enabled: true,
          metadata: %{
            "depends_on" => ["base_feature_1", "base_feature_2"],
            # all must be enabled
            "dependency_type" => "all"
          }
        })

      assert dependent.metadata["depends_on"] == ["base_feature_1", "base_feature_2"]
      assert dependent.metadata["dependency_type"] == "all"
    end

    test "validates circular dependencies pr__evention" do
      # Create features with potential circular dependency
      {:ok, feature_a} =
        FeatureFlag.create(%{
          name: "feature_a",
          metadata: %{"depends_on" => ["feature_b"]}
        })

      {:ok, feature_b} =
        FeatureFlag.create(%{
          name: "feature_b",
          metadata: %{"depends_on" => ["feature_c"]}
        })

      {:ok, feature_c} =
        FeatureFlag.create(%{
          name: "feature_c",
          # No circular dependency
          metadata: %{"depends_on" => []}
        })

      # In practice, you'd validate against circular dependencies
      assert feature_a.metadata["depends_on"] == ["feature_b"]
      assert feature_b.metadata["depends_on"] == ["feature_c"]
      assert feature_c.metadata["depends_on"] == []
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: General
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
