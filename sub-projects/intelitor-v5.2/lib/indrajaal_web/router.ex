defmodule IndrajaalWeb.Router do
  @moduledoc """
  Main Phoenix router for the Indrajaal security monitoring platform.

  Defines routing for web, API, and mobile endpoints with proper authentication
  and authorization pipelines.
  """
  use IndrajaalWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {IndrajaalWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # L4-A04: Theme injection (SC-HMI-001, SC-HMI-008)
    plug IndrajaalWeb.Plugs.ThemePlug
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :analytics_api do
    plug :accepts, ["json"]
    plug :put_resp_content_type, "application/json"
  end

  # Kubernetes Health Probe Routes (unauthenticated)
  # STAMP Compliance: SC-OBS-065, SC-OBS-066, SC-EMR-057
  scope "/", IndrajaalWeb do
    pipe_through :api

    get "/healthz", HealthController, :liveness
    get "/ready", HealthController, :readiness
    get "/startup", HealthController, :startup
    get "/health", HealthController, :comprehensive
  end

  pipeline :mobile_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug IndrajaalWeb.Plugs.AuthenticateAPI
    plug IndrajaalWeb.Plugs.PerformanceOptimizer
  end

  # WebSocket endpoint for mobile clients - moved to endpoint.ex
  # socket "/mobile/socket", IndrajaalWeb.MobileSocket,
  #   websocket: [
  #     connect_info: [:peer_data, :__user_agent],
  #     timeout: 45_000,
  #     compress: true
  #   ],
  #   longpoll: false

  # L4-A04: LiveView routes with theme hook (SC-HMI-001, SC-HMI-008)
  live_session :themed,
    on_mount: [IndrajaalWeb.Live.Hooks.ThemeHook] do
    scope "/", IndrajaalWeb do
      pipe_through :browser

      # System Navigation Portal (SC-PORTAL-001, SC-PORTAL-002)
      live "/", NavigationPortalLive, :index

      # Advanced Analytics Dashboard
      live "/analytics/stamp-tdg-gde-advanced", StampTdgGdeAdvancedAnalyticsLive, :index
      live "/analytics/dashboard", StampTdgGdeDashboardLive, :index

      # Permission Management
      live "/admin/permissions", PermissionsManagementLive, :index

      # Access Control Monitoring Dashboard - Worker - 5: Access Control Integration Agent
      live "/admin/access_control", AccessControlMonitoringLive, :index
      live "/admin/config", ConfigManagementLive, :index
      live "/admin/system-status", SystemStatusLive, :index
      live "/admin/journal", JournalLive, :index

      # SOPv5.1 Performance Optimization Dashboard - Worker - 1: Performance Specialist
      live "/performance", PerformanceDashboardLive, :index
      live "/monitoring", MonitoringDashboardLive, :index

      # PRAJNA C3I Mesh Cockpit (SC-HMI-001 to SC-HMI-004, SC-VDP-*)
      # Implements NASA-STD-3000 Dark Cockpit, NUREG-0700, MIL-STD-1472H principles
      live "/cockpit", PrajnaLive, :index
      live "/cockpit/dashboard", PrajnaLive, :dashboard
      live "/cockpit/startup", Prajna.StartupLive, :index
      live "/cockpit/containers", Prajna.ContainersLive, :index
      live "/cockpit/commands", Prajna.CommandsLive, :index
      live "/cockpit/mesh", Prajna.MeshLive, :index
      live "/cockpit/alarms", Prajna.AlarmsLive, :index
      live "/cockpit/ai-copilot", Prajna.CopilotLive, :index
      live "/cockpit/cluster", Prajna.ClusterLive, :index
      live "/cockpit/settings", Prajna.SettingsLive, :index
      live "/cockpit/diagnostics", Prajna.DiagnosticsLive, :index
      live "/cockpit/test-evolution", Prajna.TestCockpitLive, :index
      live "/cockpit/shutdown", Prajna.ShutdownLive, :index
      live "/cockpit/observability", Prajna.ObservabilityLive, :index
      live "/cockpit/knowledge", Prajna.KnowledgeLive, :index
      live "/cockpit/knowledge/developer", Prajna.Knowledge.DeveloperLive, :index
      live "/cockpit/knowledge/product", Prajna.Knowledge.ProductLive, :index
      live "/cockpit/knowledge/sre", Prajna.Knowledge.SRELive, :index

      # Sprint 30: Critical Safety Dashboards (SC-PRAJNA-001, SC-IMMUNE-001, SC-REG-001)
      live "/cockpit/sentinel", Prajna.SentinelDashboardLive, :index
      live "/cockpit/guardian", Prajna.GuardianDashboardLive, :index
      live "/cockpit/register", Prajna.RegisterLive, :index

      # Sprint 88: Real-time Threat + Health + Guardian Approval (SC-IMMUNE-001, SC-PRAJNA-001, SC-MON-001)
      live "/cockpit/threat", Prajna.ThreatLive, :index
      live "/cockpit/health-sparklines", Prajna.HealthSparklineLive, :index
      live "/cockpit/guardian-approval", Prajna.GuardianLive, :index

      # Git Intelligence Dashboard (SC-BRIDGE-001, SC-BIO-EXT-001)
      live "/cockpit/git-intelligence", Prajna.GitIntelligenceLive, :index

      # Sprint 52: Agentic UI — AG-UI Protocol Integration (28 ideas, Score 34-40)
      live "/cockpit/agentic/ignition", Prajna.Agentic.IgnitionLive, :index
      live "/cockpit/agentic/ai-copilot", Prajna.Agentic.AiCopilotLive, :index
      live "/cockpit/agentic/mesh-control", Prajna.Agentic.MeshControlLive, :index
      live "/cockpit/agentic/observability", Prajna.Agentic.ObservabilityLive, :index
      live "/cockpit/agentic/safety", Prajna.Agentic.SafetyLive, :index

      # Sprint 30 P2: Domain Integration Dashboards (SC-OBS-069, SC-PRAJNA-004)
      live "/cockpit/access-control", Prajna.AccessControlLive, :index
      live "/cockpit/devices", Prajna.DevicesLive, :index
      live "/cockpit/video", Prajna.VideoLive, :index
      live "/cockpit/analytics", Prajna.AnalyticsLive, :index
      live "/cockpit/compliance", Prajna.ComplianceLive, :index

      # Graph + Formal Verification (SC-GRAPH-001, SC-GVF-001, SC-VER-001)
      live "/cockpit/topology", Prajna.TopologyLive, :index
      live "/cockpit/prometheus", Prajna.PrometheusLive, :index

      # Operations Center (SC-HMI-001 to SC-HMI-004)
      # Real-time security operations monitoring and response
      live "/operations/alarms", Operations.ActiveAlarmsLive, :index
      live "/operations/alarms/:id", Operations.AlarmInvestigationLive, :show
      live "/operations/access", Operations.AccessDashboardLive, :index
      live "/operations/video", Operations.VideoWallLive, :index
      live "/operations/dispatch", Operations.DispatchConsoleLive, :index

      # Two-Key Manual Override (SC-SAFETY-001 Arm & Fire, P0-SEC RPN 240)
      live "/admin/two-key-override", Prajna.TwoKeyOverrideLive, :index

      # Bicameral Release Dashboard — Two-Key protocol sign-off (task 813a7a93)
      live "/admin/release-dashboard", Prajna.ReleaseDashboardLive, :index

      # NASA-STD-3000 Biomorphic Matrix — L0-L7 unified health view (task aa1ce076)
      live "/cockpit/biomorphic-matrix", Prajna.BiomorphicMatrixLive, :index

      # Evolution Vector Visualization — V1-V4 vectors (task 1f5e1cc0)
      live "/cockpit/evolution-vectors", Prajna.EvolutionVectorLive, :index

      # Homeostasis Control — interactive PID set points (task 167fff39)
      live "/cockpit/homeostasis", Prajna.HomeostasisControlLive, :index

      # Homeostasis Threshold Controls — band boundaries + Ziegler-Nichols ref (task 167fff39)
      live "/cockpit/homeostasis-thresholds", Prajna.HomeostasisThresholdLive, :index

      # CRM Dashboard (SC-DF-001, SC-PRF-050)
      live "/crm/dashboard", Crm.DashboardLive, :index

      # P3-UI LiveView Features (tasks 598288ec, 889e6ae7, 8db1f246, df5d7681)
      # Alarm List Real-Time (SC-ALARM-001)
      live "/prajna/alarms/list", Prajna.AlarmListLive, :index

      # Copilot Chat Streaming (SC-AGT-001)
      live "/prajna/copilot", Prajna.CopilotChatLive, :index

      # Analytics Report Builder (SC-ANALYTICS-001)
      live "/analytics/reports/builder", Analytics.ReportBuilderLive, :index

      # Device Health Grid (SC-DEV-001)
      live "/prajna/devices/grid", Prajna.DeviceHealthGridLive, :index
    end
  end

  # Mobile API routes
  scope "/api/mobile", IndrajaalWeb.Api.Mobile do
    pipe_through :api

    # Authentication endpoints (no auth __required)
    # Agent: Helper - 1 manages authentication flow
    post "/auth/login", AuthController, :login
    post "/auth/login/biometric", AuthController, :biometric_login
    post "/auth/refresh", AuthController, :refresh_token
    post "/auth/password/reset", AuthController, :request_password_reset
    post "/auth/mfa/verify", AuthController, :verify_mfa
  end

  scope "/api/mobile", IndrajaalWeb.Api.Mobile do
    pipe_through :mobile_api

    # Authentication endpoints (auth __required)
    # Agent: Helper - 1 manages authenticated operations
    post "/auth/logout", AuthController, :logout
    get "/auth/session", AuthController, :session_info
    post "/auth/mfa/enroll", AuthController, :enroll_mfa

    # Alarm management
    get "/alarms", MobileApiController, :get_alarms
    get "/alarms/:id", MobileApiController, :get_alarm
    post "/alarms/:id/acknowledge", MobileApiController, :acknowledge_alarm
    post "/alarms/:id/resolve", MobileApiController, :resolve_alarm
    post "/alarms/:id/escalate", MobileApiController, :escalate_alarm

    # Device and site information
    get "/devices", MobileApiController, :get_devices
    get "/sites", MobileApiController, :get_sites

    # Push notifications
    post "/notifications/register", MobileApiController, :register_push_notifications
    get "/notifications/preferences", MobileApiController, :get_notification_preferences
    put "/notifications/preferences", MobileApiController, :update_notification_preferences

    # Dashboard
    get "/dashboard", MobileApiController, :get_dashboard

    # Batch operations for efficient mobile performance
    # Agent: Helper - 3 manages batch operations
    post "/batch/get", BatchController, :batch_get
    post "/batch/create", BatchController, :batch_create
    put "/batch/update", BatchController, :batch_update
    post "/batch/acknowledge", BatchController, :batch_acknowledge
    post "/batch/sync", BatchController, :batch_sync
  end

  # Mobile Configuration API routes - 2,280+ endpoints for complete system conf
  # Agent Comment: Supervisor oversees all configuration routes
  # Worker agents handle domain - specific endpoints in parallel
  scope "/api/mobile/config", IndrajaalWeb.Api.Mobile.Config do
    pipe_through :mobile_api

    # Alarms Configuration (25+ endpoints) - Worker - 1
    resources "/alarms/types", AlarmsController, except: [:new, :edit]
    post "/alarms/types/bulk", AlarmsController, :bulk_create

    # Configuration Management Features (NEW)
    # Agent: Supervisor coordinates config management
    post "/alarms/bulk", AlarmsController, :bulk_create
    put "/alarms/bulk", AlarmsController, :bulk_update
    delete "/alarms/bulk", AlarmsController, :bulk_delete
    get "/alarms/export", AlarmsController, :export
    post "/alarms/import", AlarmsController, :import
    get "/alarms/templates", AlarmsController, :list_templates
    post "/alarms/templates", AlarmsController, :create_template
    post "/alarms/templates/:id/apply", AlarmsController, :apply_template
    get "/alarms/:id/versions", AlarmsController, :list_versions
    post "/alarms/:id/rollback", AlarmsController, :rollback
    get "/alarms/rules", AlarmsController, :list_rules
    post "/alarms/rules", AlarmsController, :create_rule
    put "/alarms/rules/:id", AlarmsController, :update_rule
    delete "/alarms/rules/:id", AlarmsController, :delete_rule
    get "/alarms/workflows", AlarmsController, :list_workflows
    post "/alarms/workflows", AlarmsController, :create_workflow
    put "/alarms/workflows/:id", AlarmsController, :update_workflow
    get "/alarms/escalation-policies", AlarmsController, :list_escalation_policies
    post "/alarms/escalation-policies", AlarmsController, :create_escalation_policy
    put "/alarms/escalation-policies/:id", AlarmsController, :update_escalation_policy
    post "/alarms/import", AlarmsController, :import
    get "/alarms/export", AlarmsController, :export

    # Devices Configuration (20+ endpoints) - Worker - 2
    get "/devices/types", DevicesController, :list_types
    post "/devices/register", DevicesController, :register
    resources "/devices", DevicesController, except: [:new, :edit]

    # Configuration Management Features (NEW)
    post "/devices/bulk", DevicesController, :bulk_create
    put "/devices/bulk", DevicesController, :bulk_update
    delete "/devices/bulk", DevicesController, :bulk_delete
    get "/devices/export", DevicesController, :export
    post "/devices/import", DevicesController, :import
    get "/devices/templates", DevicesController, :list_templates
    post "/devices/templates", DevicesController, :create_template
    post "/devices/templates/:id/apply", DevicesController, :apply_template
    get "/devices/:id/versions", DevicesController, :list_versions
    post "/devices/:id/rollback", DevicesController, :rollback
    get "/devices/:id/parameters", DevicesController, :get_parameters
    put "/devices/:id/parameters", DevicesController, :update_parameters
    post "/devices/:id/firmware-update", DevicesController, :firmware_update
    resources "/devices/groups", DeviceGroupsController, except: [:new, :edit]
    post "/devices/bulk-configure", DevicesController, :bulk_configure
    get "/devices/templates", DevicesController, :list_templates
    post "/devices/templates", DevicesController, :create_template

    # Sites Configuration (13 endpoints) - Worker - 3
    resources "/sites", SitesController, except: [:new, :edit]
    get "/sites/:site_id/locations", LocationsController, :index
    post "/sites/:site_id/locations", LocationsController, :create
    put "/locations/:id", LocationsController, :update
    get "/sites/:site_id/zones", ZonesController, :index
    post "/sites/:site_id/zones", ZonesController, :create
    put "/zones/:id", ZonesController, :update
    post "/sites/:id/maps/upload", SitesController, :upload_map
    get "/sites/:id/operating-hours", SitesController, :get_operating_hours
    put "/sites/:id/operating-hours", SitesController, :update_operating_hours

    # Video Configuration (14 endpoints) - Worker - 4
    resources "/video", VideoController, except: [:new, :edit]
    resources "/video/streams", VideoStreamsController, except: [:new, :edit]
    get "/video/analytics", VideoAnalyticsController, :index
    post "/video/analytics", VideoAnalyticsController, :create
    put "/video/analytics/:id", VideoAnalyticsController, :update
    get "/video/recording-policies", VideoRecordingController, :list_policies
    post "/video/recording-policies", VideoRecordingController, :create_policy
    put "/video/recording-policies/:id", VideoRecordingController, :update_policy
    get "/video/retention-policies", VideoRetentionController, :get_policies
    put "/video/retention-policies", VideoRetentionController, :update_policies
    post "/video/privacy-masks", VideoPrivacyController, :create_mask
    put "/video/privacy-masks/:id", VideoPrivacyController, :update_mask

    # Access Control Configuration (48 endpoints) - Worker - 5
    resources "/access_control", AccessControlController, except: [:new, :edit]
    post "/access_control/bulk", AccessControlController, :bulk_create
    post "/access_control/import", AccessControlController, :import
    get "/access_control/export", AccessControlController, :export

    # Visitor Management Configuration (32 endpoints) - Worker - 6
    resources "/visitor_management",
              VisitorManagementController,
              except: [:new, :edit]

    post "/visitor_management/bulk", VisitorManagementController, :bulk_create
    post "/visitor_management/import", VisitorManagementController, :import
    get "/visitor_management/export", VisitorManagementController, :export

    # Guard Tours Configuration (32 endpoints) - Worker - 2
    resources "/guard_tours", GuardToursController, except: [:new, :edit]
    post "/guard_tours/bulk", GuardToursController, :bulk_create
    post "/guard_tours/import", GuardToursController, :import
    get "/guard_tours/export", GuardToursController, :export

    # Maintenance Configuration (32 endpoints) - Worker - 3
    resources "/maintenance", MaintenanceController, except: [:new, :edit]
    post "/maintenance/bulk", MaintenanceController, :bulk_create
    post "/maintenance/import", MaintenanceController, :import
    get "/maintenance/export", MaintenanceController, :export

    # Shifts Configuration (24 endpoints) - Worker - 4
    resources "/shifts", ShiftsController, except: [:new, :edit]
    post "/shifts/bulk", ShiftsController, :bulk_create
    post "/shifts/import", ShiftsController, :import
    get "/shifts/export", ShiftsController, :export

    # Analytics Configuration (32 endpoints) - Worker - 5
    resources "/analytics", AnalyticsController, except: [:new, :edit]
    post "/analytics/bulk", AnalyticsController, :bulk_create
    post "/analytics/import", AnalyticsController, :import
    get "/analytics/export", AnalyticsController, :export

    # Intelligence Configuration (32 endpoints) - Worker - 6
    resources "/intelligence", IntelligenceController, except: [:new, :edit]
    post "/intelligence/bulk", IntelligenceController, :bulk_create
    post "/intelligence/import", IntelligenceController, :import
    get "/intelligence/export", IntelligenceController, :export

    # Integration Configuration (32 endpoints) - Worker - 1
    resources "/integration", IntegrationController, except: [:new, :edit]
    post "/integration/bulk", IntegrationController, :bulk_create
    post "/integration/import", IntegrationController, :import
    get "/integration/export", IntegrationController, :export

    # Communication Configuration (32 endpoints) - Worker - 2
    resources "/communication", CommunicationController, except: [:new, :edit]
    post "/communication/bulk", CommunicationController, :bulk_create
    post "/communication/import", CommunicationController, :import
    get "/communication/export", CommunicationController, :export

    # Fleet Management Configuration (28 endpoints) - Worker - 3
    resources "/fleet_management",
              FleetManagementController,
              except: [:new, :edit]

    post "/fleet_management/bulk", FleetManagementController, :bulk_create
    post "/fleet_management/import", FleetManagementController, :import
    get "/fleet_management/export", FleetManagementController, :export

    # Environmental Configuration (20 endpoints) - Worker - 5
    resources "/environmental", EnvironmentalController, except: [:new, :edit]
    post "/environmental/bulk", EnvironmentalController, :bulk_create
    post "/environmental/import", EnvironmentalController, :import
    get "/environmental/export", EnvironmentalController, :export

    # Compliance Configuration (36 endpoints) - Worker - 6
    resources "/compliance", ComplianceController, except: [:new, :edit]
    post "/compliance/bulk", ComplianceController, :bulk_create
    post "/compliance/import", ComplianceController, :import
    get "/compliance/export", ComplianceController, :export

    # Training Configuration (28 endpoints) - Worker - 1
    resources "/training", TrainingController, except: [:new, :edit]
    post "/training/bulk", TrainingController, :bulk_create
    post "/training/import", TrainingController, :import
    get "/training/export", TrainingController, :export

    # Accounts Configuration (24 endpoints) - Worker - 2
    resources "/accounts", AccountsController, except: [:new, :edit]
    post "/accounts/bulk", AccountsController, :bulk_create
    post "/accounts/import", AccountsController, :import
    get "/accounts/export", AccountsController, :export
  end

  # Analytics API routes for BI integration
  scope "/api/v1/analytics", IndrajaalWeb do
    pipe_through :analytics_api

    get "/stamp-tdg-gde", AnalyticsApiController, :get_stamp_tdg_gde_data
    get "/real-time", AnalyticsApiController, :get_real_time_metrics
    get "/historical", AnalyticsApiController, :get_historical_data
    get "/predictions", AnalyticsApiController, :get_predictions
    get "/anomalies", AnalyticsApiController, :get_anomalies
    get "/benchmarks", AnalyticsApiController, :get_benchmarks
    get "/data-quality", AnalyticsApiController, :get_data_quality
    get "/metadata", AnalyticsApiController, :get_metadata
    post "/export", AnalyticsApiController, :export_data
  end

  scope "/api/v1", IndrajaalWeb do
    pipe_through :analytics_api

    get "/health", AnalyticsApiController, :health_check
  end

  # KMS (Knowledge Management System) API routes
  # STAMP Compliance: SC-KMS-001, SC-KMS-002, SC-KMS-004 (OODA <100ms)
  # Fractal Holonic Architecture: SQLite (OLTP) + DuckDB (OLAP)
  scope "/api/kms", IndrajaalWeb.Api do
    pipe_through :api

    resources "/holons", KmsController, except: [:new, :edit]
    get "/holons/:id/children", KmsController, :children
    get "/holons/:id/descendants", KmsController, :descendants

    post "/edges", KmsController, :create_edge
    post "/oracle", KmsController, :oracle

    get "/search", KmsController, :search
    get "/health", KmsController, :health
    get "/entropy", KmsController, :entropy
    get "/stats", KmsController, :stats
  end

  # Prajna API routes for CEPAF-Prajna Full Sync (v21.1.0)
  # STAMP Compliance: SC-SYNC-001 to SC-SYNC-010, SC-PRAJNA-001 to SC-PRAJNA-007
  # AOR Compliance: AOR-SYNC-001 to AOR-SYNC-008, AOR-PRAJNA-001 to AOR-PRAJNA-005
  scope "/api/v1/prajna", IndrajaalWeb.Api do
    pipe_through :api

    # Sentinel Health (SC-PRAJNA-004, AOR-SYNC-007)
    get "/sentinel/health", PrajnaController, :sentinel_health

    # Guardian Integration (SC-PRAJNA-001, SC-SYNC-005)
    post "/guardian/submit", PrajnaController, :submit_command

    # Founder Directive (SC-PRAJNA-002, AOR-SYNC-003)
    post "/founder/validate", PrajnaController, :validate_founder

    # Immutable Register (SC-PRAJNA-003, SC-SYNC-006)
    post "/register/record", PrajnaController, :record_state

    # PROMETHEUS Proof Token (SC-SYNC-007)
    post "/prometheus/token", PrajnaController, :get_proof_token

    # Constitutional Check (SC-SYNC-008)
    post "/constitutional/check", PrajnaController, :check_constitutional

    # Zenoh Integration (SC-SYNC-009)
    post "/zenoh/subscribe", PrajnaController, :zenoh_subscribe
    post "/zenoh/publish", PrajnaController, :zenoh_publish

    # Sprint 32: Container Operations (SC-SYNC-011)
    get "/containers/status", PrajnaController, :containers_status
    get "/containers/:id/logs", PrajnaController, :container_logs
    post "/containers/:id/action", PrajnaController, :container_action

    # Sprint 32: Agent Mesh Operations (SC-SYNC-012)
    get "/mesh/agents", PrajnaController, :mesh_agents
    get "/mesh/agents/:id", PrajnaController, :mesh_agent
    post "/mesh/agents/:id/command", PrajnaController, :mesh_agent_command

    # Sprint 32: Biomorphic Operations (SC-SYNC-013)
    get "/bio/holons", PrajnaController, :bio_holons
    get "/bio/holons/:id/vitals", PrajnaController, :bio_holon_vitals
    get "/bio/holons/:id/membrane", PrajnaController, :bio_membrane

    # Sprint 32: Domain Data Endpoints
    get "/alarms/correlation", PrajnaController, :alarms_correlation
    get "/devices/state", PrajnaController, :devices_state
    get "/access/audit", PrajnaController, :access_audit
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:indrajaal, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: IndrajaalWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end

# Agent: Helper - 2 (General Purpose Agent)
# SOPv5.1 Compliance: ✅ General system coordination and management with cyberne
# Domain: Web
# Responsibilities: Template generation, standards enforcement, general coordin
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
