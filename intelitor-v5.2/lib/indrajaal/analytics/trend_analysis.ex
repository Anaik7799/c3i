defmodule Indrajaal.Analytics.TrendAnalysis do
  # PHASE M: Analytics patterns consolidated with Unified
  @moduledoc """
  Trend detection and pattern analysis across security data.
  Statistical analysis of metrics over time with predictions.
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Analytics

  use Indrajaal.Multitenancy.TenantResource

  attributes do
    uuid_primary_key :id

    attribute :analysis_type, :atom do
      constraints one_of: [
                    :incident_trend,
                    :response_performance,
                    :access_patterns,
                    :device_reliability,
                    :cost_trend,
                    :compliance_drift,
                    :seasonal_pattern,
                    :anomaly_trend,
                    :__user_behavior,
                    :threat_evolution,
                    :performance_degradation
                  ]

      allow_nil? false
    end

    attribute :time_range_start, :utc_datetime do
      allow_nil? false
    end

    attribute :time_range_end, :utc_datetime do
      allow_nil? false
    end

    attribute :__data_points, {:array, :map} do
      default []
      # Structure: [%{timestamp: ~U[...], value: 123.45, meta_data: %{...}}, ...]
    end

    attribute :trend_direction, :atom do
      constraints one_of: [:increasing, :decreasing, :stable, :volatile]
    end

    attribute :trend_strength, :float do
      # 0.0 to 1.0 - how strong the trend is
      constraints min: 0.0, max: 1.0
    end

    attribute :statistical_metrics, :map do
      default %{}
      # mean, median, std_dev, confidence_interval, r_squared, etc.
    end

    attribute :predictions, {:array, :map} do
      default []

      # Future projections: [%{timestamp: ~U[...], predicted_value: 123.45, con
    end

    attribute :insights, {:array, :string} do
      default []
      # AI - generated insights and observations
    end

    attribute :confidence_level, :float do
      constraints min: 0.0, max: 1.0
    end

    attribute :analysis_parameters, :map do
      default %{}
      # Configuration used for the analysis
    end

    attribute :anomalies_detected, {:array, :map} do
      default []
      # Detected anomalies: [%{timestamp: ~U[...], severity: :high, description:
    end

    timestamps()
  end

  relationships do
    belongs_to :triggered_by_metric, Indrajaal.Analytics.SecurityMetric
    belongs_to :organization, Indrajaal.Core.Organization
    belongs_to :site, Indrajaal.Sites.Site
  end

  actions do
    defaults [:read, :update, :destroy]

    create :analyze do
      primary? true

      accept [
        :analysis_type,
        :time_range_start,
        :time_range_end,
        :triggered_by_metric_id,
        :organization_id,
        :site_id,
        :analysis_parameters
      ]

      change after_action(&perform_analysis/2)
    end

    read :list_by_type do
      argument :analysis_type, :atom do
        allow_nil? false
      end

      argument :days_back, :integer, default: 90

      filter expr(analysis_type == ^arg(:analysis_type))
      filter expr(time_range_start >= ago(^arg(:days_back), :day))
    end

    read :list_recent do
      argument :limit, :integer, default: 10

      pagination offset?: true, default_limit: 10
    end

    update :add_insight do
      require_atomic? false
      accept []

      argument :insight, :string do
        allow_nil? false
      end

      change fn changeset, __context ->
        insight = Ash.Changeset.get_argument(changeset, :insight)

        current_insights =
          Ash.Changeset.get_attribute(
            changeset,
            :insights
          ) || []

        new_insights = [insight | current_insights]
        Ash.Changeset.change_attribute(changeset, :insights, new_insights)
      end
    end
  end

  calculations do
    calculate :trend_summary, :string do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          direction = record.trend_direction || :stable
          strength = record.trend_strength || 0.0

          case {direction, strength >= 0.7} do
            {:increasing, true} -> "Strong upward trend"
            {:increasing, false} -> "Moderate upward trend"
            {:decreasing, true} -> "Strong downward trend"
            {:decreasing, false} -> "Moderate downward trend"
            {:volatile, _} -> "Highly volatile pattern"
            {:stable, _} -> "Stable pattern"
          end
        end)
      end
    end

    calculate :next_predicted_value, :decimal do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          if record.predictions && length(record.predictions) > 0 do
            record.predictions
            |> List.first()
            |> Map.get("predicted_value")
            |> case do
              value when is_number(value) -> Decimal.new(value)
              _ -> nil
            end
          else
            nil
          end
        end)
      end
    end

    calculate :__data_points_count, :integer do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          length(record.__data_points || [])
        end)
      end
    end

    calculate :has_anomalies?, :boolean do
      calculation fn records, _ ->
        Enum.map(records, fn record ->
          length(record.anomalies_detected || []) > 0
        end)
      end
    end
  end

  validations do
    validate compare(:time_range_end, greater_than: :time_range_start)

    validate fn changeset, __context ->
      if changeset.attributes[:trend_strength] do
        if changeset.attributes[:trend_strength] < 0.0 ||
             changeset.attributes[:trend_strength] > 1.0 do
          Ash.Changeset.add_error(changeset, :trend_strength, "must be between 0.0 and 1.0")
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
    define :analyze, action: :analyze
    define :list_by_type, action: :list_by_type
    define :list_recent, action: :list_recent
    define :add_insight, action: :add_insight
  end

  postgres do
    table "trend_analyses"
    repo Indrajaal.Repo

    custom_indexes do
      index [:tenant_id, :analysis_type, :time_range_start],
        name: "trend_analyses_tenant_type_time_index"

      index [:tenant_id, :created_at],
        name: "trend_analyses_tenant_created_index"

      index [:tenant_id, :triggered_by_metric_id],
        name: "trend_analyses_tenant_metric_index"

      index [:tenant_id, :organization_id, :analysis_type],
        name: "trend_analyses_tenant_org_type_index"
    end
  end

  # Callback function to perform the actual analysis
  @spec perform_analysis(term(), term()) :: term()
  defp perform_analysis(_changeset, record) do
    # Extract numeric values from data_points attribute
    raw_points = Map.get(record, :__data_points, [])

    values =
      Enum.flat_map(raw_points, fn
        %{value: v} when is_number(v) -> [v * 1.0]
        %{"value" => v} when is_number(v) -> [v * 1.0]
        v when is_number(v) -> [v * 1.0]
        _ -> []
      end)

    n = length(values)

    {mean, std_dev, trend_direction, trend_strength, confidence, r_squared} =
      if n < 2 do
        {0.0, 0.0, :stable, 0.0, 0.5, 0.0}
      else
        # Mean
        mean_v = Enum.sum(values) / n

        # Std dev
        variance =
          values
          |> Enum.map(&:math.pow(&1 - mean_v, 2))
          |> Enum.sum()
          |> Kernel./(n)

        std_v = :math.sqrt(variance)

        # Linear regression slope (index as x-axis)
        xs = Enum.to_list(0..(n - 1)) |> Enum.map(&(&1 * 1.0))
        mean_x = (n - 1) / 2.0

        numerator =
          Enum.zip(xs, values)
          |> Enum.reduce(0.0, fn {x, y}, acc -> acc + (x - mean_x) * (y - mean_v) end)

        denom_x = Enum.reduce(xs, 0.0, fn x, acc -> acc + :math.pow(x - mean_x, 2) end)
        slope = if denom_x < 1.0e-10, do: 0.0, else: numerator / denom_x

        # R-squared
        ss_tot = Enum.reduce(values, 0.0, fn y, acc -> acc + :math.pow(y - mean_v, 2) end)

        ss_res =
          Enum.zip(xs, values)
          |> Enum.reduce(0.0, fn {x, y}, acc ->
            pred = mean_v + slope * (x - mean_x)
            acc + :math.pow(y - pred, 2)
          end)

        r2 = if ss_tot < 1.0e-10, do: 1.0, else: max(0.0, 1.0 - ss_res / ss_tot)

        # Trend direction from slope relative to std_dev/n scale
        threshold = if std_v > 0, do: std_v / n, else: 0.001

        direction =
          cond do
            slope > threshold * 3 -> :increasing
            slope < -threshold * 3 -> :decreasing
            std_v / max(abs(mean_v), 1.0e-6) > 0.3 -> :volatile
            true -> :stable
          end

        # Trend strength = |slope| normalized by std_dev, capped at 1.0
        strength =
          if std_v < 1.0e-10,
            do: 0.0,
            else: min(1.0, abs(slope) * :math.sqrt(n) / std_v)

        # Confidence increases with n and r-squared
        confidence_v = min(0.99, 0.5 + r2 * 0.3 + min(n, 100) / 500.0)

        {mean_v, std_v, direction, strength, confidence_v, r2}
      end

    # Detect anomalies (Z-score > 2.5)
    anomalies =
      if n >= 3 and std_dev > 1.0e-10 do
        values
        |> Enum.with_index()
        |> Enum.filter(fn {v, _i} -> abs((v - mean) / std_dev) > 2.5 end)
        |> Enum.map(fn {v, i} ->
          %{
            index: i,
            value: v,
            z_score: Float.round((v - mean) / std_dev, 3),
            severity: if(abs((v - mean) / std_dev) > 3.5, do: :high, else: :medium)
          }
        end)
      else
        []
      end

    insights =
      cond do
        n == 0 ->
          ["Insufficient data for trend analysis", "Collect more data points to enable analysis"]

        n < 5 ->
          [
            "Limited data points (#{n}) — results may be imprecise",
            "Trend direction: #{trend_direction}"
          ]

        true ->
          base = [
            "Trend direction: #{trend_direction} (strength: #{Float.round(trend_strength, 2)})"
          ]

          anom =
            if length(anomalies) > 0, do: ["#{length(anomalies)} anomalies detected"], else: []

          r2_msg =
            if r_squared > 0.7,
              do: ["Strong linear fit (R²=#{Float.round(r_squared, 2)})"],
              else: []

          base ++ anom ++ r2_msg
      end

    updated_record =
      record
      |> Map.put(:trend_direction, trend_direction)
      |> Map.put(:trend_strength, Float.round(trend_strength, 4))
      |> Map.put(:confidence_level, Float.round(confidence, 4))
      |> Map.put(:statistical_metrics, %{
        mean: Float.round(mean, 4),
        std_dev: Float.round(std_dev, 4),
        data_points: n,
        r_squared: Float.round(r_squared, 4),
        min: if(n > 0, do: Enum.min(values), else: 0.0),
        max: if(n > 0, do: Enum.max(values), else: 0.0)
      })
      |> Map.put(:anomalies_detected, anomalies)
      |> Map.put(:insights, insights)

    {:ok, updated_record}
  end
end

# Agent: Worker - 6 (Analytics Domain Agent)
# SOPv5.1 Compliance: ✅ Data analytics and business intelligence coordination w
# Domain: Analytics
# Responsibilities: Data analytics, business intelligence, performance metrics
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
