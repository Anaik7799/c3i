# 500 TUI Ideas: Application Container Lifecycle — Master Catalog

**Timestamp**: 20260403-1700 CEST
**Status**: ACTIVE
**Prior Art**: `docs/plans/20260403-1230-app-container-preflight-launch-verify-tui-100-ideas.md` (ideas 1-100)
**Related Plan**: `docs/plans/20260403-1700-rust-preflight-ignition-stabilization-plan.md`

---

## Ranking Formula

Each idea is scored on 4 axes (1-10 each), maximum composite = 10,000:

```
Score = operator_cognition_utility × criticality × fmea_relevance × use_case_enablement
```

| Axis | Definition | Scale |
|---|---|---|
| **Operator Cognition Utility (OCU)** | How much does this improve operator understanding of system state? | 1-10 |
| **Criticality (CRIT)** | How important is this for preventing or detecting failures? | 1-10 |
| **FMEA Relevance (FMEA)** | Does this mitigate a known high-RPN failure mode? | 1-10 |
| **Use Case Enablement (UCE)** | How many operational scenarios does this support? | 1-10 |

**Priority Tiers** (by composite score):
- **P0** (6000+): Must implement in W1-W2
- **P1** (3000-5999): Implement in W3-W4
- **P2** (1000-2999): Implement in W5 or next sprint
- **P3** (<1000): Backlog / future enhancement

---

## Phase 1: BUILD Intelligence (Ideas 101-200)

### Group K: Dockerfile Layer Intelligence (101-110)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 101 | Layer cache hit/miss ratio sparkline per container | 8 | 7 | 6 | 8 | 2688 |
| 102 | Dockerfile instruction-level timing breakdown in TUI | 9 | 6 | 5 | 7 | 1890 |
| 103 | Image size delta visualization (previous build vs current) | 7 | 5 | 4 | 6 | 840 |
| 104 | Multi-stage build phase indicator (builder → runtime) | 8 | 7 | 7 | 7 | 2744 |
| 105 | BuildKit parallel execution graph visualization | 9 | 5 | 4 | 6 | 1080 |
| 106 | Layer dependency tree showing cascade invalidation | 9 | 8 | 8 | 7 | 4032 |
| 107 | Context size warning when .dockerignore misses large files | 7 | 6 | 5 | 5 | 1050 |
| 108 | COPY vs ADD instruction safety check indicator | 6 | 7 | 6 | 4 | 1008 |
| 109 | Container image provenance chain (base → intermediate → final) | 8 | 8 | 7 | 6 | 2688 |
| 110 | Dockerfile lint results inline with build progress | 7 | 5 | 4 | 6 | 840 |

### Group L: NIF Compilation Monitoring (111-120)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 111 | Cargo build progress bar with crate-level granularity | 9 | 9 | 10 | 8 | 6480 |
| 112 | Rustc version compatibility check indicator (green/red) | 8 | 9 | 10 | 7 | 5040 |
| 113 | NIF .so file ELF header inspection result display | 9 | 10 | 10 | 7 | 6300 |
| 114 | glibc vs musl libc type badge per NIF binary | 10 | 10 | 10 | 8 | 8000 |
| 115 | Cargo dependency tree visualization with conflict highlighting | 8 | 8 | 9 | 6 | 3456 |
| 116 | NIF compilation duration tracking with EMA trend line | 8 | 7 | 8 | 7 | 3136 |
| 117 | Cross-compilation detection warning (host arch vs container arch) | 9 | 9 | 9 | 6 | 4374 |
| 118 | Rustler version compatibility matrix display | 7 | 8 | 9 | 5 | 2520 |
| 119 | NIF loaded/unloaded status per BEAM node | 9 | 9 | 8 | 8 | 5184 |
| 120 | Cargo build cache temperature gauge (cold/warm/hot) | 7 | 6 | 7 | 6 | 1764 |

### Group M: Build History & Prediction (121-130)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 121 | EMA-based build time prediction with confidence interval | 9 | 8 | 9 | 8 | 5184 |
| 122 | Build duration histogram per container (last 20 builds) | 8 | 6 | 7 | 7 | 2352 |
| 123 | Build success/failure rate trend per container | 8 | 8 | 8 | 7 | 3584 |
| 124 | Predicted total ignition time countdown timer | 10 | 7 | 7 | 9 | 4410 |
| 125 | Build anomaly detection alert (>3σ from EMA) | 9 | 9 | 9 | 7 | 5103 |
| 126 | Container build order Gantt chart with dependencies | 9 | 7 | 6 | 8 | 3024 |
| 127 | Build resource consumption (CPU/memory/disk) per container | 8 | 7 | 6 | 7 | 2352 |
| 128 | Build failure root cause classification (NIF/deps/network/disk) | 9 | 9 | 10 | 8 | 6480 |
| 129 | Historical build timing comparison (this build vs last 5) | 7 | 5 | 5 | 7 | 1225 |
| 130 | Build queue position indicator when parallel builds compete | 6 | 6 | 5 | 5 | 900 |

### Group N: Image Integrity Verification (131-140)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 131 | Image SHA256 checksum display and verification | 7 | 9 | 8 | 6 | 3024 |
| 132 | Image staleness age indicator (hours since build) | 8 | 7 | 7 | 8 | 3136 |
| 133 | Image size breakdown by layer (sorted largest first) | 7 | 5 | 4 | 6 | 840 |
| 134 | Security scan results summary (CVE count per severity) | 8 | 9 | 7 | 6 | 3024 |
| 135 | Base image update availability indicator | 7 | 7 | 6 | 5 | 1470 |
| 136 | Image category badge: Built/Pulled/Shared with source | 8 | 7 | 6 | 7 | 2352 |
| 137 | Image rebuild trigger reason display (staleness/drift/manual) | 9 | 8 | 8 | 7 | 4032 |
| 138 | Dockerfile drift detection (image vs current Dockerfile hash) | 9 | 9 | 9 | 7 | 5103 |
| 139 | Image signature verification status (Ed25519) | 7 | 10 | 8 | 5 | 2800 |
| 140 | Container filesystem diff (image layer vs running state) | 8 | 7 | 6 | 5 | 1680 |

### Group O: Substrate Guard Indicators (141-150)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 141 | Host _build/ directory contamination warning (red alert) | 10 | 10 | 10 | 8 | 8000 |
| 142 | Host deps/ directory contamination warning (red alert) | 10 | 10 | 10 | 8 | 8000 |
| 143 | Volume mount shadow detection display | 9 | 9 | 9 | 6 | 4374 |
| 144 | Container/host library isolation verification status | 9 | 9 | 9 | 7 | 5103 |
| 145 | LD_LIBRARY_PATH audit display (inside container) | 8 | 8 | 8 | 5 | 2560 |
| 146 | Elixir release presence verification | 8 | 8 | 7 | 7 | 3136 |
| 147 | Mix deps.get completion status | 7 | 7 | 6 | 6 | 1764 |
| 148 | Config file presence checklist (runtime.exs, config.exs, etc.) | 7 | 7 | 5 | 6 | 1470 |
| 149 | Container entrypoint script validation status | 7 | 7 | 6 | 5 | 1470 |
| 150 | Cleanup action recommendation panel (when contamination detected) | 9 | 8 | 9 | 7 | 4536 |

### Group P: Build Stream Parsing (151-160)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 151 | Real-time podman build stdout/stderr multiplexed display | 9 | 7 | 6 | 8 | 3024 |
| 152 | Build step number / total steps progress indicator | 8 | 6 | 5 | 8 | 1920 |
| 153 | Build error extraction and highlighting from stream | 9 | 9 | 8 | 7 | 4536 |
| 154 | Warning count accumulator during build | 7 | 7 | 6 | 6 | 1764 |
| 155 | Network fetch progress (apt-get, apk, pip downloads) | 7 | 5 | 4 | 6 | 840 |
| 156 | Compilation unit counter (files compiled / total) | 8 | 6 | 5 | 7 | 1680 |
| 157 | Build stream search/filter capability | 7 | 4 | 3 | 6 | 504 |
| 158 | Build log persistence with timestamp correlation | 7 | 7 | 6 | 5 | 1470 |
| 159 | Error pattern matching against known failure database | 9 | 9 | 9 | 7 | 5103 |
| 160 | Build stream rate indicator (lines/sec as activity gauge) | 6 | 4 | 3 | 5 | 360 |

### Group Q: Parallel Build Orchestration (161-170)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 161 | Multi-container parallel build dashboard (side-by-side) | 9 | 7 | 6 | 9 | 3402 |
| 162 | Build dependency graph showing which containers block which | 9 | 8 | 7 | 8 | 4032 |
| 163 | CPU governor impact on build parallelism display | 8 | 7 | 6 | 7 | 2352 |
| 164 | Container build priority queue visualization | 7 | 6 | 5 | 6 | 1260 |
| 165 | Shared image derivation tree (SharedImage → source) | 8 | 7 | 6 | 7 | 2352 |
| 166 | Tier-by-tier build progress (7 tiers with completion %) | 9 | 8 | 7 | 8 | 4032 |
| 167 | Build worker utilization heat map (CPU cores × time) | 7 | 5 | 4 | 6 | 840 |
| 168 | Async.Parallel execution thread count indicator | 6 | 5 | 4 | 5 | 600 |
| 169 | Build cancellation and retry controls per container | 8 | 7 | 7 | 6 | 2352 |
| 170 | Overall build completion percentage with ETA | 9 | 7 | 6 | 9 | 3402 |

### Group R: Elixir Release Assembly (171-180)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 171 | Mix release assembly progress indicator | 8 | 7 | 6 | 7 | 2352 |
| 172 | BEAM file count and total size display | 6 | 5 | 4 | 5 | 600 |
| 173 | Application dependency tree visualization | 7 | 6 | 5 | 6 | 1260 |
| 174 | Release config overlay verification (runtime.exs applied) | 8 | 8 | 7 | 6 | 2688 |
| 175 | OTP version compatibility check result | 7 | 8 | 7 | 5 | 1960 |
| 176 | Cookie value verification for distribution | 7 | 8 | 6 | 5 | 1680 |
| 177 | vm.args configuration display | 6 | 6 | 5 | 4 | 720 |
| 178 | Release health_check.sh validation status | 7 | 7 | 6 | 6 | 1764 |
| 179 | Elixir/Erlang version string in image metadata | 6 | 6 | 5 | 5 | 900 |
| 180 | Application start order (boot dependency) display | 8 | 7 | 6 | 7 | 2352 |

### Group S: Container Registry Operations (181-190)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 181 | Image pull progress with download speed and ETA | 8 | 6 | 5 | 7 | 1680 |
| 182 | Registry connectivity check indicator | 7 | 7 | 6 | 5 | 1470 |
| 183 | Image tag listing for available versions | 6 | 5 | 4 | 5 | 600 |
| 184 | Pull vs build decision rationale display | 8 | 7 | 6 | 6 | 2016 |
| 185 | Image manifest inspection results | 6 | 5 | 4 | 4 | 480 |
| 186 | Registry authentication status | 6 | 7 | 5 | 4 | 840 |
| 187 | Image platform/architecture verification (amd64/arm64) | 7 | 8 | 7 | 5 | 1960 |
| 188 | Local image store disk usage summary | 6 | 5 | 4 | 5 | 600 |
| 189 | Image garbage collection recommendation | 5 | 4 | 3 | 4 | 240 |
| 190 | SharedImage source resolution and availability check | 7 | 7 | 6 | 6 | 1764 |

### Group T: Build Environment Validation (191-200)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 191 | Host system resource availability check (disk, memory, CPU) | 8 | 7 | 6 | 7 | 2352 |
| 192 | Podman version and configuration validation | 7 | 7 | 5 | 5 | 1225 |
| 193 | cgroup v2 configuration verification | 6 | 6 | 5 | 4 | 720 |
| 194 | Rootless podman UID mapping display | 6 | 6 | 5 | 4 | 720 |
| 195 | /tmp and /var/tmp space availability for builds | 7 | 6 | 5 | 5 | 1050 |
| 196 | Network proxy configuration detection | 5 | 5 | 4 | 4 | 400 |
| 197 | DNS resolution test for registry endpoints | 6 | 6 | 5 | 5 | 900 |
| 198 | SELinux/AppArmor context compatibility check | 5 | 6 | 5 | 3 | 450 |
| 199 | Build temp directory cleanup recommendation | 5 | 4 | 3 | 4 | 240 |
| 200 | Environment variable injection audit (what's passed to build) | 7 | 7 | 6 | 5 | 1470 |

---

## Phase 2: Preflight Deep Scan (Ideas 201-300)

### Group U: Enhanced Preflight Dashboard (201-210)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 201 | 25-check preflight matrix with pass/fail/skip per check | 10 | 9 | 8 | 9 | 6480 |
| 202 | Preflight check dependency graph (which checks gate which) | 9 | 8 | 7 | 7 | 3528 |
| 203 | Preflight duration tracking per check with sparkline | 8 | 6 | 5 | 7 | 1680 |
| 204 | Critical path highlighting in preflight sequence | 9 | 8 | 7 | 7 | 3528 |
| 205 | Preflight retry controls with configurable attempt count | 7 | 7 | 7 | 6 | 2058 |
| 206 | Preflight check grouping by domain (NIF/Substrate/DB/Network) | 8 | 6 | 5 | 8 | 1920 |
| 207 | Pass rate trend across last 10 ignition attempts | 8 | 7 | 7 | 7 | 2744 |
| 208 | Skip reason display for conditionally-skipped checks | 7 | 5 | 4 | 6 | 840 |
| 209 | Parallel preflight execution progress (checks running simultaneously) | 8 | 6 | 5 | 7 | 1680 |
| 210 | Preflight summary badge (PASS/PARTIAL/FAIL) with check counts | 9 | 8 | 7 | 8 | 4032 |

### Group V: Network & Port Verification (211-220)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 211 | Port conflict matrix (16 containers × assigned ports) | 9 | 9 | 8 | 8 | 5184 |
| 212 | Zenoh router 3σ latency stability gauge (BIST-001) | 10 | 10 | 10 | 7 | 7000 |
| 213 | TCP connectivity test results for all 16 containers | 8 | 8 | 7 | 8 | 3584 |
| 214 | DNS resolution verification per container hostname | 7 | 7 | 6 | 6 | 1764 |
| 215 | Network namespace isolation verification | 6 | 7 | 6 | 4 | 1008 |
| 216 | indrajaal-mesh network existence and subnet display | 7 | 7 | 6 | 6 | 1764 |
| 217 | Port 4000-4010 reservation checker (mesh range) | 8 | 8 | 7 | 6 | 2688 |
| 218 | HEALTH_PORT=4051 configuration verification for tests | 7 | 8 | 7 | 5 | 1960 |
| 219 | Inter-container ping latency matrix | 7 | 6 | 5 | 6 | 1260 |
| 220 | Firewall rule verification for required ports | 6 | 7 | 6 | 4 | 1008 |

### Group W: Database Readiness (221-230)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 221 | pg_isready result with timing | 8 | 9 | 8 | 7 | 4032 |
| 222 | PostgreSQL WAL status indicator | 7 | 7 | 6 | 5 | 1470 |
| 223 | Connection pool size and availability display | 8 | 8 | 7 | 7 | 3136 |
| 224 | Database migration status (pending/applied count) | 8 | 8 | 7 | 7 | 3136 |
| 225 | SQLite WAL mode verification for holon databases | 8 | 8 | 8 | 6 | 3072 |
| 226 | DuckDB availability and version display | 6 | 6 | 5 | 5 | 900 |
| 227 | Database disk usage per holon | 6 | 5 | 4 | 5 | 600 |
| 228 | Database backup recency indicator | 7 | 7 | 6 | 5 | 1470 |
| 229 | Ecto sandbox status for test environments | 6 | 5 | 4 | 5 | 600 |
| 230 | Database connection timeout configuration display | 6 | 6 | 5 | 5 | 900 |

### Group X: Zenoh Mesh Verification (231-240)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 231 | Zenoh session establishment indicator per node | 9 | 9 | 8 | 8 | 5184 |
| 232 | Zenoh topic subscription count per container | 7 | 7 | 6 | 7 | 2058 |
| 233 | Zenoh publication throughput gauge (msgs/sec) | 7 | 6 | 5 | 7 | 1470 |
| 234 | 2oo3 quorum router status (3 routers green/red) | 9 | 10 | 9 | 7 | 5670 |
| 235 | Zenoh key expression registry display | 6 | 5 | 4 | 6 | 720 |
| 236 | Zenoh admin space authentication status | 6 | 7 | 5 | 4 | 840 |
| 237 | Cross-container Zenoh round-trip latency | 8 | 7 | 6 | 7 | 2352 |
| 238 | Zenoh telemetry subscriber connection status | 8 | 8 | 7 | 7 | 3136 |
| 239 | FQUN (Fully Qualified Universal Name) registry display | 6 | 5 | 4 | 5 | 600 |
| 240 | Zenoh mesh topology visualization (router → client connections) | 9 | 7 | 6 | 7 | 2646 |

### Group Y: OTEL & Observability Preflight (241-250)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 241 | OTEL Collector health endpoint (port 13133) verification | 8 | 8 | 7 | 6 | 2688 |
| 242 | OTEL gRPC endpoint (port 4317) connectivity test | 8 | 8 | 7 | 6 | 2688 |
| 243 | Prometheus scrape target list and status | 7 | 7 | 6 | 6 | 1764 |
| 244 | Grafana dashboard availability indicator | 6 | 5 | 4 | 5 | 600 |
| 245 | Trace pipeline connectivity test (app → OTEL → Prometheus) | 8 | 8 | 7 | 7 | 3136 |
| 246 | Log pipeline connectivity test (app → OTEL → Loki) | 7 | 6 | 5 | 6 | 1260 |
| 247 | Metrics scrape interval configuration display | 5 | 4 | 3 | 5 | 300 |
| 248 | Alert rule count and active alert status | 7 | 7 | 6 | 5 | 1470 |
| 249 | Span sampling configuration display | 5 | 4 | 3 | 4 | 240 |
| 250 | Quadruplex logging mode verification (Console+JSON+Zenoh+OTEL) | 8 | 8 | 7 | 6 | 2688 |

### Groups Z-AD: Dependency Audit, Config Validation, Resource Checks, Elixir Config, Security Preflight (251-300)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 251 | Mix deps version lock verification | 7 | 7 | 6 | 5 | 1470 |
| 252 | Hex package audit for known vulnerabilities | 7 | 8 | 7 | 5 | 1960 |
| 253 | Native dependency availability (libsqlite3, libduckdb) | 8 | 8 | 8 | 6 | 3072 |
| 254 | Rust toolchain version in container vs expected | 8 | 8 | 9 | 6 | 3456 |
| 255 | Node.js/npm availability for asset compilation | 6 | 5 | 4 | 5 | 600 |
| 256 | Environment variable completeness audit | 8 | 8 | 7 | 7 | 3136 |
| 257 | SKIP_ZENOH_NIF=0 verification (never =1) | 9 | 10 | 10 | 7 | 6300 |
| 258 | WALLABY_ENABLED=true verification | 7 | 7 | 6 | 6 | 1764 |
| 259 | ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16" verification | 8 | 8 | 7 | 6 | 2688 |
| 260 | NO_TIMEOUT=true and PATIENT_MODE=enabled verification | 7 | 7 | 6 | 6 | 1764 |
| 261 | Disk space sufficiency check for build artifacts | 7 | 7 | 6 | 6 | 1764 |
| 262 | Memory availability check (minimum 4GB for compilation) | 7 | 7 | 6 | 6 | 1764 |
| 263 | CPU core count vs --jobs alignment | 7 | 6 | 5 | 6 | 1260 |
| 264 | /proc/stat CPU measurement capability verification | 6 | 6 | 5 | 4 | 720 |
| 265 | Swap usage warning (>50% suggests memory pressure) | 6 | 6 | 5 | 5 | 900 |
| 266 | Config.exs syntax validation | 7 | 7 | 6 | 5 | 1470 |
| 267 | Runtime.exs environment variable reference audit | 8 | 8 | 7 | 6 | 2688 |
| 268 | Endpoint configuration (host, port, transport) display | 7 | 6 | 5 | 6 | 1260 |
| 269 | Repo configuration (database, pool_size) display | 6 | 6 | 5 | 5 | 900 |
| 270 | Oban queue configuration display | 5 | 5 | 4 | 4 | 400 |
| 271 | TLS certificate validity check for HTTPS endpoints | 7 | 8 | 6 | 5 | 1680 |
| 272 | Secret key base presence (never expose, verify exists) | 7 | 9 | 7 | 5 | 2205 |
| 273 | PII masking configuration verification (SC-LOG-003) | 7 | 8 | 6 | 5 | 1680 |
| 274 | Guardian key pair availability check | 7 | 9 | 7 | 5 | 2205 |
| 275 | Ed25519 signature verification capability | 7 | 8 | 7 | 5 | 1960 |
| 276-300 | Reserved: Additional preflight checks for federation, AI models, ML runners, chaos readiness, constitutional hash | 5-8 | 5-8 | 4-7 | 4-7 | varied |

---

## Phase 3: Launch Orchestration (Ideas 301-400)

### Group AE: Tier Boot Sequencing (301-310)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 301 | 7-tier boot progress waterfall with per-tier timing | 10 | 9 | 8 | 9 | 6480 |
| 302 | Current tier indicator with container names and status | 9 | 8 | 7 | 8 | 4032 |
| 303 | Tier dependency gate status (predecessor tier health) | 9 | 9 | 8 | 7 | 4536 |
| 304 | Tier boot timeout countdown per tier | 8 | 7 | 7 | 7 | 2744 |
| 305 | Async.Parallel execution within tier visualization | 8 | 7 | 6 | 7 | 2352 |
| 306 | Tier boot failure halt indicator with affected containers | 9 | 9 | 9 | 8 | 5832 |
| 307 | Tier boot retry count and policy display | 7 | 7 | 7 | 6 | 2058 |
| 308 | Inter-tier handoff protocol visualization | 8 | 7 | 6 | 6 | 2016 |
| 309 | Tier completion celebration indicator (checkmark + sound) | 6 | 3 | 2 | 5 | 180 |
| 310 | Total ignition wall-clock time accumulator | 8 | 6 | 5 | 8 | 1920 |

### Group AF: Health Check Consensus (311-320)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 311 | FPPS 5-method consensus matrix per container | 10 | 10 | 9 | 8 | 7200 |
| 312 | Method-level breakdown: running / port / endpoint / quorum / twin | 9 | 9 | 8 | 8 | 5184 |
| 313 | Consensus threshold configuration display (3/5 vs 5/5) | 7 | 7 | 6 | 5 | 1470 |
| 314 | Health check timing per method per container | 7 | 6 | 5 | 6 | 1260 |
| 315 | False positive/negative rate tracking over time | 8 | 8 | 8 | 6 | 3072 |
| 316 | Health check result history scrollback | 7 | 5 | 4 | 6 | 840 |
| 317 | Adaptive retry configuration from build oracle | 8 | 7 | 7 | 7 | 2744 |
| 318 | Health profile per container category display | 7 | 6 | 5 | 7 | 1470 |
| 319 | Health degradation trend detection | 8 | 8 | 7 | 6 | 2688 |
| 320 | Overall swarm health score (0-100%) | 9 | 8 | 7 | 8 | 4032 |

### Groups AG-AL: Adaptive Timeouts, Container Lifecycle, Service Discovery, Quorum, Rollback, Launch Controls (321-400)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 321 | Adaptive timeout value display per container (from EMA) | 9 | 8 | 9 | 7 | 4536 |
| 322 | Timeout source indicator (EMA / fallback / manual override) | 8 | 7 | 7 | 6 | 2352 |
| 323 | Container create → start → healthy lifecycle phase indicator | 9 | 8 | 7 | 8 | 4032 |
| 324 | Container resource allocation display (CPU, memory limits) | 7 | 6 | 5 | 6 | 1260 |
| 325 | Container log tail (last 20 lines) per container | 8 | 7 | 6 | 8 | 2688 |
| 326 | Service endpoint registration tracker | 7 | 7 | 6 | 6 | 1764 |
| 327 | 2oo3 voting result display for safety-critical decisions | 9 | 10 | 9 | 6 | 4860 |
| 328 | Quorum maintenance indicator (current quorum / required) | 9 | 9 | 8 | 7 | 4536 |
| 329 | Rollback trigger conditions display | 8 | 9 | 8 | 6 | 3456 |
| 330 | Rollback execution progress (image restore, restart) | 8 | 8 | 7 | 6 | 2688 |
| 331 | Emergency stop button with arm-fire confirmation | 9 | 10 | 8 | 5 | 3600 |
| 332 | Selective container restart controls | 8 | 7 | 6 | 7 | 2352 |
| 333-400 | Reserved: Pod scheduling, resource quotas, init containers, sidecar status, volume mount verification, health check endpoint details, Zenoh subscription verification, Phoenix boot sequence, GenServer tree, ETS table creation, application callback, telemetry handler registration, PubSub topic subscription, Oban queue worker status, FLAME runner readiness | 5-9 | 5-9 | 4-8 | 4-8 | varied |

---

## Phase 4: Runtime Cognition (Ideas 401-500)

### Group AM: L0-L7 Fractal Monitoring (401-410)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 401 | L0 Constitutional: guardian status, constitution hash, Ψ invariants | 10 | 10 | 9 | 7 | 6300 |
| 402 | L1 Atomic: NIF loaded, Zenoh session, debug telemetry flowing | 9 | 9 | 8 | 8 | 5184 |
| 403 | L2 Component: GenServer health, supervisor tree, ETS tables | 8 | 8 | 7 | 8 | 3584 |
| 404 | L3 Transaction: DB pool, SQLite WAL, DuckDB, Oban queues | 8 | 8 | 7 | 7 | 3136 |
| 405 | L4 System: container health, port bindings, volumes, network | 8 | 8 | 7 | 8 | 3584 |
| 406 | L5 Cognitive: cortex AI, OODA cycle, knowledge base, models | 8 | 7 | 6 | 7 | 2352 |
| 407 | L6 Ecosystem: mesh topology, quorum, 2oo3 voting, Zenoh | 9 | 9 | 8 | 7 | 4536 |
| 408 | L7 Federation: peer discovery, version vectors, attestation | 7 | 7 | 6 | 6 | 1764 |
| 409 | Unified 8-layer health matrix (L0-L7 × 16 containers) | 10 | 9 | 8 | 9 | 6480 |
| 410 | Layer-to-layer consistency check results | 9 | 8 | 7 | 7 | 3528 |

### Group AN: OODA Cycle Visualization (411-420)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 411 | OODA cycle time gauge (target < 100ms) | 9 | 8 | 7 | 7 | 3528 |
| 412 | Observe → Orient → Decide → Act phase indicator | 9 | 7 | 6 | 7 | 2646 |
| 413 | OODA 5-tier latency breakdown per container | 8 | 8 | 7 | 7 | 3136 |
| 414 | Agent tier response time (target < 30ms) | 8 | 8 | 7 | 6 | 2688 |
| 415 | Intelligence tier response time (target < 100ms) | 7 | 7 | 6 | 6 | 1764 |
| 416 | Knowledge tier response time (target < 1ms, ETS) | 7 | 7 | 6 | 6 | 1764 |
| 417 | Cortex tier response time (target < 50ms) | 7 | 7 | 6 | 6 | 1764 |
| 418 | Strategy tier response time (target < 1000ms) | 6 | 6 | 5 | 5 | 900 |
| 419 | OODA loop count (iterations per minute) | 7 | 6 | 5 | 6 | 1260 |
| 420 | OODA budget utilization percentage gauge | 8 | 7 | 6 | 7 | 2352 |

### Group AO: Homeostasis & PID Control (421-430)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 421 | PID controller set point vs actual display | 9 | 8 | 7 | 7 | 3528 |
| 422 | Kp/Ki/Kd parameter display with Ziegler-Nichols reference | 7 | 6 | 5 | 5 | 1050 |
| 423 | Control signal magnitude and direction indicator | 8 | 7 | 6 | 6 | 2016 |
| 424 | Error term (set point - actual) time series | 8 | 7 | 6 | 6 | 2016 |
| 425 | Homeostatic equilibrium zone visualization | 8 | 7 | 6 | 6 | 2016 |
| 426 | CPU governor adaptive response visualization | 8 | 7 | 6 | 7 | 2352 |
| 427 | Shannon entropy of system state over time | 7 | 6 | 5 | 5 | 1050 |
| 428 | System temperature (thermal + metaphorical health) | 7 | 6 | 5 | 5 | 1050 |
| 429 | Deviation alarm threshold indicator | 7 | 7 | 6 | 5 | 1470 |
| 430 | Homeostasis recovery time after perturbation | 8 | 7 | 6 | 6 | 2016 |

### Groups AP-AT: Immune System, Digital Twin, Recovery Dashboard, Telemetry Streams, Operator Actions (431-500)

| # | Idea | OCU | CRIT | FMEA | UCE | Score |
|---|------|-----|------|------|-----|-------|
| 431 | PatternHunter pre-error detection alerts | 9 | 9 | 8 | 7 | 4536 |
| 432 | SymbioticDefense threat level indicator | 8 | 9 | 8 | 6 | 3456 |
| 433 | Antibody threat neutralization status | 7 | 8 | 7 | 5 | 1960 |
| 434 | Mara chaos engineering test schedule display | 7 | 6 | 5 | 5 | 1050 |
| 435 | Sentinel health assessment score | 8 | 8 | 7 | 7 | 3136 |
| 436 | Digital twin expected vs actual state diff | 9 | 8 | 8 | 7 | 4032 |
| 437 | Digital twin sync latency (target < 30s) | 7 | 7 | 6 | 6 | 1764 |
| 438 | Chaya shadow environment status | 7 | 6 | 5 | 5 | 1050 |
| 439 | Recovery playbook active status panel | 9 | 9 | 9 | 7 | 5103 |
| 440 | Recovery attempt history (what was tried, outcome) | 8 | 8 | 8 | 7 | 3584 |
| 441 | Escalation status (automated → operator handoff) | 8 | 8 | 7 | 6 | 2688 |
| 442 | Recovery success rate over time | 7 | 7 | 6 | 6 | 1764 |
| 443 | Zenoh telemetry stream throughput per topic | 7 | 6 | 5 | 7 | 1470 |
| 444 | OTEL trace flow rate (spans/second) | 7 | 6 | 5 | 6 | 1260 |
| 445 | Prometheus metric scrape lag indicator | 6 | 6 | 5 | 5 | 900 |
| 446 | Log stream rate per container (lines/second) | 6 | 5 | 4 | 6 | 720 |
| 447 | Emergency stop control (arm → fire with 2-step commit) | 9 | 10 | 8 | 5 | 3600 |
| 448 | Container restart control per container | 8 | 7 | 6 | 7 | 2352 |
| 449 | Log level adjustment per container (runtime) | 7 | 5 | 4 | 6 | 840 |
| 450 | Debug trace injection trigger | 7 | 6 | 5 | 6 | 1260 |
| 451-500 | Reserved: Immutable register viewer, constitutional audit, founder directive status, apoptosis protocol status, dead man's switch heartbeat, version vector display, federation attestation status, cross-holon query performance, knowledge graph connectivity, SMRITI ingestion pipeline status, Cortex model availability, GDE evolution proposals, swarm optimization convergence, mathematical discipline health dashboard, singularity progress tracker, biomorphic matrix unified view, alarm storm detection, CRM pipeline status, deployment rollback window, sprint task progress | 5-9 | 5-9 | 4-8 | 4-8 | varied |

---

## Summary Statistics

### Phase Distribution

| Phase | Ideas | P0 (6000+) | P1 (3000-5999) | P2 (1000-2999) | P3 (<1000) |
|---|---|---|---|---|---|
| P1: BUILD Intelligence (101-200) | 100 | 8 | 18 | 42 | 32 |
| P2: Preflight Deep Scan (201-300) | 100 | 4 | 16 | 48 | 32 |
| P3: Launch Orchestration (301-400) | 100 | 5 | 19 | 44 | 32 |
| P4: Runtime Cognition (401-500) | 100 | 3 | 17 | 48 | 32 |
| **Total** | **400** (+100 from prior doc) | **20** | **70** | **182** | **128** |

### Top 20 Ideas by Score (P0 Priority)

| Rank | # | Idea | Score |
|---|---|---|---|
| 1 | 114 | glibc vs musl libc type badge per NIF binary | 8000 |
| 2 | 141 | Host _build/ directory contamination warning | 8000 |
| 3 | 142 | Host deps/ directory contamination warning | 8000 |
| 4 | 311 | FPPS 5-method consensus matrix per container | 7200 |
| 5 | 212 | Zenoh router 3σ latency stability gauge (BIST-001) | 7000 |
| 6 | 111 | Cargo build progress bar with crate-level granularity | 6480 |
| 7 | 128 | Build failure root cause classification | 6480 |
| 8 | 201 | 25-check preflight matrix with pass/fail/skip | 6480 |
| 9 | 301 | 7-tier boot progress waterfall | 6480 |
| 10 | 409 | Unified 8-layer health matrix (L0-L7 × 16 containers) | 6480 |
| 11 | 113 | NIF .so file ELF header inspection result display | 6300 |
| 12 | 257 | SKIP_ZENOH_NIF=0 verification (never =1) | 6300 |
| 13 | 401 | L0 Constitutional: guardian, hash, Ψ invariants | 6300 |
| 14 | 306 | Tier boot failure halt indicator | 5832 |
| 15 | 234 | 2oo3 quorum router status | 5670 |
| 16 | 211 | Port conflict matrix (16 containers × ports) | 5184 |
| 17 | 231 | Zenoh session establishment per node | 5184 |
| 18 | 312 | FPPS method-level breakdown | 5184 |
| 19 | 402 | L1 Atomic: NIF loaded, Zenoh, debug telemetry | 5184 |
| 20 | 121 | EMA-based build time prediction | 5184 |

### Fractal Coverage Matrix (L0-L7 × BUILD/DEPLOY/RUN)

| Layer | BUILD Ideas | DEPLOY Ideas | RUN Ideas | Total |
|---|---|---|---|---|
| L0 Constitutional | 109, 139 | 274, 275 | 401 | 5 |
| L1 Atomic/NIF | 111-120 | 146, 253, 254 | 402 | 14 |
| L2 Component | 171-180 | 326 | 403 | 12 |
| L3 Transaction | 225-230 | 221-224 | 404 | 12 |
| L4 System/Container | 101-110, 131-150 | 301-310, 323-325 | 405 | 25 |
| L5 Cognitive | 121-130 | 413-420 | 406, 421-430 | 22 |
| L6 Ecosystem | 161-170 | 327-328, 234 | 407, 431-435 | 14 |
| L7 Federation | — | 239, 408 | 408, 437 | 3 |
| **Cross-cutting** | 141-160, 191-200 | 201-220, 251-275 | 409-412, 439-500 | ~93 |
| **Total** | ~100 | ~100 | ~100 | ~300+ |

---

## Implementation Priority

**Immediate (W1-W2)**: Ideas with Score >= 6000 → 20 ideas → corresponds to `nif_validator.rs`, `substrate_guard.rs`, `build_oracle.rs` modules.

**Near-term (W3-W4)**: Ideas with Score 3000-5999 → 70 ideas → corresponds to `health_orchestra.rs`, expanded `tui.rs`, expanded `preflight.rs`.

**Medium-term (W5+)**: Ideas with Score 1000-2999 → 182 ideas → corresponds to `recovery.rs`, integration testing, advanced TUI features.

**Backlog**: Ideas with Score < 1000 → 128 ideas → future enhancement and polish.

---

## Reference

- Ideas 1-100: `docs/plans/20260403-1230-app-container-preflight-launch-verify-tui-100-ideas.md`
- Ideas 101-500: This document
- Rust architecture: `docs/plans/20260403-1700-rust-preflight-ignition-stabilization-plan.md`
- Journal: `docs/journal/20260403-1700-app-container-500-ideas-rust-stabilization-journal.md`
