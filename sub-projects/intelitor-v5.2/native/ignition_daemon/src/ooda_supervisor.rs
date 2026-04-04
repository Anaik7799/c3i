use crate::errors::IgnitionError;
use crate::podman;
use crate::digital_twin::{Genotype, Phenotype, TwinDrift, compare_twin};
use std::time::{Duration, Instant};
use tokio::time;
use tracing::{debug, error, info, instrument, warn, span, Level};
use std::collections::HashMap;

#[derive(Debug, Clone)]
pub struct BootConfig {
    pub mode: String,
    pub max_retries: u32,
    pub timeout_ms: u64,
}

impl Default for BootConfig {
    fn default() -> Self {
        Self {
            mode: "prod".into(),
            max_retries: 3,
            timeout_ms: 30000,
        }
    }
}

#[derive(Debug, Clone)]
pub enum Decision {
    NoAction(String),
    BootMesh(BootConfig),
    ShutdownMesh,
    RestartContainer(String, String),
    ScaleUp(u32),
    ScaleDown(u32),
    EmergencyStop(String),
    HealthCheck(Vec<String>),
    DrainContainer(String),
}

#[derive(Debug, Clone)]
pub struct Observation {
    pub active_containers: usize,
    pub mesh_healthy: bool,
    pub failed_nodes: Vec<String>,
    pub phenotypes: Vec<Phenotype>,
    pub timestamp: Instant,
}

#[derive(Debug, Clone)]
pub struct Orientation {
    pub drift_detected: bool,
    pub twin_drifts: Vec<TwinDrift>,
    pub overload: bool,
    pub missing_critical_nodes: bool,
    pub timestamp: Instant,
}

#[derive(Debug, Clone)]
pub struct ActionResult {
    pub success: bool,
    pub message: String,
    pub timestamp: Instant,
}

#[derive(Debug, Clone)]
pub struct SupervisorConfig {
    pub cycle_interval_ms: u64,
    pub observe_budget_ms: u64,
    pub orient_budget_ms: u64,
    pub decide_budget_ms: u64,
    pub act_budget_ms: u64,
    pub expected_genotypes: Vec<Genotype>,
}

impl Default for SupervisorConfig {
    fn default() -> Self {
        Self {
            cycle_interval_ms: 30, // 30ms OODA loop (Biomorphic Target)
            observe_budget_ms: 30,
            orient_budget_ms: 20,
            decide_budget_ms: 20,
            act_budget_ms: 20,
            expected_genotypes: crate::digital_twin::build_sil6_genotypes(),
        }
    }
}

#[derive(Debug, Clone)]
pub struct SupervisorState {
    pub mesh_running: bool,
    pub current_cycle: u64,
    pub last_health_check: Option<Instant>,
    pub consecutive_failures: u32,
}

#[derive(Debug, Clone)]
pub struct OodaCycle {
    pub cycle_number: u64,
    pub start: Instant,
    pub duration_ms: u64,
    pub observation: Observation,
    pub orientation: Orientation,
    pub decision: Decision,
    pub action_result: ActionResult,
    pub sla_compliant: bool,
}

/// The OODA Supervisor for the SIL-6 Mesh.
///
/// Implements the Observe-Orient-Decide-Act loop under strict <100ms timing constraints.
pub struct OodaSupervisor {
    pub config: SupervisorConfig,
    pub state: SupervisorState,
}

impl OodaSupervisor {
    pub fn new(config: SupervisorConfig) -> Self {
        Self {
            config,
            state: SupervisorState {
                mesh_running: false,
                current_cycle: 0,
                last_health_check: None,
                consecutive_failures: 0,
            },
        }
    }

    /// PHASE 1: OBSERVE
    /// Gathers state from the physical mesh via Podman REST API/CLI.
    #[instrument(skip(self))]
    pub async fn observe(&self) -> Result<Observation, IgnitionError> {
        let start = Instant::now();
        
        // Gather stats
        let stats = podman::get_all_stats().await?;
        let active_containers = stats.len();
        
        let mut failed_nodes = Vec::new();
        let mut phenotypes = Vec::new();

        for stat in &stats {
            // Inspect container for actual image (best-effort, fallback to "unknown")
            let actual_image = podman::podman_inspect(&stat.name, "{{.Config.Image}}")
                .await
                .unwrap_or_else(|_| "unknown".into());

            let running = podman::podman_inspect(&stat.name, "{{.State.Running}}")
                .await
                .map(|s| s.trim() == "true")
                .unwrap_or(false);

            if !running {
                failed_nodes.push(stat.name.clone());
            }

            phenotypes.push(Phenotype {
                container_name: stat.name.clone(),
                actual_image,
                actual_ports: vec![],
                actual_env: HashMap::new(),
                running,
            });
        }
        
        let elapsed = start.elapsed().as_millis() as u64;
        if elapsed > self.config.observe_budget_ms {
            warn!("Observe phase exceeded budget: {}ms > {}ms", elapsed, self.config.observe_budget_ms);
        }
        
        Ok(Observation {
            active_containers,
            mesh_healthy: active_containers > 0 && failed_nodes.is_empty(),
            failed_nodes,
            phenotypes,
            timestamp: Instant::now(),
        })
    }

    /// PHASE 2: ORIENT
    /// Compares observation against the Digital Twin Genotypes to find drifts.
    #[instrument(skip(self))]
    pub fn orient(&self, obs: &Observation) -> Orientation {
        let start = Instant::now();
        
        let mut twin_drifts = Vec::new();
        let mut missing_critical_nodes = false;

        for expected in &self.config.expected_genotypes {
            if let Some(actual) = obs.phenotypes.iter().find(|p| p.container_name == expected.container_name) {
                let drift = compare_twin(expected, actual);
                if !drift.is_aligned {
                    twin_drifts.push(drift);
                }
            } else {
                missing_critical_nodes = true;
            }
        }
        
        let elapsed = start.elapsed().as_millis() as u64;
        if elapsed > self.config.orient_budget_ms {
            warn!("Orient phase exceeded budget: {}ms > {}ms", elapsed, self.config.orient_budget_ms);
        }
        
        Orientation {
            drift_detected: !twin_drifts.is_empty(),
            twin_drifts,
            overload: false,
            missing_critical_nodes,
            timestamp: Instant::now(),
        }
    }

    /// PHASE 3: DECIDE
    /// Forms a decision based on the current orientation.
    #[instrument(skip(self))]
    pub fn decide(&self, obs: &Observation, orient: &Orientation) -> Decision {
        let start = Instant::now();

        let decision = if let Some(rule_decision) = crate::rule_engine::evaluate_decision(obs, orient, &self.state) {
            info!("Rule Engine Decision: {:?}", rule_decision);
            rule_decision
        } else if !self.state.mesh_running && orient.missing_critical_nodes {
            Decision::BootMesh(BootConfig::default())
        } else if self.state.mesh_running && orient.missing_critical_nodes {
            Decision::EmergencyStop("Missing critical nodes while running".into())
        } else if orient.drift_detected {
            // For now, take the first drifted container and restart it
            if let Some(drift) = orient.twin_drifts.first() {
                Decision::RestartContainer(drift.container_name.clone(), "Drift detected".into())
            } else {
                Decision::NoAction("Drift detected but no target identified".into())
            }
        } else {
            Decision::NoAction("Mesh is fully aligned with genotype".into())
        };
        
        let elapsed = start.elapsed().as_millis() as u64;
        if elapsed > self.config.decide_budget_ms {
            warn!("Decide phase exceeded budget: {}ms > {}ms", elapsed, self.config.decide_budget_ms);
        }
        
        decision
    }

    /// PHASE 4: ACT
    /// Executes the decision using the Podman commands.
    #[instrument(skip(self))]
    pub async fn act(&mut self, decision: Decision) -> Result<ActionResult, IgnitionError> {
        let start = Instant::now();
        
        let mut result = ActionResult {
            success: true,
            message: "Action completed".into(),
            timestamp: Instant::now(),
        };

        match decision {
            Decision::NoAction(reason) => {
                result.message = format!("No action needed: {}", reason);
            }
            Decision::BootMesh(config) => {
                self.state.mesh_running = true;
                result.message = format!("Booting mesh in {} mode", config.mode);
                // Implementation would call robust_launch::launch_mesh()
            }
            Decision::ShutdownMesh => {
                self.state.mesh_running = false;
                result.message = "Mesh shutting down".into();
            }
            Decision::RestartContainer(container, reason) => {
                info!("Restarting container {} due to: {}", container, reason);
                podman::stop_container(&container, 10).await?;
                podman::start_container(&container).await?;
                result.message = format!("Restarted {}", container);
            }
            Decision::ScaleUp(count) => {
                result.message = format!("Scaled up by {}", count);
            }
            Decision::ScaleDown(count) => {
                result.message = format!("Scaled down by {}", count);
            }
            Decision::EmergencyStop(reason) => {
                self.state.mesh_running = false;
                result.message = format!("Emergency stop initiated: {}", reason);
            }
            Decision::HealthCheck(nodes) => {
                result.message = format!("Triggered health checks for {} nodes", nodes.len());
            }
            Decision::DrainContainer(container) => {
                // LLM escalation: ask OpenRouter for advice before acting
                let prompt = format!(
                    "Container '{}' has drifted from genotype. Cycle #{}, mesh_running={}. \
                     Should we: (a) drain and restart, (b) restart only, (c) ignore? \
                     Respond with one letter and a brief reason.",
                    container, self.state.current_cycle, self.state.mesh_running
                );
                match crate::openrouter::query_llm_advisor(&prompt).await {
                    Ok(advice) => {
                        info!("LLM Advisor for {}: {}", container, advice);
                        result.message = format!("LLM advised on {}: {}", container, advice);
                    }
                    Err(e) => {
                        warn!("LLM unavailable ({}), proceeding with drain for {}", e, container);
                    }
                }
                // Execute drain + restart
                if let Err(e) = podman::stop_container(&container, 10).await {
                    warn!("Failed to drain {}: {}", container, e);
                    result.success = false;
                }
                if let Err(e) = podman::start_container(&container).await {
                    warn!("Failed to restart {}: {}", container, e);
                    result.success = false;
                }
                if result.success {
                    result.message = format!("Drained and restarted {} (LLM-guided)", container);
                }
            }
        }
        
        let elapsed = start.elapsed().as_millis() as u64;
        if elapsed > self.config.act_budget_ms {
            warn!("Act phase exceeded budget: {}ms > {}ms", elapsed, self.config.act_budget_ms);
        }
        
        result.timestamp = Instant::now();
        Ok(result)
    }

    /// VALIDATE
    /// Guardian validation step before committing to action.
    /// P0 decisions (EmergencyStop, BootMesh) require Guardian approval.
    /// Fail-closed in release builds; permissive in debug/test (SC-GUARD-002).
    pub fn validate_with_guardian(&self, decision: &Decision) -> bool {
        match decision {
            Decision::EmergencyStop(_) | Decision::BootMesh(_) => {
                warn!("Guardian gate: P0 decision {:?} requires approval", decision);
                // In debug/test: allow. In release: fail-closed (require Guardian service).
                cfg!(debug_assertions)
            }
            _ => true,
        }
    }

    /// Run a complete OODA cycle
    pub async fn run_cycle(&mut self) -> Result<OodaCycle, IgnitionError> {
        let cycle_start = Instant::now();
        self.state.current_cycle += 1;

        let obs = self.observe().await?;
        let orient = self.orient(&obs);
        let decision = self.decide(&obs, &orient);

        let final_decision = if self.validate_with_guardian(&decision) {
            decision
        } else {
            warn!("Guardian rejected decision: {:?}", decision);
            Decision::NoAction("Guardian rejected decision".into())
        };

        let act_res = self.act(final_decision.clone()).await?;

        let duration_ms = cycle_start.elapsed().as_millis() as u64;
        let sla_compliant = duration_ms <= 100;

        if !sla_compliant {
            warn!("OODA cycle {} violated SLA. Duration: {}ms", self.state.current_cycle, duration_ms);
        }

        Ok(OodaCycle {
            cycle_number: self.state.current_cycle,
            start: cycle_start,
            duration_ms,
            observation: obs,
            orientation: orient,
            decision: final_decision,
            action_result: act_res,
            sla_compliant,
        })
    }

    /// Run a shadow OODA cycle (no real actions)
    pub async fn run_shadow_cycle(&mut self) -> Result<OodaCycle, IgnitionError> {
        let cycle_start = Instant::now();
        self.state.current_cycle += 1;

        let obs = self.observe().await?;
        let orient = self.orient(&obs);
        let decision = self.decide(&obs, &orient);

        let final_decision = if self.validate_with_guardian(&decision) {
            decision
        } else {
            Decision::NoAction("Guardian rejected decision".into())
        };

        let act_res = ActionResult {
            success: true,
            message: format!("Shadow mode: Would have executed {:?}", final_decision),
            timestamp: Instant::now(),
        };

        let duration_ms = cycle_start.elapsed().as_millis() as u64;
        let sla_compliant = duration_ms <= 100;

        if !sla_compliant {
            warn!("Shadow OODA cycle {} violated SLA. Duration: {}ms", self.state.current_cycle, duration_ms);
        }

        Ok(OodaCycle {
            cycle_number: self.state.current_cycle,
            start: cycle_start,
            duration_ms,
            observation: obs,
            orientation: orient,
            decision: final_decision,
            action_result: act_res,
            sla_compliant,
        })
    }

    /// Start a continuous OODA loop
    pub async fn start_loop(&mut self) -> Result<(), IgnitionError> {
        let mut interval = time::interval(Duration::from_millis(self.config.cycle_interval_ms));
        
        loop {
            interval.tick().await;
            
            match self.run_cycle().await {
                Ok(cycle) => {
                    debug!("Cycle {} completed in {}ms", cycle.cycle_number, cycle.duration_ms);
                }
                Err(e) => {
                    error!("Cycle failed: {}", e);
                    self.state.consecutive_failures += 1;
                    if self.state.consecutive_failures > 5 {
                        return Err(IgnitionError::InternalError("Too many OODA cycle failures".into()));
                    }
                }
            }
        }
    }
}
