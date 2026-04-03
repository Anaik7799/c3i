# C3I AG-UI Integration: 200 Ranked Ideas

## Scoring (1-5 each, max 20): Criticality, Usability, Information Utility, UX/CX


---

## Category 1: AG-UI Core Event Integration

### 1.  OODA Cycle SSE Lifecycle (Score: 20/20)
- **Source:** AG-UI RUN events
- **Description:** Emit RUN_STARTED/FINISHED for each OODA cycle. Operators see cycle count, duration, health delta in real-time.
- **Zenoh Topic:** `c3i/ooda/{cycle_id}`
- **Scores:** Criticality=5, Usability=5, Info Utility=5, UX/CX=5

### 2.  Safety Kernel Constitutional Reasoning Stream (Score: 20/20)
- **Source:** AG-UI REASONING events
- **Description:** Stream Psi-0..Psi-5 constitutional check results as REASONING_MESSAGE_CONTENT events. Exposes decision chain without raw prompts.
- **Zenoh Topic:** `c3i/safety/reasoning/{op_id}`
- **Scores:** Criticality=5, Usability=5, Info Utility=5, UX/CX=5

### 3.  Guardian Approval Interrupt (Score: 20/20)
- **Source:** AG-UI Interrupts (Draft)
- **Description:** When SafetyKernel needs two-key-turn confirmation, emit RUN_FINISHED(outcome=interrupt). Frontend shows approval dialog. Resume on user response.
- **Zenoh Topic:** `c3i/guardian/approval/{req_id}`
- **Scores:** Criticality=5, Usability=5, Info Utility=5, UX/CX=5

### 4.  Mesh State Delta Streaming via JSON Patch (Score: 19/20)
- **Source:** AG-UI STATE_DELTA (RFC 6902)
- **Description:** Replace 30s polling with incremental JSON Patch updates. Only changed metrics flow to the frontend.
- **Zenoh Topic:** `c3i/telemetry/delta`
- **Scores:** Criticality=5, Usability=5, Info Utility=5, UX/CX=4

### 5.  Planning Task Lifecycle Events (Score: 17/20)
- **Source:** AG-UI STEP events
- **Description:** Each task CRUD operation emits STEP_STARTED/FINISHED. Shows exact operation being performed.
- **Zenoh Topic:** `c3i/planning/events`
- **Scores:** Criticality=4, Usability=5, Info Utility=4, UX/CX=4

### 6.  MCP Tool Call Visibility (Score: 19/20)
- **Source:** AG-UI TOOL_CALL events
- **Description:** When MCP executes planning_query or verification_run, emit TOOL_CALL_START/ARGS/END. Operator sees which tool is executing and with what arguments.
- **Zenoh Topic:** `c3i/mcp/tool_call/{id}`
- **Scores:** Criticality=5, Usability=4, Info Utility=5, UX/CX=5

### 7.  Circuit Breaker State Change Events (Score: 19/20)
- **Source:** AG-UI CUSTOM
- **Description:** Emit CUSTOM('circuit_breaker') when enforcer opens/closes a circuit. Shows blocked agent IDs in real-time.
- **Zenoh Topic:** `c3i/enforcer/circuit/{agent_id}`
- **Scores:** Criticality=5, Usability=5, Info Utility=4, UX/CX=5

### 8.  Emergency Stop Mesh Broadcast (Score: 19/20)
- **Source:** AG-UI CUSTOM + Zenoh
- **Description:** Emergency stop emits CUSTOM('emergency_stop') AND broadcasts to c3i/a2a/broadcast. All mesh agents halt. Frontend flashes red overlay.
- **Zenoh Topic:** `c3i/a2a/broadcast`
- **Scores:** Criticality=5, Usability=5, Info Utility=5, UX/CX=4

### 9.  Verification Run Progress Stream (Score: 17/20)
- **Source:** AG-UI ACTIVITY events
- **Description:** During gleam test, emit ACTIVITY_SNAPSHOT with test name, ACTIVITY_DELTA for each pass/fail. Shows 479/479 progress bar.
- **Zenoh Topic:** `c3i/verification/progress`
- **Scores:** Criticality=4, Usability=4, Info Utility=5, UX/CX=4

### 10.  Chaya Sync Phase Stream (Score: 16/20)
- **Source:** AG-UI STEP events
- **Description:** 5-phase sync emits STEP for each phase: ReadPlanning, DetectOrphans, Convert, Regenerate, Verify. Real-time phase indicator.
- **Zenoh Topic:** `c3i/planning/sync/{phase}`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=4

### 11.  Audit Trail Messages Snapshot (Score: 16/20)
- **Source:** AG-UI MESSAGES_SNAPSHOT
- **Description:** Emit complete safety event log as MESSAGES_SNAPSHOT. Operator gets scrollable compliance history.
- **Zenoh Topic:** `c3i/safety/audit`
- **Scores:** Criticality=5, Usability=3, Info Utility=5, UX/CX=3

### 12.  Zenoh Raw Event Passthrough (Score: 14/20)
- **Source:** AG-UI RAW events
- **Description:** Forward native Zenoh pub/sub messages as RAW events with source='zenoh'. Frontend renders message key, payload, timestamp.
- **Zenoh Topic:** `c3i/zenoh/raw/#`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=3

### 13.  Metabolic Set-Point State Delta (Score: 15/20)
- **Source:** AG-UI STATE_DELTA
- **Description:** Push metabolic governor state changes: set_point, energy, cpu_load, health_status as JSON Patch operations.
- **Zenoh Topic:** `c3i/metabolic/state`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=4

### 14.  Boot Sequence Step Events (Score: 14/20)
- **Source:** AG-UI STEP events
- **Description:** 5-stage boot emits STEP per stage: InitSystem, LoadConfig, MountFS, StartServices, ActivateApp. Shows sequential progress.
- **Zenoh Topic:** `c3i/boot/stage/{n}`
- **Scores:** Criticality=4, Usability=4, Info Utility=3, UX/CX=3

### 15.  Immune Threat Level Custom Event (Score: 15/20)
- **Source:** AG-UI CUSTOM
- **Description:** MARA state changes emit CUSTOM('threat_level') with level, strategy, confidence. Dashboard shows threat gauge.
- **Zenoh Topic:** `c3i/immune/threat`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=4

### 16.  Text Message Agent Explanations (Score: 16/20)
- **Source:** AG-UI TEXT_MESSAGE events
- **Description:** Agent streams natural language explanations via TEXT_MESSAGE_START/CONTENT/END. Operator asks 'why is CPU high?' and gets streaming answer.
- **Zenoh Topic:** `c3i/agent/response`
- **Scores:** Criticality=3, Usability=5, Info Utility=4, UX/CX=4

### 17.  Tool Call Result Rendering (Score: 16/20)
- **Source:** AG-UI TOOL_CALL_RESULT
- **Description:** After MCP tool execution, emit TOOL_CALL_RESULT with structured output. Frontend renders results inline (e.g., task list, verification report).
- **Zenoh Topic:** `c3i/mcp/result/{id}`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=4

### 18.  State Snapshot on Connection (Score: 15/20)
- **Source:** AG-UI STATE_SNAPSHOT
- **Description:** When SSE connection opens, immediately emit full STATE_SNAPSHOT with all current mesh state. Client bootstraps from this.
- **Zenoh Topic:** `c3i/state/snapshot`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=3

### 19.  Multi-Step OODA with Nested Runs (Score: 14/20)
- **Source:** AG-UI parentRunId
- **Description:** Complex OODA cycles that delegate to sub-agents create nested runs with parentRunId. UI shows run hierarchy tree.
- **Zenoh Topic:** `c3i/ooda/{cycle_id}/sub/{sub_id}`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 20.  Custom Event Schema Registry (Score: 13/20)
- **Source:** AG-UI CUSTOM
- **Description:** Define a C3I-specific custom event schema registry: emergency_stop, circuit_breaker, threat_level, anomaly_detected, tmr_vote, sync_phase. All agents use consistent schema.
- **Zenoh Topic:** `c3i/schema/events`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=2


---

## Category 2: Zenoh A2A Agent Communication

### 21.  Agent-to-Agent Direct Messaging (Score: 19/20)
- **Source:** A2A + Zenoh
- **Description:** Each of 7 services (Cortex, Prajna, Smriti, CEPAF, Planning, Chaya, Guardian) has a dedicated inbox topic. Direct messaging via c3i/a2a/{source}/{target}.
- **Zenoh Topic:** `c3i/a2a/{src}/{tgt}`
- **Scores:** Criticality=5, Usability=5, Info Utility=5, UX/CX=4

### 22.  Mesh Broadcast for Global State (Score: 16/20)
- **Source:** A2A + Zenoh
- **Description:** Broadcast channel for mesh-wide announcements: config changes, emergency alerts, new service registration.
- **Zenoh Topic:** `c3i/a2a/broadcast`
- **Scores:** Criticality=5, Usability=4, Info Utility=4, UX/CX=3

### 23.  Zenoh Heartbeat Discovery (Score: 14/20)
- **Source:** A2A + Zenoh
- **Description:** Each agent publishes heartbeat every 5s to c3i/a2a/heartbeat/{agent_id}. Auto-populate ServiceRegistry from gossip.
- **Zenoh Topic:** `c3i/a2a/heartbeat/{id}`
- **Scores:** Criticality=4, Usability=4, Info Utility=3, UX/CX=3

### 24.  Task Distribution via Zenoh Topics (Score: 15/20)
- **Source:** A2A + Planning Orchestration
- **Description:** Planning publishes tasks to c3i/planning/distribute/{strategy}. Chaya nodes subscribe and accept based on strategy (round-robin, least-loaded, priority).
- **Zenoh Topic:** `c3i/planning/distribute/{strategy}`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=3

### 25.  Guardian Consensus via Zenoh (Score: 15/20)
- **Source:** A2A + SafetyKernel
- **Description:** Multiple Guardian instances reach consensus on safety-critical operations via pub/sub voting on c3i/guardian/vote/{op_id}.
- **Zenoh Topic:** `c3i/guardian/vote/{op_id}`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 26.  Cortex AI Request Pipeline (Score: 15/20)
- **Source:** A2A + Zenoh
- **Description:** Planning asks Cortex for AI analysis by publishing to c3i/a2a/planning/cortex. Cortex responds on c3i/a2a/cortex/planning with enriched results.
- **Zenoh Topic:** `c3i/a2a/planning/cortex`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=3

### 27.  Smriti Knowledge Query via Zenoh (Score: 15/20)
- **Source:** A2A + Zenoh
- **Description:** Any agent queries Smriti knowledge base by publishing to c3i/a2a/*/smriti with topic filter. Smriti responds with relevant knowledge nodes.
- **Zenoh Topic:** `c3i/a2a/*/smriti`
- **Scores:** Criticality=3, Usability=4, Info Utility=5, UX/CX=3

### 28.  Prajna Health Aggregation (Score: 14/20)
- **Source:** A2A + Zenoh
- **Description:** Prajna subscribes to all heartbeat topics, aggregates mesh health, publishes composite score to c3i/prajna/health/composite.
- **Zenoh Topic:** `c3i/prajna/health/composite`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 29.  OODA Phase Coordination (Score: 15/20)
- **Source:** A2A + Zenoh
- **Description:** OODA controller publishes current phase to c3i/ooda/{cycle}/phase. Other agents can inject observations by publishing to c3i/ooda/{cycle}/inject.
- **Zenoh Topic:** `c3i/ooda/{cycle}/phase`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 30.  Service Registration Events (Score: 12/20)
- **Source:** A2A + Zenoh
- **Description:** When a new service starts, it publishes ServiceRegistered to c3i/a2a/registry. All agents update their ServiceRegistry.
- **Zenoh Topic:** `c3i/a2a/registry`
- **Scores:** Criticality=4, Usability=3, Info Utility=3, UX/CX=2

### 31.  Multi-Agent Consensus Protocol (Score: 12/20)
- **Source:** A2A + Zenoh
- **Description:** Implement Raft-like consensus over Zenoh for distributed decisions. Leader election via c3i/a2a/consensus/leader.
- **Zenoh Topic:** `c3i/a2a/consensus/leader`
- **Scores:** Criticality=4, Usability=2, Info Utility=4, UX/CX=2

### 32.  Dead Letter Queue for Failed Messages (Score: 12/20)
- **Source:** A2A + Zenoh
- **Description:** Undeliverable A2A messages routed to c3i/a2a/dead_letter. Monitor and replay failed messages.
- **Zenoh Topic:** `c3i/a2a/dead_letter`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=2

### 33.  Agent Capability Advertisement (Score: 13/20)
- **Source:** A2A + Zenoh
- **Description:** Each agent publishes its MCP tool capabilities to c3i/a2a/capabilities/{agent_id}. Enables dynamic tool discovery.
- **Zenoh Topic:** `c3i/a2a/capabilities/{id}`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=2

### 34.  Cross-Holon State Sync via Zenoh (Score: 12/20)
- **Source:** A2A + Zenoh
- **Description:** Holons sync their state via c3i/holon/{id}/state. Conflict resolution uses last-writer-wins with vector clocks.
- **Zenoh Topic:** `c3i/holon/{id}/state`
- **Scores:** Criticality=4, Usability=2, Info Utility=4, UX/CX=2

### 35.  Zenoh QoS Priority Lanes (Score: 12/20)
- **Source:** Zenoh
- **Description:** Safety messages use high-priority Zenoh channels. Telemetry uses best-effort. Ensures emergency_stop always arrives first.
- **Zenoh Topic:** `c3i/priority/high/*`
- **Scores:** Criticality=5, Usability=2, Info Utility=3, UX/CX=2

### 36.  Agent Subscription Management (Score: 11/20)
- **Source:** A2A + Zenoh
- **Description:** Agents dynamically subscribe/unsubscribe to topics based on current role. E.g., Planning only subscribes to task-related topics.
- **Zenoh Topic:** `c3i/subscriptions/{agent_id}`
- **Scores:** Criticality=3, Usability=3, Info Utility=3, UX/CX=2

### 37.  Zenoh Bridge to External A2A (Score: 12/20)
- **Source:** A2A Protocol + Zenoh
- **Description:** Bridge Zenoh topics to Google A2A protocol for inter-system agent communication. C3I agents talk to external agent ecosystems.
- **Zenoh Topic:** `c3i/bridge/a2a/*`
- **Scores:** Criticality=3, Usability=3, Info Utility=3, UX/CX=3

### 38.  AG-UI Event Fan-Out via Zenoh (Score: 14/20)
- **Source:** AG-UI + Zenoh
- **Description:** AG-UI events emitted by any agent are published to c3i/agui/events/{agent_id}. Multiple SSE endpoints can subscribe and relay to different frontends.
- **Zenoh Topic:** `c3i/agui/events/{agent_id}`
- **Scores:** Criticality=4, Usability=4, Info Utility=3, UX/CX=3

### 39.  Zenoh Backpressure for Slow Consumers (Score: 10/20)
- **Source:** Zenoh
- **Description:** When SSE client falls behind, Zenoh publisher applies backpressure. Prevents memory exhaustion on fast-producing agents.
- **Zenoh Topic:** `c3i/backpressure/*`
- **Scores:** Criticality=4, Usability=2, Info Utility=2, UX/CX=2

### 40.  Temporal Message Ordering via Zenoh Timestamps (Score: 11/20)
- **Source:** Zenoh
- **Description:** All Zenoh messages carry NTP-synced timestamps. Consumers reorder by timestamp for deterministic replay. Critical for audit trail.
- **Zenoh Topic:** `c3i/time/*`
- **Scores:** Criticality=4, Usability=2, Info Utility=3, UX/CX=2


---

## Category 3: Generative UI Widgets

### 41.  Interactive Mesh Topology D3 Graph (Score: 16/20)
- **Source:** Google Generative UI
- **Description:** Agent generates SVG/D3 mesh topology with 7 containers as nodes. Color by health. Click to drill down. Live position updates via STATE_DELTA.
- **Zenoh Topic:** `c3i/ui/topology`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=5

### 42.  Fractal Compliance Matrix (Score: 16/20)
- **Source:** Google Generative UI + Verification
- **Description:** 8x8 colored grid: Fractal Layers (L0-L7) vs Compliance Checks (types, safety, perf, etc.). Green=pass, red=fail. Click cell for details.
- **Zenoh Topic:** `c3i/ui/compliance`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=4

### 43.  14-State Container DFA Widget (Score: 15/20)
- **Source:** Google Generative UI + Math
- **Description:** Interactive state machine diagram showing container lifecycle. Current state highlighted. Transitions animate on STATE_DELTA events.
- **Zenoh Topic:** `c3i/ui/dfa/{container}`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=4

### 44.  Real-Time Sparkline Dashboard (Score: 16/20)
- **Source:** Google Generative UI
- **Description:** Agent generates sparkline charts for CPU, memory, network, disk across all containers. Auto-scales. Color-coded thresholds.
- **Zenoh Topic:** `c3i/ui/sparklines`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=5

### 45.  OTel Flame Graph Visualization (Score: 15/20)
- **Source:** Golden Triangle + Generative UI
- **Description:** Agent generates interactive flame graph from OTel traces. Shows time breakdown: HTTP -> routing -> safety -> DB -> Zenoh -> response.
- **Zenoh Topic:** `c3i/ui/flamegraph`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=4

### 46.  Streaming Task Kanban Board (Score: 16/20)
- **Source:** Generative UI + Planning
- **Description:** Drag-drop Kanban with columns: Pending, InProgress, Completed, Blocked. Tasks move in real-time via STATE_DELTA. Drag triggers TOOL_CALL.
- **Zenoh Topic:** `c3i/ui/kanban`
- **Scores:** Criticality=3, Usability=5, Info Utility=4, UX/CX=4

### 47.  Threat Level Gauge Widget (Score: 15/20)
- **Source:** Generative UI + Immune
- **Description:** Animated radial gauge showing MARA threat level (0-100). Color transitions: green -> yellow -> red. Needle moves on STATE_DELTA.
- **Zenoh Topic:** `c3i/ui/threat_gauge`
- **Scores:** Criticality=4, Usability=3, Info Utility=3, UX/CX=5

### 48.  Knowledge Graph Explorer (Score: 14/20)
- **Source:** Generative UI + Knowledge
- **Description:** Interactive force-directed graph of knowledge nodes. Colored by HolonLevel. Search and filter. Double-click to expand neighbors.
- **Zenoh Topic:** `c3i/ui/knowledge`
- **Scores:** Criticality=2, Usability=3, Info Utility=5, UX/CX=4

### 49.  Zenoh Message Flow Animation (Score: 14/20)
- **Source:** Generative UI + Zenoh
- **Description:** Animated diagram showing messages flowing between topics. Lines pulse from publisher to subscriber. Color by message type.
- **Zenoh Topic:** `c3i/ui/zenoh_flow`
- **Scores:** Criticality=2, Usability=3, Info Utility=4, UX/CX=5

### 50.  Fault Injection Simulation (Score: 14/20)
- **Source:** Generative UI + Chaos
- **Description:** Interactive sandbox: operator clicks to kill a container, introduces network partition, or injects CPU spike. Mesh reacts in real-time.
- **Zenoh Topic:** `c3i/ui/simulation`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=4

### 51.  Incident Report Generator (Score: 14/20)
- **Source:** Google Generative UI + OTel
- **Description:** After incident, agent generates complete HTML report with timeline, root cause, affected components, RCA tree, and remediation steps.
- **Zenoh Topic:** `c3i/ui/incident/{id}`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3

### 52.  TMR Voting Panel (Score: 14/20)
- **Source:** Generative UI + TMR
- **Description:** 3-panel widget showing Channel A/B/C values side-by-side. Majority highlighted in green. Dissenter marked red. Animation on consensus.
- **Zenoh Topic:** `c3i/ui/tmr`
- **Scores:** Criticality=4, Usability=3, Info Utility=3, UX/CX=4

### 53.  Access Control Graph Visualization (Score: 15/20)
- **Source:** Generative UI + GraphVerification
- **Description:** DOT graph of agent -> method -> file -> decision. Click to highlight paths. Run DFS/BFS live. Color SCCs distinctly.
- **Zenoh Topic:** `c3i/ui/access_graph`
- **Scores:** Criticality=4, Usability=3, Info Utility=5, UX/CX=3

### 54.  Metabolic Homeostasis Dashboard (Score: 14/20)
- **Source:** Generative UI + Metabolic
- **Description:** Multi-gauge panel: CPU set-point dial, energy bar, TPS meter, error rate counter. Governor action (Expand/Maintain/Contract) as background color.
- **Zenoh Topic:** `c3i/ui/metabolic`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=4

### 55.  Podman Container Cards (Score: 15/20)
- **Source:** Generative UI + Podman
- **Description:** Card grid for each container: name, status pill, CPU/memory bars, uptime, image tag. Start/Stop/Restart buttons trigger TOOL_CALLs.
- **Zenoh Topic:** `c3i/ui/podman`
- **Scores:** Criticality=3, Usability=5, Info Utility=3, UX/CX=4

### 56.  Generative Documentation Pages (Score: 14/20)
- **Source:** Google Generative UI
- **Description:** Ask 'explain SafetyKernel Psi checks' and agent generates a full HTML page with diagrams, code examples, and state machine visualizations.
- **Zenoh Topic:** `c3i/ui/docs/{topic}`
- **Scores:** Criticality=2, Usability=4, Info Utility=5, UX/CX=3

### 57.  Timeline Waterfall Chart (Score: 14/20)
- **Source:** Generative UI + OTel
- **Description:** Horizontal waterfall chart showing request lifecycle. Each span as a colored bar. Hover for details. Shows critical path.
- **Zenoh Topic:** `c3i/ui/waterfall`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=4

### 58.  Heatmap of Agent Activity (Score: 13/20)
- **Source:** Generative UI + OTel
- **Description:** Time-of-day vs agent-id heatmap showing activity density. Identifies peak hours, idle agents, and hotspots.
- **Zenoh Topic:** `c3i/ui/heatmap`
- **Scores:** Criticality=2, Usability=3, Info Utility=4, UX/CX=4

### 59.  System Architecture Diagram (Score: 14/20)
- **Source:** Generative UI
- **Description:** Auto-generated architecture diagram showing all services, their connections, protocols, and ports. Updated dynamically from ServiceRegistry.
- **Zenoh Topic:** `c3i/ui/architecture`
- **Scores:** Criticality=2, Usability=4, Info Utility=4, UX/CX=4

### 60.  Interactive Training Sandbox (Score: 12/20)
- **Source:** Google Generative UI
- **Description:** Agent generates fault-scenario training: 'Practice responding to split-brain'. Interactive simulation with injected faults requiring operator remediation.
- **Zenoh Topic:** `c3i/ui/training/{scenario}`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=4


---

## Category 4: Human-in-the-Loop & Safety

### 61.  Two-Key-Turn Operation Confirmation (Score: 17/20)
- **Source:** AG-UI Interrupts + Prajna
- **Description:** Stop/Restart/Scale operations require two-key-turn: first key arms, interrupt pauses, second key confirms. Prevents accidental destructive actions.
- **Zenoh Topic:** `c3i/guardian/two_key/{op}`
- **Scores:** Criticality=5, Usability=5, Info Utility=3, UX/CX=4

### 62.  Agent Steering During OODA (Score: 15/20)
- **Source:** AG-UI Steering
- **Description:** While OODA cycle is running, operator can inject override observations or force a specific Decision. Agent adjusts mid-stream.
- **Zenoh Topic:** `c3i/ooda/{cycle}/steer`
- **Scores:** Criticality=5, Usability=4, Info Utility=3, UX/CX=3

### 63.  Rollback Confirmation Dialog (Score: 16/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Before execute_with_rollback commits a state change, emit TOOL_CALL('frontend_confirm'). User sees before/after diff and approves.
- **Zenoh Topic:** `c3i/safety/rollback/{op}`
- **Scores:** Criticality=5, Usability=4, Info Utility=4, UX/CX=3

### 64.  Constitutional Override Request (Score: 15/20)
- **Source:** AG-UI Interrupts
- **Description:** When a Psi check fails but operator believes it's a false positive, they can request an override. Requires elevated Guardian approval.
- **Zenoh Topic:** `c3i/safety/override/{check}`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 65.  Encrypted Reasoning State (Score: 12/20)
- **Source:** AG-UI ReasoningEncryptedValue
- **Description:** Constitutional reasoning chain encrypted for carry-over across turns. Backend decrypts to maintain continuity. Frontend stores opaquely.
- **Zenoh Topic:** `c3i/safety/encrypted_reasoning`
- **Scores:** Criticality=5, Usability=2, Info Utility=3, UX/CX=2

### 66.  Real-Time Violation Feed (Score: 16/20)
- **Source:** AG-UI CUSTOM + Enforcer
- **Description:** Every access violation emits CUSTOM('violation') with agent, path, reason, severity. Dashboard shows scrolling violation feed.
- **Zenoh Topic:** `c3i/enforcer/violations`
- **Scores:** Criticality=5, Usability=4, Info Utility=4, UX/CX=3

### 67.  Manual Circuit Breaker Reset (Score: 14/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Operator clicks 'Reset Circuit' for a blocked agent. Emits TOOL_CALL('reset_circuit', {agent_id}). Requires Guardian token.
- **Zenoh Topic:** `c3i/enforcer/reset/{agent_id}`
- **Scores:** Criticality=4, Usability=4, Info Utility=3, UX/CX=3

### 68.  Safety Event Timeline (Score: 16/20)
- **Source:** AG-UI ACTIVITY + Safety
- **Description:** Chronological timeline of all safety events: checks passed, violations, overrides, emergency stops. Filterable by severity.
- **Zenoh Topic:** `c3i/safety/timeline`
- **Scores:** Criticality=5, Usability=3, Info Utility=5, UX/CX=3

### 69.  Quarantine Agent Action (Score: 14/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Operator quarantines a suspicious agent via TOOL_CALL('quarantine_agent'). Agent loses all permissions until Guardian lifts quarantine.
- **Zenoh Topic:** `c3i/safety/quarantine/{agent_id}`
- **Scores:** Criticality=5, Usability=3, Info Utility=3, UX/CX=3

### 70.  Compliance Attestation Workflow (Score: 15/20)
- **Source:** AG-UI Interrupts
- **Description:** Before deployment, agent runs verification suite. If all pass, emit interrupt requesting operator attestation signature. Stored as audit record.
- **Zenoh Topic:** `c3i/compliance/attestation`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 71.  Emergency Stop with Mesh Cascade (Score: 16/20)
- **Source:** AG-UI CUSTOM + Zenoh
- **Description:** Emergency stop cascades: first stops local operations, then broadcasts to mesh, then notifies all SSE clients. Three-phase shutdown.
- **Zenoh Topic:** `c3i/emergency/cascade`
- **Scores:** Criticality=5, Usability=4, Info Utility=3, UX/CX=4

### 72.  Safety Kernel Health Monitor (Score: 15/20)
- **Source:** AG-UI STATE_DELTA + Safety
- **Description:** Continuous monitoring of SafetyKernel actor state: is_active, threat_level, guardian_healthy. Any change pushes STATE_DELTA.
- **Zenoh Topic:** `c3i/safety/health`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 73.  Lethal Mutation Gate in UI (Score: 15/20)
- **Source:** AG-UI CUSTOM + Safety
- **Description:** When lethal mutation gate detects dangerous command (rm -rf), emit CUSTOM('lethal_mutation') with command, violation list. Frontend blocks execution.
- **Zenoh Topic:** `c3i/safety/lethal`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 74.  Permission Elevation Workflow (Score: 14/20)
- **Source:** AG-UI Interrupts
- **Description:** Agent requests elevated permissions via interrupt. Operator reviews the operation scope, approves with time limit, agent continues.
- **Zenoh Topic:** `c3i/safety/elevation/{req}`
- **Scores:** Criticality=4, Usability=4, Info Utility=3, UX/CX=3

### 75.  Audit Export to Immutable Log (Score: 13/20)
- **Source:** AG-UI Custom + Safety
- **Description:** All safety events are also exported to an append-only immutable log via Zenoh. Tamper-evident for regulatory compliance.
- **Zenoh Topic:** `c3i/audit/immutable`
- **Scores:** Criticality=5, Usability=2, Info Utility=4, UX/CX=2

### 76.  SIL-6 Compliance Dashboard (Score: 16/20)
- **Source:** AG-UI STATE_SNAPSHOT
- **Description:** Full STATE_SNAPSHOT of all IEC 61508 compliance metrics: STAMP constraint coverage, FMEA scores, test pass rates, NIF status.
- **Zenoh Topic:** `c3i/compliance/sil6`
- **Scores:** Criticality=5, Usability=3, Info Utility=5, UX/CX=3

### 77.  Agent Behavior Anomaly Alert (Score: 15/20)
- **Source:** AG-UI CUSTOM
- **Description:** Behavioral analysis detects unusual patterns (e.g., agent making 100x normal requests). CUSTOM('behavior_anomaly') with details.
- **Zenoh Topic:** `c3i/enforcer/anomaly`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 78.  Proof Token Verification in UI (Score: 13/20)
- **Source:** AG-UI CUSTOM
- **Description:** Display ProofToken validation status for each operation. Green checkmark for valid, red X for invalid, yellow for expired.
- **Zenoh Topic:** `c3i/safety/proof_token`
- **Scores:** Criticality=4, Usability=3, Info Utility=3, UX/CX=3

### 79.  Safety Kernel Activation Toggle (Score: 13/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Operator can activate/deactivate SafetyKernel from dashboard. Requires two-key-turn. Status shown as glowing indicator.
- **Zenoh Topic:** `c3i/safety/activation`
- **Scores:** Criticality=5, Usability=3, Info Utility=2, UX/CX=3

### 80.  Constitutional Check Replay (Score: 14/20)
- **Source:** AG-UI MESSAGES_SNAPSHOT
- **Description:** Replay any past constitutional check sequence. Load the MESSAGES_SNAPSHOT, step through each Psi check result, analyze decisions.
- **Zenoh Topic:** `c3i/safety/replay/{op_id}`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3


---

## Category 5: Dark Cockpit & Situational Awareness

### 81.  Progressive Disclosure Mode (Score: 17/20)
- **Source:** SC-HMI-010 + AG-UI
- **Description:** 5 modes: Dark (>90% healthy), Dim (>70%), Normal, Bright (<30%), Emergency. Transition via STATE_DELTA health score.
- **Zenoh Topic:** `c3i/hmi/mode`
- **Scores:** Criticality=4, Usability=5, Info Utility=3, UX/CX=5

### 82.  Activity-Driven Status Bar (Score: 16/20)
- **Source:** AG-UI ACTIVITY events
- **Description:** Bottom bar shows current ops: 'OODA: Orient [3/5]', 'Sync: Phase 2 [45%]', 'Test: [312/479]'. Updates via ACTIVITY_DELTA.
- **Zenoh Topic:** `c3i/hmi/status_bar`
- **Scores:** Criticality=3, Usability=5, Info Utility=4, UX/CX=4

### 83.  Critical Alert Sound Events (Score: 14/20)
- **Source:** AG-UI CUSTOM + Audio
- **Description:** CUSTOM('sound_alert', {severity}) triggers browser audio. Different tones for warning/error/critical. Operator hears alerts even when not looking.
- **Zenoh Topic:** `c3i/hmi/sound`
- **Scores:** Criticality=4, Usability=4, Info Utility=2, UX/CX=4

### 84.  Anomaly Highlighting via State Delta (Score: 14/20)
- **Source:** AG-UI STATE_DELTA
- **Description:** When a metric crosses a threshold, the STATE_DELTA includes a 'highlight' flag. Frontend pulses the affected element.
- **Zenoh Topic:** `c3i/hmi/highlight`
- **Scores:** Criticality=3, Usability=4, Info Utility=3, UX/CX=4

### 85.  Zen Mode (Minimal Display) (Score: 13/20)
- **Source:** AG-UI Custom
- **Description:** Operator toggles Zen mode: only critical alerts and active OODA cycles visible. Everything else fades to dark. Maximum focus.
- **Zenoh Topic:** `c3i/hmi/zen`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=5

### 86.  Alert Acknowledgment Workflow (Score: 14/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Critical alerts require explicit acknowledgment. TOOL_CALL('acknowledge_alert', {id}). Unacked alerts escalate after timeout.
- **Zenoh Topic:** `c3i/hmi/alerts/ack`
- **Scores:** Criticality=4, Usability=4, Info Utility=3, UX/CX=3

### 87.  Situational Awareness Blink Animation (Score: 13/20)
- **Source:** AG-UI CUSTOM + CockpitZenoh
- **Description:** Critical alarms trigger CSS blink animation on affected container cards. Stops when acknowledged. Per SC-COCKPIT-002.
- **Zenoh Topic:** `c3i/hmi/blink/{container}`
- **Scores:** Criticality=4, Usability=3, Info Utility=2, UX/CX=4

### 88.  Trend Sparklines in Status Cards (Score: 15/20)
- **Source:** AG-UI STATE_DELTA
- **Description:** Each container card shows mini sparklines for last 60s of CPU/memory. Trends visible at a glance. Generated from STATE_DELTA history.
- **Zenoh Topic:** `c3i/hmi/trends/{container}`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=4

### 89.  Color-Blind Accessible Modes (Score: 12/20)
- **Source:** WCAG 2.1 + AG-UI
- **Description:** Dark cockpit uses patterns (stripes, dots, cross-hatching) in addition to colors. Operator selects deuteranopia/protanopia mode.
- **Zenoh Topic:** `c3i/hmi/a11y`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 90.  Keyboard Navigation for All Actions (Score: 12/20)
- **Source:** WCAG 2.1 + AG-UI
- **Description:** All cockpit actions accessible via keyboard shortcuts. Tab order follows logical flow. Screen reader announces AG-UI events.
- **Zenoh Topic:** `c3i/hmi/keyboard`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 91.  Minimap Overview Panel (Score: 13/20)
- **Source:** Generative UI + Cockpit
- **Description:** Zoomable minimap showing entire mesh at a glance. Click to zoom into any section. Current view highlighted as a viewport box.
- **Zenoh Topic:** `c3i/hmi/minimap`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=4

### 92.  Log Level Toggle per Container (Score: 13/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Operator adjusts log level per container from cockpit: TOOL_CALL('set_log_level', {container, level}). Changes propagate via Zenoh.
- **Zenoh Topic:** `c3i/hmi/loglevel/{container}`
- **Scores:** Criticality=3, Usability=4, Info Utility=3, UX/CX=3

### 93.  Health Score Trendline (Score: 14/20)
- **Source:** AG-UI STATE_DELTA
- **Description:** Composite health score (0-100) plotted over time. Declining trend triggers predictive warning before actual failure.
- **Zenoh Topic:** `c3i/hmi/health_trend`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 94.  Auto-Layout Dashboard Panels (Score: 14/20)
- **Source:** Generative UI + HMI
- **Description:** Dashboard panels automatically rearrange based on alert state. Critical alerts expand, healthy components shrink. Priority-based layout.
- **Zenoh Topic:** `c3i/hmi/layout`
- **Scores:** Criticality=3, Usability=4, Info Utility=3, UX/CX=4

### 95.  Night Vision Mode (Score: 11/20)
- **Source:** HMI + Dark Cockpit
- **Description:** Red-on-black color scheme for nighttime operations. Preserves dark adaptation. All UI elements use deep red shades.
- **Zenoh Topic:** `c3i/hmi/nightvision`
- **Scores:** Criticality=2, Usability=3, Info Utility=2, UX/CX=4

### 96.  Contextual Tooltip System (Score: 15/20)
- **Source:** AG-UI + Generative UI
- **Description:** Hover over any metric to see AI-generated contextual explanation: what the metric means, why it's at current level, what action to take.
- **Zenoh Topic:** `c3i/hmi/tooltips`
- **Scores:** Criticality=2, Usability=5, Info Utility=4, UX/CX=4

### 97.  Multi-Monitor Support (Score: 13/20)
- **Source:** AG-UI + HMI
- **Description:** Different SSE streams per monitor: Monitor 1 = mesh overview, Monitor 2 = planning, Monitor 3 = telemetry. Each is an independent AG-UI client.
- **Zenoh Topic:** `c3i/hmi/monitor/{n}`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=4

### 98.  Ambient Background Color by Health (Score: 13/20)
- **Source:** HMI + AG-UI STATE_DELTA
- **Description:** Dashboard background subtly shifts: dark green (healthy) -> warm amber (degraded) -> deep red (critical). Peripheral vision cue.
- **Zenoh Topic:** `c3i/hmi/ambient`
- **Scores:** Criticality=3, Usability=3, Info Utility=2, UX/CX=5

### 99.  Pin Important Metrics (Score: 13/20)
- **Source:** AG-UI + HMI
- **Description:** Operator pins specific metrics to always-visible top bar. Pinned items persist across sessions via Zenoh state store.
- **Zenoh Topic:** `c3i/hmi/pins`
- **Scores:** Criticality=2, Usability=5, Info Utility=3, UX/CX=3

### 100.  Notification Center (Score: 15/20)
- **Source:** AG-UI CUSTOM
- **Description:** Sliding notification panel showing history of all CUSTOM events: violations, alerts, approvals, tool calls. Filterable, searchable, dismissable.
- **Zenoh Topic:** `c3i/hmi/notifications`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=4


---

## Category 6: OTel Golden Triangle

### 101.  Token Cost Tracker per MCP Tool (Score: 14/20)
- **Source:** Golden Triangle + OTel
- **Description:** Track LLM token consumption per tool call. CUSTOM('token_usage', {tool, input, output, cost}). Dashboard shows cumulative cost breakdown.
- **Zenoh Topic:** `c3i/otel/cost`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3

### 102.  Distributed Trace Visualization (Score: 14/20)
- **Source:** Golden Triangle + OTel
- **Description:** Full distributed trace from HTTP request through Gleam -> Zenoh -> Cortex -> DB and back. Rendered as connected spans.
- **Zenoh Topic:** `c3i/otel/traces`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3

### 103.  Latency Percentile Dashboard (Score: 14/20)
- **Source:** OTel Metrics
- **Description:** P50/P95/P99 latency charts for each endpoint. Alerts when P99 exceeds threshold. Historical comparison.
- **Zenoh Topic:** `c3i/otel/latency`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3

### 104.  Error Rate Monitoring (Score: 14/20)
- **Source:** OTel Metrics
- **Description:** Error rate per service/endpoint. Spike detection triggers CUSTOM('error_spike'). Correlated with recent deployments.
- **Zenoh Topic:** `c3i/otel/errors`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 105.  Prometheus Query Builder (Score: 14/20)
- **Source:** OTel + Generative UI
- **Description:** Agent generates Prometheus queries from natural language: 'show me CPU usage for the last hour' -> PromQL query -> chart.
- **Zenoh Topic:** `c3i/otel/promql`
- **Scores:** Criticality=2, Usability=4, Info Utility=4, UX/CX=4

### 106.  Service Dependency Map from Traces (Score: 14/20)
- **Source:** OTel + Generative UI
- **Description:** Auto-generate service dependency map from OTel trace data. Shows which services call which, with latency on edges.
- **Zenoh Topic:** `c3i/otel/dependency`
- **Scores:** Criticality=2, Usability=3, Info Utility=5, UX/CX=4

### 107.  OODA Cycle Performance Metrics (Score: 14/20)
- **Source:** OTel + SC-ORCH-004
- **Description:** Track OODA cycle time vs 100ms target. Histogram of cycle times. Alert when trending above threshold.
- **Zenoh Topic:** `c3i/otel/ooda`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 108.  Memory Leak Detection (Score: 12/20)
- **Source:** OTel Metrics
- **Description:** Track BEAM process memory over time. Detect monotonically increasing memory (leak indicator). Alert with process ID.
- **Zenoh Topic:** `c3i/otel/memory`
- **Scores:** Criticality=4, Usability=2, Info Utility=4, UX/CX=2

### 109.  Log Volume Analytics (Score: 13/20)
- **Source:** OTel + Generative UI
- **Description:** Chart log volume by level over time. Spike in error logs triggers investigation workflow. Agent suggests root cause.
- **Zenoh Topic:** `c3i/otel/log_volume`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 110.  SLA Dashboard (Score: 13/20)
- **Source:** OTel Metrics
- **Description:** Service Level Agreement tracking: uptime %, error budget remaining, latency targets. Shows burn rate.
- **Zenoh Topic:** `c3i/otel/sla`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 111.  Zenoh Message Rate Metrics (Score: 13/20)
- **Source:** OTel + Zenoh
- **Description:** Track messages/sec per Zenoh topic. Identify hot topics, silent topics, and unusual spikes.
- **Zenoh Topic:** `c3i/otel/zenoh_rate`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 112.  DB Query Performance (Score: 13/20)
- **Source:** OTel + DuckDB
- **Description:** Track DuckDB query execution times. Identify slow queries. Show query plan visualization.
- **Zenoh Topic:** `c3i/otel/db`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 113.  NIF Call Latency Tracking (Score: 12/20)
- **Source:** OTel + Rust NIFs
- **Description:** Track Rust NIF call latency: zenoh_open, zenoh_put, sqrt, etc. Detect NIF loading failures.
- **Zenoh Topic:** `c3i/otel/nif`
- **Scores:** Criticality=4, Usability=2, Info Utility=4, UX/CX=2

### 114.  Grafana Dashboard Auto-Link (Score: 13/20)
- **Source:** Golden Triangle
- **Description:** AG-UI CUSTOM events include Grafana dashboard deep links. Clicking 'Details' opens the relevant Grafana panel.
- **Zenoh Topic:** `c3i/otel/grafana`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=4

### 115.  Alert Correlation Engine (Score: 14/20)
- **Source:** OTel + AG-UI
- **Description:** Correlate multiple OTel alerts into a single incident. 'High CPU' + 'Slow queries' + 'Memory spike' = 'Resource exhaustion incident'.
- **Zenoh Topic:** `c3i/otel/correlate`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3

### 116.  Capacity Planning Projections (Score: 14/20)
- **Source:** OTel + Generative UI
- **Description:** Agent analyzes resource trends and generates capacity projection charts. Shows when resources will be exhausted at current growth rate.
- **Zenoh Topic:** `c3i/otel/capacity`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3

### 117.  Cost Optimization Recommendations (Score: 13/20)
- **Source:** Golden Triangle + OTel
- **Description:** Agent analyzes token usage, resource consumption, and suggests optimizations: 'Switch to smaller model for planning_query saves 40% tokens'.
- **Zenoh Topic:** `c3i/otel/optimize`
- **Scores:** Criticality=2, Usability=4, Info Utility=4, UX/CX=3

### 118.  Real-Time Request Tracing (Score: 14/20)
- **Source:** OTel + AG-UI SSE
- **Description:** Tag an incoming request and trace it through the entire stack in real-time. Each hop emits a STEP event.
- **Zenoh Topic:** `c3i/otel/trace/{id}`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=4

### 119.  Comparison Mode (Before/After) (Score: 13/20)
- **Source:** OTel + Generative UI
- **Description:** Compare metrics from two time windows side-by-side. Agent generates diff visualization highlighting significant changes.
- **Zenoh Topic:** `c3i/otel/compare`
- **Scores:** Criticality=2, Usability=3, Info Utility=4, UX/CX=4

### 120.  Health Score Calculation Transparency (Score: 14/20)
- **Source:** OTel + AG-UI REASONING
- **Description:** Show how composite health score is calculated: weights for CPU, memory, errors, latency. REASONING events explain each factor.
- **Zenoh Topic:** `c3i/otel/health_calc`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=3


---

## Category 7: MCP Tool Ecosystem

### 121.  zenoh_subscribe Tool (Score: 15/20)
- **Source:** MCP + Zenoh
- **Description:** New MCP tool that subscribes to a Zenoh topic and streams messages back as TOOL_CALL_RESULT events. Live data feed to the agent.
- **Zenoh Topic:** `c3i/mcp/zenoh_sub/*`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=3

### 122.  container_manage Tool (Score: 15/20)
- **Source:** MCP + Podman
- **Description:** MCP tool for container operations: list, start, stop, restart, inspect. Returns structured ContainerInfo.
- **Zenoh Topic:** `c3i/mcp/podman/*`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=3

### 123.  graph_query Tool (Score: 15/20)
- **Source:** MCP + Knowledge
- **Description:** Query the knowledge graph by node type, relationship, or semantic similarity. Returns matching nodes and paths.
- **Zenoh Topic:** `c3i/mcp/knowledge/*`
- **Scores:** Criticality=3, Usability=4, Info Utility=5, UX/CX=3

### 124.  anomaly_detect Tool (Score: 14/20)
- **Source:** MCP + Anomaly
- **Description:** Run anomaly detection on specified metrics with configurable thresholds. Returns list of detected anomalies.
- **Zenoh Topic:** `c3i/mcp/anomaly/*`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 125.  cryocore_archive Tool (Score: 11/20)
- **Source:** MCP + Indrajaal.Ark
- **Description:** Create or restore system snapshots. Archive creates GZip tarball, restore unpacks to specified path.
- **Zenoh Topic:** `c3i/mcp/cryocore/*`
- **Scores:** Criticality=3, Usability=3, Info Utility=3, UX/CX=2

### 126.  Tool Output Streaming (Score: 15/20)
- **Source:** AG-UI Tool Output Streaming
- **Description:** Long-running tools (verification_run) stream partial results via TOOL_CALL_RESULT with intermediate data.
- **Zenoh Topic:** `c3i/mcp/stream/{id}`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=4

### 127.  Tool Chain Orchestration (Score: 14/20)
- **Source:** MCP + AG-UI STEP
- **Description:** Chain tools: planning_query -> verification_run -> report_generate. Each step emitted as AG-UI STEP event.
- **Zenoh Topic:** `c3i/mcp/chain/{id}`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=3

### 128.  Frontend-Executed Tools (Score: 13/20)
- **Source:** AG-UI Frontend Tools
- **Description:** Some tools execute in the browser: clipboard_read, screenshot, local_file_browse. Agent requests, frontend executes, result sent back.
- **Zenoh Topic:** `c3i/mcp/frontend/*`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=4

### 129.  execute_gleam Tool (Score: 14/20)
- **Source:** MCP + Gleam
- **Description:** Execute arbitrary Gleam expressions in a sandboxed BEAM environment. Returns the result. For interactive exploration.
- **Zenoh Topic:** `c3i/mcp/gleam_eval`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=3

### 130.  ooda_trigger Tool (Score: 14/20)
- **Source:** MCP + OODA
- **Description:** Manually trigger an OODA cycle with specified observations. Returns the full Observe->Orient->Decide->Act chain.
- **Zenoh Topic:** `c3i/mcp/ooda/trigger`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=3

### 131.  safety_check Tool (Score: 15/20)
- **Source:** MCP + SafetyKernel
- **Description:** Run all constitutional checks (Psi-0..5, Omega-0) against a proposed operation. Returns structured SafetyResult list.
- **Zenoh Topic:** `c3i/mcp/safety/check`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 132.  mesh_health Tool (Score: 15/20)
- **Source:** MCP + Prajna
- **Description:** Aggregate health from all mesh nodes. Returns composite health score, per-node status, and recommendations.
- **Zenoh Topic:** `c3i/mcp/mesh/health`
- **Scores:** Criticality=4, Usability=4, Info Utility=4, UX/CX=3

### 133.  generate_report Tool (Score: 13/20)
- **Source:** MCP + Generative UI
- **Description:** Generate comprehensive system report as HTML. Includes all domain states, metrics, compliance status.
- **Zenoh Topic:** `c3i/mcp/report/generate`
- **Scores:** Criticality=2, Usability=3, Info Utility=5, UX/CX=3

### 134.  diff_state Tool (Score: 13/20)
- **Source:** MCP + State
- **Description:** Compare two state snapshots and return JSON Patch diff. Useful for understanding what changed between two points in time.
- **Zenoh Topic:** `c3i/mcp/state/diff`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 135.  search_logs Tool (Score: 14/20)
- **Source:** MCP + OTel
- **Description:** Search OTel logs by keyword, time range, severity. Returns matching log entries with context.
- **Zenoh Topic:** `c3i/mcp/logs/search`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=3

### 136.  explain_error Tool (Score: 15/20)
- **Source:** MCP + OODA Orient
- **Description:** Given an error message, classify it using OODA Orient patterns and suggest remediation steps.
- **Zenoh Topic:** `c3i/mcp/error/explain`
- **Scores:** Criticality=3, Usability=5, Info Utility=4, UX/CX=3

### 137.  schedule_task Tool (Score: 13/20)
- **Source:** MCP + Planning
- **Description:** Schedule a task for future execution with cron-like syntax. Returns scheduled task ID and next execution time.
- **Zenoh Topic:** `c3i/mcp/planning/schedule`
- **Scores:** Criticality=3, Usability=4, Info Utility=3, UX/CX=3

### 138.  export_audit Tool (Score: 13/20)
- **Source:** MCP + Safety
- **Description:** Export safety audit log for specified time range. Returns JSON array of all safety events.
- **Zenoh Topic:** `c3i/mcp/audit/export`
- **Scores:** Criticality=4, Usability=3, Info Utility=4, UX/CX=2

### 139.  Tool Permissions Matrix (Score: 11/20)
- **Source:** MCP + Enforcer
- **Description:** Each MCP tool has an access matrix defining which agent types can call it. Enforcer checks before execution.
- **Zenoh Topic:** `c3i/mcp/permissions`
- **Scores:** Criticality=4, Usability=2, Info Utility=3, UX/CX=2

### 140.  Tool Usage Analytics (Score: 12/20)
- **Source:** MCP + OTel
- **Description:** Track which tools are called most, average latency, success/failure rates. Optimize tool implementations.
- **Zenoh Topic:** `c3i/mcp/analytics`
- **Scores:** Criticality=2, Usability=3, Info Utility=4, UX/CX=3


---

## Category 8: Multi-Modal & Accessibility

### 141.  Voice Command Input (Score: 12/20)
- **Source:** AG-UI Multimodality
- **Description:** Operator speaks commands. Browser speech recognition transcribes. Sent as AG-UI user message. Agent responds with text + UI updates.
- **Zenoh Topic:** `c3i/modal/voice/input`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 142.  Voice Alert Output (Score: 14/20)
- **Source:** AG-UI Multimodality
- **Description:** Critical safety events trigger browser speech synthesis: 'Warning: CPU threshold exceeded on zenoh-router-2'. Hands-free awareness.
- **Zenoh Topic:** `c3i/modal/voice/output`
- **Scores:** Criticality=3, Usability=4, Info Utility=3, UX/CX=4

### 143.  Screenshot Attachment (Score: 11/20)
- **Source:** AG-UI Multimodality
- **Description:** Operator captures screenshot and attaches to AG-UI message. Agent can analyze it (if vision-capable) or store for incident report.
- **Zenoh Topic:** `c3i/modal/image/attach`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=3

### 144.  Generated Architecture Diagrams (Score: 13/20)
- **Source:** AG-UI Multimodality + GenUI
- **Description:** Agent generates SVG architecture diagrams and sends as image attachment. Operator sees visual representation of system state.
- **Zenoh Topic:** `c3i/modal/image/generate`
- **Scores:** Criticality=2, Usability=3, Info Utility=4, UX/CX=4

### 145.  ARIA Labels for All Widgets (Score: 12/20)
- **Source:** WCAG 2.1
- **Description:** All generative UI widgets include proper ARIA labels, roles, and live regions. Screen readers announce state changes.
- **Zenoh Topic:** `c3i/a11y/aria`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 146.  High Contrast Mode (Score: 11/20)
- **Source:** WCAG 2.1 + HMI
- **Description:** Force high contrast colors for all UI elements. White on black for maximum readability. Toggleable from cockpit.
- **Zenoh Topic:** `c3i/a11y/contrast`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=3

### 147.  Mobile-Responsive Cockpit (Score: 12/20)
- **Source:** AG-UI + CSS
- **Description:** Dashboard adapts to mobile screen: single column, swipeable pages, touch-friendly buttons. SSE still works on mobile.
- **Zenoh Topic:** `c3i/a11y/mobile`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 148.  Text-to-Speech for Reasoning (Score: 11/20)
- **Source:** AG-UI REASONING + TTS
- **Description:** Constitutional reasoning chain read aloud via browser TTS. Useful for operators who are monitoring multiple screens.
- **Zenoh Topic:** `c3i/modal/tts/reasoning`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=3

### 149.  Haptic Feedback for Alerts (Score: 9/20)
- **Source:** AG-UI + Mobile
- **Description:** On mobile devices, critical alerts trigger haptic vibration pattern. Different patterns for warning/error/critical.
- **Zenoh Topic:** `c3i/modal/haptic`
- **Scores:** Criticality=2, Usability=3, Info Utility=1, UX/CX=3

### 150.  Internationalization (i18n) (Score: 10/20)
- **Source:** AG-UI + Generative UI
- **Description:** Agent generates UI in the operator's preferred language. Metric labels, alert descriptions, tooltips all localized.
- **Zenoh Topic:** `c3i/a11y/i18n`
- **Scores:** Criticality=1, Usability=3, Info Utility=2, UX/CX=4

### 151.  Reduced Motion Mode (Score: 9/20)
- **Source:** WCAG 2.1
- **Description:** Disable all animations for vestibular sensitivity. Sparklines become static bars. Blink alerts become solid colors.
- **Zenoh Topic:** `c3i/a11y/motion`
- **Scores:** Criticality=1, Usability=3, Info Utility=2, UX/CX=3

### 152.  PDF Export of Dashboard (Score: 11/20)
- **Source:** AG-UI + Generative UI
- **Description:** Export current dashboard state as a PDF report. Generated by agent with all current metrics and charts rendered to static images.
- **Zenoh Topic:** `c3i/modal/pdf`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=3

### 153.  Clipboard Integration (Score: 10/20)
- **Source:** AG-UI Frontend Tools
- **Description:** TOOL_CALL('clipboard_write', {content}) copies data to clipboard. Useful for sharing metrics, IDs, or configurations.
- **Zenoh Topic:** `c3i/modal/clipboard`
- **Scores:** Criticality=1, Usability=4, Info Utility=2, UX/CX=3

### 154.  Custom Keyboard Shortcuts (Score: 11/20)
- **Source:** AG-UI + HMI
- **Description:** Operator defines custom keyboard shortcuts for frequent actions: Ctrl+O = OODA cycle, Ctrl+E = emergency stop, etc.
- **Zenoh Topic:** `c3i/a11y/shortcuts`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=3

### 155.  Dyslexia-Friendly Font Option (Score: 8/20)
- **Source:** WCAG 2.1
- **Description:** Toggle to OpenDyslexic font for all UI text. Improves readability for dyslexic operators.
- **Zenoh Topic:** `c3i/a11y/font`
- **Scores:** Criticality=1, Usability=3, Info Utility=1, UX/CX=3

### 156.  Tab Panel Focus Management (Score: 9/20)
- **Source:** WCAG 2.1
- **Description:** Tab through dashboard panels in logical order. Focus ring visible. Active panel announced by screen reader.
- **Zenoh Topic:** `c3i/a11y/focus`
- **Scores:** Criticality=1, Usability=3, Info Utility=2, UX/CX=3

### 157.  Audio Transcription for Incident Reports (Score: 11/20)
- **Source:** AG-UI Multimodality
- **Description:** Operator records voice memo about an incident. Transcribed and attached to the incident report automatically.
- **Zenoh Topic:** `c3i/modal/transcribe`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=3

### 158.  Color Theme Customization (Score: 9/20)
- **Source:** AG-UI + Generative UI
- **Description:** Agent generates CSS theme from natural language: 'aerospace blue', 'NASA mission control', 'cyber green'. Applied to entire cockpit.
- **Zenoh Topic:** `c3i/modal/theme`
- **Scores:** Criticality=1, Usability=3, Info Utility=1, UX/CX=4

### 159.  Widget Size Customization (Score: 11/20)
- **Source:** AG-UI + HMI
- **Description:** Operator resizes dashboard widgets by dragging edges. Layout persisted via Zenoh state store. Each operator has personal layout.
- **Zenoh Topic:** `c3i/hmi/widget_size`
- **Scores:** Criticality=1, Usability=4, Info Utility=2, UX/CX=4

### 160.  Multi-Language Agent Responses (Score: 10/20)
- **Source:** AG-UI TEXT_MESSAGE
- **Description:** Agent responds in the operator's preferred language. Safety alerts always include English alongside the localized version.
- **Zenoh Topic:** `c3i/modal/language`
- **Scores:** Criticality=2, Usability=3, Info Utility=2, UX/CX=3


---

## Category 9: State Management & Persistence

### 161.  Run History with Branching (Score: 14/20)
- **Source:** AG-UI parentRunId
- **Description:** Every agent run stores parentRunId creating a git-like log. UI shows run tree. Branch from any point to explore alternatives.
- **Zenoh Topic:** `c3i/state/runs`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=3

### 162.  Thread Persistence Across Sessions (Score: 14/20)
- **Source:** AG-UI threadId
- **Description:** Conversation threads persist in DuckDB. Operator resumes where they left off. Full message history available.
- **Zenoh Topic:** `c3i/state/threads`
- **Scores:** Criticality=2, Usability=5, Info Utility=3, UX/CX=4

### 163.  State Rollback (Time-Travel) (Score: 13/20)
- **Source:** AG-UI STATE_SNAPSHOT
- **Description:** Store periodic STATE_SNAPSHOTs. Operator can 'rewind' to any past state and inspect. Useful for debugging.
- **Zenoh Topic:** `c3i/state/rollback`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 164.  Cross-Session State via Zenoh (Score: 12/20)
- **Source:** Zenoh + AG-UI
- **Description:** Dashboard state (pinned metrics, layout, preferences) stored in Zenoh key-value store. Available from any client.
- **Zenoh Topic:** `c3i/state/preferences/{user}`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 165.  Collaborative Multi-Operator View (Score: 13/20)
- **Source:** AG-UI Shared State + Zenoh
- **Description:** Multiple operators share same SSE stream via Zenoh broadcast. One operator's actions (approvals, task updates) visible to all.
- **Zenoh Topic:** `c3i/state/collab`
- **Scores:** Criticality=3, Usability=4, Info Utility=3, UX/CX=3

### 166.  Operator Cursor Presence (Score: 10/20)
- **Source:** AG-UI Shared State
- **Description:** Like Google Docs: each operator's cursor/focus visible to others. See who is looking at which section of the dashboard.
- **Zenoh Topic:** `c3i/state/cursors`
- **Scores:** Criticality=1, Usability=3, Info Utility=2, UX/CX=4

### 167.  Undo/Redo for Operations (Score: 13/20)
- **Source:** AG-UI STATE_SNAPSHOT
- **Description:** Operator can undo last action (task status change, config update). STATE_SNAPSHOT provides the checkpoint for rollback.
- **Zenoh Topic:** `c3i/state/undo`
- **Scores:** Criticality=3, Usability=4, Info Utility=2, UX/CX=4

### 168.  Bookmark Important States (Score: 12/20)
- **Source:** AG-UI + State
- **Description:** Operator bookmarks a STATE_SNAPSHOT with a label: 'before deployment', 'after hotfix'. Quick comparison between bookmarks.
- **Zenoh Topic:** `c3i/state/bookmarks`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=3

### 169.  State Diff Between Bookmarks (Score: 12/20)
- **Source:** AG-UI STATE_DELTA
- **Description:** Select two bookmarked states and see the JSON Patch diff. Highlights exactly what changed.
- **Zenoh Topic:** `c3i/state/diff`
- **Scores:** Criticality=2, Usability=3, Info Utility=4, UX/CX=3

### 170.  Auto-Save Dashboard Configuration (Score: 11/20)
- **Source:** AG-UI + Zenoh
- **Description:** Dashboard layout, active filters, pinned items auto-save every 30s to Zenoh KV store. Never lose your workspace.
- **Zenoh Topic:** `c3i/state/autosave/{user}`
- **Scores:** Criticality=1, Usability=4, Info Utility=2, UX/CX=4

### 171.  Session Recording and Replay (Score: 13/20)
- **Source:** AG-UI Events
- **Description:** Record all AG-UI events during a session. Replay later for training, debugging, or audit. Like a DVR for the cockpit.
- **Zenoh Topic:** `c3i/state/recording/{id}`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=3

### 172.  State Schema Versioning (Score: 10/20)
- **Source:** AG-UI + MSTS
- **Description:** STATE_SNAPSHOT includes schema version. Frontend handles schema migrations gracefully when server updates.
- **Zenoh Topic:** `c3i/state/schema/version`
- **Scores:** Criticality=3, Usability=2, Info Utility=3, UX/CX=2

### 173.  Optimistic UI Updates (Score: 12/20)
- **Source:** AG-UI STATE_DELTA
- **Description:** Frontend applies state changes optimistically before server confirms. Reverts if server-side validation fails. Snappy UX.
- **Zenoh Topic:** `c3i/state/optimistic`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 174.  Conflict Resolution for Shared State (Score: 12/20)
- **Source:** AG-UI + Zenoh
- **Description:** When two operators modify the same state simultaneously, Zenoh vector clocks detect conflict. UI shows merge dialog.
- **Zenoh Topic:** `c3i/state/conflict`
- **Scores:** Criticality=3, Usability=3, Info Utility=3, UX/CX=3

### 175.  Offline Mode with Sync (Score: 12/20)
- **Source:** AG-UI + State
- **Description:** Dashboard works offline using cached STATE_SNAPSHOT. When reconnected, STATE_DELTA stream catches up. No data loss.
- **Zenoh Topic:** `c3i/state/offline`
- **Scores:** Criticality=2, Usability=4, Info Utility=2, UX/CX=4

### 176.  State Export/Import (Score: 9/20)
- **Source:** AG-UI + State
- **Description:** Export entire dashboard state as JSON file. Import on another machine. Useful for sharing configurations between operators.
- **Zenoh Topic:** `c3i/state/export`
- **Scores:** Criticality=1, Usability=3, Info Utility=2, UX/CX=3

### 177.  Event Sourcing for All Changes (Score: 12/20)
- **Source:** AG-UI + Safety
- **Description:** All state mutations stored as an event log (not just final state). Complete history reconstructable from events.
- **Zenoh Topic:** `c3i/state/events`
- **Scores:** Criticality=4, Usability=2, Info Utility=4, UX/CX=2

### 178.  State Snapshot Compression (Score: 9/20)
- **Source:** AG-UI + Performance
- **Description:** Large STATE_SNAPSHOTs compressed with gzip before SSE transmission. Reduces bandwidth by ~70% for initial load.
- **Zenoh Topic:** `c3i/state/compressed`
- **Scores:** Criticality=2, Usability=2, Info Utility=2, UX/CX=3

### 179.  Selective State Subscription (Score: 11/20)
- **Source:** AG-UI + Performance
- **Description:** Client subscribes to specific state subtrees (e.g., only planning, not telemetry). Reduces event volume for focused views.
- **Zenoh Topic:** `c3i/state/subscribe/{path}`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=3

### 180.  State Garbage Collection (Score: 8/20)
- **Source:** AG-UI + Performance
- **Description:** Old STATE_SNAPSHOTs automatically pruned after retention period. Configurable per-domain (safety: 365d, telemetry: 7d).
- **Zenoh Topic:** `c3i/state/gc`
- **Scores:** Criticality=2, Usability=2, Info Utility=2, UX/CX=2


---

## Category 10: Advanced & Future

### 181.  A2UI Declarative Widget Specs (Score: 16/20)
- **Source:** Google A2UI Spec
- **Description:** C3I defines domain-specific A2UI widget schemas: MeshNodeGrid, ComplianceMatrix, SparklineChart. Agents propose widget trees, frontend validates and mounts.
- **Zenoh Topic:** `c3i/a2ui/widgets`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=5

### 182.  MCP-UI Iframe Embedding (Score: 13/20)
- **Source:** Microsoft MCP-UI
- **Description:** External tools (Grafana, Prometheus, custom dashboards) embedded as MCP-UI iframes within the cockpit. Agent manages iframe lifecycle.
- **Zenoh Topic:** `c3i/mcp_ui/iframe/*`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=4

### 183.  Open-JSON-UI for Structured Responses (Score: 14/20)
- **Source:** OpenAI Open-JSON-UI
- **Description:** Agent responses follow Open-JSON-UI schema for consistent structured rendering. Tables, lists, code blocks all typed.
- **Zenoh Topic:** `c3i/ojui/responses`
- **Scores:** Criticality=2, Usability=4, Info Utility=4, UX/CX=4

### 184.  Self-Healing Mesh via AG-UI Feedback (Score: 15/20)
- **Source:** AG-UI + A2A + OODA
- **Description:** OODA cycle detects failure, AG-UI interrupts for human approval, Zenoh A2A coordinates recovery across mesh. Closed-loop self-healing.
- **Zenoh Topic:** `c3i/self_heal/{incident}`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 185.  Digital Twin Generative Visualization (Score: 15/20)
- **Source:** Generative UI + Chaya
- **Description:** Agent generates a visual digital twin of the mesh: containers, connections, data flow, health states. Interactive and explorable.
- **Zenoh Topic:** `c3i/digital_twin/viz`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=5

### 186.  Predictive Maintenance Dashboard (Score: 15/20)
- **Source:** OTel + Generative UI
- **Description:** Agent analyzes trends and predicts when components will fail. Generates timeline showing predicted failure dates and recommended actions.
- **Zenoh Topic:** `c3i/predict/maintenance`
- **Scores:** Criticality=4, Usability=3, Info Utility=5, UX/CX=3

### 187.  Natural Language System Configuration (Score: 15/20)
- **Source:** AG-UI + MCP
- **Description:** Operator says 'increase the OODA cycle frequency to every 10 seconds'. Agent translates to config change, seeks approval, applies.
- **Zenoh Topic:** `c3i/config/nlp`
- **Scores:** Criticality=3, Usability=5, Info Utility=3, UX/CX=4

### 188.  Generative Runbook Creation (Score: 15/20)
- **Source:** Google Generative UI + Safety
- **Description:** Agent generates interactive runbooks for incident response. Step-by-step guide with clickable actions that trigger actual operations.
- **Zenoh Topic:** `c3i/runbook/generate`
- **Scores:** Criticality=3, Usability=4, Info Utility=4, UX/CX=4

### 189.  Agent Marketplace via Zenoh (Score: 12/20)
- **Source:** A2A + Zenoh
- **Description:** Agents advertise capabilities on c3i/marketplace. Operator can 'install' new agents that auto-register with ServiceRegistry.
- **Zenoh Topic:** `c3i/marketplace`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=4

### 190.  Federated Learning Across Holons (Score: 11/20)
- **Source:** A2A + Zenoh
- **Description:** Each holon trains local anomaly model. Federated learning aggregates models via Zenoh without sharing raw data.
- **Zenoh Topic:** `c3i/federated/model`
- **Scores:** Criticality=3, Usability=2, Info Utility=4, UX/CX=2

### 191.  Explainable AI Dashboard (Score: 15/20)
- **Source:** AG-UI REASONING + Generative UI
- **Description:** For every AI decision, generate an explanation page showing: input features, model weights, decision boundary, confidence score.
- **Zenoh Topic:** `c3i/xai/explain/{decision}`
- **Scores:** Criticality=3, Usability=3, Info Utility=5, UX/CX=4

### 192.  Chaos Engineering Console (Score: 14/20)
- **Source:** Generative UI + Immune
- **Description:** Interactive chaos engineering interface: select fault type (CPU spike, network partition, memory leak), target container, duration. Execute and observe.
- **Zenoh Topic:** `c3i/chaos/console`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=4

### 193.  Regulatory Compliance Report Generator (Score: 15/20)
- **Source:** Generative UI + Safety
- **Description:** Agent generates full IEC 61508 / DO-178C compliance report with evidence mapping: requirement -> test -> result -> artifact.
- **Zenoh Topic:** `c3i/compliance/report`
- **Scores:** Criticality=4, Usability=3, Info Utility=5, UX/CX=3

### 194.  Agent Performance Leaderboard (Score: 12/20)
- **Source:** OTel + AG-UI
- **Description:** Rank agents by: response time, success rate, resource efficiency. Gamified view showing top performers.
- **Zenoh Topic:** `c3i/agents/leaderboard`
- **Scores:** Criticality=2, Usability=3, Info Utility=3, UX/CX=4

### 195.  Zero-Trust Agent Onboarding (Score: 13/20)
- **Source:** AG-UI Interrupts + Safety
- **Description:** New agent must pass constitutional checks, capability verification, and operator approval before joining mesh. AG-UI interrupt for human review.
- **Zenoh Topic:** `c3i/onboard/{agent_id}`
- **Scores:** Criticality=4, Usability=3, Info Utility=3, UX/CX=3

### 196.  Semantic Zoom in Dashboard (Score: 14/20)
- **Source:** Generative UI + HMI
- **Description:** Zoom out: see entire mesh as abstract boxes. Zoom in: see individual metrics, logs, traces. Continuous semantic zoom.
- **Zenoh Topic:** `c3i/ui/semantic_zoom`
- **Scores:** Criticality=2, Usability=4, Info Utility=3, UX/CX=5

### 197.  AR Overlay for Physical Infrastructure (Score: 11/20)
- **Source:** AG-UI Multimodality + AR
- **Description:** Augmented reality overlay shows container health when pointing phone at server rack. AG-UI events stream to AR app.
- **Zenoh Topic:** `c3i/modal/ar`
- **Scores:** Criticality=1, Usability=2, Info Utility=3, UX/CX=5

### 198.  Generative Test Scenario Builder (Score: 14/20)
- **Source:** Generative UI + Verification
- **Description:** Agent generates interactive test scenario builder: select fractal layer, component, failure mode. Auto-generates test code.
- **Zenoh Topic:** `c3i/test/builder`
- **Scores:** Criticality=3, Usability=3, Info Utility=4, UX/CX=4

### 199.  Autonomous Recovery Orchestration (Score: 15/20)
- **Source:** AG-UI + A2A + OODA + Safety
- **Description:** Full autonomous recovery: OODA detects failure -> A2A coordinates agents -> AG-UI shows progress -> Safety validates -> Guardian approves if needed.
- **Zenoh Topic:** `c3i/recovery/auto/{incident}`
- **Scores:** Criticality=5, Usability=3, Info Utility=4, UX/CX=3

### 200.  Recursive Meta-Agent for System Evolution (Score: 14/20)
- **Source:** AG-UI + A2A + Generative UI
- **Description:** A meta-agent that observes system performance, proposes architectural improvements, generates implementation plans, and (with approval) evolves the system.
- **Zenoh Topic:** `c3i/meta/evolution`
- **Scores:** Criticality=4, Usability=2, Info Utility=5, UX/CX=3


---

## Summary: Top 50 Ideas by Score

| Rank | # | Idea | Score | Crit | Usab | Info | UX |
|:----:|:-:|------|:-----:|:----:|:----:|:----:|:--:|
| 1 | 1 | OODA Cycle SSE Lifecycle | 20 | 5 | 5 | 5 | 5 |
| 2 | 2 | Safety Kernel Constitutional Reasoning Stream | 20 | 5 | 5 | 5 | 5 |
| 3 | 3 | Guardian Approval Interrupt | 20 | 5 | 5 | 5 | 5 |
| 4 | 4 | Mesh State Delta Streaming via JSON Patch | 19 | 5 | 5 | 5 | 4 |
| 5 | 6 | MCP Tool Call Visibility | 19 | 5 | 4 | 5 | 5 |
| 6 | 7 | Circuit Breaker State Change Events | 19 | 5 | 5 | 4 | 5 |
| 7 | 8 | Emergency Stop Mesh Broadcast | 19 | 5 | 5 | 5 | 4 |
| 8 | 21 | Agent-to-Agent Direct Messaging | 19 | 5 | 5 | 5 | 4 |
| 9 | 5 | Planning Task Lifecycle Events | 17 | 4 | 5 | 4 | 4 |
| 10 | 9 | Verification Run Progress Stream | 17 | 4 | 4 | 5 | 4 |
| 11 | 61 | Two-Key-Turn Operation Confirmation | 17 | 5 | 5 | 3 | 4 |
| 12 | 81 | Progressive Disclosure Mode | 17 | 4 | 5 | 3 | 5 |
| 13 | 10 | Chaya Sync Phase Stream | 16 | 4 | 4 | 4 | 4 |
| 14 | 11 | Audit Trail Messages Snapshot | 16 | 5 | 3 | 5 | 3 |
| 15 | 16 | Text Message Agent Explanations | 16 | 3 | 5 | 4 | 4 |
| 16 | 17 | Tool Call Result Rendering | 16 | 4 | 4 | 4 | 4 |
| 17 | 22 | Mesh Broadcast for Global State | 16 | 5 | 4 | 4 | 3 |
| 18 | 41 | Interactive Mesh Topology D3 Graph | 16 | 3 | 4 | 4 | 5 |
| 19 | 42 | Fractal Compliance Matrix | 16 | 4 | 4 | 4 | 4 |
| 20 | 44 | Real-Time Sparkline Dashboard | 16 | 3 | 4 | 4 | 5 |
| 21 | 46 | Streaming Task Kanban Board | 16 | 3 | 5 | 4 | 4 |
| 22 | 63 | Rollback Confirmation Dialog | 16 | 5 | 4 | 4 | 3 |
| 23 | 66 | Real-Time Violation Feed | 16 | 5 | 4 | 4 | 3 |
| 24 | 68 | Safety Event Timeline | 16 | 5 | 3 | 5 | 3 |
| 25 | 71 | Emergency Stop with Mesh Cascade | 16 | 5 | 4 | 3 | 4 |
| 26 | 76 | SIL-6 Compliance Dashboard | 16 | 5 | 3 | 5 | 3 |
| 27 | 82 | Activity-Driven Status Bar | 16 | 3 | 5 | 4 | 4 |
| 28 | 181 | A2UI Declarative Widget Specs | 16 | 3 | 4 | 4 | 5 |
| 29 | 13 | Metabolic Set-Point State Delta | 15 | 4 | 3 | 4 | 4 |
| 30 | 15 | Immune Threat Level Custom Event | 15 | 4 | 3 | 4 | 4 |
| 31 | 18 | State Snapshot on Connection | 15 | 4 | 4 | 4 | 3 |
| 32 | 24 | Task Distribution via Zenoh Topics | 15 | 4 | 4 | 4 | 3 |
| 33 | 25 | Guardian Consensus via Zenoh | 15 | 5 | 3 | 4 | 3 |
| 34 | 26 | Cortex AI Request Pipeline | 15 | 4 | 4 | 4 | 3 |
| 35 | 27 | Smriti Knowledge Query via Zenoh | 15 | 3 | 4 | 5 | 3 |
| 36 | 29 | OODA Phase Coordination | 15 | 5 | 3 | 4 | 3 |
| 37 | 43 | 14-State Container DFA Widget | 15 | 4 | 3 | 4 | 4 |
| 38 | 45 | OTel Flame Graph Visualization | 15 | 3 | 3 | 5 | 4 |
| 39 | 47 | Threat Level Gauge Widget | 15 | 4 | 3 | 3 | 5 |
| 40 | 53 | Access Control Graph Visualization | 15 | 4 | 3 | 5 | 3 |
| 41 | 55 | Podman Container Cards | 15 | 3 | 5 | 3 | 4 |
| 42 | 62 | Agent Steering During OODA | 15 | 5 | 4 | 3 | 3 |
| 43 | 64 | Constitutional Override Request | 15 | 5 | 3 | 4 | 3 |
| 44 | 70 | Compliance Attestation Workflow | 15 | 5 | 3 | 4 | 3 |
| 45 | 72 | Safety Kernel Health Monitor | 15 | 5 | 3 | 4 | 3 |
| 46 | 73 | Lethal Mutation Gate in UI | 15 | 5 | 3 | 4 | 3 |
| 47 | 77 | Agent Behavior Anomaly Alert | 15 | 5 | 3 | 4 | 3 |
| 48 | 88 | Trend Sparklines in Status Cards | 15 | 3 | 4 | 4 | 4 |
| 49 | 96 | Contextual Tooltip System | 15 | 2 | 5 | 4 | 4 |
| 50 | 100 | Notification Center | 15 | 3 | 4 | 4 | 4 |
