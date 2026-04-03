import Indrajaal.Test.SharedFactoryUtilities

defmodule Indrajaal.AnalyticsFactory do
  @moduledoc """
  Comprehensive factory definitions for Analytics domain with 50+ items
    per resource.
  Implements enterprise testing standards with diverse security intelligence
    data patterns.
  """

  defmacro __using__(_) do
    quote do
      alias Faker
      alias Indrajaal.Shared.TestSupport

      # ===== SECURITY METRIC FACTORY (50+ diverse metrics) =====
      @spec security_metric_factory(map()) :: any()
      def security_metric_factory(attrs \\ %{}) do
        Map.merge(
          %{
            metric_type: random_metric_type(),
            period_type: random_period_type(),
            period_start: random_period_start(),
            period_end: fn -> DateTime.add(period_start(), random_period_duration(), :second) end,
            value: random_metric_value(),
            unit: metric_unit_for_type(),
            dimensions: random_dimensions(),
            target_value: random_target_value(),
            threshold_min: random_threshold_min(),
            threshold_max: random_threshold_max(),
            status: :no_target,
            metadata: security_metric_metadata(),
            tenant_id: fn -> build(:tenant).id end,
            organization_id: fn -> build(:organization).id end,
            site_id: fn -> build(:site).id end
          },
          attrs
        )
      end

      @spec bulk_create_security_metrics(any()) :: any()
      def bulk_create_security_metrics(count) do
        # Replaced with TestSupport.bulk_create
        TestSupport.bulk_create(:security_metric, count)
      end

      @spec _original_bulk_create_security_metrics(integer()) :: term()
      def _original_bulk_create_security_metrics(count) do
        metrics =
          Enum.map(1..count, fn i ->
            metric_type = Enum.at(metric_types(), rem(i, length(metric_types())))

            period_start =
              DateTime.add(DateTime.utc_now(), -(:rand.uniform(30) * 86_400), :second)

            period_end = DateTime.add(period_start, 3600, :second)

            attrs = %{
              metric_type: metric_type,
              period_type: period_type_by_pattern(i),
              period_start: period_start,
              period_end: period_end,
              value: realistic_value_for_metric(metric_type, i),
              unit: unit_for_metric_type(metric_type),
              dimensions: dimensions_for_metric(metric_type, i),
              target_value: target_for_metric_type(metric_type),
              threshold_min: threshold_min_for_type(metric_type),
              threshold_max: threshold_max_for_type(metric_type),
              metadata: metadata_for_pattern(i)
            }

            insert(:security_metric, attrs)
          end)

        # Add edge cases and critical scenarios
        edge_metrics = [
          insert(:security_metric, %{
            metric_type: :response_time,
            value: Decimal.new("300.5"),
            threshold_max: Decimal.new("120"),
            status: :critical
          }),
          insert(:security_metric, %{
            metric_type: :false_alarm_rate,
            value: Decimal.new("0.02"),
            target_value: Decimal.new("0.05"),
            status: :on_target
          })
        ]

        metrics ++ edge_metrics
      end

      # ===== TREND ANALYSIS FACTORY =====
      @spec trend_analysis_factory(map()) :: any()
      def trend_analysis_factory(attrs \\ %{}) do
        base_attributes()
        |> Map.merge(trend_analysis_attributes())
        |> Map.merge(trend_statistical_data())
        |> Map.merge(trend_pattern_data())
        |> Map.merge(analytics_metadata())
        |> Map.merge(attrs)
      end

      @spec trend_analysis_attributes() :: any()
      defp trend_analysis_attributes do
        %{
          name: sequence(:trend_name, &trend_analysis_name/1),
          analysis_type: random_analysis_type(),
          time_period: random_time_period(),
          start_date: random_start_date(),
          end_date: fn -> Date.add(start_date(), Enum.random(7..365)) end,
          trend_direction: Enum.random([:increasing, :decreasing, :stable, :volatile])
        }
      end

      @spec trend_statistical_data() :: any()
      defp trend_statistical_data do
        %{
          confidence_level: Decimal.new(to_string(Enum.random(70..99)) <> ".5"),
          data_points: Enum.random(50..1000),
          r_squared: Decimal.new(to_string(Enum.random(60..95)) <> ".0"),
          slope: random_slope(),
          correlation_strength: Enum.random([:weak, :moderate, :strong, :very_strong]),
          prediction_accuracy: Decimal.new(to_string(Enum.random(75..95)) <> ".2")
        }
      end

      @spec trend_pattern_data() :: any()
      defp trend_pattern_data do
        %{
          seasonal_pattern: random_seasonal_pattern(),
          anomaly_count: Enum.random(0..15),
          insights: trend_insights(),
          recommendations: trend_recommendations()
        }
      end

      # ===== HEAT MAP FACTORY =====
      @spec heat_map_factory() :: any()
      def heat_map_factory do
        heat_map_basic_attributes()
        |> Map.merge(heat_map_visual_config())
        |> Map.merge(heat_map_data_config())
        |> Map.merge(heat_map_identifiers())
      end

      @spec heat_map_basic_attributes() :: any()
      defp heat_map_basic_attributes do
        %{
          name: sequence(:heatmap_name, &heat_map_name/1),
          map_type: random_map_type(),
          data_source: random_data_source(),
          time_range_start: random_time_range_start(),
          time_range_end: fn ->
            DateTime.add(time_range_start(), Enum.random(3600..86_400), :second)
          end
        }
      end

      @spec heat_map_visual_config() :: any()
      defp heat_map_visual_config do
        %{
          grid_resolution: Enum.random([:low, :medium, :high, :ultra_high]),
          color_scheme: Enum.random([:red_green, :blue_yellow, :thermal, :grayscale, :custom]),
          intensity_scale: Enum.random([:linear, :logarithmic, :exponential]),
          visualization_config: heat_map_config()
        }
      end

      @spec heat_map_data_config() :: any()
      defp heat_map_data_config do
        %{
          max_intensity: Decimal.new(to_string(Enum.random(50..100)) <> ".0"),
          min_intensity: Decimal.new("0.0"),
          hotspot_count: Enum.random(1..25),
          coverage_area: coverage_area_data(),
          aggregation_method: Enum.random([:sum, :average, :maximum, :minimum, :count]),
          data_density: Decimal.new(to_string(Enum.random(10..90)) <> ".5"),
          metadata: heat_map_metadata()
        }
      end

      @spec heat_map_identifiers() :: any()
      defp heat_map_identifiers do
        %{
          tenant_id: fn -> build(:tenant).id end,
          site_id: fn -> build(:site).id end
        }
      end

      # ===== SECURITY DASHBOARD FACTORY =====
      @spec security_dashboard_factory(map()) :: any()
      def security_dashboard_factory(attrs \\ %{}) do
        Map.merge(
          %{
            name: sequence(:dashboard_name, &dashboard_name/1),
            dashboard_type: random_dashboard_type(),
            layout: random_layout_config(),
            widgets: dashboard_widgets(),
            refresh_interval: Enum.random([30, 60, 300, 600, 1800]),
            auto_refresh: Enum.random([true, false]),
            time_range: random_dashboard_time_range(),
            filters: dashboard_filters(),
            permissions: dashboard_permissions(),
            sharing_settings: sharing_settings(),
            alerts_enabled: Enum.random([true, false]),
            export_formats: Enum.random([["pdf"], ["csv"], ["json"], ["pdf", "csv", "json"]]),
            theme: Enum.random([:light, :dark, :high_contrast, :custom]),
            is_default: false,
            is_public: false,
            view_count: Enum.random(0..5000),
            last_accessed: random_last_accessed(),
            metadata: dashboard_metadata(),
            tenant_id: fn -> build(:tenant).id end,
            organization_id: fn -> build(:organization).id end
          },
          attrs
        )
      end

      # ===== RISK SCORE FACTORY =====
      @spec risk_score_factory() :: any()
      def risk_score_factory do
        %{
          entity_type: random_entity_type(),
          entity_id: fn -> Faker.UUID.v4() end,
          risk_category: random_risk_category(),
          score_value: random_risk_score(),
          confidence_level: Decimal.new(to_string(Enum.random(60..99)) <> ".5"),
          severity_level: calculate_severity_level(),
          calculation_method:
            Enum.random([:weighted_average, :monte_carlo, :bayesian, :machine_learning]),
          factors: risk_factors(),
          historical_trend: Enum.random([:improving, :worsening, :stable, :volatile]),
          last_calculated: random_calculation_time(),
          next_review: fn ->
            DateTime.add(last_calculated(), Enum.random(86_400..604_800), :second)
          end,
          mitigation_strategies: mitigation_strategies(),
          impact_assessment: impact_assessment_data(),
          probability_assessment: probability_data(),
          residual_risk: residual_risk_data(),
          metadata: risk_score_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== PREDICTIVE MODEL FACTORY =====
      @spec predictive_model_factory() :: any()
      def predictive_model_factory do
        predictive_model_basic_attrs()
        |> Map.merge(predictive_model_metrics())
        |> Map.merge(predictive_model_training_attrs())
        |> Map.merge(predictive_model_deployment_attrs())
        |> Map.merge(predictive_model_identifiers())
      end

      @spec predictive_model_basic_attrs() :: map()
      defp predictive_model_basic_attrs do
        %{
          name: sequence(:model_name, &predictive_model_name/1),
          model_type: random_model_type(),
          algorithm: random_algorithm(),
          hyperparameters: model_hyperparameters(),
          model_version: sequence(:version, &"v1.#{&1}"),
          metadata: predictive_model_metadata()
        }
      end

      @spec predictive_model_metrics() :: map()
      defp predictive_model_metrics do
        %{
          validation_accuracy: random_decimal_in_range(75, 95, ".2"),
          precision: random_decimal_in_range(70, 90, ".1"),
          recall: random_decimal_in_range(80, 95, ".3"),
          f1_score: random_decimal_in_range(75, 90, ".4"),
          cross_validation_score: random_decimal_in_range(70, 90, ".6"),
          data_drift_score: random_decimal_in_range(0, 30, ".5")
        }
      end

      @spec predictive_model_training_attrs() :: map()
      defp predictive_model_training_attrs do
        %{
          training_data_size: Enum.random(1000..100_000),
          training_duration: Enum.random(300..7200),
          feature_count: Enum.random(5..50),
          overfitting_risk: Enum.random([:low, :medium, :high]),
          last_trained: random_training_time(),
          next_retrain: fn ->
            DateTime.add(last_trained(), Enum.random(604_800..2_592_000), :second)
          end
        }
      end

      @spec predictive_model_deployment_attrs() :: map()
      defp predictive_model_deployment_attrs do
        %{
          deployment_status:
            Enum.random([:development, :testing, :staging, :production, :retired]),
          prediction_horizon: Enum.random([:short_term, :medium_term, :long_term])
        }
      end

      @spec predictive_model_identifiers() :: map()
      defp predictive_model_identifiers do
        %{
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      @spec random_decimal_in_range(integer(), integer(), String.t()) :: Decimal.t()
      defp random_decimal_in_range(min, max, suffix) do
        Decimal.new(to_string(Enum.random(min..max)) <> suffix)
      end

      # ===== ANOMALY DETECTION FACTORY =====
      @spec anomaly_detection_factory(map()) :: any()
      def anomaly_detection_factory(attrs \\ %{}) do
        Map.merge(
          %{
            detection_type: random_detection_type(),
            algorithm_type: random_anomaly_algorithm(),
            sensitivity_level: Enum.random([:low, :medium, :high, :ultra_high]),
            threshold_value: random_threshold(),
            confidence_score: Decimal.new(to_string(Enum.random(70..99)) <> ".1"),
            anomaly_count: Enum.random(0..50),
            detection_time: random_detection_time(),
            data_window_size: Enum.random([3600, 7200, 86_400, 604_800]),
            baseline_period: Enum.random([7, 14, 30, 90]),
            false_positive_rate: Decimal.new(to_string(Enum.random(1..10)) <> ".5"),
            detection_accuracy: Decimal.new(to_string(Enum.random(80..95)) <> ".2"),
            patterns_detected: anomaly_patterns(),
            severity_distribution: severity_distribution(),
            temporal_patterns: temporal_patterns(),
            feature_importance: feature_importance_data(),
            alert_rules: anomaly_alert_rules(),
            auto_resolution: Enum.random([true, false]),
            escalation_rules: escalation_rules(),
            metadata: anomaly_detection_metadata(),
            tenant_id: fn -> build(:tenant).id end,
            organization_id: fn -> build(:organization).id end
          },
          attrs
        )
      end

      # ===== BEHAVIOR PROFILE FACTORY =====
      @spec behavior_profile_factory() :: any()
      def behavior_profile_factory do
        %{
          profile_name: sequence(:profile_name, &behavior_profile_name/1),
          entity_type: random_behavior_entity(),
          entity_id: fn -> Faker.UUID.v4() end,
          profile_type: random_profile_type(),
          learning_period: Enum.random([7, 14, 30, 60, 90]),
          confidence_level: Decimal.new(to_string(Enum.random(60..95)) <> ".3"),
          baseline_established: Enum.random([true, false]),
          activity_patterns: activity_patterns(),
          temporal_patterns: behavior_temporal_patterns(),
          location_patterns: location_patterns(),
          interaction_patterns: interaction_patterns(),
          deviation_threshold: Decimal.new(to_string(Enum.random(10..50)) <> ".0"),
          risk_indicators: behavior_risk_indicators(),
          normal_behaviors: normal_behavior_list(),
          anomalous_behaviors: anomalous_behavior_list(),
          last_updated: random_profile_update(),
          update_frequency: Enum.random([:hourly, :daily, :weekly]),
          profile_version: sequence(:profile_version, &"p#{&1}.0"),
          metadata: behavior_profile_metadata(),
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      # ===== Additional Factory Resources =====

      @spec alert_correlation_factory() :: any()
      def alert_correlation_factory do
        %{
          correlation_name: sequence(:correlation_name, &correlation_name/1),
          rule_type: random_correlation_rule(),
          time_window: Enum.random([300, 600, 1800, 3600]),
          correlation_threshold: Decimal.new(to_string(Enum.random(70..95)) <> ".0"),
          event_types: correlation_event_types(),
          matching_criteria: correlation_criteria(),
          action_rules: correlation_actions(),
          enabled: Enum.random([true, false]),
          priority: Enum.random([:low, :medium, :high, :critical]),
          metadata: correlation_metadata(),
          tenant_id: fn -> build(:tenant).id end
        }
      end

      @spec incident_prediction_factory() :: any()
      def incident_prediction_factory do
        %{
          prediction_type: random_prediction_type(),
          prediction_horizon: Enum.random([1, 6, 12, 24, 48]),
          confidence_score: Decimal.new(to_string(Enum.random(60..90)) <> ".5"),
          probability_score: Decimal.new(to_string(Enum.random(10..80)) <> ".2"),
          risk_factors: prediction_risk_factors(),
          historical_accuracy: Decimal.new(to_string(Enum.random(70..90)) <> ".3"),
          model_version: sequence(:pred_version, &"pm#{&1}.0"),
          prediction_window: prediction_time_window(),
          mitigation_recommendations: prediction_mitigations(),
          metadata: prediction_metadata(),
          tenant_id: fn -> build(:tenant).id end
        }
      end

      @spec performance_metric_factory() :: any()
      def performance_metric_factory do
        %{
          metric_name: sequence(:perf_metric, &performance_metric_name/1),
          category: random_performance_category(),
          measurement_unit: random_measurement_unit(),
          current_value: random_performance_value(),
          target_value: random_performance_target(),
          benchmark_value: random_benchmark_value(),
          trend_direction: Enum.random([:up, :down, :stable]),
          measurement_period: random_measurement_period(),
          data_quality_score: Decimal.new(to_string(Enum.random(80..100)) <> ".0"),
          metadata: performance_metric_metadata(),
          tenant_id: fn -> build(:tenant).id end
        }
      end

      @spec compliance_score_factory() :: any()
      def compliance_score_factory do
        %{
          framework_name: random_compliance_framework(),
          overall_score: Decimal.new(to_string(Enum.random(60..100)) <> ".0"),
          compliance_percentage: Decimal.new(to_string(Enum.random(70..100)) <> ".5"),
          non_compliance_count: Enum.random(0..25),
          critical_findings: Enum.random(0..10),
          assessment_date: random_assessment_date(),
          next_assessment: fn -> Date.add(assessment_date(), Enum.random(90..365)) end,
          auditor_notes: compliance_auditor_notes(),
          remediation_plan: remediation_plan_data(),
          metadata: compliance_score_metadata(),
          tenant_id: fn -> build(:tenant).id end
        }
      end

      # ===== REPORT FACTORY (Analytics Reports) =====
      @spec report_factory(any()) :: any()
      def report_factory(attrs \\ %{}) do
        attrs_map = normalize_attrs(attrs)
        {tenant, attrs_map} = handle_tenant_association(attrs_map, __MODULE__)

        report_types = ["security", "maintenance", "usage", "compliance", "performance"]

        report_attrs =
          %{
            name: sequence(:report_name, &"Report #{&1}"),
            description: "Test report",
            active: true,
            type: attrs_map[:type] || Enum.random(report_types),
            status: :draft,
            configuration: %{},
            tags: [],
            metadata: %{},
            tenant_id: tenant.id
          }
          |> merge_attributes(attrs_map)
          |> Map.delete(:tenant)
          |> Map.delete(:format)

        system_admin = %{id: "system", is_system_admin: true}

        case Ash.create(
               Indrajaal.Analytics.Report,
               report_attrs,
               action: :create_report,
               authorize?: false,
               actor: system_admin
             ) do
          {:ok, report} ->
            report

          {:error, changeset} ->
            raise "Failed to create report: #{inspect(changeset)}"
        end
      end

      unquote(analytics_factory_part_2())
    end
  end

  defp analytics_factory_part_2 do
    quote do
      alias Faker
      alias Indrajaal.Shared.TestSupport

      # ===== HELPER FUNCTIONS =====

      @spec random_metric_type() :: any()
      defp random_metric_type do
        Enum.random([
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
          :user_activity,
          :system_performance,
          :data_accuracy
        ])
      end

      @spec random_period_type() :: any()
      defp random_period_type do
        Enum.random([:hourly, :daily, :weekly, :monthly, :quarterly, :yearly])
      end

      @spec random_period_start() :: any()
      defp random_period_start do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(1..86_400), :second)
        |> DateTime.truncate(:second)
      end

      @spec random_period_duration() :: any()
      defp random_period_duration do
        case Enum.random([:hourly, :daily, :weekly]) do
          :hourly -> 3600
          :daily -> 86_400
          :weekly -> 604_800
        end
      end

      @spec random_metric_value() :: any()
      defp random_metric_value do
        Decimal.new(to_string(:rand.uniform(1000) + :rand.uniform()))
      end

      @spec metric_unit_for_type() :: any()
      defp metric_unit_for_type do
        Enum.random(["seconds", "percentage", "count", "dollars", "score", "rate"])
      end

      @spec random_dimensions() :: any()
      defp random_dimensions do
        %{
          "site_id" => Faker.UUID.v4(),
          "department" => Enum.random(["Security", "Operations", "IT", "Facilities"]),
          "shift" => Enum.random(["day", "night", "weekend"]),
          "zone" => Enum.random(["A", "B", "C", "D"])
        }
      end

      @spec random_target_value() :: any()
      defp random_target_value do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(500) + :rand.uniform()))
        else
          nil
        end
      end

      @spec random_threshold_min() :: any()
      defp random_threshold_min do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(100)))
        else
          nil
        end
      end

      @spec random_threshold_max() :: any()
      defp random_threshold_max do
        if Enum.random([true, false]) do
          Decimal.new(to_string(:rand.uniform(800) + 200))
        else
          nil
        end
      end

      @spec security_metric_metadata() :: any()
      defp security_metric_metadata do
        %{
          "source_system" => Enum.random(["CCTV", "Access Control", "Alarm Panel", "Analytics"]),
          "collection_method" => Enum.random(["automated", "manual", "calculated"]),
          "data_quality" => Enum.random(["high", "medium", "low"]),
          "last_validated" => DateTime.to_iso8601(DateTime.utc_now())
        }
      end

      # ===== SHARED HELPER FUNCTIONS =====

      @spec base_attributes() :: any()
      defp base_attributes do
        %{
          tenant_id: fn -> build(:tenant).id end,
          organization_id: fn -> build(:organization).id end
        }
      end

      @spec analytics_metadata() :: any()
      defp analytics_metadata do
        %{
          metadata: trend_metadata()
        }
      end

      # ===== TREND ANALYSIS HELPER FUNCTIONS =====

      @spec trend_analysis_name(integer()) :: String.t()
      defp trend_analysis_name(n), do: "Trend Analysis #{n}"

      @spec random_analysis_type() :: atom()
      defp random_analysis_type do
        Enum.random([:linear, :exponential, :seasonal, :cyclical, :step_change])
      end

      @spec random_time_period() :: atom()
      defp random_time_period do
        Enum.random([:daily, :weekly, :monthly, :quarterly, :yearly])
      end

      @spec random_start_date() :: Date.t()
      defp random_start_date do
        Date.utc_today() |> Date.add(-Enum.random(30..365))
      end

      @spec start_date() :: Date.t()
      defp start_date, do: random_start_date()

      @spec random_slope() :: Decimal.t()
      defp random_slope do
        Decimal.new(to_string(Enum.random(-100..100) / 10.0))
      end

      @spec random_seasonal_pattern() :: map()
      defp random_seasonal_pattern do
        %{
          "type" => Enum.random(["weekly", "monthly", "yearly"]),
          "strength" => Enum.random(1..10)
        }
      end

      @spec trend_insights() :: list()
      defp trend_insights do
        Enum.take_random(
          ["Upward trend detected", "Stable pattern", "Seasonal variation", "Anomaly detected"],
          Enum.random(1..3)
        )
      end

      @spec trend_recommendations() :: list()
      defp trend_recommendations do
        Enum.take_random(
          ["Monitor closely", "Increase capacity", "Review procedures", "Schedule maintenance"],
          Enum.random(1..2)
        )
      end

      @spec trend_metadata() :: map()
      defp trend_metadata do
        %{
          "source" => "analytics_engine",
          "version" => "1.0",
          "generated_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      end

      # ===== HEAT MAP HELPER FUNCTIONS =====

      @spec heat_map_name(integer()) :: String.t()
      defp heat_map_name(n), do: "Heat Map #{n}"

      @spec random_map_type() :: atom()
      defp random_map_type do
        Enum.random([:activity, :incident, :access, :motion, :thermal])
      end

      @spec random_data_source() :: atom()
      defp random_data_source do
        Enum.random([:sensors, :cameras, :access_logs, :incidents, :patrols])
      end

      @spec random_time_range_start() :: DateTime.t()
      defp random_time_range_start do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(3600..86_400), :second)
        |> DateTime.truncate(:second)
      end

      @spec time_range_start() :: DateTime.t()
      defp time_range_start, do: random_time_range_start()

      @spec heat_map_config() :: map()
      defp heat_map_config do
        %{
          "opacity" => Enum.random(50..100) / 100.0,
          "blur" => Enum.random(1..5)
        }
      end

      @spec coverage_area_data() :: map()
      defp coverage_area_data do
        %{
          "total_area" => Enum.random(1000..10_000),
          "covered_area" => Enum.random(800..9000)
        }
      end

      @spec heat_map_metadata() :: map()
      defp heat_map_metadata do
        %{
          "generated_at" => DateTime.to_iso8601(DateTime.utc_now()),
          "algorithm" => "density_estimation"
        }
      end

      # ===== DASHBOARD HELPER FUNCTIONS =====

      @spec dashboard_name(integer()) :: String.t()
      defp dashboard_name(n), do: "Security Dashboard #{n}"

      @spec random_dashboard_type() :: atom()
      defp random_dashboard_type do
        Enum.random([:overview, :detailed, :executive, :operational, :custom])
      end

      @spec random_layout_config() :: map()
      defp random_layout_config do
        %{"columns" => Enum.random(2..4), "rows" => Enum.random(2..6)}
      end

      @spec dashboard_widgets() :: list()
      defp dashboard_widgets do
        widgets = ["chart", "table", "gauge", "map", "counter", "timeline"]
        Enum.take_random(widgets, Enum.random(3..6))
      end

      @spec random_dashboard_time_range() :: map()
      defp random_dashboard_time_range do
        %{"period" => Enum.random(["1h", "24h", "7d", "30d"]), "refresh" => true}
      end

      @spec dashboard_filters() :: map()
      defp dashboard_filters do
        %{"site" => "all", "device_type" => "all"}
      end

      @spec dashboard_permissions() :: map()
      defp dashboard_permissions do
        %{"view" => ["admin", "operator"], "edit" => ["admin"]}
      end

      @spec sharing_settings() :: map()
      defp sharing_settings do
        %{"enabled" => false, "link" => nil}
      end

      @spec random_last_accessed() :: DateTime.t()
      defp random_last_accessed do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(0..86_400), :second)
        |> DateTime.truncate(:second)
      end

      @spec dashboard_metadata() :: map()
      defp dashboard_metadata do
        %{"created_by" => "system", "template" => "default"}
      end

      # ===== RISK SCORE HELPER FUNCTIONS =====

      @spec random_entity_type() :: atom()
      defp random_entity_type do
        Enum.random([:site, :device, :user, :zone, :building])
      end

      @spec random_risk_category() :: atom()
      defp random_risk_category do
        Enum.random([:security, :operational, :compliance, :financial, :reputational])
      end

      @spec random_risk_score() :: Decimal.t()
      defp random_risk_score do
        Decimal.new(to_string(Enum.random(0..100)))
      end

      @spec calculate_severity_level() :: atom()
      defp calculate_severity_level do
        Enum.random([:low, :medium, :high, :critical])
      end

      @spec risk_factors() :: list()
      defp risk_factors do
        factors = ["access_control", "surveillance", "personnel", "environmental", "technical"]
        Enum.take_random(factors, Enum.random(2..4))
      end

      @spec random_calculation_time() :: DateTime.t()
      defp random_calculation_time do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(0..3600), :second)
        |> DateTime.truncate(:second)
      end

      @spec last_calculated() :: DateTime.t()
      defp last_calculated, do: random_calculation_time()

      @spec mitigation_strategies() :: list()
      defp mitigation_strategies do
        strategies = ["increase_patrols", "upgrade_cameras", "train_staff", "review_policies"]
        Enum.take_random(strategies, Enum.random(1..3))
      end

      @spec impact_assessment_data() :: map()
      defp impact_assessment_data do
        %{"financial" => Enum.random(1..5), "operational" => Enum.random(1..5)}
      end

      @spec probability_data() :: map()
      defp probability_data do
        %{"likelihood" => Enum.random(1..5), "frequency" => "rare"}
      end

      @spec residual_risk_data() :: map()
      defp residual_risk_data do
        %{"score" => Enum.random(10..50), "acceptable" => true}
      end

      @spec risk_score_metadata() :: map()
      defp risk_score_metadata do
        %{"model" => "risk_v1", "last_update" => DateTime.to_iso8601(DateTime.utc_now())}
      end

      # ===== PREDICTIVE MODEL HELPER FUNCTIONS =====

      @spec predictive_model_name(integer()) :: String.t()
      defp predictive_model_name(n), do: "Predictive Model #{n}"

      @spec random_model_type() :: atom()
      defp random_model_type do
        Enum.random([:classification, :regression, :clustering, :anomaly_detection])
      end

      @spec random_algorithm() :: atom()
      defp random_algorithm do
        Enum.random([:random_forest, :neural_network, :svm, :gradient_boosting, :lstm])
      end

      @spec model_hyperparameters() :: map()
      defp model_hyperparameters do
        %{"learning_rate" => 0.01, "epochs" => 100, "batch_size" => 32}
      end

      @spec random_training_time() :: DateTime.t()
      defp random_training_time do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(86_400..604_800), :second)
        |> DateTime.truncate(:second)
      end

      @spec last_trained() :: DateTime.t()
      defp last_trained, do: random_training_time()

      @spec predictive_model_metadata() :: map()
      defp predictive_model_metadata do
        %{"framework" => "tensorflow", "version" => "2.0"}
      end

      # ===== ANOMALY DETECTION HELPER FUNCTIONS =====

      @spec random_detection_type() :: atom()
      defp random_detection_type do
        Enum.random([:point, :contextual, :collective, :seasonal])
      end

      @spec random_anomaly_algorithm() :: atom()
      defp random_anomaly_algorithm do
        Enum.random([:isolation_forest, :dbscan, :autoencoder, :statistical])
      end

      @spec random_threshold() :: Decimal.t()
      defp random_threshold do
        Decimal.new(to_string(Enum.random(1..100) / 10.0))
      end

      @spec random_detection_time() :: DateTime.t()
      defp random_detection_time do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(0..3600), :second)
        |> DateTime.truncate(:second)
      end

      @spec anomaly_patterns() :: list()
      defp anomaly_patterns do
        patterns = ["spike", "drop", "drift", "level_shift"]
        Enum.take_random(patterns, Enum.random(1..3))
      end

      @spec severity_distribution() :: map()
      defp severity_distribution do
        %{"low" => 60, "medium" => 30, "high" => 8, "critical" => 2}
      end

      @spec temporal_patterns() :: map()
      defp temporal_patterns do
        %{"peak_hours" => [9, 17], "quiet_hours" => [2, 5]}
      end

      @spec feature_importance_data() :: map()
      defp feature_importance_data do
        %{"time" => 0.3, "location" => 0.25, "device" => 0.2, "user" => 0.15, "other" => 0.1}
      end

      @spec anomaly_alert_rules() :: list()
      defp anomaly_alert_rules do
        [
          %{"threshold" => 0.8, "action" => "notify"},
          %{"threshold" => 0.95, "action" => "escalate"}
        ]
      end

      @spec escalation_rules() :: list()
      defp escalation_rules do
        [%{"level" => 1, "contact" => "operator"}, %{"level" => 2, "contact" => "supervisor"}]
      end

      @spec anomaly_detection_metadata() :: map()
      defp anomaly_detection_metadata do
        %{
          "engine" => "anomaly_detector_v2",
          "last_calibration" => DateTime.to_iso8601(DateTime.utc_now())
        }
      end

      # ===== BEHAVIOR PROFILE HELPER FUNCTIONS =====

      @spec behavior_profile_name(integer()) :: String.t()
      defp behavior_profile_name(n), do: "Behavior Profile #{n}"

      @spec random_behavior_entity() :: atom()
      defp random_behavior_entity do
        Enum.random([:user, :device, :zone, :access_point])
      end

      @spec random_profile_type() :: atom()
      defp random_profile_type do
        Enum.random([:individual, :group, :role_based, :temporal])
      end

      @spec activity_patterns() :: map()
      defp activity_patterns do
        %{"work_hours" => [8, 18], "active_days" => ["Mon", "Tue", "Wed", "Thu", "Fri"]}
      end

      @spec behavior_temporal_patterns() :: map()
      defp behavior_temporal_patterns do
        %{"peak_activity" => 10, "low_activity" => 3}
      end

      @spec location_patterns() :: map()
      defp location_patterns do
        %{"primary_zones" => ["lobby", "office"], "rare_zones" => ["server_room"]}
      end

      @spec interaction_patterns() :: map()
      defp interaction_patterns do
        %{"frequent_contacts" => 5, "avg_interactions" => 20}
      end

      @spec behavior_risk_indicators() :: list()
      defp behavior_risk_indicators do
        indicators = ["after_hours_access", "unusual_location", "failed_attempts"]
        Enum.take_random(indicators, Enum.random(0..2))
      end

      @spec normal_behavior_list() :: list()
      defp normal_behavior_list do
        ["badge_in_morning", "badge_out_evening", "cafeteria_access"]
      end

      @spec anomalous_behavior_list() :: list()
      defp anomalous_behavior_list do
        ["weekend_access", "multiple_failed_attempts"]
      end

      @spec random_profile_update() :: DateTime.t()
      defp random_profile_update do
        DateTime.utc_now()
        |> DateTime.add(-Enum.random(0..86_400), :second)
        |> DateTime.truncate(:second)
      end

      @spec behavior_profile_metadata() :: map()
      defp behavior_profile_metadata do
        %{"algorithm" => "behavioral_analytics_v1", "confidence" => 0.85}
      end

      # ===== ALERT CORRELATION HELPER FUNCTIONS =====

      @spec correlation_name(integer()) :: String.t()
      defp correlation_name(n), do: "Correlation Rule #{n}"

      @spec random_correlation_rule() :: atom()
      defp random_correlation_rule do
        Enum.random([:temporal, :spatial, :causal, :pattern_based])
      end

      @spec correlation_event_types() :: list()
      defp correlation_event_types do
        types = ["alarm", "access", "motion", "tamper", "system"]
        Enum.take_random(types, Enum.random(2..4))
      end

      @spec correlation_criteria() :: map()
      defp correlation_criteria do
        %{"match_type" => "any", "min_events" => 2}
      end

      @spec correlation_actions() :: list()
      defp correlation_actions do
        [%{"type" => "create_incident", "priority" => "high"}]
      end

      @spec correlation_metadata() :: map()
      defp correlation_metadata do
        %{"engine" => "correlation_v1", "enabled" => true}
      end

      # ===== INCIDENT PREDICTION HELPER FUNCTIONS =====

      @spec random_prediction_type() :: atom()
      defp random_prediction_type do
        Enum.random([:intrusion, :equipment_failure, :access_violation, :vandalism])
      end

      @spec prediction_risk_factors() :: list()
      defp prediction_risk_factors do
        factors = ["time_of_day", "historical_patterns", "weather", "events"]
        Enum.take_random(factors, Enum.random(2..4))
      end

      @spec prediction_time_window() :: map()
      defp prediction_time_window do
        %{"start" => DateTime.to_iso8601(DateTime.utc_now()), "hours" => Enum.random(1..48)}
      end

      @spec prediction_mitigations() :: list()
      defp prediction_mitigations do
        mitigations = ["increase_patrols", "alert_staff", "lock_down_area"]
        Enum.take_random(mitigations, Enum.random(1..2))
      end

      @spec prediction_metadata() :: map()
      defp prediction_metadata do
        %{"model" => "incident_predictor_v1", "accuracy" => 0.82}
      end

      # ===== PERFORMANCE METRIC HELPER FUNCTIONS =====

      @spec performance_metric_name(integer()) :: String.t()
      defp performance_metric_name(n), do: "Performance Metric #{n}"

      @spec random_performance_category() :: atom()
      defp random_performance_category do
        Enum.random([:response_time, :throughput, :availability, :efficiency])
      end

      @spec random_measurement_unit() :: String.t()
      defp random_measurement_unit do
        Enum.random(["ms", "percent", "count", "rate"])
      end

      @spec random_performance_value() :: Decimal.t()
      defp random_performance_value do
        Decimal.new(to_string(Enum.random(1..1000) / 10.0))
      end

      @spec random_performance_target() :: Decimal.t()
      defp random_performance_target do
        Decimal.new(to_string(Enum.random(50..200) / 10.0))
      end

      @spec random_benchmark_value() :: Decimal.t()
      defp random_benchmark_value do
        Decimal.new(to_string(Enum.random(30..150) / 10.0))
      end

      @spec random_measurement_period() :: atom()
      defp random_measurement_period do
        Enum.random([:hourly, :daily, :weekly, :monthly])
      end

      @spec performance_metric_metadata() :: map()
      defp performance_metric_metadata do
        %{"source" => "performance_monitor", "version" => "1.0"}
      end

      # ===== COMPLIANCE SCORE HELPER FUNCTIONS =====

      @spec random_compliance_framework() :: String.t()
      defp random_compliance_framework do
        Enum.random(["ISO27001", "SOC2", "GDPR", "HIPAA", "PCI-DSS"])
      end

      @spec random_assessment_date() :: Date.t()
      defp random_assessment_date do
        Date.utc_today() |> Date.add(-Enum.random(0..90))
      end

      @spec assessment_date() :: Date.t()
      defp assessment_date, do: random_assessment_date()

      @spec compliance_auditor_notes() :: String.t()
      defp compliance_auditor_notes do
        Enum.random([
          "All controls verified",
          "Minor findings noted",
          "Remediation required",
          "Compliant with recommendations"
        ])
      end

      @spec remediation_plan_data() :: map()
      defp remediation_plan_data do
        %{
          "items" => Enum.random(0..5),
          "due_date" => Date.to_iso8601(Date.add(Date.utc_today(), 30))
        }
      end

      @spec compliance_score_metadata() :: map()
      defp compliance_score_metadata do
        %{"auditor" => "internal", "methodology" => "continuous"}
      end

      # ===== BULK METRICS HELPER FUNCTIONS =====

      @spec metric_types() :: list()
      defp metric_types do
        [:response_time, :false_alarm_rate, :incident_count, :patrol_completion, :device_uptime]
      end

      @spec period_type_by_pattern(integer()) :: atom()
      defp period_type_by_pattern(i) do
        types = [:hourly, :daily, :weekly, :monthly]
        Enum.at(types, rem(i, length(types)))
      end

      @spec realistic_value_for_metric(atom(), integer()) :: Decimal.t()
      defp realistic_value_for_metric(_type, i) do
        Decimal.new(to_string(rem(i * 7, 100) + Enum.random(1..10)))
      end

      @spec unit_for_metric_type(atom()) :: String.t()
      defp unit_for_metric_type(:response_time), do: "seconds"
      defp unit_for_metric_type(:false_alarm_rate), do: "percentage"
      defp unit_for_metric_type(:incident_count), do: "count"
      defp unit_for_metric_type(:patrol_completion), do: "percentage"
      defp unit_for_metric_type(:device_uptime), do: "percentage"
      defp unit_for_metric_type(_), do: "unit"

      @spec dimensions_for_metric(atom(), integer()) :: map()
      defp dimensions_for_metric(_type, i) do
        %{"site" => "site_#{rem(i, 5)}", "zone" => "zone_#{rem(i, 3)}"}
      end

      @spec target_for_metric_type(atom()) :: Decimal.t() | nil
      defp target_for_metric_type(:response_time), do: Decimal.new("60")
      defp target_for_metric_type(:false_alarm_rate), do: Decimal.new("5")
      defp target_for_metric_type(:patrol_completion), do: Decimal.new("95")
      defp target_for_metric_type(:device_uptime), do: Decimal.new("99")
      defp target_for_metric_type(_), do: nil

      @spec threshold_min_for_type(atom()) :: Decimal.t() | nil
      defp threshold_min_for_type(:device_uptime), do: Decimal.new("90")
      defp threshold_min_for_type(:patrol_completion), do: Decimal.new("80")
      defp threshold_min_for_type(_), do: nil

      @spec threshold_max_for_type(atom()) :: Decimal.t() | nil
      defp threshold_max_for_type(:response_time), do: Decimal.new("120")
      defp threshold_max_for_type(:false_alarm_rate), do: Decimal.new("10")
      defp threshold_max_for_type(_), do: nil

      @spec metadata_for_pattern(integer()) :: map()
      defp metadata_for_pattern(i) do
        %{"pattern_id" => i, "generated" => true}
      end

      @spec period_start() :: DateTime.t()
      defp period_start, do: random_period_start()
    end
  end
end
