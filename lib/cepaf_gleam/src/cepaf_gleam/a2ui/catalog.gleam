//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity><module>cepaf_gleam/a2ui/catalog</module></identity>
////   <fractal-topology><layer>L2_COMPONENT</layer></fractal-topology>
////   <compliance><stamp-controls>SC-A2UI-002, SC-A2UI-004</stamp-controls></compliance>
//// </c3i-module>
////
//// Trusted component registry — the security boundary for A2UI.
//// Agents can ONLY request components registered in this catalog.
//// STAMP: SC-A2UI-002, SC-A2UI-004

import cepaf_gleam/a2ui/schema.{
  type ComponentSpec, type FractalLayer, BoolProp, ComponentSpec, EnumProp,
  FloatProp, IntProp, JsonProp, L0Constitutional, L1AtomicDebug, L2Component,
  L3Transaction, L4System, L5Cognitive, L6Ecosystem, L7Federation, PropSpec,
  StringProp,
}
import gleam/dict.{type Dict}
import gleam/list
import gleam/result

/// The component catalog — maps type names to specs.
pub type Catalog {
  Catalog(components: Dict(String, ComponentSpec))
}

/// Build the default c3i component catalog with all registered components.
pub fn default_catalog() -> Catalog {
  let components = [
    // L0 Constitutional
    #(
      "alert",
      ComponentSpec(
        "alert",
        L0Constitutional,
        "Safety alert display",
        [
          PropSpec(
            "severity",
            EnumProp(["info", "warning", "error", "critical"]),
            "Alert severity",
          ),
          PropSpec("message", StringProp, "Alert message text"),
        ],
        [PropSpec("dismissable", BoolProp, "Can be dismissed")],
      ),
    ),
    #(
      "modal",
      ComponentSpec(
        "modal",
        L0Constitutional,
        "Modal dialog for HITL approval",
        [
          PropSpec("title", StringProp, "Dialog title"),
          PropSpec("content", StringProp, "Dialog body"),
        ],
        [PropSpec("show_cancel", BoolProp, "Show cancel button")],
      ),
    ),
    #(
      "emergency_stop",
      ComponentSpec(
        "emergency_stop",
        L0Constitutional,
        "Emergency stop button",
        [PropSpec("label", StringProp, "Button label")],
        [],
      ),
    ),
    // L1 Debug
    #(
      "sparkline",
      ComponentSpec(
        "sparkline",
        L1AtomicDebug,
        "Time series sparkline",
        [PropSpec("data", JsonProp, "Array of float values")],
        [
          PropSpec("width", IntProp, "Chart width"),
          PropSpec("color", StringProp, "Line color"),
        ],
      ),
    ),
    // L2 Component
    #(
      "badge",
      ComponentSpec(
        "badge",
        L2Component,
        "Status badge indicator",
        [
          PropSpec("text", StringProp, "Badge text"),
          PropSpec(
            "severity",
            EnumProp(["healthy", "degraded", "critical", "unknown"]),
            "Health severity",
          ),
        ],
        [],
      ),
    ),
    #(
      "button",
      ComponentSpec(
        "button",
        L2Component,
        "Action button",
        [
          PropSpec("label", StringProp, "Button label"),
          PropSpec("action", StringProp, "Action identifier"),
        ],
        [PropSpec("disabled", BoolProp, "Button disabled state")],
      ),
    ),
    // L3 Transaction
    #(
      "data_table",
      ComponentSpec(
        "data_table",
        L3Transaction,
        "Sortable data table",
        [
          PropSpec("columns", JsonProp, "Column definitions"),
          PropSpec("rows", JsonProp, "Row data"),
        ],
        [PropSpec("sortable", BoolProp, "Enable sorting")],
      ),
    ),
    // L4 System
    #(
      "progress",
      ComponentSpec(
        "progress",
        L4System,
        "Progress bar indicator",
        [
          PropSpec("value", FloatProp, "Progress 0.0-1.0"),
          PropSpec("label", StringProp, "Progress label"),
        ],
        [],
      ),
    ),
    #(
      "container_card",
      ComponentSpec(
        "container_card",
        L4System,
        "Container status card",
        [
          PropSpec("name", StringProp, "Container name"),
          PropSpec(
            "status",
            EnumProp(["running", "stopped", "error"]),
            "Container status",
          ),
        ],
        [PropSpec("health", FloatProp, "Health score 0.0-1.0")],
      ),
    ),
    // L5 Cognitive
    #(
      "ooda_ring",
      ComponentSpec(
        "ooda_ring",
        L5Cognitive,
        "OODA cycle ring diagram",
        [
          PropSpec(
            "phase",
            EnumProp(["observe", "orient", "decide", "act", "idle"]),
            "Current phase",
          ),
        ],
        [PropSpec("cycle_ms", IntProp, "Last cycle duration")],
      ),
    ),
    #(
      "reasoning",
      ComponentSpec(
        "reasoning",
        L5Cognitive,
        "Agent reasoning stream",
        [PropSpec("content", StringProp, "Reasoning text")],
        [PropSpec("encrypted", BoolProp, "Is encrypted CoT")],
      ),
    ),
    // L6 Ecosystem
    #(
      "topology",
      ComponentSpec(
        "topology",
        L6Ecosystem,
        "Mesh topology graph",
        [
          PropSpec("nodes", JsonProp, "Node list"),
          PropSpec("edges", JsonProp, "Edge list"),
        ],
        [],
      ),
    ),
    // Operational Control Panels (L0-L7)
    #(
      "action_button",
      ComponentSpec(
        "action_button",
        L2Component,
        "Action button that performs an API call via JS fetch.",
        [
          PropSpec("label", StringProp, "Button label"),
          PropSpec("endpoint", StringProp, "API endpoint to call"),
          PropSpec("payload", StringProp, "JSON string payload to send"),
        ],
        [],
      ),
    ),
    #(
      "card_grid",
      ComponentSpec(
        "card_grid",
        L2Component,
        "Grid layout for cards or buttons",
        [],
        [],
      ),
    ),
    #(
      "section",
      ComponentSpec(
        "section",
        L2Component,
        "Section with a title",
        [
          PropSpec("title", StringProp, "Section title"),
        ],
        [],
      ),
    ),

    // =========================================================================
    // 100 NEW COMPONENTS — SC-ULTRA-001 #4 Homomorphic Tripartite UI
    // =========================================================================
    // --- LAYOUT (14) ---
    #(
      "split_pane",
      ComponentSpec(
        "split_pane",
        L2Component,
        "Resizable two-panel layout",
        [PropSpec("ratio", FloatProp, "Split ratio 0.0-1.0")],
        [],
      ),
    ),
    #(
      "tab_strip",
      ComponentSpec(
        "tab_strip",
        L2Component,
        "Horizontal tab selector",
        [
          PropSpec("tabs", JsonProp, "Tab labels"),
          PropSpec("active", IntProp, "Active index"),
        ],
        [],
      ),
    ),
    #(
      "collapsible_panel",
      ComponentSpec(
        "collapsible_panel",
        L2Component,
        "Expandable/collapsible region",
        [
          PropSpec("title", StringProp, "Panel title"),
          PropSpec("expanded", BoolProp, "Initial state"),
        ],
        [],
      ),
    ),
    #(
      "fractal_breadcrumb",
      ComponentSpec(
        "fractal_breadcrumb",
        L1AtomicDebug,
        "L0-L7 fractal hierarchy breadcrumb",
        [PropSpec("layers", JsonProp, "Active layer path")],
        [],
      ),
    ),
    #(
      "grid_layout",
      ComponentSpec(
        "grid_layout",
        L2Component,
        "Configurable CSS grid layout",
        [
          PropSpec("columns", IntProp, "Column count"),
          PropSpec("gap", IntProp, "Gap pixels"),
        ],
        [],
      ),
    ),
    #(
      "scroll_viewport",
      ComponentSpec(
        "scroll_viewport",
        L2Component,
        "Virtualized scroll container",
        [PropSpec("max_height", IntProp, "Max height")],
        [],
      ),
    ),
    #(
      "sidebar_nav",
      ComponentSpec(
        "sidebar_nav",
        L2Component,
        "Vertical navigation sidebar grouped by layer",
        [],
        [],
      ),
    ),
    #(
      "modal_overlay",
      ComponentSpec(
        "modal_overlay",
        L0Constitutional,
        "Full-screen focus-trapping overlay",
        [PropSpec("visible", BoolProp, "Is visible")],
        [],
      ),
    ),
    #(
      "sticky_footer",
      ComponentSpec(
        "sticky_footer",
        L2Component,
        "Persistent bottom status bar",
        [PropSpec("content", StringProp, "Footer content")],
        [],
      ),
    ),
    #(
      "responsive_columns",
      ComponentSpec(
        "responsive_columns",
        L2Component,
        "Auto-reflowing column layout",
        [PropSpec("min_width", IntProp, "Min column width")],
        [],
      ),
    ),
    #(
      "layer_accordion",
      ComponentSpec(
        "layer_accordion",
        L2Component,
        "Accordion grouped by L0-L7 layers",
        [],
        [],
      ),
    ),
    #(
      "dashboard_tile",
      ComponentSpec(
        "dashboard_tile",
        L2Component,
        "Fixed-ratio dashboard tile",
        [PropSpec("title", StringProp, "Tile title")],
        [],
      ),
    ),
    #(
      "header_bar",
      ComponentSpec(
        "header_bar",
        L2Component,
        "Application header with holon identity",
        [PropSpec("holon_id", StringProp, "Holon identity")],
        [],
      ),
    ),
    #(
      "empty_state",
      ComponentSpec(
        "empty_state",
        L2Component,
        "Empty data placeholder with action",
        [
          PropSpec("message", StringProp, "Message"),
          PropSpec("icon", StringProp, "Icon"),
        ],
        [],
      ),
    ),

    // --- DATA (16) ---
    #(
      "kv_table",
      ComponentSpec(
        "kv_table",
        L3Transaction,
        "Multi-row key-value display",
        [PropSpec("rows", JsonProp, "Key-value pairs")],
        [],
      ),
    ),
    #(
      "log_stream",
      ComponentSpec(
        "log_stream",
        L1AtomicDebug,
        "Scrolling severity-colored log viewer",
        [PropSpec("lines", JsonProp, "Log lines")],
        [PropSpec("max_lines", IntProp, "Max visible")],
      ),
    ),
    #(
      "json_tree",
      ComponentSpec(
        "json_tree",
        L1AtomicDebug,
        "Collapsible JSON object viewer",
        [PropSpec("data", JsonProp, "JSON object")],
        [],
      ),
    ),
    #(
      "triple_row",
      ComponentSpec(
        "triple_row",
        L3Transaction,
        "Subject-predicate-object triple",
        [
          PropSpec("subject", StringProp, "S"),
          PropSpec("predicate", StringProp, "P"),
          PropSpec("object", StringProp, "O"),
        ],
        [],
      ),
    ),
    #(
      "diff_viewer",
      ComponentSpec(
        "diff_viewer",
        L3Transaction,
        "RFC 6902 JSON patch diff viewer",
        [PropSpec("patches", JsonProp, "JSON patches")],
        [],
      ),
    ),
    #(
      "metric_counter",
      ComponentSpec(
        "metric_counter",
        L1AtomicDebug,
        "Large numeric metric with delta arrow",
        [
          PropSpec("value", FloatProp, "Current value"),
          PropSpec("label", StringProp, "Label"),
          PropSpec("unit", StringProp, "Unit"),
        ],
        [PropSpec("delta", FloatProp, "Change")],
      ),
    ),
    #(
      "histogram_bar",
      ComponentSpec(
        "histogram_bar",
        L4System,
        "Horizontal histogram with segments",
        [PropSpec("segments", JsonProp, "Segment data")],
        [],
      ),
    ),
    #(
      "version_vector_row",
      ComponentSpec(
        "version_vector_row",
        L7Federation,
        "Peer version vector display",
        [
          PropSpec("peer_id", StringProp, "Peer"),
          PropSpec("clock", IntProp, "Clock value"),
        ],
        [],
      ),
    ),
    #(
      "hash_display",
      ComponentSpec(
        "hash_display",
        L0Constitutional,
        "Truncated hash with copy and validity",
        [
          PropSpec("hash", StringProp, "Hash value"),
          PropSpec("valid", BoolProp, "Is valid"),
        ],
        [],
      ),
    ),
    #(
      "container_log_tail",
      ComponentSpec(
        "container_log_tail",
        L4System,
        "Tail-follow container log viewer",
        [
          PropSpec("container", StringProp, "Container name"),
          PropSpec("lines", JsonProp, "Log lines"),
        ],
        [],
      ),
    ),
    #(
      "sparql_result_grid",
      ComponentSpec(
        "sparql_result_grid",
        L3Transaction,
        "SPARQL query result table",
        [
          PropSpec("variables", JsonProp, "Variable names"),
          PropSpec("bindings", JsonProp, "Row bindings"),
        ],
        [],
      ),
    ),
    #(
      "event_payload_card",
      ComponentSpec(
        "event_payload_card",
        L5Cognitive,
        "AG-UI event detail card",
        [
          PropSpec("event_type", StringProp, "Event type"),
          PropSpec("payload", JsonProp, "Event payload"),
        ],
        [],
      ),
    ),
    #(
      "latency_gauge",
      ComponentSpec(
        "latency_gauge",
        L5Cognitive,
        "Color-banded latency display",
        [
          PropSpec("value_ms", FloatProp, "Latency ms"),
          PropSpec("budget_ms", FloatProp, "Budget ms"),
        ],
        [],
      ),
    ),
    #(
      "resource_usage_row",
      ComponentSpec(
        "resource_usage_row",
        L4System,
        "CPU/memory/disk usage row",
        [
          PropSpec("cpu", FloatProp, "CPU %"),
          PropSpec("memory", FloatProp, "Memory %"),
        ],
        [PropSpec("disk", FloatProp, "Disk %")],
      ),
    ),
    #(
      "task_detail_pane",
      ComponentSpec(
        "task_detail_pane",
        L3Transaction,
        "Full task detail view",
        [PropSpec("task_id", StringProp, "Task ID")],
        [],
      ),
    ),
    #(
      "proof_token_card",
      ComponentSpec(
        "proof_token_card",
        L0Constitutional,
        "Verification proof token",
        [
          PropSpec("hash", StringProp, "Token hash"),
          PropSpec(
            "result",
            EnumProp(["Verified", "Rejected", "Inconclusive"]),
            "Result",
          ),
        ],
        [],
      ),
    ),

    // --- STATUS (18) ---
    #(
      "health_indicator",
      ComponentSpec(
        "health_indicator",
        L4System,
        "Colored health dot",
        [
          PropSpec(
            "status",
            EnumProp(["healthy", "degraded", "critical", "unknown"]),
            "Status",
          ),
        ],
        [],
      ),
    ),
    #(
      "connection_status",
      ComponentSpec(
        "connection_status",
        L6Ecosystem,
        "Connection indicator with latency",
        [
          PropSpec("connected", BoolProp, "Connected"),
          PropSpec("latency_ms", IntProp, "Latency"),
        ],
        [],
      ),
    ),
    #(
      "cockpit_mode_badge",
      ComponentSpec(
        "cockpit_mode_badge",
        L5Cognitive,
        "Dark cockpit mode display",
        [
          PropSpec(
            "mode",
            EnumProp(["dark", "dim", "normal", "bright", "emergency"]),
            "Mode",
          ),
        ],
        [],
      ),
    ),
    #(
      "quorum_indicator",
      ComponentSpec(
        "quorum_indicator",
        L7Federation,
        "Quorum status display",
        [
          PropSpec("current", IntProp, "Current peers"),
          PropSpec("required", IntProp, "Required peers"),
        ],
        [],
      ),
    ),
    #(
      "boot_phase_tracker",
      ComponentSpec(
        "boot_phase_tracker",
        L4System,
        "7-phase boot progress",
        [
          PropSpec("current_phase", IntProp, "Phase 0-6"),
          PropSpec("phases", JsonProp, "Phase names"),
        ],
        [],
      ),
    ),
    #(
      "threat_level_bar",
      ComponentSpec(
        "threat_level_bar",
        L0Constitutional,
        "Immune threat level indicator",
        [
          PropSpec(
            "level",
            EnumProp(["nominal", "elevated", "critical"]),
            "Level",
          ),
        ],
        [],
      ),
    ),
    #(
      "container_status_dot",
      ComponentSpec(
        "container_status_dot",
        L4System,
        "Single container dot",
        [
          PropSpec("name", StringProp, "Name"),
          PropSpec(
            "status",
            EnumProp(["running", "stopped", "error"]),
            "Status",
          ),
        ],
        [],
      ),
    ),
    #(
      "psi_invariant_row",
      ComponentSpec(
        "psi_invariant_row",
        L0Constitutional,
        "Psi invariant check result",
        [
          PropSpec("name", StringProp, "Psi-N"),
          PropSpec("passed", BoolProp, "Passed"),
          PropSpec("detail", StringProp, "Detail"),
        ],
        [],
      ),
    ),
    #(
      "sil_compliance_badge",
      ComponentSpec(
        "sil_compliance_badge",
        L0Constitutional,
        "SIL-6 compliance badge",
        [
          PropSpec("level", StringProp, "SIL level"),
          PropSpec("verified", BoolProp, "Verified"),
        ],
        [],
      ),
    ),
    #(
      "circuit_breaker_status",
      ComponentSpec(
        "circuit_breaker_status",
        L6Ecosystem,
        "Circuit breaker state",
        [PropSpec("state", EnumProp(["closed", "open", "half_open"]), "State")],
        [],
      ),
    ),
    #(
      "mara_status",
      ComponentSpec(
        "mara_status",
        L0Constitutional,
        "Chaos engineering daemon status",
        [
          PropSpec("running", BoolProp, "Is running"),
          PropSpec("attack_count", IntProp, "Attacks run"),
        ],
        [],
      ),
    ),
    #(
      "agent_heartbeat",
      ComponentSpec(
        "agent_heartbeat",
        L5Cognitive,
        "Agent heartbeat indicator",
        [
          PropSpec("agent_id", StringProp, "Agent"),
          PropSpec("last_seen", StringProp, "Timestamp"),
        ],
        [],
      ),
    ),
    #(
      "sync_status_icon",
      ComponentSpec(
        "sync_status_icon",
        L7Federation,
        "Federation sync state per peer",
        [
          PropSpec(
            "state",
            EnumProp(["in_sync", "behind", "ahead", "conflict"]),
            "Sync state",
          ),
        ],
        [],
      ),
    ),
    #(
      "entropy_score",
      ComponentSpec(
        "entropy_score",
        L5Cognitive,
        "Shannon entropy H display",
        [
          PropSpec("value", FloatProp, "Entropy bits"),
          PropSpec("threshold", FloatProp, "Gate threshold"),
        ],
        [],
      ),
    ),
    #(
      "test_suite_status",
      ComponentSpec(
        "test_suite_status",
        L1AtomicDebug,
        "Test suite passed/failed/skipped",
        [
          PropSpec("passed", IntProp, "Passed"),
          PropSpec("failed", IntProp, "Failed"),
          PropSpec("skipped", IntProp, "Skipped"),
        ],
        [],
      ),
    ),
    #(
      "cognitive_load_meter",
      ComponentSpec(
        "cognitive_load_meter",
        L5Cognitive,
        "HMI cognitive load estimate",
        [
          PropSpec(
            "level",
            EnumProp(["low", "medium", "high", "overload"]),
            "Load level",
          ),
        ],
        [],
      ),
    ),
    #(
      "dag_integrity_badge",
      ComponentSpec(
        "dag_integrity_badge",
        L1AtomicDebug,
        "DAG validity check badge",
        [
          PropSpec("nodes", IntProp, "Nodes"),
          PropSpec("edges", IntProp, "Edges"),
          PropSpec("acyclic", BoolProp, "Is acyclic"),
        ],
        [],
      ),
    ),
    #(
      "mesh_mode_indicator",
      ComponentSpec(
        "mesh_mode_indicator",
        L6Ecosystem,
        "MeshMode display",
        [
          PropSpec(
            "mode",
            EnumProp(["standalone", "clustered", "federated"]),
            "Mode",
          ),
        ],
        [],
      ),
    ),

    // --- INTERACTIVE (16) ---
    #(
      "filter_bar",
      ComponentSpec(
        "filter_bar",
        L2Component,
        "Horizontal filter chip bar",
        [
          PropSpec("options", JsonProp, "Filter options"),
          PropSpec("selected", JsonProp, "Active filters"),
        ],
        [],
      ),
    ),
    #(
      "search_input",
      ComponentSpec(
        "search_input",
        L2Component,
        "Debounced text search input",
        [PropSpec("placeholder", StringProp, "Placeholder text")],
        [],
      ),
    ),
    #(
      "confirm_dialog",
      ComponentSpec(
        "confirm_dialog",
        L0Constitutional,
        "Two-button approve/reject dialog",
        [
          PropSpec("title", StringProp, "Title"),
          PropSpec("message", StringProp, "Message"),
        ],
        [],
      ),
    ),
    #(
      "toggle_switch",
      ComponentSpec(
        "toggle_switch",
        L2Component,
        "Boolean on/off toggle",
        [
          PropSpec("label", StringProp, "Label"),
          PropSpec("value", BoolProp, "Current state"),
        ],
        [],
      ),
    ),
    #(
      "dropdown_select",
      ComponentSpec(
        "dropdown_select",
        L2Component,
        "Single-value dropdown",
        [
          PropSpec("options", JsonProp, "Options"),
          PropSpec("selected", StringProp, "Current value"),
        ],
        [],
      ),
    ),
    #(
      "command_palette",
      ComponentSpec(
        "command_palette",
        L5Cognitive,
        "Keyboard command palette (Ctrl+K)",
        [],
        [],
      ),
    ),
    #(
      "threshold_slider",
      ComponentSpec(
        "threshold_slider",
        L2Component,
        "Numeric range slider",
        [
          PropSpec("min", FloatProp, "Min"),
          PropSpec("max", FloatProp, "Max"),
          PropSpec("value", FloatProp, "Current"),
        ],
        [],
      ),
    ),
    #(
      "bulk_action_bar",
      ComponentSpec(
        "bulk_action_bar",
        L4System,
        "Multi-select batch action bar",
        [PropSpec("actions", JsonProp, "Available actions")],
        [],
      ),
    ),
    #(
      "topic_subscribe_btn",
      ComponentSpec(
        "topic_subscribe_btn",
        L6Ecosystem,
        "Zenoh topic subscribe toggle",
        [
          PropSpec("topic", StringProp, "Topic key expression"),
          PropSpec("subscribed", BoolProp, "Is subscribed"),
        ],
        [],
      ),
    ),
    #(
      "refresh_button",
      ComponentSpec(
        "refresh_button",
        L2Component,
        "Manual refresh trigger",
        [PropSpec("loading", BoolProp, "Is loading")],
        [],
      ),
    ),
    #(
      "pagination_controls",
      ComponentSpec(
        "pagination_controls",
        L2Component,
        "Previous/next page controls",
        [
          PropSpec("page", IntProp, "Current page"),
          PropSpec("total", IntProp, "Total pages"),
        ],
        [],
      ),
    ),
    #(
      "sort_header",
      ComponentSpec(
        "sort_header",
        L3Transaction,
        "Sortable column header",
        [
          PropSpec("label", StringProp, "Column label"),
          PropSpec(
            "direction",
            EnumProp(["asc", "desc", "none"]),
            "Sort direction",
          ),
        ],
        [],
      ),
    ),
    #(
      "copy_button",
      ComponentSpec(
        "copy_button",
        L2Component,
        "Copy-to-clipboard button",
        [PropSpec("value", StringProp, "Value to copy")],
        [],
      ),
    ),
    #(
      "two_key_release",
      ComponentSpec(
        "two_key_release",
        L0Constitutional,
        "Bicameral two-key sign-off",
        [
          PropSpec("key1_signed", BoolProp, "Key 1"),
          PropSpec("key2_signed", BoolProp, "Key 2"),
        ],
        [],
      ),
    ),
    #(
      "chaos_inject_btn",
      ComponentSpec(
        "chaos_inject_btn",
        L0Constitutional,
        "Chaos attack injection button",
        [
          PropSpec(
            "attack_type",
            EnumProp(["kill", "partition", "cpu_spike", "memory_leak"]),
            "Attack type",
          ),
        ],
        [],
      ),
    ),
    #(
      "time_range_picker",
      ComponentSpec(
        "time_range_picker",
        L2Component,
        "Start/end time selector",
        [
          PropSpec("start", StringProp, "Start time"),
          PropSpec("end", StringProp, "End time"),
        ],
        [],
      ),
    ),

    // --- VISUALIZATION (20) ---
    #(
      "container_grid_16",
      ComponentSpec(
        "container_grid_16",
        L4System,
        "4x4 grid of 16 container dots",
        [PropSpec("containers", JsonProp, "Container statuses")],
        [],
      ),
    ),
    #(
      "ooda_waterfall",
      ComponentSpec(
        "ooda_waterfall",
        L5Cognitive,
        "OODA cycle waterfall chart",
        [PropSpec("cycles", JsonProp, "Cycle durations")],
        [],
      ),
    ),
    #(
      "trace_flamegraph",
      ComponentSpec(
        "trace_flamegraph",
        L1AtomicDebug,
        "OTel span flamegraph",
        [
          PropSpec("trace_id", StringProp, "Trace ID"),
          PropSpec("spans", JsonProp, "Span data"),
        ],
        [],
      ),
    ),
    #(
      "span_gantt_chart",
      ComponentSpec(
        "span_gantt_chart",
        L1AtomicDebug,
        "Concurrent span Gantt chart",
        [
          PropSpec("spans", JsonProp, "Span data"),
          PropSpec("time_range_ms", IntProp, "Window ms"),
        ],
        [],
      ),
    ),
    #(
      "peer_ring",
      ComponentSpec(
        "peer_ring",
        L7Federation,
        "Circular federation peer ring",
        [
          PropSpec("peers", JsonProp, "Peer data"),
          PropSpec("attestations", JsonProp, "Attestation edges"),
        ],
        [],
      ),
    ),
    #(
      "antibody_list",
      ComponentSpec(
        "antibody_list",
        L0Constitutional,
        "Immune antibody list",
        [PropSpec("antibodies", JsonProp, "Antibody list")],
        [],
      ),
    ),
    #(
      "attack_timeline",
      ComponentSpec(
        "attack_timeline",
        L0Constitutional,
        "Chaos attack timeline",
        [PropSpec("attacks", JsonProp, "Attack events")],
        [],
      ),
    ),
    #(
      "knowledge_graph_mini",
      ComponentSpec(
        "knowledge_graph_mini",
        L3Transaction,
        "Mini knowledge graph viz",
        [PropSpec("triples", JsonProp, "SPO triples")],
        [],
      ),
    ),
    #(
      "pid_control_plot",
      ComponentSpec(
        "pid_control_plot",
        L2Component,
        "PID controller time series",
        [
          PropSpec("setpoint", FloatProp, "Set point"),
          PropSpec("actual", FloatProp, "Actual"),
          PropSpec("error", FloatProp, "Error"),
        ],
        [],
      ),
    ),
    #(
      "version_clock_ring",
      ComponentSpec(
        "version_clock_ring",
        L7Federation,
        "Version vector clock ring",
        [PropSpec("peers", JsonProp, "Peer clocks")],
        [],
      ),
    ),
    #(
      "event_frequency_heatmap",
      ComponentSpec(
        "event_frequency_heatmap",
        L5Cognitive,
        "AG-UI event frequency grid",
        [PropSpec("data", JsonProp, "Frequency matrix")],
        [],
      ),
    ),
    #(
      "task_kanban_board",
      ComponentSpec(
        "task_kanban_board",
        L3Transaction,
        "4-column task kanban",
        [PropSpec("tasks", JsonProp, "Task list")],
        [],
      ),
    ),
    #(
      "dependency_dag",
      ComponentSpec(
        "dependency_dag",
        L3Transaction,
        "Task dependency graph",
        [
          PropSpec("nodes", JsonProp, "Nodes"),
          PropSpec("edges", JsonProp, "Edges"),
        ],
        [],
      ),
    ),
    #(
      "reconciliation_diff",
      ComponentSpec(
        "reconciliation_diff",
        L7Federation,
        "Federation reconciliation diff",
        [PropSpec("entries", JsonProp, "Diff entries")],
        [],
      ),
    ),
    #(
      "router_topology_mini",
      ComponentSpec(
        "router_topology_mini",
        L6Ecosystem,
        "3-node router triangle",
        [PropSpec("routers", JsonProp, "Router statuses")],
        [],
      ),
    ),
    #(
      "metric_time_series",
      ComponentSpec(
        "metric_time_series",
        L1AtomicDebug,
        "Multi-line time series chart",
        [
          PropSpec("series", JsonProp, "Series data"),
          PropSpec("labels", JsonProp, "Series labels"),
        ],
        [],
      ),
    ),
    #(
      "hash_chain_strip",
      ComponentSpec(
        "hash_chain_strip",
        L0Constitutional,
        "Horizontal hash chain visualization",
        [PropSpec("blocks", JsonProp, "Hash blocks")],
        [],
      ),
    ),
    #(
      "layer_sunburst",
      ComponentSpec(
        "layer_sunburst",
        L2Component,
        "L0-L7 concentric ring chart",
        [PropSpec("layers", JsonProp, "Layer data")],
        [],
      ),
    ),
    #(
      "evolution_radar",
      ComponentSpec(
        "evolution_radar",
        L5Cognitive,
        "4-axis evolution radar chart",
        [PropSpec("vectors", JsonProp, "V1-V4 values")],
        [],
      ),
    ),
    #(
      "coverage_gauge_ring",
      ComponentSpec(
        "coverage_gauge_ring",
        L1AtomicDebug,
        "Donut gauge for coverage metric",
        [
          PropSpec("value", FloatProp, "Coverage 0.0-1.0"),
          PropSpec("label", StringProp, "Metric name"),
        ],
        [],
      ),
    ),

    // --- AGENT (10) ---
    #(
      "agent_run_card",
      ComponentSpec(
        "agent_run_card",
        L5Cognitive,
        "Active agent run card",
        [
          PropSpec("run_id", StringProp, "Run ID"),
          PropSpec("step_count", IntProp, "Steps"),
          PropSpec("elapsed_ms", IntProp, "Elapsed"),
        ],
        [],
      ),
    ),
    #(
      "tool_call_panel",
      ComponentSpec(
        "tool_call_panel",
        L5Cognitive,
        "In-flight tool call panel",
        [
          PropSpec("tool_name", StringProp, "Tool"),
          PropSpec(
            "status",
            EnumProp(["pending", "running", "completed", "failed"]),
            "Status",
          ),
        ],
        [],
      ),
    ),
    #(
      "reasoning_stream",
      ComponentSpec(
        "reasoning_stream",
        L5Cognitive,
        "Real-time reasoning text",
        [
          PropSpec("content", StringProp, "Text"),
          PropSpec("encrypted", BoolProp, "Encrypted CoT"),
        ],
        [],
      ),
    ),
    #(
      "sse_connection_indicator",
      ComponentSpec(
        "sse_connection_indicator",
        L6Ecosystem,
        "SSE connection badge",
        [
          PropSpec("connected", BoolProp, "Connected"),
          PropSpec("reconnect_count", IntProp, "Reconnects"),
        ],
        [],
      ),
    ),
    #(
      "agent_hierarchy_tree",
      ComponentSpec(
        "agent_hierarchy_tree",
        L5Cognitive,
        "5-tier agent hierarchy",
        [
          PropSpec("cortex", IntProp, "Cortex count"),
          PropSpec("intelligence", IntProp, "Intelligence"),
          PropSpec("workers", IntProp, "Workers"),
        ],
        [],
      ),
    ),
    #(
      "hitl_pending_queue",
      ComponentSpec(
        "hitl_pending_queue",
        L0Constitutional,
        "HITL approval request queue",
        [PropSpec("requests", JsonProp, "Pending requests")],
        [],
      ),
    ),
    #(
      "activity_feed",
      ComponentSpec(
        "activity_feed",
        L5Cognitive,
        "AG-UI activity event feed",
        [PropSpec("events", JsonProp, "Activity events")],
        [],
      ),
    ),
    #(
      "state_inspector",
      ComponentSpec(
        "state_inspector",
        L5Cognitive,
        "AG-UI SharedState viewer",
        [PropSpec("state", JsonProp, "Current state")],
        [],
      ),
    ),
    #(
      "message_thread",
      ComponentSpec(
        "message_thread",
        L5Cognitive,
        "AG-UI text message thread",
        [PropSpec("messages", JsonProp, "Message list")],
        [],
      ),
    ),
    #(
      "agent_capability_badges",
      ComponentSpec(
        "agent_capability_badges",
        L5Cognitive,
        "Agent capability badge row",
        [PropSpec("capabilities", JsonProp, "Capability list")],
        [],
      ),
    ),

    // --- SAFETY (6) ---
    #(
      "guardian_approval_panel",
      ComponentSpec(
        "guardian_approval_panel",
        L0Constitutional,
        "Full Guardian approval workflow",
        [
          PropSpec("request_id", StringProp, "Request ID"),
          PropSpec("action", StringProp, "Requested action"),
        ],
        [],
      ),
    ),
    #(
      "psi_invariant_dashboard",
      ComponentSpec(
        "psi_invariant_dashboard",
        L0Constitutional,
        "All Psi invariants grid",
        [PropSpec("results", JsonProp, "Check results")],
        [],
      ),
    ),
    #(
      "emergency_banner",
      ComponentSpec(
        "emergency_banner",
        L0Constitutional,
        "Full-width emergency banner",
        [PropSpec("message", StringProp, "Emergency message")],
        [],
      ),
    ),
    #(
      "constitutional_hash_chain",
      ComponentSpec(
        "constitutional_hash_chain",
        L0Constitutional,
        "Constitution hash chain display",
        [PropSpec("chain", JsonProp, "Chain blocks")],
        [],
      ),
    ),
    #(
      "audit_trail_log",
      ComponentSpec(
        "audit_trail_log",
        L0Constitutional,
        "Immutable audit log viewer",
        [PropSpec("entries", JsonProp, "Audit entries")],
        [],
      ),
    ),
    #(
      "sil6_compliance_matrix",
      ComponentSpec(
        "sil6_compliance_matrix",
        L0Constitutional,
        "STAMP control verification matrix",
        [PropSpec("controls", JsonProp, "Control statuses")],
        [],
      ),
    ),

    // =========================================================================
    // WAVE 2: 100 SPECIALIZED DOMAIN COMPONENTS (Total: 215)
    // =========================================================================
    // --- REAL-TIME MONITORS (15) ---
    #(
      "cpu_governor_gauge",
      ComponentSpec(
        "cpu_governor_gauge",
        L4System,
        "Adaptive CPU governor with 85% hard limit display",
        [
          PropSpec("cpu_pct", FloatProp, "Current CPU %"),
          PropSpec(
            "mode",
            EnumProp(["full_speed", "slight", "moderate", "heavy", "wait"]),
            "Governor mode",
          ),
        ],
        [],
      ),
    ),
    #(
      "memory_pressure_bar",
      ComponentSpec(
        "memory_pressure_bar",
        L4System,
        "System memory pressure with OOM distance",
        [
          PropSpec("used_mb", IntProp, "Used MB"),
          PropSpec("total_mb", IntProp, "Total MB"),
        ],
        [],
      ),
    ),
    #(
      "disk_io_sparkline",
      ComponentSpec(
        "disk_io_sparkline",
        L4System,
        "Disk I/O read/write sparkline pair",
        [
          PropSpec("read_iops", JsonProp, "Read IOPS history"),
          PropSpec("write_iops", JsonProp, "Write IOPS history"),
        ],
        [],
      ),
    ),
    #(
      "network_throughput",
      ComponentSpec(
        "network_throughput",
        L6Ecosystem,
        "Network bytes in/out per second",
        [
          PropSpec("rx_bps", IntProp, "Receive bps"),
          PropSpec("tx_bps", IntProp, "Transmit bps"),
        ],
        [],
      ),
    ),
    #(
      "beam_scheduler_load",
      ComponentSpec(
        "beam_scheduler_load",
        L4System,
        "BEAM VM scheduler utilization per core",
        [PropSpec("schedulers", JsonProp, "Scheduler loads")],
        [],
      ),
    ),
    #(
      "nif_latency_histogram",
      ComponentSpec(
        "nif_latency_histogram",
        L1AtomicDebug,
        "NIF call latency distribution (p50/p95/p99)",
        [
          PropSpec("p50_us", IntProp, "p50 microseconds"),
          PropSpec("p95_us", IntProp, "p95"),
          PropSpec("p99_us", IntProp, "p99"),
        ],
        [],
      ),
    ),
    #(
      "sqlite_wal_status",
      ComponentSpec(
        "sqlite_wal_status",
        L3Transaction,
        "SQLite WAL checkpoint status and size",
        [
          PropSpec("wal_pages", IntProp, "WAL pages"),
          PropSpec("checkpointed", BoolProp, "Recently checkpointed"),
        ],
        [],
      ),
    ),
    #(
      "gc_pressure_indicator",
      ComponentSpec(
        "gc_pressure_indicator",
        L4System,
        "BEAM garbage collection pressure",
        [
          PropSpec("minor_gcs", IntProp, "Minor GCs/s"),
          PropSpec("major_gcs", IntProp, "Major GCs/s"),
        ],
        [],
      ),
    ),
    #(
      "process_count_gauge",
      ComponentSpec(
        "process_count_gauge",
        L4System,
        "BEAM process count with limit",
        [
          PropSpec("count", IntProp, "Active processes"),
          PropSpec("limit", IntProp, "Max processes"),
        ],
        [],
      ),
    ),
    #(
      "message_queue_depth",
      ComponentSpec(
        "message_queue_depth",
        L4System,
        "Longest BEAM message queue",
        [
          PropSpec("max_depth", IntProp, "Deepest queue"),
          PropSpec("pid", StringProp, "Process with deepest"),
        ],
        [],
      ),
    ),
    #(
      "ets_table_monitor",
      ComponentSpec(
        "ets_table_monitor",
        L3Transaction,
        "ETS table size and memory monitor",
        [
          PropSpec("table_name", StringProp, "Table"),
          PropSpec("size", IntProp, "Entries"),
          PropSpec("memory_bytes", IntProp, "Memory"),
        ],
        [],
      ),
    ),
    #(
      "dirty_scheduler_load",
      ComponentSpec(
        "dirty_scheduler_load",
        L4System,
        "Dirty CPU/IO scheduler utilization",
        [
          PropSpec("dirty_cpu_pct", FloatProp, "Dirty CPU %"),
          PropSpec("dirty_io_pct", FloatProp, "Dirty IO %"),
        ],
        [],
      ),
    ),
    #(
      "zenoh_topic_rate",
      ComponentSpec(
        "zenoh_topic_rate",
        L6Ecosystem,
        "Per-topic message rate meter",
        [
          PropSpec("topic", StringProp, "Key expression"),
          PropSpec("msgs_per_sec", FloatProp, "Message rate"),
        ],
        [],
      ),
    ),
    #(
      "otel_export_status",
      ComponentSpec(
        "otel_export_status",
        L1AtomicDebug,
        "OTel collector export success/failure rate",
        [
          PropSpec("exported", IntProp, "Exported spans"),
          PropSpec("failed", IntProp, "Failed exports"),
        ],
        [],
      ),
    ),
    #(
      "heartbeat_monitor",
      ComponentSpec(
        "heartbeat_monitor",
        L6Ecosystem,
        "Per-node heartbeat with staleness detection",
        [
          PropSpec("node_id", StringProp, "Node"),
          PropSpec("last_heartbeat_ms", IntProp, "Last seen"),
          PropSpec("stale", BoolProp, "Is stale"),
        ],
        [],
      ),
    ),

    // --- ZENOH MESH SPECIFIC (10) ---
    #(
      "key_expression_viewer",
      ComponentSpec(
        "key_expression_viewer",
        L6Ecosystem,
        "Zenoh key expression tree with wildcard resolution",
        [PropSpec("expression", StringProp, "Key expression pattern")],
        [],
      ),
    ),
    #(
      "pub_sub_flow",
      ComponentSpec(
        "pub_sub_flow",
        L6Ecosystem,
        "Publisher-subscriber flow diagram for a topic",
        [
          PropSpec("topic", StringProp, "Topic"),
          PropSpec("publishers", IntProp, "Pub count"),
          PropSpec("subscribers", IntProp, "Sub count"),
        ],
        [],
      ),
    ),
    #(
      "zenoh_session_card",
      ComponentSpec(
        "zenoh_session_card",
        L6Ecosystem,
        "Single Zenoh session detail card",
        [
          PropSpec("session_id", StringProp, "Session ID"),
          PropSpec("peer_count", IntProp, "Connected peers"),
          PropSpec("uptime_ms", IntProp, "Uptime"),
        ],
        [],
      ),
    ),
    #(
      "router_health_strip",
      ComponentSpec(
        "router_health_strip",
        L6Ecosystem,
        "3-router health strip with failover indicator",
        [PropSpec("routers", JsonProp, "Router statuses")],
        [],
      ),
    ),
    #(
      "topic_tree",
      ComponentSpec(
        "topic_tree",
        L6Ecosystem,
        "Hierarchical Zenoh topic namespace tree",
        [
          PropSpec("root", StringProp, "Root prefix"),
          PropSpec("children", JsonProp, "Child topics"),
        ],
        [],
      ),
    ),
    #(
      "message_inspector",
      ComponentSpec(
        "message_inspector",
        L6Ecosystem,
        "Zenoh message payload inspector with hex/JSON toggle",
        [
          PropSpec("key", StringProp, "Key"),
          PropSpec("payload", StringProp, "Payload bytes"),
        ],
        [],
      ),
    ),
    #(
      "qos_priority_badge",
      ComponentSpec(
        "qos_priority_badge",
        L6Ecosystem,
        "Zenoh QoS priority level badge",
        [
          PropSpec("priority", IntProp, "Priority 0-7"),
          PropSpec(
            "reliability",
            EnumProp(["best_effort", "reliable"]),
            "Reliability",
          ),
        ],
        [],
      ),
    ),
    #(
      "congestion_indicator",
      ComponentSpec(
        "congestion_indicator",
        L6Ecosystem,
        "Zenoh congestion control state",
        [
          PropSpec("congested", BoolProp, "Is congested"),
          PropSpec("dropped", IntProp, "Dropped messages"),
        ],
        [],
      ),
    ),
    #(
      "liveliness_token",
      ComponentSpec(
        "liveliness_token",
        L6Ecosystem,
        "Zenoh liveliness token status",
        [
          PropSpec("token", StringProp, "Token key"),
          PropSpec("alive", BoolProp, "Is alive"),
        ],
        [],
      ),
    ),
    #(
      "scout_result",
      ComponentSpec(
        "scout_result",
        L6Ecosystem,
        "Zenoh scout discovery result",
        [
          PropSpec("peers_found", IntProp, "Peers"),
          PropSpec("routers_found", IntProp, "Routers"),
        ],
        [],
      ),
    ),

    // --- CONTAINER LIFECYCLE (10) ---
    #(
      "container_restart_btn",
      ComponentSpec(
        "container_restart_btn",
        L4System,
        "Single container restart button with confirmation",
        [
          PropSpec("container", StringProp, "Container name"),
          PropSpec("confirm", BoolProp, "Require confirm"),
        ],
        [],
      ),
    ),
    #(
      "image_staleness_badge",
      ComponentSpec(
        "image_staleness_badge",
        L4System,
        "Container image age with rebuild threshold",
        [
          PropSpec("image", StringProp, "Image name"),
          PropSpec("age_hours", IntProp, "Hours since build"),
          PropSpec("threshold_hours", IntProp, "Rebuild threshold"),
        ],
        [],
      ),
    ),
    #(
      "build_history_chart",
      ComponentSpec(
        "build_history_chart",
        L4System,
        "Container build EMA timing chart",
        [
          PropSpec("container", StringProp, "Container"),
          PropSpec("build_times", JsonProp, "Recent build durations"),
        ],
        [],
      ),
    ),
    #(
      "port_mapping_row",
      ComponentSpec(
        "port_mapping_row",
        L4System,
        "Container port mapping display",
        [
          PropSpec("container", StringProp, "Container"),
          PropSpec("host_port", IntProp, "Host port"),
          PropSpec("container_port", IntProp, "Container port"),
        ],
        [],
      ),
    ),
    #(
      "volume_mount_list",
      ComponentSpec(
        "volume_mount_list",
        L4System,
        "Container volume mount paths",
        [
          PropSpec("container", StringProp, "Container"),
          PropSpec("mounts", JsonProp, "Mount points"),
        ],
        [],
      ),
    ),
    #(
      "health_check_log",
      ComponentSpec(
        "health_check_log",
        L4System,
        "Container health check result history",
        [
          PropSpec("container", StringProp, "Container"),
          PropSpec("checks", JsonProp, "Recent check results"),
        ],
        [],
      ),
    ),
    #(
      "resource_limit_bar",
      ComponentSpec(
        "resource_limit_bar",
        L4System,
        "Container CPU/memory limit vs usage",
        [
          PropSpec("cpu_limit", FloatProp, "CPU limit cores"),
          PropSpec("cpu_usage", FloatProp, "CPU usage"),
          PropSpec("mem_limit_mb", IntProp, "Memory limit MB"),
          PropSpec("mem_usage_mb", IntProp, "Memory usage MB"),
        ],
        [],
      ),
    ),
    #(
      "network_namespace_badge",
      ComponentSpec(
        "network_namespace_badge",
        L4System,
        "Container network namespace indicator",
        [
          PropSpec("namespace", StringProp, "Network namespace"),
          PropSpec("ip", StringProp, "IP address"),
        ],
        [],
      ),
    ),
    #(
      "tier_boot_progress",
      ComponentSpec(
        "tier_boot_progress",
        L4System,
        "7-tier boot sequence per-tier progress",
        [
          PropSpec("tier", IntProp, "Tier 1-7"),
          PropSpec("containers", JsonProp, "Containers in tier"),
          PropSpec("completed", IntProp, "Completed count"),
        ],
        [],
      ),
    ),
    #(
      "apoptosis_countdown",
      ComponentSpec(
        "apoptosis_countdown",
        L0Constitutional,
        "Dying gasp countdown during container shutdown",
        [
          PropSpec("container", StringProp, "Container"),
          PropSpec("grace_ms", IntProp, "Grace period ms"),
          PropSpec("elapsed_ms", IntProp, "Elapsed ms"),
        ],
        [],
      ),
    ),

    // --- PLANNING & TASK (10) ---
    #(
      "task_priority_pill",
      ComponentSpec(
        "task_priority_pill",
        L3Transaction,
        "Color-coded priority pill (P0 red, P1 orange, P2 blue, P3 gray)",
        [PropSpec("priority", EnumProp(["P0", "P1", "P2", "P3"]), "Priority")],
        [],
      ),
    ),
    #(
      "task_status_flow",
      ComponentSpec(
        "task_status_flow",
        L3Transaction,
        "Status transition flow diagram: pending→active→completed",
        [
          PropSpec(
            "current",
            EnumProp(["pending", "in_progress", "completed", "blocked"]),
            "Current status",
          ),
        ],
        [],
      ),
    ),
    #(
      "task_burndown_chart",
      ComponentSpec(
        "task_burndown_chart",
        L3Transaction,
        "Sprint burndown chart showing completed vs remaining",
        [
          PropSpec("total", IntProp, "Total tasks"),
          PropSpec("completed", IntProp, "Completed"),
          PropSpec("days", JsonProp, "Daily progress"),
        ],
        [],
      ),
    ),
    #(
      "task_dependency_edge",
      ComponentSpec(
        "task_dependency_edge",
        L3Transaction,
        "Single dependency arrow between two tasks",
        [
          PropSpec("from_id", StringProp, "Source task"),
          PropSpec("to_id", StringProp, "Target task"),
          PropSpec(
            "type",
            EnumProp(["blocks", "blocked_by"]),
            "Dependency type",
          ),
        ],
        [],
      ),
    ),
    #(
      "critical_path_highlight",
      ComponentSpec(
        "critical_path_highlight",
        L3Transaction,
        "Critical path highlight on task DAG",
        [
          PropSpec("path", JsonProp, "Task IDs on critical path"),
          PropSpec("total_duration_ms", IntProp, "Path duration"),
        ],
        [],
      ),
    ),
    #(
      "task_age_indicator",
      ComponentSpec(
        "task_age_indicator",
        L3Transaction,
        "Task age with staleness warning",
        [
          PropSpec("created_at", StringProp, "Created timestamp"),
          PropSpec("stale_hours", IntProp, "Staleness threshold hours"),
        ],
        [],
      ),
    ),
    #(
      "owner_avatar",
      ComponentSpec(
        "owner_avatar",
        L3Transaction,
        "Task owner badge with initials",
        [
          PropSpec("owner", StringProp, "Owner name"),
          PropSpec("color", StringProp, "Avatar color"),
        ],
        [],
      ),
    ),
    #(
      "sprint_velocity",
      ComponentSpec(
        "sprint_velocity",
        L3Transaction,
        "Rolling sprint velocity metric",
        [
          PropSpec("velocity", FloatProp, "Tasks per day"),
          PropSpec("trend", EnumProp(["up", "down", "stable"]), "Trend"),
        ],
        [],
      ),
    ),
    #(
      "raw_lines_preview",
      ComponentSpec(
        "raw_lines_preview",
        L3Transaction,
        "Task raw markdown lines preview",
        [PropSpec("lines", StringProp, "Raw markdown")],
        [],
      ),
    ),
    #(
      "parent_child_tree",
      ComponentSpec(
        "parent_child_tree",
        L3Transaction,
        "Parent-child task hierarchy tree",
        [
          PropSpec("parent_id", StringProp, "Parent"),
          PropSpec("children", JsonProp, "Child task IDs"),
        ],
        [],
      ),
    ),

    // --- KNOWLEDGE & SEMANTIC (8) ---
    #(
      "triple_store_stats",
      ComponentSpec(
        "triple_store_stats",
        L3Transaction,
        "Triple store statistics (SPO/POS/OSP index counts)",
        [
          PropSpec("triples", IntProp, "Total triples"),
          PropSpec("subjects", IntProp, "Unique subjects"),
          PropSpec("predicates", IntProp, "Unique predicates"),
        ],
        [],
      ),
    ),
    #(
      "sparql_query_editor",
      ComponentSpec(
        "sparql_query_editor",
        L3Transaction,
        "SPARQL query input with syntax highlighting",
        [PropSpec("query", StringProp, "SPARQL query text")],
        [],
      ),
    ),
    #(
      "entity_detail_card",
      ComponentSpec(
        "entity_detail_card",
        L3Transaction,
        "Knowledge entity with all properties",
        [
          PropSpec("entity_id", StringProp, "Entity URI"),
          PropSpec("properties", JsonProp, "Property list"),
        ],
        [],
      ),
    ),
    #(
      "inference_chain",
      ComponentSpec(
        "inference_chain",
        L5Cognitive,
        "Materialized inference rule chain visualization",
        [
          PropSpec("rules", JsonProp, "Inference rules applied"),
          PropSpec("conclusion", StringProp, "Derived fact"),
        ],
        [],
      ),
    ),
    #(
      "ontology_class_tree",
      ComponentSpec(
        "ontology_class_tree",
        L3Transaction,
        "Ontology class hierarchy tree",
        [
          PropSpec("root_class", StringProp, "Root"),
          PropSpec("hierarchy", JsonProp, "Class tree"),
        ],
        [],
      ),
    ),
    #(
      "semantic_search_result",
      ComponentSpec(
        "semantic_search_result",
        L3Transaction,
        "Semantic search result with relevance score",
        [
          PropSpec("title", StringProp, "Title"),
          PropSpec("score", FloatProp, "Relevance 0-1"),
          PropSpec("snippet", StringProp, "Text snippet"),
        ],
        [],
      ),
    ),
    #(
      "namespace_prefix_table",
      ComponentSpec(
        "namespace_prefix_table",
        L3Transaction,
        "RDF namespace prefix mappings",
        [PropSpec("prefixes", JsonProp, "Prefix-URI pairs")],
        [],
      ),
    ),
    #(
      "graph_statistics_card",
      ComponentSpec(
        "graph_statistics_card",
        L3Transaction,
        "Named graph statistics",
        [
          PropSpec("graph_name", StringProp, "Graph URI"),
          PropSpec("triple_count", IntProp, "Triples"),
          PropSpec("last_modified", StringProp, "Modified timestamp"),
        ],
        [],
      ),
    ),

    // --- RULE ENGINE & DECISION (8) ---
    #(
      "grl_rule_card",
      ComponentSpec(
        "grl_rule_card",
        L5Cognitive,
        "Single GRL rule display with salience and conditions",
        [
          PropSpec("name", StringProp, "Rule name"),
          PropSpec("salience", IntProp, "Priority"),
          PropSpec("when_clause", StringProp, "When condition"),
          PropSpec("then_clause", StringProp, "Then action"),
        ],
        [],
      ),
    ),
    #(
      "fact_table",
      ComponentSpec(
        "fact_table",
        L5Cognitive,
        "Current fact base key-value table",
        [PropSpec("facts", JsonProp, "Fact key-value pairs")],
        [],
      ),
    ),
    #(
      "rule_fire_log",
      ComponentSpec(
        "rule_fire_log",
        L5Cognitive,
        "Chronological rule firing log",
        [PropSpec("firings", JsonProp, "Rule fire entries")],
        [],
      ),
    ),
    #(
      "decision_tree_node",
      ComponentSpec(
        "decision_tree_node",
        L5Cognitive,
        "Single decision tree node with branches",
        [
          PropSpec("condition", StringProp, "Branch condition"),
          PropSpec("true_action", StringProp, "If true"),
          PropSpec("false_action", StringProp, "If false"),
        ],
        [],
      ),
    ),
    #(
      "domain_selector",
      ComponentSpec(
        "domain_selector",
        L5Cognitive,
        "Rule domain selector (13 domains)",
        [
          PropSpec("domains", JsonProp, "Available domains"),
          PropSpec("selected", StringProp, "Active domain"),
        ],
        [],
      ),
    ),
    #(
      "hysteresis_band",
      ComponentSpec(
        "hysteresis_band",
        L5Cognitive,
        "Hysteresis threshold band visualization",
        [
          PropSpec("upper", FloatProp, "Upper threshold"),
          PropSpec("lower", FloatProp, "Lower threshold"),
          PropSpec("current", FloatProp, "Current value"),
        ],
        [],
      ),
    ),
    #(
      "rete_network_viz",
      ComponentSpec(
        "rete_network_viz",
        L5Cognitive,
        "RETE network alpha/beta node visualization",
        [
          PropSpec("alpha_nodes", IntProp, "Alpha nodes"),
          PropSpec("beta_nodes", IntProp, "Beta nodes"),
          PropSpec("rules_loaded", IntProp, "Rules"),
        ],
        [],
      ),
    ),
    #(
      "escalation_path",
      ComponentSpec(
        "escalation_path",
        L5Cognitive,
        "RCA escalation path L1→L7",
        [
          PropSpec("current_level", IntProp, "Current RCA level 1-7"),
          PropSpec("reason", StringProp, "Escalation reason"),
        ],
        [],
      ),
    ),

    // --- RECOVERY & RESILIENCE (8) ---
    #(
      "recovery_playbook_card",
      ComponentSpec(
        "recovery_playbook_card",
        L0Constitutional,
        "FMEA recovery playbook with RPN score",
        [
          PropSpec("failure_mode", StringProp, "Failure mode"),
          PropSpec("rpn", IntProp, "Risk Priority Number"),
          PropSpec("action", StringProp, "Recovery action"),
        ],
        [],
      ),
    ),
    #(
      "cascade_containment",
      ComponentSpec(
        "cascade_containment",
        L0Constitutional,
        "Cascade failure containment boundary",
        [
          PropSpec("depth", IntProp, "Cascade depth"),
          PropSpec(
            "action",
            EnumProp(["apoptosis", "isolate", "monitor"]),
            "Containment action",
          ),
        ],
        [],
      ),
    ),
    #(
      "partition_fence_status",
      ComponentSpec(
        "partition_fence_status",
        L7Federation,
        "Split-brain partition fencing status",
        [
          PropSpec("partitions", IntProp, "Detected partitions"),
          PropSpec("fenced", BoolProp, "Minority fenced"),
        ],
        [],
      ),
    ),
    #(
      "graceful_degradation_bar",
      ComponentSpec(
        "graceful_degradation_bar",
        L4System,
        "Graceful degradation level indicator",
        [
          PropSpec(
            "level",
            EnumProp(["full", "degraded_1", "degraded_2", "minimal", "offline"]),
            "Degradation level",
          ),
        ],
        [],
      ),
    ),
    #(
      "checkpoint_status",
      ComponentSpec(
        "checkpoint_status",
        L3Transaction,
        "State checkpoint with restore button",
        [
          PropSpec("checkpoint_id", StringProp, "Checkpoint ID"),
          PropSpec("timestamp", StringProp, "Checkpoint time"),
          PropSpec("size_bytes", IntProp, "Size"),
        ],
        [],
      ),
    ),
    #(
      "rollback_button",
      ComponentSpec(
        "rollback_button",
        L0Constitutional,
        "One-click rollback to last checkpoint",
        [
          PropSpec("checkpoint_id", StringProp, "Target checkpoint"),
          PropSpec("confirm", BoolProp, "Require confirmation"),
        ],
        [],
      ),
    ),
    #(
      "dying_gasp_log",
      ComponentSpec(
        "dying_gasp_log",
        L0Constitutional,
        "Last-breath telemetry from dying container",
        [
          PropSpec("container", StringProp, "Container"),
          PropSpec("gasp_data", JsonProp, "Final telemetry snapshot"),
        ],
        [],
      ),
    ),
    #(
      "self_heal_timeline",
      ComponentSpec(
        "self_heal_timeline",
        L4System,
        "Auto-healing event timeline with success rate",
        [
          PropSpec("events", JsonProp, "Heal events"),
          PropSpec("success_rate", FloatProp, "Success rate 0-1"),
        ],
        [],
      ),
    ),

    // --- OBSERVABILITY & TRACING (8) ---
    #(
      "trace_id_link",
      ComponentSpec(
        "trace_id_link",
        L1AtomicDebug,
        "Clickable trace ID with copy and navigate",
        [PropSpec("trace_id", StringProp, "Trace ID")],
        [],
      ),
    ),
    #(
      "span_detail_drawer",
      ComponentSpec(
        "span_detail_drawer",
        L1AtomicDebug,
        "Expandable span detail drawer with attributes",
        [
          PropSpec("span_id", StringProp, "Span ID"),
          PropSpec("name", StringProp, "Span name"),
          PropSpec("attributes", JsonProp, "Span attributes"),
          PropSpec("duration_us", IntProp, "Duration microseconds"),
        ],
        [],
      ),
    ),
    #(
      "service_map_node",
      ComponentSpec(
        "service_map_node",
        L1AtomicDebug,
        "Service dependency map node",
        [
          PropSpec("service", StringProp, "Service name"),
          PropSpec("request_rate", FloatProp, "Requests/sec"),
          PropSpec("error_rate", FloatProp, "Error rate"),
        ],
        [],
      ),
    ),
    #(
      "log_level_filter",
      ComponentSpec(
        "log_level_filter",
        L1AtomicDebug,
        "Log level filter chips (DEBUG/INFO/WARN/ERROR)",
        [PropSpec("active_levels", JsonProp, "Active log levels")],
        [],
      ),
    ),
    #(
      "metric_label_filter",
      ComponentSpec(
        "metric_label_filter",
        L1AtomicDebug,
        "Metric label key=value filter builder",
        [PropSpec("labels", JsonProp, "Label filters")],
        [],
      ),
    ),
    #(
      "alert_rule_card",
      ComponentSpec(
        "alert_rule_card",
        L1AtomicDebug,
        "Alerting rule with condition and threshold",
        [
          PropSpec("name", StringProp, "Rule name"),
          PropSpec("condition", StringProp, "Alert condition"),
          PropSpec("threshold", FloatProp, "Threshold value"),
          PropSpec("firing", BoolProp, "Currently firing"),
        ],
        [],
      ),
    ),
    #(
      "slo_budget_gauge",
      ComponentSpec(
        "slo_budget_gauge",
        L1AtomicDebug,
        "SLO error budget remaining gauge",
        [
          PropSpec("slo_name", StringProp, "SLO name"),
          PropSpec("budget_remaining_pct", FloatProp, "Budget remaining %"),
          PropSpec("window_days", IntProp, "Window days"),
        ],
        [],
      ),
    ),
    #(
      "exemplar_link",
      ComponentSpec(
        "exemplar_link",
        L1AtomicDebug,
        "Metric exemplar linking to trace",
        [
          PropSpec("metric_name", StringProp, "Metric"),
          PropSpec("trace_id", StringProp, "Linked trace ID"),
          PropSpec("value", FloatProp, "Exemplar value"),
        ],
        [],
      ),
    ),

    // --- BIOMORPHIC & METABOLIC (8) ---
    #(
      "pid_tuning_panel",
      ComponentSpec(
        "pid_tuning_panel",
        L2Component,
        "Interactive PID controller tuning with live preview",
        [
          PropSpec("kp", FloatProp, "Proportional"),
          PropSpec("ki", FloatProp, "Integral"),
          PropSpec("kd", FloatProp, "Derivative"),
        ],
        [PropSpec("auto_tune", BoolProp, "Enable auto-tuning")],
      ),
    ),
    #(
      "metabolic_rate_gauge",
      ComponentSpec(
        "metabolic_rate_gauge",
        L4System,
        "Metabolic rate with set-point comparison",
        [
          PropSpec("rate", FloatProp, "Current rate"),
          PropSpec("set_point", FloatProp, "Target set-point"),
        ],
        [],
      ),
    ),
    #(
      "energy_flow_sankey",
      ComponentSpec(
        "energy_flow_sankey",
        L4System,
        "Energy flow Sankey diagram across subsystems",
        [PropSpec("flows", JsonProp, "Energy flow data")],
        [],
      ),
    ),
    #(
      "neuro_signal_trace",
      ComponentSpec(
        "neuro_signal_trace",
        L5Cognitive,
        "Neural subsystem signal trace waveform",
        [
          PropSpec("signal_data", JsonProp, "Signal samples"),
          PropSpec("sample_rate_hz", IntProp, "Sample rate"),
        ],
        [],
      ),
    ),
    #(
      "immune_antibody_forge",
      ComponentSpec(
        "immune_antibody_forge",
        L0Constitutional,
        "Antibody synthesis pipeline status",
        [
          PropSpec("in_progress", IntProp, "Being synthesized"),
          PropSpec("deployed", IntProp, "Deployed"),
          PropSpec("retired", IntProp, "Retired"),
        ],
        [],
      ),
    ),
    #(
      "homeostasis_error_integral",
      ComponentSpec(
        "homeostasis_error_integral",
        L2Component,
        "Cumulative PID error integral with reset",
        [
          PropSpec("integral", FloatProp, "Error integral"),
          PropSpec("windup_limit", FloatProp, "Anti-windup limit"),
        ],
        [],
      ),
    ),
    #(
      "bio_subsystem_radar",
      ComponentSpec(
        "bio_subsystem_radar",
        L5Cognitive,
        "3-axis Bio/Neuro/Immune radar chart",
        [
          PropSpec("bio", FloatProp, "Bio health 0-1"),
          PropSpec("neuro", FloatProp, "Neuro health 0-1"),
          PropSpec("immune", FloatProp, "Immune health 0-1"),
        ],
        [],
      ),
    ),
    #(
      "adaptation_rate_meter",
      ComponentSpec(
        "adaptation_rate_meter",
        L5Cognitive,
        "System adaptation rate with momentum",
        [
          PropSpec("rate", FloatProp, "Adaptation rate"),
          PropSpec("momentum", FloatProp, "Momentum factor"),
        ],
        [],
      ),
    ),

    // --- FEDERATION & L7 (8) ---
    #(
      "consensus_vote_panel",
      ComponentSpec(
        "consensus_vote_panel",
        L7Federation,
        "Tricameral vote panel with 2oo3 status",
        [
          PropSpec("votes", JsonProp, "Vote results"),
          PropSpec("consensus", BoolProp, "Consensus reached"),
        ],
        [],
      ),
    ),
    #(
      "crdt_merge_log",
      ComponentSpec(
        "crdt_merge_log",
        L7Federation,
        "CRDT merge operation log",
        [
          PropSpec("operations", JsonProp, "Merge ops"),
          PropSpec("conflicts", IntProp, "Conflict count"),
        ],
        [],
      ),
    ),
    #(
      "attestation_chain",
      ComponentSpec(
        "attestation_chain",
        L7Federation,
        "Ed25519 attestation chain display",
        [PropSpec("attestations", JsonProp, "Signed attestations")],
        [],
      ),
    ),
    #(
      "federation_member_card",
      ComponentSpec(
        "federation_member_card",
        L7Federation,
        "Single federation member detail",
        [
          PropSpec("member_id", StringProp, "Member ID"),
          PropSpec(
            "role",
            EnumProp(["primary", "secondary", "observer"]),
            "Role",
          ),
          PropSpec("last_sync", StringProp, "Last sync time"),
        ],
        [],
      ),
    ),
    #(
      "causal_order_timeline",
      ComponentSpec(
        "causal_order_timeline",
        L7Federation,
        "Causally ordered event timeline across peers",
        [
          PropSpec("events", JsonProp, "Causal events"),
          PropSpec("vector_clocks", JsonProp, "Vector clock values"),
        ],
        [],
      ),
    ),
    #(
      "gateway_status",
      ComponentSpec(
        "gateway_status",
        L7Federation,
        "Federation gateway health and throughput",
        [
          PropSpec("connected", BoolProp, "Connected"),
          PropSpec("throughput_msg_s", IntProp, "Messages/second"),
        ],
        [],
      ),
    ),
    #(
      "sovereignty_badge",
      ComponentSpec(
        "sovereignty_badge",
        L7Federation,
        "Data sovereignty compliance badge",
        [
          PropSpec("compliant", BoolProp, "Compliant"),
          PropSpec("jurisdiction", StringProp, "Data jurisdiction"),
        ],
        [],
      ),
    ),
    #(
      "mesh_partition_map",
      ComponentSpec(
        "mesh_partition_map",
        L7Federation,
        "Network partition visual map",
        [
          PropSpec("partitions", JsonProp, "Partition groups"),
          PropSpec("bridge_nodes", JsonProp, "Bridge node IDs"),
        ],
        [],
      ),
    ),

    // --- ACCESSIBILITY & HMI (8) ---
    #(
      "color_contrast_badge",
      ComponentSpec(
        "color_contrast_badge",
        L2Component,
        "WCAG 2.1 color contrast ratio badge",
        [
          PropSpec("ratio", FloatProp, "Contrast ratio"),
          PropSpec("level", EnumProp(["AA", "AAA", "fail"]), "WCAG level"),
        ],
        [],
      ),
    ),
    #(
      "keyboard_shortcut_hint",
      ComponentSpec(
        "keyboard_shortcut_hint",
        L2Component,
        "Keyboard shortcut key display",
        [
          PropSpec("keys", StringProp, "Key combination"),
          PropSpec("action", StringProp, "Action description"),
        ],
        [],
      ),
    ),
    #(
      "aria_landmark_indicator",
      ComponentSpec(
        "aria_landmark_indicator",
        L2Component,
        "ARIA landmark role indicator for accessibility audit",
        [
          PropSpec("role", StringProp, "Landmark role"),
          PropSpec("label", StringProp, "Accessible label"),
        ],
        [],
      ),
    ),
    #(
      "focus_trap_boundary",
      ComponentSpec(
        "focus_trap_boundary",
        L2Component,
        "Focus trap boundary for modal dialogs",
        [PropSpec("active", BoolProp, "Trap active")],
        [],
      ),
    ),
    #(
      "screen_reader_status",
      ComponentSpec(
        "screen_reader_status",
        L2Component,
        "Screen reader compatible status announcement",
        [
          PropSpec("message", StringProp, "Status message"),
          PropSpec(
            "priority",
            EnumProp(["polite", "assertive"]),
            "Announcement priority",
          ),
        ],
        [],
      ),
    ),
    #(
      "reduced_motion_toggle",
      ComponentSpec(
        "reduced_motion_toggle",
        L2Component,
        "Respects prefers-reduced-motion media query",
        [PropSpec("reduced", BoolProp, "Motion reduced")],
        [],
      ),
    ),
    #(
      "high_contrast_mode",
      ComponentSpec(
        "high_contrast_mode",
        L2Component,
        "Windows High Contrast mode detection and adaptation",
        [PropSpec("active", BoolProp, "High contrast active")],
        [],
      ),
    ),
    #(
      "text_scaling_control",
      ComponentSpec(
        "text_scaling_control",
        L2Component,
        "Font size scaling control (80%-200%)",
        [PropSpec("scale_pct", IntProp, "Scale percentage")],
        [],
      ),
    ),

    // --- SECURITY & CRYPTO (7) ---
    #(
      "proof_token_verifier",
      ComponentSpec(
        "proof_token_verifier",
        L0Constitutional,
        "Ed25519 proof token verification result",
        [
          PropSpec("token", StringProp, "Token"),
          PropSpec("verified", BoolProp, "Verification result"),
          PropSpec(
            "tier",
            EnumProp(["bypass", "session", "full"]),
            "Security tier",
          ),
        ],
        [],
      ),
    ),
    #(
      "key_rotation_timeline",
      ComponentSpec(
        "key_rotation_timeline",
        L0Constitutional,
        "KMS key rotation schedule timeline",
        [
          PropSpec("key_id", StringProp, "Key ID"),
          PropSpec("rotated_at", StringProp, "Last rotation"),
          PropSpec("next_rotation", StringProp, "Next scheduled"),
        ],
        [],
      ),
    ),
    #(
      "certificate_status",
      ComponentSpec(
        "certificate_status",
        L0Constitutional,
        "TLS certificate validity and expiry",
        [
          PropSpec("subject", StringProp, "Subject CN"),
          PropSpec("expires_at", StringProp, "Expiry date"),
          PropSpec("valid", BoolProp, "Currently valid"),
        ],
        [],
      ),
    ),
    #(
      "access_control_row",
      ComponentSpec(
        "access_control_row",
        L0Constitutional,
        "RBAC permission row",
        [
          PropSpec("principal", StringProp, "Principal"),
          PropSpec("resource", StringProp, "Resource"),
          PropSpec("permission", EnumProp(["allow", "deny"]), "Permission"),
        ],
        [],
      ),
    ),
    #(
      "encryption_indicator",
      ComponentSpec(
        "encryption_indicator",
        L0Constitutional,
        "Data encryption status indicator",
        [
          PropSpec("algorithm", StringProp, "Algorithm"),
          PropSpec("encrypted", BoolProp, "Is encrypted"),
        ],
        [],
      ),
    ),
    #(
      "hmac_verification_badge",
      ComponentSpec(
        "hmac_verification_badge",
        L0Constitutional,
        "HMAC-SHA256 verification result badge",
        [
          PropSpec("verified", BoolProp, "Verification passed"),
          PropSpec("key_id", StringProp, "Key identifier"),
        ],
        [],
      ),
    ),
    #(
      "rate_limit_gauge",
      ComponentSpec(
        "rate_limit_gauge",
        L0Constitutional,
        "API rate limit remaining gauge",
        [
          PropSpec("remaining", IntProp, "Remaining requests"),
          PropSpec("limit", IntProp, "Total limit"),
          PropSpec("reset_ms", IntProp, "Reset in ms"),
        ],
        [],
      ),
    ),

    // --- ALLIUM & SPECIFICATION (5) ---
    #(
      "allium_entity_card",
      ComponentSpec(
        "allium_entity_card",
        L5Cognitive,
        "Allium behavioral spec entity display",
        [
          PropSpec("entity_name", StringProp, "Entity name"),
          PropSpec("transitions", JsonProp, "State transitions"),
        ],
        [],
      ),
    ),
    #(
      "allium_rule_display",
      ComponentSpec(
        "allium_rule_display",
        L5Cognitive,
        "Allium rule with preconditions/postconditions",
        [
          PropSpec("rule_name", StringProp, "Rule name"),
          PropSpec("when_clause", StringProp, "Precondition"),
          PropSpec("ensures", StringProp, "Postcondition"),
        ],
        [],
      ),
    ),
    #(
      "allium_invariant_badge",
      ComponentSpec(
        "allium_invariant_badge",
        L5Cognitive,
        "Allium invariant hold/violated badge",
        [
          PropSpec("name", StringProp, "Invariant name"),
          PropSpec("holds", BoolProp, "Currently holds"),
        ],
        [],
      ),
    ),
    #(
      "spec_drift_indicator",
      ComponentSpec(
        "spec_drift_indicator",
        L5Cognitive,
        "Allium spec vs code drift detection",
        [
          PropSpec("entity", StringProp, "Entity name"),
          PropSpec("drift_pct", FloatProp, "Drift percentage"),
        ],
        [],
      ),
    ),
    #(
      "contract_boundary_viz",
      ComponentSpec(
        "contract_boundary_viz",
        L5Cognitive,
        "Allium contract boundary visualization",
        [
          PropSpec("contract_name", StringProp, "Contract"),
          PropSpec("methods", JsonProp, "Contract methods"),
        ],
        [],
      ),
    ),

    // --- NOTIFICATION & COMMUNICATION (5) ---
    #(
      "toast_notification",
      ComponentSpec(
        "toast_notification",
        L2Component,
        "Auto-dismissing toast notification",
        [
          PropSpec("message", StringProp, "Message"),
          PropSpec(
            "severity",
            EnumProp(["info", "success", "warning", "error"]),
            "Severity",
          ),
          PropSpec("duration_ms", IntProp, "Auto-dismiss ms"),
        ],
        [],
      ),
    ),
    #(
      "notification_badge_counter",
      ComponentSpec(
        "notification_badge_counter",
        L2Component,
        "Notification count badge overlay",
        [
          PropSpec("count", IntProp, "Unread count"),
          PropSpec("max_display", IntProp, "Max display number"),
        ],
        [],
      ),
    ),
    #(
      "system_announcement",
      ComponentSpec(
        "system_announcement",
        L2Component,
        "System-wide announcement banner",
        [
          PropSpec("message", StringProp, "Announcement"),
          PropSpec("dismissable", BoolProp, "Can dismiss"),
        ],
        [],
      ),
    ),
    #(
      "operator_presence",
      ComponentSpec(
        "operator_presence",
        L5Cognitive,
        "Multi-operator presence indicator",
        [
          PropSpec("operators", JsonProp, "Active operators"),
          PropSpec("current_user", StringProp, "Current user"),
        ],
        [],
      ),
    ),
    #(
      "chat_message_bubble",
      ComponentSpec(
        "chat_message_bubble",
        L5Cognitive,
        "Agent-operator chat message bubble",
        [
          PropSpec("sender", StringProp, "Sender"),
          PropSpec("message", StringProp, "Message text"),
          PropSpec("role", EnumProp(["agent", "operator", "system"]), "Role"),
        ],
        [],
      ),
    ),
  ]
  Catalog(components: dict.from_list(components))
}

/// Look up a component spec by type name.
pub fn lookup(
  catalog: Catalog,
  component_type: String,
) -> Result(ComponentSpec, String) {
  dict.get(catalog.components, component_type)
  |> result.replace_error(
    "Component '" <> component_type <> "' not in catalog (SC-A2UI-002)",
  )
}

/// Check if a component type is registered.
pub fn is_registered(catalog: Catalog, component_type: String) -> Bool {
  dict.has_key(catalog.components, component_type)
}

/// Get all component types for a specific fractal layer.
pub fn components_for_layer(
  catalog: Catalog,
  layer: FractalLayer,
) -> List(ComponentSpec) {
  dict.values(catalog.components)
  |> list.filter(fn(spec) { spec.layer == layer })
}

/// Count total registered components.
pub fn component_count(catalog: Catalog) -> Int {
  dict.size(catalog.components)
}
