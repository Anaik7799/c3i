# NIF Stability & Substrate Verification Framework

**Version:** 1.0.0
**Status:** ACTIVE
**Goal:** Formalize the rules, constraints, and operational mechanisms to guarantee BEAM VM stability when interacting with Native Implemented Functions (NIFs).

## 1. STAMP Safety Constraints (SC-NIF)

| ID | Constraint | Severity | Enforcement |
|----|------------|----------|-------------|
| **SC-NIF-001** | All NIFs performing I/O or blocking operations (>1ms) SHALL be marked `schedule = "DirtyCpu"` or `DirtyIo`. | CRITICAL | Code Review / AST Analysis |
| **SC-NIF-002** | The system SHALL gracefully bypass NIF compilation if the native toolchain (`cargo`) is missing, falling back to Elixir implementations or Safe Mocks. | HIGH | Compile-time macro checks |
| **SC-NIF-003** | Rust NIFs SHALL NEVER use `panic="abort"` in their build profiles. All panics MUST unwind to be caught by Rustler. | CRITICAL | Cargo.toml audit |
| **SC-NIF-004** | Async Rust execution (e.g., Tokio) SHALL NOT leak lifetimes into the BEAM. Tokio runtimes MUST be isolated and block on futures at the NIF boundary. | CRITICAL | Architectural constraint |
| **SC-NIF-005** | Any un-proven control signal intercepted at the Elixir wrapper layer SHALL be dropped before crossing the FFI boundary to the NIF. | CRITICAL | `verify_substrate_safety/2` |

## 2. Agent Operating Rules (AOR-NIF)

| ID | Rule | Description |
|----|------|-------------|
| **AOR-NIF-001** | **Check Dirty Schedulers** | Agents MUST verify `DirtyCpu` or `DirtyIo` annotations exist on any NIF calling a network, filesystem, or heavy computation routine. |
| **AOR-NIF-002** | **Implement Fallbacks** | Agents MUST wrap `use Rustler` in compile-time environment checks (`@cargo_available`, `SKIP_NIF_BUILD`) to prevent container boot crash loops. |
| **AOR-NIF-003** | **Enforce ProofTokens** | Agents MUST NOT pass data from the Complex Plane (AI) directly to a NIF without validating a PROMETHEUS `ProofToken` in the Elixir proxy layer. |
| **AOR-NIF-004** | **No Bare Pointers** | Agents MUST use `ResourceArc<T>` for passing state between Erlang and Rust. Bare memory pointers are strictly forbidden. |

## 3. FMEA: NIF Integration Risks

| Failure Mode | Proximate Cause | Effect | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|---|---|
| **Scheduler Starvation** | CPU-bound NIF runs >1ms on normal scheduler. | VM lockup, missed heartbeats, system partition. | 10 | 3 | 4 | **120** | `schedule = "DirtyCpu"` annotation. |
| **Crash Loop** | Missing `cargo` in runtime container. | Application fails to compile, orchestrator restarts container indefinitely. | 8 | 5 | 2 | **80** | Compile-time checks (`@cargo_available`) + Elixir fallbacks. |
| **Host Segfault** | Memory corruption or `panic="abort"` in Rust. | Complete BEAM VM crash. Loss of ephemeral state. | 10 | 2 | 8 | **160** | Rust memory safety (no `unsafe` blocks), `panic="unwind"`. |
| **Rogue Signal** | Untrusted mutation payload passed to Zenoh NIF. | Actuators perform unsafe actions across the mesh. | 10 | 4 | 2 | **80** | Elixir-layer ProofToken validation (`SC-EVO-002`) prior to NIF dispatch. |

## 4. Test-Driven Generation (TDG-NIF)

- **TDG-NIF-001:** Test modules MUST verify the fallback behavior when the NIF is disabled (e.g., simulating `SKIP_NIF_BUILD=1`).
- **TDG-NIF-002:** NIFs interacting with the Zenoh mesh MUST have PropCheck generators that simulate malformed, huge, and unexpected payloads to prove the Rustler boundary does not panic.

## 5. Mathematical & Cybernetic Control (PROMETHEUS)

- **KL Divergence Monitoring:** If the NIF layer begins returning anomalous latency metrics or error rates, the `Homeostasis` engine will register an increase in KL Divergence.
- **OODA Throttling:** The continuous control loop will automatically scale back background evolution tasks to prevent overwhelming the stressed NIF boundary.