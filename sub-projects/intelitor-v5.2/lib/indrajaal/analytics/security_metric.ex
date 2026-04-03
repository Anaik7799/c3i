defmodule Indrajaal.Analytics.SecurityMetric do
  # PHASE M: Analytics patterns consolidated with Unified
  @moduledoc """
  Key performance indicators and security metrics tracking.
  Optimized for time - series data with high write volume.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :metric_type, :atom do
      constraints one_of: [
                    :response_time,
                    :false_alarm_rate,
                    :incident_count,
                    :patrol_completion,
                    :access_denial_rate,
                    :device_uptime,
                    :compliance_score,
                    :training_completion,
                    :cost_per_incident,
                    :threat_detection_rate,
                    :resolution_time,
                    :__user_activity,
                    :system_performance,
                    :data_accuracy
                  ]

      allow_nil? false
    end

    attribute :period_type, :atom do
      constraints one_of: [:hourly, :daily, :weekly, :monthly, :quarterly, :yearly]
      allow_nil? false
    end

    attribute :period_start, :utc_datetime do
      allow_nil? false
    end

    attribute :period_end, :utc_datetime do
      allow_nil? false
    end

    attribute :value, :decimal do
      allow_nil? false
    end

    attribute :unit, :string do
      constraints max_length: 20
      # "seconds", "percentage", "count", "dollars", etc.
    end

    attribute :dimensions, :map do
      default %{}
      # site_id, department, alarm_type, etc.
    end

    attribute :target_value, :decimal
    attribute :threshold_min, :decimal
    attribute :threshold_max, :decimal

    attribute :status, :atom do
      constraints one_of: [:on_target, :warning, :critical, :no_target]
      default :no_target
    end

    attribute :metadata, :map, default: %{}

    timestamps()
  end

  relationships do
    belongs_to :organization, Indrajaal.Core.Organization
    belongs_to :site, Indrajaal.Sites.Site
  end

  identities do
    identity :unique_metric_period, [
      :tenant_id,
      :metric_type,
      :period_type,
      :period_start,
      :site_id
    ]
  end

  actions do
    defaults [:read, :update, :destroy]

    create :record do
      primary? true

      accept [
        :metric_type,
        :period_type,
        :period_start,
        :period_end,
        :value,
        :unit,
        :dimensions,
        :target_value,
        :threshold_min,
        :threshold_max,
        :organization_id,
        :site_id
      ]

      # Calculate status based on thresholds
      change before_action(fn changeset ->
               status = calculate_metric_status(changeset)
               Ash.Changeset.change_attribute(changeset, :status, status)
             end)
    end

    read :list_by_type do
      argument :metric_type, :atom do
        allow_nil? false
      end

      argument :period_type, :atom
      argument :days_back, :integer, default: 30

      filter expr(metric_type == ^arg(:metric_type))
      filter expr(period_start >= ago(^arg(:days_back), :day))

      filter expr(
               if is_nil(arg(:period_type)) do
                 true
               else
                 period_type == ^arg(:period_type)
               end
             )
    end

    read :list_critical do
      filter expr(status == :critical)
    end
  end

  calculations do
    calculate :variance_from_target, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.target_value do
            Decimal.sub(record.value, record.target_value)
          else
            nil
          end
        end)
      end
    end

    calculate :percentage_of_target, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.target_value &&
               Decimal.compare(
                 record.target_value,
                 0
               ) == :gt do
            record.value
            |> Decimal.div(record.target_value)
            |> Decimal.mult(100)
          else
            nil
          end
        end)
      end
    end

    calculate :trend_direction, :atom do
      calculation fn records, _ ->
        # This would need actual implementation to compare with previous periods
        Enum.map(records, fn _record ->
          # Placeholder
          :stable
        end)
      end
    end
  end

  validations do
    validate attribute_does_not_equal(:period_start, :period_end)
    validate compare(:period_end, greater_than: :period_start)

    validate fn changeset, __context ->
      if changeset.attributes[:threshold_min] && changeset.attributes[:threshold_max] do
        if Decimal.compare(
             changeset.attributes[:threshold_min],
             changeset.attributes[:threshold_max]
           ) == :gt do
          Ash.Changeset.add_error(changeset, :threshold_min, "must be less than threshold_max")
        else
          changeset
        end
      else
        changeset
      end
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if relates_to_actor_via(:tenant)
    end

    policy action_type([:create, :update, :destroy]) do
      authorize_if actor_attribute_equals(:role, "admin")
      authorize_if actor_attribute_equals(:role, "analyst")
      authorize_if actor_attribute_equals(:role, "manager")
    end
  end

  code_interface do
    define :record, action: :record
    define :list_by_type, action: :list_by_type
    define :list_critical, action: :list_critical
  end

  postgres do
    table "security_metrics"
    repo Indrajaal.Repo

    custom_indexes do
      # Optimized for time - series queries
      index [:tenant_id, :metric_type, :period_start],
        name: "metrics_tenant_type_period_index"

      index [:tenant_id, :organization_id, :metric_type, :period_start],
        name: "metrics_tenant_org_type_period_index"

      index [:tenant_id, :site_id, :metric_type, :period_start],
        name: "metrics_tenant_site_type_period_index"

      index [:tenant_id, :status],
        where: "status IN ('warning', 'critical')",
        name: "metrics_tenant_status_alerts_index"

      index [:period_start], name: "metrics_period_start_index"
    end
  end

  # Helper function for calculating metric status
  @spec calculate_metric_status(term()) :: term()
  defp calculate_metric_status(changeset) do
    value = Ash.Changeset.get_attribute(changeset, :value)
    threshold_min = Ash.Changeset.get_attribute(changeset, :threshold_min)
    threshold_max = Ash.Changeset.get_attribute(changeset, :threshold_max)
    target_value = Ash.Changeset.get_attribute(changeset, :target_value)

    cond do
      threshold_min && Decimal.compare(value, threshold_min) == :lt ->
        :critical

      threshold_max && Decimal.compare(value, threshold_max) == :gt ->
        :critical

      target_value && threshold_min && threshold_max ->
        # Check if within warning range (e.g., 10% of target)
        warning_range = Decimal.mult(target_value, Decimal.new("0.1"))

        if Decimal.compare(Decimal.abs(Decimal.sub(value, target_value)), warning_range) == :gt do
          :warning
        else
          :on_target
        end

      target_value ->
        :on_target

      true ->
        :no_target
    end
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.1 Compliance: ✅ Data analytics and business intelligence coordination w
# Domain: Analytics
# Responsibilities: Data analytics, business intelligence, performance metrics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
