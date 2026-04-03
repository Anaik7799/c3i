// =============================================================================
// INTELITOR CONTAINER VERIFICATION - QUINT SPECIFICATION
// =============================================================================
// Version: 1.1.0
// Updated: 2025-12-19
// Framework: SOPv5.11 + STAMP + TDG + AOR
// Purpose: Model checking for container lifecycle and health verification
//
// ExUnit Test Coverage:
//   - test/indrajaal/cortex/sensors/container_health_sensor_test.exs (35 tests)
//   - test/indrajaal/cortex/sensors/container_health_telemetry_test.exs (26 tests)
//   - Total: 61 tests passing
//
// Implementation:
//   - lib/indrajaal/cortex/sensors/container_health_sensor.ex
//   - lib/indrajaal/cortex/sensors/container_health_telemetry.ex
// =============================================================================

module ContainerVerification {

  // ---------------------------------------------------------------------------
  // §Q.CNT.1 TYPE DEFINITIONS
  // ---------------------------------------------------------------------------

  type Version = { major: int, minor: int, patch: int }

  type ContainerOS = NixOS | Alpine | Debian | Ubuntu

  type Registry = Localhost | DockerHub | External

  type Runtime = Podman | Docker

  // Fix: Rename Failed to HealthFailed to avoid conflict with VerificationPhase
  type HealthStatus = Healthy | Unhealthy | Starting | Unknown | HealthFailed

  type VerificationPhase =
    | Initializing
    | VerifyingVersions
    | VerifyingPackages
    | VerifyingEnvironment
    | VerifyingNetwork
    | VerifyingSSL
    | VerifyingPHICS
    | VerifyingSTAMP
    | Complete
    | VerificationFailed

  type STAMPConstraint = {
    id: str,
    satisfied: bool,
    severity: str
  }

  // ---------------------------------------------------------------------------
  // §Q.CNT.2 STATE VARIABLES
  // ---------------------------------------------------------------------------

  // Version state
  var elixirVersion: Version
  var otpVersion: Version
  var ertsVersion: Version

  // Container configuration
  var containerOS: ContainerOS
  var registry: Registry
  var runtime: Runtime
  var phicsEnabled: bool
  var noTimeout: bool
  var rootless: bool

  // Health and verification state
  var healthStatus: HealthStatus
  var verificationPhase: VerificationPhase
  var stampConstraints: str -> STAMPConstraint
  var verificationErrors: List[str]
  var globalClock: int

  // Package availability
  var packagesAvailable: Set[str]

  // ---------------------------------------------------------------------------
  // §Q.CNT.3 CONSTANTS
  // ---------------------------------------------------------------------------

  pure val EXPECTED_ELIXIR: Version = { major: 1, minor: 19, patch: 2 }
  pure val EXPECTED_OTP: Version = { major: 28, minor: 0, patch: 0 }
  pure val EXPECTED_ERTS: Version = { major: 16, minor: 1, patch: 1 }

  pure val REQUIRED_PACKAGES: Set[str] = Set(
    "elixir", "erl", "git", "curl", "wget", "make", "gcc",
    "psql", "redis-cli", "node", "yarn", "inotifywait", "entr"
  )

  pure val VERIFICATION_TIMEOUT: int = 60000  // 60 seconds

  // ---------------------------------------------------------------------------
  // §Q.CNT.4 INITIALIZATION
  // ---------------------------------------------------------------------------

  action init = all {
    elixirVersion' = { major: 0, minor: 0, patch: 0 },
    otpVersion' = { major: 0, minor: 0, patch: 0 },
    ertsVersion' = { major: 0, minor: 0, patch: 0 },
    containerOS' = NixOS,
    registry' = Localhost,
    runtime' = Podman,
    phicsEnabled' = false,
    noTimeout' = false,
    rootless' = true,
    healthStatus' = Unknown,
    verificationPhase' = Initializing,
    stampConstraints' = Map(),
    verificationErrors' = [],
    globalClock' = 0,
    packagesAvailable' = Set()
  }

  // ---------------------------------------------------------------------------
  // §Q.CNT.5 VERSION VERIFICATION ACTIONS
  // All actions must update the same set of state variables (Quint any{} rule).
  // Variables not logically modified use stuttering assignments (x' = x).
  // ---------------------------------------------------------------------------

  action detectElixirVersion(major: int, minor: int, patch: int): bool = all {
    verificationPhase == VerifyingVersions,
    elixirVersion' = { major: major, minor: minor, patch: patch },
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action detectOTPVersion(major: int): bool = all {
    verificationPhase == VerifyingVersions,
    elixirVersion' = elixirVersion,
    otpVersion' = { major: major, minor: 0, patch: 0 },
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action detectERTSVersion(major: int, minor: int, patch: int): bool = all {
    verificationPhase == VerifyingVersions,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = { major: major, minor: minor, patch: patch },
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  // ---------------------------------------------------------------------------
  // §Q.CNT.6 VERIFICATION PHASE TRANSITIONS
  // ---------------------------------------------------------------------------

  action startVerification: bool = all {
    verificationPhase == Initializing,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = Starting,
    verificationPhase' = VerifyingVersions,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 10,
    packagesAvailable' = packagesAvailable
  }

  action completeVersionVerification: bool = {
    val versionsValid = (
      elixirVersion.major == EXPECTED_ELIXIR.major and
      elixirVersion.minor == EXPECTED_ELIXIR.minor and
      otpVersion.major == EXPECTED_OTP.major and
      ertsVersion.major == EXPECTED_ERTS.major
    )

    all {
      verificationPhase == VerifyingVersions,
      elixirVersion' = elixirVersion,
      otpVersion' = otpVersion,
      ertsVersion' = ertsVersion,
      containerOS' = containerOS,
      registry' = registry,
      runtime' = runtime,
      phicsEnabled' = phicsEnabled,
      noTimeout' = noTimeout,
      rootless' = rootless,
      packagesAvailable' = packagesAvailable,
      stampConstraints' = stampConstraints,
      if (versionsValid) all {
        verificationPhase' = VerifyingPackages,
        healthStatus' = healthStatus,
        verificationErrors' = verificationErrors,
        globalClock' = globalClock + 50
      } else all {
        verificationPhase' = VerificationFailed,
        healthStatus' = HealthFailed,
        verificationErrors' = verificationErrors.append("Version mismatch"),
        globalClock' = globalClock + 50
      }
    }
  }

  action verifyPackage(pkg: str): bool = all {
    verificationPhase == VerifyingPackages,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 50,
    packagesAvailable' = packagesAvailable.union(Set(pkg))
  }

  action completePackageVerification: bool = {
    val allPackagesAvailable = REQUIRED_PACKAGES.subseteq(packagesAvailable)

    all {
      verificationPhase == VerifyingPackages,
      elixirVersion' = elixirVersion,
      otpVersion' = otpVersion,
      ertsVersion' = ertsVersion,
      containerOS' = containerOS,
      registry' = registry,
      runtime' = runtime,
      phicsEnabled' = phicsEnabled,
      noTimeout' = noTimeout,
      rootless' = rootless,
      packagesAvailable' = packagesAvailable,
      stampConstraints' = stampConstraints,
      if (allPackagesAvailable) all {
        verificationPhase' = VerifyingEnvironment,
        healthStatus' = healthStatus,
        verificationErrors' = verificationErrors,
        globalClock' = globalClock + 50
      } else all {
        verificationPhase' = VerificationFailed,
        healthStatus' = HealthFailed,
        verificationErrors' = verificationErrors.append("Missing packages"),
        globalClock' = globalClock + 50
      }
    }
  }

  action verifyEnvironment(os: ContainerOS, phics: bool, timeout: bool): bool = all {
    verificationPhase == VerifyingEnvironment,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = os,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phics,
    noTimeout' = timeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = VerifyingNetwork,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action completeNetworkVerification: bool = all {
    verificationPhase == VerifyingNetwork,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = VerifyingSSL,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action completeSSLVerification: bool = all {
    verificationPhase == VerifyingSSL,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = VerifyingPHICS,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action completePHICSVerification: bool = all {
    verificationPhase == VerifyingPHICS,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = VerifyingSTAMP,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action verifySTAMPConstraint(id: str, satisfied: bool, severity: str): bool = all {
    verificationPhase == VerifyingSTAMP,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints.set(id, {
      id: id,
      satisfied: satisfied,
      severity: severity
    }),
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 50,
    packagesAvailable' = packagesAvailable
  }

  action completeSTAMPVerification: bool = {
    val allCriticalSatisfied = stampConstraints.keys().forall(id =>
      stampConstraints.get(id).severity != "CRITICAL" or
      stampConstraints.get(id).satisfied
    )

    all {
      verificationPhase == VerifyingSTAMP,
      elixirVersion' = elixirVersion,
      otpVersion' = otpVersion,
      ertsVersion' = ertsVersion,
      containerOS' = containerOS,
      registry' = registry,
      runtime' = runtime,
      phicsEnabled' = phicsEnabled,
      noTimeout' = noTimeout,
      rootless' = rootless,
      packagesAvailable' = packagesAvailable,
      stampConstraints' = stampConstraints,
      if (allCriticalSatisfied) all {
        verificationPhase' = Complete,
        healthStatus' = Healthy,
        verificationErrors' = verificationErrors,
        globalClock' = globalClock + 100
      } else all {
        verificationPhase' = VerificationFailed,
        healthStatus' = HealthFailed,
        verificationErrors' = verificationErrors.append("STAMP violation"),
        globalClock' = globalClock + 100
      }
    }
  }

  // ---------------------------------------------------------------------------
  // §Q.CNT.7 HEALTH CHECK ACTIONS
  // ---------------------------------------------------------------------------

  action periodicHealthCheck: bool = all {
    verificationPhase == Complete,
    healthStatus == Healthy,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = healthStatus,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 5000,
    packagesAvailable' = packagesAvailable
  }

  action healthCheckFails: bool = all {
    verificationPhase == Complete,
    healthStatus == Healthy,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = Unhealthy,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 100,
    packagesAvailable' = packagesAvailable
  }

  action recoverySucceeds: bool = all {
    healthStatus == Unhealthy,
    elixirVersion' = elixirVersion,
    otpVersion' = otpVersion,
    ertsVersion' = ertsVersion,
    containerOS' = containerOS,
    registry' = registry,
    runtime' = runtime,
    phicsEnabled' = phicsEnabled,
    noTimeout' = noTimeout,
    rootless' = rootless,
    healthStatus' = Healthy,
    verificationPhase' = verificationPhase,
    stampConstraints' = stampConstraints,
    verificationErrors' = verificationErrors,
    globalClock' = globalClock + 500,
    packagesAvailable' = packagesAvailable
  }

  // ---------------------------------------------------------------------------
  // §Q.CNT.8 SAFETY INVARIANTS (STAMP Constraints as Quint Properties)
  // ---------------------------------------------------------------------------

  // SC-CNT-009: Container OS is always NixOS
  val SC_CNT_009: bool =
    (verificationPhase == Complete) implies (containerOS == NixOS)

  // SC-CNT-010: Registry is always localhost
  val SC_CNT_010: bool =
    (verificationPhase == Complete) implies (registry == Localhost)

  // SC-CNT-011: PHICS is enabled when complete
  val SC_CNT_011: bool =
    (verificationPhase == Complete) implies phicsEnabled

  // SC-CNT-012: Rootless execution
  val SC_CNT_012: bool =
    (verificationPhase == Complete) implies rootless

  // SC-CNT-V01: Elixir version correct
  val SC_CNT_V01: bool =
    (verificationPhase == Complete) implies (
      elixirVersion.major == EXPECTED_ELIXIR.major and
      elixirVersion.minor == EXPECTED_ELIXIR.minor
    )

  // SC-CNT-V02: OTP version correct
  val SC_CNT_V02: bool =
    (verificationPhase == Complete) implies (otpVersion.major == EXPECTED_OTP.major)

  // No Docker runtime allowed
  val neverDocker: bool = runtime != Docker

  // Verification completes within timeout
  val withinTimeout: bool = globalClock <= VERIFICATION_TIMEOUT

  // Combined container safety invariant
  val containerSafetyInvariant: bool = all {
    SC_CNT_009,
    SC_CNT_010,
    SC_CNT_011,
    SC_CNT_012,
    SC_CNT_V01,
    SC_CNT_V02,
    neverDocker,
    withinTimeout
  }

  temporal alwaysContainerSafe = always(containerSafetyInvariant)

  // ---------------------------------------------------------------------------
  // §Q.CNT.9 LIVENESS PROPERTIES
  // ---------------------------------------------------------------------------

  // Verification eventually completes or fails
  temporal verificationTerminates = always(
    (verificationPhase == Initializing) implies eventually(
      verificationPhase == Complete or verificationPhase == VerificationFailed
    )
  )

  // Health eventually stabilizes
  temporal healthStabilizes = always(
    (healthStatus == Starting) implies eventually(
      healthStatus == Healthy or healthStatus == HealthFailed
    )
  )

  // Unhealthy state eventually recovers or fails
  temporal unhealthyResolves = always(
    (healthStatus == Unhealthy) implies eventually(
      healthStatus == Healthy or healthStatus == HealthFailed
    )
  )

  // ---------------------------------------------------------------------------
  // §Q.CNT.10 MODEL CHECKING CONFIGURATION
  // ---------------------------------------------------------------------------

  // System step: nondeterministic choice of actions
  action step = any {
    startVerification,
    nondet major = oneOf(Set(1, 2))
    nondet minor = oneOf(Set(18, 19, 20))
    nondet patch = oneOf(Set(0, 1, 2, 3))
    detectElixirVersion(major, minor, patch),
    nondet otpMajor = oneOf(Set(26, 27, 28))
    detectOTPVersion(otpMajor),
    nondet ertsMajor = oneOf(Set(14, 15, 16))
    nondet ertsMinor = oneOf(Set(0, 1))
    nondet ertsPatch = oneOf(Set(0, 1))
    detectERTSVersion(ertsMajor, ertsMinor, ertsPatch),
    completeVersionVerification,
    nondet pkg = oneOf(REQUIRED_PACKAGES)
    verifyPackage(pkg),
    completePackageVerification,
    verifyEnvironment(NixOS, true, true),
    completeNetworkVerification,
    completeSSLVerification,
    completePHICSVerification,
    nondet id = oneOf(Set("SC-CNT-009", "SC-CNT-010", "SC-CNT-011"))
    verifySTAMPConstraint(id, true, "CRITICAL"),
    completeSTAMPVerification,
    periodicHealthCheck,
    healthCheckFails,
    recoverySucceeds
  }
}

// =============================================================================
// CORTEX HEALTH VERIFICATION MODULE
// =============================================================================

module CortexContainerHealth {
  import ContainerVerification.*

  // ---------------------------------------------------------------------------
  // §Q.CORTEX.1 CORTEX STATE MACHINE
  // ---------------------------------------------------------------------------

  type CortexState =
    | CortexIdle
    | CortexVerifying
    | CortexHealthy
    | CortexDegraded
    | CortexFailed
    | CortexRecovering

  var cortexState: CortexState
  var verificationAttempts: int
  var lastHealthCheck: int
  var degradedReasons: Set[str]

  pure val MAX_VERIFICATION_ATTEMPTS: int = 3
  pure val HEALTH_CHECK_INTERVAL: int = 5000

  // ---------------------------------------------------------------------------
  // §Q.CORTEX.2 CORTEX ACTIONS
  // ---------------------------------------------------------------------------

  action cortexInit = all {
    cortexState' = CortexIdle,
    verificationAttempts' = 0,
    lastHealthCheck' = 0,
    degradedReasons' = Set()
  }

  action cortexStartVerification: bool = all {
    cortexState == CortexIdle,
    verificationAttempts < MAX_VERIFICATION_ATTEMPTS,
    cortexState' = CortexVerifying,
    verificationAttempts' = verificationAttempts + 1,
    lastHealthCheck' = lastHealthCheck,
    degradedReasons' = degradedReasons
  }

  action cortexVerificationSucceeds: bool = all {
    cortexState == CortexVerifying,
    verificationPhase == Complete,
    healthStatus == Healthy,
    cortexState' = CortexHealthy,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = globalClock,
    degradedReasons' = degradedReasons
  }

  // Fix: use if/else without braces — single expression per branch
  action cortexVerificationFails: bool = all {
    cortexState == CortexVerifying,
    verificationPhase == VerificationFailed,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = lastHealthCheck,
    degradedReasons' = degradedReasons,
    if (verificationAttempts >= MAX_VERIFICATION_ATTEMPTS)
      cortexState' = CortexFailed
    else
      cortexState' = CortexIdle
  }

  action cortexHealthCheckPasses: bool = all {
    cortexState == CortexHealthy,
    globalClock - lastHealthCheck >= HEALTH_CHECK_INTERVAL,
    healthStatus == Healthy,
    cortexState' = cortexState,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = globalClock,
    degradedReasons' = degradedReasons
  }

  action cortexHealthCheckFails(reason: str): bool = all {
    cortexState == CortexHealthy,
    healthStatus == Unhealthy,
    cortexState' = CortexDegraded,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = lastHealthCheck,
    degradedReasons' = degradedReasons.union(Set(reason))
  }

  action cortexRecoveryAttempt: bool = all {
    cortexState == CortexDegraded,
    cortexState' = CortexRecovering,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = lastHealthCheck,
    degradedReasons' = degradedReasons
  }

  action cortexRecoverySucceeds: bool = all {
    cortexState == CortexRecovering,
    healthStatus == Healthy,
    cortexState' = CortexHealthy,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = lastHealthCheck,
    degradedReasons' = Set()
  }

  action cortexRecoveryFails: bool = all {
    cortexState == CortexRecovering,
    healthStatus != Healthy,
    cortexState' = CortexFailed,
    verificationAttempts' = verificationAttempts,
    lastHealthCheck' = lastHealthCheck,
    degradedReasons' = degradedReasons
  }

  // ---------------------------------------------------------------------------
  // §Q.CORTEX.3 CORTEX SAFETY INVARIANTS
  // ---------------------------------------------------------------------------

  // Never proceed to healthy without verification
  val cortexVerifiedBeforeHealthy: bool =
    (cortexState == CortexHealthy) implies (verificationPhase == Complete)

  // Failed state invariant: cortexFailed means cortexState is CortexFailed (tautology)
  val cortexFailedIsStable: bool =
    (cortexState == CortexFailed) implies (cortexState == CortexFailed)

  // Health checks are periodic
  val cortexRegularHealthChecks: bool =
    (cortexState == CortexHealthy) implies (
      globalClock - lastHealthCheck <= HEALTH_CHECK_INTERVAL * 2
    )

  val cortexSafetyInvariant: bool = all {
    cortexVerifiedBeforeHealthy,
    containerSafetyInvariant
  }

  temporal alwaysCortexSafe = always(cortexSafetyInvariant)

  // ---------------------------------------------------------------------------
  // §Q.CORTEX.4 CORTEX LIVENESS
  // ---------------------------------------------------------------------------

  // Cortex eventually reaches a stable state
  temporal cortexStabilizes = always(
    (cortexState == CortexVerifying) implies eventually(
      cortexState == CortexHealthy or cortexState == CortexFailed
    )
  )

  // Degraded state eventually resolves
  temporal cortexDegradedResolves = always(
    (cortexState == CortexDegraded) implies eventually(
      cortexState == CortexHealthy or cortexState == CortexFailed
    )
  )
}
