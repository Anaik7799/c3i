defmodule Indrajaal.Analytics.BehaviorProfile do
  # PHASE M: Analytics patterns consolidated with Unified
  @moduledoc """
  Normal behavior patterns and baselines for anomaly detection.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :entity_type, :atom do
      constraints one_of: [:user, :device, :site, :system]
      allow_nil? false
    end

    attribute :entity_id, :uuid do
      allow_nil? false
    end

    attribute :profile_data, :map do
      default %{}
    end

    attribute :learning_period_start, :utc_datetime do
      allow_nil? false
    end

    attribute :learning_period_end, :utc_datetime do
      allow_nil? false
    end

    attribute :confidence_level, :float do
      constraints min: 0.0, max: 1.0
    end

    timestamps()
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  code_interface do
    define :create
  end

  postgres do
    table "behavior_profiles"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.1 Compliance: ✅ Data analytics and business intelligence coordination w
# Domain: Analytics
# Responsibilities: Data analytics, business intelligence, performance metrics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
