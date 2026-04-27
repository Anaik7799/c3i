# Constraint Registry (Reconciled 2026-03-22, PARITY ACHIEVED)
All SC-*/AOR-* constraint families. CLAUDE.md + .claude/rules/ is the authoritative superset.
Individual constraint details live in code; this registry tracks families and ranges.

## Delta (2026-04-21)
| Family | IDs | # | Description |
|---|---|---|---|
| SC-FRAC-RRF | 001-010 | 10 | Fractal layer/component matrix with RETE-UL+ruliology evidence, STAMP mapping, FMEA/FEMA scoring, and criticality-first execution |

## Delta (2026-04-27)
| Family | IDs | # | Description |
|---|---|---|---|
| SC-INFER-RUST-API | 001-008 | 8 | mistral.rs Rust-API-only mandate (no `mistralrs-server`/`pyo3`/`bench`; `MultimodalModelBuilder` + `Model::send_chat_request` + detached dispatch + `OnceLock` singleton). See `.claude/rules/mistral-rust-api-mandate.md` |
| SC-TESTDATA | 001-006 | 6 | Universal test-data corpus contract — license, manifest, ground-truth, no-PII, size budget. See `.claude/rules/test-data-corpus.md` |
| SC-TESTDATA-TXT | 001-005 | 5 | Text fixtures — UTF-8 ≤ 8K tokens, multilingual, refusal-bait coverage |
| SC-TESTDATA-IMG | 001-006 | 6 | Image fixtures — gemma-4 native 384×384, format sweep, ≥4 categories, adversarial |
| SC-TESTDATA-AUD | 001-006 | 6 | Audio fixtures — gemma-4 native 16 kHz mono PCM-16, ≥3 200 samples, codec sweep, no Common Voice |
| SC-TESTDATA-VID | 001-006 | 6 | Video fixtures — ≥4 frames @ 384×384, FPS sweep, JSON storage, ≥1 real Kinetics |
# P0-SAFETY (CRITICAL)
| Family | IDs | # | Description |
|--------|-----|---|-------------|
| SC-ENFORCE | 001-025 | 25 | Planning enforcer access control, circuit breaker, audit |
| SC-SIL4 | 001-029 | 21 | IEC 61508 SIL-4: fail-safe, 2oo3 voting, boot DAG, quorum |
| SC-SAFETY | 001-022 | 22 | Planning safety kernel: Guardian approval, Psi invariants, emergency halt |
| SC-SIL | 001-005 | 5 | SIL compliance: PFD, HFT, safe failure fraction >= 90% |
| SC-DMS | 001-004 | 4 | Dead man's switch: 100ms heartbeat, 50ms failsafe |
| SC-GUARD | 001-003 | 3 | Guardian integration: Envelope, DeadMansSwitch, FounderDirective |
| SC-WATCHDOG | 001-003 | 3 | State watchdog: 100ms check, corruption detection |
| SC-SAFE | 001 | 1 | Safety invariants verified for all state changes |
| SC-SIMPLEX | 002 | 1 | Redundancy >= MinRedundancy=2 |
| SC-SEC | 001-049 | 23 | Security: auth, encryption, PII masking, rate limiting |
| SC-NEURO | 001-005 | 5 | Neural/cognitive substrate safety |
| SC-NIF | 001-006 | 6 | NIF layer: Rust FFI boundary safety, crash isolation |
| SC-PRIME | 001-003 | 3 | Constitutional prime axioms, symbiotic defense |
# P0 Key Individual Constraints (highest decision-criticality)
| ID | Constraint |
|----|------------|
| SC-SIL4-001 | Safety functions MUST fail to safe state |
| SC-SIL4-006 | 2oo3 voting MANDATORY for production actuations |
| SC-SIL4-007 | Dying gasp checkpoint MANDATORY before shutdown |
| SC-SIL4-010 | DAG validation before boot |
| SC-SIL4-011 | Quorum floor(N/2)+1 maintained throughout upgrades |
| SC-SIL4-015 | Split-brain detection triggers apoptosis |
| SC-SAFETY-001 | Guardian pre-approval REQUIRED for planning mutations |
| SC-SAFETY-009 | Psi-0 (Existence) validated for all operations |
| SC-SAFETY-020 | Auto-halt at threat threshold |
| SC-SAFETY-022 | Emergency stop < 5 seconds |
| SC-ENFORCE-001 | Direct PROJECT_TODOLIST.md access MUST be blocked |
| SC-ENFORCE-021 | Unknown agents MUST be denied by default |
| SC-DMS-001 | Heartbeat interval MUST be 100ms |
| SC-DMS-002 | Failsafe triggers within 50ms of timeout |
| SC-GUARD-002 | Guardian integrates with DeadMansSwitch, fail closed |
| SC-PRIME-001 | Constitutional prime axioms inviolable |
**AOR-P0**: ENFORCE(15) SAFETY(15) SIL4(6) SIL6(4) SEC(3) GUARD(2) NEURO(2) NIF(1) PRIME(1)
# P1-CORE (HIGH)
| Family | IDs | # | Description |
|--------|-----|---|-------------|
| SC-FSH | 003-122 | 24 | F# safety: active patterns, units of measure, Kleisli, workflows, recursion |
| SC-SMRITI | 023-142 | 24 | Knowledge mgmt: telemetry, federation, immortality, version vectors |
| SC-XHOLON | 001-051 | 18 | Cross-holon DB: isolated files, Zenoh-only cross access, OCC, WAL |
| SC-VER | 001-079 | 18 | System verification: startup, fractal L0-L7, Psi invariants |
| SC-ORCH | 001-015 | 15 | Orchestration: Prajna/Smriti/Chaya coordination, Guardian approval |
| SC-BOOT | 001-010 | 10 | Boot sequence: state vector, migration, quorum, DAG, waves |
| SC-PHICS | 001-008 | 8 | Physical interface: command logging, Guardian approval, latency |
| SC-CONSOL | 001-010 | 10 | Config consolidation: MeshConfig.fs, ports, ANSI, boot validation |
| SC-LOG | 001-010 | 8 | Fractal logger: async, PII masking, TraceID, HLC timestamps |
| SC-OPT | 001-008 | 8 | Boot optimization: <60s target, exponential backoff, waves |
| SC-FED | 001-006 | 6 | Federation governance: constitution, autonomy, Ed25519 |
| SC-UTLTS | 001-012 | 7 | Universal test lifecycle: WAL, multi-lang, coverage import |
| SC-HA | 001-011 | 7 | High availability: SIL-6, failover, 2oo3 quorum, chaos |
| SC-CI | 001-007 | 7 | CI/CD: reproducible builds, quality gates, 5 test levels |
| SC-MATH | 001-004 | 4 | Mathematical disciplines: health, token ratios, PID tuning |
| SC-RECONFIG | 001-010 | 5 | Constitutional reconfiguration: graph transform, Guardian |
| SC-SWARM | 001-005 | 5 | Swarm algorithms: convergence, diversity, fitness <10ms |
| SC-AGENT | 001-005 | 5 | Distributed agent mesh: FQUN, Zenoh, state, lifecycle |
| SC-CONSENSUS | 001-003 | 3 | Tricameral: 2oo3 voting, Constitutional veto, <30s timeout |
| SC-HASH | 001-003 | 3 | Hash computation: deterministic, constant-time, canonical |
| SC-IKE | 001-003 | 3 | Knowledge engine: ingestion, entropy gating, drift detection |
| SC-STATE | 001-003 | 3 | Holon state: atomic updates, constitution hash, logged |
| SC-CIRCUIT | 001-002 | 2 | Prajna circuit breaker: drop at >100 msgs, logged |
| SC-FRACTAL | 001 | 1 | Genotype topology must match runtime graph |
| SC-QUORUM | 001 | 1 | 2oo3 voting mandatory for safety-critical |
| SC-VALID | 001 | 1 | STAMP references for every validated action |
| SC-SYNC | 001-014 | 14 | State sync: Elixir-F# bridge, cockpit, Zenoh publishing |
| SC-VAL | 001-008 | 8 | Validation: FPPS consensus, compilation, patterns |
| SC-REGEN | 002-004 | 3 | Regeneration: container lifecycle, health, supervisor |
| SC-ZEN | 001-005 | 5 | Zenoh session: lifecycle, connectivity, routing |
**AOR-P1**: VER(40) XHOLON(40) MATH(20) ORCH(15) FSH(12) CONSOL(10) OPT(10) PHICS(10) SYNC(8) LOG(6) CI(5) AGENT(4) OBS(4) VAL(4) BOOT(3) FFI(3) FRAC(3) RECONFIG(3) GDE(2) HLC(2) IKE(2) FED(1) LOGIC(1)
# P2-DOMAIN: Critical (RPN >= 200)
| Family | IDs | # | Description |
|--------|-----|---|-------------|
| SC-HMI | 001-080 | 80 | Human-Machine Interface: cockpit UI, accessibility, dark cockpit |
| SC-MCP | 001-082 | 82 | Model Context Protocol: MCP server, tool dispatch, handlers |
| SC-SEM | 001-072 | 72 | Semantic analysis: NLP, embedding, classification |
| SC-ACE | 001-039 | 39 | Agent Collaboration Engine: coordination, task allocation |
| SC-KMS | 001-023 | 23 | Key Management: lifecycle, encryption, certificates |
# P2-DOMAIN: High (6+ IDs)
| Family | # | Sev | Description |
|--------|---|-----|-------------|
| SC-ALARM | 41 | H | Alarm management, storm detection, escalation |
| SC-GRID | 25 | M | Grid layout, capability grid, responsive |
| SC-AGT | 24 | H | Agent management, C3I console orchestration |
| SC-CNT | 19 | H | Container lifecycle, health, compliance |
| SC-VDP | 17 | H | Visual data plane, cluster visualization |
| SC-ARROW | 12 | M | Signal arrows, cockpit flow visualization |
| SC-ALARMS | 12 | H | Alarm engine, severity classification |
| SC-FLAME | 11 | H | FLAME runner, distributed compute, crash recovery |
| SC-DEBUG | 10 | H | Debug telemetry, probes, trace capture |
| SC-CONC | 10 | H | Concurrency, DuckDB pool management |
| SC-DIST | 10 | H | Distribution, FQUN, mesh, node management |
| SC-GRAPH | 10 | H | Graph operations, verification, analytics |
| SC-API | 10 | H | API safety, backoff, rate limiting, circuit breaker |
| SC-OODA | 9 | H | OODA loop: observe-orient-decide-act cycle |
| SC-EMR | 10 | H | Emergency response, stop, rollback, notification |
| SC-CLU | 8 | H | Clustering, application cluster management |
| SC-CTX | 8 | H | Context management, lifecycle |
| SC-CLI | 8 | M | CLI interface, command parsing, REPL |
| SC-CV | 8 | M | Coverage validation, TDG framework |
| SC-DAT | 8 | M | Data acquisition, sensor collection |
| SC-DEV | 8 | M | Device management, Prajna dashboard |
| SC-ECO | 8 | M | Ecosystem, API gateway, integrations |
| SC-GVF | 8 | M | Graph verification, Prometheus framework |
| SC-MIX | 8 | M | Mix tasks, safety constraint validation |
| SC-POD | 8 | M | Podman integration, CEPAF bridge containers |
| SC-TEST | 7 | H | Test lifecycle, coverage, harness |
| SC-PROM | 7 | H | PROMETHEUS verification, proof gates |
| SC-CMP | 8 | H | Compilation: zero-warning, parallel build |
| SC-DF | 7 | M | Data flow, AI pricing, transformation |
| SC-SIM | 7 | M | Simulation, cockpit theme, scenarios |
| SC-ARK | 6 | H | Ark persistence, data archival |
| SC-TPS | 6 | H | Toyota Production System, Jidoka, quality |
| SC-PROP | 6 | M | Property testing, PropCheck |
| SC-BUS | 5 | M | Unified control bus, backpressure |
| SC-SOVEREIGNTY | 5 | M | AI inference sovereignty, data locality |
**AOR-P2-High**: CMD(8) FOUNDER(10) CTX(10) TPS(3) CAE(3) CHAYA(5) CNT(4) VAR(4)
# P2-DOMAIN: Minor/Standard (1-5 IDs each)
**Missed families**: SC-CAMERA(5) SC-PM(5) SC-AUC(4) SC-DIS(4) SC-SITE(2) SC-GIT-006(1)
**3-ID families (MEDIUM)**: SC-ALERT SC-ARTERY SC-COCKPIT SC-DEP SC-EDIT SC-GOSSIP SC-HEALTH SC-HITL SC-HTTP SC-MA SC-PREROLL SC-SENS SC-STPA SC-TEL SC-THR SC-WS SC-CREDO SC-MIG SC-TDG
**2-ID families (MEDIUM)**: SC-BUF SC-CAT SC-CEA SC-CHANNEL SC-CLUSTER SC-COMM SC-COMPLIANCE SC-COUNT SC-DEVICE SC-DISPATCH SC-DSP SC-FM SC-MAT SC-MIL SC-MULTILINE SC-PASS SC-PROD SC-REPORT SC-RESP SC-SEN SC-SER SC-SYNAPSE SC-VID SC-VIEW SC-EVAL SC-RCA SC-DRIFT SC-GEM SC-PORTAL SC-VAR
**1-ID families**: SC-A SC-B SC-C SC-CACHE SC-CEPAF SC-CPU SC-DATA SC-DBBOTH SC-DEMO SC-DIAG SC-DOC SC-DOS SC-EID SC-ERGO SC-FAIL SC-FLM SC-FPPS SC-HIST SC-K8S SC-L1 SC-L7 SC-LATENCY SC-MORPH SC-NAME SC-NASA SC-PRD SC-PRIV SC-PVE SC-RECOVER SC-REFLEX SC-SAF SC-SENTINEL SC-SHARED SC-SRE SC-STAMP SC-TRACE SC-TWIN SC-UX SC-VSM SC-ZUIP SC-CA SC-ANA
**4-ID VSM families**: SC-S1 SC-S2 SC-S3 SC-S4 SC-S5 SC-BEL SC-SUR SC-EVT SC-SNP SC-PRJ SC-RPL SC-TT SC-SHADOW SC-TRAIN SC-CPL
**4-ID Architecture**: SC-HOL SC-HLT SC-SUP SC-PROT SC-MET SC-ACT SC-CROSS SC-HIER(5) SC-SEV
**4-ID Jain/Federation**: SC-APR SC-BUD SC-CON SC-CRD SC-CRY SC-DIR SC-GEN SC-JAI SC-PRO SC-REP SC-WAL
**4-ID Infrastructure**: SC-BATCH SC-BRG SC-BROADWAY SC-ENV SC-FIX SC-GOS SC-GRM SC-MYC SC-NAT SC-OBAN SC-ORC SC-PAR SC-PHE SC-PRC SC-ROU SC-TX SC-WORKER SC-WORKFLOW
**4-ID Alarms/Safety**: SC-AE SC-IT SC-NOTIFY SC-UAP SC-WE SC-PO SC-GOI
**4-ID Cockpit/UI**: SC-DRK SC-ENT SC-FBK SC-HMP SC-INT SC-LED SC-PRT SC-CONFIG(6)
**Gleam UI Families**: SC-GLM-UI(10) SC-GLM-ZEN(3) SC-GLM-TST(2) SC-AGUI(10) SC-A2UI(8) SC-UIGT(10) SC-HINT(8) SC-MATH-COV(6)
**Gleam UI Families**: SC-GLM-UI(10) SC-GLM-ZEN(3) SC-GLM-TST(2) SC-AGUI(10) SC-A2UI(8) SC-UIGT(10) SC-HINT(8) SC-MATH-COV(6)
**4-ID Data/Knowledge**: SC-STORE(4) SC-DBPROXY SC-PUBSUB SC-TENANT SC-AUDIT SC-AUTH SC-AUTHZ SC-AUTO SC-JOB SC-LV SC-MAINT SC-MEM
**Larger P2 families**: SC-EVO(30) SC-MODEL(20) SC-STARTUP(20) SC-TRI(15) SC-SMOKE(13) SC-BDD(10) SC-CPM(10) SC-DBINT(10) SC-DFA(10) SC-RCPSP(10) SC-STREAM(10) SC-EFFECT(10) SC-COMONAD(8) SC-STM(8) SC-MOJO(7) SC-CHAYA(6) SC-SESS(5) SC-SET(10) SC-C3I(5) SC-CHAOS(5) SC-DASH(5) SC-HOM(5) SC-JRN(5) SC-MSG(6) SC-RES(5) SC-MV(5) SC-FAME(5) SC-TXN(5) SC-ECON(4) SC-SING(10) SC-VIDEO(5) SC-GRAV(4)
# P2-DOMAIN: Analytics (all MEDIUM, 5 IDs each unless noted)
SC-AAE SC-AC SC-AD SC-ADE SC-ANALYTICS SC-BDW SC-BI SC-BP SC-BVM SC-CS SC-EDE SC-HM SC-IP SC-KPI SC-LOKI SC-MDRS SC-ML SC-MLI SC-PA SC-PB SC-PERF SC-PPM SC-PRED SC-PTR SC-PVF SC-RBC SC-REALTIME SC-RPT SC-RS SC-RTBC SC-SD SC-SID SC-SM SC-TA SC-TREND SC-UAE SC-UNIFIED SC-AN SC-SIG | SC-ANA(1) SC-SRE(1) | AOR-KPI(3)
# P3-STYLE (LOW, from ErrorPatterns.fs)
| Family | # | Description |
|--------|---|-------------|
| SC-DEPR | 25 | Deprecated API usage detection |
| SC-STYLE | 25 | Code style violations |
| SC-UNUSED | 25 | Unused variable/import detection |
| SC-WARN | 25 | Compiler warning patterns |
| SC-COMP | 10 | Compliance live view |
| SC-IMPORT | 10 | Import validation |
| SC-TYPE | 10 | Type safety validation |
| SC-MOD | 4 | Module structure |
| SC-STR | 4 | String handling |
| SC-MACRO | 2 | Macro usage patterns |
**1-ID SC-P3**: ACCESS ANON ATTR BINARY CASE DRY KWLIST PATTERN PIN PIPE RAISE RECEIVE SIGIL STRUCT TRY WITH
**AOR-P3**: DEPR(25) STYLE(25) UNUSED(25) WARN(4) MACRO(3) + 30 single-ID AOR rules (ACCESS ANON ARCH ATOM ATTR BIN BINARY BOOL CASE CB CLAUSE COMP IMPORT KWLIST MAP MATCH MOD PATTERN PIN PIPE PROC RAISE RECEIVE SIGIL SPEC STR STRUCT TRY TYPE WITH)
# P2-DOMAIN AOR Rules
**AOR-P2-Standard**: DEBUG(5) FLAME(3) GRAPH(3) DASH(2) FAME(2) ASH(2) SING(10) BRIDGE(2) CREDO(2) DBCROSS(2) DBLOCAL(2) DOC(5) GEM(5) TEST(2) KPI(3)
**AOR-P2-Single**: AGT BATCH BDD BUS CLI COCKPIT CODE COMM COMPLIANCE CONFIG CPM DB DEP DEV DFA DISPATCH ENV EVO-006 FAG-002 GVF IGNITE MCP PERF PROP QUA RCA RCPSP SET SITE THR VIDEO