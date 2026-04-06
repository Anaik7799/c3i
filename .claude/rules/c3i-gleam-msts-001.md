---
paths:
- lib/cepaf_gleam/**/*.gleam
- src/**/*.gleam
---
# C3I Mathematical & Semantic Traceability Standard (MSTS)
# 1. Overview & Scope
*   **Purpose:** To enforce mathematically sound, zero-semantic-loss code migration from the CLR (F# CEPAF) to the BEAM (Gleam C3I). This framework guarantees runtime invariants are preserved across architectural paradigms.
*   **Compliance:** DO-178C DAL-A, IEC 61508 SIL-6.
*   **Applicability:** Mandatory for all `.gleam` files across the C3I runtime system.
# 2. Transformation Morphisms (Category Theory)
Agents MUST tag semantic transformations using structural morphisms. This declares exactly how an F# construct maps to Gleam and what data/metadata is lost or preserved.
*   $\cong$ **Isomorphic (`isomorphic`):** Perfect 1:1 mapping. Zero information loss.
*   *Example:* F# `Record` $\cong$ Gleam `Custom Type`.
*   $\twoheadrightarrow$ **Surjective (`surjective`):** Lossy mapping. The F# structure contains metadata (Reflection, CLR Exceptions, Timezones) that Gleam does not natively support. A `<mitigation>` block is strictly required.
*   *Example:* F# `try/with` $\twoheadrightarrow$ Gleam `Result(T, Error)`. Mitigation: Exception stack traces are dropped; explicit telemetry IDs must be attached to the Error variant.
*   *Example:* F# `typeof<'T>.Name` $\twoheadrightarrow$ Gleam Type Erasure. Mitigation: Type names must be passed explicitly as `String` arguments.
*   $\hookrightarrow$ **Injective (`injective`):** Embedded mapping. The F# structure is embedded into a broader BEAM runtime feature.
*   *Example:* F# `MailboxProcessor<'T>` $\hookrightarrow$ Gleam `gleam/otp/actor`.
*   $\oslash$ **Prohibited (`prohibited`):** F# constructs that are illegal in SIL-6 Gleam.
*   *Examples:* Mutable global state, `null`, unbounded recursion, non-exhaustive active patterns.
# 3. Fractal Architecture Topology
Every file MUST declare its topological position in the 7-Layer Biomorphic Mesh (refer to `AGENTS.md`).
| Layer | Domain Focus | Typical Gleam Implementation |
| :--- | :--- | :--- |
| **L0_CONSTITUTIONAL** | Safety, Types, Cryptography | `core/types.gleam`, `core/ids.gleam` |
| **L1_ATOMIC_DEBUG** | Telemetry, Tracing | `telemetry/otel.gleam` |
| **L2_COMPONENT** | Pure Logic, Parsers | `planning/parser.gleam` |
| **L3_TRANSACTION** | State Mutations, DB, Actors | `db/sqlite.gleam`, `planning/manager.gleam` |
| **L4_SYSTEM** | PodmanAPI, Host OS | `podman/client.gleam` |
| **L5_COGNITIVE** | MCP, UI Logic, Advisory | `mcp/server.gleam` |
| **L6_ECOSYSTEM** | Mesh Orchestration, Zenoh | `zenoh/lifecycle.gleam` |
| **L7_FEDERATION** | Multi-node Consensus | `verification/swarm.gleam` |
# 4. The C3I Module-Level Safety Contract
Every Gleam file MUST begin with this exact XML-augmented block.
```gleam
//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>path/to/module</module>
////     <fsharp-lineage>Cepaf.Namespace.File.fs</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L3_TRANSACTION</layer>
////   </fractal-topology>
////   <compliance>
////     <stamp-controls>SC-XXX-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="surjective" loss="reflection">
////       F# `typeof<'T>.Name` ↠ Explicit String passing.
////       Mitigation: Type Name passed explicitly to Zenoh serialization.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
```
# 5. The Atomic Design by Contract (DbC)
Complex functions MUST utilize Hoare Logic (`{P} C {Q}`) to formally prove state transitions.
```gleam
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="injective">F# Async ↪ Gleam OTP</morphism>
///   <formal-proof>
///     <P> Pre-condition: UserID is authenticated. </P>
///     <C> execute_transaction(user_id) </C>
///     <Q> Post-condition: Result(State, Error) is returned. Never panics. </Q>
///   </formal-proof>
/// </c3i-atomic>
```
# 6. Resolution of Known CLR ➡️ BEAM Semantic Conflicts
When operating under MSTS, agents must adhere to these resolutions:
1.  **Constructor Clashes:** Gleam lacks `[<RequireQualifiedAccess>]`. If F# DUs share constructor names (e.g., `Unknown`), they MUST be renamed to avoid module-scope collision (e.g., `UnknownTask`, `UnknownHealth`).
2.  **Equality:** F# `Object.ReferenceEquals` is prohibited. Rely on BEAM structural equality (`==`).
3.  **Time/Dates:** F# `DateTimeOffset` maps to `Int` (Unix Epoch). Timezone logic MUST be explicitly managed if required.
# 7. Way of Working for Agents
When an autonomous agent (e.g., `@fractal-architect`) is tasked with porting or modifying Gleam code:
1.  **Read Ancestry:** Use the `read` or `glob` tool to find the corresponding `*.fs` file in `lib/cepaf/`.
2.  **Determine Fractal Layer:** Analyze the file's purpose and assign the correct `L0-L7` layer based on Section 3.
3.  **Identify Morphisms:** Analyze the F# syntax. If Reflection, Exceptions, or Task/Async are used, determine the corresponding `Surjective` or `Injective` morphism.
4.  **Draft Contract:** Write the `[C3I-SIL6-MSTS]` header at the top of the `.gleam` file.
5.  **Implement Logic:** Write the Gleam code, using Result types exclusively for errors.
6.  **Verify:** Run `gleam check` and `gleam format --check src/`. Zero defects are mandatory.