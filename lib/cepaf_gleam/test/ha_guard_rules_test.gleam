//// Guard Rules Engine Tests — RETE-UL typed rule definitions
//// STAMP: SC-SIL4-001, SC-HA-001, SC-OODA-001, SC-MUDA-001
//// Layer: L5_COGNITIVE
//// नियतं कुरु कर्म त्वं — Perform your prescribed duty (Gita 3.8)

import cepaf_gleam/ha/guard_rules.{
  ActionSequence, AllOf, AnyOf, AttemptHotReload, CascadeDepth, EntropyExceeds,
  EscalateToOperator, FailureCountExceeds, HealthAbove, HealthBelow,
  IsolateCell, JidokaHalt, LogWarning, LyapunovPositive,
  ModuleConsecutiveFailures, NoAction, SetCockpitMode, TriggerRunbook,
  type GuardRule, type RuleEvaluation,
}
import gleam/list
import gleam/string
import gleeunit/should

// ═══════════════════════════════════════════════════════════════
// Rule Catalog
// ═══════════════════════════════════════════════════════════════

pub fn all_rules_returns_fifteen_test() {
  guard_rules.rule_count() |> should.equal(15)
}

pub fn all_rules_have_unique_ids_test() {
  let ids =
    guard_rules.all_rules()
    |> list.map(fn(r: GuardRule) { r.id })
  let unique_count = list.unique(ids) |> list.length()
  unique_count |> should.equal(15)
}

pub fn all_rules_have_non_empty_names_test() {
  guard_rules.all_rules()
  |> list.all(fn(r: GuardRule) { string.length(r.name) > 0 })
  |> should.be_true()
}

pub fn all_rules_have_positive_salience_test() {
  guard_rules.all_rules()
  |> list.all(fn(r: GuardRule) { r.salience > 0 })
  |> should.be_true()
}

pub fn rules_contain_gr001_test() {
  guard_rules.all_rules()
  |> list.any(fn(r: GuardRule) { r.id == "GR-001" })
  |> should.be_true()
}

pub fn rules_contain_gr003_constitutional_threat_test() {
  guard_rules.all_rules()
  |> list.any(fn(r: GuardRule) { r.id == "GR-003" })
  |> should.be_true()
}

// ═══════════════════════════════════════════════════════════════
// evaluate_condition — atomic conditions
// ═══════════════════════════════════════════════════════════════

pub fn failure_count_exceeds_fires_at_threshold_test() {
  guard_rules.evaluate_condition(
    FailureCountExceeds(threshold: 5),
    1.0, 0.0, 0, 5, 0.0,
  )
  |> should.be_true()
}

pub fn failure_count_exceeds_does_not_fire_below_threshold_test() {
  guard_rules.evaluate_condition(
    FailureCountExceeds(threshold: 5),
    1.0, 0.0, 0, 4, 0.0,
  )
  |> should.be_false()
}

pub fn cascade_depth_fires_at_min_depth_test() {
  guard_rules.evaluate_condition(
    CascadeDepth(min_depth: 3),
    1.0, 0.0, 3, 0, 0.0,
  )
  |> should.be_true()
}

pub fn cascade_depth_does_not_fire_below_min_depth_test() {
  guard_rules.evaluate_condition(
    CascadeDepth(min_depth: 3),
    1.0, 0.0, 2, 0, 0.0,
  )
  |> should.be_false()
}

pub fn entropy_exceeds_fires_above_threshold_test() {
  guard_rules.evaluate_condition(
    EntropyExceeds(threshold: 1.5),
    1.0, 2.0, 0, 0, 0.0,
  )
  |> should.be_true()
}

pub fn entropy_exceeds_does_not_fire_at_equal_test() {
  guard_rules.evaluate_condition(
    EntropyExceeds(threshold: 1.5),
    1.0, 1.5, 0, 0, 0.0,
  )
  |> should.be_false()
}

pub fn entropy_exceeds_does_not_fire_below_threshold_test() {
  guard_rules.evaluate_condition(
    EntropyExceeds(threshold: 1.5),
    1.0, 1.0, 0, 0, 0.0,
  )
  |> should.be_false()
}

pub fn health_below_fires_when_health_is_low_test() {
  guard_rules.evaluate_condition(
    HealthBelow(threshold: 0.5),
    0.3, 0.0, 0, 0, 0.0,
  )
  |> should.be_true()
}

pub fn health_below_does_not_fire_above_threshold_test() {
  guard_rules.evaluate_condition(
    HealthBelow(threshold: 0.5),
    0.8, 0.0, 0, 0, 0.0,
  )
  |> should.be_false()
}

pub fn health_above_fires_when_health_is_high_test() {
  guard_rules.evaluate_condition(
    HealthAbove(threshold: 0.9),
    0.95, 0.0, 0, 0, 0.0,
  )
  |> should.be_true()
}

pub fn health_above_does_not_fire_at_threshold_test() {
  guard_rules.evaluate_condition(
    HealthAbove(threshold: 0.9),
    0.9, 0.0, 0, 0, 0.0,
  )
  |> should.be_false()
}

pub fn lyapunov_positive_fires_when_positive_test() {
  guard_rules.evaluate_condition(
    LyapunovPositive,
    1.0, 0.0, 0, 0, 0.1,
  )
  |> should.be_true()
}

pub fn lyapunov_positive_does_not_fire_when_negative_test() {
  guard_rules.evaluate_condition(
    LyapunovPositive,
    1.0, 0.0, 0, 0, -0.1,
  )
  |> should.be_false()
}

pub fn lyapunov_positive_does_not_fire_at_zero_test() {
  guard_rules.evaluate_condition(
    LyapunovPositive,
    1.0, 0.0, 0, 0, 0.0,
  )
  |> should.be_false()
}

pub fn module_consecutive_failures_fires_at_count_test() {
  // lyapunov = -3.0 signals 3 consecutive failures
  guard_rules.evaluate_condition(
    ModuleConsecutiveFailures(module: "nif_bridge", count: 3),
    1.0, 0.0, 0, 0, -3.0,
  )
  |> should.be_true()
}

pub fn module_consecutive_failures_does_not_fire_below_count_test() {
  guard_rules.evaluate_condition(
    ModuleConsecutiveFailures(module: "nif_bridge", count: 3),
    1.0, 0.0, 0, 0, -2.0,
  )
  |> should.be_false()
}

pub fn module_consecutive_failures_does_not_fire_when_positive_lyapunov_test() {
  guard_rules.evaluate_condition(
    ModuleConsecutiveFailures(module: "nif_bridge", count: 1),
    1.0, 0.0, 0, 0, 1.0,
  )
  |> should.be_false()
}

// ═══════════════════════════════════════════════════════════════
// AllOf / AnyOf combinators
// ═══════════════════════════════════════════════════════════════

pub fn all_of_true_when_all_conditions_true_test() {
  guard_rules.evaluate_condition(
    AllOf(conditions: [
      HealthBelow(threshold: 0.5),
      CascadeDepth(min_depth: 2),
    ]),
    0.3, 0.0, 3, 0, 0.0,
  )
  |> should.be_true()
}

pub fn all_of_false_when_one_condition_false_test() {
  guard_rules.evaluate_condition(
    AllOf(conditions: [
      HealthBelow(threshold: 0.5),
      CascadeDepth(min_depth: 2),
    ]),
    0.3, 0.0, 1, 0, 0.0,
  )
  |> should.be_false()
}

pub fn any_of_true_when_one_condition_true_test() {
  guard_rules.evaluate_condition(
    AnyOf(conditions: [
      HealthBelow(threshold: 0.5),
      CascadeDepth(min_depth: 5),
    ]),
    0.3, 0.0, 2, 0, 0.0,
  )
  |> should.be_true()
}

pub fn any_of_false_when_all_conditions_false_test() {
  guard_rules.evaluate_condition(
    AnyOf(conditions: [
      HealthBelow(threshold: 0.5),
      CascadeDepth(min_depth: 5),
    ]),
    0.8, 0.0, 2, 0, 0.0,
  )
  |> should.be_false()
}

pub fn nested_all_of_any_of_evaluates_correctly_test() {
  // (health < 0.5) AND (cascade >= 2 OR failure_count >= 3)
  let condition =
    AllOf(conditions: [
      HealthBelow(threshold: 0.5),
      AnyOf(conditions: [
        CascadeDepth(min_depth: 2),
        FailureCountExceeds(threshold: 3),
      ]),
    ])
  // health=0.3 (<0.5), cascade=1 (<2), failures=4 (>=3) → True
  guard_rules.evaluate_condition(condition, 0.3, 0.0, 1, 4, 0.0)
  |> should.be_true()
}

pub fn all_of_with_empty_list_is_vacuously_true_test() {
  guard_rules.evaluate_condition(AllOf(conditions: []), 0.5, 0.0, 0, 0, 0.0)
  |> should.be_true()
}

pub fn any_of_with_empty_list_is_false_test() {
  guard_rules.evaluate_condition(AnyOf(conditions: []), 0.5, 0.0, 0, 0, 0.0)
  |> should.be_false()
}

// ═══════════════════════════════════════════════════════════════
// evaluate_all — bulk evaluation with salience ordering
// ═══════════════════════════════════════════════════════════════

pub fn evaluate_all_returns_fifteen_evaluations_test() {
  let evals =
    guard_rules.evaluate_all(0.8, 0.5, 0, 0, 0.0)
  list.length(evals) |> should.equal(15)
}

pub fn evaluate_all_sorted_by_salience_descending_test() {
  let evals = guard_rules.evaluate_all(0.8, 0.5, 0, 0, 0.0)
  let saliences = list.map(evals, fn(e: RuleEvaluation) { e.salience })
  // Verify each element is >= the next (non-increasing order)
  let pairs = list.zip(saliences, list.drop(saliences, 1))
  list.all(pairs, fn(p) { p.0 >= p.1 })
  |> should.be_true()
}

pub fn evaluate_all_healthy_system_no_critical_rules_fired_test() {
  // Perfect health, low entropy, no cascade, positive lyapunov not set
  let evals = guard_rules.evaluate_all(0.98, 0.1, 0, 0, -0.1)
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  // Only GR-014 (NormalMode) and GR-015 (AllClear) should fire
  list.any(fired, fn(e: RuleEvaluation) { e.rule_id == "GR-014" })
  |> should.be_true()
}

pub fn evaluate_all_critical_failure_fires_jidoka_halt_test() {
  // health=0.1, cascade=4 → GR-001 CascadeEscalation should fire
  let evals = guard_rules.evaluate_all(0.1, 2.0, 4, 8, 0.0)
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  list.any(fired, fn(e: RuleEvaluation) { e.rule_id == "GR-001" })
  |> should.be_true()
}

pub fn evaluate_all_unfired_rules_carry_no_action_test() {
  // Perfect health — no alerts should fire
  let evals = guard_rules.evaluate_all(0.98, 0.1, 0, 0, 0.0)
  let unfired = list.filter(evals, fn(e: RuleEvaluation) { !e.condition_met })
  list.all(unfired, fn(e: RuleEvaluation) { e.action == NoAction })
  |> should.be_true()
}

// ═══════════════════════════════════════════════════════════════
// highest_priority_action
// ═══════════════════════════════════════════════════════════════

pub fn highest_priority_action_returns_no_action_when_none_fired_test() {
  let evals = guard_rules.evaluate_all(0.98, 0.1, 0, 0, 0.0)
  // Only NormalMode and AllClear fire; AllClear = NoAction, NormalMode = SetCockpitMode("dark")
  let action = guard_rules.highest_priority_action(evals)
  // NormalMode (salience 40) fires → SetCockpitMode("dark")
  action |> should.equal(SetCockpitMode("dark"))
}

pub fn highest_priority_action_returns_jidoka_halt_on_cascade_test() {
  let evals = guard_rules.evaluate_all(0.1, 2.0, 4, 8, 0.0)
  let action = guard_rules.highest_priority_action(evals)
  // GR-001 (salience 100) fires JidokaHalt
  case action {
    JidokaHalt(_) -> should.be_true(True)
    _ -> should.be_true(False)
  }
}

pub fn highest_priority_action_emergency_mode_on_low_health_test() {
  // health=0.2, no cascade, no layer-specific failure
  let evals = guard_rules.evaluate_all(0.2, 0.5, 0, 2, 0.0)
  let action = guard_rules.highest_priority_action(evals)
  // GR-002 EmergencyMode (salience 95) should fire — health < 0.3
  action |> should.equal(SetCockpitMode("emergency"))
}

pub fn highest_priority_action_returns_no_action_empty_list_test() {
  guard_rules.highest_priority_action([])
  |> should.equal(NoAction)
}

// ═══════════════════════════════════════════════════════════════
// evaluate_all_with_layers — explicit layer failure API
// ═══════════════════════════════════════════════════════════════

pub fn evaluate_all_with_layers_l0_failing_fires_constitutional_threat_test() {
  let evals =
    guard_rules.evaluate_all_with_layers(0.8, 0.5, 0, 0, 0.0, ["L0"])
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  list.any(fired, fn(e: RuleEvaluation) { e.rule_id == "GR-003" })
  |> should.be_true()
}

pub fn evaluate_all_with_layers_l6_failing_fires_quorum_threat_test() {
  let evals =
    guard_rules.evaluate_all_with_layers(0.8, 0.5, 0, 0, 0.0, ["L6"])
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  list.any(fired, fn(e: RuleEvaluation) { e.rule_id == "GR-004" })
  |> should.be_true()
}

pub fn evaluate_all_with_layers_l1_failing_fires_runbook_nif_test() {
  let evals =
    guard_rules.evaluate_all_with_layers(0.8, 0.5, 0, 0, 0.0, ["L1"])
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  list.any(fired, fn(e: RuleEvaluation) { e.rule_id == "GR-009" })
  |> should.be_true()
}

pub fn evaluate_all_with_layers_no_failures_does_not_fire_layer_rules_test() {
  let evals =
    guard_rules.evaluate_all_with_layers(0.95, 0.2, 0, 0, -0.1, [])
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  // Layer-specific rules should NOT fire when no layers are failing
  list.any(fired, fn(e: RuleEvaluation) {
    e.rule_id == "GR-003"
    || e.rule_id == "GR-004"
    || e.rule_id == "GR-009"
  })
  |> should.be_false()
}

// ═══════════════════════════════════════════════════════════════
// to_json — serialisation
// ═══════════════════════════════════════════════════════════════

pub fn to_json_produces_valid_array_test() {
  let evals = guard_rules.evaluate_all(0.8, 0.5, 0, 0, 0.0)
  let json = guard_rules.to_json(evals)
  string.starts_with(json, "[") |> should.be_true()
  string.ends_with(json, "]") |> should.be_true()
}

pub fn to_json_contains_rule_id_field_test() {
  let evals = guard_rules.evaluate_all(0.8, 0.5, 0, 0, 0.0)
  let json = guard_rules.to_json(evals)
  string.contains(json, "rule_id") |> should.be_true()
}

pub fn to_json_contains_salience_field_test() {
  let evals = guard_rules.evaluate_all(0.8, 0.5, 0, 0, 0.0)
  let json = guard_rules.to_json(evals)
  string.contains(json, "salience") |> should.be_true()
}

// ═══════════════════════════════════════════════════════════════
// action_to_string — logging
// ═══════════════════════════════════════════════════════════════

pub fn action_to_string_no_action_test() {
  guard_rules.action_to_string(NoAction) |> should.equal("NoAction")
}

pub fn action_to_string_jidoka_halt_test() {
  let s = guard_rules.action_to_string(JidokaHalt("critical"))
  string.starts_with(s, "JidokaHalt(") |> should.be_true()
}

pub fn action_to_string_set_cockpit_mode_test() {
  guard_rules.action_to_string(SetCockpitMode("emergency"))
  |> should.equal("SetCockpitMode(emergency)")
}

pub fn action_to_string_attempt_hot_reload_test() {
  guard_rules.action_to_string(AttemptHotReload)
  |> should.equal("AttemptHotReload")
}

pub fn action_to_string_trigger_runbook_test() {
  guard_rules.action_to_string(TriggerRunbook("RB-001"))
  |> should.equal("TriggerRunbook(RB-001)")
}

pub fn action_to_string_log_warning_test() {
  let s = guard_rules.action_to_string(LogWarning("system degraded"))
  string.starts_with(s, "LogWarning(") |> should.be_true()
}

pub fn action_to_string_escalate_to_operator_test() {
  let s = guard_rules.action_to_string(EscalateToOperator("quorum loss"))
  string.starts_with(s, "EscalateToOperator(") |> should.be_true()
}

pub fn action_to_string_isolate_cell_test() {
  guard_rules.action_to_string(IsolateCell("L4"))
  |> should.equal("IsolateCell(L4)")
}

pub fn action_to_string_action_sequence_test() {
  let s =
    guard_rules.action_to_string(
      ActionSequence(actions: [SetCockpitMode("bright"), LogWarning("warn")]),
    )
  string.starts_with(s, "ActionSequence([") |> should.be_true()
}

// ═══════════════════════════════════════════════════════════════
// Edge cases
// ═══════════════════════════════════════════════════════════════

pub fn evaluate_condition_with_layers_health_below_uses_standard_evaluator_test() {
  // Non-layer condition delegates to standard evaluator
  guard_rules.evaluate_condition_with_layers(
    HealthBelow(threshold: 0.5),
    0.3, 0.0, 0, 0, 0.0, [],
  )
  |> should.be_true()
}

pub fn evaluate_condition_cascade_depth_zero_does_not_fire_test() {
  guard_rules.evaluate_condition(
    CascadeDepth(min_depth: 1),
    1.0, 0.0, 0, 0, 0.0,
  )
  |> should.be_false()
}

pub fn evaluate_all_with_multiple_layer_failures_fires_multiple_rules_test() {
  let evals =
    guard_rules.evaluate_all_with_layers(0.4, 0.5, 1, 3, 0.0, ["L1", "L4", "L5"])
  let fired = list.filter(evals, fn(e: RuleEvaluation) { e.condition_met })
  { list.length(fired) > 2 } |> should.be_true()
}
