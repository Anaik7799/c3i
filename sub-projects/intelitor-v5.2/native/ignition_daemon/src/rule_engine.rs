use crate::ooda_supervisor::{BootConfig, Decision, Observation, Orientation, SupervisorState};
use log::{debug, error, info};
use rust_rule_engine::{Facts, GRLParser, KnowledgeBase, Rule, RustRuleEngine, Value};
use std::sync::OnceLock;

/// Cached parsed GRL rules — parsed once, reused on every OODA cycle.
/// Eliminates re-parsing overhead for <1ms rule evaluation SLA.
static PARSED_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn get_rules() -> &'static Vec<Rule> {
    PARSED_RULES.get_or_init(|| {
        let rule_script = grl_rule_script();
        GRLParser::parse_rules(&rule_script).expect("GRL rules must parse at startup")
    })
}

/// Complete GRL rule set (7 rules covering critical FMEA failure modes).
/// Salience determines priority: higher = evaluated first.
fn grl_rule_script() -> String {
    r#"
        rule "Emergency Stop on Missing Critical Nodes" salience 100 {
            when
                System.MeshRunning == true && System.MissingCriticalNodes == true
            then
                System.Decision = "EmergencyStop";
                System.DecisionReason = "Missing critical nodes while running";
        }

        rule "Cascade Apoptosis on Mass Drift" salience 100 {
            when
                System.MeshRunning == true && System.HighDriftCount == true
            then
                System.Decision = "EmergencyStop";
                System.DecisionReason = "Cascade failure: >5 containers drifted";
        }

        rule "Boot Mesh on Missing Critical Nodes" salience 90 {
            when
                System.MeshRunning == false && System.MissingCriticalNodes == true
            then
                System.Decision = "BootMesh";
                System.DecisionReason = "Initial boot sequence required";
        }

        rule "Restart on Drift" salience 80 {
            when
                System.DriftDetected == true && System.MissingCriticalNodes == false && System.HighDriftCount == false
            then
                System.Decision = "RestartContainer";
                System.DecisionReason = "Drift detected in single container";
        }

        rule "Health Check on Multi-Drift" salience 60 {
            when
                System.DriftDetected == true && System.MissingCriticalNodes == false && System.MultiDrift == true && System.HighDriftCount == false
            then
                System.Decision = "HealthCheck";
                System.DecisionReason = "Multiple containers degraded, running health sweep";
        }

        rule "LLM Escalation on Ambiguous Drift" salience 40 {
            when
                System.DriftDetected == true && System.MissingCriticalNodes == false && System.MultiDrift == false
            then
                System.Decision = "DrainContainer";
                System.DecisionReason = "Ambiguous single drift, escalating to LLM advisor";
        }

        rule "No Action on Healthy Mesh" salience 10 {
            when
                System.DriftDetected == false && System.MissingCriticalNodes == false
            then
                System.Decision = "NoAction";
                System.DecisionReason = "Mesh is fully aligned with genotype";
        }
    "#.to_string()
}

pub fn evaluate_decision(
    obs: &Observation,
    orient: &Orientation,
    state: &SupervisorState,
) -> Option<Decision> {
    let mut kb = KnowledgeBase::new("OODA_Rules");
    let mut engine = RustRuleEngine::new(kb);

    let rules = get_rules();
    for r in rules {
        if let Err(e) = engine.knowledge_base().add_rule(r.clone()) {
            error!("Failed to add rule: {}", e);
            return None;
        }
    }

    let drift_count = orient.twin_drifts.len();

    let mut facts = Facts::new();
    facts.set("System.MeshRunning", Value::Boolean(state.mesh_running));
    facts.set(
        "System.MissingCriticalNodes",
        Value::Boolean(orient.missing_critical_nodes),
    );
    facts.set(
        "System.DriftDetected",
        Value::Boolean(orient.drift_detected),
    );
    facts.set(
        "System.MultiDrift",
        Value::Boolean(drift_count > 2),
    );
    facts.set(
        "System.HighDriftCount",
        Value::Boolean(drift_count > 5),
    );
    facts.set("System.Decision", Value::String("NoAction".into()));
    facts.set(
        "System.DecisionReason",
        Value::String("Mesh is fully aligned with genotype".into()),
    );

    if let Err(e) = engine.execute(&mut facts) {
        error!("Failed to execute rule engine: {}", e);
        return None;
    }

    let decision_str = match facts.get("System.Decision") {
        Some(Value::String(s)) => s.clone(),
        _ => "NoAction".to_string(),
    };

    let reason_str = match facts.get("System.DecisionReason") {
        Some(Value::String(s)) => s.clone(),
        _ => "Unknown".to_string(),
    };

    match decision_str.as_str() {
        "EmergencyStop" => Some(Decision::EmergencyStop(reason_str)),
        "BootMesh" => Some(Decision::BootMesh(BootConfig::default())),
        "RestartContainer" => {
            if let Some(drift) = orient.twin_drifts.first() {
                Some(Decision::RestartContainer(
                    drift.container_name.clone(),
                    reason_str,
                ))
            } else {
                Some(Decision::NoAction(
                    "Drift detected but no target identified".into(),
                ))
            }
        }
        "HealthCheck" => {
            let targets: Vec<String> = orient.twin_drifts.iter()
                .map(|d| d.container_name.clone())
                .collect();
            Some(Decision::HealthCheck(targets))
        }
        "DrainContainer" => {
            if let Some(drift) = orient.twin_drifts.first() {
                Some(Decision::DrainContainer(drift.container_name.clone()))
            } else {
                Some(Decision::NoAction("No drain target identified".into()))
            }
        }
        "ScaleDown" => Some(Decision::ScaleDown(2)),
        "NoAction" => Some(Decision::NoAction(reason_str)),
        _ => Some(Decision::NoAction(format!(
            "Unhandled rule decision: {}",
            decision_str
        ))),
    }
}

// =============================================================================
// DOMAIN 2: PREFLIGHT GATE
// =============================================================================

static PREFLIGHT_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn preflight_grl() -> &'static Vec<Rule> {
    PREFLIGHT_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Block Boot on Infra Failure" salience 100 {
                when Preflight.InfraHealthy == false
                then Preflight.Decision = "BlockBoot"; Preflight.Reason = "Infrastructure containers not running";
            }
            rule "Block Boot on No Quorum" salience 95 {
                when Preflight.ZenohQuorum == false && Preflight.InfraHealthy == true
                then Preflight.Decision = "BlockBoot"; Preflight.Reason = "Zenoh 2oo3 quorum not achieved";
            }
            rule "Warn on Substrate Contamination" salience 40 {
                when Preflight.SubstrateClean == false && Preflight.InfraHealthy == true && Preflight.ZenohQuorum == true
                then Preflight.Decision = "WarnAndProceed"; Preflight.Reason = "Host _build contamination (Axiom 0.1)";
            }
            rule "Pass Preflight" salience 10 {
                when Preflight.InfraHealthy == true && Preflight.ZenohQuorum == true && Preflight.SubstrateClean == true
                then Preflight.Decision = "Pass"; Preflight.Reason = "All critical checks passed";
            }
        "#).expect("Preflight GRL must parse")
    })
}

#[derive(Debug, Clone)]
pub struct PreflightFacts {
    pub infra_healthy: bool,
    pub zenoh_quorum: bool,
    pub db_ready: bool,
    pub substrate_clean: bool,
    pub image_exists: bool,
}

#[derive(Debug, Clone)]
pub struct RuleResult {
    pub decision: String,
    pub reason: String,
}

pub fn evaluate_preflight(facts: &PreflightFacts) -> RuleResult {
    let result = run_domain("Preflight", preflight_grl(), &[
        ("Preflight.InfraHealthy", Value::Boolean(facts.infra_healthy)),
        ("Preflight.ZenohQuorum", Value::Boolean(facts.zenoh_quorum)),
        ("Preflight.DbReady", Value::Boolean(facts.db_ready)),
        ("Preflight.SubstrateClean", Value::Boolean(facts.substrate_clean)),
        ("Preflight.ImageExists", Value::Boolean(facts.image_exists)),
    ]);
    info!("Preflight rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 5: CASCADE CONTAINMENT
// =============================================================================

static CASCADE_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn cascade_grl() -> &'static Vec<Rule> {
    CASCADE_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Apoptosis on Deep Cascade" salience 100 {
                when Cascade.HighDepth == true
                then Cascade.Decision = "Apoptosis"; Cascade.Reason = "Cascade depth >= 3";
            }
            rule "Isolate on Medium Cascade" salience 70 {
                when Cascade.MediumDepth == true && Cascade.P0Affected == true
                then Cascade.Decision = "IsolateTier"; Cascade.Reason = "P0 containers in cascade";
            }
            rule "Monitor on Shallow Cascade" salience 40 {
                when Cascade.HighDepth == false && Cascade.MediumDepth == false
                then Cascade.Decision = "Monitor"; Cascade.Reason = "Single-tier, watching";
            }
        "#).expect("Cascade GRL must parse")
    })
}

pub fn evaluate_cascade(depth: u8, p0_affected: bool) -> RuleResult {
    let result = run_domain("Cascade", cascade_grl(), &[
        ("Cascade.HighDepth", Value::Boolean(depth >= 3)),
        ("Cascade.MediumDepth", Value::Boolean(depth >= 2)),
        ("Cascade.P0Affected", Value::Boolean(p0_affected)),
    ]);
    info!("Cascade rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 7: LAUNCH TIER GATING
// =============================================================================

static LAUNCH_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn launch_grl() -> &'static Vec<Rule> {
    LAUNCH_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Block on Critical Failure" salience 100 {
                when Launch.TierFailed == true && Launch.CriticalFailure == true
                then Launch.Decision = "HaltPipeline"; Launch.Reason = "P0 container failed in tier";
            }
            rule "Continue on Non-Critical" salience 50 {
                when Launch.TierFailed == true && Launch.CriticalFailure == false
                then Launch.Decision = "ContinueWithWarning"; Launch.Reason = "Non-critical failure, proceeding";
            }
            rule "Proceed" salience 10 {
                when Launch.TierFailed == false
                then Launch.Decision = "Proceed"; Launch.Reason = "Tier healthy";
            }
        "#).expect("Launch GRL must parse")
    })
}

pub fn evaluate_launch_tier(tier_failed: bool, critical_failure: bool) -> RuleResult {
    let result = run_domain("Launch", launch_grl(), &[
        ("Launch.TierFailed", Value::Boolean(tier_failed)),
        ("Launch.CriticalFailure", Value::Boolean(critical_failure)),
    ]);
    info!("Launch rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 9: VERIFY COMPLIANCE
// =============================================================================

static VERIFY_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn verify_grl() -> &'static Vec<Rule> {
    VERIFY_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Non-Compliant" salience 100 {
                when Verify.CriticalFailed == true
                then Verify.Decision = "NonCompliant"; Verify.Reason = "Critical verification check failed";
            }
            rule "Degraded" salience 50 {
                when Verify.CriticalFailed == false && Verify.AllPassed == false
                then Verify.Decision = "DegradedButOperational"; Verify.Reason = "Non-critical checks failed";
            }
            rule "Compliant" salience 10 {
                when Verify.AllPassed == true
                then Verify.Decision = "Compliant"; Verify.Reason = "All checks passed";
            }
        "#).expect("Verify GRL must parse")
    })
}

pub fn evaluate_verify(all_passed: bool, critical_failed: bool) -> RuleResult {
    let result = run_domain("Verify", verify_grl(), &[
        ("Verify.AllPassed", Value::Boolean(all_passed)),
        ("Verify.CriticalFailed", Value::Boolean(critical_failed)),
    ]);
    info!("Verify rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 12: RCA ESCALATION
// =============================================================================

static RCA_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn rca_grl() -> &'static Vec<Rule> {
    RCA_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "L1 NIF Pattern" salience 80 {
                when RCA.NifPattern == true
                then RCA.Decision = "L1"; RCA.Reason = "NIF/binary mismatch detected";
            }
            rule "L4 Container Pattern" salience 80 {
                when RCA.ContainerPattern == true && RCA.NifPattern == false
                then RCA.Decision = "L4"; RCA.Reason = "Container orchestration failure";
            }
            rule "L6 Quorum Pattern" salience 80 {
                when RCA.QuorumPattern == true
                then RCA.Decision = "L6"; RCA.Reason = "Ecosystem quorum loss";
            }
            rule "Unknown to LLM" salience 10 {
                when RCA.NifPattern == false && RCA.ContainerPattern == false && RCA.QuorumPattern == false
                then RCA.Decision = "L7_LLM"; RCA.Reason = "Unknown pattern — escalate to LLM";
            }
        "#).expect("RCA GRL must parse")
    })
}

pub fn evaluate_rca(error: &str) -> RuleResult {
    let nif = error.contains("NIF") || error.contains("glibc") || error.contains("musl");
    let container = error.contains("container") || error.contains("podman");
    let quorum = error.contains("quorum") || error.contains("split brain") || error.contains("partition");

    let result = run_domain("RCA", rca_grl(), &[
        ("RCA.NifPattern", Value::Boolean(nif)),
        ("RCA.ContainerPattern", Value::Boolean(container)),
        ("RCA.QuorumPattern", Value::Boolean(quorum)),
    ]);
    info!("RCA rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// GENERIC DOMAIN RUNNER
// =============================================================================

fn run_domain(domain: &str, rules: &[Rule], fact_list: &[(&str, Value)]) -> RuleResult {
    let kb = KnowledgeBase::new(domain);
    let mut engine = RustRuleEngine::new(kb);

    for r in rules {
        if let Err(e) = engine.knowledge_base().add_rule(r.clone()) {
            error!("[{}] Failed to add rule: {}", domain, e);
            return RuleResult {
                decision: "Error".into(),
                reason: format!("Rule load failed: {}", e),
            };
        }
    }

    let mut facts = Facts::new();
    for (key, value) in fact_list {
        facts.set(key, value.clone());
    }
    facts.set(&format!("{}.Decision", domain), Value::String("NoAction".into()));
    facts.set(&format!("{}.Reason", domain), Value::String("Default".into()));

    if let Err(e) = engine.execute(&mut facts) {
        error!("[{}] Rule execution failed: {}", domain, e);
        return RuleResult {
            decision: "Error".into(),
            reason: format!("Execution failed: {}", e),
        };
    }

    let decision = match facts.get(&format!("{}.Decision", domain)) {
        Some(Value::String(s)) => s.clone(),
        _ => "NoAction".into(),
    };
    let reason = match facts.get(&format!("{}.Reason", domain)) {
        Some(Value::String(s)) => s.clone(),
        _ => "Unknown".into(),
    };

    RuleResult { decision, reason }
}

// =============================================================================
// TESTS
// =============================================================================

// =============================================================================
// DOMAIN 3: RECOVERY PLAYBOOK SELECTION
// =============================================================================

static RECOVERY_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn recovery_grl() -> &'static Vec<Rule> {
    RECOVERY_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "NIF Recovery" salience 252 {
                when Recovery.NifFailed == true
                then Recovery.Decision = "NifCompilation"; Recovery.Reason = "RPN 252 — highest risk";
            }
            rule "Cascade Recovery" salience 230 {
                when Recovery.CascadeDetected == true && Recovery.NifFailed == false
                then Recovery.Decision = "CascadeContainment"; Recovery.Reason = "RPN 230 — multi-tier";
            }
            rule "Glibc Recovery" salience 225 {
                when Recovery.GlibcConflict == true && Recovery.NifFailed == false && Recovery.CascadeDetected == false
                then Recovery.Decision = "GlibcMusl"; Recovery.Reason = "RPN 225 — substrate contamination";
            }
            rule "Memory Leak Recovery" salience 198 {
                when Recovery.MemoryLeak == true && Recovery.NifFailed == false && Recovery.CascadeDetected == false && Recovery.GlibcConflict == false
                then Recovery.Decision = "MemoryLeak"; Recovery.Reason = "RPN 198 — RSS unbounded";
            }
            rule "Health Timeout Recovery" salience 196 {
                when Recovery.HealthTimeout == true && Recovery.NifFailed == false && Recovery.CascadeDetected == false && Recovery.GlibcConflict == false && Recovery.MemoryLeak == false
                then Recovery.Decision = "HealthTimeout"; Recovery.Reason = "RPN 196 — Patient Mode";
            }
            rule "No Recovery Needed" salience 10 {
                when Recovery.NifFailed == false && Recovery.CascadeDetected == false && Recovery.GlibcConflict == false && Recovery.MemoryLeak == false && Recovery.HealthTimeout == false
                then Recovery.Decision = "NoRecovery"; Recovery.Reason = "No failure mode active";
            }
        "#).expect("Recovery GRL must parse")
    })
}

pub fn evaluate_recovery(nif: bool, cascade: bool, glibc: bool, memory: bool, timeout: bool) -> RuleResult {
    let result = run_domain("Recovery", recovery_grl(), &[
        ("Recovery.NifFailed", Value::Boolean(nif)),
        ("Recovery.CascadeDetected", Value::Boolean(cascade)),
        ("Recovery.GlibcConflict", Value::Boolean(glibc)),
        ("Recovery.MemoryLeak", Value::Boolean(memory)),
        ("Recovery.HealthTimeout", Value::Boolean(timeout)),
    ]);
    info!("Recovery rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 4: HEALTH CONSENSUS
// =============================================================================

static HEALTH_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn health_grl() -> &'static Vec<Rule> {
    HEALTH_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Critical Consensus 4/5" salience 80 {
                when Health.IsCritical == true && Health.HighAgreement == true
                then Health.Decision = "Reached"; Health.Reason = "P0 container: 4/5 agreement";
            }
            rule "Standard Consensus 3/5" salience 50 {
                when Health.IsCritical == false && Health.StandardAgreement == true
                then Health.Decision = "Reached"; Health.Reason = "Standard 3/5 threshold met";
            }
            rule "Degraded Consensus" salience 30 {
                when Health.StandardAgreement == false && Health.MinimalAgreement == true
                then Health.Decision = "Degraded"; Health.Reason = "Only 2/5 methods agree";
            }
            rule "No Consensus" salience 10 {
                when Health.MinimalAgreement == false
                then Health.Decision = "NotReached"; Health.Reason = "Fewer than 2/5 agree";
            }
        "#).expect("Health GRL must parse")
    })
}

pub fn evaluate_health_consensus(is_critical: bool, agreed: u8) -> RuleResult {
    let result = run_domain("Health", health_grl(), &[
        ("Health.IsCritical", Value::Boolean(is_critical)),
        ("Health.HighAgreement", Value::Boolean(agreed >= 4)),
        ("Health.StandardAgreement", Value::Boolean(agreed >= 3)),
        ("Health.MinimalAgreement", Value::Boolean(agreed >= 2)),
    ]);
    info!("Health rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 6: PARTITION FENCING
// =============================================================================

static PARTITION_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn partition_grl() -> &'static Vec<Rule> {
    PARTITION_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Preserve Data Partition" salience 90 {
                when Partition.Detected == true && Partition.DbInMinority == true
                then Partition.Decision = "FenceMajority"; Partition.Reason = "DB in minority — preserve data";
            }
            rule "Fence Minority" salience 80 {
                when Partition.Detected == true && Partition.DbInMinority == false
                then Partition.Decision = "FenceMinority"; Partition.Reason = "Standard majority rule";
            }
            rule "No Partition" salience 10 {
                when Partition.Detected == false
                then Partition.Decision = "NoAction"; Partition.Reason = "No partition detected";
            }
        "#).expect("Partition GRL must parse")
    })
}

pub fn evaluate_partition(detected: bool, db_in_minority: bool) -> RuleResult {
    let result = run_domain("Partition", partition_grl(), &[
        ("Partition.Detected", Value::Boolean(detected)),
        ("Partition.DbInMinority", Value::Boolean(db_in_minority)),
    ]);
    info!("Partition rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 8: CPU GOVERNOR
// =============================================================================

static GOVERNOR_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn governor_grl() -> &'static Vec<Rule> {
    GOVERNOR_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Emergency Pause" salience 100 {
                when Governor.OverLimit == true
                then Governor.Decision = "Wait"; Governor.Reason = "CPU > 85% — hard limit";
            }
            rule "Heavy Throttle" salience 70 {
                when Governor.HighLoad == true && Governor.OverLimit == false
                then Governor.Decision = "HeavyThrottle"; Governor.Reason = "CPU 70-85% — reduce parallelism";
            }
            rule "Full Speed" salience 10 {
                when Governor.HighLoad == false && Governor.OverLimit == false
                then Governor.Decision = "FullSpeed"; Governor.Reason = "CPU < 70% — full parallelism";
            }
        "#).expect("Governor GRL must parse")
    })
}

pub fn evaluate_governor(cpu_pct: u8) -> RuleResult {
    let result = run_domain("Governor", governor_grl(), &[
        ("Governor.OverLimit", Value::Boolean(cpu_pct > 85)),
        ("Governor.HighLoad", Value::Boolean(cpu_pct >= 70)),
    ]);
    info!("Governor rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 10: BUILD STALENESS
// =============================================================================

static BUILD_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn build_grl() -> &'static Vec<Rule> {
    BUILD_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Force Rebuild Critical" salience 90 {
                when Build.IsCritical == true && Build.Stale72h == true
                then Build.Decision = "Rebuild"; Build.Reason = "P0 container older than 72h";
            }
            rule "Standard Rebuild" salience 50 {
                when Build.Stale168h == true && Build.IsCritical == false
                then Build.Decision = "Rebuild"; Build.Reason = "Image older than 7 days";
            }
            rule "Skip Fresh" salience 10 {
                when Build.Stale72h == false
                then Build.Decision = "Skip"; Build.Reason = "Image is fresh";
            }
        "#).expect("Build GRL must parse")
    })
}

pub fn evaluate_build(is_critical: bool, age_hours: u64) -> RuleResult {
    let result = run_domain("Build", build_grl(), &[
        ("Build.IsCritical", Value::Boolean(is_critical)),
        ("Build.Stale72h", Value::Boolean(age_hours > 72)),
        ("Build.Stale168h", Value::Boolean(age_hours > 168)),
    ]);
    info!("Build rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 11: APOPTOSIS GRACE PERIOD
// =============================================================================

static APOPTOSIS_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn apoptosis_grl() -> &'static Vec<Rule> {
    APOPTOSIS_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Immediate on Split Brain" salience 100 {
                when Apoptosis.SplitBrain == true
                then Apoptosis.Decision = "Immediate"; Apoptosis.Reason = "No grace for split-brain";
            }
            rule "Fast on Cascade" salience 90 {
                when Apoptosis.Cascade == true && Apoptosis.SplitBrain == false
                then Apoptosis.Decision = "Fast2s"; Apoptosis.Reason = "2s grace for cascade";
            }
            rule "Graceful on Manual" salience 50 {
                when Apoptosis.Manual == true && Apoptosis.SplitBrain == false && Apoptosis.Cascade == false
                then Apoptosis.Decision = "Graceful10s"; Apoptosis.Reason = "10s grace for operator-initiated";
            }
            rule "Default Grace" salience 10 {
                when Apoptosis.SplitBrain == false && Apoptosis.Cascade == false && Apoptosis.Manual == false
                then Apoptosis.Decision = "Default5s"; Apoptosis.Reason = "Standard 5s grace period";
            }
        "#).expect("Apoptosis GRL must parse")
    })
}

pub fn evaluate_apoptosis(split_brain: bool, cascade: bool, manual: bool) -> RuleResult {
    let result = run_domain("Apoptosis", apoptosis_grl(), &[
        ("Apoptosis.SplitBrain", Value::Boolean(split_brain)),
        ("Apoptosis.Cascade", Value::Boolean(cascade)),
        ("Apoptosis.Manual", Value::Boolean(manual)),
    ]);
    info!("Apoptosis rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// DOMAIN 13: HYSTERESIS CONFIG
// =============================================================================

static HYSTERESIS_RULES: OnceLock<Vec<Rule>> = OnceLock::new();

fn hysteresis_grl() -> &'static Vec<Rule> {
    HYSTERESIS_RULES.get_or_init(|| {
        GRLParser::parse_rules(r#"
            rule "Tighten on Cascade" salience 80 {
                when Hysteresis.CascadeActive == true
                then Hysteresis.Decision = "Aggressive"; Hysteresis.Reason = "Auto-tighten during cascade";
            }
            rule "Conservative in Prod" salience 50 {
                when Hysteresis.CascadeActive == false && Hysteresis.IsProd == true
                then Hysteresis.Decision = "Conservative"; Hysteresis.Reason = "Production stability";
            }
            rule "Default" salience 10 {
                when Hysteresis.CascadeActive == false && Hysteresis.IsProd == false
                then Hysteresis.Decision = "Default"; Hysteresis.Reason = "Standard dev config";
            }
        "#).expect("Hysteresis GRL must parse")
    })
}

pub fn evaluate_hysteresis(cascade_active: bool, is_prod: bool) -> RuleResult {
    let result = run_domain("Hysteresis", hysteresis_grl(), &[
        ("Hysteresis.CascadeActive", Value::Boolean(cascade_active)),
        ("Hysteresis.IsProd", Value::Boolean(is_prod)),
    ]);
    info!("Hysteresis rule: {} — {}", result.decision, result.reason);
    result
}

// =============================================================================
// TESTS
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_preflight_pass() {
        let result = evaluate_preflight(&PreflightFacts {
            infra_healthy: true, zenoh_quorum: true, db_ready: true,
            substrate_clean: true, image_exists: true,
        });
        assert_eq!(result.decision, "Pass");
    }

    #[test]
    fn test_preflight_block_on_infra() {
        let result = evaluate_preflight(&PreflightFacts {
            infra_healthy: false, zenoh_quorum: true, db_ready: true,
            substrate_clean: true, image_exists: true,
        });
        assert_eq!(result.decision, "BlockBoot");
    }

    #[test]
    fn test_preflight_block_on_quorum() {
        let result = evaluate_preflight(&PreflightFacts {
            infra_healthy: true, zenoh_quorum: false, db_ready: true,
            substrate_clean: true, image_exists: true,
        });
        assert_eq!(result.decision, "BlockBoot");
    }

    #[test]
    fn test_preflight_warn_on_substrate() {
        let result = evaluate_preflight(&PreflightFacts {
            infra_healthy: true, zenoh_quorum: true, db_ready: true,
            substrate_clean: false, image_exists: true,
        });
        assert_eq!(result.decision, "WarnAndProceed");
    }

    #[test]
    fn test_cascade_apoptosis_deep() {
        let result = evaluate_cascade(3, false);
        assert_eq!(result.decision, "Apoptosis");
    }

    #[test]
    fn test_cascade_isolate_medium() {
        let result = evaluate_cascade(2, true);
        assert_eq!(result.decision, "IsolateTier");
    }

    #[test]
    fn test_cascade_monitor_shallow() {
        let result = evaluate_cascade(1, false);
        assert_eq!(result.decision, "Monitor");
    }

    #[test]
    fn test_launch_halt_critical() {
        let result = evaluate_launch_tier(true, true);
        assert_eq!(result.decision, "HaltPipeline");
    }

    #[test]
    fn test_launch_continue_noncritical() {
        let result = evaluate_launch_tier(true, false);
        assert_eq!(result.decision, "ContinueWithWarning");
    }

    #[test]
    fn test_launch_proceed() {
        let result = evaluate_launch_tier(false, false);
        assert_eq!(result.decision, "Proceed");
    }

    #[test]
    fn test_verify_compliant() {
        let result = evaluate_verify(true, false);
        assert_eq!(result.decision, "Compliant");
    }

    #[test]
    fn test_verify_noncompliant() {
        let result = evaluate_verify(false, true);
        assert_eq!(result.decision, "NonCompliant");
    }

    #[test]
    fn test_verify_degraded() {
        let result = evaluate_verify(false, false);
        assert_eq!(result.decision, "DegradedButOperational");
    }

    #[test]
    fn test_rca_nif_pattern() {
        let result = evaluate_rca("NIF compilation failed with glibc");
        assert_eq!(result.decision, "L1");
    }

    #[test]
    fn test_rca_container_pattern() {
        let result = evaluate_rca("podman container crashed");
        assert_eq!(result.decision, "L4");
    }

    #[test]
    fn test_rca_quorum_pattern() {
        let result = evaluate_rca("split brain detected, quorum lost");
        assert_eq!(result.decision, "L6");
    }

    #[test]
    fn test_rca_unknown_to_llm() {
        let result = evaluate_rca("something completely unknown happened");
        assert_eq!(result.decision, "L7_LLM");
    }

    // Domain 3: Recovery
    #[test]
    fn test_recovery_nif_highest_priority() {
        let result = evaluate_recovery(true, true, true, true, true);
        assert_eq!(result.decision, "NifCompilation"); // salience 252 wins
    }

    #[test]
    fn test_recovery_cascade_second() {
        let result = evaluate_recovery(false, true, true, true, true);
        assert_eq!(result.decision, "CascadeContainment"); // salience 230
    }

    #[test]
    fn test_recovery_glibc_third() {
        let result = evaluate_recovery(false, false, true, false, false);
        assert_eq!(result.decision, "GlibcMusl"); // salience 225
    }

    #[test]
    fn test_recovery_none() {
        let result = evaluate_recovery(false, false, false, false, false);
        assert_eq!(result.decision, "NoRecovery");
    }

    // Domain 4: Health Consensus
    #[test]
    fn test_health_critical_needs_4() {
        let result = evaluate_health_consensus(true, 4);
        assert_eq!(result.decision, "Reached");
    }

    #[test]
    fn test_health_standard_needs_3() {
        let result = evaluate_health_consensus(false, 3);
        assert_eq!(result.decision, "Reached");
    }

    #[test]
    fn test_health_degraded_at_2() {
        let result = evaluate_health_consensus(false, 2);
        assert_eq!(result.decision, "Degraded");
    }

    #[test]
    fn test_health_none_at_1() {
        let result = evaluate_health_consensus(false, 1);
        assert_eq!(result.decision, "NotReached");
    }

    // Domain 6: Partition
    #[test]
    fn test_partition_fence_minority() {
        let result = evaluate_partition(true, false);
        assert_eq!(result.decision, "FenceMinority");
    }

    #[test]
    fn test_partition_preserve_data() {
        let result = evaluate_partition(true, true);
        assert_eq!(result.decision, "FenceMajority");
    }

    #[test]
    fn test_partition_none() {
        let result = evaluate_partition(false, false);
        assert_eq!(result.decision, "NoAction");
    }

    // Domain 8: Governor
    #[test]
    fn test_governor_full_speed() {
        let result = evaluate_governor(50);
        assert_eq!(result.decision, "FullSpeed");
    }

    #[test]
    fn test_governor_throttle() {
        let result = evaluate_governor(75);
        assert_eq!(result.decision, "HeavyThrottle");
    }

    #[test]
    fn test_governor_emergency() {
        let result = evaluate_governor(90);
        assert_eq!(result.decision, "Wait");
    }

    // Domain 10: Build
    #[test]
    fn test_build_skip_fresh() {
        let result = evaluate_build(false, 24);
        assert_eq!(result.decision, "Skip");
    }

    #[test]
    fn test_build_critical_at_72h() {
        let result = evaluate_build(true, 100);
        assert_eq!(result.decision, "Rebuild");
    }

    #[test]
    fn test_build_standard_at_168h() {
        let result = evaluate_build(false, 200);
        assert_eq!(result.decision, "Rebuild");
    }

    // Domain 11: Apoptosis
    #[test]
    fn test_apoptosis_immediate_split_brain() {
        let result = evaluate_apoptosis(true, false, false);
        assert_eq!(result.decision, "Immediate");
    }

    #[test]
    fn test_apoptosis_fast_cascade() {
        let result = evaluate_apoptosis(false, true, false);
        assert_eq!(result.decision, "Fast2s");
    }

    #[test]
    fn test_apoptosis_graceful_manual() {
        let result = evaluate_apoptosis(false, false, true);
        assert_eq!(result.decision, "Graceful10s");
    }

    #[test]
    fn test_apoptosis_default() {
        let result = evaluate_apoptosis(false, false, false);
        assert_eq!(result.decision, "Default5s");
    }

    // Domain 13: Hysteresis
    #[test]
    fn test_hysteresis_tighten_cascade() {
        let result = evaluate_hysteresis(true, true);
        assert_eq!(result.decision, "Aggressive");
    }

    #[test]
    fn test_hysteresis_conservative_prod() {
        let result = evaluate_hysteresis(false, true);
        assert_eq!(result.decision, "Conservative");
    }

    #[test]
    fn test_hysteresis_default_dev() {
        let result = evaluate_hysteresis(false, false);
        assert_eq!(result.decision, "Default");
    }
}
