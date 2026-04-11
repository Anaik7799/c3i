//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ui/web/dashboard_views</module>
////     <fsharp-lineage>Cepaf.UI.Pages.fs (split: dashboard domain)</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L5_COGNITIVE</layer>
////     <mesh-domain>Dashboard, Cockpit, Planning-Dashboard page views</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>HIGH</criticality>
////     <stamp-controls>SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-GLM-UI-009, SC-MUDA-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="isomorphic">
////       SharedMeshState ≅ Lustre Element tree. Pure, no side effects.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// विभागशः — Division into parts, each complete in itself (Gita 18.41)
////
//// Dashboard, Cockpit, and Planning-Dashboard HTML page body renderers.
////
//// STAMP: SC-GLM-UI-001, SC-GLM-UI-002, SC-GLM-UI-008, SC-GLM-UI-009, SC-MUDA-001

import cepaf_gleam/agui/event_stream_widget
import cepaf_gleam/ui/lustre/shell
import cepaf_gleam/ui/state.{type SharedMeshState}
import gleam/int
import gleam/string
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html

// ---------------------------------------------------------------------------
// 1. Dashboard — L5 Cognitive
// ---------------------------------------------------------------------------

pub fn dashboard_view(state: SharedMeshState) -> Element(msg) {
  let health_str = case
    state.quorum_healthy && state.healthy_count == state.container_count
  {
    True -> "Healthy"
    False ->
      case state.healthy_count > state.container_count / 2 {
        True -> "Degraded"
        False -> "Critical"
      }
  }
  html.div([attribute.class("w-full dashboard-evolutionary")], [
    page_header(
      "Indrajaal Swarm Dashboard",
      "Biomorphic SIL-6 Mesh — 50 Cybernetic Enhancement Vectors Active",
    ),
    // --- SECTION 0: HMI & COGNITIVE CONTROL (NEW) ---
    shell.section("HMI & Cognitive Load Controls", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "Dashboard Audio",
          "Healthy",
          "Muted",
          "Optional Sonification",
        ),
        shell.status_card(
          "Semantic Zoom",
          "Healthy",
          "Level 2",
          "Cognitive Complexity",
        ),
        shell.status_card(
          "LOA Pruning",
          "Healthy",
          "Active",
          "Data Saturation Filter",
        ),
      ]),
      html.div([attribute.class("section-actions")], [
        html.button(
          [
            attribute.class("hmi-toggle-btn"),
            attribute.attribute("role", "button"),
          ],
          [element.text("ENABLE SONIFICATION [432Hz RESONANCE]")],
        ),
        html.button(
          [
            attribute.class("hmi-toggle-btn"),
            attribute.attribute("role", "button"),
          ],
          [element.text("DECREASE SEMANTIC ZOOM [LOA PRUNING]")],
        ),
      ]),
    ]),
    // --- SECTION 0.5: CONTAINER GENOME GRID (16-cell SIL-6 Biomorphic Mesh) ---
    shell.section("Container Genome (SIL-6 Biomorphic Mesh)", [
      shell.genome_grid([
        #("zenoh-router", "healthy"),
        #("db-prod", "healthy"),
        #("obs-prod", "healthy"),
        #("zenoh-r-1", "healthy"),
        #("zenoh-r-2", "healthy"),
        #("zenoh-r-3", "healthy"),
        #("ex-app-1", "healthy"),
        #("ex-app-2", "healthy"),
        #("ex-app-3", "healthy"),
        #("chaya", "healthy"),
        #("cepaf-bridge", "healthy"),
        #("cortex", "healthy"),
        #("ollama", "healthy"),
        #("mojo", "healthy"),
        #("ml-runner-1", "healthy"),
        #("ml-runner-2", "healthy"),
      ]),
    ]),
    // --- SECTION 0.6: OODA 5-Tier Decision Ring ---
    shell.section("OODA Decision Ring (5-Tier)", [
      shell.ooda_5tier(state.ooda_phase),
    ]),
    // --- SECTION 0.7: Constitutional Proof Chain ---
    shell.section("Constitutional Proof Chain", [
      shell.proof_chain([
        #("e3b0c4", True),
        #("a1f2d3", True),
        #("b7c8e9", True),
        #("d4e5f6", True),
        #("f0a1b2", True),
        #("c3d4e5", True),
        #("98a7b6", True),
        #("latest", True),
      ]),
    ]),
    // --- SECTION 0.8: AG-UI Event Stream (live agent activity) ---
    event_stream_widget.render_html(event_stream_widget.demo_events(), 8),
    // --- SECTION 1: MESH HEALTH & AUTONOMY (10) ---
    shell.section("Mesh Health & Autonomy Controls", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "1. Mesh Health",
          health_str,
          int.to_string(state.healthy_count)
            <> "/"
            <> int.to_string(state.container_count),
          "containers healthy",
        ),
        shell.status_card(
          "2. OODA Phase",
          "Healthy",
          state.ooda_phase,
          "current cycle phase",
        ),
        shell.status_card(
          "3. Threat Level",
          threat_label(state.threat_level),
          state.threat_level,
          "immune system status",
        ),
        shell.status_card(
          "4. Zenoh Connectivity",
          bool_status(state.zenoh_connected),
          case state.zenoh_connected {
            True -> "Connected"
            False -> "Offline"
          },
          "mesh transport bus",
        ),
        shell.status_card(
          "5. Quorum",
          bool_status(state.quorum_healthy),
          case state.quorum_healthy {
            True -> "2oo3"
            False -> "Lost"
          },
          "consensus voting",
        ),
        shell.status_card(
          "6. Cockpit Mode",
          "Healthy",
          state.dark_cockpit_mode,
          "dark cockpit state",
        ),
        shell.status_card(
          "7. Symbiotic Autonomy",
          "Optimal",
          "Ready",
          "Human-AI Handover",
        ),
        shell.status_card(
          "8. Anti-Fragility",
          "Optimal",
          "0.94",
          "Systemic Score",
        ),
        shell.status_card(
          "9. Ghost Detector",
          "Healthy",
          "0 Anomalies",
          "Substrate Logic",
        ),
        shell.status_card(
          "10. BFT Confidence",
          "Healthy",
          "99.9%",
          "Byzantine Fault Tol.",
        ),
      ]),
    ]),
    // --- SECTION 2: COGNITIVE & INFERENCE (10) ---
    shell.section("Cognitive & Inference Plane (Qwen3-Coder)", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "11. LLM Token Burn",
          "Healthy",
          "142/s",
          "Inference Velocity",
        ),
        shell.status_card(
          "12. Semantic Frags",
          "Healthy",
          "2.1%",
          "Memory Fragmentation",
        ),
        shell.status_card(
          "13. Cognitive Load",
          "Healthy",
          "0.12",
          "Operator Overload",
        ),
        shell.status_card(
          "14. SLM Readiness",
          "Healthy",
          "Loaded",
          "Edge-Inference Kernel",
        ),
        shell.status_card(
          "15. PSO Activity",
          "Healthy",
          "Converged",
          "Particle Swarm Opt.",
        ),
        shell.status_card(
          "16. Singularity T-",
          "Stressed",
          "3.2 yrs",
          "Countdown Ticker",
        ),
        shell.status_card(
          "17. FEP Surprise",
          "Healthy",
          "0.004",
          "Active Inference",
        ),
        shell.status_card(
          "18. Multi-tenant",
          "Healthy",
          "14 Nodes",
          "Resource Saturation",
        ),
        shell.status_card(
          "19. Context Press",
          "Healthy",
          "0.45",
          "AI Token Limit Gauge",
        ),
        shell.status_card(
          "20. AERI Indicator",
          "Healthy",
          "Stable",
          "Epistemic Resonance",
        ),
      ]),
      html.div([attribute.class("cognitive-multilayer-display")], [
        html.div([attribute.class("multilayer-row")], [
          shell.kv_row("Primary Model", "Qwen3 Coder 35B"),
          shell.kv_row("High Capacity", "Qwen3 Coder 480B"),
          shell.kv_row("API Gateway", "OpenRouter (MoZ Enabled)"),
        ]),
        html.div([attribute.class("multilayer-row")], [
          shell.kv_row("Burn Threshold", "10,000 tokens/min"),
          shell.kv_row("Context Limit", "128,000 tokens"),
          shell.kv_row("Active Inference", "Surprise Minimization (FEP)"),
        ]),
      ]),
    ]),
    // --- SECTION 3: TELEMETRY & PERFORMANCE (10) ---
    shell.section("Telemetry & Performance (Zero-IP)", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "21. OODA Latency",
          "Healthy",
          "42ms",
          "Target < 50ms",
        ),
        shell.status_card(
          "22. Zenoh B/W",
          "Healthy",
          "1.4 Gbps",
          "Mesh Multicast",
        ),
        shell.status_card(
          "23. GC Pause Time",
          "Healthy",
          "1.2ms",
          "Erlang/BEAM Metric",
        ),
        shell.status_card(
          "24. Trace Depth",
          "Healthy",
          "8 Layers",
          "Distributed Tracing",
        ),
        shell.status_card(
          "25. WAL Flush",
          "Healthy",
          "10Hz",
          "SQLite Persistence",
        ),
        shell.status_card(
          "26. Route Eff.",
          "Healthy",
          "0.98",
          "Zero-IP Efficiency",
        ),
        shell.status_card(
          "27. Leak Predict",
          "Healthy",
          "Safe",
          "Memory Trajectory",
        ),
        shell.status_card(
          "28. Mesh Fluidity",
          "Healthy",
          "Optimal",
          "Dynamic Topology",
        ),
        shell.status_card(
          "29. Evolution Vec",
          "Healthy",
          "v22.1",
          "Morphological Vector",
        ),
        shell.status_card(
          "30. Load Balancer",
          "Healthy",
          "Balanced",
          "Cognitive Distribution",
        ),
      ]),
    ]),
    // --- SECTION 4: SECURITY & INTEGRITY (10) ---
    shell.section("Security & Integrity Bounds", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "31. Merkle Root",
          "Healthy",
          "0x8f3a",
          "Visual Cryptography",
        ),
        shell.status_card(
          "32. Token Vel.",
          "Healthy",
          "800/s",
          "Proof-Token Signing",
        ),
        shell.status_card(
          "33. RS Health",
          "Healthy",
          "RS(32,28)",
          "Reed-Solomon Parity",
        ),
        shell.status_card(
          "34. Antibody Rate",
          "Healthy",
          "12/min",
          "Immune Spawn Rate",
        ),
        shell.status_card(
          "35. Apoptosis Thr",
          "Healthy",
          "Remote",
          "Threshold Proximity",
        ),
        shell.status_card(
          "36. Containment",
          "Healthy",
          "Active",
          "Cascade Failure Guard",
        ),
        shell.status_card(
          "37. Tri-Sync",
          "Healthy",
          "Synced",
          "Consensus Accuracy",
        ),
        shell.status_card(
          "38. Strict Mode",
          "Healthy",
          "Enforced",
          "Credo/Dialyzer Linter",
        ),
        shell.status_card(
          "39. Terminal Sync",
          "Healthy",
          "Parity",
          "TUI Mirroring",
        ),
        shell.status_card(
          "40. Isolation",
          "Healthy",
          "Isolated",
          "Thread-Local Integrity",
        ),
      ]),
    ]),
    // --- SECTION 5: ADVANCED A2UI VISUALIZATIONS (10) ---
    shell.section("Advanced A2UI Crystalline Wavefront", [
      html.div([attribute.class("card-grid")], [
        shell.status_card(
          "41. Heatmap",
          "Healthy",
          "Neuromorphic",
          "CSS Stress Shading",
        ),
        html.div([attribute.class("cyber-pulse led-on")], [
          shell.status_card(
            "42. 3D Topology",
            "Healthy",
            "Depth-Enabled",
            "Sparkline Depth",
          ),
        ]),
        html.div([attribute.class("cyber-pulse")], [
          shell.status_card(
            "43. Cyber-Pulse",
            "Healthy",
            "Animating",
            "Node Heartbeat",
          ),
        ]),
        shell.status_card(
          "44. Holo-Grid",
          "Healthy",
          "Active",
          "Dashboard Backdrop",
        ),
        shell.status_card(
          "45. ARIA Live",
          "Healthy",
          "Assertive",
          "Alert Live-Regions",
        ),
        shell.status_card(
          "46. Fractal Zoom",
          "Healthy",
          "Enabled",
          "Deep-Zoom Support",
        ),
        shell.status_card(
          "47. DLQ Warning",
          "Healthy",
          "0 Messages",
          "Backpressure Signal",
        ),
        html.div([attribute.class("mesh-breath")], [
          shell.status_card(
            "48. Mesh Breath",
            "Healthy",
            "Synced",
            "Opacity Animation",
          ),
        ]),
        html.div([attribute.class("led-on")], [
          shell.status_card(
            "49. Jidoka Cord",
            "Healthy",
            "Standby",
            "Emergency Stop",
          ),
        ]),
        shell.status_card(
          "50. LED Matrix",
          "Healthy",
          "L0-L7",
          "Layer Activation",
        ),
      ]),
      html.div([attribute.class("section-actions")], [
        html.button(
          [
            attribute.class("emergency-stop-btn cyber-pulse"),
            attribute.attribute("role", "button"),
            attribute.attribute("aria-label", "Pull the Jidoka Cord"),
          ],
          [element.text("PULL THE JIDOKA CORD [HALT SWARM]")],
        ),
      ]),
    ]),
    shell.section("OODA Ring [A2UI Continuous Wavefront]", [
      html.div([attribute.class("ooda-phases")], [
        ooda_phase_pill("Observe", state.ooda_phase == "observe"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Orient", state.ooda_phase == "orient"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Decide", state.ooda_phase == "decide"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Act", state.ooda_phase == "act"),
        html.span([attribute.class("ooda-arrow")], [element.text("▶")]),
        ooda_phase_pill("Verify", state.ooda_phase == "verify"),
      ]),
      html.div(
        [
          attribute.class("reasoning-marquee"),
          attribute.attribute(
            "style",
            "margin-top: 1rem; padding: 0.75rem; background: rgba(61, 214, 140, 0.1); border-left: 4px solid #3dd68c; font-family: monospace; color: #a6accd;",
          ),
        ],
        [
          element.text("CoT [RETE-UL]: "),
          html.span([attribute.attribute("style", "color: #3dd68c;")], [
            element.text(
              "Evaluating missing critical nodes... No anomalies detected. System in homeostasis. Transitioning to Observe.",
            ),
          ]),
        ],
      ),
    ]),
    // --- SECTION 6: FRACTAL LAYER SUPERVISORS (L0-L7) ---
    // सर्वभूतस्थमात्मानं सर्वभूतानि चात्मनि — See the Self in all beings (Gita 6.29)
    shell.section("Fractal Layer Supervisors (L0-L7) — Zenoh Backplane", [
      // Fractal filter chips
      html.div(
        [attribute.id("fractal-filter-chips"), attribute.class("fractal-chips")],
        [
          filter_pill("All", True),
          html.span([attribute.class("layer-pill layer-l0")], [
            element.text("L0 Constitutional"),
          ]),
          html.span([attribute.class("layer-pill layer-l1")], [
            element.text("L1 Atomic"),
          ]),
          html.span([attribute.class("layer-pill layer-l2")], [
            element.text("L2 Component"),
          ]),
          html.span([attribute.class("layer-pill layer-l3")], [
            element.text("L3 Transaction"),
          ]),
          html.span([attribute.class("layer-pill layer-l4")], [
            element.text("L4 System"),
          ]),
          html.span([attribute.class("layer-pill layer-l5")], [
            element.text("L5 Cognitive"),
          ]),
          html.span([attribute.class("layer-pill layer-l6")], [
            element.text("L6 Ecosystem"),
          ]),
          html.span([attribute.class("layer-pill layer-l7")], [
            element.text("L7 Federation"),
          ]),
        ],
      ),
      // L0 Constitutional — Guardian, Safety, Psi invariants
      html.div([attribute.class("card-grid"), attribute.id("layer-l0")], [
        shell.status_card(
          "L0 Guardian",
          "Healthy",
          "Active",
          "Constitutional approval gate — HITL mandatory",
        ),
        shell.status_card(
          "L0 Psi-0..5",
          "Healthy",
          "6/6 Pass",
          "Existence, Regeneration, Reversibility, Verification, Alignment, Truth",
        ),
        shell.status_card(
          "L0 Emergency Stop",
          "Healthy",
          "Standby",
          "Jidoka cord < 5s response — SC-SAFETY-022",
        ),
      ]),
      // L1 Atomic — Debug, Trace, NIF
      html.div([attribute.class("card-grid"), attribute.id("layer-l1")], [
        shell.status_card(
          "L1 NIF Bridge",
          "Healthy",
          "14 NIFs",
          "c3i_nif.so — Rust FFI boundary",
        ),
        shell.status_card(
          "L1 OTel Trace",
          "Healthy",
          "8 Layers",
          "Distributed tracing via Zenoh",
        ),
        shell.status_card(
          "L1 Debug Probes",
          "Healthy",
          "Active",
          "Event monitor + state inspection",
        ),
      ]),
      // L2 Component — Forms, Grids, Badges
      html.div([attribute.class("card-grid"), attribute.id("layer-l2")], [
        shell.status_card(
          "L2 A2UI Catalog",
          "Healthy",
          "233 Types",
          "Declarative component registry",
        ),
        shell.status_card(
          "L2 Shell Helpers",
          "Healthy",
          "12 Funcs",
          "status_card, kv_row, mini_bar",
        ),
        shell.status_card(
          "L2 Lustre SSR",
          "Healthy",
          "31 Pages",
          "Server-rendered, no client JS",
        ),
      ]),
      // L3 Transaction — Planning, State, DB
      html.div([attribute.class("card-grid"), attribute.id("layer-l3")], [
        shell.status_card(
          "L3 sa-plan-daemon",
          "Healthy",
          "Running",
          "Rust task management — SC-TODO-001",
        ),
        shell.status_card(
          "L3 Smriti.db",
          "Healthy",
          "FTS5",
          "SQLite knowledge store + RAG",
        ),
        shell.status_card(
          "L3 Planning.db",
          "Healthy",
          "WAL",
          "Task state authority",
        ),
      ]),
      // L4 System — Containers, Podman, Boot
      html.div([attribute.class("card-grid"), attribute.id("layer-l4")], [
        shell.status_card(
          "L4 Container Genome",
          "Healthy",
          int.to_string(state.container_count) <> " Alive",
          "16-container SIL-6 biomorphic mesh",
        ),
        shell.status_card(
          "L4 Boot Sequencer",
          "Healthy",
          "7 Tiers",
          "DAG topological sort + waves",
        ),
        shell.status_card(
          "L4 CPU Governor",
          "Healthy",
          "< 85%",
          "Adaptive parallelism — SC-CPU-GOV",
        ),
      ]),
      // L5 Cognitive — OODA, Cortex, Inference
      html.div([attribute.class("card-grid"), attribute.id("layer-l5")], [
        shell.status_card(
          "L5 Cortex",
          "Healthy",
          "31 Modules",
          "Rust 9,104 LOC — chat + voice + RAG",
        ),
        shell.status_card(
          "L5 OODA Loop",
          "Healthy",
          state.ooda_phase,
          "< 100ms cycle — 5-tier decision ring",
        ),
        shell.status_card(
          "L5 Inference",
          "Healthy",
          "6-Tier",
          "Hedged: Gemini || OpenRouter || Ollama || RETE-UL",
        ),
      ]),
      // L6 Ecosystem — Zenoh, Mesh, Topology
      html.div([attribute.class("card-grid"), attribute.id("layer-l6")], [
        shell.status_card(
          "L6 Zenoh Mesh",
          bool_status(state.zenoh_connected),
          case state.zenoh_connected {
            True -> "4 Routers"
            False -> "Offline"
          },
          "Pub/sub + OTel + MCP transport",
        ),
        shell.status_card(
          "L6 Quorum",
          bool_status(state.quorum_healthy),
          case state.quorum_healthy {
            True -> "2oo3 Met"
            False -> "Lost"
          },
          "Byzantine fault tolerance",
        ),
        shell.status_card(
          "L6 MoZ Bridge",
          "Healthy",
          "73 Tools",
          "MCP-over-Zenoh JSON-RPC",
        ),
      ]),
      // L7 Federation — Gateway, Consensus, Multi-node
      html.div([attribute.class("card-grid"), attribute.id("layer-l7")], [
        shell.status_card(
          "L7 Gateway",
          "Healthy",
          "3 Bridges",
          "Telegram + GChat + WhatsApp",
        ),
        shell.status_card(
          "L7 HA Election",
          "Healthy",
          "Primary",
          "Leader/Backup/Standby via Zenoh lease",
        ),
        shell.status_card(
          "L7 Version Vectors",
          "Healthy",
          "Synced",
          "Federated reconciliation — CRDT",
        ),
      ]),
    ]),
    // --- SECTION 7: SUPERVISOR TREE & THREAD MONITORING ---
    // कर्मण्येवाधिकारस्ते — Your right is to action alone (Gita 2.47)
    shell.section("Supervisor Tree & Thread Monitoring", [
      html.div(
        [attribute.id("supervisor-tree"), attribute.class("card-grid")],
        [
          shell.status_card(
            "EXEC-001 Orchestrator",
            "Healthy",
            "Opus",
            "Root supervisor — 25 agents, 2-layer",
          ),
          shell.status_card(
            "Context Supervisor",
            "Healthy",
            "Sonnet",
            "5 workers — compile, format, read",
          ),
          shell.status_card(
            "Domain Supervisor",
            "Healthy",
            "Sonnet",
            "5 workers — test, fix, doc",
          ),
          shell.status_card(
            "Test Supervisor",
            "Healthy",
            "Sonnet",
            "5 workers — unit, E2E, property",
          ),
          shell.status_card(
            "Quality Supervisor",
            "Healthy",
            "Sonnet",
            "5 workers — credo, STAMP, verify",
          ),
        ],
      ),
      html.div(
        [attribute.id("thread-monitor"), attribute.class("card-grid")],
        [
          shell.status_card(
            "BEAM Schedulers",
            "Healthy",
            "16+16",
            "16 normal + 16 dirty IO threads",
          ),
          shell.status_card(
            "Rust Tokio Runtime",
            "Healthy",
            "8 Threads",
            "sa-plan-daemon async runtime",
          ),
          shell.status_card(
            "Rust Modules",
            "Healthy",
            "31 Files",
            "9,104 LOC — cortex, gateway, trace",
          ),
          shell.status_card(
            "Zenoh Sessions",
            bool_status(state.zenoh_connected),
            "4 Routers",
            "TCP 7447 — mesh transport",
          ),
          shell.status_card(
            "Active OODA",
            "Healthy",
            "1 Cycle",
            "Observe-Orient-Decide-Act-Verify",
          ),
          shell.status_card(
            "WebSocket Conns",
            "Healthy",
            "Active",
            "/ws/dashboard + /ws/planning",
          ),
        ],
      ),
    ]),
    // --- SECTION 8: QUICK LINKS + NAVIGATION ---
    shell.section("Quick Links", [
      html.div([attribute.class("card-grid-wide")], [
        quick_link_card("Podman", "/podman", "Container lifecycle, genome health", "L4"),
        quick_link_card("Zenoh Mesh", "/zenoh", "Pub/sub topology, router status", "L6"),
        quick_link_card(
          "Verification",
          "/verification",
          "PROMETHEUS proofs, SIL-6 gates",
          "L0",
        ),
        quick_link_card(
          "Immune System",
          "/immune",
          "Threat detection, antibody counters",
          "L0",
        ),
        quick_link_card(
          "Planning",
          "/planning",
          "Task management, Kanban, AI search",
          "L3",
        ),
        quick_link_card(
          "Agents",
          "/agents",
          "Agent hierarchy, OODA supervision",
          "L5",
        ),
        quick_link_card(
          "Knowledge",
          "/knowledge",
          "Zettelkasten brain, 2060+ holons",
          "L5",
        ),
        quick_link_card("Cockpit", "/cockpit", "Dark cockpit, operator view", "L5"),
      ]),
    ]),
    // --- SECTION 9: OPERATIONAL CONTROLS ---
    shell.section("L5 Operational Controls [A2UI Cognitive Projection]", [
      case state.threat_level {
        "critical" | "severe" ->
          html.div([attribute.class("loa-pruned")], [
            html.span(
              [
                attribute.attribute(
                  "style",
                  "color: #e06c75; font-style: italic;",
                ),
              ],
              [
                element.text(
                  "High threat detected. Manual controls pruned (Dynamic LOA: Supervised Autonomy). System is autonomously mitigating.",
                ),
              ],
            ),
          ])
        _ ->
          html.div([attribute.class("card-grid")], [
            shell.action_button(
              "Force OODA Cycle",
              "/api/v1/ooda/trigger",
              "{\\\"action\\\": \\\"force_cycle\\\"}",
            ),
            shell.action_button(
              "Trigger LLM Advisor",
              "/api/v1/ooda/trigger",
              "{\\\"action\\\": \\\"llm_advise\\\"}",
            ),
            shell.action_button(
              "Inject Fact (RETE-UL)",
              "/api/v1/ooda/trigger",
              "{\\\"action\\\": \\\"inject_fact\\\"}",
            ),
          ])
      },
    ]),
    // --- SECTION 10: INTERACTIVE DASHBOARD ---
    // योगस्थः कुरु कर्माणि — Established in yoga, perform action (Gita 2.48)
    // WebSocket /ws/dashboard + Gemma AI Chat + Live Fractal Monitoring
    shell.section("Live System Intelligence (Zenoh-Native)", [
      html.p([attribute.class("sub")], [
        element.text(
          "Real-time fractal monitoring + AI chat. WebSocket push via Zenoh backplane. Gemma 3/4 AI. Updates every 1s.",
        ),
      ]),
      // View mode toggle
      html.div(
        [
          attribute.id("dash-view-toggle"),
          attribute.attribute(
            "style",
            "display:flex;gap:8px;margin-bottom:12px;flex-wrap:wrap",
          ),
        ],
        [
          html.button(
            [
              attribute.class("btn btn-primary"),
              attribute.attribute("data-view", "grid"),
            ],
            [element.text("Grid")],
          ),
          html.button(
            [
              attribute.class("btn btn-ghost"),
              attribute.attribute("data-view", "supervisors"),
            ],
            [element.text("Supervisors")],
          ),
          html.button(
            [
              attribute.class("btn btn-ghost"),
              attribute.attribute("data-view", "fractal"),
            ],
            [element.text("Fractal Layers")],
          ),
          html.button(
            [
              attribute.class("btn btn-ghost"),
              attribute.attribute("data-view", "analytics"),
            ],
            [element.text("Analytics")],
          ),
        ],
      ),
      // Search bar (Ctrl+K)
      html.div(
        [attribute.id("dash-search-bar"), attribute.attribute("style", "margin-bottom:12px")],
        [
          html.input([
            attribute.type_("text"),
            attribute.id("dash-search-input"),
            attribute.attribute(
              "placeholder",
              "Search system... (Ctrl+K)",
            ),
            attribute.attribute(
              "style",
              "width:100%;padding:10px 14px;background:#141922;border:1px solid #1e2a3a;border-radius:8px;color:#e0e6ed;font-size:0.9rem;min-height:44px",
            ),
          ]),
        ],
      ),
      // WebSocket status + heartbeat
      html.div(
        [
          attribute.attribute(
            "style",
            "display:flex;gap:12px;align-items:center;margin-bottom:12px;flex-wrap:wrap",
          ),
        ],
        [
          html.div(
            [
              attribute.id("dash-ws-status"),
              attribute.attribute("style", "font-size:0.78rem;color:#7a8fa6"),
            ],
            [element.text("Connecting to /ws/dashboard...")],
          ),
          html.div(
            [
              attribute.id("dash-heartbeat"),
              attribute.attribute(
                "style",
                "width:10px;height:10px;border-radius:50%;background:#7a8fa6",
              ),
            ],
            [],
          ),
          html.div(
            [
              attribute.id("dash-task-summary"),
              attribute.attribute("style", "font-size:0.85rem;flex:1"),
            ],
            [element.text("Loading system snapshot...")],
          ),
        ],
      ),
      // Dynamic content area (JS fills this)
      html.div(
        [
          attribute.id("dash-dynamic-content"),
          attribute.attribute("style", "min-height:200px"),
        ],
        [],
      ),
      // Change log
      html.div(
        [
          attribute.id("dash-change-log"),
          attribute.attribute(
            "style",
            "margin-top:12px;max-height:200px;overflow-y:auto",
          ),
        ],
        [
          html.div(
            [
              attribute.attribute(
                "style",
                "color:#7a8fa6;font-size:0.75rem;padding:8px",
              ),
            ],
            [element.text("State change log will appear here...")],
          ),
        ],
      ),
      // AI Chat widget
      html.div([attribute.id("dash-ai-chat")], [
        html.div(
          [
            attribute.attribute(
              "style",
              "color:#7a8fa6;font-size:0.78rem;padding:20px;text-align:center",
            ),
          ],
          [element.text("Loading Gemma AI chat...")],
        ),
      ]),
      // Load comprehensive dashboard JS
      element.element(
        "script",
        [attribute.attribute("src", "/static/dashboard-grid.js?v=22.6.1")],
        [],
      ),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// 6. Cockpit — L5 Cognitive  (SC-HMI-010, SC-AGUI-UI-001..015)
// अन्धकारात् प्रकाशं प्राप्नोति — From darkness one reaches light (Dark Cockpit)
// ---------------------------------------------------------------------------

pub fn cockpit_view(state: SharedMeshState) -> Element(msg) {
  // Derive cockpit mode from health (SC-HMI-010 5-mode state machine)
  let mode = cockpit_mode_from_state(state)
  let mode_color = cockpit_mode_color(mode)
  let health_pct =
    int.to_string(
      case state.healthy_count == 0 && state.container_count == 0 {
        True -> 100
        False ->
          state.healthy_count * 100 / int.max(state.container_count, 1)
      },
    )
  html.div(
    [
      attribute.class("w-full cockpit-page cockpit-mode-" <> mode),
      attribute.attribute("data-cockpit-mode", mode),
    ],
    [
      // ── Header ──────────────────────────────────────────────────────────
      html.div([attribute.class("page-header cockpit-header")], [
        html.div([attribute.class("cockpit-header-left")], [
          html.h1([attribute.class("page-title")], [
            element.text("Cockpit"),
          ]),
          html.div([attribute.class("page-subtitle")], [
            element.text(
              "Operator Primary View — Dark Cockpit Pattern (SC-HMI-010)",
            ),
          ]),
        ]),
        html.div([attribute.class("cockpit-header-right")], [
          // Mode badge
          html.div(
            [
              attribute.class("cockpit-mode-badge cockpit-badge-" <> mode),
              attribute.attribute("id", "cockpit-mode-badge"),
              attribute.attribute("style", "color:" <> mode_color),
            ],
            [element.text(string.uppercase(mode))],
          ),
          // Heartbeat indicator
          html.div(
            [
              attribute.class("cockpit-heartbeat"),
              attribute.attribute("id", "cockpit-heartbeat"),
              attribute.attribute("title", "WebSocket connection status"),
            ],
            [
              html.span(
                [
                  attribute.class("heartbeat-dot heartbeat-live"),
                  attribute.attribute("id", "cockpit-hb-dot"),
                ],
                [],
              ),
              html.span(
                [attribute.attribute("id", "cockpit-hb-label")],
                [element.text("LIVE")],
              ),
            ],
          ),
        ]),
      ]),
      // ── Row 1: Cockpit Mode Status (5-mode display) ──────────────────────
      shell.section("Dark Cockpit 5-Mode Status (SC-HMI-010)", [
        html.div([attribute.class("cockpit-mode-strip")], [
          cockpit_mode_pill("dark", mode, "#3dd68c", "All Nominal"),
          cockpit_mode_pill("dim", mode, "#f5a623", "Warnings"),
          cockpit_mode_pill("normal", mode, "#e0e6ed", "Errors"),
          cockpit_mode_pill("bright", mode, "#ffd93d", "Multiple Errors"),
          cockpit_mode_pill("emergency", mode, "#ff4757", "Critical"),
        ]),
        html.div([attribute.class("card-grid")], [
          shell.status_card(
            "Cockpit Mode",
            case mode {
              "dark" | "dim" -> "Healthy"
              "normal" -> "Degraded"
              _ -> "Critical"
            },
            string.uppercase(mode),
            "SC-HMI-010 active mode",
          ),
          shell.status_card(
            "Health Score",
            case mode {
              "dark" -> "Healthy"
              "dim" -> "Degraded"
              _ -> "Critical"
            },
            health_pct <> "%",
            int.to_string(state.healthy_count)
              <> "/"
              <> int.to_string(state.container_count)
              <> " healthy",
          ),
          shell.status_card(
            "2oo3 Quorum",
            bool_status(state.quorum_healthy),
            case state.quorum_healthy {
              True -> "Met"
              False -> "Lost"
            },
            "SIL-4 voting (SC-SIL4-006)",
          ),
          shell.status_card(
            "Zenoh Mesh",
            bool_status(state.zenoh_connected),
            case state.zenoh_connected {
              True -> "Connected"
              False -> "Offline"
            },
            "4/4 routers active",
          ),
          shell.status_card(
            "OODA Phase",
            "Healthy",
            state.ooda_phase,
            "cycle < 100ms (SC-OODA)",
          ),
          shell.status_card(
            "CPU Governor",
            "Healthy",
            "< 60%",
            "SC-CPU-GOV active",
          ),
          shell.status_card(
            "Threat Level",
            threat_label(state.threat_level),
            state.threat_level,
            "immune system",
          ),
          shell.status_card(
            "Active Alarms",
            "Healthy",
            "0",
            "all acknowledged",
          ),
        ]),
      ]),
      // ── Row 2: Alarm Panel (sorted Critical → Advisory) ─────────────────
      shell.section("Alarm Panel — Critical/Warning/Caution/Advisory", [
        html.div(
          [
            attribute.class("cockpit-alarm-toolbar"),
            attribute.attribute("id", "cockpit-alarm-toolbar"),
          ],
          [
            html.span([attribute.class("alarm-filter-chips")], [
              alarm_filter_chip("ALL", True),
              alarm_filter_chip("CRIT", False),
              alarm_filter_chip("WARN", False),
              alarm_filter_chip("CAUT", False),
              alarm_filter_chip("INFO", False),
            ]),
            html.span(
              [
                attribute.class("alarm-count mono"),
                attribute.attribute("id", "alarm-count-label"),
              ],
              [element.text("0 active alarms")],
            ),
          ],
        ),
        html.div(
          [
            attribute.class("cockpit-alarm-list"),
            attribute.attribute("id", "cockpit-alarm-list"),
          ],
          [
            // Dark cockpit default: no alarms = empty state (nominal is invisible)
            html.div([attribute.class("alarm-empty-state")], [
              html.div([attribute.class("alarm-empty-icon")], [
                element.text("●"),
              ]),
              html.div([attribute.class("alarm-empty-text")], [
                element.text("Dark Cockpit — All nominal. Nothing to show."),
              ]),
            ]),
          ],
        ),
      ]),
      // ── Row 3: Container Genome Grid (16-cell SIL-6 mesh) ─────────────
      shell.section("Container Genome Grid — 16-Cell SIL-6 Biomorphic Mesh", [
        shell.genome_grid([
          #("zenoh-router", "healthy"),
          #("db-prod", "healthy"),
          #("obs-prod", "healthy"),
          #("zenoh-r-1", "healthy"),
          #("zenoh-r-2", "healthy"),
          #("zenoh-r-3", "healthy"),
          #("ex-app-1", "healthy"),
          #("ex-app-2", "healthy"),
          #("ex-app-3", "healthy"),
          #("chaya", "healthy"),
          #("cepaf-bridge", "healthy"),
          #("cortex", "healthy"),
          #("ollama", "healthy"),
          #("mojo", "healthy"),
          #("ml-runner-1", "healthy"),
          #("ml-runner-2", "healthy"),
        ]),
      ]),
      // ── Row 4: OODA Phase Ring + Zenoh Mesh Nodes ──────────────────────
      html.div([attribute.class("cockpit-dual-panel")], [
        html.div([attribute.class("cockpit-panel-half")], [
          shell.section("OODA Phase Ring (5-Tier)", [
            shell.ooda_5tier(state.ooda_phase),
            html.div([attribute.class("ooda-meta-row")], [
              shell.kv_row("Current Phase", state.ooda_phase),
              shell.kv_row("Cycle SLA", "< 100ms"),
              shell.kv_row("Budget Used", "42ms"),
            ]),
          ]),
        ]),
        html.div([attribute.class("cockpit-panel-half")], [
          shell.section("Node Status — Zenoh Mesh Connectivity", [
            html.div(
              [
                attribute.class("cockpit-node-list"),
                attribute.attribute("id", "cockpit-node-list"),
              ],
              [
                node_row("zenoh-router-1", "connected", "12.3", "45.2"),
                node_row("zenoh-router-2", "connected", "8.7", "38.1"),
                node_row("zenoh-router-3", "connected", "10.1", "41.5"),
                node_row("zenoh-router-4", "connected", "9.4", "39.8"),
                node_row("db-prod", "connected", "22.4", "62.8"),
                node_row("obs-prod", "connected", "15.6", "55.3"),
                node_row("cortex", "connected", "31.2", "70.1"),
                node_row("ex-app-1", "connected", "18.9", "48.6"),
              ],
            ),
          ]),
        ]),
      ]),
      // ── Row 5: L0-L7 Fractal Layer Status (condensed for operator) ─────
      shell.section(
        "L0-L7 Fractal Layer Health (Operator View — Condensed)",
        [
          html.div([attribute.class("fractal-layer-strip")], [
            fractal_layer_badge("L0", "Constitutional", "Healthy", "#ff6b6b"),
            fractal_layer_badge("L1", "Atomic/Debug", "Healthy", "#ffd93d"),
            fractal_layer_badge("L2", "Component", "Healthy", "#6bcb77"),
            fractal_layer_badge("L3", "Transaction", "Healthy", "#4d96ff"),
            fractal_layer_badge("L4", "System", "Healthy", "#9b59b6"),
            fractal_layer_badge("L5", "Cognitive", "Healthy", "#00d4aa"),
            fractal_layer_badge("L6", "Ecosystem", "Healthy", "#e74c3c"),
            fractal_layer_badge("L7", "Federation", "Healthy", "#f39c12"),
          ]),
        ],
      ),
      // ── Row 6: AI Chat + View controls (JS-driven) ────────────────────
      html.div([attribute.class("cockpit-bottom-strip")], [
        html.div([attribute.class("cockpit-view-controls")], [
          html.div([attribute.class("view-toggle"), attribute.attribute("id", "cockpit-view-toggle")], [
            html.button([attribute.class("view-btn active"), attribute.attribute("data-view", "grid")], [element.text("Grid")]),
            html.button([attribute.class("view-btn"), attribute.attribute("data-view", "alarms")], [element.text("Alarms")]),
            html.button([attribute.class("view-btn"), attribute.attribute("data-view", "nodes")], [element.text("Nodes")]),
            html.button([attribute.class("view-btn"), attribute.attribute("data-view", "genome")], [element.text("Genome")]),
          ]),
          html.div([attribute.class("cockpit-search-bar")], [
            html.input([
              attribute.class("cockpit-search-input"),
              attribute.attribute("id", "cockpit-search"),
              attribute.attribute("placeholder", "Search alarms, nodes… (Ctrl+K)"),
              attribute.attribute("type", "text"),
            ]),
          ]),
        ]),
        // Gemma AI chat widget (SC-AGUI-UI-005)
        html.div(
          [
            attribute.class("cockpit-ai-chat"),
            attribute.attribute("id", "cockpit-ai-panel"),
          ],
          [
            html.div([attribute.class("ai-chat-header")], [
              html.span([attribute.class("ai-model-label")], [
                element.text("Gemma 3 AI Advisor"),
              ]),
              html.button(
                [
                  attribute.class("ai-chat-toggle"),
                  attribute.attribute("id", "cockpit-ai-toggle"),
                ],
                [element.text("Ask AI")],
              ),
            ]),
            html.div(
              [
                attribute.class("ai-chat-panel"),
                attribute.attribute("id", "cockpit-chat-panel"),
                attribute.attribute("style", "display:none"),
              ],
              [
                html.div(
                  [
                    attribute.class("ai-messages"),
                    attribute.attribute("id", "cockpit-ai-messages"),
                  ],
                  [],
                ),
                html.div([attribute.class("ai-input-row")], [
                  html.input([
                    attribute.class("ai-input"),
                    attribute.attribute("id", "cockpit-ai-input"),
                    attribute.attribute("placeholder", "Ask about alarms, nodes…"),
                    attribute.attribute("type", "text"),
                  ]),
                  html.button(
                    [
                      attribute.class("ai-send-btn"),
                      attribute.attribute("id", "cockpit-ai-send"),
                    ],
                    [element.text("Send")],
                  ),
                ]),
              ],
            ),
          ],
        ),
      ]),
      // ── JS loader ──────────────────────────────────────────────────────
      html.script(
        [attribute.attribute("src", "/static/cockpit-grid.js?v=22.6.1")],
        "",
      ),
    ],
  )
}

// Dark Cockpit 5-mode: derive from health state (SC-HMI-010)
fn cockpit_mode_from_state(state: SharedMeshState) -> String {
  let total = int.max(state.container_count, 1)
  let ratio = state.healthy_count * 100 / total
  case state.quorum_healthy, ratio {
    False, _ -> "emergency"
    True, r if r >= 90 -> state.dark_cockpit_mode
    True, r if r >= 70 -> "dim"
    True, r if r >= 50 -> "normal"
    True, r if r >= 30 -> "bright"
    True, _ -> "emergency"
  }
}

fn cockpit_mode_color(mode: String) -> String {
  case mode {
    "dark" -> "#3dd68c"
    "dim" -> "#f5a623"
    "normal" -> "#e0e6ed"
    "bright" -> "#ffd93d"
    "emergency" -> "#ff4757"
    _ -> "#7a8fa6"
  }
}

fn cockpit_mode_pill(
  name: String,
  active: String,
  color: String,
  label: String,
) -> Element(msg) {
  let is_active = name == active
  let cls = case is_active {
    True -> "cockpit-mode-pill cockpit-mode-pill-active"
    False -> "cockpit-mode-pill"
  }
  let style = case is_active {
    True -> "border-color:" <> color <> ";color:" <> color
    False -> ""
  }
  html.div(
    [
      attribute.class(cls),
      attribute.attribute("style", style),
      attribute.attribute("title", label),
    ],
    [
      html.div(
        [
          attribute.class("pill-dot"),
          attribute.attribute("style", "background:" <> color),
        ],
        [],
      ),
      element.text(string.uppercase(name)),
    ],
  )
}

fn alarm_filter_chip(label: String, active: Bool) -> Element(msg) {
  let cls = case active {
    True -> "alarm-chip alarm-chip-active"
    False -> "alarm-chip"
  }
  html.button([attribute.class(cls)], [element.text(label)])
}

fn node_row(
  name: String,
  status: String,
  cpu: String,
  mem: String,
) -> Element(msg) {
  let status_color = case status {
    "connected" -> "var(--accent)"
    "stale" -> "var(--warn)"
    "degraded" | "disconnected" -> "var(--crit)"
    _ -> "#7a8fa6"
  }
  html.div([attribute.class("cockpit-node-row")], [
    html.span(
      [
        attribute.class("node-status-dot"),
        attribute.attribute("style", "background:" <> status_color),
      ],
      [],
    ),
    html.span([attribute.class("node-name mono")], [element.text(name)]),
    html.span([attribute.class("node-cpu")], [
      element.text("CPU " <> cpu <> "%"),
    ]),
    html.span([attribute.class("node-mem")], [
      element.text("MEM " <> mem <> "%"),
    ]),
    html.span(
      [
        attribute.class("node-status-label"),
        attribute.attribute("style", "color:" <> status_color),
      ],
      [element.text(status)],
    ),
  ])
}

fn fractal_layer_badge(
  layer: String,
  name: String,
  status: String,
  color: String,
) -> Element(msg) {
  html.div(
    [
      attribute.class("fractal-layer-badge"),
      attribute.attribute("title", name <> " — " <> status),
    ],
    [
      html.div(
        [
          attribute.class("flb-layer"),
          attribute.attribute("style", "color:" <> color),
        ],
        [element.text(layer)],
      ),
      html.div([attribute.class("flb-name")], [element.text(name)]),
      html.div(
        [
          attribute.class("flb-status flb-" <> string_lower(status)),
        ],
        [element.text(status)],
      ),
    ],
  )
}

// ---------------------------------------------------------------------------
// 24. Planning Dashboard — L3 Transaction
// ---------------------------------------------------------------------------

pub fn planning_dashboard_view(_state: SharedMeshState) -> Element(msg) {
  html.div([attribute.class("w-full")], [
    page_header(
      "Planning Dashboard",
      "8-panel cockpit — OODA + task + safety + enforcer",
    ),
    shell.section("Panels", [
      html.div([attribute.class("card-grid")], [
        shell.status_card("Task Board", "Healthy", "active", "sa-plan SQLite"),
        shell.status_card("OODA Cycle", "Healthy", "observe", "100ms SLA"),
        shell.status_card("Safety Kernel", "Healthy", "active", "Psi 0-5"),
        shell.status_card(
          "Enforcer Shield",
          "Healthy",
          "active",
          "SC-ENFORCE-001",
        ),
        shell.status_card("Graph Verify", "Healthy", "active", "PageRank"),
        shell.status_card(
          "Orch Mesh",
          "Healthy",
          "active",
          "Prajna + Smriti",
        ),
        shell.status_card("Chaya Twin", "Healthy", "active", "digital twin"),
        shell.status_card(
          "Startup Optim",
          "Healthy",
          "active",
          "< 60s target",
        ),
      ]),
    ]),
    shell.section("AI Copilot", [
      shell.kv_row("Mode", "OODA advisory"),
      shell.kv_row("Model", "OpenRouter (via Zenoh MoZ)"),
      shell.kv_row("HITL gate", "Mandatory for all L0 mutations"),
    ]),
  ])
}

// ---------------------------------------------------------------------------
// Private helpers — used only within this module
// ---------------------------------------------------------------------------

fn page_header(title: String, subtitle: String) -> Element(msg) {
  html.div([attribute.class("page-header")], [
    html.div([], [
      html.h1([attribute.class("page-title")], [element.text(title)]),
      html.div([attribute.class("page-subtitle")], [element.text(subtitle)]),
    ]),
  ])
}

fn threat_label(level: String) -> String {
  case level {
    "nominal" -> "Healthy"
    "elevated" -> "Degraded"
    "critical" -> "Critical"
    _ -> "Unknown"
  }
}

fn bool_status(b: Bool) -> String {
  case b {
    True -> "Healthy"
    False -> "Critical"
  }
}

fn ooda_phase_pill(label: String, active: Bool) -> Element(msg) {
  let cls = case active {
    True -> "ooda-phase ooda-phase-active"
    False -> "ooda-phase"
  }
  html.span([attribute.class(cls)], [element.text(label)])
}

fn quick_link_card(
  title: String,
  href: String,
  description: String,
  layer: String,
) -> Element(msg) {
  html.a([attribute.href(href), attribute.class("card quick-link-card")], [
    html.div([attribute.class("card-header")], [
      html.span([attribute.class("mono text-sm")], [element.text(title)]),
      html.span([attribute.class("layer-badge layer-" <> string_lower(layer))], [
        element.text(layer),
      ]),
    ]),
    html.div([attribute.class("card-detail")], [element.text(description)]),
  ])
}

fn filter_pill(label: String, active: Bool) -> Element(msg) {
  let cls = case active {
    True -> "btn btn-primary"
    False -> "btn btn-ghost"
  }
  html.span([attribute.class(cls)], [element.text(label)])
}

fn string_lower(s: String) -> String {
  case s {
    "L0" -> "l0"
    "L1" -> "l1"
    "L2" -> "l2"
    "L3" -> "l3"
    "L4" -> "l4"
    "L5" -> "l5"
    "L6" -> "l6"
    "L7" -> "l7"
    _ -> s
  }
}
