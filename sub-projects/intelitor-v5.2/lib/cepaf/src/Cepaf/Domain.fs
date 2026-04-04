namespace Cepaf

open System
open Argu

// --- PODMAN SPECIFIC TYPES ---
type PodmanSocket =
    | Rootful of path: string
    | Rootless of path: string

type PodmanRuntime =
    | Crun
    | Runc

type PodmanState =
    | Created
    | Running
    | Paused
    | Exited
    | Stopped
    | Removing
    | Dead of reason: string

type PodmanHealthStatus =
    | HealthStarting
    | Healthy
    | Unhealthy
    | HealthNone

type PodmanServiceType =
    | Container
    | Pod
    | Image
    | Volume
    | Network

// --- CORE SYSTEM TYPES (V21.0) ---
// Updated: 2025-12-26 for Cortex Master Plan Integration
type Environment =
    | DEV | TEST | DEMO | PROD | SYSTEM_STANDALONE_DB_TEST | SYSTEM_STANDALONE_OBS_TEST | MESH
    | SIL6  // SIL-6 Biomorphic Fractal Mesh full 16-container topology
    | SHADOW_MODE_EVAL  // Shadow model evaluation environment (SC-SHADOW-001)

type ContainerState =
    | Absent
    | Created
    | Starting
    | Probing
    | Healthy
    | Unhealthy of reason: string
    | Dead of exitCode: int * stderr: string

type TaskStatus = 
    | Pending 
    | InProgress of percent: int 
    | Completed 
    | Failed of reason: string

type ProtocolTask = {
    Id: string
    Description: string
    EntryCriteria: string
    ExitCriteria: string
    StartState: string
    EndState: string
    Status: TaskStatus
    EstimatedDurationMs: int64
    ActualDurationMs: int64 option
}

type SafetyConstraint = {
    Id: string
    Category: string
    Description: string
    Compliance: bool option
}

type SystemRegistry = {
    LogPath: string
    DatabasePath: string
    TempDir: string
    ComposeFiles: Map<Environment, string>
    ContainerNames: Map<string, string>
    PortMap: Map<string, int>
    ReadyPatterns: Map<string, string>
    Dockerfiles: Map<string, string>
    Constraints: SafetyConstraint list
    PodmanSocket: PodmanSocket option
}

type AppError =
    | InfrastructureError of tool: string * message: string
    | ProcessError of cmd: string * exitCode: int * stderr: string
    | HealthCheckTimedOut of service: string * probe: string
    | ConfigurationError of reason: string
    | DependencyCycleDetected of nodes: string list
    | FileIOError of path: string * message: string
    | ValidationFailed of rule: string * reason: string
    | FormalVerificationError of gate: string * error: string
    | BootMandateViolation of durationMs: int64 * thresholdMs: int64
    | SafetyViolation of constraintId: string * reason: string
    | PodmanApiError of endpoint: string * statusCode: int * body: string
    | SignalInterrupt
    | CircuitBreakerOpen of tool: string
    | PhicsLatencyViolation of actual: int64 * target: int
    | AorViolation of ruleId: string * reason: string

type TelemetryEvent =
    | ProtocolStart of timestamp: DateTimeOffset
    | ProtocolComplete of durationMs: int64 * success: bool
    | PhaseStart of name: string
    | PhaseComplete of name: string * durationMs: int64 * success: bool
    | TaskUpdate of task: ProtocolTask
    | OodaTransition of phase: string * decision: string
    | AnomalyDetected of description: string * severity: string
    | MetricLogged of name: string * value: float
    | SafetyAuditStarted
    | SafetyCheckPassed of constraintId: string
    | SafetyAuditComplete of success: bool
    | PodmanEventObserved of id: string * status: string * timestamp: string
    // --- CORTEX MASTER PLAN EVENTS (2025-12-26) ---
    | TrainingGymEpisode of episodeType: string * reward: float
    | ShadowModeExecution of modelId: string * agreed: bool
    | GuardianValidation of action: string * approved: bool
    | OpenRouterCall of model: string * tokenCount: int64
    // --- GDE PIPELINE EVENTS (2025-12-26 Phase 8) ---
    | GDEProposalGenerated of proposalType: string * confidence: float
    | GDEProposalValidated of proposalId: string * passed: bool * reason: string
    | GDECycleComplete of proposalCount: int * validatedCount: int * successRate: float
    | FractalLogEvent of level: int * channel: string * message: string
    | ZenohEvolutionEvent of keyExpr: string * eventType: string * payload: string

type CepaConfig = {
    Environments: Environment list
    Sterilize: bool
    FormalVerify: bool
    Build: bool
    DbTestOnly: bool
    ObsTestOnly: bool
    StandaloneMode: bool
    InfraCheck: bool
    RunTests: bool
    RunUiCheck: bool
    AutoConfirm: bool
    PatientMode: bool
    PhicsEnabled: bool
    BootThresholdMs: int64
    Registry: SystemRegistry
}

type CepaArgs =
    | [<AltCommandLine("-e")>] Env of Environment list
    | [<AltCommandLine("-y")>] Yes
    | [<AltCommandLine("-i")>] No_Infra
    | No_Sterilize
    | No_Build
    | [<AltCommandLine("-v")>] Verify
    | [<AltCommandLine("-d")>] Db_Test
    | [<AltCommandLine("-o")>] Obs_Test
    | [<AltCommandLine("-s")>] Standalone
    | Test
    | UI
    | [<AltCommandLine("-p")>] Patient_Mode
    | Dashboard_Demo
    | Prajna_Demo
    | C3I_Demo
    | AEE_Mode
    | [<AltCommandLine("-t")>] Theme_Simulator
    | SIL4_Startup
    | SIL4_Shutdown
    | SIL6_Startup
    | SIL6_Shutdown
    | Supervised_Ignite
    | Prajna_Migration_Demo
    | Phase2_Verify
    | Phase3_Verify
    | FullSystem_Verify
    | Phase5_Verify
    | Fractal_Verify
    | Prune of metabolic: bool
    | Confirm_Prune of hash: string

    interface IArgParserTemplate with
        member s.Usage =
            match s with
            | Env _ -> "Target environments."
            | Yes -> "Auto-confirm."
            | No_Infra -> "Skip infra."
            | No_Sterilize -> "Skip VTO."
            | No_Build -> "Skip build."
            | Verify -> "Formal verification."
            | Db_Test -> "Standalone DB Test."
            | Obs_Test -> "Standalone OBS Test."
            | Standalone -> "Standalone distributed mode setup."
            | Test -> "Run Elixir tests."
            | UI -> "Run UI checks."
            | Patient_Mode -> "Enable Patient Mode."
            | Dashboard_Demo -> "Run CLI Dashboard demo."
            | Prajna_Demo -> "Run PRAJNA C3I Mesh Cockpit (AI-Enhanced Intelligence)."
            | C3I_Demo -> "Run C3I Multi-Agent Dashboard with OODA/GDE/ACE (Full Autonomic)."
            | AEE_Mode -> "Run full AEE mode with fast OODA until zero-defect goal achieved."
            | Theme_Simulator -> "Run Aerospace Theme Simulator with user journey testing."
            | SIL4_Startup -> "Execute SIL4 optimized mesh startup (10s SLA)."
            | SIL4_Shutdown -> "Execute SIL4 surgical mesh shutdown (5s SLA)."
            | SIL6_Startup -> "Execute SIL6 biomorphic full-mesh startup (15 containers)."
            | SIL6_Shutdown -> "Execute SIL6 biomorphic full-mesh shutdown with checkpoint."
            | Supervised_Ignite -> "Execute SIL6 Panoptic Ignition with Autonomic Supervisor Agent."
            | Prajna_Migration_Demo -> "Run Prajna Migration Verification Demo"
            | Phase2_Verify -> "Run Phase 2 Connectivity Verification (Lobotomy Test)"
            | Phase3_Verify -> "Run Phase 3 Cognitive Expansion Verification (Synapse/KMS)"
            | Phase5_Verify -> "Run Phase 5 Cognitive Fabric Verification (Memory/RAG)"
            | FullSystem_Verify -> "Run Master 9x9 Full System Verification (Prajna/Chaya/Smriti)"
            | Fractal_Verify -> "Run 8x8 Fractal Health Check Suite (L0-L7) with Quadruplex Logging"
            | Prune _ -> "Execute substrate pruning. Use --metabolic for high-assurance orphan cleanup."
            | Confirm_Prune _ -> "Confirm metabolic pruning with BLAKE3 hash from analysis report."
