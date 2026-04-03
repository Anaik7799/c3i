# STAMP/TDG/GDE Monitoring Configuration
# Generated: 2025-08-02 23:25:00 CEST

import Config

# Telemetry configuration for STAMP/TDG/GDE monitoring
config :indrajaal, :stamp_tdg_gde_monitoring,
  enabled: true,

  # STAMP monitoring configuration
  stamp: [
    # Track STPA analyses
    track_stpa_analyses: true,
    stpa_analysis_events: [
      [:stamp, :stpa, :started],
      [:stamp, :stpa, :completed],
      [:stamp, :stpa, :failed]
    ],

    # Track CAST investigations
    track_cast_investigations: true,
    cast_events: [
      [:stamp, :cast, :initiated],
      [:stamp, :cast, :completed],
      [:stamp, :cast, :recommendations]
    ],

    # Track safety violations
    track_violations: true,
    violation_events: [
      [:stamp, :violation, :detected],
      [:stamp, :violation, :resolved]
    ],

    # Compliance thresholds
    compliance_thresholds: [
      critical: 98,
      warning: 95,
      info: 90
    ]
  ],

  # TDG monitoring configuration
  tdg: [
    # Track test coverage
    track_coverage: true,
    coverage_events: [
      [:tdg, :coverage, :calculated],
      [:tdg, :coverage, :improved],
      [:tdg, :coverage, :degraded]
    ],

    # Track validation
    track_validation: true,
    validation_events: [
      [:tdg, :validation, :started],
      [:tdg, :validation, :passed],
      [:tdg, :validation, :failed]
    ],

    # Track AI generation
    track_generation: true,
    generation_events: [
      [:tdg, :generation, :requested],
      [:tdg, :generation, :completed],
      [:tdg, :generation, :rejected]
    ],

    # Coverage requirements
    coverage_requirements: [
      minimum: 95,
      target: 98,
      ideal: 100
    ]
  ],

  # GDE monitoring configuration
  gde: [
    # Track goals
    track_goals: true,
    goal_events: [
      [:gde, :goal, :defined],
      [:gde, :goal, :updated],
      [:gde, :goal, :achieved],
      [:gde, :goal, :missed]
    ],

    # Track progress
    track_progress: true,
    progress_events: [
      [:gde, :progress, :reported],
      [:gde, :progress, :milestone],
      [:gde, :progress, :blocked]
    ],

    # Track interventions
    track_interventions: true,
    intervention_events: [
      [:gde, :intervention, :triggered],
      [:gde, :intervention, :executed],
      [:gde, :intervention, :successful]
    ],

    # Goal achievement thresholds
    achievement_thresholds: [
      on_track: 90,
      at_risk: 70,
      critical: 50
    ]
  ],

  # Dashboards configuration
  dashboards: [
    # Main overview dashboard
    overview: [
      name: "STAMP/TDG/GDE Overview",
      refresh_interval: :timer.seconds(30),
      panels: [
        :compliance_gauges,
        :trend_charts,
        :recent_events,
        :goal_progress
      ]
    ],

    # STAMP safety dashboard
    safety: [
      name: "STAMP Safety Analysis",
      refresh_interval: :timer.seconds(60),
      panels: [
        :stpa_analyses,
        :cast_investigations,
        :violation_heatmap,
        :safety_trends
      ]
    ],

    # TDG quality dashboard
    quality: [
      name: "TDG Quality Metrics",
      refresh_interval: :timer.seconds(60),
      panels: [
        :coverage_by_module,
        :validation_results,
        :generation_stats,
        :quality_trends
      ]
    ],

    # GDE progress dashboard
    progress: [
      name: "GDE Goal Progress",
      refresh_interval: :timer.seconds(120),
      panels: [
        :active_goals,
        :achievement_timeline,
        :intervention_log,
        :prediction_accuracy
      ]
    ]
  ],

  # Alerting configuration
  alerts: [
    # STAMP alerts
    stamp_compliance_low: [
      condition: "compliance_score < 95",
      severity: :warning,
      channels: [:email, :slack]
    ],
    stamp_critical_violation: [
      condition: "critical_violations > 0",
      severity: :critical,
      channels: [:pagerduty, :email, :slack]
    ],

    # TDG alerts
    tdg_coverage_drop: [
      condition: "coverage_change < -5",
      severity: :warning,
      channels: [:email, :slack]
    ],
    tdg_validation_failure: [
      condition: "validation_failures > threshold",
      severity: :error,
      channels: [:email, :slack, :ci_cd]
    ],

    # GDE alerts
    gde_goal_at_risk: [
      condition: "achievement_probability < 50",
      severity: :warning,
      channels: [:email, :slack]
    ],
    gde_goal_blocked: [
      condition: "blocked_duration > 24h",
      severity: :error,
      channels: [:email, :slack, :jira]
    ]
  ],

  # Data retention
  retention: [
    raw_events: {:days, 7},
    aggregated_metrics: {:days, 30},
    reports: {:days, 90},
    audit_logs: {:days, 365}
  ],

  # Export configuration
  export: [
    formats: [:json, :csv, :prometheus],
    endpoints: [
      prometheus: "/metrics",
      json_api: "/api/monitoring/metrics"
    ]
  ]

# LiveDashboard integration
config :phoenix_live_dashboard,
  additional_pages: [
    stamp_tdg_gde: Indrajaal.Monitoring.StampTdgGdePage
  ]

# Prometheus exporter configuration
config :prometheus,
  collectors: [
    Indrajaal.Monitoring.StampCollector,
    Indrajaal.Monitoring.TdgCollector,
    Indrajaal.Monitoring.GdeCollector
  ]
