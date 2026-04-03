import gleam/option.{type Option}

/// Shared UI domain types for the triple-interface mandate (SC-GLM-UI-001).
/// ALL Lustre components, Wisp endpoints, and TUI views MUST import from this module.
/// No per-interface type duplication permitted (SC-GLM-UI-009).
///
/// STAMP: SC-GLM-UI-001, SC-GLM-UI-009
/// Represents a c3i page/view that must be rendered across all 3 interfaces.
pub type Page {
  Dashboard
  Planning
  Immune
  Knowledge
  Zenoh
  Cockpit
  Verification
  Substrate
  Metabolic
  Podman
  Mcp
  Kms
  Telemetry
}

/// Health status shared across all interfaces.
pub type HealthStatus {
  Healthy
  Degraded(reason: String)
  Critical(reason: String)
  Unknown
}

/// Telemetry data point — sourced from Zenoh, rendered by all 3 interfaces.
pub type TelemetryPoint {
  TelemetryPoint(key: String, value: Float, timestamp: Int, unit: String)
}

/// Navigation action — same semantics in Web, API, and TUI.
pub type Action {
  Navigate(page: Page)
  Refresh
  Execute(command: String)
  Subscribe(topic: String)
  Unsubscribe(topic: String)
}

/// Rendering context — carries session state for all 3 interfaces.
pub type RenderContext {
  RenderContext(
    page: Page,
    health: HealthStatus,
    telemetry: List(TelemetryPoint),
    zenoh_connected: Bool,
  )
}

/// Convert page to URL path (Wisp routing) and TUI tab name.
pub fn page_to_path(page: Page) -> String {
  case page {
    Dashboard -> "/dashboard"
    Planning -> "/planning"
    Immune -> "/immune"
    Knowledge -> "/knowledge"
    Zenoh -> "/zenoh"
    Cockpit -> "/cockpit"
    Verification -> "/verification"
    Substrate -> "/substrate"
    Metabolic -> "/metabolic"
    Podman -> "/podman"
    Mcp -> "/mcp"
    Kms -> "/kms"
    Telemetry -> "/telemetry"
  }
}

/// Convert page to human-readable label.
pub fn page_to_label(page: Page) -> String {
  case page {
    Dashboard -> "Dashboard"
    Planning -> "Planning"
    Immune -> "Immune System"
    Knowledge -> "Knowledge (Smriti)"
    Zenoh -> "Zenoh Mesh"
    Cockpit -> "Cockpit"
    Verification -> "Verification"
    Substrate -> "Substrate"
    Metabolic -> "Metabolic"
    Podman -> "Podman"
    Mcp -> "MCP Server"
    Kms -> "KMS Catalog"
    Telemetry -> "Telemetry"
  }
}

/// Fractal layer assignment for UI elements.
pub type FractalLayer {
  L0Constitutional
  L1AtomicDebug
  L2Component
  L3Transaction
  L4System
  L5Cognitive
  L6Ecosystem
  L7Federation
}

/// Capabilities a fractal element can have.
pub type Capability {
  EmitEvents
  ReceiveEvents
  ProposeUI
  AcceptHITL
  DelegateToSubAgent
  PersistState
  StreamContent
}

/// Agent binding — connects a UI element to a backend agent.
pub type AgentBinding {
  AgentBinding(
    agent_id: String,
    run_id: Option(String),
    subscribed_topics: List(String),
  )
}

/// Fractal Agentic Element — the atomic unit of the Agentic UI.
/// Every UI element is a holon at a specific fractal layer.
pub type FractalElement {
  FractalElement(
    id: String,
    layer: FractalLayer,
    element_type: String,
    agent_binding: Option(AgentBinding),
    capabilities: List(Capability),
    stamp_controls: List(String),
  )
}

/// Convert fractal layer to string.
pub fn layer_to_string(layer: FractalLayer) -> String {
  case layer {
    L0Constitutional -> "L0_CONSTITUTIONAL"
    L1AtomicDebug -> "L1_ATOMIC_DEBUG"
    L2Component -> "L2_COMPONENT"
    L3Transaction -> "L3_TRANSACTION"
    L4System -> "L4_SYSTEM"
    L5Cognitive -> "L5_COGNITIVE"
    L6Ecosystem -> "L6_ECOSYSTEM"
    L7Federation -> "L7_FEDERATION"
  }
}

/// Convert fractal layer to numeric level.
pub fn layer_level(layer: FractalLayer) -> Int {
  case layer {
    L0Constitutional -> 0
    L1AtomicDebug -> 1
    L2Component -> 2
    L3Transaction -> 3
    L4System -> 4
    L5Cognitive -> 5
    L6Ecosystem -> 6
    L7Federation -> 7
  }
}
