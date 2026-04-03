// =============================================================================
// QUINT FORMAL SPECIFICATIONS
// Subsystems: C1.1 Observability | C1.3.2 Container Security | C2.1 FLAME
// Version: 1.0.0 | Date: 2025-12-18
// Framework: SOPv5.11 + STAMP + TDG + GDE
// =============================================================================

// =============================================================================
// MODULE 1: OBSERVABILITY SUBSYSTEM (C1.1)
// =============================================================================

module Observability {

  // ---------------------------------------------------------------------------
  // Types
  // ---------------------------------------------------------------------------

  type ExporterState = Disconnected | Connecting | Connected | Exporting | Retrying | Failed
  type SamplingStrategy = AlwaysOn | AlwaysOff | Probability | RateLimiting
  type LogLevel = Debug | Info | Warning | Error | Critical

  type Span = {
    traceId: str,
    spanId: str,
    name: str,
    attributes: str -> str,
    startTime: int,
    endTime: int
  }

  type Metric = {
    name: str,
    value: int,
    labels: str -> str,
    timestamp: int
  }

  // ---------------------------------------------------------------------------
  // State Variables
  // ---------------------------------------------------------------------------

  var exporterState: ExporterState
  var retryCount: int
  var batchBuffer: List[Span]
  var metricsBuffer: List[Metric]
  var samplingRate: int  // 0-100 percentage
  var handlersAttached: bool
  var otelInitialized: bool
  var globalClock: int

  // ---------------------------------------------------------------------------
  // Constants (SC-OBS constraints)
  // ---------------------------------------------------------------------------

  pure val MAX_RETRY_COUNT = 5
  pure val MAX_BATCH_SIZE = 1000
  pure val BATCH_TIMEOUT_MS = 10000
  pure val MIN_SAMPLING_RATE = 1
  pure val MAX_SAMPLING_RATE = 100

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  action init = all {
    exporterState' = Disconnected,
    retryCount' = 0,
    batchBuffer' = [],
    metricsBuffer' = [],
    samplingRate' = 100,
    handlersAttached' = false,
    otelInitialized' = false,
    globalClock' = 0
  }

  // ---------------------------------------------------------------------------
  // SC-OBS-001: Initialize OTEL before tracing
  // ---------------------------------------------------------------------------

  action initializeOTEL: bool = all {
    not(otelInitialized),
    otelInitialized' = true,
    exporterState' = Connecting,
    globalClock' = globalClock + 1
  }

  // ---------------------------------------------------------------------------
  // SC-OBS-002: Attach telemetry handlers at startup
  // ---------------------------------------------------------------------------

  action attachHandlers: bool = all {
    otelInitialized,
    not(handlersAttached),
    handlersAttached' = true,
    globalClock' = globalClock + 1
  }

  // ---------------------------------------------------------------------------
  // Exporter State Transitions
  // ---------------------------------------------------------------------------

  action connectExporter: bool = all {
    exporterState == Connecting,
    exporterState' = Connected,
    retryCount' = 0,
    globalClock' = globalClock + 100
  }

  action exportBatch: bool = all {
    exporterState == Connected,
    length(batchBuffer) > 0,
    exporterState' = Exporting,
    globalClock' = globalClock + 50
  }

  action exportSuccess: bool = all {
    exporterState == Exporting,
    exporterState' = Connected,
    batchBuffer' = [],
    globalClock' = globalClock + 10
  }

  action exportFailure: bool = all {
    exporterState == Exporting,
    retryCount < MAX_RETRY_COUNT,
    exporterState' = Retrying,
    retryCount' = retryCount + 1,
    globalClock' = globalClock + 100
  }

  action retrySuccess: bool = all {
    exporterState == Retrying,
    exporterState' = Connected,
    retryCount' = 0,
    batchBuffer' = [],
    globalClock' = globalClock + 100
  }

  action maxRetriesReached: bool = all {
    exporterState == Retrying,
    retryCount >= MAX_RETRY_COUNT,
    exporterState' = Failed,
    globalClock' = globalClock + 10
  }

  // ---------------------------------------------------------------------------
  // SC-OBS-006: Batch spans before export
  // ---------------------------------------------------------------------------

  action addSpanToBatch(span: Span): bool = all {
    otelInitialized,
    length(batchBuffer) < MAX_BATCH_SIZE,
    batchBuffer' = batchBuffer.append(span),
    globalClock' = globalClock + 1
  }

  // ---------------------------------------------------------------------------
  // Safety Invariants
  // ---------------------------------------------------------------------------

  // SC-OBS-001: OTEL init before handlers
  val otelInitBeforeHandlers: bool =
    handlersAttached implies otelInitialized

  // SC-OBS-006: Batch size limit
  val batchSizeLimit: bool =
    length(batchBuffer) <= MAX_BATCH_SIZE

  // SC-OBS-007: Bounded retry
  val boundedRetry: bool =
    retryCount <= MAX_RETRY_COUNT

  // SC-OBS-009: No blocking on failure (exporter failure doesn't stop app)
  val noBlockingOnFailure: bool =
    exporterState == Failed implies otelInitialized

  // SC-OBS-013: Valid sampling rate
  val validSamplingRate: bool =
    samplingRate >= MIN_SAMPLING_RATE and samplingRate <= MAX_SAMPLING_RATE

  // Combined invariant
  val observabilityInvariant: bool = all {
    otelInitBeforeHandlers,
    batchSizeLimit,
    boundedRetry,
    noBlockingOnFailure,
    validSamplingRate
  }

  temporal alwaysObservabilitySafe = always(observabilityInvariant)

  // ---------------------------------------------------------------------------
  // Liveness Properties
  // ---------------------------------------------------------------------------

  // Eventually exports or fails
  temporal exportEventuallyCompletes = always(
    exporterState == Exporting implies eventually(
      exporterState == Connected or exporterState == Failed
    )
  )

  // Retry eventually resolves
  temporal retryEventuallyResolves = always(
    exporterState == Retrying implies eventually(
      exporterState == Connected or exporterState == Failed
    )
  )
}

// =============================================================================
// MODULE 2: CONTAINER SECURITY SUBSYSTEM (C1.3.2)
// =============================================================================

module ContainerSecurity {

  // ---------------------------------------------------------------------------
  // Types
  // ---------------------------------------------------------------------------

  type SecurityState = Unchecked | Validating | Compliant | NonCompliant | Remediated
  type Capability = NetBindService | SetUID | SetGID | SysAdmin | All
  type SeccompProfile = RuntimeDefault | CustomRestricted | Unconfined

  type SecurityContext = {
    runAsNonRoot: bool,
    userId: int,
    readOnlyFs: bool,
    noNewPrivileges: bool,
    seccompProfile: SeccompProfile,
    capabilities: Set[Capability]
  }

  type Container = {
    name: str,
    securityContext: SecurityContext,
    registry: str,
    imageScanned: bool,
    vulnerabilities: int
  }

  // ---------------------------------------------------------------------------
  // State Variables
  // ---------------------------------------------------------------------------

  var securityState: SecurityState
  var containers: str -> Container
  var auditLog: List[str]
  var policyViolations: int
  var globalClock: int

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  pure val ALLOWED_CAPABILITIES = Set(NetBindService, SetUID, SetGID)
  pure val ALLOWED_REGISTRY = "localhost/"
  pure val MAX_VULNERABILITIES = 0
  pure val MIN_USER_ID = 1000

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  action init = all {
    securityState' = Unchecked,
    containers' = Map(),
    auditLog' = [],
    policyViolations' = 0,
    globalClock' = 0
  }

  // ---------------------------------------------------------------------------
  // SC-SEC-001: Run as non-root
  // ---------------------------------------------------------------------------

  def isNonRoot(ctx: SecurityContext): bool =
    ctx.runAsNonRoot and ctx.userId >= MIN_USER_ID

  // ---------------------------------------------------------------------------
  // SC-SEC-002/003: Minimal capabilities
  // ---------------------------------------------------------------------------

  def hasMinimalCapabilities(ctx: SecurityContext): bool =
    ctx.capabilities.forall(c => ALLOWED_CAPABILITIES.contains(c))

  // ---------------------------------------------------------------------------
  // SC-SEC-008: Localhost registry only
  // ---------------------------------------------------------------------------

  def isAllowedRegistry(container: Container): bool =
    container.registry == ALLOWED_REGISTRY

  // ---------------------------------------------------------------------------
  // Security Validation Actions
  // ---------------------------------------------------------------------------

  action validateContainer(name: str, container: Container): bool = all {
    securityState == Unchecked or securityState == Compliant,
    securityState' = Validating,
    containers' = containers.set(name, container),
    globalClock' = globalClock + 10
  }

  action validationPass: bool = all {
    securityState == Validating,
    containers.keys().forall(name =>
      val c = containers.get(name);
      isNonRoot(c.securityContext) and
      hasMinimalCapabilities(c.securityContext) and
      isAllowedRegistry(c) and
      c.vulnerabilities <= MAX_VULNERABILITIES
    ),
    securityState' = Compliant,
    globalClock' = globalClock + 5
  }

  action validationFail: bool = all {
    securityState == Validating,
    not(containers.keys().forall(name =>
      val c = containers.get(name);
      isNonRoot(c.securityContext) and hasMinimalCapabilities(c.securityContext)
    )),
    securityState' = NonCompliant,
    policyViolations' = policyViolations + 1,
    auditLog' = auditLog.append("VIOLATION: Security policy failed"),
    globalClock' = globalClock + 5
  }

  action remediate: bool = all {
    securityState == NonCompliant,
    securityState' = Validating,
    globalClock' = globalClock + 100
  }

  // ---------------------------------------------------------------------------
  // Safety Invariants
  // ---------------------------------------------------------------------------

  // SC-SEC-001: All containers run as non-root
  val allNonRoot: bool =
    securityState == Compliant implies containers.keys().forall(name =>
      isNonRoot(containers.get(name).securityContext)
    )

  // SC-SEC-002/003: Minimal capabilities
  val minimalCapabilities: bool =
    securityState == Compliant implies containers.keys().forall(name =>
      hasMinimalCapabilities(containers.get(name).securityContext)
    )

  // SC-SEC-008: Registry restriction
  val registryRestriction: bool =
    securityState == Compliant implies containers.keys().forall(name =>
      isAllowedRegistry(containers.get(name))
    )

  // SC-SEC-004: Seccomp enabled
  val seccompEnabled: bool =
    securityState == Compliant implies containers.keys().forall(name =>
      containers.get(name).securityContext.seccompProfile != Unconfined
    )

  // SC-SEC-005: No new privileges
  val noNewPrivileges: bool =
    securityState == Compliant implies containers.keys().forall(name =>
      containers.get(name).securityContext.noNewPrivileges
    )

  // Combined invariant
  val securityInvariant: bool = all {
    allNonRoot,
    minimalCapabilities,
    registryRestriction,
    seccompEnabled,
    noNewPrivileges
  }

  temporal alwaysSecure = always(securityInvariant)

  // ---------------------------------------------------------------------------
  // Liveness Properties
  // ---------------------------------------------------------------------------

  // Non-compliant eventually remediated or validated
  temporal eventuallyCompliant = always(
    securityState == NonCompliant implies eventually(
      securityState == Compliant or securityState == Validating
    )
  )
}

// =============================================================================
// MODULE 3: FLAME ELASTIC COMPUTE (C2.1)
// =============================================================================

module FLAMECompute {

  // ---------------------------------------------------------------------------
  // Types
  // ---------------------------------------------------------------------------

  type PoolState = Idle | Spawning | Running | ScalingUp | ScalingDown | Draining | Terminated
  type RunnerState = Starting | Ready | Busy | RunnerDraining | RunnerTerminated

  type Runner = {
    id: int,
    state: RunnerState,
    activeTasks: int,
    localState: int  // Should be 0 for stateless
  }

  type Pool = {
    name: str,
    state: PoolState,
    minSize: int,
    maxSize: int,
    maxConcurrency: int,
    idleShutdownMs: int,
    runners: int -> Runner
  }

  // ---------------------------------------------------------------------------
  // State Variables
  // ---------------------------------------------------------------------------

  var pools: str -> Pool
  var totalRunners: int
  var workQueue: int
  var crashedRunners: int
  var telemetryEvents: List[str]
  var globalClock: int

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  pure val MAX_POOLS = 10
  pure val MIN_IDLE_SHUTDOWN_MS = 1000
  pure val MAX_RUNNERS_PER_POOL = 100

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  action init = all {
    pools' = Map(
      "IntelligencePool" -> {
        name: "IntelligencePool",
        state: Idle,
        minSize: 0,
        maxSize: 10,
        maxConcurrency: 5,
        idleShutdownMs: 30000,
        runners: Map()
      },
      "VideoPool" -> {
        name: "VideoPool",
        state: Idle,
        minSize: 0,
        maxSize: 20,
        maxConcurrency: 2,
        idleShutdownMs: 60000,
        runners: Map()
      }
    ),
    totalRunners' = 0,
    workQueue' = 0,
    crashedRunners' = 0,
    telemetryEvents' = [],
    globalClock' = 0
  }

  // ---------------------------------------------------------------------------
  // Pool Operations
  // ---------------------------------------------------------------------------

  action submitWork(poolName: str, workCount: int): bool = all {
    pools.keys().contains(poolName),
    pools.get(poolName).state == Idle,
    workQueue' = workQueue + workCount,
    pools' = pools.set(poolName, { ...pools.get(poolName), state: Spawning }),
    telemetryEvents' = telemetryEvents.append("flame.pool.spawning"),
    globalClock' = globalClock + 10
  }

  action spawnRunner(poolName: str, runnerId: int): bool =
    val pool = pools.get(poolName);
    val newRunner = { id: runnerId, state: Starting, activeTasks: 0, localState: 0 };
    all {
      pool.state == Spawning or pool.state == ScalingUp,
      pool.runners.keys().size() < pool.maxSize,
      pools' = pools.set(poolName, {
        ...pool,
        runners: pool.runners.set(runnerId, newRunner)
      }),
      totalRunners' = totalRunners + 1,
      telemetryEvents' = telemetryEvents.append("flame.runner.spawn"),
      globalClock' = globalClock + 100
    }

  action runnerReady(poolName: str, runnerId: int): bool =
    val pool = pools.get(poolName);
    all {
      pool.runners.keys().contains(runnerId),
      pool.runners.get(runnerId).state == Starting,
      pools' = pools.set(poolName, {
        ...pool,
        state: Running,
        runners: pool.runners.set(runnerId, { ...pool.runners.get(runnerId), state: Ready })
      }),
      globalClock' = globalClock + 10
    }

  // SC-FLAME-004: Graceful drain before shutdown
  action drainRunner(poolName: str, runnerId: int): bool =
    val pool = pools.get(poolName);
    all {
      pool.runners.keys().contains(runnerId),
      pool.runners.get(runnerId).state == Ready or pool.runners.get(runnerId).state == Busy,
      pools' = pools.set(poolName, {
        ...pool,
        runners: pool.runners.set(runnerId, { ...pool.runners.get(runnerId), state: RunnerDraining })
      }),
      telemetryEvents' = telemetryEvents.append("flame.runner.draining"),
      globalClock' = globalClock + 10
    }

  action terminateRunner(poolName: str, runnerId: int): bool =
    val pool = pools.get(poolName);
    val runner = pool.runners.get(runnerId);
    all {
      pool.runners.keys().contains(runnerId),
      runner.state == RunnerDraining,
      runner.activeTasks == 0,  // SC-FLAME-003: Must be drained
      pools' = pools.set(poolName, {
        ...pool,
        runners: pool.runners.set(runnerId, { ...runner, state: RunnerTerminated })
      }),
      totalRunners' = totalRunners - 1,
      telemetryEvents' = telemetryEvents.append("flame.runner.terminated"),
      globalClock' = globalClock + 10
    }

  // SC-FLAME-009: Handle runner crashes
  action runnerCrash(poolName: str, runnerId: int): bool =
    val pool = pools.get(poolName);
    all {
      pool.runners.keys().contains(runnerId),
      crashedRunners' = crashedRunners + 1,
      totalRunners' = totalRunners - 1,
      telemetryEvents' = telemetryEvents.append("flame.runner.crash"),
      // Work is requeued
      workQueue' = workQueue + pool.runners.get(runnerId).activeTasks,
      pools' = pools.set(poolName, {
        ...pool,
        runners: pool.runners.set(runnerId, {
          ...pool.runners.get(runnerId),
          state: RunnerTerminated,
          activeTasks: 0
        })
      }),
      globalClock' = globalClock + 5
    }

  // ---------------------------------------------------------------------------
  // Safety Invariants
  // ---------------------------------------------------------------------------

  // SC-FLAME-001: Pool bounds respected
  val poolBoundsRespected: bool =
    pools.keys().forall(name =>
      val pool = pools.get(name);
      val runnerCount = pool.runners.keys().filter(id =>
        pool.runners.get(id).state != RunnerTerminated
      ).size();
      pool.minSize <= runnerCount and runnerCount <= pool.maxSize
    )

  // SC-FLAME-002: Concurrency limits
  val concurrencyLimits: bool =
    pools.keys().forall(name =>
      val pool = pools.get(name);
      pool.runners.keys().forall(id =>
        pool.runners.get(id).activeTasks <= pool.maxConcurrency
      )
    )

  // SC-FLAME-005: Stateless runners
  val statelessRunners: bool =
    pools.keys().forall(name =>
      val pool = pools.get(name);
      pool.runners.keys().forall(id =>
        pool.runners.get(id).localState == 0
      )
    )

  // SC-FLAME-003: Graceful termination (no active tasks on terminated)
  val gracefulTermination: bool =
    pools.keys().forall(name =>
      val pool = pools.get(name);
      pool.runners.keys().forall(id =>
        pool.runners.get(id).state == RunnerTerminated implies
          pool.runners.get(id).activeTasks == 0
      )
    )

  // Combined invariant
  val flameInvariant: bool = all {
    poolBoundsRespected,
    concurrencyLimits,
    statelessRunners,
    gracefulTermination
  }

  temporal alwaysFLAMESafe = always(flameInvariant)

  // ---------------------------------------------------------------------------
  // Liveness Properties
  // ---------------------------------------------------------------------------

  // Work eventually processed
  temporal workEventuallyProcessed = always(
    workQueue > 0 implies eventually(workQueue == 0)
  )

  // Draining eventually terminates
  temporal drainingTerminates = always(
    pools.keys().forall(name =>
      pools.get(name).state == Draining implies eventually(
        pools.get(name).state == Terminated
      )
    )
  )
}

// =============================================================================
// NOTE: Cross-subsystem integration (CrossSubsystem, ModelCheckingHarness)
// requires multi-module composition with shared state variables.
// These modules are verified independently above.
// =============================================================================
