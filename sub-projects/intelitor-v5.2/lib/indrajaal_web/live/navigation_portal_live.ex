defmodule IndrajaalWeb.NavigationPortalLive do
  @moduledoc """
  System Navigation Portal — comprehensive entry point for ALL web UI applications.

  Provides categorized navigation to every route in the system, grouped by domain.
  Implements SC-HMI-001 Dark Cockpit compliance with semantic color classes.

  ## STAMP Constraints
  - SC-HMI-001: Dark Cockpit theme (semantic colors only)
  - SC-HMI-008: Theme-aware rendering
  - SC-PORTAL-001: Root page MUST link to ALL routes defined in router.ex
  - SC-PORTAL-002: All linked routes MUST return HTTP 200 for release
  """

  use IndrajaalWeb, :live_view
  import IndrajaalWeb.PrajnaComponents

  @version "v21.3.0-SIL6"

  # --- Elixir Service Architecture Map ---
  @service_planes [
    %{
      name: "Data Plane",
      accent: "border-teal-500",
      icon: "hero-circle-stack",
      description: "Authoritative storage substrate",
      services: [
        %{
          name: "PostgreSQL 17",
          type: "Database",
          runtime: "indrajaal-db-prod",
          role: "Primary transactional storage for 19 Ash domains"
        },
        %{
          name: "TimescaleDB",
          type: "Extension",
          runtime: "indrajaal-db-prod",
          role: "Time-series storage for Alarms/Metrics"
        },
        %{
          name: "SMRITI SQLite",
          type: "Local DB",
          runtime: "BEAM / F#",
          role: "Real-time holon state (OLTP) — authoritative source of truth"
        },
        %{
          name: "SMRITI DuckDB",
          type: "Analytical DB",
          runtime: "BEAM / F#",
          role: "Columnar evolution history and analytics"
        },
        %{
          name: "Redis",
          type: "Cache",
          runtime: "indrajaal-ex-app-1",
          role: "Distributed session state and PubSub buffer"
        }
      ]
    },
    %{
      name: "Control Plane",
      accent: "border-indigo-500",
      icon: "hero-signal",
      description: "Zenoh mesh coordination",
      services: [
        %{
          name: "Zenoh Router 1-3",
          type: "Router",
          runtime: "zenoh-router-1..3",
          role: "2oo3 voting mesh for distributed consensus"
        },
        %{
          name: "Zenoh NIF Proxy",
          type: "Rust/NIF",
          runtime: "BEAM (Rustler)",
          role: "Substrate-level safety gate enforcing ProofTokens"
        },
        %{
          name: "CEPAF Bridge",
          type: "F# Service",
          runtime: "cepaf-bridge",
          role: "Orchestration link between Elixir and F#"
        },
        %{
          name: "MCP Server",
          type: "F# Service",
          runtime: "Cepaf.Sentinel.MCP",
          role: "Agent interface for Claude/Gemini AI"
        }
      ]
    },
    %{
      name: "Cognitive Plane",
      accent: "border-purple-500",
      icon: "hero-cpu-chip",
      description: "Cortex & intelligence services",
      services: [
        %{
          name: "Synapse",
          type: "GenServer",
          runtime: "Elixir",
          role: "Central router for AI/ML queries (Local & API)"
        },
        %{
          name: "FastOODA",
          type: "GenServer",
          runtime: "Elixir",
          role: "Real-time sensor processing loop (20ms target)"
        },
        %{
          name: "Drift Monitor",
          type: "GenServer",
          runtime: "Elixir",
          role: "KL Divergence calculation for homeostasis"
        },
        %{
          name: "Homeostasis",
          type: "GenServer",
          runtime: "Elixir",
          role: "Autonomic metabolic regulator (CPU/Memory/Queue)"
        },
        %{
          name: "Vision Holon",
          type: "ML Service",
          runtime: "ml-runner-1..2",
          role: "YOLO-based object/threat detection"
        },
        %{
          name: "Digital Twin",
          type: "F# Holon",
          runtime: "indrajaal-chaya",
          role: "Predictive shadow simulation of the mesh"
        }
      ]
    },
    %{
      name: "Safety & Immune Plane",
      accent: "border-red-500",
      icon: "hero-shield-exclamation",
      description: "The Simplex Kernel",
      services: [
        %{
          name: "Guardian",
          type: "GenServer",
          runtime: "Elixir",
          role: "Deterministic Safety Kernel; vetoes unsafe mutations"
        },
        %{
          name: "Sentinel",
          type: "GenServer",
          runtime: "Elixir",
          role: "Active threat hunter; quarantine and antibodies"
        },
        %{
          name: "Consensus Aggregator",
          type: "GenServer",
          runtime: "Elixir",
          role: "Unifies Elixir and F# integrity metrics"
        },
        %{
          name: "Prometheus Verifier",
          type: "Module",
          runtime: "Elixir",
          role: "Cryptographic ProofToken generator and DAG auditor"
        }
      ]
    }
  ]

  # --- F# CEPAF Substrate Map ---
  @fsharp_groups [
    %{
      name: "Core Orchestration & Lifecycle",
      accent: "border-orange-500",
      icon: "hero-rocket-launch",
      projects: [
        %{
          name: "Cepaf",
          role: "Primary Mesh Orchestrator",
          modules: "PanopticonOrchestrator, ServiceDAG, ChainVerifier, AOREngine"
        },
        %{
          name: "Cepaf.Podman",
          role: "Container Substrate Driver",
          modules: "PodmanClient, VolumeManager, NetworkEnforcer"
        },
        %{
          name: "Cepaf.Config",
          role: "Distributed Configuration",
          modules: "ComposeGenerator, MeshConfig, ConfigBridge"
        },
        %{
          name: "Cepaf.Bridge",
          role: "Elixir-F# RPC Link",
          modules: "Server, PortHandler, JsonRpc"
        }
      ]
    },
    %{
      name: "Planning & Evolution",
      accent: "border-lime-500",
      icon: "hero-beaker",
      projects: [
        %{
          name: "Cepaf.Planning",
          role: "Authoritative Task Substrate",
          modules: "Manager, Repository, EvolutionObservability, SafetyKernel"
        },
        %{
          name: "Cepaf.Evolution.Service",
          role: "Morphogenic Analytics",
          modules: "MutationTracker, DriftAnalyzer"
        },
        %{
          name: "Cepaf.GitIntelligence",
          role: "Mutation Lineage",
          modules: "Provenance, CommitSigner, LineageAudit"
        }
      ]
    },
    %{
      name: "HMI & Cockpit",
      accent: "border-sky-500",
      icon: "hero-tv",
      projects: [
        %{
          name: "Cepaf.Cockpit",
          role: "Unified UI Logic",
          modules: "DarkCockpitUI, SituationalAwareness, AiCopilot, SmartMetrics"
        },
        %{
          name: "Cepaf.Cockpit.Avalonia",
          role: "Cross-Platform Desktop GUI",
          modules: "App, MainWindow, ViewDispatcher"
        },
        %{
          name: "Cepaf.Cockpit.CLI",
          role: "TUI / Command-Line HMI",
          modules: "PanopticonTui, CommandParser"
        },
        %{
          name: "Cepaf.Sentinel.MCP",
          role: "Agent Control Plane",
          modules: "ZenohTools, EvolutionTools, McpProtocol"
        }
      ]
    },
    %{
      name: "Knowledge & SMRITI (L7)",
      accent: "border-fuchsia-500",
      icon: "hero-academic-cap",
      projects: [
        %{
          name: "Cepaf.Smriti.Semantic",
          role: "Fractal Knowledge Engine",
          modules: "VectorSimilarity, TripleStore, QueryEngine, VirtualGraph"
        },
        %{
          name: "Cepaf.Knowledge",
          role: "Knowledge Graph Ingest",
          modules: "ZettelParser, LinkResolver"
        },
        %{name: "Cepaf.Holon", role: "State Serialization", modules: "HolonStore, VersionVector"},
        %{
          name: "Semantic.Bridge",
          role: "Auxiliary SMRITI Bridge",
          modules: "ZettelProcessor, VectorSearch"
        },
        %{
          name: "Cepaf.Immune",
          role: "F# Digital Immune System",
          modules: "Mara (Chaos engineering & recovery)"
        }
      ]
    }
  ]

  # --- Infrastructure & Observability Endpoints ---
  @infra_endpoints [
    %{name: "Phoenix (Main App)", port: 4000, path: "/", desc: "Primary HMI — this portal"},
    %{
      name: "Health Server",
      port: 4001,
      path: "/health",
      desc: "Bandit liveness probe (FoundationSupervisor)"
    },
    %{
      name: "Digital Twin (Chaya)",
      port: 4002,
      path: "/",
      desc: "Shadow simulation of mesh health"
    },
    %{
      name: "Grafana / SigNoz",
      port: 3000,
      path: "/",
      desc: "Distributed traces and quantitative metrics"
    },
    %{name: "Prometheus", port: 9090, path: "/", desc: "Time-series query interface and alerts"},
    %{name: "Loki", port: 3100, path: "/", desc: "Distributed log exploration"},
    %{name: "Zenoh Control", port: 8000, path: "/", desc: "Mesh topology and link metrics"},
    %{
      name: "OTEL Collector (gRPC)",
      port: 4317,
      path: nil,
      desc: "OpenTelemetry trace ingestion"
    },
    %{name: "OTEL Collector (HTTP)", port: 4318, path: nil, desc: "OpenTelemetry metric push"},
    %{name: "PostgreSQL", port: 5433, path: nil, desc: "Primary database (psql access)"},
    %{name: "Zenoh Router", port: 7447, path: nil, desc: "Mesh control plane (2oo3 quorum)"},
    %{name: "Redis", port: 6379, path: nil, desc: "Session cache and PubSub buffer"}
  ]

  @route_categories [
    %{
      name: "C3I Cockpit",
      icon: "hero-command-line",
      accent: "border-blue-500",
      description: "Command, Control, Communications & Intelligence",
      routes: [
        %{path: "/cockpit", label: "Dashboard", desc: "Command center overview"},
        %{path: "/cockpit/dashboard", label: "Main Dashboard", desc: "Primary operational view"},
        %{path: "/cockpit/startup", label: "Startup", desc: "Boot sequence monitor"},
        %{path: "/cockpit/containers", label: "Containers", desc: "15-container mesh status"},
        %{path: "/cockpit/commands", label: "Commands", desc: "Command dispatch console"},
        %{path: "/cockpit/mesh", label: "Mesh", desc: "Zenoh mesh topology"},
        %{path: "/cockpit/alarms", label: "Alarms", desc: "Alarm processing pipeline"},
        %{path: "/cockpit/ai-copilot", label: "AI Copilot", desc: "Founder's AI assistant"},
        %{path: "/cockpit/cluster", label: "Cluster", desc: "Node cluster management"},
        %{path: "/cockpit/settings", label: "Settings", desc: "System configuration"},
        %{path: "/cockpit/diagnostics", label: "Diagnostics", desc: "System diagnostics"},
        %{path: "/cockpit/test-evolution", label: "Test Evolution", desc: "TDG test cockpit"},
        %{path: "/cockpit/shutdown", label: "Shutdown", desc: "Graceful shutdown control"},
        %{
          path: "/cockpit/observability",
          label: "Observability",
          desc: "OTEL traces and metrics"
        },
        %{path: "/cockpit/knowledge", label: "Knowledge", desc: "SMRITI knowledge base"},
        %{
          path: "/cockpit/knowledge/developer",
          label: "Knowledge: Dev",
          desc: "Developer knowledge"
        },
        %{
          path: "/cockpit/knowledge/product",
          label: "Knowledge: Product",
          desc: "Product knowledge"
        },
        %{path: "/cockpit/knowledge/sre", label: "Knowledge: SRE", desc: "SRE knowledge"},
        %{path: "/cockpit/sentinel", label: "Sentinel", desc: "Health monitoring dashboard"},
        %{path: "/cockpit/guardian", label: "Guardian", desc: "Constitutional safety gate"},
        %{path: "/cockpit/register", label: "Register", desc: "Immutable state register"},
        %{path: "/cockpit/threat", label: "Threat", desc: "Real-time threat monitor"},
        %{
          path: "/cockpit/health-sparklines",
          label: "Health Sparklines",
          desc: "Health trend visualization"
        },
        %{
          path: "/cockpit/guardian-approval",
          label: "Guardian Approval",
          desc: "Proposal approval queue"
        },
        %{
          path: "/cockpit/git-intelligence",
          label: "Git Intelligence",
          desc: "Git mesh analytics"
        },
        %{
          path: "/cockpit/access-control",
          label: "Access Control",
          desc: "Permission management"
        },
        %{path: "/cockpit/devices", label: "Devices", desc: "Device health matrix"},
        %{path: "/cockpit/video", label: "Video", desc: "Video stream health"},
        %{path: "/cockpit/analytics", label: "Analytics", desc: "Domain analytics"},
        %{path: "/cockpit/compliance", label: "Compliance", desc: "Compliance audit trail"},
        %{
          path: "/cockpit/biomorphic-matrix",
          label: "Biomorphic Matrix",
          desc: "NASA-STD-3000 L0-L7 view"
        },
        %{
          path: "/cockpit/evolution-vectors",
          label: "Evolution Vectors",
          desc: "V1-V4 vector visualization"
        },
        %{path: "/cockpit/homeostasis", label: "Homeostasis", desc: "PID setpoint controls"}
      ]
    },
    %{
      name: "Operations Center",
      icon: "hero-shield-check",
      accent: "border-emerald-500",
      description: "Real-time security operations monitoring and response",
      routes: [
        %{path: "/operations/alarms", label: "Active Alarms", desc: "Live alarm queue"},
        %{path: "/operations/access", label: "Access Dashboard", desc: "Access event monitor"},
        %{path: "/operations/video", label: "Video Wall", desc: "Multi-camera view"},
        %{path: "/operations/dispatch", label: "Dispatch Console", desc: "Guard dispatch"}
      ]
    },
    %{
      name: "Analytics & Monitoring",
      icon: "hero-chart-bar",
      accent: "border-violet-500",
      description: "System metrics, performance analysis, and dashboards",
      routes: [
        %{
          path: "/analytics/stamp-tdg-gde-advanced",
          label: "STAMP/TDG/GDE Advanced",
          desc: "Advanced safety analytics"
        },
        %{
          path: "/analytics/dashboard",
          label: "STAMP/TDG Dashboard",
          desc: "Safety metrics overview"
        },
        %{path: "/monitoring", label: "Monitoring", desc: "System monitoring dashboard"},
        %{path: "/performance", label: "Performance", desc: "Performance optimization"}
      ]
    },
    %{
      name: "Administration",
      icon: "hero-cog-6-tooth",
      accent: "border-amber-500",
      description: "System administration, configuration, and access control",
      routes: [
        %{path: "/admin/permissions", label: "Permissions", desc: "Permission management"},
        %{path: "/admin/access_control", label: "Access Control Monitor", desc: "Access audit"},
        %{path: "/admin/config", label: "Configuration", desc: "System config management"},
        %{path: "/admin/system-status", label: "System Status", desc: "Infrastructure status"},
        %{
          path: "/admin/two-key-override",
          label: "Two-Key Override",
          desc: "Manual safety override"
        },
        %{
          path: "/admin/release-dashboard",
          label: "Release Dashboard",
          desc: "Bicameral release sign-off"
        },
        %{path: "/admin/journal", label: "Journal", desc: "Development journal viewer"}
      ]
    },
    %{
      name: "Health Probes",
      icon: "hero-heart",
      accent: "border-rose-500",
      description: "Kubernetes-compatible health check endpoints",
      routes: [
        %{path: "/healthz", label: "Liveness", desc: "K8s liveness probe"},
        %{path: "/ready", label: "Readiness", desc: "K8s readiness probe"},
        %{path: "/startup", label: "Startup", desc: "K8s startup probe"},
        %{path: "/health", label: "Comprehensive", desc: "Full health report (JSON)"}
      ]
    },
    %{
      name: "Assurance & Verification",
      icon: "hero-check-badge",
      accent: "border-green-500",
      description: "Formal verification results, STAMP audits, and UI verification reports",
      routes: [
        %{
          path: "/analytics/stamp-tdg-gde-advanced",
          label: "Advanced Analytics",
          desc: "STAMP/TDG metrics dashboard"
        },
        %{path: "/monitoring", label: "System Monitor", desc: "Real-time verification metrics"},
        %{path: "/performance", label: "Performance DB", desc: "Substrate benchmark reports"}
      ]
    },
    %{
      name: "API Reference",
      icon: "hero-code-bracket",
      accent: "border-cyan-500",
      description: "REST API endpoints for external integrations",
      routes: [
        %{
          path: "/api/mobile/auth/login",
          label: "Mobile Auth",
          desc: "Mobile authentication API"
        },
        %{
          path: "/api/v1/analytics/stamp-tdg-gde",
          label: "Analytics API",
          desc: "BI analytics endpoints"
        },
        %{path: "/api/v1/health", label: "API Health", desc: "API health check"},
        %{path: "/api/kms/holons", label: "KMS Holons", desc: "Knowledge management API"},
        %{path: "/api/kms/health", label: "KMS Health", desc: "KMS health endpoint"},
        %{
          path: "/api/v1/prajna/sentinel/health",
          label: "Prajna Sentinel",
          desc: "Sentinel health API"
        },
        %{
          path: "/api/v1/prajna/containers/status",
          label: "Prajna Containers",
          desc: "Container status API"
        },
        %{path: "/api/v1/prajna/mesh/agents", label: "Prajna Mesh", desc: "Agent mesh API"}
      ]
    }
  ]

  @impl true
  def mount(_params, _session, socket) do
    node_name =
      try do
        node() |> to_string()
      rescue
        _ -> "standalone"
      end

    total_routes = Enum.reduce(@route_categories, 0, fn cat, acc -> acc + length(cat.routes) end)

    total_services =
      Enum.reduce(@service_planes, 0, fn plane, acc -> acc + length(plane.services) end)

    total_fsharp =
      Enum.reduce(@fsharp_groups, 0, fn group, acc -> acc + length(group.projects) end)

    socket =
      socket
      |> assign(:page_title, "System Navigation Portal")
      |> assign(:route_categories, @route_categories)
      |> assign(:service_planes, @service_planes)
      |> assign(:fsharp_groups, @fsharp_groups)
      |> assign(:infra_endpoints, @infra_endpoints)
      |> assign(:version, @version)
      |> assign(:node_name, node_name)
      |> assign(:total_routes, total_routes)
      |> assign(:total_services, total_services)
      |> assign(:total_fsharp, total_fsharp)
      |> assign(:current_time, DateTime.utc_now())

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- SC-HMI-001: Color Rich compliant navigation portal --%>
    <div class="min-h-screen bg-surface-primary color-rich">
      <%!-- Portal Header --%>
      <div class="border-b border-border-theme-primary bg-surface-secondary px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-4">
            <.product_logo class="h-12 w-12" />
            <div>
              <h1 class="text-2xl font-bold text-content-primary tracking-tight">
                INDRAJAAL
                <span class="text-sm font-normal text-content-secondary ml-2">{@version}</span>
              </h1>
              <p class="text-sm text-content-secondary mt-1">
                System Navigation Portal ·
                <span class="text-accent-primary font-mono text-xs">
                  http://vm-1.tail55d152.ts.net:4000/
                </span>
                <span class="mx-2 text-border-theme-primary">|</span>
                Node: <span class="text-content-primary font-mono text-xs">{@node_name}</span>
              </p>
            </div>
          </div>
          <div class="text-right">
            <div class="text-xs text-content-secondary">
              {Calendar.strftime(@current_time, "%Y-%m-%d %H:%M:%S UTC")}
            </div>
            <div class="text-xs text-content-secondary mt-1">
              {@total_routes} routes across {length(@route_categories)} categories
            </div>
          </div>
        </div>
      </div>

      <%!-- Route Category Grid --%>
      <div class="px-6 py-6">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div
            :for={category <- @route_categories}
            class={[
              "rounded-lg bg-surface-secondary border-l-4 overflow-hidden",
              category.accent
            ]}
          >
            <%!-- Category Header --%>
            <div class="px-4 py-3 border-b border-border-theme-primary">
              <div class="flex items-center gap-2">
                <span class={["w-5 h-5 text-content-secondary", category.icon]} />
                <h2 class="text-lg font-semibold text-content-primary">{category.name}</h2>
              </div>
              <p class="text-xs text-content-secondary mt-1">{category.description}</p>
            </div>

            <%!-- Route List --%>
            <div class="divide-y divide-border-theme-primary">
              <.link
                :for={route <- category.routes}
                navigate={route.path}
                class="flex items-center justify-between px-4 py-2 hover:bg-surface-tertiary transition-colors group"
              >
                <div>
                  <span class="text-sm font-medium text-content-primary group-hover:text-accent-primary transition-colors">
                    {route.label}
                  </span>
                  <span class="text-xs text-content-secondary ml-2">{route.desc}</span>
                </div>
                <span class="text-xs font-mono text-content-secondary group-hover:text-accent-primary transition-colors">
                  {route.path}
                </span>
              </.link>
            </div>
          </div>
        </div>
      </div>

      <%!-- Section Divider: Elixir Service Architecture --%>
      <div class="px-6 pt-2 pb-4">
        <div class="border-t border-border-theme-primary pt-6">
          <h2 class="text-lg font-bold text-content-primary mb-1">Elixir Service Architecture</h2>
          <p class="text-xs text-content-secondary mb-4">
            {@total_services} services across {length(@service_planes)} architectural planes
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div
              :for={plane <- @service_planes}
              class={[
                "rounded-lg bg-surface-secondary border-l-4 overflow-hidden",
                plane.accent
              ]}
            >
              <div class="px-4 py-3 border-b border-border-theme-primary">
                <div class="flex items-center gap-2">
                  <span class={["w-5 h-5 text-content-secondary", plane.icon]} />
                  <h3 class="text-lg font-semibold text-content-primary">{plane.name}</h3>
                </div>
                <p class="text-xs text-content-secondary mt-1">{plane.description}</p>
              </div>

              <div class="divide-y divide-border-theme-primary">
                <div :for={svc <- plane.services} class="px-4 py-2">
                  <div class="flex items-center justify-between">
                    <span class="text-sm font-medium text-content-primary">{svc.name}</span>
                    <span class="text-xs font-mono text-accent-primary bg-surface-tertiary px-1.5 py-0.5 rounded">
                      {svc.type}
                    </span>
                  </div>
                  <div class="text-xs text-content-secondary mt-0.5">
                    <span class="font-mono">{svc.runtime}</span>
                    <span class="mx-1">—</span>
                    {svc.role}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Section Divider: F# CEPAF Substrate --%>
      <div class="px-6 pt-2 pb-4">
        <div class="border-t border-border-theme-primary pt-6">
          <h2 class="text-lg font-bold text-content-primary mb-1">F# CEPAF Substrate</h2>
          <p class="text-xs text-content-secondary mb-4">
            {@total_fsharp} F# projects across {length(@fsharp_groups)} groups (net10.0)
          </p>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div
              :for={group <- @fsharp_groups}
              class={[
                "rounded-lg bg-surface-secondary border-l-4 overflow-hidden",
                group.accent
              ]}
            >
              <div class="px-4 py-3 border-b border-border-theme-primary">
                <div class="flex items-center gap-2">
                  <span class={["w-5 h-5 text-content-secondary", group.icon]} />
                  <h3 class="text-lg font-semibold text-content-primary">{group.name}</h3>
                </div>
              </div>

              <div class="divide-y divide-border-theme-primary">
                <div :for={proj <- group.projects} class="px-4 py-2">
                  <div class="flex items-center justify-between">
                    <span class="text-sm font-medium text-content-primary font-mono">
                      {proj.name}
                    </span>
                  </div>
                  <div class="text-xs text-content-secondary mt-0.5">{proj.role}</div>
                  <div class="text-xs text-content-secondary mt-0.5 font-mono opacity-70">
                    {proj.modules}
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Section Divider: Infrastructure & Observability --%>
      <div class="px-6 pt-2 pb-6">
        <div class="border-t border-border-theme-primary pt-6">
          <h2 class="text-lg font-bold text-content-primary mb-1">
            Infrastructure & Observability Endpoints
          </h2>
          <p class="text-xs text-content-secondary mb-4">
            {length(@infra_endpoints)} services across the mesh
          </p>

          <div class="rounded-lg bg-surface-secondary border border-border-theme-primary overflow-hidden">
            <%!-- Table Header --%>
            <div class="grid grid-cols-12 gap-2 px-4 py-2 bg-surface-tertiary border-b border-border-theme-primary text-xs font-semibold text-content-secondary">
              <div class="col-span-4">Service</div>
              <div class="col-span-1 text-center">Port</div>
              <div class="col-span-2">Path</div>
              <div class="col-span-5">Purpose</div>
            </div>

            <%!-- Table Rows --%>
            <div class="divide-y divide-border-theme-primary">
              <div
                :for={ep <- @infra_endpoints}
                class="grid grid-cols-12 gap-2 px-4 py-2 hover:bg-surface-tertiary transition-colors"
              >
                <div class="col-span-4 text-sm font-medium text-content-primary">{ep.name}</div>
                <div class="col-span-1 text-center text-sm font-mono text-accent-primary">
                  {ep.port}
                </div>
                <div class="col-span-2 text-sm font-mono text-content-secondary">
                  {ep.path || "—"}
                </div>
                <div class="col-span-5 text-xs text-content-secondary">{ep.desc}</div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Portal Footer --%>
      <div class="border-t border-border-theme-primary bg-surface-secondary px-6 py-3 text-center">
        <p class="text-xs text-content-secondary">
          Indrajaal {@version} · SIL-6 Biomorphic Fractal Mesh · {@total_routes} routes · {@total_services} services · {@total_fsharp} F# projects · {length(
            @infra_endpoints
          )} infra endpoints ·
          IEC 61508 · ISO 27001 · GDPR · EN 50131
        </p>
      </div>
    </div>
    """
  end
end
