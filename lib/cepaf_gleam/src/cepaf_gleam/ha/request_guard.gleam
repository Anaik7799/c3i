//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ha/request_guard</module>
////     <fsharp-lineage>None — novel HTTP request admission gate (SC-SIL4-001)</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L0_CONSTITUTIONAL</layer>
////     <mesh-domain>
////       Request guard — evaluates guard grid health before admitting an HTTP
////       request to a critical API endpoint.  A fresh GuardGrid reflects the
////       topological state at call time; if health_score is below the critical
////       threshold (0.3) the request is rejected with 503.
////
////       This is a pure gate: no side effects, no I/O.  Callers integrate it
////       at the start of handler functions in router.gleam.
////     </mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>SAFETY-CRITICAL</criticality>
////     <stamp-controls>
////       SC-SIL4-001, SC-FUNC-002, SC-SATYA-001, SC-TRUTH-001,
////       SC-NASA-001, SC-GLM-UI-001, SC-GLM-UI-003
////     </stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="injective">
////       GuardGrid.health_score ↪ GuardResult ADT.
////       All logic is pure; callers own HTTP plumbing.
////     </morphism>
////     <morphism type="surjective" loss="wall-clock time">
////       A freshly initialised grid (all PASSED) always returns 1.0.
////       Mitigation: callers with persistent grid state SHOULD pass a
////       pre-populated grid via check_with_grid/1 for accurate runtime checks.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// REQUEST GUARD — HTTP admission gate backed by GuardGrid health
//// अभयं सत्त्वसंशुद्धिः — Fearlessness and purity of being (Gita 16.1)
////
//// Usage (in router.gleam handler):
////
////   case request_guard.check() {
////     request_guard.Proceed -> handle_normal_logic()
////     request_guard.Block(reason) -> request_guard.service_unavailable(reason)
////   }
////
//// STAMP: SC-SIL4-001, SC-FUNC-002, SC-SATYA-001, SC-NASA-001

import cepaf_gleam/ha/guard_grid
import gleam/float
import gleam/http/response.{type Response}

// ---------------------------------------------------------------------------
// Critical health threshold — below this the service is considered unsafe
// ---------------------------------------------------------------------------

/// Minimum health score required to admit requests.
/// Grid health < 0.3 means ≥ 70 % of the 24 cells have failed verdicts —
/// the system is in a degraded state where serving requests risks cascading
/// failures.  Chosen at 0.3 to match the "Emergency" cockpit mode threshold
/// (SC-HMI-010).
const critical_threshold: Float = 0.3

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// Decision returned by the guard — caller routes accordingly.
pub type GuardResult {
  /// System is healthy enough — proceed with the normal handler.
  Proceed
  /// System health is below critical_threshold — reject this request.
  Block(reason: String)
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Check whether the system is healthy enough to accept an API request.
///
/// Initialises a fresh GuardGrid (all cells start as PASSED → health = 1.0).
/// Use `check_with_grid/1` if you hold a persistent, runtime-updated grid.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="injective">guard_grid.init() ↪ GuardResult</morphism>
///   <formal-proof>
///     <P> No precondition — always safe to call. </P>
///     <C> check() </C>
///     <Q> Returns Proceed when health >= 0.3, Block otherwise.
///         Never panics; health is clamped to [0.0, 1.0] by guard_grid. </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn check() -> GuardResult {
  let grid = guard_grid.init()
  check_with_grid(grid)
}

/// Check health using a caller-supplied guard grid.
///
/// Prefer this over `check/0` when the grid is maintained in actor state,
/// as it reflects actual runtime verdict history rather than a fresh snapshot.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="injective">GuardGrid.health_score ↪ GuardResult</morphism>
///   <formal-proof>
///     <P> grid is a valid GuardGrid (non-negative cell counts). </P>
///     <C> check_with_grid(grid) </C>
///     <Q> health = grid.health_score.
///         health >= critical_threshold → Proceed.
///         health <  critical_threshold → Block with descriptive reason. </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn check_with_grid(grid: guard_grid.GuardGrid) -> GuardResult {
  let health = guard_grid.health_score(grid)
  case health <. critical_threshold {
    True ->
      Block(
        "System health critical ("
        <> float.to_string(health)
        <> ") — request rejected",
      )
    False -> Proceed
  }
}

/// Build a 503 Service Unavailable response for a blocked request.
///
/// The body contains the reason string as-is (plain text).
/// Callers SHOULD wrap the reason in JSON if their endpoint contract requires
/// it — this helper deliberately stays format-agnostic so it can be used from
/// any handler.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <formal-proof>
///     <P> reason is a non-empty string. </P>
///     <C> service_unavailable(reason) </C>
///     <Q> Returns Response(String) with status=503 and body=reason. </Q>
///   </formal-proof>
/// </c3i-atomic>
pub fn service_unavailable(reason: String) -> Response(String) {
  response.new(503)
  |> response.set_body(reason)
  |> response.set_header("content-type", "text/plain")
  |> response.set_header("x-guard-blocked", "true")
}

/// Build a 503 response with a JSON body for API endpoints.
///
/// Produces: {"error":"service_unavailable","reason":"<reason>"}
pub fn service_unavailable_json(reason: String) -> Response(String) {
  let body =
    "{\"error\":\"service_unavailable\",\"reason\":\""
    <> reason
    <> "\"}"
  response.new(503)
  |> response.set_body(body)
  |> response.set_header("content-type", "application/json")
  |> response.set_header("x-guard-blocked", "true")
}

/// Expose the critical threshold constant for external use (e.g. tests).
pub fn critical_health_threshold() -> Float {
  critical_threshold
}
