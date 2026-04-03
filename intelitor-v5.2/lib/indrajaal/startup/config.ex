defmodule Indrajaal.Startup.Config do
  @moduledoc """
  ## CENTRALIZED STARTUP CONFIGURATION - SINGLE SOURCE OF TRUTH

  Version: 21.2.1-SIL6
  Date: 2026-01-17

  STAMP Compliance:
  - SC-BOOT-001: State vector MUST be verified before each stage
  - SC-CONFIG-001: All configuration MUST be in single location
  - SC-CONFIG-002: NO magic values in boot/runtime code
  - SC-CONFIG-003: Change ONE location for system-wide updates

  This module is the AUTHORITATIVE source for all Elixir startup configuration.
  All other modules MUST reference this config - NO hardcoded values allowed.

  ## Mathematical Foundation

  State Vector Definition:
  $\\vec{S}(t) = (s_{compile}, s_{migrations}, s_{containers}, s_{zenoh}, s_{health}, s_{quorum})$

  Each component $s_i \\in \\{0, 1\\}$ where $1$ = valid

  Valid Startup Predicate:
  $\\text{ValidStartup}(t) \\iff \\prod_{i=1}^{6} s_i(t) = 1$

  ## Usage

      iex> Indrajaal.Startup.Config.ports(:phoenix_primary)
      4000

      iex> Indrajaal.Startup.Config.timeout(:health_check)
      5000

      iex> Indrajaal.Startup.Config.state_vector_valid?(%{...})
      true
  """

  # =============================================================================
  # PORT CONFIGURATION - ALL PORTS IN ONE PLACE
  # =============================================================================

  @doc "Get port by name - SINGLE SOURCE OF TRUTH for all port numbers"
  @spec ports(atom()) :: non_neg_integer()
  def ports(name) do
    case name do
      # Application Tier
      :phoenix_primary -> 4000
      :phoenix_health -> 4001
      :phoenix_chaya -> 4002
      :phoenix_app2 -> 4003
      :phoenix_app2_health -> 4004
      :phoenix_app3 -> 4005
      :phoenix_app3_health -> 4006
      :redis -> 6379
      :prometheus_metrics -> 9568
      # Database Tier
      :postgres -> 5433
      :postgres_internal -> 5432
      # Zenoh Control Plane (2oo3 Quorum)
      :zenoh_router1_tcp -> 7447
      :zenoh_router1_ws -> 8448
      :zenoh_router1_rest -> 8000
      :zenoh_router2_tcp -> 7448
      :zenoh_router2_ws -> 8449
      :zenoh_router2_rest -> 8001
      :zenoh_router3_tcp -> 7449
      :zenoh_router3_ws -> 8450
      :zenoh_router3_rest -> 8002
      # Cognitive Plane
      :cepaf_bridge -> 9876
      :cortex -> 9877
      # Observability Stack
      :otel_grpc -> 4317
      :otel_http -> 4318
      :otel_metrics -> 8888
      :prometheus -> 9090
      :grafana -> 3000
      :loki -> 3100
      :signoz_frontend -> 3301
      :signoz_query -> 8080
      :signoz_alert -> 9093
      :clickhouse_http -> 8123
      :clickhouse_native -> 9000
      _ -> raise ArgumentError, "Unknown port name: #{name}"
    end
  end

  @doc """
  Get all ports as a map for BDD test compatibility.
  Maps service atoms to port numbers.
  """
  @spec ports_map() :: map()
  def ports_map do
    %{
      phoenix: ports(:phoenix_primary),
      phoenix_health: ports(:phoenix_health),
      postgres: ports(:postgres),
      redis: ports(:redis),
      zenoh_router1: ports(:zenoh_router1_tcp),
      otel_grpc: ports(:otel_grpc),
      prometheus: ports(:prometheus),
      grafana: ports(:grafana)
    }
  end

  @doc "Get all ports as list for port scouring"
  @spec all_ports() :: [non_neg_integer()]
  def all_ports do
    [
      ports(:phoenix_primary),
      ports(:phoenix_health),
      ports(:phoenix_chaya),
      ports(:phoenix_app2),
      ports(:phoenix_app2_health),
      ports(:phoenix_app3),
      ports(:phoenix_app3_health),
      ports(:redis),
      ports(:prometheus_metrics),
      ports(:postgres),
      ports(:zenoh_router1_tcp),
      ports(:zenoh_router1_ws),
      ports(:zenoh_router1_rest),
      ports(:zenoh_router2_tcp),
      ports(:zenoh_router2_ws),
      ports(:zenoh_router2_rest),
      ports(:zenoh_router3_tcp),
      ports(:zenoh_router3_ws),
      ports(:zenoh_router3_rest),
      ports(:cepaf_bridge),
      ports(:cortex),
      ports(:otel_grpc),
      ports(:otel_http),
      ports(:otel_metrics),
      ports(:prometheus),
      ports(:grafana),
      ports(:loki),
      ports(:signoz_frontend),
      ports(:signoz_query),
      ports(:signoz_alert),
      ports(:clickhouse_http),
      ports(:clickhouse_native)
    ]
  end

  # =============================================================================
  # IP ADDRESS CONFIGURATION
  # =============================================================================

  @doc "Get IP address by role"
  @spec ip_address(atom()) :: String.t()
  def ip_address(role) do
    case role do
      :subnet -> "172.28.0.0/16"
      :gateway -> "172.28.0.1"
      :internal_subnet -> "172.29.0.0/16"
      # Application Tier
      :app_primary -> "172.28.0.10"
      :app_node2 -> "172.28.0.11"
      :app_node3 -> "172.28.0.12"
      # Data Tier
      :database -> "172.28.0.20"
      # Observability Tier
      :observability -> "172.28.0.30"
      # Zenoh Control Plane
      :zenoh_router1 -> "172.28.0.40"
      :zenoh_router2 -> "172.28.0.41"
      :zenoh_router3 -> "172.28.0.42"
      :zenoh_proxy -> "172.28.0.43"
      # Cognitive Plane
      :cepaf_bridge -> "172.28.0.50"
      :cortex -> "172.28.0.60"
      # Digital Twin Plane
      :chaya -> "172.28.0.70"
      # Satellite Plane
      :ml_runner1 -> "172.28.0.80"
      :ml_runner2 -> "172.28.0.81"
      _ -> raise ArgumentError, "Unknown IP address role: #{role}"
    end
  end

  @doc """
  Get all IP addresses as a map for BDD test compatibility.
  Maps role atoms to IP strings.
  """
  @spec ip_addresses_map() :: map()
  def ip_addresses_map do
    %{
      app: ip_address(:app_primary),
      db: ip_address(:database),
      observability: ip_address(:observability),
      zenoh: ip_address(:zenoh_router1)
    }
  end

  # =============================================================================
  # HOSTNAME CONFIGURATION
  # =============================================================================

  @doc """
  Get all hostnames as a map for BDD test compatibility.
  Maps service atoms to hostname strings.
  """
  @spec hostnames_map() :: map()
  def hostnames_map do
    %{
      db: hostname(:db_prod),
      obs: hostname(:obs_prod),
      app: hostname(:app_primary),
      zenoh: hostname(:zenoh_proxy)
    }
  end

  @doc "Get hostname by service"
  @spec hostname(atom()) :: String.t()
  def hostname(service) do
    case service do
      :db_prod -> "indrajaal-db-prod"
      :obs_prod -> "indrajaal-obs-prod"
      :app_primary -> "indrajaal-ex-app-1"
      :app_node2 -> "indrajaal-ex-app-2"
      :app_node3 -> "indrajaal-ex-app-3"
      :zenoh_router1 -> "zenoh-router-1"
      :zenoh_router2 -> "zenoh-router-2"
      :zenoh_router3 -> "zenoh-router-3"
      :zenoh_proxy -> "zenoh-router"
      :cepaf_bridge -> "cepaf-bridge"
      :cortex -> "indrajaal-cortex"
      :chaya -> "indrajaal-chaya"
      :ml_runner1 -> "indrajaal-ml-runner-1"
      :ml_runner2 -> "indrajaal-ml-runner-2"
      _ -> raise ArgumentError, "Unknown hostname service: #{service}"
    end
  end

  # =============================================================================
  # NETWORK CONFIGURATION
  # =============================================================================

  @doc "Get network name"
  @spec network(atom()) :: String.t()
  def network(name) do
    case name do
      :sil6_mesh -> "indrajaal-sil6-mesh"
      :internal -> "indrajaal-internal"
      :cluster_net -> "indrajaal-cluster-net"
      :db_standalone -> "db-standalone-net"
      :obs_standalone -> "obs-standalone-net"
      _ -> raise ArgumentError, "Unknown network name: #{name}"
    end
  end

  # =============================================================================
  # TIMEOUT CONFIGURATION (milliseconds)
  # =============================================================================

  @doc """
  Get all timeouts as a map for BDD test compatibility.
  Maps timeout names to millisecond values.
  """
  @spec timeouts_map() :: map()
  def timeouts_map do
    %{
      total_boot: timeout(:total_boot),
      container: timeout(:container),
      health_check: timeout(:health_check),
      ooda_cycle: timeout(:ooda_cycle_max)
    }
  end

  @doc "Get timeout value by name"
  @spec timeout(atom()) :: non_neg_integer()
  def timeout(name) do
    case name do
      # Boot sequence timeouts
      :total_boot -> 15_000
      :container -> 30_000
      :health_check -> 5_000
      :health_check_interval -> 500
      :max_health_retries -> 20
      :db_init_wait -> 5_000
      :obs_init_wait -> 3_000
      :zenoh_init_wait -> 2_000
      :app_health_max_wait -> 300_000
      :app_health_retries -> 60
      :app_health_retry_interval -> 5_000
      # Runtime timeouts
      :ooda_cycle_max -> 100
      :health_heartbeat -> 10_000
      :sentinel_sync -> 30_000
      :circuit_breaker_threshold -> 3
      :quorum_timeout -> 5_000
      :zenoh_reconnect -> 5_000
      :compact_trigger_percent -> 75
      # Graceful shutdown timeouts
      :lameduck_period -> 5_000
      :drain_timeout -> 30_000
      :stop_timeout -> 10_000
      :kill_timeout -> 5_000
      :checkpoint_timeout -> 10_000
      # Jitter configuration
      :seed_delay -> 0
      :satellite_base_delay -> 500
      :satellite_max_jitter -> 200
      _ -> raise ArgumentError, "Unknown timeout name: #{name}"
    end
  end

  # =============================================================================
  # CONTAINER IMAGE CONFIGURATION
  # =============================================================================

  @doc "Get container image"
  @spec image(atom()) :: String.t()
  def image(name) do
    registry = "localhost"

    case name do
      :app_unified -> "#{registry}/indrajaal-app-unified:nixos-devenv"
      :db_timescale -> "#{registry}/indrajaal-timescaledb-demo:nixos-devenv"
      :obs_unified -> "#{registry}/indrajaal-obs-unified:nixos-devenv"
      :zenoh -> "eclipse/zenoh:1.0.0"
      :cepaf_bridge -> "#{registry}/cepaf-bridge:latest"
      :cortex -> "#{registry}/indrajaal-cortex:latest"
      _ -> raise ArgumentError, "Unknown image name: #{name}"
    end
  end

  # =============================================================================
  # RESOURCE LIMITS
  # =============================================================================

  @doc "Get resource limit"
  @spec resource(atom(), atom()) :: number()
  def resource(service, resource_type) do
    case {service, resource_type} do
      # Database
      {:db, :memory_mb} -> 4096
      {:db, :cpu_limit} -> 4.0
      {:db, :memory_reservation_mb} -> 2048
      {:db, :cpu_reservation} -> 2.0
      # Observability
      {:obs, :memory_mb} -> 10240
      {:obs, :cpu_limit} -> 6.0
      {:obs, :memory_reservation_mb} -> 5120
      {:obs, :cpu_reservation} -> 3.0
      # Application
      {:app, :memory_mb} -> 10240
      {:app, :cpu_limit} -> 8.0
      {:app, :memory_reservation_mb} -> 5120
      {:app, :cpu_reservation} -> 4.0
      # Zenoh Routers
      {:zenoh, :memory_mb} -> 512
      {:zenoh, :cpu_limit} -> 1.0
      {:zenoh, :memory_reservation_mb} -> 256
      {:zenoh, :cpu_reservation} -> 0.5
      # Cognitive Plane
      {:cognitive, :memory_mb} -> 1024
      {:cognitive, :cpu_limit} -> 2.0
      {:cognitive, :memory_reservation_mb} -> 512
      {:cognitive, :cpu_reservation} -> 1.0
      _ -> raise ArgumentError, "Unknown resource: #{service}/#{resource_type}"
    end
  end

  # =============================================================================
  # QUORUM CONFIGURATION
  # =============================================================================

  @doc "Calculate quorum requirement: Q = floor(N/2) + 1"
  @spec calculate_quorum(non_neg_integer()) :: non_neg_integer()
  def calculate_quorum(node_count) do
    div(node_count, 2) + 1
  end

  @doc "Zenoh 2oo3 configuration"
  @spec zenoh_quorum() :: map()
  def zenoh_quorum do
    %{
      node_count: 3,
      # = 2
      quorum: calculate_quorum(3)
    }
  end

  @doc "FPPS 5-point consensus configuration"
  @spec fpps_quorum() :: map()
  def fpps_quorum do
    %{
      validator_count: 5,
      # = 3
      quorum: calculate_quorum(5)
    }
  end

  @doc "Circuit breaker threshold"
  @spec circuit_breaker_threshold() :: non_neg_integer()
  def circuit_breaker_threshold, do: 3

  # =============================================================================
  # STATE VECTOR CONFIGURATION
  # =============================================================================

  @typedoc "State vector component"
  @type state_component :: :invalid | :valid

  @typedoc "Full state vector for startup verification"
  @type state_vector :: %{
          compile: state_component(),
          migrations: state_component(),
          containers: state_component(),
          zenoh: state_component(),
          health: state_component(),
          quorum: state_component()
        }

  @doc "Create empty state vector"
  @spec empty_state_vector() :: state_vector()
  def empty_state_vector do
    %{
      compile: :invalid,
      migrations: :invalid,
      containers: :invalid,
      zenoh: :invalid,
      health: :invalid,
      quorum: :invalid
    }
  end

  @doc """
  Check if state vector is valid for complete startup.

  ValidStartup(t) ⟺ ∏(i=1..6) s_i(t) = 1
  """
  @spec state_vector_valid?(state_vector()) :: boolean()
  def state_vector_valid?(state) do
    state.compile == :valid &&
      state.migrations == :valid &&
      state.containers == :valid &&
      state.zenoh == :valid &&
      state.health == :valid &&
      state.quorum == :valid
  end

  @doc "Verify state vector for specific stage"
  @spec verify_state_for_stage(non_neg_integer(), state_vector()) :: :ok | {:error, String.t()}
  def verify_state_for_stage(stage, state) do
    case stage do
      # S0_PREFLIGHT has no pre-conditions
      0 ->
        :ok

      1 when state.compile == :valid ->
        :ok

      2
      when state.compile == :valid and state.migrations == :valid and state.containers == :valid ->
        :ok

      3
      when state.compile == :valid and state.migrations == :valid and state.containers == :valid and
             state.zenoh == :valid ->
        :ok

      4
      when state.compile == :valid and state.migrations == :valid and state.containers == :valid and
             state.zenoh == :valid and state.health == :valid ->
        :ok

      n ->
        {:error, "State vector invalid for stage S#{n}: #{inspect(state)}"}
    end
  end

  @doc "Format state vector as [c,m,co,z,h,q]"
  @spec format_state_vector(state_vector()) :: String.t()
  def format_state_vector(state) do
    b = fn v -> if v == :valid, do: "1", else: "0" end

    "[#{b.(state.compile)},#{b.(state.migrations)},#{b.(state.containers)},#{b.(state.zenoh)},#{b.(state.health)},#{b.(state.quorum)}]"
  end

  # =============================================================================
  # BOOT STAGE CONFIGURATION
  # =============================================================================

  @doc "Boot stage definitions"
  @spec boot_stage(atom()) :: map()
  def boot_stage(stage) do
    case stage do
      :s0_preflight ->
        %{
          name: "PREFLIGHT",
          description: "Environment validation, port scouring, container cleanup",
          timeout_ms: 5000,
          state_required: "[_,_,_,_,_,_]",
          state_after: "[1,_,_,_,_,_]"
        }

      :s1_infrastructure ->
        %{
          name: "INFRASTRUCTURE",
          description: "DB + Observability containers",
          timeout_ms: 30000,
          state_required: "[1,_,_,_,_,_]",
          state_after: "[1,1,1,_,_,_]"
        }

      :s2_zenoh_mesh ->
        %{
          name: "ZENOH_MESH",
          description: "Zenoh router + quorum verification",
          timeout_ms: 5000,
          state_required: "[1,1,1,_,_,_]",
          state_after: "[1,1,1,1,_,_]"
        }

      :s3_app_seed ->
        %{
          name: "APP_SEED",
          description: "Application boot with health wait",
          # 5 minutes for compilation
          timeout_ms: 300_000,
          state_required: "[1,1,1,1,_,_]",
          state_after: "[1,1,1,1,1,_]"
        }

      :s4_homeostasis ->
        %{
          name: "HOMEOSTASIS",
          description: "Health verification, quorum, Cortex verify",
          timeout_ms: 10000,
          state_required: "[1,1,1,1,1,_]",
          state_after: "[1,1,1,1,1,1]"
        }
    end
  end

  @doc "All boot stages in order"
  @spec boot_stages() :: [atom()]
  def boot_stages do
    [:s0_preflight, :s1_infrastructure, :s2_zenoh_mesh, :s3_app_seed, :s4_homeostasis]
  end

  # =============================================================================
  # MANDATORY ENVIRONMENT VARIABLES
  # =============================================================================

  @doc "Get mandatory environment variable value"
  @spec mandatory_env(atom()) :: String.t()
  def mandatory_env(name) do
    case name do
      :elixir_erl_options -> "+S 16:16 +SDio 16"
      :no_timeout -> "true"
      :patient_mode -> "enabled"
      :infinite_patience -> "true"
      :mix_partition_count -> "8"
      # NIF MUST be active (SC-ZENOH-001)
      :skip_zenoh_nif -> "0"
      :zenoh_enabled -> "true"
      :zenoh_mode -> "client"
      :sil6_mode -> "true"
      :biomorphic_healing -> "enabled"
      :cortex_integration -> "true"
      _ -> raise ArgumentError, "Unknown mandatory env: #{name}"
    end
  end

  @doc "Get Zenoh router endpoint"
  @spec zenoh_router_endpoint() :: String.t()
  def zenoh_router_endpoint do
    "tcp://#{hostname(:zenoh_proxy)}:#{ports(:zenoh_router1_tcp)}"
  end

  @doc "Build database URL"
  @spec database_url(String.t(), String.t(), non_neg_integer(), String.t()) :: String.t()
  def database_url(env, host, port, db) do
    "ecto://postgres:postgres@#{host}:#{port}/#{db}_#{env}"
  end

  @doc "Get default database URLs"
  @spec default_database_url(atom()) :: String.t()
  def default_database_url(env) do
    case env do
      :dev -> database_url("dev", "localhost", ports(:postgres), "indrajaal")
      :prod -> database_url("prod", hostname(:db_prod), ports(:postgres), "indrajaal")
      :test -> database_url("test", "localhost", ports(:postgres), "indrajaal")
    end
  end

  @doc "Get OTEL endpoint"
  @spec otel_endpoint() :: String.t()
  def otel_endpoint do
    "http://#{hostname(:obs_prod)}:#{ports(:otel_grpc)}"
  end

  @doc "Get CEPAF bridge URL"
  @spec cepaf_bridge_url() :: String.t()
  def cepaf_bridge_url do
    "http://#{hostname(:cepaf_bridge)}:#{ports(:cepaf_bridge)}"
  end

  @doc "Get Cortex URL"
  @spec cortex_url() :: String.t()
  def cortex_url do
    "http://#{hostname(:cortex)}:#{ports(:cortex)}"
  end

  # =============================================================================
  # HEALTH CHECK CONFIGURATION
  # =============================================================================

  @doc "Get health check configuration"
  @spec health_check(atom()) :: map()
  def health_check(service) do
    case service do
      :db ->
        %{
          test: "pg_isready -U postgres -d indrajaal_prod -p #{ports(:postgres)}",
          interval_s: 5,
          timeout_s: 5,
          retries: 10,
          start_period_s: 15
        }

      :app ->
        %{
          test: "curl -sf http://localhost:#{ports(:phoenix_primary)}/ > /dev/null || exit 1",
          interval_s: 30,
          timeout_s: 30,
          retries: 30,
          # 15 minutes for compilation
          start_period_s: 900
        }

      :obs ->
        %{
          test:
            "wget -q --spider http://localhost:#{ports(:prometheus)}/-/healthy && wget -q --spider http://localhost:#{ports(:grafana)}/api/health",
          interval_s: 15,
          timeout_s: 10,
          retries: 5,
          start_period_s: 45
        }

      :zenoh ->
        %{
          test: "nc -z localhost #{ports(:zenoh_router1_rest)}",
          interval_s: 10,
          timeout_s: 5,
          retries: 5,
          start_period_s: 10
        }
    end
  end

  # =============================================================================
  # STAMP CONSTRAINTS
  # =============================================================================

  @doc "STAMP constraints for boot sequence"
  @spec stamp_constraints() :: [map()]
  def stamp_constraints do
    [
      %{
        id: "SC-BOOT-001",
        description: "State vector MUST be verified before each stage",
        severity: :critical,
        enforcement: "Pre-stage gate"
      },
      %{
        id: "SC-BOOT-002",
        description: "Migration status MUST be checked before S3",
        severity: :critical,
        enforcement: "Migration gate"
      },
      %{
        id: "SC-BOOT-003",
        description: "Quorum MUST be achieved before S3",
        severity: :critical,
        enforcement: "Quorum gate"
      },
      %{
        id: "SC-BOOT-004",
        description: "Boot MUST be transactional (rollback on fail)",
        severity: :critical,
        enforcement: "Rollback handler"
      },
      %{
        id: "SC-BOOT-005",
        description: "Boot time MUST be < 120s (target 60s)",
        severity: :high,
        enforcement: "Timeout enforcement"
      },
      %{
        id: "SC-BOOT-006",
        description: "All containers MUST pass health check",
        severity: :high,
        enforcement: "Health gate"
      },
      %{
        id: "SC-BOOT-007",
        description: "Ports MUST be scoured before boot",
        severity: :high,
        enforcement: "Port isolation"
      },
      %{
        id: "SC-BOOT-008",
        description: "DAG MUST be acyclic (verified by Kahn)",
        severity: :critical,
        enforcement: "Topology validation"
      },
      %{
        id: "SC-BOOT-009",
        description: "Waves MUST boot in parallel within wave",
        severity: :high,
        enforcement: "Parallelization"
      },
      %{
        id: "SC-BOOT-010",
        description: "Checkpoints MUST be created at each stage",
        severity: :high,
        enforcement: "Dying gasp"
      },
      %{
        id: "SC-CONFIG-001",
        description: "All configuration MUST be in single location",
        severity: :critical,
        enforcement: "Code review"
      },
      %{
        id: "SC-CONFIG-002",
        description: "NO magic values in boot/runtime code",
        severity: :critical,
        enforcement: "Static analysis"
      },
      %{
        id: "SC-CONFIG-003",
        description: "Change ONE location for system-wide updates",
        severity: :high,
        enforcement: "Architecture rule"
      }
    ]
  end

  # =============================================================================
  # FMEA FAILURE MODES
  # =============================================================================

  @doc "FMEA failure modes with RPN scores"
  @spec fmea_failure_modes() :: [map()]
  def fmea_failure_modes do
    [
      %{
        id: "FM-BOOT-001",
        failure: "Port conflict",
        effect: "Container fails to start",
        severity: 7,
        occurrence: 5,
        detection: 4,
        rpn: 140,
        mitigation: "Port scouring in S0"
      },
      %{
        id: "FM-BOOT-002",
        failure: "DB not running",
        effect: "Commands fail",
        severity: 8,
        occurrence: 4,
        detection: 6,
        rpn: 192,
        mitigation: "Pre-check with pg_isready"
      },
      %{
        id: "FM-BOOT-003",
        failure: "NIF disabled",
        effect: "Tests skip Zenoh",
        severity: 7,
        occurrence: 6,
        detection: 6,
        rpn: 252,
        mitigation: "Force SKIP_ZENOH_NIF=0"
      },
      %{
        id: "FM-BOOT-004",
        failure: ".NET missing",
        effect: "CEPAF fails",
        severity: 6,
        occurrence: 9,
        detection: 54,
        rpn: 54,
        mitigation: "Check dotnet version"
      },
      %{
        id: "FM-BOOT-005",
        failure: "F# build fails",
        effect: "Cockpit unavailable",
        severity: 8,
        occurrence: 10,
        detection: 8,
        rpn: 80,
        mitigation: "Dedicated fix sprint"
      },
      %{
        id: "FM-BOOT-006",
        failure: "Migrations missing",
        effect: "Oban tables undefined",
        severity: 9,
        occurrence: 3,
        detection: 8,
        rpn: 216,
        mitigation: "Migration gate in S1"
      },
      %{
        id: "FM-BOOT-007",
        failure: "Quorum lost",
        effect: "Cluster unstable",
        severity: 8,
        occurrence: 4,
        detection: 5,
        rpn: 160,
        mitigation: "2oo3 Zenoh voting"
      },
      %{
        id: "FM-BOOT-008",
        failure: "Health check timeout",
        effect: "Container marked unhealthy",
        severity: 6,
        occurrence: 5,
        detection: 3,
        rpn: 90,
        mitigation: "Patient mode + 900s start"
      }
    ]
  end

  @doc "Get high-risk failure modes (RPN >= threshold)"
  @spec high_risk_failures(non_neg_integer()) :: [map()]
  def high_risk_failures(threshold \\ 150) do
    fmea_failure_modes()
    |> Enum.filter(fn fm -> fm.rpn >= threshold end)
    |> Enum.sort_by(fn fm -> -fm.rpn end)
  end

  # =============================================================================
  # CONFIGURATION VALIDATION
  # =============================================================================

  @doc "Validate all configuration"
  @spec validate_all() :: :ok | {:error, [String.t()]}
  def validate_all do
    errors = []

    # Validate ports are unique
    ports = all_ports()
    duplicates = ports -- Enum.uniq(ports)

    errors =
      if duplicates != [],
        do: ["Duplicate ports found: #{inspect(duplicates)}" | errors],
        else: errors

    # Validate quorum
    errors =
      if zenoh_quorum().quorum < 2,
        do: ["Zenoh quorum must be at least 2 for 2oo3 voting" | errors],
        else: errors

    # Validate timeouts
    errors =
      if timeout(:total_boot) > timeout(:app_health_max_wait),
        do: ["Total timeout must be less than app health max wait" | errors],
        else: errors

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end

  # =============================================================================
  # CONFIGURATION EXPORT
  # =============================================================================

  @doc "Export configuration summary"
  @spec summary() :: map()
  def summary do
    %{
      version: "21.2.1-SIL6",
      ports: %{
        phoenix: ports(:phoenix_primary),
        health: ports(:phoenix_health),
        postgres: ports(:postgres),
        zenoh_tcp: ports(:zenoh_router1_tcp),
        otel_grpc: ports(:otel_grpc),
        grafana: ports(:grafana)
      },
      timeouts: %{
        total_boot_ms: timeout(:total_boot),
        health_check_ms: timeout(:health_check),
        ooda_cycle_ms: timeout(:ooda_cycle_max)
      },
      quorum: %{
        zenoh_nodes: zenoh_quorum().node_count,
        zenoh_quorum: zenoh_quorum().quorum,
        fpps_quorum: fpps_quorum().quorum
      },
      validation: validate_all()
    }
  end

  @doc "Print configuration summary to console"
  @spec print_summary() :: :ok
  def print_summary do
    IO.puts("=== INDRAJAAL STARTUP CONFIGURATION SUMMARY ===")
    IO.puts("")
    IO.puts("=== PORTS ===")
    IO.puts("  Phoenix Primary: #{ports(:phoenix_primary)}")
    IO.puts("  PostgreSQL: #{ports(:postgres)}")
    IO.puts("  Zenoh Router: #{ports(:zenoh_router1_tcp)}")
    IO.puts("  OTEL Collector: #{ports(:otel_grpc)}")
    IO.puts("  Grafana: #{ports(:grafana)}")
    IO.puts("")
    IO.puts("=== TIMEOUTS ===")
    IO.puts("  Total Boot: #{timeout(:total_boot)}ms")
    IO.puts("  Container: #{timeout(:container)}ms")
    IO.puts("  Health Check: #{timeout(:health_check)}ms")
    IO.puts("  OODA Cycle: #{timeout(:ooda_cycle_max)}ms")
    IO.puts("")
    IO.puts("=== QUORUM ===")
    IO.puts("  Zenoh Nodes: #{zenoh_quorum().node_count}")
    IO.puts("  Zenoh Quorum: #{zenoh_quorum().quorum}")
    IO.puts("  FPPS Quorum: #{fpps_quorum().quorum}")
    IO.puts("")
    IO.puts("=== STATE VECTOR ===")
    IO.puts("  Empty: #{format_state_vector(empty_state_vector())}")
    IO.puts("")
    IO.puts("=== VALIDATION ===")

    case validate_all() do
      :ok ->
        IO.puts("  ✓ All configuration valid")

      {:error, errors} ->
        IO.puts("  ✗ Configuration errors:")
        Enum.each(errors, fn e -> IO.puts("    - #{e}") end)
    end

    :ok
  end
end
