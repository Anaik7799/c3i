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
  L3Transaction, L4System, L5Cognitive, L6Ecosystem, PropSpec, StringProp,
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
  ]
  Catalog(components: dict.from_list(components))
}

/// Look up a component spec by type name.
pub fn lookup(catalog: Catalog, component_type: String) -> Result(ComponentSpec, String) {
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
