# GEMINI.md — Indrajaal c3i Multi-Language System Spec (Root)
**Version**: 21.4.0-GLM | **Status**: ACTIVE | **Primary Language**: Gleam (BEAM) | **Date**: 2026-04-01

## Language Architecture
| Language | Role | Build Command | Constraint |
|:---|:---|:---|:---|
| **Gleam** | Primary c3i language — all new logic | `gleam build` / `gleam test` / `gleam format` | SC-GLM-CMP-001 to SC-GLM-CMP-005 |
| **Rust** | NIF boundary only (Zenoh FFI) | `cargo build --release` / `cargo test` | SC-NIF-001 to SC-NIF-006, SC-GLM-NIF-001 to SC-GLM-NIF-005 |
| **Elixir** | Web portal (Phoenix LiveView, OTP) | `mix compile --jobs 16` / `mix test` | SC-ENV-COMPILE-001 to SC-ENV-COMPILE-008 |
| **F#** | Legacy bridge/cognitive (Phase 6 substrate) | `dotnet build` / `dotnet test` | SC-FSH-003 to SC-FSH-122 |

## Build Order (AOR-BUILD-001)
```
Rust NIFs → Gleam → Elixir → F# (if needed)
```

### Category G: Architectural Oversight and Assertion (AOR) (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| AOR-ARCH-001 | Gleam is the primary language for all new c3i system logic, ensuring code consistency and maintainability. | Code reviews, static analysis tools |
| AOR-NIF-001 | Rust NIFs must have a clearly defined interface contract with Gleam, minimizing risk of runtime errors and unsafety. | Interface documentation, property testing |
| AOR-POLYGLOT-001 | Language boundaries (Gleam-Rust, Gleam-Elixir, Gleam-F#) must be explicitly documented and tested for interoperability. | Architectural diagrams, integration tests |
| AOR-BUILD-002 | The build order MUST be strictly followed to ensure correct compilation dependencies across all languages. | CI script validation |

## Canonical GEMINI.md Location
Full spec: `intelitor-v5.2/GEMINI.md` (v21.4.0-GLM)

---

### Category D: Compilation Safety (SC-CMP-025 to SC-CMP-035)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-CMP-025 | System SHALL prevent compilation with ANY warnings | --warnings-as-errors for Gleam (primary for c3i) and Elixir, -D warnings for Rust NIFs, /warnaserror for F# |
| SC-CMP-026 | System SHALL ensure complete file compilation for the C3I system (prioritizing Gleam and Rust for NIFs), while supporting Elixir and F# | `gleam build`, `cargo build --release`, `mix compile --jobs 16`, `dotnet build` |
| SC-CMP-027 | System SHALL maintain compilation determinism | Reproducibility check — Gleam BEAM output deterministic |
| SC-CMP-028 | System SHALL prevent compilation interruption | Process monitoring |
| SC-CMP-029 | System SHALL validate syntax correctness | Pre-compilation: `gleam check` (fast type-check gate) |
| SC-CMP-030 | System SHALL ensure dependency resolution | `gleam deps download`, `mix deps.get`, `cargo fetch` |
| SC-CMP-031 | System SHALL prevent compilation environment drift | `devenv.nix` canonical, `gleam.toml` pinned |
| SC-CMP-032 | System SHALL maintain compilation performance baselines | Performance monitoring — Gleam build < 5s target |
| SC-CMP-033 | System SHALL use appropriate parallelization flags | Elixir: `--jobs 16`, `+S 16:16`; Gleam: BEAM-native; Rust: `-j 16` |
| SC-CMP-034 | System SHALL ensure language-specific tooling is available in container | `gleam`, `rustc`, `elixir`, `dotnet` in `devenv.nix` |
| SC-CMP-035 | System SHALL ensure NIFs for Rust are correctly compiled and linked | `priv/native/libzenoh_ffi.so` verified before BEAM boot |

### Category E: Gleam-Specific Safety (SC-GLM-CMP-001 to SC-GLM-CMP-005, NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-GLM-CMP-001 | `gleam build` MUST produce zero warnings and zero errors | CI gate + pre-commit |
| SC-GLM-CMP-002 | `gleam format` MUST pass before any Gleam commit | Pre-commit hook |
| SC-GLM-CMP-003 | `gleam check` MUST pass as pre-commit fast gate | Type-check without full build |
| SC-GLM-CMP-004 | Gleam modules MUST compile to BEAM bytecode (not JS) | `target = "erlang"` in `gleam.toml` |
| SC-GLM-CMP-005 | Gleam-Elixir FFI boundary MUST use typed OTP message passing | Code review + property test |

### Category F: Migration Safety (SC-GLM-MIG-001 to SC-GLM-MIG-005, NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| SC-GLM-MIG-001 | F# and Gleam enforcers MUST dual-run during Phases 1-2 | Runtime check |
| SC-GLM-MIG-002 | Semantic drift < 5% between F# and Gleam | Property test comparison |
| SC-GLM-MIG-003 | F# modules NOT deleted until Gleam passes all TDG tests | Pre-deletion gate |
| SC-GLM-MIG-004 | Container substrate remains F# until cognitive layers verified | Phase 6 gate |
| SC-GLM-MIG-005 | Migration progress tracked in `doc/plans/` with timestamps | Audit check |

### Category H: State Management and Transition Protocol (STAMP) (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| STAMP-STATE-001 | All system states, especially those involving Gleam and Rust components, MUST be deterministic and auditable. | Runtime verification, state replayability |
| STAMP-CONCUR-001 | Concurrent access to shared state across language boundaries must be managed via thread-safe mechanisms or explicit locking. | Concurrency testing, lock analysis |
| STAMP-PERSIST-001 | Persistent state (e.g., database, file system) MUST be handled with robust transactionality and recovery mechanisms. | Transaction integrity checks, disaster recovery drills |

### Category I: Failure Mode and Error Analysis (FEMA) (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| FEMA-ERROR-001 | Comprehensive error handling and fault tolerance are MANDATORY for all system components, regardless of language. | Code review, fault injection testing |
| FEMA-NIF-001 | Rust NIFs MUST include explicit error propagation and robust safety checks to prevent memory unsafety. | Fuzz testing, static analysis for memory safety |
| FEMA-LOGGING-001 | Detailed logging and diagnostics must be implemented to facilitate rapid analysis of failure modes. | Log analysis tools, automated log validation |

### Category J: Skills and Agent Integration (NEW)
| ID | Constraint | Verification |
|----|-----------|--------------|
| AGENT-SKILL-001 | Gemini CLI will leverage specialized skills for Gleam (`gleam-expert`) and Rust NIF development (`skill-creator` if needed). | Skill activation logs, agent task reports |
| AGENT-PROTO-001 | All agent operations MUST adhere to the Active State Synchronization Protocol (ASSP) and relevant GEMINI/CLAUDE protocols for traceability. | ASSP compliance checks, journal entries |
| AGENT-LANG-001 | Agents managing code development MUST be configured to use Gleam as primary, Rust for NIFs, and support Elixir/F#. | Agent configuration review |