# PHICS v2.1 Configuration for Multi-AI Validation Framework
# Created: 2025-01-01 05:50:00 CEST
# Purpose: Hot-reloading integration for container-based validation

import Config

# PHICS v2.1 Hot-Reloading Configuration
config :phics,
  enabled: true,
  # milliseconds - <50ms target
  sync_interval: 50,
  bidirectional_sync: true,
  hot_reload_enabled: true,
  validation_framework_integration: true

# Multi-AI Validation Framework Integration
config :multi_ai_validation,
  container_mode: true,
  phics_integration: true,
  validators: [
    claude: %{
      port: 8001,
      weight: 40,
      role: "primary",
      capabilities: ["semantic_analysis", "code_generation", "pattern_recognition"],
      container_name: "indrajaal-claude-validator",
      health_endpoint: "/health",
      hot_reload_support: true
    },
    opencode: %{
      port: 8002,
      weight: 30,
      role: "secondary",
      capabilities: ["static_analysis", "security_scan", "performance_check"],
      container_name: "indrajaal-opencode-validator",
      health_endpoint: "/health",
      hot_reload_support: true
    },
    fpps: %{
      port: 8003,
      weight: 30,
      role: "consensus",
      capabilities: ["multi_method", "consensus_check", "false_positive_prevention"],
      container_name: "indrajaal-fpps-validator",
      health_endpoint: "/health",
      hot_reload_support: true
    }
  ],
  consensus_manager: %{
    port: 8000,
    weight: 100,
    role: "coordinator",
    capabilities: ["quorum_voting", "emergency_halt", "audit_trail"],
    container_name: "indrajaal-consensus-manager",
    health_endpoint: "/health",
    hot_reload_support: true
  }

# Container Deployment Configuration
config :container_deployment,
  base_image: "registry.nixos.org/nixos/nixos:25.05",
  registry_prefix: "localhost/",
  network_name: "indrajaal-multi-ai-validation",
  volume_prefix: "indrajaal-validation-",
  memory_limit: "2GB",
  cpu_limit: "2.0",
  health_check_interval: "30s",
  restart_policy: "unless-stopped"

# PHICS File Synchronization
config :phics, :file_sync,
  watch_patterns: ["*.exs", "*.ex", "*.json", "*.md"],
  ignore_patterns: ["_build/**", "deps/**", ".git/**", "*.beam"],
  container_mount: "/workspace",
  host_mount: "/home/an/dev/indrajaal-demo",
  sync_mode: :bidirectional,
  conflict_resolution: :host_wins,
  # milliseconds
  sync_delay: 50,
  # immediate sync for validation files
  batch_sync: false,
  verbose_logging: true

# SOPv5.11 Cybernetic Framework Integration
config :sopv511_framework,
  agent_architecture: :fifty_agent,
  cybernetic_coordination: true,
  safety_constraints: 8,
  emergency_protocols: ["emergency_stop", "consensus_halt", "container_isolation"],
  patient_mode: true,
  infinite_patience: true,
  timeout_disabled: true

# STAMP Safety Constraints for Container Deployment
config :stamp_safety,
  constraints: [
    "SC-VAL-001": "System SHALL use Patient Mode for all validations",
    "SC-VAL-002": "System SHALL achieve consensus across all validators",
    "SC-VAL-003": "System SHALL halt on validation disagreement",
    "SC-CNT-001": "Containers SHALL use only localhost registry",
    "SC-CNT-002": "PHICS SHALL maintain <50ms sync latency",
    "SC-CNT-003": "Health checks SHALL pass before validation",
    "SC-EMR-001": "Emergency stop SHALL complete in <5 seconds",
    "SC-EMR-002": "All validation data SHALL be preserved during emergency"
  ],
  monitoring_enabled: true,
  violation_response: :immediate_halt

# TDG (Test-Driven Generation) Configuration
config :tdg_validation,
  test_driven_deployment: true,
  pre_deployment_tests: true,
  post_deployment_validation: true,
  container_test_coverage: 95,
  integration_test_coverage: 90,
  regression_test_enabled: true

# Performance and Monitoring
config :performance_monitoring,
  metrics_collection: true,
  # milliseconds
  response_time_target: 500,
  memory_monitoring: true,
  cpu_monitoring: true,
  network_latency_monitoring: true,
  phics_sync_latency_monitoring: true,
  alert_thresholds: %{
    # milliseconds
    response_time: 1000,
    # percentage
    memory_usage: 85,
    # percentage
    cpu_usage: 90,
    # milliseconds
    sync_latency: 100
  }

# Logging Configuration
config :logger,
  backends: [:console, {LoggerFileBackend, :validation_framework}],
  level: :info

config :logger, :validation_framework,
  path: "./data/tmp/multi_ai_validation_framework.log",
  level: :info,
  format: "$date $time [$level] $metadata$message\n",
  metadata: [:container, :validator, :sync_status, :latency]

# Emergency Response Configuration
config :emergency_response,
  protocols: [
    %{
      name: "validation_disagreement",
      trigger: "consensus_failure",
      action: "immediate_halt",
      recovery: "manual_investigation"
    },
    %{
      name: "container_failure",
      trigger: "health_check_failure",
      action: "container_restart",
      recovery: "automatic_with_logging"
    },
    %{
      name: "phics_sync_failure",
      trigger: "sync_latency_exceeded",
      action: "sync_restart",
      recovery: "bidirectional_resync"
    },
    %{
      name: "memory_exhaustion",
      trigger: "memory_threshold_exceeded",
      action: "graceful_degradation",
      recovery: "resource_optimization"
    }
  ],
  # 30 seconds
  escalation_delay: 30_000,
  manual_intervention_required: ["validation_disagreement", "security_violation"]

# Development Environment Configuration
config :dev_environment,
  hot_reload_enabled: true,
  code_reloading: true,
  automatic_testing: true,
  phics_development_mode: true,
  container_development_workflow: true,
  real_time_feedback: true
