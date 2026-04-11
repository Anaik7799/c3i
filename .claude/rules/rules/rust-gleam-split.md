# Rust-Gleam Architectural Split (SC-ARCH-SPLIT)
# PERMANENT RULE
**Monitoring, orchestration, infrastructure, and advanced diagnostics are RUST ONLY.**
**UI, domain types, testing framework, and NIF bridges are GLEAM.**
# Rust (planning_daemon, 31 modules, 9,104 LOC) — Operations + Cognitive
ALL of the following MUST be implemented in Rust only:
- Container lifecycle (start/stop/restart/build/pull)
- OODA supervisor (observe/orient/decide/act)
- Rule engine (RETE-UL, 52 GRL rules, 13 domains)
- Health orchestration (FPPS 5-method, hysteresis)
- Apoptosis (dying gasp, 6-phase shutdown)
- Preflight checks (18 critical + extended)
- DAG boot sequencing (topological sort, waves)
- CPM optimization (critical path, slack)
- Digital twin (genotype/phenotype drift)
- Seven-level RCA (L1-L7 root cause analysis)
- OpenRouter LLM advisory
- Zenoh telemetry (checkpoints, state vector)
- CPU governor (adaptive parallelism)
- Cascade containment (failure isolation)
- Partition fencing (split-brain prevention)
- Recovery playbooks (15 FMEA modes)
- NIF validation (ELF inspection)
- Substrate guard (Axiom 0.1)
- MCP-over-Zenoh bridge
- Build stream monitoring
- Build history (SQLite EMA)
- **Chat cortex** (intent classification, 6-tier hedged inference, gateway broadcast)
- **Voice pipeline** (Gemini Live WS, REST multimodal, Whisper.cpp fallback)
- **PipelineTracer** (zero-write hot path, batch SQLite+Zenoh finish)
- **RAG pipeline** (Smriti FTS5 context injection)
- **Semantic cache** (24h TTL, SQLite-backed)
- **Circuit breakers** (4 per-tier, 3 failures → 60s cooldown)
- **PII scrubber** (email, phone, CC, SSN, IP redaction)
- **SMTP email** (lettre, OAuth2, attachments)
- **Conversation history** (50-message sliding window)
- **Rate limiting** (20/min per user)
- **Ruliology engine** (Wolfram-style cellular automata, causal graphs)
- **FMEA automation** (trace-based failure mode analysis)
- **HA leader election** (Primary/Backup/Standby via Zenoh lease)
- **400-scenario simulator** (20 categories × 10 × 2 channels)
# Gleam (cepaf_gleam) — Presentation + Types + Testing
ALL of the following MUST be implemented in Gleam only:
- Domain types (`ui/domain.gleam`: Page, FractalLayer, HealthStatus)
- Lustre SSR web UI (24 pages, port 4100)
- Wisp REST API (14 endpoints, port 4100)
- TUI terminal views (24 view files)
- AG-UI 32-event protocol
- A2UI declarative component catalog
- Fractal widgets (L0-L7)
- Testing framework (coverage_math, alignment, nav_graph, fractal_matrix)
- Rule engine NIF bridge (`rules/engine.gleam`)
- Zenoh OTel span observation (test-time)
- Flight check (Gleam-side preflight for tests)
- Gemini verification (pipeline testing)
# Bridge Points (Gleam calls Rust)
| Bridge | Mechanism | Direction |
|--------|-----------|-----------|
| Rule engine | NIF (`rule_engine_nif.so`) | Gleam → Rust → Gleam |
| Container status | Podman CLI FFI (`cepaf_gleam_ffi.erl`) | Gleam → Erlang → Shell |
| Zenoh pub/sub | Zenoh NIF (`zenoh_nif.so`) | Gleam → Rust → Zenoh |
| OODA results | Zenoh subscription | Rust → Zenoh → Gleam |
| Ignition commands | `./sa-up` CLI | Gleam TUI → Shell → Rust |
# What Gleam MUST NOT Do
- Gleam MUST NOT implement container orchestration logic
- Gleam MUST NOT implement OODA supervisor loop
- Gleam MUST NOT implement health polling/consensus
- Gleam MUST NOT implement apoptosis/cascade/partition logic
- Gleam MUST NOT implement build/image management
- Gleam MUST NOT implement recovery playbooks
- Gleam MUST NOT duplicate Rust monitoring functionality
# STAMP
| ID | Constraint | Severity |
|----|------------|----------|
| SC-ARCH-SPLIT-001 | Monitoring + ops = Rust only | CRITICAL |
| SC-ARCH-SPLIT-002 | UI + types + testing = Gleam only | CRITICAL |
| SC-ARCH-SPLIT-003 | Bridge via NIF/Zenoh/CLI only | HIGH |
| SC-ARCH-SPLIT-004 | No operational logic duplication | HIGH |