# Phase 7: Startup Performance Optimization Feature
# Version: 21.2.1-SIL6
# Created: 2026-01-18
# STAMP Constraints: SC-OPT-001 to SC-OPT-010, SC-CONSOL-001 to SC-CONSOL-010
# AOR Rules: AOR-OPT-001 to AOR-OPT-008

@startup @performance @sil6 @critical
Feature: Phase 7 Startup Performance Optimization
  As a SIL-6 biomorphic system
  I need optimized startup performance with pre-compiled BEAM, parallel waves, and unified configuration
  So that boot time is < 30s, PHICS latency < 50ms, and all 7 fractal layers are verified

  ## STAMP Constraints Coverage
  # SC-OPT-001: Pre-compiled BEAM image MUST exist before deployment
  # SC-OPT-002: Boot time MUST be < 30s from cold start
  # SC-OPT-003: PHICS latency MUST be < 50ms (p99)
  # SC-OPT-004: Health check MUST respond < 500ms
  # SC-OPT-005: Pre-compiled BEAM MUST NOT recompile at runtime
  # SC-OPT-006: Wave parallelization MUST achieve >50% time reduction
  # SC-OPT-007: BEAM cache MUST persist across container restarts
  # SC-OPT-008: Performance telemetry MUST publish to Zenoh
  # SC-OPT-009: Quorum MUST form < 10s after W3 start
  # SC-OPT-010: All 7 fractal layers MUST verify during boot
  # SC-CONSOL-001: ComposeGenerator MUST produce valid YAML
  # SC-CONSOL-002: ComposeGenerator MUST include all 15 containers
  # SC-CONSOL-003: ComposeGenerator MUST be deterministic
  # SC-CONSOL-004: ComposeGenerator MUST validate against schema
  # SC-CONSOL-005: ConfigBridge MUST sync F# to Elixir config
  # SC-CONSOL-006: ConfigBridge MUST detect drift
  # SC-CONSOL-007: ConfigBridge MUST publish to Zenoh
  # SC-CONSOL-008: ConfigBridge MUST support hot reload
  # SC-CONSOL-009: Config changes MUST trigger validation
  # SC-CONSOL-010: Config drift MUST trigger alerts

  Background:
    Given the Indrajaal system is in initial state
    And STAMP constraints SC-OPT-001 to SC-OPT-010 are loaded
    And STAMP constraints SC-CONSOL-001 to SC-CONSOL-010 are loaded
    And the startup orchestrator is initialized
    And telemetry collection is active
    And performance baseline is established

  # ============================================================================
  # SCENARIO 1: Pre-compiled BEAM Image Build and Deployment
  # ============================================================================
  @precompiled @beam @critical @sc-opt-005
  Scenario: Pre-compiled BEAM image build produces bootable artifact
    Given I have a clean build environment
    And compilation metrics collector is running
    And image registry is accessible

    When I trigger pre-compiled BEAM image build
    Then the build MUST complete within 300 seconds
    And the build MUST produce zero errors
    And the build MUST produce zero warnings (SC-CMP-025)
    And the image MUST be tagged with version "21.2.1-SIL6"
    And the image MUST contain compiled BEAM files for 773 modules
    And the image MUST contain Zenoh NIF library
    And the image MUST contain Lineage NIF library
    And the image size MUST be < 500MB
    And the manifest MUST include 7-layer verification metadata

    # 7-Level Detail Structure
    And at L7_FEDERATION level:
      | Property | Expected |
      | image_architecture | amd64 |
      | base_image | alpine:3.19 |
      | elixir_version | 1.19+ |
      | otp_version | 28+ |
      | manifest_signature | present |

    And at L6_CLUSTER level:
      | Property | Expected |
      | compilation_parallelism | 16_schedulers |
      | beam_files_count | 773 |
      | nif_libraries | 2 |
      | dependencies_locked | true |

    And at L5_NODE level:
      | Property | Expected |
      | runtime_requirements | verified |
      | port_bindings | documented |
      | volume_mounts | specified |

    And at L4_CONTAINER level:
      | Property | Expected |
      | entrypoint | /app/bin/indrajaal |
      | workdir | /app |
      | user | indrajaal:indrajaal |
      | health_check | defined |

    And at L3_PROCESS level:
      | Property | Expected |
      | vm_args | optimized |
      | env_vars | minimal |
      | startup_script | present |

    And at L2_FUNCTION level:
      | Property | Expected |
      | compiled_modules | all |
      | protocol_consolidated | true |
      | app_loaded | verified |

    And at L1_DATA level:
      | Property | Expected |
      | beam_format | valid |
      | file_checksums | verified |
      | layer_integrity | confirmed |

    And the image MUST be pushed to registry "localhost/indrajaal-app:21.2.1-SIL6-precompiled"
    And performance telemetry MUST show build time breakdown
    And the build log MUST be archived

  @precompiled @boot @critical @sc-opt-002
  Scenario: Pre-compiled BEAM boots faster than runtime compilation
    Given a pre-compiled BEAM image exists at "localhost/indrajaal-app:21.2.1-SIL6-precompiled"
    And a runtime-compiled image exists at "localhost/indrajaal-app:21.2.1-SIL6-runtime"
    And boot time measurement is configured
    And the database container is healthy
    And the observability stack is running

    # Boot with pre-compiled image
    When I start container using pre-compiled image
    Then the container MUST start within 30 seconds (SC-OPT-002)
    And the health endpoint MUST respond within 500ms (SC-OPT-004)
    And NO runtime compilation MUST occur (SC-OPT-005)
    And the application MUST be ready for requests
    And I record the boot time as "precompiled_boot_time"
    And I stop the container gracefully

    # Boot with runtime-compiled image
    When I start container using runtime-compiled image
    Then the container MUST start
    And I record the boot time as "runtime_boot_time"
    And I stop the container gracefully

    # Comparison
    Then "precompiled_boot_time" MUST be < "runtime_boot_time"
    And the speedup MUST be at least 2x
    And performance telemetry MUST publish comparison to Zenoh topic "indrajaal/perf/boot_comparison"

    And detailed timing breakdown MUST include:
      | Phase | Max Time (Precompiled) | Max Time (Runtime) |
      | BEAM VM Start | 2s | 2s |
      | Application Load | 3s | 30s |
      | Supervisor Tree | 5s | 10s |
      | Health Ready | 1s | 2s |
      | Total | 30s | 60s |

  @precompiled @verification @critical @sc-opt-005
  Scenario: Pre-compiled BEAM image contains no runtime compilation artifacts
    Given a running container with pre-compiled image
    And runtime monitoring is active

    When the application boots to healthy state
    Then I inspect the running container filesystem
    And the "_build/dev" directory MUST NOT exist
    And the "_build/prod" directory MUST contain only release artifacts
    And NO "Compiling" log messages MUST appear
    And NO "mix compile" processes MUST be running
    And beam files MUST have timestamps from image build time
    And the application MUST serve requests normally

    And at L3_PROCESS level:
      | Check | Result |
      | ps aux grep "mix compile" | 0 processes |
      | find /app/_build -name "*.ex" | 0 files |
      | find /app/_build -name "*.beam" | 773 files |
      | beam file age | > 1 hour (from build) |

  # ============================================================================
  # SCENARIO 2: Wave Parallelization Optimization
  # ============================================================================
  @wave @parallelization @critical @sc-opt-006
  Scenario: W2 observability and Zenoh boot in parallel
    Given the startup orchestrator is at S1_INFRASTRUCTURE complete
    And W2_OBSERVABILITY components are ready to start
    And W2_ZENOH_MESH components are ready to start
    And parallel execution is enabled
    And timing measurement is configured

    When I trigger W2 parallel boot
    Then BOTH component groups MUST start simultaneously
    And the observability stack MUST include:
      | Container | Max Boot Time |
      | indrajaal-obs-prod | 15s |
      | otel-collector | 5s |
      | prometheus | 8s |
      | grafana | 10s |
      | loki | 7s |

    And the Zenoh mesh MUST include:
      | Container | Max Boot Time |
      | zenoh-router-1 | 3s |
      | zenoh-router-2 | 3s |
      | zenoh-router-3 | 3s |

    And the total W2 time MUST be max(observability, zenoh) < 20s
    And parallelization speedup MUST be > 50% vs sequential
    And dependency ordering MUST be respected within each group
    And health checks MUST pass for all components

    # 7-Level Verification
    And at L6_CLUSTER level:
      | Metric | Value |
      | parallel_threads | 2 |
      | orchestration_overhead | < 1s |
      | dependency_violations | 0 |

    And at L5_NODE level:
      | Metric | Value |
      | cpu_utilization | optimized |
      | memory_peak | within_limits |
      | network_ready | confirmed |

    And telemetry MUST show parallel execution trace on Zenoh topic "indrajaal/startup/wave/w2/parallel"

  @wave @early-start @critical @sc-opt-009
  Scenario: W3 application starts early after quorum formation
    Given W2 parallel boot is complete
    And database quorum verification is configured
    And application readiness check is configured
    And quorum timeout is set to 10 seconds

    When I monitor database cluster quorum status
    Then quorum MUST form within 10 seconds (SC-OPT-009)
    And the quorum status MUST be verified via health check
    And W3_APPLICATION MUST start immediately after quorum confirmation
    And W3_APPLICATION MUST NOT wait for full W2 health stabilization
    And the application MUST reach healthy state within 15s

    And quorum formation details:
      | Check | Threshold |
      | database_primary | available |
      | database_replicas | >= 1 |
      | connection_pool | established |
      | migration_version | current |

    And early start benefits:
      | Metric | Improvement |
      | total_boot_time | -5s to -10s |
      | time_to_first_request | -5s |
      | user_perceived_latency | -30% |

  @wave @ha-parallel @high @sc-opt-006
  Scenario: W5 HA components boot in parallel
    Given W4 homeostasis verification is complete
    And HA configuration is loaded
    And clustering is enabled

    When I trigger W5_HA_CLUSTERING boot
    Then the following containers MUST start in parallel:
      | Container | Purpose | Max Boot |
      | indrajaal-ex-app-2 | HA replica 2 | 20s |
      | indrajaal-ex-app-3 | HA replica 3 | 20s |

    And cluster formation MUST occur automatically
    And distributed Erlang connections MUST be established
    And the cluster MUST reach full mesh topology
    And all nodes MUST report to epmd

    And at L6_CLUSTER level:
      | Metric | Expected |
      | cluster_size | 3 |
      | mesh_topology | full_mesh |
      | partition_tolerance | verified |
      | split_brain_protection | active |

    And parallel HA boot speedup MUST be > 50% vs sequential

  @wave @timing @critical @sc-opt-006
  Scenario: Full wave sequence achieves target parallelization speedup
    Given a clean startup environment
    And sequential boot baseline is recorded as "baseline_time"
    And parallelized boot is configured

    When I execute full 7-stage boot with parallelization
    Then the timing breakdown MUST be:
      | Stage | Parallel Time | Sequential Baseline |
      | S0_PREFLIGHT | 5s | 5s |
      | S1_INFRASTRUCTURE | 10s | 10s |
      | S2_ZENOH_MESH (W2 parallel) | 15s | 30s |
      | S3_OBSERVABILITY (W2 parallel) | 15s (concurrent) | 30s |
      | S4_APPLICATION (W3 early) | 15s | 20s |
      | S5_HA_CLUSTERING (W5 parallel) | 20s | 40s |
      | S6_HOMEOSTASIS | 10s | 10s |
      | TOTAL | < 60s | > 100s |

    And overall speedup MUST be > 50% (SC-OPT-006)
    And all STAMP constraints MUST be satisfied
    And no timing violations MUST occur

  # ============================================================================
  # SCENARIO 3: ComposeGenerator Deterministic Output
  # ============================================================================
  @compose @generator @critical @sc-consol-001
  Scenario: ComposeGenerator produces valid YAML from unified config
    Given the unified config file exists at "lib/cepaf/artifacts/config/indrajaal-sil6-unified.yaml"
    And the ComposeGenerator is initialized
    And YAML schema validation is configured

    When I invoke ComposeGenerator with config
    Then the generator MUST produce valid YAML output
    And the output MUST conform to Podman Compose v2.0 schema (SC-CONSOL-001)
    And the output MUST include ALL 15 containers (SC-CONSOL-002):
      | Container Name | Image | Purpose |
      | indrajaal-db-prod | postgres:17-alpine | Database |
      | indrajaal-obs-prod | otel/opentelemetry-collector-contrib:latest | Observability |
      | indrajaal-ex-app-1 | localhost/indrajaal-app:21.2.1-SIL6 | App Primary |
      | indrajaal-ex-app-2 | localhost/indrajaal-app:21.2.1-SIL6 | App HA 2 |
      | indrajaal-ex-app-3 | localhost/indrajaal-app:21.2.1-SIL6 | App HA 3 |
      | zenoh-router-1 | eclipse/zenoh:latest | Zenoh Primary |
      | zenoh-router-2 | eclipse/zenoh:latest | Zenoh Replica 2 |
      | zenoh-router-3 | eclipse/zenoh:latest | Zenoh Replica 3 |
      | prometheus | prom/prometheus:latest | Metrics |
      | grafana | grafana/grafana:latest | Visualization |
      | loki | grafana/loki:latest | Logs |
      | indrajaal-cortex | localhost/indrajaal-cortex:latest | Cognitive Plane |
      | cepaf-bridge | localhost/cepaf-bridge:latest | Orchestration |
      | indrajaal-chaya | localhost/indrajaal-chaya:latest | Digital Twin |

    And the output MUST define all required networks
    And the output MUST define all required volumes
    And the output MUST specify all health checks
    And the output MUST include all environment variables
    And syntax validation MUST pass

  @compose @deterministic @critical @sc-consol-003
  Scenario: ComposeGenerator produces identical output for identical input
    Given the unified config file "indrajaal-sil6-unified.yaml"
    And deterministic mode is enabled
    And output comparison is configured

    When I generate compose file 10 times with same input
    Then ALL 10 outputs MUST be byte-for-byte identical (SC-CONSOL-003)
    And SHA-256 checksums MUST match exactly
    And generation timestamps MUST NOT affect output
    And random ordering MUST NOT occur
    And the output MUST have stable formatting

    And deterministic properties MUST include:
      | Property | Verification |
      | container_order | alphabetical |
      | network_order | alphabetical |
      | volume_order | alphabetical |
      | env_var_order | alphabetical |
      | dependency_order | topological |

  @compose @validation @critical @sc-consol-004
  Scenario: ComposeGenerator validates output against schema
    Given a unified config with intentional errors
    And schema validation is enabled
    And error reporting is configured

    When I invoke ComposeGenerator
    Then validation MUST detect all schema violations
    And validation errors MUST include:
      | Error Type | Example |
      | missing_required_field | services.indrajaal-app.image missing |
      | invalid_port_format | ports: "not_a_number" |
      | unknown_property | services.foo.unknown_key |
      | invalid_dependency | depends_on: nonexistent_service |
      | invalid_network | networks: invalid_name |

    And the generator MUST refuse to produce invalid output
    And clear error messages MUST be provided
    And error location (line/column) MUST be reported

    When I fix all validation errors
    And I invoke ComposeGenerator again
    Then validation MUST pass (SC-CONSOL-004)
    And valid YAML MUST be generated

  @compose @integration @high @sc-consol-002
  Scenario: Generated compose file boots full 15-container stack
    Given ComposeGenerator has produced valid YAML
    And the output is saved to "generated-compose.yml"
    And Podman is available
    And required images exist or can be pulled

    When I execute "podman-compose -f generated-compose.yml up -d"
    Then ALL 15 containers MUST start
    And ALL health checks MUST pass within 60 seconds
    And the full system MUST be operational
    And all inter-container dependencies MUST be satisfied

    And container verification:
      | Check | Result |
      | podman ps --format '{{.Names}}' wc -l | 15 |
      | all containers STATUS | healthy |
      | all networks | created |
      | all volumes | created |

    When I execute "podman-compose -f generated-compose.yml down"
    Then graceful shutdown MUST complete
    And NO containers MUST remain running

  # ============================================================================
  # SCENARIO 4: ConfigBridge F# to Elixir Synchronization
  # ============================================================================
  @config @bridge @critical @sc-consol-005
  Scenario: ConfigBridge exports F# config to Elixir format
    Given the F# unified config is loaded from "lib/cepaf/artifacts/config/indrajaal-sil6-unified.yaml"
    And the ConfigBridge module is initialized
    And Elixir config target path is "config/runtime.exs"

    When I invoke ConfigBridge.export()
    Then the Elixir config file MUST be generated (SC-CONSOL-005)
    And the config MUST be valid Elixir syntax
    And the config MUST contain all required sections:
      | Section | Keys |
      | :indrajaal | :database, :zenoh, :telemetry, :startup |
      | :logger | :level, :backends |
      | :phoenix | :endpoint |

    And database configuration MUST match F# source:
      | Property | F# Source | Elixir Export |
      | hostname | localhost | localhost |
      | port | 5433 | 5433 |
      | database | indrajaal_prod | indrajaal_prod |
      | pool_size | 10 | 10 |

    And Zenoh configuration MUST match:
      | Property | F# Source | Elixir Export |
      | enabled | true | true |
      | router_endpoint | tcp/zenoh-router-1:7447 | tcp/zenoh-router-1:7447 |
      | mode | client | client |

    And the export timestamp MUST be recorded
    And telemetry MUST publish to "indrajaal/config/export"

  @config @drift @critical @sc-consol-006
  Scenario: ConfigBridge detects configuration drift
    Given F# config is at version "21.2.1-baseline"
    And Elixir config is at version "21.2.1-baseline"
    And both configs are in sync
    And drift detection is enabled

    When I modify F# config value "database.pool_size" from 10 to 20
    And I do NOT export to Elixir
    And I invoke ConfigBridge.detect_drift()

    Then drift MUST be detected (SC-CONSOL-006)
    And drift report MUST include:
      | Property | F# Value | Elixir Value | Drift |
      | database.pool_size | 20 | 10 | true |

    And drift severity MUST be calculated
    And drift alert MUST be triggered (SC-CONSOL-010)
    And drift MUST be published to Zenoh topic "indrajaal/config/drift"

    When I export the updated F# config
    And I invoke ConfigBridge.detect_drift() again
    Then NO drift MUST be detected
    And configs MUST be in sync

  @config @zenoh @high @sc-consol-007
  Scenario: ConfigBridge publishes config changes to Zenoh
    Given ConfigBridge is connected to Zenoh
    And Zenoh topic "indrajaal/config/changes" is subscribed
    And config versioning is enabled

    When I modify config value "telemetry.sample_rate" from 1.0 to 0.5
    And I export via ConfigBridge
    Then a config change event MUST be published to Zenoh (SC-CONSOL-007)

    And the Zenoh message MUST contain:
      | Field | Value |
      | change_id | unique_uuid |
      | timestamp | ISO8601 |
      | property_path | telemetry.sample_rate |
      | old_value | 1.0 |
      | new_value | 0.5 |
      | version | 21.2.1+1 |
      | author | ConfigBridge |

    And subscribers MUST receive the change notification
    And the change MUST be logged to Immutable Register

  @config @hotreload @high @sc-consol-008
  Scenario: ConfigBridge supports hot reload of runtime config
    Given the application is running
    And hot reload is enabled in config
    And runtime config watcher is active

    When I modify non-critical config "logger.level" from "info" to "debug"
    And I trigger ConfigBridge.export(hot_reload: true)
    Then the config change MUST be applied WITHOUT restart (SC-CONSOL-008)
    And the logger level MUST change to "debug" immediately
    And NO application downtime MUST occur
    And telemetry MUST show hot reload success

    And hot reload verification:
      | Check | Result |
      | application_uptime | continuous |
      | config_reloaded_at | timestamp |
      | logger_level | debug |
      | active_connections | preserved |

    # Critical config changes require restart
    When I modify critical config "database.hostname"
    And I trigger ConfigBridge.export(hot_reload: true)
    Then a warning MUST be issued that restart is required
    And the config MUST NOT be applied until restart
    And an alert MUST be sent to operators

  @config @validation @critical @sc-consol-009
  Scenario: Config changes trigger automatic validation
    Given the ConfigBridge validation pipeline is configured
    And validation rules are loaded
    And rejection on failure is enabled

    When I attempt to set "database.pool_size" to -5 (invalid)
    Then validation MUST reject the change (SC-CONSOL-009)
    And validation error MUST be reported:
      | Field | Error |
      | database.pool_size | must be positive integer |

    When I attempt to set "zenoh.router_endpoint" to "invalid_uri"
    Then validation MUST reject the change
    And validation error MUST be:
      | Field | Error |
      | zenoh.router_endpoint | invalid URI format |

    When I set valid config changes
    Then validation MUST pass
    And changes MUST be applied

    And validation rules MUST cover:
      | Category | Examples |
      | type_checking | int, string, bool, duration |
      | range_checking | port: 1-65535, pool_size: 1-100 |
      | format_checking | URI, email, regex |
      | dependency_checking | if X enabled, Y required |

  # ============================================================================
  # SCENARIO 5: BEAM Cache Persistence and Efficiency
  # ============================================================================
  @beam @cache @high @sc-opt-007
  Scenario: BEAM cache persists across container restarts
    Given a container with BEAM volume mounted at "/app/_build"
    And the application has compiled 773 modules
    And cache checksums are recorded

    When I stop the container gracefully
    And I start the container again
    Then the BEAM cache volume MUST persist (SC-OPT-007)
    And all 773 BEAM files MUST be present
    And checksums MUST match pre-restart values
    And NO recompilation MUST occur
    And boot time MUST be equivalent to first boot

    And cache persistence verification:
      | Check | Result |
      | find /app/_build -name "*.beam" wc -l | 773 |
      | cache_hit_rate | 100% |
      | recompilation_count | 0 |

  @beam @cache @high
  Scenario: BEAM cache invalidates when source changes
    Given a container with BEAM cache from previous build
    And application version is "21.2.1"
    And cache is valid

    When I update source code to version "21.2.2"
    And I rebuild the application
    Then the cache MUST detect changes
    And ONLY modified modules MUST recompile
    And unmodified modules MUST use cache
    And incremental build MUST be faster than full rebuild

    And incremental build metrics:
      | Metric | Value |
      | modules_changed | 5 |
      | modules_recompiled | 5 |
      | modules_cached | 768 |
      | build_time_reduction | 90% |

  @beam @cache @medium
  Scenario: BEAM cache cleanup removes stale artifacts
    Given a BEAM cache with multiple versions
    And cleanup policy is configured (keep last 3 versions)

    When cache cleanup is triggered
    Then stale BEAM files MUST be removed
    And current version cache MUST be preserved
    And last 2 versions MUST be preserved
    And older versions MUST be deleted
    And disk space MUST be reclaimed

    And cleanup report MUST show:
      | Metric | Value |
      | versions_kept | 3 |
      | versions_deleted | N-3 |
      | disk_reclaimed | >100MB |

  # ============================================================================
  # SCENARIO 6: Comprehensive Performance Target Verification
  # ============================================================================
  @performance @targets @critical @sc-opt-002
  Scenario: Full system meets all performance targets
    Given a clean environment
    And performance monitoring is active on all layers
    And baseline measurements are recorded

    When I execute full system boot from cold start
    Then ALL performance targets MUST be met:
      | Target | Constraint | Measured | Status |
      | Boot Time < 30s | SC-OPT-002 | measured | PASS/FAIL |
      | PHICS < 50ms | SC-OPT-003 | measured | PASS/FAIL |
      | Health Check < 500ms | SC-OPT-004 | measured | PASS/FAIL |
      | Quorum < 10s | SC-OPT-009 | measured | PASS/FAIL |

    # 7-Level Performance Verification
    And at L7_FEDERATION level:
      | Metric | Target | Measured |
      | cross_cluster_latency | < 100ms | measured |
      | federation_sync | < 5s | measured |

    And at L6_CLUSTER level:
      | Metric | Target | Measured |
      | cluster_formation | < 10s | measured |
      | consensus_time | < 5s | measured |
      | distributed_txn | < 50ms | measured |

    And at L5_NODE level:
      | Metric | Target | Measured |
      | node_boot | < 20s | measured |
      | beam_vm_start | < 3s | measured |
      | supervisor_tree | < 5s | measured |

    And at L4_CONTAINER level:
      | Metric | Target | Measured |
      | container_create | < 2s | measured |
      | container_start | < 5s | measured |
      | health_check | < 500ms | measured |

    And at L3_PROCESS level:
      | Metric | Target | Measured |
      | genserver_init | < 100ms | measured |
      | supervisor_init | < 200ms | measured |
      | app_start | < 1s | measured |

    And at L2_FUNCTION level:
      | Metric | Target | Measured |
      | function_call | < 1ms | measured |
      | database_query | < 10ms | measured |
      | cache_lookup | < 0.1ms | measured |

    And at L1_DATA level:
      | Metric | Target | Measured |
      | beam_load | < 10ms | measured |
      | ets_create | < 1ms | measured |
      | file_read | < 5ms | measured |

    And telemetry MUST publish full performance report
    And any target violations MUST trigger alerts

  @performance @phics @critical @sc-opt-003
  Scenario: PHICS latency remains under 50ms (p99)
    Given the system is fully operational
    And PHICS (Phoenix-Ecto-Container-Storage) monitoring is active
    And latency measurement is configured for 1000 requests

    When I execute 1000 HTTP requests to health endpoint
    Then p50 latency MUST be < 10ms
    And p95 latency MUST be < 30ms
    And p99 latency MUST be < 50ms (SC-OPT-003)
    And p99.9 latency MUST be < 100ms

    And latency breakdown MUST show:
      | Component | p99 Latency |
      | Network (LB → App) | < 5ms |
      | Phoenix Routing | < 2ms |
      | Controller Logic | < 5ms |
      | Ecto Query | < 20ms |
      | Container I/O | < 10ms |
      | Storage Read | < 8ms |
      | Total PHICS | < 50ms |

    And NO request MUST exceed 100ms
    And telemetry MUST publish latency histogram to Zenoh

  @performance @telemetry @high @sc-opt-008
  Scenario: Performance telemetry publishes to Zenoh continuously
    Given the system is operational
    And Zenoh is connected
    And telemetry publishers are active

    When I monitor Zenoh topic "indrajaal/perf/**"
    Then telemetry MUST be published every 10 seconds (SC-OPT-008)
    And telemetry MUST include:
      | Topic | Data |
      | indrajaal/perf/boot | boot_time, stage_times |
      | indrajaal/perf/phics | p50, p95, p99 latencies |
      | indrajaal/perf/health | health_response_time |
      | indrajaal/perf/quorum | quorum_formation_time |
      | indrajaal/perf/cache | cache_hit_rate, cache_size |
      | indrajaal/perf/wave | wave_parallelization_times |

    And telemetry data MUST be structured as JSON
    And telemetry MUST include timestamps
    And telemetry MUST be stored in DuckDB for analytics

  # ============================================================================
  # SCENARIO 7: 7-Layer Fractal Verification During Boot
  # ============================================================================
  @fractal @verification @critical @sc-opt-010
  Scenario: All 7 fractal layers verify during optimized boot
    Given the startup orchestrator is configured for full verification
    And fractal layer checks are enabled at each stage
    And verification results are tracked

    When I execute optimized boot sequence
    Then ALL 7 fractal layers MUST verify (SC-OPT-010):

    # L0: Runtime/Constitutional Layer
    And at L0_RUNTIME verification:
      | Check | Result |
      | system_compiles | VERIFIED |
      | beam_vm_boots | VERIFIED |
      | constitutional_axioms | VERIFIED |
      | founder_directive | VERIFIED |

    # L1: Function/Contract Layer
    And at L1_FUNCTION verification:
      | Check | Result |
      | io_contracts_valid | VERIFIED |
      | type_specs_complete | VERIFIED |
      | function_exports | VERIFIED |

    # L2: Component/Module Layer
    And at L2_COMPONENT verification:
      | Check | Result |
      | module_cohesion | VERIFIED |
      | genserver_patterns | VERIFIED |
      | supervision_trees | VERIFIED |

    # L3: Holon/Domain Layer
    And at L3_HOLON verification:
      | Check | Result |
      | agent_logic_sound | VERIFIED |
      | ash_resources_valid | VERIFIED |
      | domain_boundaries | VERIFIED |

    # L4: Container/Isolation Layer
    And at L4_CONTAINER verification:
      | Check | Result |
      | container_isolation | VERIFIED |
      | port_bindings | VERIFIED |
      | volume_mounts | VERIFIED |
      | health_checks | VERIFIED |

    # L5: Node/Runtime Layer
    And at L5_NODE verification:
      | Check | Result |
      | runtime_stable | VERIFIED |
      | clustering_active | VERIFIED |
      | epmd_registered | VERIFIED |

    # L6: Cluster/Consensus Layer
    And at L6_CLUSTER verification:
      | Check | Result |
      | consensus_holds | VERIFIED |
      | quorum_achieved | VERIFIED |
      | partition_tolerance | VERIFIED |
      | 2oo3_voting | VERIFIED |

    # L7: Federation/Global Layer
    And at L7_FEDERATION verification:
      | Check | Result |
      | global_invariants | VERIFIED |
      | federation_protocol | VERIFIED |
      | cross_holon_comms | VERIFIED |

    And the verification summary MUST be published to Zenoh
    And any verification failure MUST halt boot
    And verification results MUST be logged to Immutable Register

  # ============================================================================
  # SCENARIO 8: Error Handling and Degradation
  # ============================================================================
  @error @handling @high
  Scenario: Graceful degradation when pre-compiled image unavailable
    Given the pre-compiled image is missing
    And fallback to runtime compilation is configured

    When I attempt to boot the system
    Then the system MUST detect missing pre-compiled image
    And the system MUST fall back to runtime compilation
    And a warning MUST be logged
    And boot time MUST be longer but still functional
    And an alert MUST be sent to operators

  @error @handling @high
  Scenario: Recovery from wave parallelization failure
    Given W2 parallel boot is in progress
    And one component fails to start

    When the failure is detected
    Then the failed component MUST be retried
    And the successful component MUST continue
    And if retry succeeds, boot MUST continue
    And if retry fails, boot MUST roll back
    And detailed error report MUST be generated

  @error @validation @high
  Scenario: ComposeGenerator handles invalid config gracefully
    Given a malformed unified config file
    And error handling is enabled

    When I invoke ComposeGenerator
    Then the generator MUST detect all errors
    And the generator MUST produce NO output
    And clear error messages MUST be provided
    And suggestions for fixes MUST be included
    And the error MUST be logged

  @error @drift @critical
  Scenario: ConfigBridge alerts on critical drift
    Given configs are out of sync
    And drift severity is CRITICAL
    And alerting is configured

    When critical drift is detected
    Then an immediate alert MUST be triggered (SC-CONSOL-010)
    And the alert MUST include drift details
    And operators MUST be notified via Zenoh
    And the drift MUST be logged to audit trail
    And automated remediation MUST be offered

  # ============================================================================
  # SCENARIO 9: Integration and End-to-End Testing
  # ============================================================================
  @integration @e2e @critical
  Scenario: Full optimized boot with all Phase 7 features enabled
    Given a clean environment
    And all Phase 7 optimizations are enabled:
      | Optimization | Status |
      | Pre-compiled BEAM | enabled |
      | Wave Parallelization | enabled |
      | ComposeGenerator | enabled |
      | ConfigBridge | enabled |
      | BEAM Caching | enabled |
      | Performance Monitoring | enabled |

    When I execute full system boot
    Then boot MUST complete in < 30s (SC-OPT-002)
    And all 15 containers MUST be healthy
    And all 7 fractal layers MUST verify
    And all performance targets MUST be met
    And NO errors MUST occur
    And NO warnings MUST occur

    And the system MUST be ready for production traffic
    And telemetry MUST show full optimization benefits:
      | Metric | Baseline | Optimized | Improvement |
      | Boot Time | 100s | 30s | 70% |
      | PHICS Latency | 80ms | 40ms | 50% |
      | Cache Hit Rate | 0% | 95% | 95% |
      | Wave Speedup | 1x | 2x | 100% |

  @integration @monitoring @high
  Scenario: Performance monitoring dashboard shows optimization metrics
    Given the system is running with Phase 7 optimizations
    And the monitoring dashboard is accessible
    And Grafana is configured

    When I view the performance dashboard
    Then the dashboard MUST display:
      | Panel | Metrics |
      | Boot Performance | boot_time, stage_times, speedup |
      | PHICS Latency | p50, p95, p99 histograms |
      | Cache Efficiency | hit_rate, size, evictions |
      | Wave Parallelization | parallel_time, sequential_time, speedup |
      | Config Drift | drift_count, severity, last_sync |
      | Fractal Verification | layer_status, verification_time |

    And all metrics MUST update in real-time
    And alerts MUST be visible for violations
    And historical trends MUST be shown

  @integration @regression @high
  Scenario: Optimizations do not break existing functionality
    Given the system with Phase 7 optimizations
    And a regression test suite is defined

    When I execute the regression test suite
    Then all existing tests MUST pass
    And NO new failures MUST be introduced
    And performance MUST improve or remain stable
    And NO functional regressions MUST occur

    And regression coverage MUST include:
      | Area | Tests |
      | Database Operations | CRUD, migrations, queries |
      | API Endpoints | Health, GraphQL, REST |
      | Clustering | Join, leave, partition |
      | Monitoring | Metrics, logs, traces |
      | Security | Auth, encryption, audit |

  # ============================================================================
  # SCENARIO 10: Continuous Optimization and Tuning
  # ============================================================================
  @tuning @continuous @medium
  Scenario: Auto-tuning adjusts parallelization based on load
    Given the system is operational
    And auto-tuning is enabled
    And load patterns are monitored

    When high load is detected
    Then parallel thread count MUST increase
    And resource allocation MUST adjust
    And performance MUST be maintained

    When low load is detected
    Then parallel thread count MUST decrease
    And resource usage MUST be optimized
    And cost efficiency MUST improve

  @tuning @feedback @medium
  Scenario: Performance feedback loop improves future boots
    Given historical boot performance data exists in DuckDB
    And machine learning feedback is enabled

    When I analyze boot performance trends
    Then the system MUST identify bottlenecks
    And optimization recommendations MUST be generated
    And future boots MUST apply learned optimizations
    And boot time MUST trend downward over time

    And feedback loop metrics:
      | Metric | Trend |
      | boot_time_avg | decreasing |
      | bottleneck_count | decreasing |
      | optimization_score | increasing |
