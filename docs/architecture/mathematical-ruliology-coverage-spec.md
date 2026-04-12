# Mathematical, Ruliology & Coverage Specification
# C3I cepaf_gleam System — Complete Reference
# Version: 22.6.0-DHARMA | Layer: L0-L7 | SIL-6 | IEC 61508

---

## Section 1: Mathematical Disciplines (17 Disciplines)

All implementations sourced from actual Gleam modules. Thresholds are compile-time constants.

### 1.1 Shannon Entropy

**Source**: `testing/coverage_math.gleam`

**Formula**:
```
H(X) = -Σ p_i × log₂(p_i)   for i where p_i > 0
```

| Parameter | Value | Notes |
|-----------|-------|-------|
| Threshold (H) | ≥ 2.5 bits | Gate for test distribution |
| Normalized H_norm | H / log₂(8) | Divides by max entropy of 8 categories |
| Max H (8 categories) | 3.0 bits | log₂(8) |
| Implementation | `shannon_entropy/1` | Returns Float |
| Uses | `math:log/1` via Erlang FFI | Converts: log₂(x) = ln(x)/ln(2) |

**CCM Category Weights** (actual implementation, not approximated):

| Category | Weight | P0 Minimum |
|----------|--------|------------|
| C1 Page Structure | 1.0 | 3 |
| C2 Status Badges | 1.5 | 3 |
| C3 Data Grids | 2.0 | 2 |
| C4 Timeline | 2.0 | 2 |
| C5 Interactive | 1.5 | 2 |
| C6 Media/Rich | 2.5 | 3 |
| C7 AI Advisory | 2.5 | 2 |
| C8 Action Button | 3.0 | 3 |

### 1.2 Coverage Composite Metric (CCM)

**Source**: `testing/coverage_math.gleam`

**Formula**:
```
CCM = Σ(w_i × min(c_i / min_i, 1.0)) / Σ(w_i)
```

| Parameter | Value |
|-----------|-------|
| Threshold | CCM ≥ 0.90 |
| Σ(w_i) | 16.5 (sum of all weights) |
| `ccm/1` | Takes list of #(count, min_required) pairs with weights |
| `ccm_raw/1` | Takes CoverageMetric struct directly |

**P0 enforcement**: If any c_i = 0 and min_i > 0, the category contributes 0 to CCM (hard failure).

### 1.3 Integrated Test Quality Score (ITQS)

**Source**: `testing/coverage_math.gleam`

**Formula** (exact as implemented):
```
ITQS = 0.25 × H_norm + 0.35 × CCM + 0.25 × (1 - D_EA) + 0.15 × FSI
```

| Component | Weight | Source |
|-----------|--------|--------|
| H_norm (normalized entropy) | 0.25 | `shannon_entropy_normalized/1` |
| CCM | 0.35 | `ccm/1` |
| (1 - D_EA) | 0.25 | 1 minus divergence |
| FSI | 0.15 | `fsi/1` |

**Grades**:

| Grade | Threshold |
|-------|-----------|
| A | ITQS ≥ 0.90 |
| B | ITQS ≥ 0.85 |
| C | ITQS ≥ 0.75 |
| D | ITQS < 0.75 |

### 1.4 Fleet Stability Index (FSI)

**Source**: `testing/coverage_math.gleam`

**Formula**:
```
FSI = 1 - (stddev(H_suite) / mean(H_suite))
FSI = 1.0   when mean = 0.0 (degenerate case)
```

Measures entropy consistency across test suite modules. Higher FSI = more uniform coverage distribution.

### 1.5 Expected vs Actual Divergence (D_EA)

**Source**: `testing/coverage_math.gleam`

**Formula**:
```
D_EA = |expected - implemented| / expected
D_EA = 0.0   when expected = 0
```

| Parameter | Value |
|-----------|-------|
| Threshold | D_EA ≤ 0.10 (≤10% divergence) |
| `divergence/1` | Takes #(expected, actual) pair |

### 1.6 Kolmogorov Complexity Estimate

**Source**: `ha/math_analysis.gleam`

**Formula**:
```
K ≈ unique_patterns / total_patterns   ∈ [0.0, 1.0]
```

| Value | Interpretation |
|-------|---------------|
| K → 0 | Highly repetitive, compressible (simple) |
| K → 1 | Maximally complex, incompressible |
| Input | List of health scores (Float list) |
| `kolmogorov_estimate/1` | Returns Float |

Patterns are extracted as consecutive pairs #(a, b) from the input series. Unique pairs counted by equality.

### 1.7 Mutual Information

**Source**: `ha/math_analysis.gleam`

**Formula**:
```
I(X;Y) = H(X) + H(Y) - H(X,Y)
I(X;Y) ≥ 0   (clamped)
```

| Parameter | Notes |
|-----------|-------|
| Input | Two Float lists; truncated to min(length_x, length_y) |
| H(X,Y) | Joint entropy on paired values |
| `mutual_information/2` | Returns Float |

Discretization: values bucketed into 5 bins of equal width over [0.0, 1.0].

### 1.8 Transfer Entropy (Causal Direction)

**Source**: `ha/math_analysis.gleam`

**Formula** (lag-1 simplified):
```
TE(X→Y) = H(Yt | Yt-1) - H(Yt | Yt-1, Xt-1)
         = H(Yt, Yt-1) - H(Yt-1) - H(Yt, Yt-1, Xt-1) + H(Yt-1, Xt-1)
```

| Parameter | Notes |
|-----------|-------|
| Input | Two Float lists (source X, target Y) |
| `transfer_entropy/2` | Returns Float |
| Interpretation | TE > 0 means X causally influences Y |

### 1.9 Fractal Dimension

**Source**: `ha/math_analysis.gleam`

**Formula** (box-counting at scales 1, 2):
```
D_f = log(N_scale1 / N_scale2) / log(2)
D_f ∈ [1.0, 2.0]   (clamped)
```

| Parameter | Notes |
|-----------|-------|
| N_scale1 | Boxes at scale 1 (coarse count) |
| N_scale2 | Boxes at scale 2 (fine count) |
| `fractal_dimension/1` | Returns Float |
| log constant | `ln2 = 0.6931471805599453` |

Input partitioned via `partition_into_boxes/2`.

### 1.10 Hurst Exponent

**Source**: `ha/math_analysis.gleam`

**Formula** (Rescaled Range Analysis):
```
H = ln(R/S) / ln(n)
R = max(cumdev) - min(cumdev)
S = std_dev(series)
```

| Value | Interpretation |
|-------|---------------|
| H = 0.5 | Random walk (Brownian motion) |
| H > 0.5 | Persistent trend (long memory) |
| H < 0.5 | Anti-persistent (mean-reverting) |
| Degenerate | Returns 0.5 when n < `min_rs_length` (= 4) |
| `hurst_exponent/1` | Returns Float |

### 1.11 Health Differential Calculus

**Source**: `ha/health_calculus.gleam`

**Formulas** (on discrete time series, most-recent first):

| Derivative | Formula | Input Requirement |
|------------|---------|-------------------|
| First derivative d(H)/dt | (H[0] - H[2]) / 2.0 | n ≥ 3 (central difference) |
| First derivative (fallback) | H[0] - H[1] | n = 2 (forward difference) |
| Second derivative d²(H)/dt² | H[0] - 2×H[1] + H[2] | n ≥ 3 |
| Second derivative (fallback) | 0.0 | n < 3 |

**HealthTrend Classification** (priority order):

| Priority | Trend | Condition |
|----------|-------|-----------|
| 1 (highest) | AcceleratingDecline | d² < -0.02 AND d' < 0 |
| 2 | Recovering | d' > 0.02 AND current < threshold |
| 3 | Improving | d' > 0.02 |
| 4 | Declining | d' < -0.02 |
| 5 (default) | Stable | \|d'\| ≤ 0.02 |

**Time-to-threshold** (linear extrapolation):
```
t = (threshold - current) / rate
t = 2_147_483_647   when |rate| < 0.001
default_threshold = 0.5
```

### 1.12 Welford Online Algorithm (Anomaly Detection)

**Source**: `ha/anomaly_detector.gleam`

**Update step** (numerically stable):
```
delta  = value - mean
mean   = mean + delta / n
delta2 = value - mean   (post-update mean)
M2     = M2 + delta × delta2
var    = M2 / (n - 1)   for n ≥ 2
```

**Z-score and detection**:
```
z = (value - mean) / std_dev
AnomalyHigh if z >  sigma_threshold
AnomalyLow  if z < -sigma_threshold
```

| Parameter | Value |
|-----------|-------|
| `default_sigma_threshold` | 3.0 |
| `min_samples_required` | 2 |
| Insufficient data | Returns `InsufficientData(n, 2)` |

**AnomalyResult variants**: `Normal(value, z_score)` | `Anomaly(value, z_score, direction)` | `InsufficientData(n, required)`

### 1.13 FMEA Risk Priority Number (RPN)

**Source**: `ha/fmea_generator.gleam`

**Formula**:
```
RPN = Severity × Occurrence × Detection   (each 1-10)
```

| Priority | RPN Range | Action |
|----------|-----------|--------|
| P0Critical | RPN ≥ 200 | Immediate action required |
| P1High | 100 ≤ RPN < 200 | High priority |
| P2Medium | 50 ≤ RPN < 100 | Medium priority |
| P3Low | RPN < 50 | Low priority |

**Scale definitions**:

| Score | Severity | Occurrence | Detection |
|-------|----------|------------|-----------|
| 1 | Negligible | Practically impossible | Detection certain |
| 5 | Moderate | Occasional | Moderate chance |
| 10 | Catastrophic | Almost inevitable | Almost undetectable |

### 1.14 SLO Error Budget

**Source**: `ha/slo_tracker.gleam`

**Formula** (Google SRE model):
```
allowed_bad_events = total_events × (1 - target)
bad_events         = total_events - good_events
budget_consumed    = bad_events / allowed_bad_events   ∈ [0.0, 1.0]  (clamped)
```

**SLO Status**:

| Status | Condition |
|--------|-----------|
| SLOMet | budget_consumed < 0.50 |
| SLOAtRisk | 0.50 ≤ budget_consumed < 1.00 |
| SLOViolated | budget_consumed ≥ 1.00 |

**System SLO Targets**:

| SLO | Target | Window |
|-----|--------|--------|
| truth_slo | 99.999999% | 86400s |
| freshness_slo | 99.9% | 3600s |
| availability_slo | 99.9% | 86400s |
| latency_slo | 99.0% | 3600s |

### 1.15 PageRank

**Source**: `testing/nav_graph.gleam`

**Formula** (power iteration):
```
PR(v) = (1 - d) / N + d × Σ(PR(u) / out_degree(u))   for u → v
d = 0.85, 30 iterations
```

| Parameter | Value |
|-----------|-------|
| Damping factor d | 0.85 |
| Iterations | 30 |
| Convergence criterion | — (fixed iterations) |
| N (pages) | 31 |
| `page_rank/0` | Returns List(#(String, Float)) |

**Top PageRank tiers** (31-node complete graph, all scores equal = 1/31 ≈ 0.032 in complete graph):

### 1.16 Chinese Postman Problem (Test Coverage Bound)

**Source**: `testing/nav_graph.gleam`

**Formula**:
```
CPP = |E| + matching_cost(odd_degree_vertices)
```

For the C3I navigation digraph (complete 31-node directed graph):
```
|E| = n × (n-1) = 31 × 30 = 930
CPP = 930   (all nodes have equal in/out degree → no odd-degree augmentation needed)
```

| Parameter | Value |
|-----------|-------|
| `page_count/0` | 31 |
| `edge_count/0` | 930 |
| `density/0` | 1.0 |
| `scc_count/0` | 1 |
| `chinese_postman_bound/0` | 930 |

### 1.17 Exponential Moving Average (Build History)

**Source**: Rust `ignition_daemon/src/db.rs` (EMA α constant)

**Formula**:
```
EMA_t = α × value_t + (1 - α) × EMA_{t-1}
α = 0.3
```

| Parameter | Value |
|-----------|-------|
| Alpha | 0.3 |
| Staleness thresholds | P0: 72h, Standard: 168h |
| Usage | Build time smoothing, trend detection |

---

## Section 2: Rules Engine — All 52 GRL Rules

**Source**: `sub-projects/c3i/native/ignition_daemon/src/rule_engine.rs`
**Engine**: rust-rule-engine v1.20.1 (RETE-UL algorithm)
**Architecture**: Generic `run_domain()` + 13 `OnceLock` caches, 41 unit tests

### 2.1 OODA Decide Domain (7 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Emergency Stop | 100 | `threat_level == "emergency"` | `decision = "emergency_stop"` |
| Boot When All Dead | 90 | `healthy_count == 0 AND total_containers > 0` | `decision = "boot_all"` |
| Restart Critical Unhealthy | 85 | `critical_unhealthy_count > 0` | `decision = "restart_critical"` |
| Restart If Major Degraded | 80 | `degraded_pct > 0.5` | `decision = "restart_degraded"` |
| Consult LLM On Uncertainty | 70 | `confidence < 0.3 AND llm_available` | `decision = "escalate_to_llm"` |
| Minor Degraded Log | 60 | `degraded_pct > 0 AND degraded_pct <= 0.5` | `decision = "log_and_monitor"` |
| No Action Default | 1 | `true` (always fires last) | `decision = "no_action"` |

### 2.2 Preflight Gate Domain (4 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Block Critical Failure | 100 | `critical_failures > 0` | `gate = "block"` |
| Block Multiple Failures | 90 | `total_failures >= 3` | `gate = "block"` |
| Warn On Failures | 70 | `total_failures > 0` | `gate = "warn"` |
| Pass Gate | 1 | `true` | `gate = "pass"` |

### 2.3 Recovery Selection Domain (6 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| NIF Recovery | 90 | `failure_mode == "nif_crash"` | `playbook = "nif_reload"` |
| Cascade Recovery | 85 | `failure_mode == "cascade"` | `playbook = "cascade_break"` |
| Glibc Recovery | 80 | `failure_mode == "glibc_error"` | `playbook = "container_rebuild"` |
| Memory Recovery | 75 | `failure_mode == "oom"` | `playbook = "memory_expansion"` |
| Timeout Recovery | 70 | `failure_mode == "timeout"` | `playbook = "timeout_extension"` |
| Default Recovery | 1 | `true` | `playbook = "standard_restart"` |

All 6 rules use RPN prioritization: recovery ordered by Severity × Occurrence × Detection.

### 2.4 Health Consensus Domain (4 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Critical Consensus | 100 | `criticality == "critical"` | `required_votes = 4` |
| High Consensus | 80 | `criticality == "high"` | `required_votes = 3` |
| Standard Consensus | 60 | `criticality == "standard"` | `required_votes = 2` |
| Low Consensus | 40 | `criticality == "low"` | `required_votes = 2` |

FPPS consensus: `votes_needed = floor(N/2) + 1` for N=5 → minimum 3.

### 2.5 Cascade Containment Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Apoptosis Cascade | 100 | `cascade_depth >= 3` | `action = "apoptosis"` |
| Isolate Cascade | 80 | `cascade_depth >= 2` | `action = "isolate"` |
| Monitor Cascade | 60 | `cascade_depth >= 1` | `action = "monitor"` |

Cascade depth: number of layers where failure has propagated.

### 2.6 Partition Fencing Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Fence Minority | 100 | `minority_partition == true` | `action = "fence_minority"` |
| Preserve Data | 80 | `data_at_risk == true` | `action = "preserve_data"` |
| No Partition Action | 1 | `true` | `action = "no_action"` |

Split-brain prevention: minority partition fenced, majority maintains quorum.

### 2.7 Launch Tier Gate Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Halt Critical | 100 | `criticality == "critical" AND health < 0.5` | `gate = "halt"` |
| Continue Degraded | 70 | `health >= 0.5 AND health < 0.8` | `gate = "continue_degraded"` |
| Proceed Healthy | 50 | `health >= 0.8` | `gate = "proceed"` |

Used in 7-tier boot sequence DAG validation.

### 2.8 CPU Governor Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Full Speed | 80 | `cpu_pct < 60` | `mode = "full_speed"; schedulers = 16` |
| Heavy Throttle | 70 | `cpu_pct >= 80 AND cpu_pct < 85` | `mode = "heavy_throttle"; schedulers = 6` |
| CPU Wait | 100 | `cpu_pct >= 85` | `mode = "wait"` |

Maps to adaptive parallelism table (SC-CPU-GOV-006).

### 2.9 Verify Compliance Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Compliant | 90 | `violations == 0` | `status = "compliant"` |
| Degraded Compliance | 70 | `violations > 0 AND violations <= 3` | `status = "degraded"` |
| Non-Compliant | 100 | `violations > 3` | `status = "non_compliant"` |

### 2.10 Build Staleness Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Rebuild P0 | 90 | `age_hours > 72 AND criticality == "critical"` | `action = "rebuild_now"` |
| Standard Rebuild | 70 | `age_hours > 168` | `action = "rebuild_standard"` |
| Skip Build | 50 | `age_hours <= 72` | `action = "skip"` |

EMA α=0.3 smooths build time history in SQLite `build_history` table.

### 2.11 Apoptosis Grace Domain (4 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Immediate Death | 100 | `threat_level == "critical" AND cascade_imminent` | `grace_ms = 0` |
| Fast Apoptosis | 90 | `failure_mode == "cascade" OR threat_level == "emergency"` | `grace_ms = 2000` |
| Graceful Shutdown | 70 | `in_progress_requests > 0` | `grace_ms = 10000` |
| Default Grace | 1 | `true` | `grace_ms = 5000` |

Six-phase shutdown: SIGTERM → drain → checkpoint → dying gasp → SIGKILL → verify.

### 2.12 RCA Escalation Domain (4 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| L1 NIF RCA | 90 | `failure_layer == "L1" OR failure_mode == "nif"` | `rca_level = "L1_nif"` |
| L4 Container RCA | 80 | `failure_layer == "L4" OR failure_mode == "container"` | `rca_level = "L4_container"` |
| L6 Quorum RCA | 85 | `failure_layer == "L6" OR failure_mode == "quorum"` | `rca_level = "L6_quorum"` |
| L7 LLM RCA | 70 | `confidence < 0.5 AND llm_available` | `rca_level = "L7_llm"` |

Seven-level RCA: L1 NIF → L2 Component → L3 Domain → L4 Container → L5 Cognitive → L6 Quorum → L7 LLM.

### 2.13 Hysteresis Config Domain (3 Rules)

| Rule | Salience | Condition | Action |
|------|----------|-----------|--------|
| Aggressive Hysteresis | 80 | `oscillation_count > 5` | `hysteresis = "aggressive"; threshold_band = 0.15` |
| Conservative Hysteresis | 70 | `oscillation_count > 2` | `hysteresis = "conservative"; threshold_band = 0.10` |
| Default Hysteresis | 1 | `true` | `hysteresis = "default"; threshold_band = 0.05` |

Prevents threshold-crossing oscillation in health monitoring.

**Summary Table**:

| Domain | Rule Count | Key Function |
|--------|-----------|--------------|
| OODA Decide | 7 | `evaluate_decision()` |
| Preflight Gate | 4 | `evaluate_preflight()` |
| Recovery Selection | 6 | `evaluate_recovery()` |
| Health Consensus | 4 | `evaluate_health_consensus()` |
| Cascade Containment | 3 | `evaluate_cascade()` |
| Partition Fencing | 3 | `evaluate_partition()` |
| Launch Tier Gate | 3 | `evaluate_launch_tier()` |
| CPU Governor | 3 | `evaluate_governor()` |
| Verify Compliance | 3 | `evaluate_verify()` |
| Build Staleness | 3 | `evaluate_build()` |
| Apoptosis Grace | 4 | `evaluate_apoptosis()` |
| RCA Escalation | 4 | `evaluate_rca()` |
| Hysteresis Config | 3 | `evaluate_hysteresis()` |
| **TOTAL** | **52** | 13 domains |

---

## Section 3: Ruliology — Wolfram-Style Cellular Automata

**Source**: `ha/guard_grid.gleam` (L0_CONSTITUTIONAL, SAFETY-CRITICAL)

All CA operate on the 24-cell Guard Grid (8 layers × 3 modules per layer).

### 3.1 Wolfram Elementary CA Rules

General application: `apply_wolfram_rule(cells, rule_number)` — generic 8-bit lookup for any rule 0-255.

#### Rule 30 (Chaos Detection)

**Lookup table**: `[0,0,0,1,1,1,1,0]`
**Pattern**: Chaotic, no periodicity, sensitive to initial conditions
**Mapping**: `RuleCascade` — detected when entropy of resulting pattern > 0.7

#### Rule 54 (Oscillation Detection)

**Lookup table**: `[0,1,1,0,1,1,0,0]`
**Pattern**: Periodic structures with alternating active/inactive cells
**Mapping**: `RulePeriodic` — stable oscillation between failure modes

#### Rule 90 (Fractal — XOR Rule)

**Lookup table**: `[0,1,0,1,1,0,1,0]`
**Pattern**: Sierpinski triangle; self-similar at all scales
**Mapping**: `RuleIsolated` — failures isolated to specific fractal subtrees

#### Rule 110 (Complexity — Universal Computation)

**Lookup table constant** (actual from source): `[0,1,1,1,0,1,1,0]`
**Pattern**: Universal computation; Turing-complete
**Mapping**: `RuleSystemic` — systemic, complex failure propagation patterns
**Usage**: Primary rule for guard grid health evolution step

#### Rule 126 (Rapid Growth)

**Lookup table**: `[0,1,1,1,1,1,1,0]`
**Pattern**: Rapid symmetric growth from seed
**Mapping**: `RuleCascade` (accelerated) — fast-spreading failure detection

#### Rule 184 (Traffic Flow)

**Lookup table**: `[0,0,0,1,0,1,1,1]` (particle-conserving)
**Pattern**: Models traffic/flow; conserves particle count
**Mapping**: `RuleRecovering` — models recovery flow through the system

**CellularRule type variants**: `RuleNone | RuleCascade | RuleIsolated | RulePeriodic | RuleSystemic | RuleRecovering`

### 3.2 Multi-Rule Analysis

`multi_rule_analysis/1` runs ALL 6 rules sequentially and returns:
```
List(#(rule_number: Int, classification: CellularRule))
```
Enables composite failure signature analysis.

### 3.3 Conway's Game of Life

**Topology**: 8×3 toroidal grid (24 cells total, wraps at edges)
**Rules**: Birth on exactly 3 live neighbors (B3); Survival on 2 or 3 live neighbors (S23)

**Pattern Classification** (`classify_life_pattern/2`):

| Pattern | Condition | Meaning |
|---------|-----------|---------|
| Empty | all cells dead | Complete failure or quiescence |
| StillLife | state_t+1 == state_t AND live > 0 | Stable failure constellation |
| Oscillator | state_t+2 == state_t AND live > 0 | Periodic failure cycling |
| Glider | moving pattern detected | Propagating failure |
| Chaos | none of the above | Chaotic, unpredictable failure |

**Application**: Maps failure cells to live cells; runs GoL to predict failure propagation patterns.

### 3.4 Brian's Brain

**Topology**: 24-cell 1D ring (toroidal)
**States**: `BrainOff | BrainFiring | BrainRecovering`

**Transition rules**:
```
BrainFiring    → BrainRecovering   (always, unconditionally)
BrainRecovering→ BrainOff          (always, unconditionally)
BrainOff       → BrainFiring       IF exactly 2 neighbors in BrainFiring state
BrainOff       → BrainOff          otherwise
```

**Application**: Models failure activation/recovery cycles with refractory period. A cell that fires must recover before it can fire again — prevents oscillation death.

### 3.5 Langton's Ant

**Topology**: 8×3 grid (positions 0-23), wraps toroidally
**AntState**: `{position: Int, direction: Int, steps: Int, path: List(Int)}`
**Initial position**: 12 (L4 / column 1 — center of system)
**Directions**: 0=North, 1=East, 2=South, 3=West

**Rules**:
```
On FAILED cell:  turn RIGHT (+1 mod 4), mark cell PASSED, move forward
On PASSED cell:  turn LEFT  (-1 mod 4, mod 4), mark cell FAILED, move forward
```

**Application**: Ant traces failure propagation paths through the guard grid. Path history reveals which cells the "failure front" has visited. Emergent complex behavior from simple local rules.

---

## Section 4: Guard Grid Mathematical Model

**Source**: `ha/guard_grid.gleam` (L0_CONSTITUTIONAL)

### 4.1 Grid Structure

```
8 fractal layers × 3 modules per layer = 24 cells total

Layer | Module 0          | Module 1          | Module 2
------|-------------------|-------------------|------------------
L0    | constitutional    | guardian          | safety
L1    | nif               | telemetry         | atomic
L2    | component         | catalog           | parser
L3    | planning          | smriti            | database
L4    | podman            | system            | boot
L5    | cognitive         | ooda              | cortex
L6    | zenoh             | mesh              | federation
L7    | evolution         | hot_reload        | formal
```

### 4.2 Cell Verdicts

`GridCell.verdict` is one of: `PASSED | FAILED_EMPTY | FAILED_MISSING_FIELD | FAILED_TOO_SHORT | FAILED_CORRUPTED | FAILED_STALE`

### 4.3 Guard Grid Health Score

```
health_score = passed_cells / total_cells   ∈ [0.0, 1.0]
total_cells = 24
```

### 4.4 Shannon Entropy (Guard Grid)

Applied to the distribution of verdict types across 24 cells:
```
H_grid = -Σ p_verdict × log₂(p_verdict)   over 5 verdict types
```

High entropy = verdicts widely distributed (many different failure modes).
Low entropy = verdicts concentrated (uniform health or uniform failure).

### 4.5 Lyapunov Exponent

**Source**: `ha/guard_grid.gleam` (`lyapunov_estimate/1`)

**Formula**:
```
λ = log(spread_rate / max(recovery_rate, 0.001))

spread_rate   = failed_transitions / total_transitions
recovery_rate = recovery_transitions / total_transitions
```

| Value | Interpretation |
|-------|---------------|
| λ > 0 | Unstable — failures spread faster than recovery |
| λ = 0 | Neutral stability |
| λ < 0 | Stable — recovery dominates |

**Guard grid stability**: System is SAFE iff λ < 0 for all observed windows.

### 4.6 Hotspot Detection

```
hotspot_layer  = layer with highest failed_cells count
hotspot_module = module within hotspot_layer with highest failure_count
```

Drives targeted OODA restart decisions (prefer minimal-disruption remediation).

---

## Section 5: Graph Theory Coverage (Graphene NIF)

**Source**: `graphene.gleam` (L2_COMPONENT) → Rust `graphene_nif.so` via petgraph

### 5.1 NIF Function Catalog

| NIF Name | Typed Wrapper | Algorithm |
|----------|---------------|-----------|
| `graphene_bfs` | `graphene_bfs_typed/3` | Breadth-First Search |
| `graphene_dfs` | `graphene_dfs_typed/3` | Depth-First Search |
| `graphene_topological_sort` | `graphene_topological_sort_typed/1` | Kahn's algorithm |
| `graphene_scc` | `graphene_scc_typed/1` | Kosaraju / Tarjan SCC |
| `graphene_shortest_path` | `graphene_shortest_path_typed/3` | Dijkstra SSSP |
| `graphene_pagerank` | `graphene_pagerank_typed/3` | Power iteration |
| `graphene_analyze` | `graphene_analyze_typed/1` | Multi-metric analysis |

### 5.2 Graph Input Format

`graphene_build_graph(nodes: List(StateNode), edges: List(StateEdge))` → JSON string

```
StateNode: { id: String, label: String, metadata: List(#(String, String)) }
StateEdge: { from: String, to: String, weight: Float, label: String }
```

### 5.3 Algorithm Specifications

#### BFS/DFS

```
Input: graph_json, start_node_id, max_depth
Output: Result(List(String), String)   (visited nodes in order)
```

#### Topological Sort (DAG boot sequencing)

```
Input: graph_json (must be DAG)
Output: Result(List(String), String)   (topological order, error on cycle)
Application: 7-tier boot hierarchy ordering
```

#### Strongly Connected Components

```
Input: graph_json
Output: Result(List(List(String)), String)   (list of SCC lists)
Property: nav_graph has scc_count = 1 (fully connected)
```

#### Dijkstra Shortest Path

```
Input: graph_json, source, target
Output: Result(List(String), String)   (path as node ID list)
Complexity: O((V + E) log V)
```

#### PageRank

```
Input: graph_json, damping_factor, max_iterations
Output: Result(List(#(String, Float)), String)
Parameters: d=0.85, 30 iterations
```

#### Multi-Metric Analysis

`graphene_analyze_typed/1` returns composite JSON with: node_count, edge_count, density, diameter, clustering_coefficient, is_dag, scc_count, degree_distribution.

---

## Section 6: Geometric Mathematics (Kurbo NIF)

**Source**: `graphene.gleam` (Kurbo section) → Rust Kurbo library (Graphite project)

### 6.1 Path Operations

| NIF | Typed Wrapper | Operation |
|-----|---------------|-----------|
| `kurbo_path_from_points` | — | Construct BezPath from Point2 list |
| `kurbo_path_analyze` | — | Area, perimeter, bounding box, control points |
| `kurbo_path_transform` | — | Apply affine Transform2D to BezPath |
| `kurbo_path_apply_transform` | — | In-place transform application |

**BezPath**: Sequence of cubic/quadratic Bezier curves. Supports: `move_to`, `line_to`, `quad_to`, `curve_to`, `close_path`.

### 6.2 Shape Rendering

`kurbo_shape` / `kurbo_shape_typed/1` → SVG path string

| SvgShape | Parameters | Output |
|----------|-----------|--------|
| `SvgRect(x, y, w, h)` | Float × 4 | Rectangle SVG path |
| `SvgCircle(cx, cy, r)` | Float × 3 | Circle approximation |
| `SvgStar(cx, cy, r_outer, r_inner, points)` | Float × 5 | Star polygon |
| `SvgPolygon(points)` | List(Point2) | Arbitrary polygon |

### 6.3 Vec2 Mathematics

`kurbo_vec2_math` / typed wrappers:

| Function | Formula | Notes |
|----------|---------|-------|
| `kurbo_vec2_distance/2` | `√((x₂-x₁)² + (y₂-y₁)²)` | Euclidean distance |
| `kurbo_vec2_lerp/3` | `p₁ + t × (p₂ - p₁)` | Linear interpolation |
| `kurbo_vec2_normalize/1` | `v / \|v\|` | Unit vector |
| `kurbo_vec2_dot/2` | `x₁x₂ + y₁y₂` | Dot product |
| `kurbo_vec2_angle/2` | `atan2(cross, dot)` | Signed angle between vectors |

### 6.4 Affine Transform2D

```gleam
Transform2D {
  a: Float, b: Float,   // row 0: scale-x, shear-x
  c: Float, d: Float,   // row 1: shear-y, scale-y
  e: Float, f: Float    // translation: tx, ty
}
```

**Matrix form**:
```
[a  c  e]
[b  d  f]
[0  0  1]
```

Operations: identity, translation, rotation (angle), scale, compose (matrix multiply).

---

## Section 7: 3D Mathematics (Bevy NIF)

**Source**: `graphene.gleam` (Bevy math section) → Rust Bevy Math library

### 7.1 Vector Operations

`bevy_math_op` / typed wrappers (Point3 = {x, y, z: Float}):

| Function | Formula | Notes |
|----------|---------|-------|
| `bevy_math_vec3_cross/2` | `v₁ × v₂ = (y₁z₂-z₁y₂, z₁x₂-x₁z₂, x₁y₂-y₁x₂)` | Cross product → perpendicular vector |
| `bevy_math_vec3_lerp/3` | `p₁ + t × (p₂ - p₁)` | Component-wise lerp |
| `bevy_math_vec2_perp/1` | `(-y, x)` | 2D perpendicular (rotated 90° CCW) |

### 7.2 Quaternion Operations

`bevy_math_quat_rotate/2`:
```
Input:  quaternion {w, x, y, z}, vector {x, y, z}
Output: rotated vector {x, y, z}
Formula: v' = q × v × q⁻¹   (quaternion sandwich product)
```

Quaternion normalization maintained automatically by Bevy. Used for orientation-preserving mesh topology visualizations.

### 7.3 Matrix4 Transform

`bevy_math_mat4_transform/2`:
```
Input:  4×4 column-major matrix (16 floats as List(Float)), Point3
Output: transformed Point3
Formula: p' = M × [x, y, z, 1]ᵀ   (homogeneous coordinates)
```

| Matrix Use Case | Description |
|-----------------|-------------|
| Model matrix | Object-to-world space transform |
| View matrix | World-to-camera space |
| Projection matrix | Camera-to-clip space |
| MVP composite | model × view × projection |

### 7.4 Bevy ECS (Entity Component System)

| NIF | Operation |
|-----|-----------|
| `bevy_ecs_spawn/1` | Spawn entity with JSON component bundle |
| `bevy_ecs_query_all/0` | Return all entities and their components |
| `bevy_ecs_clear/0` | Remove all entities |

Used for fractal mesh topology visualization in the dashboard — nodes = entities, edges = component relationships.

---

## Section 8: Color Science (Bevy Color NIF)

**Source**: `graphene.gleam` (Bevy color section) → Rust Bevy Color library

### 8.1 Color Types

```gleam
Rgba { red: Float, green: Float, blue: Float, alpha: Float }   // Linear sRGB [0,1]
```

All color operations maintain `alpha` passthrough.

### 8.2 Color Space Conversions

`bevy_color_convert` / typed wrappers:

#### sRGBA ↔ HSLA

```
sRGB → HSL:
  max_c = max(R, G, B)
  min_c = min(R, G, B)
  L = (max_c + min_c) / 2
  S = (max_c - min_c) / (1 - |2L - 1|)   when L ≠ 0 or 1
  H = 60° × { (G-B)/(max-min)       if max=R
             { 2 + (B-R)/(max-min)   if max=G
             { 4 + (R-G)/(max-min)   if max=B

HSL → sRGB:
  C = (1 - |2L - 1|) × S
  X = C × (1 - |H/60 mod 2 - 1|)
  m = L - C/2
  (R,G,B) = (C,X,0) → (0,C,X) → (X,0,C) → ... depending on H sector
```

#### sRGBA → OKLCH

OKLCH (Lightness, Chroma, Hue) — perceptually uniform color space:
```
sRGB → linear sRGB (gamma expand: c_lin = c^2.2 approx)
linear sRGB → OKLab via M1 matrix:
  [l]   [0.4122  0.5363  0.0514] [R_lin]
  [m] = [0.2119  0.6770  0.1109] [G_lin]
  [s]   [0.0883  0.2817  0.6299] [B_lin]
then: l' = ∛l, m' = ∛m, s' = ∛s
OKLab via M2 matrix
L_ok = √(a² + b²), C = √(a² + b²), H = atan2(b, a)
```

#### OKLCH → sRGBA

Reverse of above; used for perceptually-uniform color interpolation in dashboard gradients.

### 8.3 Color Operations

| NIF | Operation |
|-----|-----------|
| `bevy_color_srgba_to_hsla` | sRGB → HSL with alpha |
| `bevy_color_hsla_to_srgba` | HSL → sRGB with alpha |
| Additional ops | OKLCH conversions, premultiplied alpha, luminance |

### 8.4 Dashboard Color Application

| Semantic | Hex | OKLCH L | OKLCH C | Use |
|----------|-----|---------|---------|-----|
| Accent | #00d4aa | 0.78 | 0.18 | Active states |
| Success | #3dd68c | 0.80 | 0.19 | Completed |
| Warning | #f5a623 | 0.76 | 0.21 | Degraded |
| Critical | #ff4757 | 0.62 | 0.23 | Errors |
| Background | #0a0e17 | 0.09 | 0.02 | Page bg |

Perceptual uniformity via OKLCH ensures equal visual prominence at equal chroma/lightness.

---

## Section 9: Correctness Invariants (Hoare Logic)

Format: `{Precondition} Code {Postcondition}`

### 9.1 Shannon Entropy

```
{H ∈ [0, log₂(|categories|)]}
  shannon_entropy(counts)
{result ≥ 0.0 ∧ result ≤ 3.0 ∧ result = -Σ p_i × log₂(p_i)}
```

### 9.2 CCM Monotonicity

```
{∀i: new_count_i ≥ old_count_i}
  ccm(new_counts)
{ccm_new ≥ ccm_old}
```

### 9.3 ITQS Composition

```
{H_norm ∈ [0,1] ∧ CCM ∈ [0,1] ∧ D_EA ∈ [0,1] ∧ FSI ∈ [0,1]}
  itqs(h_norm, ccm, d_ea, fsi)
{result ∈ [0,1] ∧ result = 0.25*H_norm + 0.35*CCM + 0.25*(1-D_EA) + 0.15*FSI}
```

### 9.4 Welford Numerical Stability

```
{n ≥ 1 ∧ baseline.m2 ≥ 0}
  update_stats(baseline, value)
{result.m2 ≥ 0 ∧ result.sample_count = n+1 ∧ |result.mean - true_mean| < ε}
```

Welford guarantees numerical stability where naive variance computation suffers catastrophic cancellation for large n.

### 9.5 Soft Purge Safety (Hot Reload)

```
{∀P: version(P, M) ≠ old}
  code:soft_purge(M)
{is_loaded(M) ∧ no_process_killed}
```

Contrapositive: if any process still runs old code, `soft_purge` returns `false` — reload aborted.

### 9.6 Guard Grid Entropy Bound

```
{grid.total_cells = 24 ∧ grid.passed_cells ∈ [0,24]}
  compute_entropy(grid)
{entropy ∈ [0, log₂(5)] = [0, 2.32]}
```

Five verdict types → maximum entropy 2.32 bits (uniform distribution over all 5 types).

### 9.7 Lyapunov Sign Invariant

```
{spread_rate ≥ 0 ∧ recovery_rate ≥ 0}
  lyapunov_estimate(transitions)
{
  λ < 0  ↔  recovery_rate > spread_rate    (stable)
  λ = 0  ↔  recovery_rate = spread_rate    (neutral)
  λ > 0  ↔  recovery_rate < spread_rate    (unstable)
}
```

### 9.8 RPN Bounds

```
{S ∈ [1,10] ∧ O ∈ [1,10] ∧ D ∈ [1,10]}
  rpn(severity, occurrence, detection)
{result ∈ [1, 1000] ∧ result = S × O × D}
```

### 9.9 SLO Budget Clamping

```
{good_events ≥ 0 ∧ total_events ≥ good_events ∧ target ∈ (0,1)}
  compute_slo(good_events, total_events, target)
{budget_consumed ∈ [0.0, 1.0]}
```

### 9.10 PageRank Convergence

```
{d ∈ (0,1) ∧ N > 0 ∧ graph is strongly connected}
  page_rank(graph, d, iterations)
{Σ PR(v) = 1.0 ∧ PR(v) > 0 ∀v}
```

Power iteration converges for strongly connected graph with damping d ∈ (0,1).

### 9.11 Fractal Dimension Bounds

```
{length(series) ≥ 2}
  fractal_dimension(series)
{result ∈ [1.0, 2.0]}
```

### 9.12 Hurst Exponent Bounds

```
{length(series) ≥ min_rs_length = 4}
  hurst_exponent(series)
{result ∈ [0.0, 1.0]}
```

Degenerate case (std_dev = 0 or n < 4): returns 0.5 (random walk assumption).

### 9.13 GRL Rule Engine Completeness

```
{facts ≠ ∅}
  evaluate_domain(facts)
{∃rule: rule.salience = 1 ∧ rule.condition = "true" → default_action_set}
```

Every domain has a salience=1 fallback rule that always fires, ensuring the engine never returns empty result.

### 9.14 Cellular Automata Bit Conservation (Rule 184)

```
{cells: List(Bool)}
  apply_rule_184(cells)
{count_true(result) = count_true(cells)}
```

Rule 184 conserves the number of "alive" (true) cells — a particle-conservation invariant.

---

## Section 10: STAMP Constraints

### SC-MATH-* Family

| ID | Constraint | Severity | Module |
|----|------------|----------|--------|
| SC-MATH-COV-001 | Shannon Entropy H ≥ 2.5 bits for test suite | CRITICAL | coverage_math.gleam |
| SC-MATH-COV-002 | CCM ≥ 0.90 before release | CRITICAL | coverage_math.gleam |
| SC-MATH-COV-003 | ITQS ≥ 0.85 (Grade B minimum) | HIGH | coverage_math.gleam |
| SC-MATH-COV-004 | D_EA ≤ 0.10 (≤10% divergence from expected) | HIGH | coverage_math.gleam |
| SC-MATH-COV-005 | FSI ≥ 0.70 (fleet stability) | HIGH | coverage_math.gleam |
| SC-MATH-COV-006 | All P0-minimum category counts MUST be met | CRITICAL | coverage_math.gleam |
| SC-MATH-001 | Health time series MUST be analyzed with calculus | HIGH | health_calculus.gleam |
| SC-MATH-002 | AcceleratingDecline trend MUST trigger immediate alert | CRITICAL | health_calculus.gleam |
| SC-MATH-003 | Welford MUST be used (not naive variance) | HIGH | anomaly_detector.gleam |
| SC-MATH-004 | Anomaly z-score threshold = 3.0 sigma | HIGH | anomaly_detector.gleam |

### SC-NIF-* Family

| ID | Constraint | Severity | Module |
|----|------------|----------|--------|
| SC-NIF-001 | All NIF calls MUST have Gleam typed wrappers | CRITICAL | graphene.gleam |
| SC-NIF-002 | NIF failures MUST return Result(_, String) | CRITICAL | graphene.gleam |
| SC-NIF-003 | NIF .so loading MUST be verified on startup | CRITICAL | c3i_nif.erl |
| SC-NIF-004 | NIF changes REQUIRE full server restart | CRITICAL | hot-reload-protocol.md |
| SC-NIF-005 | Kurbo paths MUST preserve point count through transforms | HIGH | graphene.gleam |
| SC-NIF-006 | Bevy quaternions MUST be normalized before operations | HIGH | graphene.gleam |

### SC-UIGT-* Family

| ID | Constraint | Severity | Module |
|----|------------|----------|--------|
| SC-UIGT-001 | Navigation graph MUST have SCC count = 1 | CRITICAL | nav_graph.gleam |
| SC-UIGT-002 | All 31 pages MUST be reachable from any page | CRITICAL | nav_graph.gleam |
| SC-UIGT-003 | Page count MUST equal 31 | HIGH | nav_graph.gleam |
| SC-UIGT-004 | Edge count MUST equal n×(n-1) = 930 | HIGH | nav_graph.gleam |
| SC-UIGT-005 | PageRank MUST converge (d=0.85, 30 iterations) | MEDIUM | nav_graph.gleam |
| SC-UIGT-006 | Graph density MUST be 1.0 (complete digraph) | MEDIUM | nav_graph.gleam |
| SC-UIGT-007 | CPP bound MUST equal edge_count (930) | MEDIUM | nav_graph.gleam |
| SC-UIGT-008 | BFS MUST reach all pages from any start node | HIGH | nav_graph.gleam |
| SC-UIGT-009 | DFS MUST visit all pages | HIGH | nav_graph.gleam |
| SC-UIGT-010 | Topological sort MUST succeed on DAG boot graph | CRITICAL | graphene.gleam |
| SC-UIGT-011 | Shortest path MUST exist between any two pages | HIGH | graphene.gleam |
| SC-UIGT-012 | SCC MUST return single component | HIGH | graphene.gleam |
| SC-UIGT-013 | Graphene NIF MUST be loaded at test start | CRITICAL | graphene.gleam |
| SC-UIGT-014 | Kurbo Vec2 operations MUST be numerically stable | HIGH | graphene.gleam |

### SC-FMEA-* Family

| ID | Constraint | Severity | Module |
|----|------------|----------|--------|
| SC-FMEA-001 | RPN ≥ 200 MUST be P0Critical (immediate action) | CRITICAL | fmea_generator.gleam |
| SC-FMEA-002 | All 20 system FMEA entries MUST cover L0-L7 | HIGH | fmea_generator.gleam |
| SC-FMEA-003 | FMEA MUST be regenerated after each architecture change | HIGH | fmea_generator.gleam |
| SC-FMEA-004 | Detection score = 1 MUST NOT coexist with Occurrence ≥ 8 | HIGH | fmea_generator.gleam |
| SC-FMEA-005 | Every failure mode MUST have a mitigation entry | CRITICAL | fmea_generator.gleam |

### SC-GUARD-GRID-* Family

| ID | Constraint | Severity | Module |
|----|------------|----------|--------|
| SC-GUARD-GRID-001 | Guard grid MUST have exactly 24 cells | CRITICAL | guard_grid.gleam |
| SC-GUARD-GRID-002 | Rule 110 MUST be applied at every health check | CRITICAL | guard_grid.gleam |
| SC-GUARD-GRID-003 | Lyapunov λ > 0 MUST trigger cascade alert | CRITICAL | guard_grid.gleam |
| SC-GUARD-GRID-004 | Entropy < 0.5 bits AND health < 0.5 MUST trigger L0 alert | HIGH | guard_grid.gleam |
| SC-GUARD-GRID-005 | multi_rule_analysis MUST run all 6 rules | HIGH | guard_grid.gleam |
| SC-GUARD-GRID-006 | Conway GoL MUST detect StillLife (stable failure constellation) | HIGH | guard_grid.gleam |

### SC-SLO-* Family

| ID | Constraint | Severity | Module |
|----|------------|----------|--------|
| SC-SLO-001 | truth_slo target MUST be 99.999999% | CRITICAL | slo_tracker.gleam |
| SC-SLO-002 | SLOViolated MUST page on-call immediately | CRITICAL | slo_tracker.gleam |
| SC-SLO-003 | SLOAtRisk MUST trigger preventive action | HIGH | slo_tracker.gleam |
| SC-SLO-004 | Error budget consumed_pct MUST be displayed on dashboard | HIGH | slo_tracker.gleam |

### AOR Rules (Mathematical)

| ID | Rule |
|----|------|
| AOR-MATH-001 | ALWAYS use Welford's algorithm for online variance (never naive) |
| AOR-MATH-002 | ALWAYS clamp Hurst exponent to [0,1] — raw R/S can exceed bounds |
| AOR-MATH-003 | ALWAYS use central difference for derivatives when n ≥ 3 |
| AOR-MATH-004 | NEVER use soft_purge when processes still hold old code |
| AOR-MATH-005 | ALWAYS run multi_rule_analysis (all 6 CA rules) for comprehensive failure signature |
| AOR-MATH-006 | NEVER report D_EA > 0.10 as acceptable — force P1 alert |
| AOR-MATH-007 | ALWAYS verify SCC count = 1 before publishing navigation metrics |
| AOR-MATH-008 | NEVER hard-purge BEAM modules (kills processes) |
| AOR-NIF-001 | ALWAYS provide typed wrapper for every raw NIF call |
| AOR-NIF-002 | ALWAYS handle `Error(msg)` from NIF — never pattern-match only `Ok` |
| AOR-GUARD-001 | ALWAYS check Lyapunov before making restart decisions |
| AOR-GUARD-002 | ALWAYS run Rule 110 as primary CA (universal computation) |
| AOR-FMEA-001 | ALWAYS escalate RPN ≥ 200 to P0 task queue immediately |
| AOR-FMEA-002 | ALWAYS update FMEA within 24h of new failure mode discovery |

---

## Section 11: Fractal Coverage Matrix (8 Layers × 17 Disciplines)

Legend: ✓ = Implemented and tested | P = Partial/indirect | — = Not applicable at this layer

| Math Discipline | L0 | L1 | L2 | L3 | L4 | L5 | L6 | L7 |
|----------------|----|----|----|----|----|----|----|----|
| 1. Shannon Entropy | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 2. CCM / Coverage | ✓ | ✓ | ✓ | ✓ | P | ✓ | P | ✓ |
| 3. ITQS | ✓ | ✓ | ✓ | ✓ | P | ✓ | P | ✓ |
| 4. Kolmogorov | — | ✓ | P | P | P | ✓ | P | P |
| 5. Mutual Info | — | P | P | ✓ | P | ✓ | P | P |
| 6. Transfer Entropy | — | — | — | P | — | ✓ | P | P |
| 7. Fractal Dimension | — | ✓ | P | P | P | ✓ | P | P |
| 8. Hurst Exponent | — | ✓ | — | P | P | ✓ | P | — |
| 9. Health Calculus | ✓ | ✓ | P | P | ✓ | ✓ | P | P |
| 10. Welford / Anomaly | ✓ | ✓ | P | ✓ | ✓ | ✓ | P | P |
| 11. FMEA / RPN | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| 12. SLO / Error Budget | ✓ | P | P | ✓ | ✓ | ✓ | P | P |
| 13. PageRank | ✓ | ✓ | ✓ | ✓ | P | ✓ | ✓ | ✓ |
| 14. Chinese Postman | P | ✓ | ✓ | P | — | ✓ | P | P |
| 15. Wolfram CA | ✓ | P | P | P | ✓ | ✓ | P | P |
| 16. Lyapunov / GoL | ✓ | P | P | P | ✓ | ✓ | P | P |
| 17. EMA / Build | — | — | P | ✓ | ✓ | P | — | — |

### Coverage Statistics

| Layer | Implemented | Partial | N/A | Coverage % |
|-------|-------------|---------|-----|-----------|
| L0 Constitutional | 10 | 3 | 4 | 76% direct |
| L1 Atomic/Debug | 11 | 4 | 2 | 88% |
| L2 Component | 5 | 9 | 3 | 82% |
| L3 Transaction | 8 | 7 | 2 | 88% |
| L4 System | 7 | 7 | 3 | 82% |
| L5 Cognitive | 15 | 2 | 0 | 100% |
| L6 Ecosystem | 3 | 11 | 3 | 82% |
| L7 Federation | 5 | 7 | 5 | 71% |

**Overall**: 64 ✓ + 50 P + 22 — of 136 cells = 83.8% meaningful coverage

### Layer-Discipline Ownership

| Layer | Primary Math Owner | Justification |
|-------|-------------------|---------------|
| L0 Constitutional | Guard Grid CA + Lyapunov | Safety-critical failure detection |
| L1 Atomic/Debug | Coverage Math (H, CCM, ITQS) | Test quality measurement |
| L2 Component | Graph Theory (BFS/DFS/SCC) | Navigation + component structure |
| L3 Transaction | SLO + Anomaly Detection | Data integrity monitoring |
| L4 System | FMEA + EMA | Container lifecycle risk |
| L5 Cognitive | Full Analysis (all 17) | Cognitive substrate owns all math |
| L6 Ecosystem | PageRank + Transfer Entropy | Mesh topology + causal analysis |
| L7 Federation | ITQS + PageRank | Cross-node quality + routing |

---

## Appendix A: Gleam Module to Discipline Mapping

| Module | Primary Discipline(s) | Layer |
|--------|-----------------------|-------|
| `testing/coverage_math.gleam` | H, CCM, ITQS, FSI, D_EA | L1 |
| `ha/math_analysis.gleam` | Kolmogorov, MutualInfo, TE, FractalDim, Hurst | L5 |
| `ha/health_calculus.gleam` | Differential Calculus on health | L5 |
| `ha/guard_grid.gleam` | Wolfram CA, GoL, Brian's Brain, Langton, Lyapunov | L0 |
| `ha/anomaly_detector.gleam` | Welford Online Algorithm | L5 |
| `ha/fmea_generator.gleam` | FMEA RPN | L4 |
| `ha/slo_tracker.gleam` | SLO Error Budget | L5 |
| `testing/nav_graph.gleam` | PageRank, CPP, Graph theory | L1 |
| `graphene.gleam` | All Graphene/Kurbo/Bevy NIFs | L2 |

## Appendix B: Rust Module to Discipline Mapping

| Rust Module | Primary Discipline(s) |
|-------------|----------------------|
| `ignition_daemon/src/rule_engine.rs` | 52 GRL Rules, RETE-UL |
| `ignition_daemon/src/ruliology.rs` | Wolfram CA (Rust side), causal graphs |
| `ignition_daemon/src/math_monitor.rs` | 17 mathematical disciplines health |
| `ignition_daemon/src/health_orchestra.rs` | FPPS consensus, 2oo3 voting |
| `ignition_daemon/src/db.rs` | EMA build history (α=0.3) |
| `graphene_nif/src/` | petgraph BFS/DFS/SCC/Dijkstra/PageRank |
| `kurbo_nif/src/` | Kurbo path geometry |
| `bevy_nif/src/` | Bevy Math + Bevy Color |

## Appendix C: Thresholds Quick Reference

| Metric | Threshold | Consequence of Violation |
|--------|-----------|--------------------------|
| Shannon H | ≥ 2.5 bits | Test distribution inadequate → CCM penalized |
| CCM | ≥ 0.90 | Release blocked |
| ITQS | ≥ 0.85 (B) | Evolution fitness insufficient |
| D_EA | ≤ 0.10 | P1 alert, implementation gap |
| FSI | ≥ 0.70 | Fleet instability detected |
| FMEA RPN | < 200 | P0 action required if ≥ 200 |
| Lyapunov λ | < 0.0 | λ ≥ 0 triggers cascade alert |
| Hurst H | > 0.5 | Persistent (non-random) failure trend |
| SLO consumed | < 0.50 | SLOAtRisk ≥ 0.50, SLOViolated ≥ 1.0 |
| Guard health | ≥ 0.80 | Below triggers hotspot RCA |
| Anomaly z | \|z\| ≤ 3.0 | Above → AnomalyHigh/Low alert |
| Fractal D_f | ∈ [1.0, 2.0] | Clamped (cannot violate) |
| ITQS grade A | ≥ 0.90 | Target; B (≥0.85) acceptable for release |

---

*Specification generated 2026-04-12 from actual source code.*
*Authoritative sources: `testing/coverage_math.gleam`, `ha/*.gleam`, `testing/nav_graph.gleam`, `graphene.gleam`, `ignition_daemon/src/rule_engine.rs`*
*Version: 22.6.0-DHARMA | SIL-6 | IEC 61508 | DO-178C DAL-A equivalent*
