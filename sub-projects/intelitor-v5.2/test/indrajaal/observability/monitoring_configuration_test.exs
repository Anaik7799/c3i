defmodule Indrajaal.Observability.MonitoringConfigurationTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Observability.MonitoringConfiguration

  describe "get_config/0" do
    test "returns complete configuration map" do
      config = MonitoringConfiguration.get_config()

      assert is_map(config)
      assert Map.has_key?(config, :environment)
      assert Map.has_key?(config, :deployment_mode)
      assert Map.has_key?(config, :cluster_mode)
    end

    test "includes all major subsystems" do
      config = MonitoringConfiguration.get_config()

      # Verify all major subsystems are present
      assert Map.has_key?(config, :monitoring)
      assert Map.has_key?(config, :metrics)
      assert Map.has_key?(config, :tracing)
      assert Map.has_key?(config, :performance)
      assert Map.has_key?(config, :health)
      assert Map.has_key?(config, :alerting)
      assert Map.has_key?(config, :dashboards)
      assert Map.has_key?(config, :cybernetic)
      assert Map.has_key?(config, :container)
      assert Map.has_key?(config, :business_intelligence)
    end

    test "monitoring subsystem has required configuration" do
      config = MonitoringConfiguration.get_config()

      assert config.monitoring.enabled == true
      assert is_map(config.monitoring.intervals)
      assert is_map(config.monitoring.retention)
    end

    test "metrics subsystem has Prometheus configuration" do
      config = MonitoringConfiguration.get_config()

      assert is_map(config.metrics.prometheus)
      assert config.metrics.prometheus.enabled == true
      assert config.metrics.prometheus.port == 9568
      assert config.metrics.prometheus.path == "/metrics"
    end

    test "tracing subsystem has Jaeger configuration" do
      config = MonitoringConfiguration.get_config()

      assert config.tracing.enabled == true
      assert is_map(config.tracing.jaeger)
      assert config.tracing.jaeger.enabled == true
      assert is_binary(config.tracing.jaeger.endpoint)
    end

    test "performance subsystem has analysis configuration" do
      config = MonitoringConfiguration.get_config()

      assert config.performance.enabled == true
      assert is_map(config.performance.analysis)
      assert is_map(config.performance.thresholds)
      assert is_map(config.performance.ml_models)
    end

    test "health subsystem has check configuration" do
      config = MonitoringConfiguration.get_config()

      assert config.health.enabled == true
      assert is_map(config.health.checks)
      assert is_map(config.health.scoring)
      assert is_map(config.health.anomaly_detection)
    end

    test "alerting subsystem has channels and rules" do
      config = MonitoringConfiguration.get_config()

      assert config.alerting.enabled == true
      assert is_map(config.alerting.channels)
      assert is_map(config.alerting.rules)
      assert is_map(config.alerting.deduplication)
      assert is_map(config.alerting.escalation)
    end

    test "cybernetic subsystem has agent monitoring" do
      config = MonitoringConfiguration.get_config()

      assert config.cybernetic.enabled == true
      assert is_map(config.cybernetic.agent_monitoring)
      assert is_map(config.cybernetic.goal_tracking)
      assert is_map(config.cybernetic.performance_metrics)
    end

    test "container subsystem has PHICS configuration" do
      config = MonitoringConfiguration.get_config()

      assert config.container.enabled == true
      assert is_map(config.container.phics)
      assert config.container.phics.enabled == true
      assert is_map(config.container.phics.thresholds)
    end

    test "includes environment in configuration" do
      config = MonitoringConfiguration.get_config()

      assert is_atom(config.environment)
      assert config.environment in [:development, :test, :production]
    end
  end

  describe "get_environment_config/1" do
    test "returns development configuration" do
      config = MonitoringConfiguration.get_environment_config(:development)

      assert config.environment == :development
      assert is_map(config)
    end

    test "returns test configuration" do
      config = MonitoringConfiguration.get_environment_config(:test)

      assert config.environment == :test
      # Test environment has monitoring disabled
      assert config.monitoring.enabled == false
      assert config.tracing.enabled == false
      assert config.alerting.enabled == false
    end

    test "returns production configuration" do
      config = MonitoringConfiguration.get_environment_config(:production)

      assert config.environment == :production
      # Production has alerting enabled
      assert config.alerting.enabled == true
    end

    test "development has different sampling rate than production" do
      dev_config = MonitoringConfiguration.get_environment_config(:development)
      prod_config = MonitoringConfiguration.get_environment_config(:production)

      # Development has 100% sampling for debugging
      assert dev_config.tracing.jaeger.sampling_rate == 1.0

      # Production has reduced sampling for performance
      assert prod_config.tracing.jaeger.sampling_rate == 0.05
    end

    test "test environment disables all monitoring subsystems" do
      config = MonitoringConfiguration.get_environment_config(:test)

      assert config.monitoring.enabled == false
      assert config.tracing.enabled == false
      assert config.alerting.enabled == false
      assert config.health.enabled == false
      assert config.performance.enabled == false
    end

    test "production has higher health threshold" do
      prod_config = MonitoringConfiguration.get_environment_config(:production)

      # Production requires higher health score
      assert prod_config.health.scoring.healthy_threshold == 90
    end

    test "production has high anomaly detection sensitivity" do
      prod_config = MonitoringConfiguration.get_environment_config(:production)

      assert prod_config.performance.ml_models.anomaly_detection.sensitivity == :high
    end
  end

  describe "validate_config/0" do
    test "validates successfully with default configuration" do
      assert :ok = MonitoringConfiguration.validate_config()
    end

    test "returns :ok when all subsystems are valid" do
      result = MonitoringConfiguration.validate_config()

      assert result == :ok
    end
  end

  describe "update_config/2" do
    test "accepts valid section and configuration updates" do
      new_config = %{enabled: false}

      assert :ok = MonitoringConfiguration.update_config(:monitoring, new_config)
    end

    test "handles multiple section updates" do
      sections = [:monitoring, :metrics, :tracing, :performance, :alerting]

      Enum.each(sections, fn section ->
        result = MonitoringConfiguration.update_config(section, %{test: true})
        assert result == :ok
      end)
    end

    test "accepts empty configuration map" do
      assert :ok = MonitoringConfiguration.update_config(:monitoring, %{})
    end

    test "accepts nested configuration updates" do
      new_config = %{
        prometheus: %{
          enabled: false,
          port: 9999
        }
      }

      assert :ok = MonitoringConfiguration.update_config(:metrics, new_config)
    end
  end

  describe "get_subsystem_config/1" do
    test "returns monitoring subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:monitoring)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :intervals)
      assert Map.has_key?(config, :retention)
    end

    test "returns metrics subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:metrics)

      assert is_map(config)
      assert Map.has_key?(config, :prometheus)
      assert Map.has_key?(config, :custom_metrics)
    end

    test "returns tracing subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:tracing)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :jaeger)
      assert Map.has_key?(config, :opentelemetry)
    end

    test "returns performance subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:performance)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :analysis)
      assert Map.has_key?(config, :thresholds)
    end

    test "returns health subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:health)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :checks)
      assert Map.has_key?(config, :scoring)
    end

    test "returns alerting subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:alerting)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :channels)
      assert Map.has_key?(config, :rules)
    end

    test "returns cybernetic subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:cybernetic)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :agent_monitoring)
      assert Map.has_key?(config, :goal_tracking)
    end

    test "returns container subsystem configuration" do
      config = MonitoringConfiguration.get_subsystem_config(:container)

      assert is_map(config)
      assert Map.has_key?(config, :enabled)
      assert Map.has_key?(config, :phics)
      assert Map.has_key?(config, :metrics)
    end

    test "returns empty map for non-existent subsystem" do
      config = MonitoringConfiguration.get_subsystem_config(:non_existent)

      assert config == %{}
    end

    test "all subsystems return valid configuration" do
      subsystems = [
        :monitoring,
        :metrics,
        :tracing,
        :performance,
        :health,
        :alerting,
        :dashboards,
        :cybernetic,
        :container,
        :business_intelligence
      ]

      Enum.each(subsystems, fn subsystem ->
        config = MonitoringConfiguration.get_subsystem_config(subsystem)
        assert is_map(config)
      end)
    end
  end

  describe "monitoring intervals" do
    test "has valid real-time metrics interval" do
      config = MonitoringConfiguration.get_config()

      assert is_integer(config.monitoring.intervals.real_time_metrics)
      assert config.monitoring.intervals.real_time_metrics > 0
    end

    test "has valid system metrics interval" do
      config = MonitoringConfiguration.get_config()

      assert is_integer(config.monitoring.intervals.system_metrics)
      assert config.monitoring.intervals.system_metrics > 0
    end

    test "has valid business metrics interval" do
      config = MonitoringConfiguration.get_config()

      assert is_integer(config.monitoring.intervals.business_metrics)
      assert config.monitoring.intervals.business_metrics > 0
    end

    test "has all required monitoring intervals" do
      config = MonitoringConfiguration.get_config()
      intervals = config.monitoring.intervals

      required_intervals = [
        :real_time_metrics,
        :system_metrics,
        :business_metrics,
        :performance_analysis,
        :predictive_analysis,
        :optimization_analysis
      ]

      Enum.each(required_intervals, fn interval ->
        assert Map.has_key?(intervals, interval)
        assert is_integer(intervals[interval])
      end)
    end

    test "intervals increase in duration appropriately" do
      config = MonitoringConfiguration.get_config()
      intervals = config.monitoring.intervals

      # Real-time should be shortest
      assert intervals.real_time_metrics < intervals.system_metrics
      # System should be shorter than business
      assert intervals.system_metrics < intervals.business_metrics
      # Business should be shorter than performance analysis
      assert intervals.business_metrics < intervals.performance_analysis
    end
  end

  describe "data retention periods" do
    test "has valid retention periods for all data types" do
      config = MonitoringConfiguration.get_config()
      retention = config.monitoring.retention

      data_types = [
        :real_time_data,
        :historical_data,
        :analytics_data,
        :business_data,
        :archive_data
      ]

      Enum.each(data_types, fn data_type ->
        assert Map.has_key?(retention, data_type)
        assert is_integer(retention[data_type])
        assert retention[data_type] > 0
      end)
    end

    test "retention periods increase with data importance" do
      config = MonitoringConfiguration.get_config()
      retention = config.monitoring.retention

      # Archive data should have longest retention
      assert retention.archive_data > retention.business_data
      # Business data should have longer retention than analytics
      assert retention.business_data > retention.analytics_data
    end
  end

  describe "performance thresholds" do
    test "has response time thresholds" do
      config = MonitoringConfiguration.get_config()
      thresholds = config.performance.thresholds.response_time

      assert is_integer(thresholds.excellent)
      assert is_integer(thresholds.good)
      assert is_integer(thresholds.acceptable)
      assert is_integer(thresholds.poor)
    end

    test "response time thresholds are ordered correctly" do
      config = MonitoringConfiguration.get_config()
      thresholds = config.performance.thresholds.response_time

      assert thresholds.excellent < thresholds.good
      assert thresholds.good < thresholds.acceptable
      assert thresholds.acceptable < thresholds.poor
    end

    test "has resource usage thresholds for all resource types" do
      config = MonitoringConfiguration.get_config()
      resource_usage = config.performance.thresholds.resource_usage

      resources = [:cpu, :memory, :disk, :network]

      Enum.each(resources, fn resource ->
        assert Map.has_key?(resource_usage, resource)
        assert Map.has_key?(resource_usage[resource], :warning)
        assert Map.has_key?(resource_usage[resource], :critical)
      end)
    end

    test "resource thresholds have warning before critical" do
      config = MonitoringConfiguration.get_config()
      resource_usage = config.performance.thresholds.resource_usage

      # All resources should have warning < critical
      assert resource_usage.cpu.warning < resource_usage.cpu.critical
      assert resource_usage.memory.warning < resource_usage.memory.critical
      assert resource_usage.disk.warning < resource_usage.disk.critical
      assert resource_usage.network.warning < resource_usage.network.critical
    end

    test "has error rate thresholds" do
      config = MonitoringConfiguration.get_config()
      error_rates = config.performance.thresholds.error_rates

      assert is_number(error_rates.warning)
      assert is_number(error_rates.critical)
      assert error_rates.warning < error_rates.critical
    end

    test "has availability thresholds" do
      config = MonitoringConfiguration.get_config()
      availability = config.performance.thresholds.availability

      assert is_number(availability.target)
      assert is_number(availability.minimum)
      assert availability.minimum < availability.target
    end
  end

  describe "machine learning configuration" do
    test "has anomaly detection ML configuration" do
      config = MonitoringConfiguration.get_config()
      ml_config = config.performance.ml_models.anomaly_detection

      assert ml_config.enabled == true
      assert ml_config.algorithm == :isolation_forest
      assert is_atom(ml_config.sensitivity)
      assert is_integer(ml_config.training_window_days)
      assert is_integer(ml_config.retraining_interval_hours)
    end

    test "has performance forecasting ML configuration" do
      config = MonitoringConfiguration.get_config()
      ml_config = config.performance.ml_models.performance_forecasting

      assert ml_config.enabled == true
      assert ml_config.algorithm == :linear_regression
      assert is_integer(ml_config.forecast_horizon_days)
      assert is_number(ml_config.confidence_interval)
    end

    test "has capacity planning ML configuration" do
      config = MonitoringConfiguration.get_config()
      ml_config = config.performance.ml_models.capacity_planning

      assert ml_config.enabled == true
      assert ml_config.algorithm == :time_series_forecasting
      assert is_integer(ml_config.planning_horizon_days)
      assert ml_config.growth_rate_analysis == true
    end
  end

  describe "alert configuration" do
    test "has email alert channel configuration" do
      config = MonitoringConfiguration.get_config()
      email = config.alerting.channels.email

      assert email.enabled == true
      assert is_list(email.recipients)
      assert length(email.recipients) > 0
    end

    test "has slack alert channel configuration" do
      config = MonitoringConfiguration.get_config()
      slack = config.alerting.channels.slack

      assert is_boolean(slack.enabled)
      assert Map.has_key?(slack, :webhook_url)
      assert Map.has_key?(slack, :channel)
    end

    test "has alert rules for performance" do
      config = MonitoringConfiguration.get_config()
      rules = config.alerting.rules

      assert Map.has_key?(rules, :slow_response_time)
      assert Map.has_key?(rules, :high_error_rate)
      assert Map.has_key?(rules, :resource_exhaustion)
    end

    test "has alert rules for business metrics" do
      config = MonitoringConfiguration.get_config()
      rules = config.alerting.rules

      assert Map.has_key?(rules, :low_user_engagement)
    end

    test "has alert rules for cybernetic metrics" do
      config = MonitoringConfiguration.get_config()
      rules = config.alerting.rules

      assert Map.has_key?(rules, :agent_coordination_failure)
      assert Map.has_key?(rules, :goal_achievement_drop)
    end

    test "alert rules have required fields" do
      config = MonitoringConfiguration.get_config()
      rules = config.alerting.rules

      Enum.each(rules, fn {_name, rule} ->
        assert is_atom(rule.severity)
      end)
    end

    test "has deduplication configuration" do
      config = MonitoringConfiguration.get_config()
      dedup = config.alerting.deduplication

      assert dedup.enabled == true
      assert is_integer(dedup.window_minutes)
      assert is_number(dedup.similar_alert_threshold)
    end

    test "has escalation configuration" do
      config = MonitoringConfiguration.get_config()
      escalation = config.alerting.escalation

      assert escalation.enabled == true
      assert is_list(escalation.levels)
      assert length(escalation.levels) > 0
    end
  end

  describe "PHICS container configuration" do
    test "has PHICS sync latency threshold" do
      config = MonitoringConfiguration.get_config()
      phics = config.container.phics

      assert is_integer(phics.thresholds.sync_latency_ms)
      assert phics.thresholds.sync_latency_ms == 50
    end

    test "has PHICS hot reload threshold" do
      config = MonitoringConfiguration.get_config()
      phics = config.container.phics

      assert is_integer(phics.thresholds.hot_reload_ms)
      assert phics.thresholds.hot_reload_ms > 0
    end

    test "has file watch response threshold" do
      config = MonitoringConfiguration.get_config()
      phics = config.container.phics

      assert is_integer(phics.thresholds.file_watch_response_ms)
      assert phics.thresholds.file_watch_response_ms > 0
    end

    test "has all PHICS monitoring flags enabled" do
      config = MonitoringConfiguration.get_config()
      phics = config.container.phics

      assert phics.sync_latency_monitoring == true
      assert phics.hot_reload_tracking == true
      assert phics.file_change_detection == true
      assert phics.bidirectional_sync_validation == true
    end
  end

  describe "cybernetic agent monitoring" do
    test "has monitoring levels for all agent types" do
      config = MonitoringConfiguration.get_config()
      agent_monitoring = config.cybernetic.agent_monitoring

      assert Map.has_key?(agent_monitoring, :executive_director)
      assert Map.has_key?(agent_monitoring, :domain_supervisors)
      assert Map.has_key?(agent_monitoring, :functional_supervisors)
      assert Map.has_key?(agent_monitoring, :worker_agents)
    end

    test "executive director has comprehensive monitoring" do
      config = MonitoringConfiguration.get_config()

      assert config.cybernetic.agent_monitoring.executive_director.monitoring_level ==
               :comprehensive
    end

    test "monitoring levels decrease with agent hierarchy" do
      config = MonitoringConfiguration.get_config()
      monitoring = config.cybernetic.agent_monitoring

      # Executive director should have highest monitoring level
      assert monitoring.executive_director.monitoring_level == :comprehensive
      # Domain supervisors should have detailed monitoring
      assert monitoring.domain_supervisors.monitoring_level == :detailed
      # Worker agents should have basic monitoring
      assert monitoring.worker_agents.monitoring_level == :basic
    end

    test "has goal tracking configuration" do
      config = MonitoringConfiguration.get_config()
      goal_tracking = config.cybernetic.goal_tracking

      assert goal_tracking.enabled == true
      assert is_integer(goal_tracking.tracking_interval_minutes)
      assert is_number(goal_tracking.achievement_threshold)
      assert is_number(goal_tracking.coordination_efficiency_threshold)
    end

    test "has cybernetic performance metrics flags" do
      config = MonitoringConfiguration.get_config()
      metrics = config.cybernetic.performance_metrics

      assert metrics.decision_quality == true
      assert metrics.coordination_efficiency == true
      assert metrics.goal_achievement_rate == true
      assert metrics.resource_utilization == true
      assert metrics.adaptation_speed == true
    end
  end

  describe "integration scenarios" do
    test "complete configuration workflow" do
      # 1. Get current configuration
      config = MonitoringConfiguration.get_config()
      assert is_map(config)

      # 2. Validate configuration
      assert :ok = MonitoringConfiguration.validate_config()

      # 3. Get subsystem configurations
      monitoring = MonitoringConfiguration.get_subsystem_config(:monitoring)
      assert is_map(monitoring)

      # 4. Update configuration
      assert :ok = MonitoringConfiguration.update_config(:monitoring, %{test: true})
    end

    test "environment-specific configuration workflow" do
      # 1. Get development configuration
      dev_config = MonitoringConfiguration.get_environment_config(:development)
      assert dev_config.environment == :development

      # 2. Get test configuration
      test_config = MonitoringConfiguration.get_environment_config(:test)
      assert test_config.environment == :test

      # 3. Get production configuration
      prod_config = MonitoringConfiguration.get_environment_config(:production)
      assert prod_config.environment == :production

      # 4. Verify environment-specific differences
      assert dev_config.tracing.jaeger.sampling_rate != prod_config.tracing.jaeger.sampling_rate
    end

    test "subsystem configuration access workflow" do
      subsystems = [
        :monitoring,
        :metrics,
        :tracing,
        :performance,
        :health,
        :alerting,
        :cybernetic,
        :container
      ]

      # Get all subsystem configurations
      configs =
        Enum.map(subsystems, fn subsystem ->
          MonitoringConfiguration.get_subsystem_config(subsystem)
        end)

      # All should be valid maps
      Enum.each(configs, fn config ->
        assert is_map(config)
      end)
    end
  end

  describe "STAMP safety constraints" do
    test "SC1: configuration provides complete monitoring coverage" do
      config = MonitoringConfiguration.get_config()

      # Verify all critical subsystems are covered
      critical_subsystems = [:monitoring, :metrics, :tracing, :health, :alerting]

      Enum.each(critical_subsystems, fn subsystem ->
        assert Map.has_key?(config, subsystem)
        subsystem_config = config[subsystem]
        assert Map.has_key?(subsystem_config, :enabled)
      end)
    end

    test "SC2: configuration validation prevents invalid states" do
      # Validation should pass for valid configuration
      assert :ok = MonitoringConfiguration.validate_config()
    end

    test "SC3: environment-specific configurations maintain safety" do
      environments = [:development, :test, :production]

      Enum.each(environments, fn env ->
        config = MonitoringConfiguration.get_environment_config(env)

        # All environment configs should have required structure
        assert is_map(config)
        assert is_atom(config.environment)
        assert config.environment == env
      end)
    end
  end
end
