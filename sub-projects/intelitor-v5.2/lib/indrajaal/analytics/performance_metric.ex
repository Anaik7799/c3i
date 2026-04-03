defmodule Indrajaal.Analytics.PerformanceMetric do
  # PHASE M: Analytics patterns consolidated with Unified
  @moduledoc """
  System performance tracking and optimization metrics.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :metric_name, :string do
      allow_nil? false
      constraints max_length: 100
    end

    attribute :component, :string do
      allow_nil? false
      constraints max_length: 50
    end

    attribute :timestamp, :utc_datetime do
      allow_nil? false
      default &DateTime.utc_now/0
    end

    attribute :value, :decimal do
      allow_nil? false
    end

    attribute :unit, :string do
      constraints max_length: 20
    end

    attribute :threshold_warning, :decimal
    attribute :threshold_critical, :decimal

    timestamps()
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  code_interface do
    define :create
  end

  postgres do
    table "performance_metrics"
    repo Indrajaal.Repo
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.1 Compliance: ✅ Data analytics and business intelligence coordination w
# Domain: Analytics
# Responsibilities: Data analytics, business intelligence, performance metrics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
