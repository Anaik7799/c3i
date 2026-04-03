# P0 Integrated Plan: ProofToken + Reflex Core + Mojo MAX + Substrate Sovereignty

**Timestamp**: 20260328-2328 CEST
**Author**: Claude Opus 4.6
**Plan File**: `.claude/plans/sharded-honking-hamster.md`
**Tasks**: 5740a000, c2467ea8, da5b06f9, e134393a

---

## 1. Scope & Trigger

Four P0 tasks require integrated delivery as a unified plan. The central innovation is a **Mojo MAX compute container** joining the SIL-6 biomorphic mesh via Zenoh, enabling Substrate-Native Cognitive Sovereignty (FAIP v3.0) — the system's ability to function without external AI APIs.

**Triggering event**: User directive to create integrated plan for all four P0 tasks with explicit focus on Mojo MAX + FLAME runner integration.

**Tasks scoped**:
| Task ID | Title | Priority |
|---------|-------|----------|
| 5740a000 | Rust NIF-Layer ProofToken Enforcement (<1ms) | P0-HARDENING |
| c2467ea8 | Elixir Reflex Core (Nx/EXLA/Bumblebee) | P0-EXISTENTIAL |
| e134393a | Mojo MAX Compute Container (indrajaal-mojo) | P0-EXISTENTIAL |
| da5b06f9 | Substrate-Native Cognitive Sovereignty (FAIP v3.0) | P0-OMEGA |

---

## 2. Pre-State Assessment

### 2.1 Current State
- **ProofToken**: Exists in Rust NIF (`native/zenoh_nif/src/proof_token.rs`, 623 lines). Control-plane only enforcement via `is_control_plane(key)`. No tiered enforcement, no session caching.
- **ReflexCore**: GenServer exists (`lib/indrajaal/core/reflex/reflex_core.ex`, 492 lines) with compile-time Nx/Bumblebee detection. Graceful degradation stubs return `{:error, :nx_not_available}`. No EXLA backend, no preloaded models.
- **FLAME Pools**: 3 inline pools in `AutonomicSupervisor` (lines 24-41): Intelligence(10), Video(20), Analytics(15). `FLAMESupervisor` exists as empty stub (21 lines). `Pools.pools()` already defines configs.
- **Mojo**: No container, no Zenoh neural bridge, no MojoRunner GenServer.
- **Sovereignty**: No InferenceRouter, no fine-tuning collector, no Turing baseline benchmark.
- **SIL-6 Mesh**: 14 containers operational. IP 172.28.0.85 available for Mojo container.

### 2.2 Key Architectural Constraint
**FLAME ≠ Mojo**: FLAME (`FLAME.call/3`) is for elastic BEAM process pools — it cannot call external containers. The Mojo integration requires a separate `MojoRunner` GenServer communicating via Zenoh pub/sub, supervised as a sibling under `FLAMESupervisor`.

---

## 3. Execution Detail

### Wave 1: ProofToken Hardening + FLAME Supervisor Consolidation

**ProofToken Tiered Enforcement** — 3-tier model to avoid crushing telemetry:

| Tier | Key Prefix | Enforcement | Latency Target |
|------|-----------|-------------|----------------|
| 0 (bypass) | `indrajaal/logs/**`, `indrajaal/metrics/**`, `indrajaal/health/**` | None | 0 |
| 1 (session) | `indrajaal/inference/**`, `indrajaal/neural/**` | Session HMAC (cached 60s) | <5us |
| 2 (full) | `indrajaal/control/**`, `indrajaal/evolution/**` | Full HMAC per call | <10us |

Files: `proof_token.rs` (add SessionToken + TTL cache), `publisher.rs` (refactor to `enforce_tiered()`), `lib.rs` (new NIF exports), `Cargo.toml` (criterion benchmarks).

**FLAME Supervisor Consolidation** — Move 3 inline FLAME.Pool children from `AutonomicSupervisor` into `FLAMESupervisor` using `Pools.pools()`.

### Wave 2: Mojo MAX Container + Zenoh Neural Bridge

**Container**: Ubuntu 22.04 base (confirmed as Modular's only officially supported Linux distro), IP 172.28.0.85, 12GB RAM, 4 CPUs, port 11436.

**NixOS assessment**: NixOS **cannot** be used as the container base. The nixpkgs package request (#257274) was closed as "not planned" (Sep 2025). Blockers: account-based SDK downloads, single-user license incompatible with Nix store. The standard pattern applies: NixOS host + Ubuntu container via Podman (per Omega-2).

**Zenoh Key Expressions**:
- `indrajaal/inference/request/{id}` — Elixir→Mojo
- `indrajaal/inference/response/{id}` — Mojo→Elixir
- `indrajaal/inference/health` — Mojo health beacon
- `indrajaal/inference/metrics` — Throughput/latency

**MojoRunner GenServer**: UUID request correlation, circuit breaker (5 timeouts → open, 60s reset), semaphore (10 concurrent, 100 queued).

### Wave 3: ReflexCore ML Wiring + Inference Router

**Dependencies**: `{:exla, "~> 0.9"}`, `{:bumblebee, "~> 0.6"}`, `{:tokenizers, "~> 0.4"}`

**ReflexCore**: EXLA backend config, preload `all-MiniLM-L6-v2` (embeddings, 22M params) + `distilbert-base-uncased-finetuned-sst-2-english` (sentiment, 66M params).

**InferenceRouter**: Symbiotic Dual Mode fallback chain:
1. OpenRouter (external, if online + budget) → capture training pair
2. MojoRunner (Zenoh, if circuit breaker closed)
3. ReflexCore (Nx in-process, if models loaded)
4. `{:error, :all_backends_failed}`

### Wave 4: Substrate Sovereignty (FAIP v3.0)

**Fine-Tuning Collector**: Capture `{input, golden_output}` pairs when external API succeeds → DuckDB `indrajaal_training_data`.

**Turing Baseline**: 50 curated benchmarks, cosine similarity between external + local outputs, target >0.85 correlation.

**Sovereignty Modes**: `:symbiotic` (full chain), `:airgap` (Mojo + Reflex only), `:degraded` (Reflex only).

---

## 4. Root Cause Analysis

### Why 4 tasks must be integrated
These tasks are **causally chained**: ProofToken gates Zenoh inference traffic (Wave 1) → MojoRunner publishes/subscribes via Zenoh (Wave 2) → ReflexCore provides local fallback (Wave 3) → InferenceRouter orchestrates the full chain for sovereignty (Wave 4).

Building them in isolation would create interface mismatches. The tiered ProofToken design was specifically driven by inference traffic volume (Tier 1 session caching exists because of MojoRunner's high-frequency pub/sub).

### Why FLAME cannot directly serve Mojo
FLAME's `call/3` spawns ephemeral BEAM processes on elastic nodes. It has no concept of external container IPC. The architectural pattern for external compute in Indrajaal is Zenoh pub/sub with request-response correlation — matching the existing SIL-6 mesh topology.

---

## 5. Fix Taxonomy

| Category | Count | Examples |
|----------|-------|---------|
| New modules | 8 | MojoRunner, MojoHealthSubscriber, InferenceRouter, FineTuningCollector, CorrelationBenchmark, serve.py, Containerfile, zenoh-mojo.json5 |
| Modified modules | 9 | proof_token.rs, publisher.rs, lib.rs, Cargo.toml, flame_supervisor.ex, autonomic_supervisor.ex, reflex_core.ex, podman-compose.yml, mix.exs |
| New test files | 4 | mojo_runner_test.exs, mojo_health_subscriber_test.exs, inference_router_test.exs, fine_tuning_collector_test.exs |
| Criterion benchmarks | 1 | proof_token_bench.rs |

---

## 6. Patterns & Anti-Patterns Discovered

### Patterns (Good)
- **Zenoh request-response correlation**: UUID-based request/response key pairing is the standard Indrajaal pattern for external compute integration (also used by SMRITI federation, GitIntelligence bridge).
- **Feature detection at compile time**: `@exla_available Code.ensure_loaded?(EXLA)` — ReflexCore already uses this pattern for graceful degradation.
- **Circuit breaker as first-class**: MojoRunner follows the Sentinel/SymbioticDefense pattern of circuit breakers for external dependencies.

### Anti-Patterns (Avoided)
- **Enforcing ProofToken on ALL NIF calls**: Would add latency to every telemetry publish. Tiered enforcement avoids this.
- **Using FLAME.call for Mojo**: Would conflate elastic BEAM pools with external container IPC. Separate GenServer avoids semantic confusion.
- **Preloading large models on boot**: Only lightweight models (MiniLM 22M, DistilBERT 66M) preloaded. Heavy inference goes to MojoRunner.

---

## 7. Verification Matrix

| Wave | Verification | Command |
|------|-------------|---------|
| W1 | ProofToken benchmarks | `cd native/zenoh_nif && cargo bench --bench proof_token_bench` |
| W1 | Compile after supervisor consolidation | `source scripts/cpu-governor.sh && governed_compile` |
| W1 | Existing tests pass | `governed_test test/indrajaal/supervisors/` |
| W2 | Build Mojo container | `podman build -t localhost/indrajaal-mojo:latest lib/cepaf/artifacts/mojo-container/` |
| W2 | MojoRunner tests | `governed_test test/indrajaal/compute/mojo_runner_test.exs` |
| W3 | Compile with ML deps | `governed_compile` (Nx + EXLA) |
| W3 | InferenceRouter tests | `governed_test test/indrajaal/core/reflex/inference_router_test.exs` |
| W4 | Fine-tuning collector tests | `governed_test test/indrajaal/core/reflex/fine_tuning_collector_test.exs` |
| W4 | Turing Baseline | `mix run -e "Indrajaal.Core.Reflex.CorrelationBenchmark.run()"` |

---

## 8. Files Modified

### New Files (13)
| # | File | Purpose |
|---|------|---------|
| 1 | `lib/indrajaal/compute/mojo_runner.ex` | Zenoh bridge GenServer to Mojo container |
| 2 | `lib/indrajaal/compute/mojo_health_subscriber.ex` | Mojo health beacon subscriber |
| 3 | `lib/indrajaal/core/reflex/inference_router.ex` | Symbiotic Dual Mode fallback router |
| 4 | `lib/indrajaal/core/reflex/fine_tuning_collector.ex` | Training data capture GenServer |
| 5 | `lib/indrajaal/core/reflex/correlation_benchmark.ex` | Turing Baseline measurement |
| 6 | `lib/cepaf/artifacts/mojo-container/Containerfile` | Mojo MAX container (Ubuntu 22.04) |
| 7 | `lib/cepaf/artifacts/mojo-container/serve.py` | MAX Engine + Zenoh inference server |
| 8 | `config/zenoh/zenoh-mojo.json5` | Zenoh client config for Mojo |
| 9 | `native/zenoh_nif/benches/proof_token_bench.rs` | Criterion latency benchmarks |
| 10 | `test/indrajaal/compute/mojo_runner_test.exs` | MojoRunner unit tests |
| 11 | `test/indrajaal/compute/mojo_health_subscriber_test.exs` | Health subscriber tests |
| 12 | `test/indrajaal/core/reflex/inference_router_test.exs` | Router tests |
| 13 | `test/indrajaal/core/reflex/fine_tuning_collector_test.exs` | Collector tests |

### Modified Files (9)
| # | File | Change |
|---|------|--------|
| 1 | `native/zenoh_nif/src/proof_token.rs` | Tiered enforcement, SessionToken TTL cache |
| 2 | `native/zenoh_nif/src/publisher.rs` | Refactor to `enforce_tiered()` |
| 3 | `native/zenoh_nif/src/lib.rs` | Session token + benchmark NIF exports |
| 4 | `native/zenoh_nif/Cargo.toml` | Add criterion dev-dependency |
| 5 | `lib/indrajaal/compute/flame_supervisor.ex` | Populate with FLAME pools + MojoRunner |
| 6 | `lib/indrajaal/supervisors/autonomic_supervisor.ex` | Replace inline pools with FLAMESupervisor |
| 7 | `lib/indrajaal/core/reflex/reflex_core.ex` | EXLA backend, preload models |
| 8 | `lib/cepaf/artifacts/podman-compose-sil6-full-mesh.yml` | Add indrajaal-mojo at 172.28.0.85 |
| 9 | `mix.exs` | Add exla, bumblebee, tokenizers deps |

---

## 9. Architectural Observations

### 9.1 Inference Topology
The InferenceRouter creates a 3-tier fallback that maps to the system's survival hierarchy:
- **External (OpenRouter)**: Highest quality, but vulnerable to network/API failures and cost
- **Local-heavy (MojoRunner)**: Good quality (Llama-3-8B), runs on local hardware, Zenoh-connected
- **Local-light (ReflexCore)**: Fast (<50ms), limited capability (embeddings/sentiment), always available

This maps directly to the FAIP v3.0 sovereignty modes: symbiotic → airgap → degraded.

### 9.2 Container Architecture Impact
Adding `indrajaal-mojo` brings the mesh to **15 containers**. The 12GB RAM + 4 CPU allocation is significant — this is the heaviest single container in the mesh. Memory pressure monitoring via PatternHunter (SC-IMMUNE-003) becomes critical.

### 9.3 Mojo OS Decision — Ubuntu 22.04 Confirmed
**Research result**: Modular officially supports **only Ubuntu 22.04 LTS** for Linux. The MAX container images on Docker Hub (`modular/max-nvidia-full`, etc.) all use Ubuntu 22.04 as base. NixOS packaging was rejected by nixpkgs maintainers (issue #257274, closed Sep 2025) due to incompatible SDK distribution model. The plan's original Containerfile specification was correct.

### 9.4 GPU Tier Information
Mojo MAX GPU support tiers (for future reference when deploying on GPU-equipped hardware):
- **Tier 1**: NVIDIA B200/H100/H200, AMD MI355X/MI300X/MI325X
- **Tier 2**: NVIDIA A100/A10/L4/L40/RTX 50/40/30XX
- **Tier 3**: Apple silicon, NVIDIA RTX 20XX/T4, AMD Radeon RX 9000/7000

Current plan is CPU-only (GGUF models). GPU acceleration is a future enhancement.

---

## 10. Remaining Gaps

| Gap | Severity | Mitigation |
|-----|----------|------------|
| GGUF model download in Containerfile | P1 | Need to decide specific model (Llama-3-8B-Q4_K_M) and download source (HuggingFace) |
| Zenoh Python client version for serve.py | P2 | Need to verify zenoh-python compatibility with zenoh 1.7 router |
| EXLA/Bumblebee download on first boot | P2 | Models download from HuggingFace on first `Bumblebee.load_model` — need offline caching strategy |
| MojoRunner timeout tuning | P3 | 30s default may be too high for local inference; needs benchmarking |
| DuckDB schema for training data | P2 | Need to define `indrajaal_training_data` table schema |
| Sovereignty mode switching via Zenoh | P3 | Key expression `indrajaal/sovereignty/mode` needs Guardian approval integration |

---

## 11. Metrics Summary

| Metric | Value |
|--------|-------|
| New STAMP constraint families | 4 (SC-MOJO, SC-NEURAL-BRIDGE, SC-SOVEREIGNTY, SC-INFERENCE-ROUTER) |
| New STAMP constraint IDs | ~25 (SC-MOJO-001..008, SC-NEURAL-BRIDGE-001..005, SC-SOVEREIGNTY-001..005, SC-INFERENCE-ROUTER-001..004, SC-NIF-010..012) |
| New files | 13 |
| Modified files | 9 |
| New test files | 4 |
| Estimated new lines | ~3,000-4,000 |
| Container count | 14 → 15 |
| Mesh RAM increase | +12GB (Mojo container) |

---

## 12. STAMP & Constitutional Alignment

### Constitutional Invariants
| Invariant | Alignment |
|-----------|-----------|
| Psi-0 (Existence) | Substrate sovereignty ensures system survives API outages |
| Psi-1 (Regeneration) | Training data in DuckDB enables model improvement from sovereign state |
| Psi-2 (History) | All inference requests logged to Immutable Register |
| Psi-3 (Verification) | Turing Baseline provides measurable sovereignty metric |
| Psi-4 (Founder Alignment) | Reduces dependency on external AI vendors — cost reduction + data sovereignty |
| Omega-0 (Founder's Covenant) | Direct resource acquisition capability (no API vendor lock-in) |
| Omega-2 (Container Isolation) | Mojo runs in Podman rootless container on NixOS host |
| Omega-7 (Holon Sovereignty) | Training data in DuckDB (not external service) |

### New STAMP Constraints
- **SC-MOJO-001..008**: Container health, Zenoh connection, GGUF integrity, memory limits
- **SC-NEURAL-BRIDGE-001..005**: Request correlation, circuit breaker, backpressure, audit
- **SC-SOVEREIGNTY-001..005**: Air-gap survival, Turing baseline, training capture, mode switch
- **SC-INFERENCE-ROUTER-001..004**: Configurable fallback, fast path <100ms, health check
- **SC-NIF-010..012**: Tiered enforcement, session caching, benchmark

---

## 13. Conclusion

This integrated plan delivers Substrate-Native Cognitive Sovereignty through 4 waves that build on each other: hardened NIF security (W1) → external compute bridge (W2) → local ML wiring (W3) → sovereignty orchestration (W4). The key architectural insight is that FLAME and Mojo serve fundamentally different roles — FLAME for elastic BEAM processes, Mojo for external ML inference via Zenoh. The fallback chain (External → Mojo → Reflex) provides graceful degradation aligned with the biomorphic immune system's defense-in-depth philosophy.

**Platform decision**: Ubuntu 22.04 LTS confirmed as the only viable OS for the Mojo container. NixOS packaging is blocked upstream. This is architecturally sound — the NixOS host provides the reproducible development environment while Ubuntu containers serve as the runtime substrate for proprietary SDKs.

**Next action**: Begin Wave 1 implementation (ProofToken tiered enforcement + FLAME supervisor consolidation).

---

Sources:
- [Mojo System Requirements](https://docs.modular.com/mojo/requirements/)
- [MAX Container Documentation](https://docs.modular.com/max/container/)
- [NixOS Mojo Package Request #257274](https://github.com/NixOS/nixpkgs/issues/257274)
- [Modular Platform GitHub](https://github.com/modular/modular)
- [Modular Blog: Mojo Docker Setup](https://www.modular.com/blog/how-to-setup-a-mojo-development-environment-with-docker-containers)
