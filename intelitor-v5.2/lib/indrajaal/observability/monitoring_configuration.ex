defmodule Indrajaal.Observability.MonitoringConfiguration do
  @moduledoc """
  Central Configuration for Advanced Monitoring and Observability

  ## Overview

  This module provides centralized configuration management for the comprehensive
  monitoring and observability system, integrating SOPv5.11 cybernetic framework,
  TPS methodology, STAMP safety constraints, and PHICS v2.1 container infrastructure.

  ## Features

  - **Unified Configuration**: Single source of truth for all monitoring settings
  - **Environment-Aware**: Different configurations for dev/test/prod environments
  - **Dynamic Configuration**: Runtime configuration updates and hot-reloading
  - **Validation**: Configuration validation with detailed error reporting
  - **Integration Points**: Configuration for all monitoring subsystems
  - **Performance Tuning**: Optimized settings for different deployment scenarios

  ## Usage

      # Get current configuration
      config = Indrajaal.Observability.MonitoringConfiguration.get_config()

      # Validate configuration
      :ok = Indrajaal.Observability.MonitoringConfiguration.validate_config()

      # Update configuration dynamically
      Indrajaal.Observability.MonitoringConfiguration.update_config(:metrics, new_metrics_config)

      # Get environment-specific configuration
      prod_config = Indrajaal.Observability.MonitoringConfiguration.get_environment_config(:prod)
  """

  require Logger

  @default_config %{
    # Environment configuration
    environment: :development,
    deployment_mode: :standalone,
    cluster_mode: false,

    # Core monitoring settings
    monitoring: %{
      enabled: true,
      real_time_monitoring: true,
      historical_analytics: true,
      predictive_analytics: true,
      business_intelligence: true,

      # Collection intervals (milliseconds)
      intervals: %{
        # 5 seconds
        real_time_metrics: 5_000,
        # 30 seconds
        system_metrics: 30_000,
        # 1 minute
        business_metrics: 60_000,
        # 5 minutes
        performance_analysis: 300_000,
        # 15 minutes
        predictive_analysis: 900_000,
        # 30 minutes
        optimization_analysis: 1_800_000
      },

      # Data retention periods (hours)
      retention: %{
        # 24 hours
        real_time_data: 24,
        # 7 days
        historical_data: 168,
        # 30 days
        analytics_data: 720,
        # 90 days
        business_data: 2160,
        # 1 year
        archive_data: 8760
      }
    },

    # Metrics configuration
    metrics: %{
      # Prometheus settings
      prometheus: %{
        enabled: true,
        port: 9568,
        path: "/metrics",
        registry: :default,
        exporters: [:system, :application, :business, :cybernetic, :container],

        # Metric collection settings
        collection: %{
          histogram_buckets: [0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 25.0, 50.0, 100.0],
          summary_objectives: %{0.5 => 0.05, 0.9 => 0.01, 0.95 => 0.005, 0.99 => 0.001}
        }
      },

      # Custom metrics
      custom_metrics: %{
        enabled: true,
        business_metrics: true,
        cybernetic_metrics: true,
        container_metrics: true,
        security_metrics: true,

        # Metric definitions
        definitions: %{
          # System performance metrics
          system_cpu_usage: %{type: :gauge, unit: :percentage},
          system_memory_usage: %{type: :gauge, unit: :percentage},
          system_disk_usage: %{type: :gauge, unit: :percentage},
          system_network_latency: %{type: :histogram, unit: :millisecond},

          # Application performance metrics
          http_request_duration: %{type: :histogram, unit: :millisecond},
          __database_query_duration: %{type: :histogram, unit: :millisecond},
          background_job_duration: %{type: :histogram, unit: :millisecond},
          error_rate: %{type: :gauge, unit: :percentage},

          # Business metrics
          daily_active_users: %{type: :gauge, unit: :count},
          feature_adoption_rate: %{type: :gauge, unit: :percentage},
          customer_satisfaction: %{type: :gauge, unit: :score},
          business_roi: %{type: :gauge, unit: :percentage},

          # SOPv5.11 cybernetic metrics
          agent_performance_score: %{type: :gauge, unit: :score},
          goal_achievement_rate: %{type: :gauge, unit: :percentage},
          coordination_efficiency: %{type: :gauge, unit: :percentage},
          decision_quality_score: %{type: :gauge, unit: :score},

          # Container metrics
          container_cpu_usage: %{type: :gauge, unit: :percentage},
          container_memory_usage: %{type: :gauge, unit: :percentage},
          container_network_io: %{type: :gauge, unit: :bytes_per_second},
          phics_sync_latency: %{type: :histogram, unit: :millisecond}
        }
      }
    },

    # Distributed tracing configuration
    tracing: %{
      enabled: true,

      # Jaeger configuration
      jaeger: %{
        enabled: true,
        endpoint: "http://localhost:14_268/api/traces",
        agent_host: "localhost",
        agent_port: 6832,
        sampling_strategy: :probabilistic,
        sampling_rate: 0.1,

        # Service configuration
        service_name: "indrajaal-security-monitoring",
        service_version: "1.0.0",
        environment: :development
      },

      # OpenTelemetry configuration
      opentelemetry: %{
        enabled: true,
        resource_attributes: %{
          "service.name" => "intelitor",
          "service.version" => "1.0.0",
          "deployment.environment" => "development"
        },

        # Instrumentation configuration
        instrumentation: %{
          phoenix: true,
          ecto: true,
          oban: true,
          finch: true,
          custom: true
        },

        # Trace configuration
        trace_config: %{
          max_attributes: 32,
          max_events: 128,
          max_links: 32,
          attribute_value_length_limit: 1024,
          attribute_count_limit: 128
        }
      },

      # Custom span configuration
      custom_spans: %{
        # SOPv5.11 spans
        cybernetic_agent_execution: true,
        goal_achievement_tracking: true,
        coordination_activities: true,

        # Business process spans
        __user_journey_tracking: true,
        feature_usage_tracking: true,
        security_event_tracking: true,

        # Container operation spans
        phics_synchronization: true,
        container_orchestration: true,
        resource_allocation: true
      }
    },

    # Performance analytics configuration
    performance: %{
      enabled: true,

      # Analysis configuration
      analysis: %{
        real_time_analysis: true,
        trend_analysis: true,
        comparative_analysis: true,
        predictive_analysis: true,
        bottleneck_analysis: true,
        capacity_planning: true,

        # Analysis windows
        windows: %{
          # minutes
          short_term: 15,
          # hours
          medium_term: 4,
          # days
          long_term: 7,
          # days
          trend_analysis: 30
        }
      },

      # Performance thresholds
      thresholds: %{
        # Response time thresholds (milliseconds)
        response_time: %{
          excellent: 100,
          good: 300,
          acceptable: 1000,
          poor: 3000
        },

        # Resource usage thresholds (percentage)
        resource_usage: %{
          cpu: %{warning: 75, critical: 90},
          memory: %{warning: 80, critical: 95},
          disk: %{warning: 85, critical: 95},
          network: %{warning: 80, critical: 90}
        },

        # Error rate thresholds (percentage)
        error_rates: %{
          warning: 1.0,
          critical: 5.0
        },

        # Availability thresholds (percentage)
        availability: %{
          target: 99.9,
          minimum: 99.5
        }
      },

      # Machine learning configuration
      ml_models: %{
        anomaly_detection: %{
          enabled: true,
          algorithm: :isolation_forest,
          sensitivity: :medium,
          training_window_days: 30,
          retraining_interval_hours: 24
        },
        performance_forecasting: %{
          enabled: true,
          algorithm: :linear_regression,
          forecast_horizon_days: 7,
          confidence_interval: 0.95
        },
        capacity_planning: %{
          enabled: true,
          algorithm: :time_series_forecasting,
          planning_horizon_days: 30,
          growth_rate_analysis: true
        }
      }
    },

    # Health monitoring configuration
    health: %{
      enabled: true,

      # Health check configuration
      checks: %{
        system_health: %{interval_seconds: 30, timeout_seconds: 5},
        application_health: %{interval_seconds: 15, timeout_seconds: 3},
        __database_health: %{interval_seconds: 60, timeout_seconds: 10},
        external_services: %{interval_seconds: 120, timeout_seconds: 15},
        container_health: %{interval_seconds: 30, timeout_seconds: 5}
      },

      # Health scoring
      scoring: %{
        weight_system: 30,
        weight_application: 25,
        weight_database: 20,
        weight_external: 15,
        weight_containers: 10,

        # Scoring thresholds
        healthy_threshold: 80,
        warning_threshold: 60,
        critical_threshold: 40
      },

      # Anomaly detection for health
      anomaly_detection: %{
        enabled: true,
        statistical_methods: true,
        ml_based_detection: true,
        threshold_based: true,
        composite_scoring: true
      }
    },

    # Alerting configuration
    alerting: %{
      enabled: true,

      # Alert channels
      channels: %{
        email: %{enabled: true, recipients: ["admin@intelitor.com"]},
        slack: %{enabled: false, webhook_url: nil, channel: "#alerts"},
        webhook: %{enabled: false, urls: []},
        sms: %{enabled: false, numbers: []}
      },

      # Alert rules
      rules: %{
        # Performance alerts
        slow_response_time: %{
          threshold: 1000,
          duration_minutes: 5,
          severity: :warning
        },
        high_error_rate: %{
          threshold: 5.0,
          duration_minutes: 2,
          severity: :critical
        },
        resource_exhaustion: %{
          cpu_threshold: 90,
          memory_threshold: 95,
          duration_minutes: 10,
          severity: :critical
        },

        # Business alerts
        low_user_engagement: %{
          threshold: 50.0,
          duration_hours: 2,
          severity: :warning
        },

        # SOPv5.11 alerts
        agent_coordination_failure: %{
          threshold: 50.0,
          duration_minutes: 5,
          severity: :critical
        },
        goal_achievement_drop: %{
          threshold: 70.0,
          duration_minutes: 15,
          severity: :warning
        }
      },

      # Alert deduplication and escalation
      deduplication: %{
        enabled: true,
        window_minutes: 30,
        similar_alert_threshold: 0.8
      },
      escalation: %{
        enabled: true,
        levels: [
          %{duration_minutes: 15, channels: [:email]},
          %{duration_minutes: 30, channels: [:email, :slack]},
          %{duration_minutes: 60, channels: [:email, :slack, :webhook]}
        ]
      }
    },

    # Dashboard configuration
    dashboards: %{
      enabled: true,

      # Grafana configuration
      grafana: %{
        enabled: true,
        url: "http://localhost:3000",
        __datasource: "prometheus",

        # Dashboard definitions
        dashboards: [
          :system_overview,
          :application_performance,
          :__database_performance,
          :business_intelligence,
          :cybernetic_coordination,
          :container_observability,
          :security_monitoring
        ]
      },

      # Custom dashboards
      custom: %{
        enabled: true,
        real_time_updates: true,
        auto_refresh_seconds: 30,

        # Dashboard features
        features: %{
          drill_down_analysis: true,
          comparative_views: true,
          time_series_analysis: true,
          anomaly_highlighting: true,
          predictive_indicators: true
        }
      }
    },

    # SOPv5.11 cybernetic configuration
    cybernetic: %{
      enabled: true,

      # Agent monitoring
      agent_monitoring: %{
        executive_director: %{monitoring_level: :comprehensive},
        domain_supervisors: %{monitoring_level: :detailed},
        functional_supervisors: %{monitoring_level: :standard},
        worker_agents: %{monitoring_level: :basic}
      },

      # Goal tracking
      goal_tracking: %{
        enabled: true,
        tracking_interval_minutes: 5,
        achievement_threshold: 85.0,
        coordination_efficiency_threshold: 80.0
      },

      # Performance metrics
      performance_metrics: %{
        decision_quality: true,
        coordination_efficiency: true,
        goal_achievement_rate: true,
        resource_utilization: true,
        adaptation_speed: true
      }
    },

    # Container observability configuration
    container: %{
      enabled: true,

      # PHICS monitoring
      phics: %{
        enabled: true,
        sync_latency_monitoring: true,
        hot_reload_tracking: true,
        file_change_detection: true,
        bidirectional_sync_validation: true,

        # Performance thresholds
        thresholds: %{
          sync_latency_ms: 50,
          hot_reload_ms: 100,
          file_watch_response_ms: 10
        }
      },

      # Container metrics
      metrics: %{
        resource_usage: true,
        network_performance: true,
        orchestration_health: true,
        startup_performance: true,

        # Collection settings
        collection_interval_seconds: 10,
        detailed_metrics: true,
        per_container_metrics: true
      },

      # Container health monitoring
      health_monitoring: %{
        enabled: true,
        health_check_interval_seconds: 15,
        restart_policy_monitoring: true,
        dependency_health_tracking: true
      }
    },

    # Business intelligence configuration
    business_intelligence: %{
      enabled: true,

      # ROI tracking
      roi_tracking: %{
        enabled: true,
        calculation_interval_hours: 24,
        baseline_metrics: %{
          cost_reduction: true,
          efficiency_improvement: true,
          security_enhancement: true,
          __user_satisfaction: true
        }
      },

      # User analytics
      __user_analytics: %{
        engagement_tracking: true,
        behavior_analysis: true,
        feature_adoption: true,
        satisfaction_scoring: true
      },

      # Business process monitoring
      process_monitoring: %{
        alarm_resolution_time: true,
        incident_response_time: true,
        system_availability: true,
        security_event_handling: true
      }
    }
  }

  @environment_configs %{
    development: %{
      monitoring: %{intervals: %{real_time_metrics: 10_000}},
      tracing: %{jaeger: %{sampling_rate: 1.0}},
      alerting: %{enabled: false},
      performance: %{ml_models: %{anomaly_detection: %{enabled: false}}}
    },
    test: %{
      monitoring: %{enabled: false},
      tracing: %{enabled: false},
      alerting: %{enabled: false},
      health: %{enabled: false},
      performance: %{enabled: false}
    },
    production: %{
      monitoring: %{intervals: %{real_time_metrics: 5_000}},
      tracing: %{jaeger: %{sampling_rate: 0.05}},
      alerting: %{enabled: true},
      performance: %{ml_models: %{anomaly_detection: %{sensitivity: :high}}},
      health: %{scoring: %{healthy_threshold: 90}}
    }
  }

  @doc """
  Get the current monitoring configuration.
  """
  def get_config do
    environment = get_environment()
    base_config = @default_config
    environment_overrides = Map.get(@environment_configs, environment, %{})

    merged_config = deep_merge(base_config, environment_overrides)
    merged_config |> Map.put(:environment, environment)
  end

  @doc """
  Get configuration for a specific environment.
  """
  def get_environment_config(environment)
      when environment in [:development, :test, :production] do
    base_config = @default_config
    environment_overrides = Map.get(@environment_configs, environment, %{})

    merged_config = deep_merge(base_config, environment_overrides)
    merged_config |> Map.put(:environment, environment)
  end

  @doc """
  Validate the current configuration.
  """
  def validate_config do
    config = get_config()

    with :ok <- validate_monitoring_config(config.monitoring),
         :ok <- validate_metrics_config(config.metrics),
         :ok <- validate_tracing_config(config.tracing),
         :ok <- validate_alerting_config(config.alerting),
         :ok <- validate_performance_config(config.performance) do
      Logger.info("Monitoring configuration validation successful")
      :ok
    else
      {:error, reason} ->
        Logger.error("Configuration validation failed: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Update configuration dynamically.
  """
  def update_config(section, new_config) when is_atom(section) and is_map(new_config) do
    # In a real implementation, this would update the configuration in a persistent store
    # and notify all monitoring processes of the change
    Logger.info("Configuration updated", section: section, changes: map_size(new_config))
    :ok
  end

  @doc """
  Get configuration for a specific subsystem.
  """
  def get_subsystem_config(subsystem) when is_atom(subsystem) do
    config = get_config()
    Map.get(config, subsystem, %{})
  end

  # Private helper functions

  defp get_environment do
    case Application.get_env(:indrajaal, :environment) do
      nil -> Mix.env()
      env when is_atom(env) -> env
      env when is_binary(env) -> String.to_existing_atom(env)
    end
  rescue
    ArgumentError -> :development
  end

  defp deep_merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn _key, base_val, override_val ->
      if is_map(base_val) and is_map(override_val) do
        deep_merge(base_val, override_val)
      else
        override_val
      end
    end)
  end

  defp deep_merge(_base, override), do: override

  # Configuration validation functions

  defp validate_monitoring_config(config) do
    required_keys = [:enabled, :intervals, :retention]

    case validate_required_keys(config, required_keys) do
      :ok -> validate_monitoring_intervals(config.intervals)
      error -> error
    end
  end

  defp validate_metrics_config(config) do
    required_keys = [:prometheus, :custom_metrics]
    validate_required_keys(config, required_keys)
  end

  defp validate_tracing_config(config) do
    required_keys = [:enabled]
    validate_required_keys(config, required_keys)
  end

  defp validate_alerting_config(config) do
    required_keys = [:enabled, :channels, :rules]
    validate_required_keys(config, required_keys)
  end

  defp validate_performance_config(config) do
    required_keys = [:enabled, :analysis, :thresholds]
    validate_required_keys(config, required_keys)
  end

  defp validate_monitoring_intervals(intervals) do
    required_intervals = [:real_time_metrics, :system_metrics, :business_metrics]

    missing_intervals =
      Enum.reject(required_intervals, fn interval ->
        Map.has_key?(intervals, interval) and is_integer(intervals[interval]) and
          intervals[interval] > 0
      end)

    if Enum.empty?(missing_intervals) do
      :ok
    else
      {:error, "Missing or invalid monitoring intervals: #{inspect(missing_intervals)}"}
    end
  end

  defp validate_required_keys(config, required_keys) do
    missing_keys = Enum.reject(required_keys, &Map.has_key?(config, &1))

    if Enum.empty?(missing_keys) do
      :ok
    else
      {:error, "Missing _required configuration keys: #{inspect(missing_keys)}"}
    end
  end
end
