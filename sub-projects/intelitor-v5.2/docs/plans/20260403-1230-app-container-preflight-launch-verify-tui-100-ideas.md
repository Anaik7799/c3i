# Plan: 100 TUI Ideas for Preflight → Launch → Verification (Application Container)

**Created**: 20260403-1230 CEST  
**Last Updated**: 20260403-1230 CEST  
**Status**: DRAFT  
**Scope**: High-fidelity operational cognition support for every stage of app container creation and verification  
**Primary Targets**: `native/ignition_daemon` (`preflight.rs`, `launch.rs`, `verify.rs`, `tui.rs`)

---

## 1. Objective

Design a complete **100-idea TUI concept bank** to evolve ignition operations from status monitoring to full cognitive command support across:

- PF-1 Infrastructure checks
- PF-2 Database readiness
- PF-3 Zenoh quorum and mesh checks
- PF-4 Network/IP/ports
- PF-5 Image readiness and fix-signature checks
- PF-6 Observability readiness
- Launch orchestration (app + bridge)
- Post-launch verification (V-1..V-14)
- Safety governance, rollback, and operator learning loops

---

## 2. Lifecycle Coverage Matrix

| Stage | Focus | Idea Range |
|---|---|---:|
| PF-1 Infrastructure | container health, dependencies, substrate integrity | 1-10 |
| PF-2 Database | readiness, migrations, hypertables, drift | 11-20 |
| PF-3 Mesh/Quorum | Zenoh quorum, liveness, partition awareness | 21-30 |
| PF-4/5 Network + Image | IP/port/network/image age/signatures | 31-40 |
| PF-6 + Launch Prep | observability and launch contract integrity | 41-50 |
| Launch Runtime | startup execution cognition | 51-60 |
| Verify V-1..V-14 | evidence-rich verification cognition | 61-70 |
| Safety & Governance | Guardian/HITL/rollback/policy controls | 71-80 |
| Operator Cognition | collaboration, accessibility, handoffs | 81-90 |
| Predictive/AI Assist | simulation, root-cause ranking, next-best actions | 91-100 |

---

## 2.1 BUILD → DEPLOY → RUN Coverage by Fractal Level (L0-L7)

Goal alignment: application container must be fully functional, with operator visibility at every level across build, deploy, and run.

| Layer | BUILD visibility | DEPLOY visibility | RUN visibility | Example Idea IDs |
|---|---|---|---|---|
| L0 Runtime/Constitutional | build policy/constraints gate | deployment safety gate | constitutional checks in runtime actions | 40, 73, 77 |
| L1 Atomic/Debug | compile/build step transcripts | launch command chain tracing | per-check evidence and error signatures | 10, 46, 62, 67 |
| L2 Component | component build artifacts (NIF, modules) | component env contract validation | component health and restart behavior | 6, 38, 44, 66 |
| L3 Transaction | migration/schema checks | DB + bridge transactional readiness | query/port/cepaf transaction trends | 14, 15, 18, 68 |
| L4 System | image/network/container build state | app container creation and attachment | full app system health/phase lifecycle | 31, 34, 51, 58 |
| L5 Cognitive | timing budget/cost prediction during build | deployment confidence and blast radius | operator cognition and anomaly diagnosis | 60, 76, 82, 98 |
| L6 Ecosystem | observability pipeline build wiring | mesh/quorum deployment consistency | cross-node telemetry and consensus behavior | 21, 24, 41, 64 |
| L7 Federation | provenance/lineage integrity | distributed policy and approval context | multi-operator handoff and learning continuity | 36, 72, 83, 99 |

---

## 2.2 Fractal Elements (E1-E8) Coverage for Application Container Lifecycle

Canonical elements required for full application-container cognition coverage:

| Element | Build Coverage | Deploy Coverage | Run Coverage | Operator Cognition Gain |
|---|---|---|---|---|
| **E1 Alarms** | Build-failure classification and severity mapping | Preflight gate alerts per PF stage | Runtime incident and restart-storm alerts | Faster triage and reduced signal ambiguity |
| **E2 Guardian** | Policy and safety constraints on build actions | HITL approval for destructive deploy actions | Governance context for runtime escalations | Clear “allowed/blocked and why” cognition |
| **E3 Sentinel** | Threat/risk posture for image and dependency state | Anomaly detection during ignition transitions | Continuous threat and drift monitoring | Early warning with confidence context |
| **E4 Devices** | Resource/device readiness (CPU/memory/socket mounts) | Port/IP/network endpoint device alignment | Device-level health telemetry and liveness | Immediate hardware/resource bottleneck visibility |
| **E5 Compliance** | Compliance baseline checks before artifact promotion | Deployment conformance gates and audit checks | Runtime compliance drift detection | Reduced audit overhead and explicit traceability |
| **E6 Analytics** | Build timing and cache efficiency analytics | Deploy success probability and variance analytics | Runtime trend, latency, and failure-cluster analytics | Predictive and explainable operational decisions |
| **E7 KMS** | Secret/certificate/key readiness and age checks | Secure env/key injection validation | Runtime key and auth posture monitoring | Trust clarity without exposing sensitive values |
| **E8 Config** | Build config integrity and provenance checks | Launch contract diff (expected vs actual) | Runtime config drift and override provenance | “What changed” cognition with reversible context |

Coverage invariant for this plan:

`∀ stage ∈ {Build, PF-1..PF-6, Ignite-1..Ignite-7, Verify}, ∀ element ∈ E1..E8, ∃ TUI evidence view(stage, element)`

---

## 2.3 Stage-by-Stage Coverage Blueprint (Preflight + Ignition + Verification)

This section describes how every stage is covered across fractal layers/elements and how cognition improves.

| Stage | Primary Layers | Mandatory Element Focus | Coverage Mechanism (TUI) | Operator Cognition Improvement |
|---|---|---|---|---|
| **BUILD-1 Artifact Synthesis** | L1-L4 | E1, E4, E6, E8 | build transcript + cache bars + provenance chain | Understand build health and speed drivers immediately |
| **BUILD-2 Security/Key Readiness** | L0-L3 | E2, E5, E7 | policy/key/compliance preflight cards | Know if artifacts are safe to promote |
| **PF-1 Infrastructure** | L1, L4, L6 | E1, E3, E4, E8 | infra treemap, blockers, contamination radar | Immediate blocker localization |
| **PF-2 Database** | L3-L4 | E1, E5, E6, E8 | migration heatmap, schema/port lens, DB gate | Explain DB readiness and failure cause chain |
| **PF-3 Mesh/Quorum** | L6-L7 | E1, E2, E3, E5 | quorum dial, pulse map, partition detector | Confident mesh viability judgment |
| **PF-4 Network/IP/Ports** | L2-L4 | E1, E4, E5, E8 | IP radar, port sunburst, attachment diff | Fast diagnosis of connectivity misconfigurations |
| **PF-5 Image Integrity** | L0-L2 | E2, E3, E6, E8 | image staleness, digest/provenance, fix-signature table | Trustworthy go/no-go image decision |
| **PF-6 Observability** | L5-L6 | E1, E5, E6 | OTEL continuity + target matrix | Verify post-launch observability won’t be blind |
| **IGNITE-1 Contract Lock** | L0-L2 | E2, E5, E8 | launch contract diff + constraint overlays | Know exactly what will execute and under which rules |
| **IGNITE-2 Container Create/Attach** | L2-L4 | E1, E4, E8 | birth timeline + network/volume attach checks | Real-time awareness of creation correctness |
| **IGNITE-3 Init Command Chain** | L1-L3 | E1, E6, E7 | command-chain tracer + secret/key audit row | Explain startup sequence behavior and risk |
| **IGNITE-4 Health Stabilization** | L4-L5 | E1, E3, E6 | SLA timers + anomaly detector + confidence composite | Distinguish transient vs systemic instability |
| **IGNITE-5 Mesh Registration** | L6-L7 | E1, E3, E5 | checkpoint bus + router auth/cert panel | Confirm cluster-level integration completeness |
| **IGNITE-6 Governance Handoff** | L0, L5 | E2, E5, E7 | Guardian queue + decision stream + immutable preview | Trust in controlled actuation and auditability |
| **IGNITE-7 Ready State Handoff** | L5-L7 | E6, E8 | handoff summary + deep links + learning capture stub | High-quality shift transition cognition |
| **VERIFY V-1..V-14** | L1-L6 | **E1..E8 all active** | verification board + evidence drawers + RCA ranking | Full-spectrum operational understanding and actionable next steps |

---

## 3. The 100 TUI Ideas

### A) PF-1 Infrastructure Cognition (1-10)

1. **Quorum Heartbeat Ring** — Circular heartbeat ring for each router with jitter overlays.  
2. **Infra Readiness Treemap** — Tree map of infra services weighted by boot criticality.  
3. **Dependency Chord Graph** — Visual graph of service dependencies and blockers.  
4. **Critical Blockers Panel** — “Top 3 blockers” sorted by impact-to-boot.  
5. **Stale Container Sentinel** — Detect and classify stale/exited/dead containers with dry-run cleanup.  
6. **NIF Presence Matrix** — Row/column matrix for required NIF artifacts per container.  
7. **Digest Divergence Detector** — Compare expected vs running image digests.  
8. **Startup Budget Gauge** — Per-container startup time vs budget bars.  
9. **Substrate Contamination Radar** — Warn on host `_build`/`deps` drift in container mode.  
10. **Preflight Command Transcript** — Structured command/result panel for PF-1 evidence.

### B) PF-2 Database Readiness Cognition (11-20)

11. **DB Port Auto-Detect Timeline** — Show discovered internal/external DB ports over time.  
12. **SSL Mismatch Signal** — Highlight SSL runtime mismatch (`DATABASE_SSL` vs DB setting).  
13. **Database Existence Gate** — Show create-db preview and projected impact before execution.  
14. **Migration Drift Heatmap** — Highlight missing/extra migration state.  
15. **Hypertable Readiness Checklist** — Verify `ts_event_logs` and hypertable metadata completeness.  
16. **Pool Saturation Predictor** — Predict near-term DB pool stress from startup trajectory.  
17. **Query Latency Sparkline** — Plot latency window from readiness probes and health checks.  
18. **Schema Hash Comparator** — Compare expected schema hash vs live DB schema hash.  
19. **Internal-vs-Host Port Lens** — Explicit lens showing mesh-internal port correctness.  
20. **DB Recovery Playbook Drawer** — One-click display of safe recovery sequence steps.

### C) PF-3 Zenoh Quorum / Mesh Cognition (21-30)

21. **2oo3 Quorum Dial** — Real-time quorum indicator with required threshold marker.  
22. **Mesh-Vantage Reachability Matrix** — Reachability from mesh-side probes, not host-side only.  
23. **Endpoint Canonicality Checker** — Validate router endpoint naming and endpoint format.  
24. **Topic Pulse Map** — Live pulse indicators for key topic families (`boot/*`, `health/*`).  
25. **Partition Suspicion Detector** — Detect asymmetric reachability and suspected network splits.  
26. **Quorum Loss Simulator** — Simulate one-node/two-node router loss before actual fault.  
27. **Router Cooldown Timeline** — Restart cooldown timers with safe retry windows.  
28. **Mesh Latency Contour** — Heatmap of inter-router RTT.  
29. **Checkpoint Bus Viewer** — High-fidelity viewer for CP-BOOT checkpoint stream.  
30. **Router Auth/Cert Panel** — Show auth and certificate posture per router.

### D) PF-4 + PF-5 Network/Image Cognition (31-40)

31. **IP Collision Radar** — Real-time collision risk indicator for target container IP.  
32. **Port Occupancy Sunburst** — Visualize host/mesh port claims and conflicts.  
33. **DNS Enabled Badge + Evidence** — DNS status with inspect evidence payload.  
34. **Expected Network Attachment Map** — Expected vs actual network attachment diff card.  
35. **Image Staleness Histogram** — Distribution of image ages vs stale threshold.  
36. **Image Provenance Chain** — Source lineage from build/pull/shared image roots.  
37. **Build Cache Hit/Miss Bars** — Track cache efficiency for rebuild decisions.  
38. **Fix-Signature Verification Table** — Grep-signature checks for required bugfixes.  
39. **NIF ABI Compatibility Sentinel** — ABI mismatch risk score before launch.  
40. **Launch-Readiness Binary Gate** — Single gate that explains every pass/fail component.

### E) PF-6 + Launch Preparation Cognition (41-50)

41. **OTEL Pipeline Continuity Map** — Validate collector path from app to observability stack.  
42. **Prometheus Target Matrix** — Display target up/down and scrape freshness.  
43. **Grafana Datasource Readiness** — Datasource verification with failure reasons.  
44. **Env Var Completeness Diff** — Required env keys vs provided launch env.  
45. **Secret Key Audit Row** — Track key generation event and age without exposing secrets.  
46. **Command-Chain Step Tracer** — Trace `redis → migrate → server` chain states.  
47. **Memory/SWAP Fit Estimator** — Predict launch survivability against memory limits.  
48. **Bridge Socket Mount Validator** — Verify mount existence/permissions before bridge launch.  
49. **Port Exposure Risk Analyzer** — Score runtime risk from current port mappings.  
50. **Dry-Run vs Actual Launch Diff** — Compare intended launch contract to real invocation.

### F) Launch Runtime Cognition (51-60)

51. **Container Birth Timeline** — Created→Starting→Running transition timeline.  
52. **Live Startup Log Classifier** — Auto-tag startup logs by domain (DB, NIF, Zenoh, etc.).  
53. **Health Endpoint SLA Timer** — Time-to-first-healthy and budget variance panel.  
54. **Redis Embedded Liveness Stream** — Ping stream and restart hints for embedded Redis.  
55. **Bridge Lifecycle Reason Codes** — Show retry/failure reasons for `cepaf-bridge`.  
56. **Fallback Execution Explainer** — Show why fallback path was chosen at runtime.  
57. **Env Override Provenance** — Explain where each env value came from.  
58. **Phase ETA Predictor** — Predict completion time for active launch phase.  
59. **Startup Anomaly Detector** — Flag unusual startup patterns against baseline.  
60. **Launch Confidence Composite** — Composite confidence score + top uncertainty factors.

### G) Verification Cognition (V-1..V-14) (61-70)

61. **Verification Card Board** — 14 cards for V-1..V-14 with status and quick actions.  
62. **Evidence Drawer per Check** — Expand each check into command output evidence.  
63. **State Vector Transition Strip** — Timeline of `[C,M,N,Z,H,Q]` transitions.  
64. **Failure Cluster Grouping** — Group check failures by subsystem and likely cause.  
65. **Error Rate vs Threshold Gauge** — Error accumulation slope and threshold predictor.  
66. **Watchdog Restart Storm Detector** — Detect and alert repeated restart loops.  
67. **BadMap/ArgError Regression Counters** — Dedicated counters for known failure signatures.  
68. **CepafPort Unavailability Trend** — Time-series trend of unavailability signals.  
69. **Guardian Escalation Monitor** — Live escalation events + constitutional rationale.  
70. **Verification Replay Mode** — Time-scrub replayer for prior verification runs.

### H) Safety / Governance Cognition (71-80)

71. **Two-Step Commit for Destructive Ops** — Arm→Confirm flow for cleanup/restart actions.  
72. **Guardian Approval Queue Panel** — Queue of pending approvals with urgency scoring.  
73. **Constraint Overlay per Action** — Show SC/AOR constraints impacted by each action.  
74. **Rollback Token Panel** — Generate/validate rollback tokens and readiness.  
75. **Emergency Stop Simulator** — Practice mode for emergency action sequence.  
76. **Blast Radius Estimator** — Predict impacted containers/services before actuation.  
77. **1st→5th Order Impact Graph** — Visual cascade map for intended mutations.  
78. **Safety-Kernel Decision Stream** — Live stream of allow/deny rationale.  
79. **Immutable Register Append Preview** — Show signed mutation record before commit.  
80. **Policy Violation Heatmap** — Heatmap by rule family and operation type.

### I) Operator Cognition / Collaboration (81-90)

81. **Role-Based Cockpit Layouts** — Optimized layouts for SRE, DBA, Security, Ops lead.  
82. **Operator Cognitive Load Meter** — Estimate overload and suggest simplification mode.  
83. **Shift Handoff Auto-Summary** — Summarize current state for handoff continuity.  
84. **Incident Timeline Co-Authoring** — Multi-operator collaborative timeline board.  
85. **Annotation Pins on Checks** — Add contextual notes directly on check cards.  
86. **Context-Preserving Deep Links** — Share exact view state with trace/time filters.  
87. **Keyboard-Only High-Velocity Mode** — Rapid command palette + key chords.  
88. **Accessibility + Theme Switcher** — Color profiles (Dark, Color Rich, High Contrast).  
89. **Multilingual Alert Labels** — Fast localized alert glossaries.  
90. **Drill/Training Scenario Launcher** — Operator drills for recurring failure modes.

### J) Predictive / AI Cognition (91-100)

91. **AI Preflight Copilot Panel** — Suggest next checks with confidence and evidence links.  
92. **Launch Success Probability** — Probabilistic launch success estimate with confidence band.  
93. **Top-3 Failure Forecast** — Forecast likely failure points before launch.  
94. **Recommendation Explainability Chain** — Show reason→evidence→action trace.  
95. **Citation Guardrail Panel** — Require source citations for AI-generated recommendations.  
96. **What-If Scenario Sandbox** — Simulate outages (DB down, quorum loss, NIF missing).  
97. **Auto-Runbook Generator** — Generate runbook from current failure signature set.  
98. **Root-Cause Candidate Ranking** — Rank candidate RCAs from telemetry and checks.  
99. **Post-Run Learning Capture** — Convert run outcomes into SMRITI knowledge entries.  
100. **Next-Best Improvement Advisor** — Prioritized improvement backlog with ROI and risk.

---

## 4. Suggested Prioritization (Fast Start)

**P0 first-set** (implement immediately): 1, 4, 10, 21, 31, 38, 40, 44, 46, 51, 61, 63, 65, 71, 72, 77, 78, 91, 93, 98.

---

## 5. Success Criteria

1. Operator can explain **why** launch is blocked/passing within 30 seconds.
2. Every preflight and verify decision has visible evidence in TUI.
3. Safety-critical actions require explicit human confirmation and rationale logging.
4. Mean time-to-diagnosis for failed launches drops by ≥40%.
5. At least 20 P0/P1 ideas implemented with stable telemetry provenance.

### 5.1 Full Functional Container Criteria (Build/Deploy/Run)

1. **BUILD**: image + NIF + fix-signature validation passes with explicit TUI evidence trail.
2. **DEPLOY**: preflight PF-1..PF-6 all green; launch contract validated before create.
3. **RUN**: verification V-1..V-14 shows stable operation with no hidden failure class.
4. **COGNITION**: operator can answer “what failed, why, what next” directly from TUI in <30s.
5. **GOVERNANCE**: destructive actions always require HITL and produce auditable rationale.

---

## 6. Next Action Options

1. Promote top 20 ideas into `sa-plan` with wave-based execution.
2. Generate implementation-ready UI specs for top 10 ideas.
3. Add BDD scenarios and acceptance checks for the selected idea subset.
