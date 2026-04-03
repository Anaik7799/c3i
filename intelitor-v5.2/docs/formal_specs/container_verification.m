(* ============================================================================= *)
(* INTELITOR CONTAINER VERIFICATION - MATHEMATICA FORMAL SPECIFICATION          *)
(* ============================================================================= *)
(* Version: 1.0.0                                                                *)
(* Framework: SOPv5.11 + STAMP + TDG + AOR                                       *)
(* Compliance: IEC 61508 SIL-2, EN 50131                                         *)
(* Container: NixOS + Elixir 1.19.2 + OTP 28                                     *)
(* ============================================================================= *)

(* ----------------------------------------------------------------------------- *)
(* §CNT.1 TYPE UNIVERSE FOR CONTAINER VERIFICATION                               *)
(* ----------------------------------------------------------------------------- *)

ContainerTypeUniverse = Module[{},
  (* Base Types *)
  ContainerTypes = <|
    "Version" -> <|"Major" -> Nat, "Minor" -> Nat, "Patch" -> Nat|>,
    "Runtime" -> {"Elixir", "Erlang", "ERTS"},
    "Registry" -> {"localhost", "dockerhub", "external"},
    "ContainerOS" -> {"nixos", "alpine", "debian", "ubuntu"},
    "HealthStatus" -> {"healthy", "unhealthy", "starting", "unknown"}
  |>;

  (* Composite Types *)
  ContainerConfig = <|
    "image" -> String,
    "runtime" -> String,
    "registry" -> String,
    "os" -> String,
    "versions" -> Association,
    "environment" -> Association,
    "labels" -> Association,
    "ports" -> List,
    "volumes" -> List
  |>;

  (* Verification Result Type *)
  VerificationResult = <|
    "component" -> String,
    "status" -> {"pass", "fail", "skip"},
    "details" -> String,
    "timestamp" -> DateTime,
    "stamp_constraint" -> String
  |>;

  <|"Base" -> ContainerTypes, "Composite" -> ContainerConfig, "Result" -> VerificationResult|>
]

(* ----------------------------------------------------------------------------- *)
(* §CNT.2 CONTAINER VERSION AXIOMS                                               *)
(* ----------------------------------------------------------------------------- *)

(* Axiom CNT-V1: Elixir Version Requirement *)
AxiomCNT_V1 := Module[{elixir = ElixirVersion},
  elixir["Major"] == 1 ∧ elixir["Minor"] == 19 ∧ elixir["Patch"] >= 2
]

(* Axiom CNT-V2: OTP Version Requirement *)
AxiomCNT_V2 := Module[{otp = OTPVersion},
  otp["Major"] == 28
]

(* Axiom CNT-V3: ERTS Version Consistency *)
AxiomCNT_V3 := Module[{erts = ERTSVersion},
  erts["Major"] == 16 ∧ erts["Minor"] == 1
]

(* Axiom CNT-V4: Compilation Consistency *)
AxiomCNT_V4 := CompiledWith[Elixir, OTP] == OTPVersion["Major"]

(* Version Constraint Set *)
VersionConstraints := {AxiomCNT_V1, AxiomCNT_V2, AxiomCNT_V3, AxiomCNT_V4}

(* ----------------------------------------------------------------------------- *)
(* §CNT.3 STAMP SAFETY CONSTRAINTS FOR CONTAINERS                                *)
(* ----------------------------------------------------------------------------- *)

(* Category B: Container Safety - Extended for Verification *)
SC_CNT_VERIFICATION := <|
  "SC-CNT-009" -> <|
    "Description" -> "System SHALL execute ALL operations within NixOS containers",
    "Predicate" -> (ContainerOS == "nixos"),
    "Verification" -> "echo $CONTAINER_OS",
    "ExpectedValue" -> "nixos",
    "Severity" -> "CRITICAL"
  |>,

  "SC-CNT-010" -> <|
    "Description" -> "System SHALL use ONLY localhost/ registry",
    "Predicate" -> StartsWith[ImageRegistry, "localhost/"],
    "Verification" -> "podman inspect --format '{{.Image}}'",
    "ExpectedPattern" -> "^localhost/",
    "Severity" -> "CRITICAL"
  |>,

  "SC-CNT-011" -> <|
    "Description" -> "System SHALL maintain PHICS v2.1 <50ms synchronization",
    "Predicate" -> PHICSEnabled ∧ PHICSLatency < 50,
    "Verification" -> "echo $PHICS_ENABLED",
    "ExpectedValue" -> "true",
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-012" -> <|
    "Description" -> "System SHALL enforce rootless container execution",
    "Predicate" -> RootlessMode == True,
    "Verification" -> "podman info --format '{{.Host.Security.Rootless}}'",
    "ExpectedValue" -> "true",
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-013" -> <|
    "Description" -> "System SHALL validate container health before operations",
    "Predicate" -> HealthCheckPassed == True,
    "Verification" -> "curl -f http://localhost:4000/health",
    "ExpectedStatus" -> 200,
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-014" -> <|
    "Description" -> "System SHALL maintain resource isolation",
    "Predicate" -> ResourceLimitsEnforced == True,
    "Verification" -> "podman inspect --format '{{.HostConfig.Memory}}'",
    "ExpectedRange" -> {0, 4 * 1024 * 1024 * 1024},  (* 4GB *)
    "Severity" -> "MEDIUM"
  |>,

  "SC-CNT-V01" -> <|
    "Description" -> "Container SHALL have Elixir 1.19.2",
    "Predicate" -> AxiomCNT_V1,
    "Verification" -> "elixir --version",
    "ExpectedPattern" -> "Elixir 1.19.2",
    "Severity" -> "CRITICAL"
  |>,

  "SC-CNT-V02" -> <|
    "Description" -> "Container SHALL have OTP 28",
    "Predicate" -> AxiomCNT_V2,
    "Verification" -> "elixir --version",
    "ExpectedPattern" -> "Erlang/OTP 28",
    "Severity" -> "CRITICAL"
  |>,

  "SC-CNT-V03" -> <|
    "Description" -> "Container SHALL have correct ERTS",
    "Predicate" -> AxiomCNT_V3,
    "Verification" -> "elixir --version",
    "ExpectedPattern" -> "erts-16.1",
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-PKG01" -> <|
    "Description" -> "Container SHALL have git installed",
    "Predicate" -> PackageInstalled["git"],
    "Verification" -> "which git",
    "ExpectedExitCode" -> 0,
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-PKG02" -> <|
    "Description" -> "Container SHALL have curl installed",
    "Predicate" -> PackageInstalled["curl"],
    "Verification" -> "which curl",
    "ExpectedExitCode" -> 0,
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-PKG03" -> <|
    "Description" -> "Container SHALL have PostgreSQL client",
    "Predicate" -> PackageInstalled["psql"],
    "Verification" -> "which psql",
    "ExpectedExitCode" -> 0,
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-SSL01" -> <|
    "Description" -> "Container SHALL have CA certificates",
    "Predicate" -> FileExists["/etc/ssl/certs/ca-bundle.crt"],
    "Verification" -> "test -f /etc/ssl/certs/ca-bundle.crt",
    "ExpectedExitCode" -> 0,
    "Severity" -> "CRITICAL"
  |>,

  "SC-CNT-ENV01" -> <|
    "Description" -> "Container SHALL have NO_TIMEOUT=true",
    "Predicate" -> EnvVar["NO_TIMEOUT"] == "true",
    "Verification" -> "echo $NO_TIMEOUT",
    "ExpectedValue" -> "true",
    "Severity" -> "HIGH"
  |>,

  "SC-CNT-LBL01" -> <|
    "Description" -> "Container SHALL have SOPv5.11 compliant label",
    "Predicate" -> Label["org.intelitor.sopv51"] == "compliant",
    "Verification" -> "podman inspect --format '{{index .Config.Labels \"org.intelitor.sopv51\"}}'",
    "ExpectedValue" -> "compliant",
    "Severity" -> "MEDIUM"
  |>
|>

(* ----------------------------------------------------------------------------- *)
(* §CNT.4 TDG RULES FOR CONTAINER TESTING                                        *)
(* ----------------------------------------------------------------------------- *)

(* Test-Driven Generation Rules for Container Verification *)
TDG_CONTAINER := <|
  "TDG-CNT-001" -> <|
    "Rule" -> O[Agent, ContainerTest ⟹ PrecedesContainerBuild],
    "Description" -> "Container tests MUST be written before container image is built",
    "Enforcement" -> "CI/CD pipeline order"
  |>,

  "TDG-CNT-002" -> <|
    "Rule" -> O[Agent, VersionChange ⟹ UpdateVerificationTests],
    "Description" -> "Version changes MUST trigger test updates first",
    "Enforcement" -> "Pre-commit hook"
  |>,

  "TDG-CNT-003" -> <|
    "Rule" -> O[Agent, NewPackage ⟹ AddPackageTest],
    "Description" -> "New packages in container MUST have availability tests",
    "Enforcement" -> "Test coverage check"
  |>,

  "TDG-CNT-004" -> <|
    "Rule" -> O[Agent, STAMPConstraint ⟹ HasExUnitTest],
    "Description" -> "Every STAMP constraint MUST have corresponding ExUnit test",
    "Enforcement" -> "STAMP-test mapping validation"
  |>,

  "TDG-CNT-005" -> <|
    "Rule" -> O[Agent, HealthCheck ⟹ TestBeforeDeploy],
    "Description" -> "Health checks MUST pass in test before deployment",
    "Enforcement" -> "Deployment gate"
  |>,

  "TDG-CNT-006" -> <|
    "Rule" -> O[Agent, ContainerLabel ⟹ HasLabelTest],
    "Description" -> "Container labels MUST have verification tests",
    "Enforcement" -> "Label test coverage"
  |>,

  "TDG-CNT-007" -> <|
    "Rule" -> F[Agent, DeployWithoutTest],
    "Description" -> "Container deployment FORBIDDEN without passing tests",
    "Enforcement" -> "CI/CD gate"
  |>,

  "TDG-CNT-008" -> <|
    "Rule" -> O[Agent, SSLConfig ⟹ TestCertificates],
    "Description" -> "SSL configuration MUST have certificate tests",
    "Enforcement" -> "Security test suite"
  |>
|>

(* TDG Workflow for Containers *)
TDGContainerWorkflow := {
  "1. WRITE_TESTS" -> "Create ExUnit tests for container properties",
  "2. RUN_RED" -> "Run tests (should fail - no container yet)",
  "3. BUILD_CONTAINER" -> "Build NixOS container with nix-build",
  "4. RUN_GREEN" -> "Run tests (should pass)",
  "5. VERIFY_STAMPS" -> "Verify all STAMP constraints pass",
  "6. DEPLOY" -> "Deploy to registry"
}

(* ----------------------------------------------------------------------------- *)
(* §CNT.5 AOR RULES FOR CONTAINER OPERATIONS                                     *)
(* ----------------------------------------------------------------------------- *)

(* Agent Operating Rules for Container Management *)
AOR_CONTAINER := <|
  "AOR-CNT-001" -> <|
    "Rule" -> F[Agent, UseDocker] ∧ O[Agent, UsePodman],
    "Description" -> "Docker FORBIDDEN, Podman REQUIRED",
    "Enforcement" -> "Runtime check, CONTAINER_POLICY.md"
  |>,

  "AOR-CNT-002" -> <|
    "Rule" -> O[Agent, ContainerBuild ⟹ UseNixBuild],
    "Description" -> "Container builds MUST use nix-build",
    "Enforcement" -> "Build script validation"
  |>,

  "AOR-CNT-003" -> <|
    "Rule" -> O[Agent, ImageTag ⟹ IncludeGitRevision],
    "Description" -> "Image tags MUST include git revision",
    "Enforcement" -> "Tag format validation"
  |>,

  "AOR-CNT-004" -> <|
    "Rule" -> O[Agent, ContainerStart ⟹ WaitForHealthy],
    "Description" -> "Container start MUST wait for healthy status",
    "Enforcement" -> "Health check timeout"
  |>,

  "AOR-CNT-005" -> <|
    "Rule" -> O[Agent, ContainerNetwork ⟹ UseDefinedSubnet],
    "Description" -> "Containers MUST use defined network subnet",
    "Enforcement" -> "Network configuration validation"
  |>,

  "AOR-CNT-006" -> <|
    "Rule" -> O[Agent, ContainerVolume ⟹ UseSELinuxLabels],
    "Description" -> "Volume mounts MUST use SELinux labels (:z)",
    "Enforcement" -> "Volume mount validation"
  |>,

  "AOR-CNT-007" -> <|
    "Rule" -> F[Agent, ExternalRegistry],
    "Description" -> "External registries FORBIDDEN",
    "Enforcement" -> "Registry source validation"
  |>,

  "AOR-CNT-008" -> <|
    "Rule" -> O[Agent, ResourceLimit ⟹ Define[Memory, CPU]],
    "Description" -> "Resource limits MUST be defined",
    "Enforcement" -> "Compose file validation"
  |>,

  "AOR-CNT-009" -> <|
    "Rule" -> O[Agent, ContainerLog ⟹ StreamToFile],
    "Description" -> "Container logs MUST stream to file",
    "Enforcement" -> "Logging configuration"
  |>,

  "AOR-CNT-010" -> <|
    "Rule" -> O[Agent, VersionUpdate ⟹ RebuildContainer],
    "Description" -> "Version updates REQUIRE container rebuild",
    "Enforcement" -> "Version-build dependency"
  |>,

  "AOR-CNT-011" -> <|
    "Rule" -> O[Agent, PHICSConfig ⟹ ValidateLatency],
    "Description" -> "PHICS configuration MUST validate latency <50ms",
    "Enforcement" -> "Latency test"
  |>,

  "AOR-CNT-012" -> <|
    "Rule" -> O[Agent, ContainerChaos ⟹ TestRecovery],
    "Description" -> "Chaos conditions MUST test recovery",
    "Enforcement" -> "Chaos test suite"
  |>
|>

(* ----------------------------------------------------------------------------- *)
(* §CNT.6 CORTEX HEALTH VERIFICATION PROTOCOL                                    *)
(* ----------------------------------------------------------------------------- *)

(* Cortex Container Health Check Protocol *)
CortexContainerProtocol := <|
  "HealthCheckPhases" -> <|
    "Phase1_VersionVerification" -> <|
      "Checks" -> {"elixir_version", "otp_version", "erts_version"},
      "Timeout" -> 5000,  (* ms *)
      "Required" -> True,
      "OnFailure" -> "HALT_STARTUP"
    |>,

    "Phase2_PackageVerification" -> <|
      "Checks" -> {"git", "curl", "psql", "redis-cli", "node"},
      "Timeout" -> 10000,
      "Required" -> True,
      "OnFailure" -> "LOG_AND_CONTINUE"
    |>,

    "Phase3_EnvironmentVerification" -> <|
      "Checks" -> {"CONTAINER_OS", "PHICS_ENABLED", "NO_TIMEOUT"},
      "Timeout" -> 2000,
      "Required" -> True,
      "OnFailure" -> "HALT_STARTUP"
    |>,

    "Phase4_NetworkVerification" -> <|
      "Checks" -> {"port_bindings", "dns_resolution", "epmd_available"},
      "Timeout" -> 5000,
      "Required" -> True,
      "OnFailure" -> "LOG_AND_CONTINUE"
    |>,

    "Phase5_SSLVerification" -> <|
      "Checks" -> {"ca_certificates", "ssl_application", "crypto_application"},
      "Timeout" -> 3000,
      "Required" -> True,
      "OnFailure" -> "LOG_AND_CONTINUE"
    |>,

    "Phase6_PHICSVerification" -> <|
      "Checks" -> {"inotify_tools", "file_watch_limit", "phics_marker"},
      "Timeout" -> 2000,
      "Required" -> False,
      "OnFailure" -> "LOG_WARNING"
    |>,

    "Phase7_STAMPVerification" -> <|
      "Checks" -> Keys[SC_CNT_VERIFICATION],
      "Timeout" -> 30000,
      "Required" -> True,
      "OnFailure" -> "HALT_STARTUP"
    |>
  |>,

  "VerificationOrder" -> {
    "Phase1_VersionVerification",
    "Phase2_PackageVerification",
    "Phase3_EnvironmentVerification",
    "Phase4_NetworkVerification",
    "Phase5_SSLVerification",
    "Phase6_PHICSVerification",
    "Phase7_STAMPVerification"
  },

  "TotalTimeout" -> 60000,  (* 60 seconds max *)

  "ResultActions" -> <|
    "ALL_PASS" -> "STARTUP_PROCEED",
    "REQUIRED_FAIL" -> "STARTUP_ABORT",
    "OPTIONAL_FAIL" -> "STARTUP_PROCEED_WITH_WARNINGS"
  |>
|>

(* Cortex Health Check State Machine *)
CortexHealthStates := {"Initializing", "Verifying", "Healthy", "Degraded", "Failed"}

CortexHealthTransitions := <|
  {"Initializing", "start_verification"} -> "Verifying",
  {"Verifying", "all_checks_pass"} -> "Healthy",
  {"Verifying", "required_check_fails"} -> "Failed",
  {"Verifying", "optional_check_fails"} -> "Degraded",
  {"Healthy", "periodic_check_fails"} -> "Degraded",
  {"Degraded", "recovery_succeeds"} -> "Healthy",
  {"Degraded", "critical_failure"} -> "Failed"
|>

(* ----------------------------------------------------------------------------- *)
(* §CNT.7 LTL TEMPORAL PROPERTIES FOR CONTAINER LIFECYCLE                        *)
(* ----------------------------------------------------------------------------- *)

(* Container Lifecycle Temporal Properties *)
ContainerLTLProperties := {
  (* LTL-CNT-1: Health verification always precedes operation *)
  □[ContainerOperation ⟹ PrecededBy[HealthCheck]],

  (* LTL-CNT-2: Version mismatch triggers rebuild *)
  □[VersionMismatch ⟹ ◇[ContainerRebuild]],

  (* LTL-CNT-3: Failed health check triggers alert *)
  □[HealthCheckFailed ⟹ ◇[AlertTriggered, δ < 5s]],

  (* LTL-CNT-4: Container always restarts on failure *)
  □[ContainerCrash ⟹ ◇[ContainerRestart]],

  (* LTL-CNT-5: STAMP violation halts operations *)
  □[STAMPViolation ⟹ ¬ContainerOperation U STAMPResolved],

  (* LTL-CNT-6: Graceful shutdown always drains connections *)
  □[ShutdownRequested ⟹ (ConnectionDraining U ContainerStopped)],

  (* LTL-CNT-7: Registry compliance is always maintained *)
  □[ImagePull ⟹ LocalhostRegistry],

  (* LTL-CNT-8: PHICS synchronization within latency bounds *)
  □[PHICSSync ⟹ Latency < 50]
}

(* ----------------------------------------------------------------------------- *)
(* §CNT.8 VERIFICATION COVERAGE MATRIX                                           *)
(* ----------------------------------------------------------------------------- *)

(* Verification Coverage Requirements *)
VerificationCoverage := <|
  "VersionVerification" -> <|
    "Tests" -> 18,
    "STAMPConstraints" -> {"SC-CNT-V01", "SC-CNT-V02", "SC-CNT-V03"},
    "Coverage" -> 100
  |>,

  "PackageVerification" -> <|
    "Tests" -> 15,
    "STAMPConstraints" -> {"SC-CNT-PKG01", "SC-CNT-PKG02", "SC-CNT-PKG03"},
    "Coverage" -> 100
  |>,

  "EnvironmentVerification" -> <|
    "Tests" -> 12,
    "STAMPConstraints" -> {"SC-CNT-009", "SC-CNT-ENV01"},
    "Coverage" -> 100
  |>,

  "SSLVerification" -> <|
    "Tests" -> 8,
    "STAMPConstraints" -> {"SC-CNT-SSL01"},
    "Coverage" -> 100
  |>,

  "FilesystemVerification" -> <|
    "Tests" -> 10,
    "STAMPConstraints" -> {"SC-CNT-014"},
    "Coverage" -> 100
  |>,

  "LabelVerification" -> <|
    "Tests" -> 8,
    "STAMPConstraints" -> {"SC-CNT-LBL01"},
    "Coverage" -> 100
  |>,

  "NetworkVerification" -> <|
    "Tests" -> 8,
    "STAMPConstraints" -> {},
    "Coverage" -> 100
  |>,

  "PHICSVerification" -> <|
    "Tests" -> 6,
    "STAMPConstraints" -> {"SC-CNT-011"},
    "Coverage" -> 100
  |>,

  "SecurityVerification" -> <|
    "Tests" -> 10,
    "STAMPConstraints" -> {"SC-CNT-012"},
    "Coverage" -> 100
  |>,

  "STAMPVerification" -> <|
    "Tests" -> 6,
    "STAMPConstraints" -> Keys[SC_CNT_VERIFICATION],
    "Coverage" -> 100
  |>,

  "ElixirReadiness" -> <|
    "Tests" -> 8,
    "STAMPConstraints" -> {},
    "Coverage" -> 100
  |>
|>

(* Total Test Count *)
TotalContainerTests := Total[#["Tests"] & /@ Values[VerificationCoverage]]
(* Expected: 109 tests *)

(* ----------------------------------------------------------------------------- *)
(* §CNT.9 FORMAL VERIFICATION ASSERTIONS                                         *)
(* ----------------------------------------------------------------------------- *)

(* Master Container Validity Predicate *)
ContainerValid[C_] :=
  AxiomCNT_V1 ∧ AxiomCNT_V2 ∧ AxiomCNT_V3 ∧ AxiomCNT_V4 ∧
  (∀ sc ∈ Keys[SC_CNT_VERIFICATION] : Satisfied[sc, C]) ∧
  (∀ aor ∈ Keys[AOR_CONTAINER] : Compliant[aor, C]) ∧
  (∀ φ ∈ ContainerLTLProperties : □[φ])

(* Forbidden Actions for Containers *)
ForbiddenContainerActions := {
  "docker_usage",
  "alpine_images",
  "external_registry",
  "root_execution",
  "unverified_deployment",
  "skipped_health_checks",
  "missing_labels",
  "incorrect_versions"
}

(* Document Metadata *)
DocumentMetadata := <|
  "Title" -> "Container Verification Formal Specification",
  "Version" -> "1.0.0",
  "Date" -> "2025-12-18",
  "Framework" -> "SOPv5.11 + STAMP + TDG + AOR",
  "Compliance" -> {"IEC 61508 SIL-2", "EN 50131"},
  "TotalTests" -> TotalContainerTests,
  "STAMPConstraints" -> Length[SC_CNT_VERIFICATION],
  "TDGRules" -> Length[TDG_CONTAINER],
  "AORRules" -> Length[AOR_CONTAINER]
|>
