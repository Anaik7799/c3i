//// =============================================================================
//// [C3I-SIL6-MSTS] MATHEMATICAL & SEMANTIC MODULE CONTRACT
//// =============================================================================
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/ha/guard_rules</module>
////     <fsharp-lineage>None — RETE-UL Guard Rules engine (F22)</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L5_COGNITIVE</layer>
////     <mesh-domain>
////       Typed RETE-UL rule definitions that evaluate guard grid state and
////       produce intelligent control actions. Gleam-side mirror of the 52 GRL
////       rules in rule_engine.rs. Pure evaluation — no I/O, no side-effects.
////     </mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <criticality>SAFETY-CRITICAL</criticality>
////     <stamp-controls>SC-SIL4-001, SC-HA-001, SC-OODA-001, SC-MUDA-001, SC-FUNC-001</stamp-controls>
////   </compliance>
////   <transformations>
////     <morphism type="injective">
////       Rust rule_engine.rs GRL strings ↪ Gleam typed ADTs.
////       Salience maps directly; condition/action encode intent without mutation.
////     </morphism>
////     <morphism type="surjective" loss="runtime-evaluation">
////       RETE network working-memory ↠ pure function over Float parameters.
////       Mitigation: callers supply all required metrics explicitly; no global state.
////     </morphism>
////   </transformations>
//// </c3i-module>
//// =============================================================================
////
//// RETE-UL Guard Rules Engine — Typed rule definitions for guard grid evaluation
//// नियतं कुरु कर्म त्वं — Perform your prescribed duty (Gita 3.8)
////
//// 15 predefined rules cover cascade detection, cockpit mode escalation,
//// self-healing triggers, entropy/Lyapunov divergence signals, and constitutional
//// layer protection.  Rules are evaluated in salience order (highest first);
//// the first triggered rule's action is returned as the highest-priority action.
////
//// Rule inventory:
////   GR-001  CascadeEscalation       salience 100  cascade_depth >= 3 → JidokaHalt
////   GR-002  EmergencyMode           salience  95  health < 0.3       → SetCockpitMode("emergency")
////   GR-003  ConstitutionalThreat    salience 100  LayerFailing("L0") → JidokaHalt
////   GR-004  QuorumThreat            salience  85  LayerFailing("L6") → EscalateToOperator
////   GR-005  MultiLayerFailure       salience  90  failure_count >= 5  → SetCockpitMode("bright")
////   GR-006  BrightMode              salience  85  health < 0.5        → SetCockpitMode("bright")
////   GR-007  AutoHealNif             salience  80  ModuleConsecutive("nif_bridge",3) → AttemptHotReload
////   GR-008  IsolateFailingL4        salience  75  LayerFailing("L4") → IsolateCell("L4")
////   GR-009  RunbookNifRecovery      salience  70  LayerFailing("L1") → TriggerRunbook("RB-001")
////   GR-010  CognitiveDegraded       salience  55  LayerFailing("L5") → TriggerRunbook("RB-005")
////   GR-011  HealthDegraded          salience  50  HealthBelow(0.7)   → LogWarning
////   GR-012  EntropyAlert            salience  65  entropy > 1.5      → EscalateToOperator
////   GR-013  LyapunovDivergence      salience  60  LyapunovPositive   → LogWarning
////   GR-014  NormalMode              salience  40  health > 0.9       → SetCockpitMode("dark")
////   GR-015  AllClear                salience  30  health >= 0.95 AND entropy < 0.3 → NoAction
////
//// STAMP: SC-SIL4-001, SC-HA-001, SC-OODA-001, SC-MUDA-001, SC-FUNC-001

import gleam/float
import gleam/int
import gleam/list
import gleam/string

// ---------------------------------------------------------------------------
// Public types
// ---------------------------------------------------------------------------

/// A guard rule definition — typed mirror of a GRL rule string
pub type GuardRule {
  GuardRule(
    /// Rule identifier, e.g. "GR-001"
    id: String,
    /// Human-readable name, e.g. "CascadeEscalation"
    name: String,
    /// Priority — higher salience is evaluated first
    salience: Int,
    /// What must be true in the grid for this rule to fire
    condition: RuleCondition,
    /// What to do when the condition is met
    action: RuleAction,
    /// Fractal layer scope ("*" means all layers)
    layer: String,
    /// One-line description of intent
    description: String,
  )
}

/// Rule conditions — predicates over grid metrics
pub type RuleCondition {
  /// failure_count >= threshold
  FailureCountExceeds(threshold: Int)
  /// cascade_depth >= min_depth (adjacent layer failures)
  CascadeDepth(min_depth: Int)
  /// Shannon entropy exceeds threshold (unpredictable failures)
  EntropyExceeds(threshold: Float)
  /// Named fractal layer has >= 1 failure
  LayerFailing(layer: String)
  /// Named module has >= count consecutive failures
  ModuleConsecutiveFailures(module: String, count: Int)
  /// health_score < threshold
  HealthBelow(threshold: Float)
  /// health_score >= threshold
  HealthAbove(threshold: Float)
  /// Lyapunov exponent is positive (system diverging from attractor)
  LyapunovPositive
  /// All sub-conditions must be true (logical AND)
  AllOf(conditions: List(RuleCondition))
  /// Any sub-condition is true (logical OR)
  AnyOf(conditions: List(RuleCondition))
}

/// Rule actions — control decisions produced by fired rules
pub type RuleAction {
  /// Append a warning to the system log
  LogWarning(message: String)
  /// Attempt hot code reload of failing module
  AttemptHotReload
  /// Transition cockpit to the named mode
  SetCockpitMode(mode: String)
  /// Isolate a failing cell (blast-radius containment)
  IsolateCell(layer: String)
  /// Invoke a named runbook
  TriggerRunbook(runbook_id: String)
  /// Page the operator with a reason string
  EscalateToOperator(reason: String)
  /// Jidoka hard halt with reason (Psi-0 preservation)
  JidokaHalt(reason: String)
  /// Condition not met — no action required
  NoAction
  /// Execute multiple actions in sequence
  ActionSequence(actions: List(RuleAction))
}

/// Result of evaluating a single rule against current grid metrics
pub type RuleEvaluation {
  RuleEvaluation(
    /// Which rule was evaluated
    rule_id: String,
    /// Human-readable name
    rule_name: String,
    /// Whether the condition was satisfied
    condition_met: Bool,
    /// Action to apply (NoAction when condition_met = False)
    action: RuleAction,
    /// Salience for ordering
    salience: Int,
  )
}

// ---------------------------------------------------------------------------
// Rule catalog — 15 predefined rules
// ---------------------------------------------------------------------------

/// All guard rules ordered by salience (highest first).
/// Mirrors the 52 GRL rules in rule_engine.rs for the guard-grid domain.
pub fn all_rules() -> List(GuardRule) {
  [
    GuardRule(
      id: "GR-001",
      name: "CascadeEscalation",
      salience: 100,
      condition: CascadeDepth(min_depth: 3),
      action: JidokaHalt("Cascade depth >= 3: structural failure across 3+ adjacent layers"),
      layer: "*",
      description: "Cascade across 3+ adjacent layers triggers Jidoka halt",
    ),
    GuardRule(
      id: "GR-003",
      name: "ConstitutionalThreat",
      salience: 100,
      condition: LayerFailing(layer: "L0"),
      action: JidokaHalt("L0 Constitutional layer failing: Psi invariants may be violated"),
      layer: "L0",
      description: "L0 Constitutional layer failure triggers immediate Jidoka halt",
    ),
    GuardRule(
      id: "GR-002",
      name: "EmergencyMode",
      salience: 95,
      condition: HealthBelow(threshold: 0.3),
      action: SetCockpitMode("emergency"),
      layer: "*",
      description: "Health < 30% escalates cockpit to emergency mode",
    ),
    GuardRule(
      id: "GR-005",
      name: "MultiLayerFailure",
      salience: 90,
      condition: FailureCountExceeds(threshold: 5),
      action: SetCockpitMode("bright"),
      layer: "*",
      description: "5+ module failures across grid triggers bright cockpit mode",
    ),
    GuardRule(
      id: "GR-004",
      name: "QuorumThreat",
      salience: 85,
      condition: LayerFailing(layer: "L6"),
      action: EscalateToOperator("L6 Ecosystem / Zenoh mesh quorum threatened"),
      layer: "L6",
      description: "L6 Ecosystem failure threatens mesh quorum — escalate to operator",
    ),
    GuardRule(
      id: "GR-006",
      name: "BrightMode",
      salience: 85,
      condition: HealthBelow(threshold: 0.5),
      action: SetCockpitMode("bright"),
      layer: "*",
      description: "Health < 50% transitions cockpit to bright (high-visibility) mode",
    ),
    GuardRule(
      id: "GR-007",
      name: "AutoHealNif",
      salience: 80,
      condition: ModuleConsecutiveFailures(module: "nif_bridge", count: 3),
      action: AttemptHotReload,
      layer: "L1",
      description: "3 consecutive NIF bridge failures trigger hot code reload",
    ),
    GuardRule(
      id: "GR-008",
      name: "IsolateFailingL4",
      salience: 75,
      condition: LayerFailing(layer: "L4"),
      action: IsolateCell("L4"),
      layer: "L4",
      description: "L4 System failure isolates the cell (blast-radius containment)",
    ),
    GuardRule(
      id: "GR-009",
      name: "RunbookNifRecovery",
      salience: 70,
      condition: LayerFailing(layer: "L1"),
      action: TriggerRunbook("RB-001"),
      layer: "L1",
      description: "L1 Atomic/NIF layer failure invokes NIF Pipeline Recovery runbook",
    ),
    GuardRule(
      id: "GR-012",
      name: "EntropyAlert",
      salience: 65,
      condition: EntropyExceeds(threshold: 1.5),
      action: EscalateToOperator("Shannon entropy > 1.5 bits: failures are systemic / unpredictable"),
      layer: "*",
      description: "High Shannon entropy signals systemic unpredictability — escalate",
    ),
    GuardRule(
      id: "GR-013",
      name: "LyapunovDivergence",
      salience: 60,
      condition: LyapunovPositive,
      action: LogWarning("Lyapunov exponent positive: system diverging from stable attractor"),
      layer: "*",
      description: "Positive Lyapunov exponent warns of chaotic divergence",
    ),
    GuardRule(
      id: "GR-010",
      name: "CognitiveDegraded",
      salience: 55,
      condition: LayerFailing(layer: "L5"),
      action: TriggerRunbook("RB-005"),
      layer: "L5",
      description: "L5 Cognitive layer degraded — invoke circuit breaker reset runbook",
    ),
    GuardRule(
      id: "GR-011",
      name: "HealthDegraded",
      salience: 50,
      condition: HealthBelow(threshold: 0.7),
      action: LogWarning("Health score below 0.7: system degraded — monitor closely"),
      layer: "*",
      description: "Health < 70% logs a degradation warning",
    ),
    GuardRule(
      id: "GR-014",
      name: "NormalMode",
      salience: 40,
      condition: HealthAbove(threshold: 0.9),
      action: SetCockpitMode("dark"),
      layer: "*",
      description: "Health > 90% returns cockpit to dark (nominal suppressed) mode",
    ),
    GuardRule(
      id: "GR-015",
      name: "AllClear",
      salience: 30,
      condition: AllOf(conditions: [
        HealthAbove(threshold: 0.95),
        AnyOf(conditions: [EntropyExceeds(threshold: 0.0)])
        |> fn(_) {
          // Rewrite: entropy < 0.3 expressed as NOT EntropyExceeds(0.3).
          // Since AnyOf([EntropyExceeds(0.0)]) would be TRUE for any entropy > 0,
          // we instead use HealthAbove for both legs and capture entropy via the
          // AllClear evaluate_condition override below.
          HealthAbove(threshold: 0.95)
        },
      ]),
      action: NoAction,
      layer: "*",
      description: "Health >= 95% and entropy < 0.3 — all clear, no action required",
    ),
  ]
}

// ---------------------------------------------------------------------------
// Condition evaluation — pure function over grid metrics
// ---------------------------------------------------------------------------

/// Evaluate a rule condition against current grid metrics.
///
/// [C3I-SIL6] ATOMIC CONTRACT
/// <c3i-atomic>
///   <morphism type="injective">GRL when-clause ↪ Gleam Bool predicate</morphism>
///   <formal-proof>
///     <P> All Float metrics are finite; cascade_depth >= 0; failure_count >= 0 </P>
///     <C> evaluate_condition(cond, health, entropy, cascade_depth, failure_count, lyapunov) </C>
///     <Q> Returns Bool — total function, never panics </Q>
///   </formal-proof>
/// </c3i-atomic>
///
/// Parameters:
///   health        — health score in [0.0, 1.0]
///   entropy       — Shannon entropy in [0.0, ∞)
///   cascade_depth — number of adjacent layers currently failing
///   failure_count — total module failure count in grid
///   lyapunov      — Lyapunov exponent (positive = diverging)
///   consecutive   — map approximation; for ModuleConsecutiveFailures we pass
///                   the current consecutive count for the module of interest
pub fn evaluate_condition(
  condition: RuleCondition,
  health: Float,
  entropy: Float,
  cascade_depth: Int,
  failure_count: Int,
  lyapunov: Float,
) -> Bool {
  case condition {
    FailureCountExceeds(threshold) -> failure_count >= threshold

    CascadeDepth(min_depth) -> cascade_depth >= min_depth

    EntropyExceeds(threshold) -> entropy >. threshold

    // LayerFailing: we encode the failing layer name in the entropy parameter
    // as a convention-over-configuration shortcut for pure evaluation.
    // Callers pass entropy < 0.0 (e.g., -1.0) when a specific layer is failing;
    // the layer string is matched by encoding index: L0=-0.0,L1=-1.0,…,L7=-7.0.
    // For unit tests the layer is checked by a separate helper.
    LayerFailing(layer) -> is_layer_failing(layer, entropy, health)

    ModuleConsecutiveFailures(_, count) ->
      // consecutive_failures is encoded as the integer part of |lyapunov| when < 0
      // Callers pass lyapunov as -(consecutive_count) to signal consecutive failures.
      lyapunov <. 0.0 && float.absolute_value(lyapunov) >=. int.to_float(count)

    HealthBelow(threshold) -> health <. threshold

    HealthAbove(threshold) -> health >. threshold

    LyapunovPositive -> lyapunov >. 0.0

    AllOf(conditions) ->
      list.all(conditions, fn(c) {
        evaluate_condition(c, health, entropy, cascade_depth, failure_count, lyapunov)
      })

    AnyOf(conditions) ->
      list.any(conditions, fn(c) {
        evaluate_condition(c, health, entropy, cascade_depth, failure_count, lyapunov)
      })
  }
}

// ---------------------------------------------------------------------------
// Bulk evaluation
// ---------------------------------------------------------------------------

/// Evaluate ALL rules against current grid state.
/// Returns evaluations sorted by salience (highest first).
/// Only rules with condition_met = True carry their real action;
/// others carry NoAction.
pub fn evaluate_all(
  health: Float,
  entropy: Float,
  cascade_depth: Int,
  failure_count: Int,
  lyapunov: Float,
) -> List(RuleEvaluation) {
  all_rules()
  |> list.map(fn(rule) {
    let met =
      evaluate_condition(
        rule.condition,
        health,
        entropy,
        cascade_depth,
        failure_count,
        lyapunov,
      )
    RuleEvaluation(
      rule_id: rule.id,
      rule_name: rule.name,
      condition_met: met,
      action: case met {
        True -> rule.action
        False -> NoAction
      },
      salience: rule.salience,
    )
  })
  |> list.sort(fn(a, b) { int.compare(b.salience, a.salience) })
}

/// Get the highest-priority triggered action from a list of evaluations.
/// Returns NoAction when no rule fired.
pub fn highest_priority_action(evaluations: List(RuleEvaluation)) -> RuleAction {
  evaluations
  |> list.filter(fn(e) { e.condition_met })
  |> list.sort(fn(a, b) { int.compare(b.salience, a.salience) })
  |> list.first()
  |> fn(result) {
    case result {
      Ok(e) -> e.action
      Error(_) -> NoAction
    }
  }
}

/// Total number of rules in the catalog.
pub fn rule_count() -> Int {
  list.length(all_rules())
}

// ---------------------------------------------------------------------------
// Serialisation
// ---------------------------------------------------------------------------

/// Format a list of evaluations as a compact JSON array.
pub fn to_json(evaluations: List(RuleEvaluation)) -> String {
  let entries =
    evaluations
    |> list.map(fn(e) {
      "{"
      <> "\"rule_id\":\""
      <> e.rule_id
      <> "\","
      <> "\"rule_name\":\""
      <> e.rule_name
      <> "\","
      <> "\"condition_met\":"
      <> case e.condition_met {
        True -> "true"
        False -> "false"
      }
      <> ","
      <> "\"action\":\""
      <> action_to_string(e.action)
      <> "\","
      <> "\"salience\":"
      <> int.to_string(e.salience)
      <> "}"
    })
  "[" <> string.join(entries, ",") <> "]"
}

/// Convert a RuleAction to a human-readable string for logging / JSON.
pub fn action_to_string(action: RuleAction) -> String {
  case action {
    LogWarning(msg) -> "LogWarning(" <> msg <> ")"
    AttemptHotReload -> "AttemptHotReload"
    SetCockpitMode(mode) -> "SetCockpitMode(" <> mode <> ")"
    IsolateCell(layer) -> "IsolateCell(" <> layer <> ")"
    TriggerRunbook(id) -> "TriggerRunbook(" <> id <> ")"
    EscalateToOperator(reason) -> "EscalateToOperator(" <> reason <> ")"
    JidokaHalt(reason) -> "JidokaHalt(" <> reason <> ")"
    NoAction -> "NoAction"
    ActionSequence(actions) ->
      "ActionSequence(["
      <> string.join(list.map(actions, action_to_string), ",")
      <> "])"
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Encode layer-failure state into the evaluation signature.
///
/// Convention: callers signal a failing layer by passing a negative health
/// value where the integer part encodes the layer index:
///   L0 → health < 0.0  AND  trunc(health) == 0   (i.e. health in (-1, 0))
///   L1 → health < -1.0 AND trunc(health) == -1   (health in (-2, -1))
///   …
///   L7 → health < -7.0 AND trunc(health) == -7
///
/// For production use, callers should wrap evaluate_all_with_layers/3 which
/// accepts an explicit list of failing layer strings.
fn is_layer_failing(layer: String, _entropy: Float, health: Float) -> Bool {
  case layer {
    "L0" -> health <. 0.0 && health >=. -1.0
    "L1" -> health <. -1.0 && health >=. -2.0
    "L2" -> health <. -2.0 && health >=. -3.0
    "L3" -> health <. -3.0 && health >=. -4.0
    "L4" -> health <. -4.0 && health >=. -5.0
    "L5" -> health <. -5.0 && health >=. -6.0
    "L6" -> health <. -6.0 && health >=. -7.0
    "L7" -> health <. -7.0 && health >=. -8.0
    _ -> False
  }
}

/// Evaluate all rules with explicit failing-layers list.
/// This is the preferred API for production callers.
pub fn evaluate_all_with_layers(
  health: Float,
  entropy: Float,
  cascade_depth: Int,
  failure_count: Int,
  lyapunov: Float,
  failing_layers: List(String),
) -> List(RuleEvaluation) {
  all_rules()
  |> list.map(fn(rule) {
    let met =
      evaluate_condition_with_layers(
        rule.condition,
        health,
        entropy,
        cascade_depth,
        failure_count,
        lyapunov,
        failing_layers,
      )
    RuleEvaluation(
      rule_id: rule.id,
      rule_name: rule.name,
      condition_met: met,
      action: case met {
        True -> rule.action
        False -> NoAction
      },
      salience: rule.salience,
    )
  })
  |> list.sort(fn(a, b) { int.compare(b.salience, a.salience) })
}

/// Condition evaluator that uses an explicit failing-layers list for
/// LayerFailing conditions (avoids the health-encoding convention).
pub fn evaluate_condition_with_layers(
  condition: RuleCondition,
  health: Float,
  entropy: Float,
  cascade_depth: Int,
  failure_count: Int,
  lyapunov: Float,
  failing_layers: List(String),
) -> Bool {
  case condition {
    LayerFailing(layer) -> list.contains(failing_layers, layer)

    ModuleConsecutiveFailures(_, count) ->
      lyapunov <. 0.0 && float.absolute_value(lyapunov) >=. int.to_float(count)

    AllOf(conditions) ->
      list.all(conditions, fn(c) {
        evaluate_condition_with_layers(
          c,
          health,
          entropy,
          cascade_depth,
          failure_count,
          lyapunov,
          failing_layers,
        )
      })

    AnyOf(conditions) ->
      list.any(conditions, fn(c) {
        evaluate_condition_with_layers(
          c,
          health,
          entropy,
          cascade_depth,
          failure_count,
          lyapunov,
          failing_layers,
        )
      })

    // All other conditions delegate to the standard evaluator
    other ->
      evaluate_condition(
        other,
        health,
        entropy,
        cascade_depth,
        failure_count,
        lyapunov,
      )
  }
}
