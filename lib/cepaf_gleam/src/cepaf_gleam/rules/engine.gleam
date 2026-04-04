//// [C3I-SIL6-MSTS] MODULE CONTRACT
//// <c3i-module>
////   <identity>
////     <module>cepaf_gleam/rules/engine</module>
////     <fsharp-lineage>Cepaf.Rules.Engine</fsharp-lineage>
////   </identity>
////   <fractal-topology>
////     <layer>L5_COGNITIVE</layer>
////     <mesh-domain>RETE-UL Rule Engine NIF Bridge</mesh-domain>
////   </fractal-topology>
////   <compliance>
////     <stamp-controls>SC-OODA-003, SC-ALLIUM-001</stamp-controls>
////   </compliance>
//// </c3i-module>
////
//// Gleam bindings to the rust-rule-engine RETE-UL NIF.
//// Evaluates GRL (Grule Rule Language) rules against facts in <1ms.
//// Falls back to pure-Gleam stub if NIF not loaded.
////
//// STAMP: SC-OODA-003 (decide phase), SC-ALLIUM-001

import gleam/list
import gleam/string

// =============================================================================
// Types
// =============================================================================

/// Result of a rule evaluation: decision + reason (auditable).
pub type RuleResult {
  RuleResult(decision: String, reason: String)
}

/// A single fact: key-value pair passed to the rule engine.
pub type Fact {
  Fact(key: String, value: String)
}

// =============================================================================
// NIF FFI Bindings
// =============================================================================

/// Evaluate GRL rules against facts via RETE-UL NIF.
/// Returns {Decision, Reason} tuple.
@external(erlang, "rule_engine_nif", "evaluate")
fn nif_evaluate(
  domain: String,
  rules_grl: String,
  facts: List(#(String, String)),
) -> #(String, String)

/// Count parsed rules (for validation).
@external(erlang, "rule_engine_nif", "parse_rules_count")
fn nif_parse_rules_count(rules_grl: String) -> Int

/// Get engine version string.
@external(erlang, "rule_engine_nif", "engine_version")
fn nif_engine_version() -> String

// =============================================================================
// Public API
// =============================================================================

/// Evaluate rules in a domain against a list of facts.
/// Uses the RETE-UL NIF for <1ms evaluation.
pub fn evaluate(
  domain: String,
  rules_grl: String,
  facts: List(Fact),
) -> RuleResult {
  let fact_tuples = list.map(facts, fn(f) { #(f.key, f.value) })
  let #(decision, reason) = nif_evaluate(domain, rules_grl, fact_tuples)
  RuleResult(decision: decision, reason: reason)
}

/// Validate GRL rules by parsing them. Returns rule count or -1 on error.
pub fn validate_rules(rules_grl: String) -> Int {
  nif_parse_rules_count(rules_grl)
}

/// Get the rule engine version.
pub fn version() -> String {
  nif_engine_version()
}

// =============================================================================
// Pre-built GRL Rule Sets (matching Rust ignition rule_engine.rs)
// =============================================================================

/// OODA Decide rules (7 rules, salience 10-100).
pub fn ooda_rules() -> String {
  "
    rule \"Emergency Stop\" salience 100 {
      when System.MeshRunning == true && System.MissingCriticalNodes == true
      then System.Decision = \"EmergencyStop\"; System.Reason = \"Missing critical nodes while running\";
    }
    rule \"Cascade Apoptosis\" salience 100 {
      when System.MeshRunning == true && System.HighDriftCount == true
      then System.Decision = \"EmergencyStop\"; System.Reason = \"Cascade failure: >5 drifted\";
    }
    rule \"Boot Mesh\" salience 90 {
      when System.MeshRunning == false && System.MissingCriticalNodes == true
      then System.Decision = \"BootMesh\"; System.Reason = \"Initial boot required\";
    }
    rule \"Restart on Drift\" salience 80 {
      when System.DriftDetected == true && System.MissingCriticalNodes == false && System.HighDriftCount == false
      then System.Decision = \"RestartContainer\"; System.Reason = \"Single container drifted\";
    }
    rule \"Health Check\" salience 60 {
      when System.DriftDetected == true && System.MultiDrift == true && System.HighDriftCount == false
      then System.Decision = \"HealthCheck\"; System.Reason = \"Multiple containers degraded\";
    }
    rule \"LLM Escalation\" salience 40 {
      when System.DriftDetected == true && System.MultiDrift == false
      then System.Decision = \"DrainContainer\"; System.Reason = \"Ambiguous drift, escalating to LLM\";
    }
    rule \"No Action\" salience 10 {
      when System.DriftDetected == false && System.MissingCriticalNodes == false
      then System.Decision = \"NoAction\"; System.Reason = \"Mesh aligned with genotype\";
    }
  "
}

/// Preflight gate rules (4 rules).
pub fn preflight_rules() -> String {
  "
    rule \"Block on Infra\" salience 100 {
      when Preflight.InfraHealthy == false
      then Preflight.Decision = \"BlockBoot\"; Preflight.Reason = \"Infrastructure not running\";
    }
    rule \"Block on Quorum\" salience 95 {
      when Preflight.ZenohQuorum == false && Preflight.InfraHealthy == true
      then Preflight.Decision = \"BlockBoot\"; Preflight.Reason = \"Zenoh quorum not achieved\";
    }
    rule \"Warn Substrate\" salience 40 {
      when Preflight.SubstrateClean == false && Preflight.InfraHealthy == true && Preflight.ZenohQuorum == true
      then Preflight.Decision = \"WarnAndProceed\"; Preflight.Reason = \"Substrate contamination\";
    }
    rule \"Pass\" salience 10 {
      when Preflight.InfraHealthy == true && Preflight.ZenohQuorum == true && Preflight.SubstrateClean == true
      then Preflight.Decision = \"Pass\"; Preflight.Reason = \"All checks passed\";
    }
  "
}

/// Cascade containment rules (3 rules).
pub fn cascade_rules() -> String {
  "
    rule \"Apoptosis\" salience 100 {
      when Cascade.HighDepth == true
      then Cascade.Decision = \"Apoptosis\"; Cascade.Reason = \"Cascade depth >= 3\";
    }
    rule \"Isolate\" salience 70 {
      when Cascade.MediumDepth == true && Cascade.P0Affected == true
      then Cascade.Decision = \"IsolateTier\"; Cascade.Reason = \"P0 in cascade\";
    }
    rule \"Monitor\" salience 40 {
      when Cascade.HighDepth == false && Cascade.MediumDepth == false
      then Cascade.Decision = \"Monitor\"; Cascade.Reason = \"Shallow cascade\";
    }
  "
}

// =============================================================================
// Convenience Evaluators
// =============================================================================

/// Evaluate OODA decide phase.
pub fn evaluate_ooda(
  mesh_running: Bool,
  missing_critical: Bool,
  drift_detected: Bool,
  multi_drift: Bool,
  high_drift: Bool,
) -> RuleResult {
  evaluate("System", ooda_rules(), [
    Fact("System.MeshRunning", bool_str(mesh_running)),
    Fact("System.MissingCriticalNodes", bool_str(missing_critical)),
    Fact("System.DriftDetected", bool_str(drift_detected)),
    Fact("System.MultiDrift", bool_str(multi_drift)),
    Fact("System.HighDriftCount", bool_str(high_drift)),
  ])
}

/// Evaluate preflight gate.
pub fn evaluate_preflight(
  infra_healthy: Bool,
  zenoh_quorum: Bool,
  substrate_clean: Bool,
) -> RuleResult {
  evaluate("Preflight", preflight_rules(), [
    Fact("Preflight.InfraHealthy", bool_str(infra_healthy)),
    Fact("Preflight.ZenohQuorum", bool_str(zenoh_quorum)),
    Fact("Preflight.SubstrateClean", bool_str(substrate_clean)),
  ])
}

/// Evaluate cascade containment.
pub fn evaluate_cascade(depth: Int, p0_affected: Bool) -> RuleResult {
  evaluate("Cascade", cascade_rules(), [
    Fact("Cascade.HighDepth", bool_str(depth >= 3)),
    Fact("Cascade.MediumDepth", bool_str(depth >= 2)),
    Fact("Cascade.P0Affected", bool_str(p0_affected)),
  ])
}

// =============================================================================
// Additional Rule Domains (matching Rust ignition 13 domains)
// =============================================================================

pub fn recovery_rules() -> String {
  "
    rule \"NIF Recovery\" salience 252 {
      when Recovery.NifFailed == true
      then Recovery.Decision = \"NifCompilation\"; Recovery.Reason = \"RPN 252\";
    }
    rule \"Cascade Recovery\" salience 230 {
      when Recovery.CascadeDetected == true && Recovery.NifFailed == false
      then Recovery.Decision = \"CascadeContainment\"; Recovery.Reason = \"RPN 230\";
    }
    rule \"Glibc Recovery\" salience 225 {
      when Recovery.GlibcConflict == true && Recovery.NifFailed == false && Recovery.CascadeDetected == false
      then Recovery.Decision = \"GlibcMusl\"; Recovery.Reason = \"RPN 225\";
    }
    rule \"No Recovery\" salience 10 {
      when Recovery.NifFailed == false && Recovery.CascadeDetected == false && Recovery.GlibcConflict == false
      then Recovery.Decision = \"NoRecovery\"; Recovery.Reason = \"No failure mode\";
    }
  "
}

pub fn health_rules() -> String {
  "
    rule \"Critical 4/5\" salience 80 {
      when Health.IsCritical == true && Health.HighAgreement == true
      then Health.Decision = \"Reached\"; Health.Reason = \"P0: 4/5 agree\";
    }
    rule \"Standard 3/5\" salience 50 {
      when Health.IsCritical == false && Health.StandardAgreement == true
      then Health.Decision = \"Reached\"; Health.Reason = \"3/5 agree\";
    }
    rule \"Degraded\" salience 30 {
      when Health.StandardAgreement == false && Health.MinimalAgreement == true
      then Health.Decision = \"Degraded\"; Health.Reason = \"2/5 agree\";
    }
    rule \"None\" salience 10 {
      when Health.MinimalAgreement == false
      then Health.Decision = \"NotReached\"; Health.Reason = \"<2/5\";
    }
  "
}

pub fn governor_rules() -> String {
  "
    rule \"Emergency Pause\" salience 100 {
      when Governor.OverLimit == true
      then Governor.Decision = \"Wait\"; Governor.Reason = \"CPU > 85%\";
    }
    rule \"Throttle\" salience 70 {
      when Governor.HighLoad == true && Governor.OverLimit == false
      then Governor.Decision = \"HeavyThrottle\"; Governor.Reason = \"CPU 70-85%\";
    }
    rule \"Full Speed\" salience 10 {
      when Governor.HighLoad == false && Governor.OverLimit == false
      then Governor.Decision = \"FullSpeed\"; Governor.Reason = \"CPU < 70%\";
    }
  "
}

pub fn verify_rules() -> String {
  "
    rule \"NonCompliant\" salience 100 {
      when Verify.CriticalFailed == true
      then Verify.Decision = \"NonCompliant\"; Verify.Reason = \"Critical failed\";
    }
    rule \"Degraded\" salience 50 {
      when Verify.CriticalFailed == false && Verify.AllPassed == false
      then Verify.Decision = \"DegradedButOperational\"; Verify.Reason = \"Non-critical failed\";
    }
    rule \"Compliant\" salience 10 {
      when Verify.AllPassed == true
      then Verify.Decision = \"Compliant\"; Verify.Reason = \"All passed\";
    }
  "
}

pub fn launch_rules() -> String {
  "
    rule \"Halt\" salience 100 {
      when Launch.TierFailed == true && Launch.CriticalFailure == true
      then Launch.Decision = \"HaltPipeline\"; Launch.Reason = \"P0 failed\";
    }
    rule \"Continue\" salience 50 {
      when Launch.TierFailed == true && Launch.CriticalFailure == false
      then Launch.Decision = \"ContinueWithWarning\"; Launch.Reason = \"Non-critical\";
    }
    rule \"Proceed\" salience 10 {
      when Launch.TierFailed == false
      then Launch.Decision = \"Proceed\"; Launch.Reason = \"Tier healthy\";
    }
  "
}

pub fn rca_rules() -> String {
  "
    rule \"L1 NIF\" salience 80 {
      when RCA.NifPattern == true
      then RCA.Decision = \"L1\"; RCA.Reason = \"NIF/binary mismatch\";
    }
    rule \"L4 Container\" salience 80 {
      when RCA.ContainerPattern == true && RCA.NifPattern == false
      then RCA.Decision = \"L4\"; RCA.Reason = \"Container failure\";
    }
    rule \"L6 Quorum\" salience 80 {
      when RCA.QuorumPattern == true
      then RCA.Decision = \"L6\"; RCA.Reason = \"Quorum loss\";
    }
    rule \"L7 LLM\" salience 10 {
      when RCA.NifPattern == false && RCA.ContainerPattern == false && RCA.QuorumPattern == false
      then RCA.Decision = \"L7_LLM\"; RCA.Reason = \"Unknown, escalate\";
    }
  "
}

// =============================================================================
// Convenience Evaluators (continued)
// =============================================================================

pub fn evaluate_recovery(nif: Bool, cascade: Bool, glibc: Bool) -> RuleResult {
  evaluate("Recovery", recovery_rules(), [
    Fact("Recovery.NifFailed", bool_str(nif)),
    Fact("Recovery.CascadeDetected", bool_str(cascade)),
    Fact("Recovery.GlibcConflict", bool_str(glibc)),
  ])
}

pub fn evaluate_health(is_critical: Bool, agreed: Int) -> RuleResult {
  evaluate("Health", health_rules(), [
    Fact("Health.IsCritical", bool_str(is_critical)),
    Fact("Health.HighAgreement", bool_str(agreed >= 4)),
    Fact("Health.StandardAgreement", bool_str(agreed >= 3)),
    Fact("Health.MinimalAgreement", bool_str(agreed >= 2)),
  ])
}

pub fn evaluate_governor(cpu_pct: Int) -> RuleResult {
  evaluate("Governor", governor_rules(), [
    Fact("Governor.OverLimit", bool_str(cpu_pct > 85)),
    Fact("Governor.HighLoad", bool_str(cpu_pct >= 70)),
  ])
}

pub fn evaluate_verify(all_passed: Bool, critical_failed: Bool) -> RuleResult {
  evaluate("Verify", verify_rules(), [
    Fact("Verify.AllPassed", bool_str(all_passed)),
    Fact("Verify.CriticalFailed", bool_str(critical_failed)),
  ])
}

pub fn evaluate_launch(tier_failed: Bool, critical: Bool) -> RuleResult {
  evaluate("Launch", launch_rules(), [
    Fact("Launch.TierFailed", bool_str(tier_failed)),
    Fact("Launch.CriticalFailure", bool_str(critical)),
  ])
}

pub fn evaluate_rca(error: String) -> RuleResult {
  let nif = string.contains(error, "NIF") || string.contains(error, "glibc")
  let container =
    string.contains(error, "container") || string.contains(error, "podman")
  let quorum =
    string.contains(error, "quorum") || string.contains(error, "split brain")
  evaluate("RCA", rca_rules(), [
    Fact("RCA.NifPattern", bool_str(nif)),
    Fact("RCA.ContainerPattern", bool_str(container)),
    Fact("RCA.QuorumPattern", bool_str(quorum)),
  ])
}

fn bool_str(b: Bool) -> String {
  case b {
    True -> "true"
    False -> "false"
  }
}
