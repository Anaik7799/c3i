//! # Core Types — SIL-6 Ignition Daemon
//!
//! ## Fractal Position
//! | Dimension | Value |
//! |-----------|-------|
//! | Layer     | L4-System (Container Orchestration) |
//! | Element   | Types / Domain Model |
//!
//! ## STAMP: SC-IGNITE-001 to SC-IGNITE-010, SC-BOOT-001 to SC-BOOT-010
//!
//! All types derived from:
//! - PanopticIgnition.fs (genome, tiers, image categories)
//! - HealthCoordinator.fs (health states, quorum)
//! - ContainerLifecycleManager.fs (FSM phases)
//! - cpu-governor.sh (adaptive parallelism)
//! - Session journal: 33 constants, 15 FMEA modes, 47 functions

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::Duration;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS — Extracted from F# Core.fs, PanopticIgnition.fs, cpu-governor.sh
// Source: docs/journal/20260402-2352-app-container-ignition-rust-replication-spec.md §15
// ═══════════════════════════════════════════════════════════════════════════════

/// Mesh network name (SC-NET-MESH-001)
pub const MESH_NETWORK: &str = "indrajaal-sil6-mesh";

/// Container ports — Source: Core.fs:318-339
pub const ZENOH_PORT: u16 = 7447;
pub const PHOENIX_PORT: u16 = 4000;
pub const HEALTH_PLUG_PORT: u16 = 4001;
pub const POSTGRES_INTERNAL_PORT: u16 = 5432;
pub const POSTGRES_EXTERNAL_PORT: u16 = 5433;
pub const OTEL_GRPC_PORT: u16 = 4317;
pub const OTEL_HTTP_PORT: u16 = 4318;
pub const PROMETHEUS_PORT: u16 = 9090;
pub const GRAFANA_PORT: u16 = 3000;
pub const LOKI_PORT: u16 = 3100;
pub const BRIDGE_PORT: u16 = 9876;
pub const CORTEX_PORT: u16 = 9877;
pub const OLLAMA_PORT: u16 = 11434;
pub const MOJO_PORT: u16 = 11436;
pub const CHAYA_PORT: u16 = 4002;

/// Image staleness — Source: PanopticIgnition.fs:193
pub const MAX_IMAGE_AGE_HOURS: f64 = 168.0; // 7 days

/// EMA — Source: BuildHistory.fs:148
pub const EMA_ALPHA: f64 = 0.3;

/// Health check — Source: Core.fs:345-351
pub const HEALTH_CHECK_TIMEOUT_MS: u64 = 5000;
pub const BOOT_TIMEOUT_MS: u64 = 60000;
/// Exponential backoff intervals (ms) — Source: Core.fs:351
pub const BACKOFF_INTERVALS: &[u64] = &[100, 200, 400, 800, 1600, 3200, 5000];

/// Quorum — Source: Core.fs:342, HealthCoordinator.fs:218
/// Q(N) = floor(N/2) + 1
pub fn quorum_threshold(total: u32) -> u32 {
    if total == 0 {
        1
    } else {
        (total / 2) + 1
    }
}

/// FPPS thresholds — Source: HealthCoordinator.fs:116-123
pub const FPPS_DEGRADED_THRESHOLD: f64 = 0.7;
pub const FPPS_UNHEALTHY_THRESHOLD: f64 = 0.3;
pub const FPPS_FAILURE_THRESHOLD: u32 = 3;
pub const FPPS_HEARTBEAT_TIMEOUT_SECS: u64 = 30;
pub const FPPS_LATENCY_THRESHOLD_MS: u64 = 5000;

/// CPU Governor — Source: cpu-governor.sh:12-17
pub const CPU_HARD_LIMIT: u8 = 85;
pub const CPU_THROTTLE_THRESHOLD: u8 = 80;
pub const CPU_RESUME_THRESHOLD: u8 = 75;
pub const CPU_CHECK_INTERVAL_SECS: u64 = 2;
pub const CPU_MAX_WAIT_SECS: u64 = 120;
pub const GOVERNOR_NICE: i32 = 10;

/// BIST — Source: PanopticIgnition.fs:878-895
pub const BIST_PING_COUNT: u32 = 10;
pub const BIST_PING_INTERVAL_MS: u64 = 10;
pub const BIST_3SIGMA_THRESHOLD_MS: f64 = 100.0;

/// Lifecycle — Source: ContainerLifecycleManager.fs:151-154
pub const PHASE_TIMEOUT_MS: u64 = 30000;
pub const TRANSITION_POLL_MS: u64 = 500;

/// Shutdown — Source: MeshShutdown.fs:92-101, 443-451
pub const DRAIN_TIMEOUT_MS: u64 = 10000;
pub const FORCE_KILL_AFTER_MS: u64 = 20000;
pub const EMERGENCY_GRACEFUL_MS: u64 = 1000;
pub const EMERGENCY_FORCE_KILL_MS: u64 = 5000;

/// Test mode ports — Source: config/wallaby.exs, .claude/rules/cpu-governor.md §Port Assignments
/// Phoenix test endpoint (wallaby base_url = http://localhost:4050)
pub const TEST_PHOENIX_PORT: u16 = 4050;
/// FoundationSupervisor health plug (avoids mesh port range 4000-4010)
pub const TEST_HEALTH_PORT: u16 = 4051;
/// Dashboard monitoring port (test)
pub const TEST_DASHBOARD_PORT: u16 = 4052;
/// Test container IP within mesh (offset from prod 172.28.0.10)
pub const TEST_CONTAINER_IP: &str = "172.28.0.20";
/// Test container name
pub const TEST_CONTAINER_NAME: &str = "indrajaal-ex-test-1";
/// Test database name
pub const TEST_DATABASE_NAME: &str = "indrajaal_test";

/// Memory — Source: F13 fix (OOM prevention)
pub const APP_MEMORY_LIMIT: &str = "4g";
pub const APP_MEMORY_SWAP: &str = "6g";

/// Redis — Source: F11 fix (locale crash)
pub const REDIS_LOCALE_OVERRIDE: &str = "C";

/// Bridge — Source: F12 fix (socket + stdin)
pub const BRIDGE_SOCKET_CONTAINER: &str = "/run/podman/podman.sock";

// ═══════════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════════

/// Launch mode — prod or test
/// SC-ENV-COMPILE-005 to SC-ENV-COMPILE-007: test mode requires specific env vars
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, clap::ValueEnum)]
pub enum LaunchMode {
    /// Production mode: MIX_ENV=prod, port 4000, mix phx.server
    Prod,
    /// Test mode: MIX_ENV=test, port 4050, HEALTH_PORT=4051, Wallaby-ready
    Test,
}

impl std::fmt::Display for LaunchMode {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            LaunchMode::Prod => write!(f, "prod"),
            LaunchMode::Test => write!(f, "test"),
        }
    }
}

/// Image category — Source: PanopticIgnition.fs, 3 variants
/// SC-IGNITE-008: sil6Genome MUST cover all 16 containers across 3 variants
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ImageCategory {
    BuiltFromDockerfile { dockerfile: String, path: String },
    PulledFromRegistry { registry_image: String },
    SharedImage { source_container: String },
}

/// Container health check type — Source: capture-ignition.sh:158-175
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HealthCheckType {
    /// TCP port probe via `podman exec ... nc -z localhost {port}`
    TcpPort(u16),
    /// PostgreSQL readiness via `podman exec ... pg_isready -U postgres`
    PgIsReady,
    /// Container running state via `podman inspect --format {{.State.Running}}`
    Running,
    /// HTTP health endpoint via `curl -sf {url}`
    Http(String),
}

/// Container health status — Source: HealthCoordinator.fs:38-48
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HealthStatus {
    Healthy,
    Degraded,
    Unhealthy,
    Unreachable,
    Unknown,
}

/// Startup FSM phases — Source: ContainerLifecycleManager.fs:53-58
/// SC-SIL4-012: 5 startup phases MANDATORY
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum StartupPhase {
    Created,
    Starting,
    Initializing,
    Connecting,
    Running,
}

/// Shutdown FSM phases — Source: ContainerLifecycleManager.fs:64-70
/// SC-SIL4-013: 6 shutdown phases MANDATORY
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ShutdownPhase {
    Running,
    Lameduck,
    Draining,
    Checkpointing,
    Stopping,
    Stopped,
}

/// Boot tier — Source: PanopticIgnition.fs:722-981
/// SC-BOOT-005: boot time < 120s (target 60s)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BootTier {
    pub number: u8,
    pub name: String,
    pub containers: Vec<String>,
    pub health_timeout: Duration,
    pub boot_timeout: Duration,
    pub parallel: bool,
}

/// Container criticality — Source: SIL6BiomorphicOrchestrator.fs:140-257
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Criticality {
    P0Critical,
    P1High,
    P2Medium,
    P3Low,
}

/// Boot checkpoint — Source: ZenohCheckpoints.fs, journal §11
/// SC-ZTEST-001: All checkpoints MUST have unique topic
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub enum BootCheckpoint {
    PreflightStart,
    PreflightComplete,
    DbReady,
    ObsReady,
    MeshQuorum,
    CognitiveBridge,
    CognitiveCortex,
    AppSeedReady,
    HomeostasisVerified,
    BootComplete,
}

impl BootCheckpoint {
    pub fn topic(&self) -> &'static str {
        match self {
            Self::PreflightStart => "indrajaal/boot/preflight/start",
            Self::PreflightComplete => "indrajaal/boot/preflight/complete",
            Self::DbReady => "indrajaal/boot/foundation/db_ready",
            Self::ObsReady => "indrajaal/boot/foundation/obs_ready",
            Self::MeshQuorum => "indrajaal/boot/mesh/quorum",
            Self::CognitiveBridge => "indrajaal/boot/cognitive/bridge",
            Self::CognitiveCortex => "indrajaal/boot/cognitive/cortex",
            Self::AppSeedReady => "indrajaal/boot/app/seed_ready",
            Self::HomeostasisVerified => "indrajaal/boot/homeostasis/verified",
            Self::BootComplete => "indrajaal/boot/complete",
        }
    }

    pub fn id(&self) -> &'static str {
        match self {
            Self::PreflightStart => "CP-BOOT-01",
            Self::PreflightComplete => "CP-BOOT-02",
            Self::DbReady => "CP-BOOT-03",
            Self::ObsReady => "CP-BOOT-04",
            Self::MeshQuorum => "CP-BOOT-05",
            Self::CognitiveBridge => "CP-BOOT-06",
            Self::CognitiveCortex => "CP-BOOT-07",
            Self::AppSeedReady => "CP-BOOT-08",
            Self::HomeostasisVerified => "CP-BOOT-09",
            Self::BootComplete => "CP-BOOT-10",
        }
    }
}

/// FMEA recovery action — Source: journal §7, Addendum 2
#[derive(Debug, Clone)]
pub enum RecoveryAction {
    Restart,
    CheckLogs,
    IncreaseMemory,
    RestartOnce,
    GracefulShutdown,
    Halt(String),
}

/// Adaptive parallelism config — Source: cpu-governor.sh:85-116
/// SC-CPU-GOV-006: Scheduler count adapts: 16 < 60%, 12 < 70%, 10 < 80%, 6 >= 80%
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParallelismConfig {
    pub schedulers: u8,
    pub dirty_io: u8,
    pub mix_jobs: u8,
    pub nice_level: i32,
}

// ═══════════════════════════════════════════════════════════════════════════════
// STRUCTS
// ═══════════════════════════════════════════════════════════════════════════════

/// SIL-6 genome entry — Source: PanopticIgnition.fs:217-238
/// SC-IGNITE-008: genome MUST cover all 16 containers
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenomeEntry {
    pub name: String,
    pub category: ImageCategory,
    pub ip: Option<String>,
    pub tier: u8,
    pub health_check: HealthCheckType,
    pub health_timeout: Duration,
    pub criticality: Criticality,
}

/// State vector — Source: StartupVerification.fs:46-59
/// Mathematical model: ∀i, t₁ < t₂: S[i](t₁) = 1 ⟹ S[i](t₂) = 1 (monotonicity)
/// ValidStartup ⟺ ∏ᵢ S[i] = 1 (all elements must be true)
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StateVector {
    pub compile: bool,
    pub migrations: bool,
    pub containers: bool,
    pub zenoh: bool,
    pub health: bool,
    pub quorum: bool,
}

impl StateVector {
    pub fn is_valid(&self) -> bool {
        self.compile
            && self.migrations
            && self.containers
            && self.zenoh
            && self.health
            && self.quorum
    }

    pub fn as_array(&self) -> [u8; 6] {
        [
            self.compile as u8,
            self.migrations as u8,
            self.containers as u8,
            self.zenoh as u8,
            self.health as u8,
            self.quorum as u8,
        ]
    }
}

/// Pre-flight report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreflightReport {
    pub infrastructure: CheckResult,
    pub database: CheckResult,
    pub zenoh_quorum: CheckResult,
    pub network: CheckResult,
    pub image: CheckResult,
    pub observability: CheckResult,
    pub passed: bool,
    pub duration_ms: u64,
}

/// Individual check result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CheckResult {
    pub name: String,
    pub passed: bool,
    pub message: String,
    pub duration_ms: u64,
}

/// Container health node — Source: HealthCoordinator.fs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthNode {
    pub name: String,
    pub status: HealthStatus,
    pub health_score: f64,
    pub consecutive_failures: u32,
    pub last_heartbeat: Option<DateTime<Utc>>,
    pub response_time_ms: Option<u64>,
}

/// Verification report — 14 checks
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VerifyReport {
    pub checks: Vec<CheckResult>,
    pub passed_count: u32,
    pub total_count: u32,
    pub all_passed: bool,
    pub state_vector: StateVector,
}

/// FMEA entry — Source: journal §7
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FmeaEntry {
    pub id: String,
    pub failure_mode: String,
    pub severity: u8,
    pub occurrence: u8,
    pub detection: u8,
    pub rpn: u16,
    pub mitigation: String,
}

// ═══════════════════════════════════════════════════════════════════════════════
// W1-W5 STABILIZATION TYPES
// Source: docs/plans/20260403-1700-rust-preflight-ignition-stabilization-plan.md
// ═══════════════════════════════════════════════════════════════════════════════

/// NIF binary libc flavor — Source: Axiom 0.1, journal 20260402-1605
/// Detects glibc vs musl mismatch before boot (not during crash)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LibcFlavor {
    Glibc,
    Musl,
    StaticLinked,
    Unknown,
}

/// NIF validation result — Source: nif_validator.rs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NifValidationResult {
    pub nif_name: String,
    pub path: PathBuf,
    pub libc_flavor: LibcFlavor,
    pub is_valid: bool,
    pub elf_class: String,   // ELF64 / ELF32
    pub machine: String,     // x86_64 / aarch64
    pub interpreter: String, // /lib64/ld-linux-x86-64.so.2 etc.
    pub dynamic_libs: Vec<String>,
    pub errors: Vec<String>,
}

/// Substrate guard check — Source: substrate_guard.rs, Axiom 0.1/0.2
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstrateCheck {
    pub name: String,
    pub passed: bool,
    pub detail: String,
}

/// Substrate guard report
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubstrateReport {
    pub checks: Vec<SubstrateCheck>,
    pub all_passed: bool,
    pub host_build_detected: bool,
    pub host_deps_detected: bool,
    pub contamination_paths: Vec<PathBuf>,
}

/// Build oracle EMA record — Source: F# BuildHistory.fs:148
/// Mirrors the `build_ema` SQLite table written by F#
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BuildEmaRecord {
    pub container_name: String,
    pub ema_duration_ms: f64,
    pub ema_image_size: f64,
    pub total_builds: i64,
    pub last_success: Option<String>,
    pub last_failure: Option<String>,
}

/// Adaptive timeout from build oracle
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AdaptiveTimeout {
    pub container_name: String,
    pub base_timeout_ms: u64,
    pub ema_timeout_ms: u64,
    pub multiplier: f64,
    pub source: TimeoutSource,
}

/// Where the timeout value came from
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TimeoutSource {
    /// EMA from BuildHistory.db (learned, preferred)
    BuildOracle,
    /// Fixed default (fallback when no EMA data)
    Default,
}

/// Health orchestra method — Source: health_orchestra.rs
/// FPPS 5-method consensus (SC-IGNITE-005, Omega-5)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum HealthMethod {
    /// Container is running (podman inspect)
    Running,
    /// TCP port is reachable
    PortOpen,
    /// Service endpoint responds (HTTP or pg_isready)
    ServiceEndpoint,
    /// Quorum voting agrees (2oo3)
    QuorumVote,
    /// Digital twin state matches (Chaya sync)
    DigitalTwin,
}

/// Health orchestra result per method
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthMethodResult {
    pub method: HealthMethod,
    pub passed: bool,
    pub latency_ms: u64,
    pub detail: String,
}

/// Health orchestra consensus result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthConsensus {
    pub container_name: String,
    pub methods: Vec<HealthMethodResult>,
    pub agreed: u32,
    pub total: u32,
    pub consensus_reached: bool,
    pub overall_status: HealthStatus,
}

/// Recovery playbook — Source: recovery.rs
/// Deterministic recovery actions for top-15 failure modes (expanded from 5)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FailureMode {
    // Original 5 (RPN 252-140)
    /// RPN 252: NIF compilation failure (cargo not found, missing deps)
    NifCompilationFailure,
    /// RPN 225: glibc/musl NIF binary conflict (host _build leaks into container)
    GlibcMuslConflict,
    /// RPN 196: Fixed health timeouts (first build takes 300s+)
    HealthTimeout,
    /// RPN 168: Boot ordering races (app tier starts before DB/Zenoh ready)
    BootOrderingRace,
    /// RPN 140: Operator observability gaps
    ObservabilityGap,
    // New 10 (Idea #48 — Self-Healing Playbook Expansion)
    /// RPN 230: Cascading failure across multiple tiers
    CascadingFailure,
    /// RPN 210: Disk exhaustion (container logs, volumes, images)
    DiskExhaustion,
    /// RPN 198: Memory leak (container RSS growing unbounded)
    MemoryLeak,
    /// RPN 189: Network partition (containers isolated from mesh)
    NetworkPartition,
    /// RPN 175: Image corruption (layer mismatch, digest mismatch)
    ImageCorruption,
    /// RPN 162: Certificate expiry (TLS certs expiring within 30 days)
    CertificateExpiry,
    /// RPN 154: Clock drift (NTP desync > 100ms between containers)
    ClockDrift,
    /// RPN 147: Zombie processes (defunct processes accumulating)
    ZombieProcess,
    /// RPN 138: Registry unavailable (localhost registry unreachable)
    RegistryUnavailable,
    /// RPN 130: Configuration drift (env vars, ports, volumes changed)
    ConfigDrift,
}

/// Recovery step — single action in a playbook
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecoveryStep {
    pub order: u8,
    pub action: String,
    pub command: Option<String>,
    pub expected_result: String,
    pub timeout_ms: u64,
}

/// Recovery playbook for a failure mode
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecoveryPlaybook {
    pub failure_mode: FailureMode,
    pub rpn: u16,
    pub steps: Vec<RecoveryStep>,
    pub max_retries: u8,
    pub escalation: String,
}

/// Recovery execution result
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecoveryResult {
    pub failure_mode: FailureMode,
    pub success: bool,
    pub steps_executed: u8,
    pub steps_total: u8,
    pub duration_ms: u64,
    pub detail: String,
}

/// Build oracle database path constant
pub const BUILD_HISTORY_DB_PATH: &str = "lib/cepaf/artifacts/build-history.db";

/// EMA multiplier for adaptive timeout (safety margin)
/// timeout = ema_duration * EMA_TIMEOUT_MULTIPLIER
pub const EMA_TIMEOUT_MULTIPLIER: f64 = 2.5;

/// Minimum adaptive timeout (never go below this even if EMA is very fast)
pub const MIN_ADAPTIVE_TIMEOUT_MS: u64 = 15_000;

/// Maximum adaptive timeout (cap to prevent infinite waits)
pub const MAX_ADAPTIVE_TIMEOUT_MS: u64 = 600_000;

/// Consensus threshold for health orchestra (3 out of 5 methods must agree)
pub const HEALTH_CONSENSUS_THRESHOLD: u32 = 3;

/// Maximum recovery retries before escalation
pub const MAX_RECOVERY_RETRIES: u8 = 3;

// ═══════════════════════════════════════════════════════════════════════════════
// W6-W8 ROBUSTNESS TYPES (Phase 1 — Ideas 16, 21, 22, 30, 46, 48, 51, 57)
// ═══════════════════════════════════════════════════════════════════════════════

/// Maximum cascading failure containment depth (prevent infinite cascade)
pub const MAX_CASCADE_DEPTH: u8 = 3;

/// Emergency drain timeout per container (ms)
pub const EMERGENCY_DRAIN_TIMEOUT_MS: u64 = 5000;

/// Stabilization window after all containers running (ms)
pub const STABILIZATION_WINDOW_MS: u64 = 30000;

/// Maximum concurrent container launches (prevent I/O storms)
pub const MAX_CONCURRENT_LAUNCHES: usize = 4;

/// Cascading failure containment state (Idea #46)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CascadeState {
    pub failed_containers: Vec<String>,
    pub isolated_domains: Vec<Vec<String>>,
    pub cascade_depth: u8,
    pub containment_active: bool,
    pub recovery_order: Vec<String>,
}

impl Default for CascadeState {
    fn default() -> Self {
        Self {
            failed_containers: Vec::new(),
            isolated_domains: Vec::new(),
            cascade_depth: 0,
            containment_active: false,
            recovery_order: Vec::new(),
        }
    }
}

/// Network partition detection result (Idea #51)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PartitionResult {
    pub detected: bool,
    pub partition_a: Vec<String>,
    pub partition_b: Vec<String>,
    pub minority_partition: Vec<String>,
    pub fence_required: bool,
}

/// Emergency drain result (Idea #30)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DrainResult {
    pub success: bool,
    pub containers_stopped: Vec<String>,
    pub containers_failed: Vec<String>,
    pub networks_cleaned: Vec<String>,
    pub volumes_preserved: Vec<String>,
    pub duration_ms: u64,
    pub detail: String,
}

/// Ignition checkpoint for resume (Idea #23)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IgnitionCheckpoint {
    pub phase: String,
    pub tier: u8,
    pub containers_started: Vec<String>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub preflight_passed: bool,
}

/// Last known good configuration for rollback (Idea #57)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KnownGoodConfig {
    pub version: u64,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub container_states: std::collections::HashMap<String, ContainerStateSnapshot>,
    pub network_config: String,
    pub volume_config: String,
}

/// Snapshot of a container's state for rollback
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContainerStateSnapshot {
    pub image: String,
    pub env_vars: std::collections::HashMap<String, String>,
    pub ports: Vec<String>,
    pub volumes: Vec<String>,
    pub networks: Vec<String>,
}

/// Atomic tier commit result (Idea #16)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TierCommitResult {
    pub tier: u8,
    pub success: bool,
    pub containers_started: Vec<String>,
    pub containers_rolled_back: Vec<String>,
    pub detail: String,
}

// ═══════════════════════════════════════════════════════════════════════════════
// DEPENDENCY GRAPH TYPE (for launch.rs DAG-based resolution)
// ═══════════════════════════════════════════════════════════════════════════════

/// Directed acyclic graph for container boot ordering.
/// Source: launch.rs — DAG-based dependency resolution
#[derive(Debug, Clone)]
pub struct DependencyGraph {
    containers: Vec<String>,
    dependencies: std::collections::HashMap<String, Vec<String>>,
}

impl DependencyGraph {
    pub fn new() -> Self {
        Self {
            containers: Vec::new(),
            dependencies: std::collections::HashMap::new(),
        }
    }

    pub fn add_container(&mut self, name: &str) {
        if !self.containers.contains(&name.to_string()) {
            self.containers.push(name.to_string());
        }
    }

    pub fn add_dependency(&mut self, container: &str, dependency: &str) {
        self.add_container(container);
        self.add_container(dependency);
        self.dependencies
            .entry(container.to_string())
            .or_default()
            .push(dependency.to_string());
    }

    /// Calculate boot waves using topological sort (Kahn's algorithm).
    /// Returns vectors of container names that can boot in parallel.
    pub fn calculate_waves(&self) -> Vec<Vec<String>> {
        let mut in_degree: std::collections::HashMap<String, usize> =
            std::collections::HashMap::new();
        for c in &self.containers {
            in_degree.entry(c.clone()).or_insert(0);
        }
        for deps in self.dependencies.values() {
            for dep in deps {
                *in_degree.entry(dep.clone()).or_insert(0);
            }
        }
        for (container, deps) in &self.dependencies {
            for dep in deps {
                *in_degree.entry(container.clone()).or_insert(0) += 1;
            }
        }

        let mut waves = Vec::new();
        let mut remaining = in_degree.clone();

        loop {
            let wave: Vec<String> = remaining
                .iter()
                .filter(|(_, &deg)| deg == 0)
                .map(|(name, _)| name.clone())
                .collect();

            if wave.is_empty() {
                break;
            }

            for name in &wave {
                remaining.remove(name);
                for (container, deps) in &self.dependencies {
                    if deps.contains(name) {
                        if let Some(deg) = remaining.get_mut(container) {
                            *deg -= 1;
                        }
                    }
                }
            }

            waves.push(wave);
        }

        waves
    }
}
