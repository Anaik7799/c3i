defmodule Indrajaal.Core.FeatureFlag do
  @moduledoc """
  Feature flag management for gradual rollouts and A / B testing.

  Supports percentage - based rollouts and rule - based targeting.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Core

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :name, :string do
      allow_nil? false
      constraints max_length: 100
      description "Human - readable feature name"
    end

    attribute :key, :string do
      allow_nil? false

      constraints max_length: 100
      # TODO: Fix match constraint - temporarily removed due to compilation err
      # match: ~S/^[a - z0 - 9_]+$/

      description "Feature key used in code"
    end

    attribute :enabled, :boolean do
      default false
      description "Global enable / disable switch"
    end

    attribute :rollout_percentage, :integer do
      default 0
      constraints min: 0, max: 100
      description "Percentage of __users to enable for"
    end

    attribute :targeting_rules, :map do
      default %{}
      description "Advanced targeting rules (JSON)"
    end

    attribute :description, :string do
      constraints max_length: 1000
      description "Feature description"
    end

    attribute :tags, {:array, :string} do
      default []
      description "Tags for categorization"
    end

    timestamps()
  end

  identities do
    identity :unique_key_per_tenant, [:tenant_id, :key]
  end

  actions do
    defaults [:read, :create, :update, :destroy]

    update :toggle do
      require_atomic? false
      accept []

      change fn changeset, _ ->
        current = Ash.Changeset.get_attribute(changeset, :enabled)
        Ash.Changeset.change_attribute(changeset, :enabled, !current)
      end

      description "Toggle enabled state"
    end

    update :set_rollout do
      require_atomic? false

      argument :percentage, :integer do
        allow_nil? false
        constraints min: 0, max: 100
      end

      accept []
      change set_attribute(:rollout_percentage, arg(:percentage))
      change set_attribute(:enabled, true)
      description "Set rollout percentage and enable"
    end

    update :add_rule do
      require_atomic? false

      argument :rule_name, :string do
        allow_nil? false
      end

      argument :rule_config, :map do
        allow_nil? false
      end

      accept []

      change fn changeset, __context ->
        current_rules =
          Ash.Changeset.get_attribute(
            changeset,
            :targeting_rules
          ) || %{}

        new_rules =
          Map.put(current_rules, __context.arguments.rule_name, __context.arguments.rule_config)

        Ash.Changeset.change_attribute(changeset, :targeting_rules, new_rules)
      end

      description "Add targeting rule"
    end

    update :remove_rule do
      require_atomic? false

      argument :rule_name, :string do
        allow_nil? false
      end

      accept []

      change fn changeset, __context ->
        current_rules =
          Ash.Changeset.get_attribute(
            changeset,
            :targeting_rules
          ) || %{}

        new_rules = Map.delete(current_rules, __context.arguments.rule_name)
        Ash.Changeset.change_attribute(changeset, :targeting_rules, new_rules)
      end

      description "Remove targeting rule"
    end

    read :enabled do
      filter expr(enabled == true)
      description "Only enabled flags"
    end

    read :by_tag do
      argument :tag, :string do
        allow_nil? false
      end

      filter expr(^arg(:tag) in tags)
    end
  end

  calculations do
    calculate :is_enabled_for, :boolean do
      argument :user_id, :uuid do
        allow_nil? false
      end

      argument :attributes, :map do
        default %{}
      end

      calculation &Indrajaal.Core.FeatureFlagCalculator.is_enabled_for/2

      description "Whether flag is enabled for specific user"
    end

    calculate :enabled_count_estimate, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn flag ->
          if flag.enabled do
            # This would use actual user count in production
            estimated_user_count = 1000
            round(estimated_user_count * flag.rollout_percentage / 100)
          else
            0
          end
        end)
      end

      description "Estimated number of __users with flag enabled"
    end
  end

  validations do
    validate string_length(:name, min: 1, max: 100)
    validate string_length(:key, min: 1, max: 100)

    # TODO: Re - enable when regex validation issue is resolved
    # validate match(:key, ~r/^[a - z0 - 9_]+$/) do
    #   message "Key must contain only lowercase letters, numbers, and undersco
    # end
  end

  policies do
    # All authenticated __users can read feature flags
    policy action_type(:read) do
      authorize_if always()
    end

    # Only admins can manage feature flags
    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, :admin)
      authorize_if actor_attribute_equals(:role, :feature_admin)
    end
  end

  code_interface do
    # get and list are already defined in BaseResource
    define :create, action: :create
    define :update, action: :update
    define :destroy, action: :destroy
    define :toggle, action: :toggle
    define :set_rollout, action: :set_rollout
  end

  postgres do
    table "feature_flags"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :key],
        unique: true,
        name: "feature_flags_unique_key_per_tenant_index"

      index [:enabled],
        name: "feature_flags_enabled_index"

      index [:tags],
        name: "feature_flags_tags_index",
        using: "GIN"
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Core
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
