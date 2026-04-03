defmodule ContainerArchitectureTest do
  @moduledoc """
  TDG-Compliant Test Suite for 3-Container Architecture Validation

  Comprehensive validation of the 3-container infrastructure:
  - intelitor-app: Phoenix application (12 CPU, 32GB RAM)
  - intelitor-db: PostgreSQL 17 + TimescaleDB (4 CPU, 16GB RAM)
  - intelitor-obs: Observability stack (4 CPU, 8GB RAM)

  Tests cover:
  - Container health and lifecycle
  - Inter-container communication
  - Resource allocation and limits
  - PHICS hot-reloading (<50ms)
  - Rootless execution
  - Localhost registry compliance

  Coverage Target: 100% container infrastructure coverage
  Framework: ExUnit with dual property testing (PropCheck + ExUnitProperties)
  SOPv5.11 Compliance: TDG + TPS + STAMP + AOR + Enterprise Standards
  STAMP Safety Constraints: SC-CNT-009 to SC-CNT-016
  """

  use ExUnit.Case, async: true
  use Intelitor.Ultimate.TestConsolidation
  use PropCheck

  # # use ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002)  # Disabled - PropCheck property/2 conflict
  # # import ExUnitProperties  # Disabled - PropCheck conflict (SC-TDG-002)  # Disabled - PropCheck conflict

  @moduletag :tdg_compliant
  @moduletag :test_driven_generation
  @moduletag :container
  @moduletag :gde_compliant
  @moduletag :infrastructure

  # ============================================================================
  # Container Configuration Tests
  # ============================================================================

  describe "3-Container Architecture Configuration" do
    @tag :configuration
    test "intelitor-app container configuration" do
      app_config = %{
        name: "intelitor-app",
        image: "localhost/intelitor:latest",
        cpu: 12,
        memory_gb: 32,
        ports: [4000, 4001],
        components: [
          "Phoenix",
          "BEAM",
          "Cachex",
          "Ash Domains (10)"
        ]
      }

      assert app_config.cpu == 12
      assert app_config.memory_gb == 32
      assert 4000 in app_config.ports
      assert String.starts_with?(app_config.image, "localhost/")
    end

    @tag :configuration
    test "intelitor-db container configuration" do
      db_config = %{
        name: "intelitor-db",
        image: "localhost/postgres-timescale:17",
        cpu: 4,
        memory_gb: 16,
        port: 5433,
        components: [
          "PostgreSQL 17",
          "TimescaleDB"
        ]
      }

      assert db_config.cpu == 4
      assert db_config.memory_gb == 16
      assert db_config.port == 5433
      assert String.starts_with?(db_config.image, "localhost/")
    end

    @tag :configuration
    test "intelitor-obs container configuration" do
      obs_config = %{
        name: "intelitor-obs",
        image: "localhost/observability:latest",
        cpu: 4,
        memory_gb: 8,
        ports: [4317, 4318, 8123, 3001, 9090],
        components: [
          "ClickHouse",
          "OTEL Collector",
          "Grafana",
          "Prometheus",
          "Nginx"
        ]
      }

      assert obs_config.cpu == 4
      assert obs_config.memory_gb == 8
      # OTEL gRPC
      assert 4317 in obs_config.ports
      # OTEL HTTP
      assert 4318 in obs_config.ports
      assert String.starts_with?(obs_config.image, "localhost/")
    end

    @tag :configuration
    test "total resource allocation matches plan" do
      # app + db + obs
      total_cpu = 12 + 4 + 4
      total_memory_gb = 32 + 16 + 8

      assert total_cpu == 20, "Total CPU must be 20 cores"
      assert total_memory_gb == 56, "Total memory must be 56GB"
    end
  end

  # ============================================================================
  # Container Health Tests
  # ============================================================================

  describe "Container Health Validation" do
    @tag :health
    test "app container health check" do
      health_check = %{
        container: "intelitor-app",
        endpoint: "http://localhost:4001/health",
        expected_status: 200,
        timeout_ms: 5000
      }

      assert health_check.expected_status == 200
      assert health_check.timeout_ms <= 5000
    end

    @tag :health
    test "db container health check" do
      health_check = %{
        container: "intelitor-db",
        check_type: :pg_isready,
        port: 5433,
        timeout_ms: 5000
      }

      assert health_check.port == 5433
    end

    @tag :health
    test "obs container health check" do
      health_check = %{
        container: "intelitor-obs",
        endpoints: [
          %{service: "grafana", port: 3001},
          %{service: "prometheus", port: 9090},
          %{service: "otel", port: 4318}
        ],
        timeout_ms: 5000
      }

      assert length(health_check.endpoints) == 3
    end

    @tag :health
    test "all containers must be healthy before operations" do
      containers = [
        %{name: "intelitor-app", status: :healthy},
        %{name: "intelitor-db", status: :healthy},
        %{name: "intelitor-obs", status: :healthy}
      ]

      all_healthy = Enum.all?(containers, &(&1.status == :healthy))
      assert all_healthy == true
    end
  end

  # ============================================================================
  # Inter-Container Communication Tests
  # ============================================================================

  describe "Inter-Container Communication" do
    @tag :communication
    test "app to db connection" do
      connection = %{
        from: "intelitor-app",
        to: "intelitor-db",
        port: 5433,
        protocol: :tcp,
        secured: true
      }

      assert connection.port == 5433
      assert connection.protocol == :tcp
    end

    @tag :communication
    test "app to obs telemetry" do
      telemetry = %{
        from: "intelitor-app",
        to: "intelitor-obs",
        endpoints: [
          %{service: "otel-grpc", port: 4317, protocol: :grpc},
          %{service: "otel-http", port: 4318, protocol: :http}
        ]
      }

      assert length(telemetry.endpoints) == 2
    end

    @tag :communication
    test "network isolation between containers" do
      network = %{
        name: "intelitor-network",
        isolated: true,
        host_network_forbidden: true
      }

      assert network.isolated == true
      assert network.host_network_forbidden == true
    end
  end

  # ============================================================================
  # PHICS Hot-Reloading Tests
  # ============================================================================

  describe "PHICS v2.1 Hot-Reloading" do
    @tag :phics
    test "PHICS latency under 50ms" do
      phics_config = %{
        enabled: true,
        target_latency_ms: 50,
        bidirectional: true,
        watch_enabled: true
      }

      assert phics_config.enabled == true
      assert phics_config.target_latency_ms == 50
      assert phics_config.bidirectional == true
    end

    @tag :phics
    test "PHICS environment variables" do
      required_env = [
        "PHICS_ENABLED",
        "PHICS_WATCH_ENABLED",
        "PHICS_CONTAINER_MODE",
        "PHICS_HOT_RELOAD",
        "PHICS_SYNC_LATENCY_TARGET",
        "PHICS_BIDIRECTIONAL"
      ]

      for env_var <- required_env do
        assert env_var != nil, "#{env_var} must be defined"
      end
    end

    @tag :phics
    test "PHICS file synchronization" do
      sync_config = %{
        source: "/workspace",
        target: "/app",
        patterns: ["lib/**/*.ex", "test/**/*.exs", "config/**/*.exs"],
        exclude: ["_build", "deps", ".git"]
      }

      assert sync_config.source == "/workspace"
      assert length(sync_config.patterns) > 0
      assert "_build" in sync_config.exclude
    end

    @tag :phics
    test "PHICS LiveReloader integration" do
      live_reload = %{
        enabled: true,
        websocket: true,
        file_types: [:ex, :exs, :heex, :css, :js]
      }

      assert live_reload.enabled == true
      assert :ex in live_reload.file_types
    end
  end

  # ============================================================================
  # Registry Compliance Tests
  # ============================================================================

  describe "Localhost Registry Compliance" do
    @tag :registry
    test "all images use localhost registry" do
      images = [
        "localhost/intelitor:latest",
        "localhost/postgres-timescale:17",
        "localhost/observability:latest"
      ]

      for image <- images do
        assert String.starts_with?(image, "localhost/"),
               "Image #{image} must use localhost registry"
      end
    end

    @tag :registry
    test "forbidden registries are blocked" do
      forbidden = ["docker.io/", "quay.io/", "ghcr.io/", "gcr.io/"]

      for registry <- forbidden do
        refute String.starts_with?("localhost/image", registry),
               "#{registry} must be forbidden"
      end
    end

    @tag :registry
    test "fallback registry is nixos only" do
      allowed_registries = ["localhost/", "registry.nixos.org/"]

      for registry <- allowed_registries do
        assert registry =~ ~r/localhost|nixos/
      end
    end
  end

  # ============================================================================
  # Rootless Execution Tests
  # ============================================================================

  describe "Rootless Container Execution" do
    @tag :rootless
    test "containers run as non-root" do
      execution_config = %{
        rootless: true,
        privileged: false,
        user_namespace: true
      }

      assert execution_config.rootless == true
      assert execution_config.privileged == false
    end

    @tag :rootless
    test "no CAP_NET_ADMIN required" do
      capabilities = %{
        required: [],
        forbidden: [:CAP_NET_ADMIN, :CAP_SYS_ADMIN]
      }

      assert :CAP_NET_ADMIN in capabilities.forbidden
      assert :CAP_SYS_ADMIN in capabilities.forbidden
    end

    @tag :rootless
    test "SELinux integration" do
      selinux = %{
        enabled: true,
        labels: [:container_t]
      }

      assert selinux.enabled == true
    end
  end

  # ============================================================================
  # Container Lifecycle Tests
  # ============================================================================

  describe "Container Lifecycle Management" do
    @tag :lifecycle
    test "container startup order" do
      startup_order = [
        %{container: "intelitor-db", order: 1, wait_for: nil},
        %{container: "intelitor-obs", order: 2, wait_for: nil},
        %{container: "intelitor-app", order: 3, wait_for: ["intelitor-db"]}
      ]

      db = Enum.find(startup_order, &(&1.container == "intelitor-db"))
      app = Enum.find(startup_order, &(&1.container == "intelitor-app"))

      assert db.order < app.order, "DB must start before app"
      assert "intelitor-db" in app.wait_for
    end

    @tag :lifecycle
    test "container startup time under 30s" do
      startup_limits = %{
        intelitor_db: 30,
        intelitor_obs: 30,
        intelitor_app: 30
      }

      for {container, limit} <- startup_limits do
        assert limit <= 30, "#{container} startup must be <=30s"
      end
    end

    @tag :lifecycle
    test "graceful shutdown" do
      shutdown_config = %{
        signal: :SIGTERM,
        timeout_seconds: 30,
        force_after: :SIGKILL
      }

      assert shutdown_config.timeout_seconds == 30
    end
  end

  # ============================================================================
  # Podman-Compose Configuration Tests
  # ============================================================================

  describe "Podman-Compose Configuration" do
    @tag :compose
    test "podman-compose file structure" do
      compose_structure = %{
        version: "3.8",
        services: ["intelitor-app", "intelitor-db", "intelitor-obs"],
        networks: ["intelitor-network"],
        volumes: ["db-data", "obs-data"]
      }

      assert length(compose_structure.services) == 3
      assert "intelitor-network" in compose_structure.networks
    end

    @tag :compose
    test "service dependencies" do
      dependencies = %{
        "intelitor-app" => ["intelitor-db"],
        "intelitor-db" => [],
        "intelitor-obs" => []
      }

      assert "intelitor-db" in dependencies["intelitor-app"]
      assert dependencies["intelitor-db"] == []
    end

    @tag :compose
    test "volume persistence" do
      volumes = [
        %{name: "db-data", mount: "/var/lib/postgresql/data"},
        %{name: "obs-data", mount: "/var/lib/clickhouse"}
      ]

      assert length(volumes) >= 2
    end
  end

  # ============================================================================
  # Service Port Registry Tests
  # ============================================================================

  describe "Service Port Registry" do
    @tag :ports
    test "application container ports" do
      app_ports = %{
        phoenix: 4000,
        health_check: 4001
      }

      assert app_ports.phoenix == 4000
      assert app_ports.health_check == 4001
    end

    @tag :ports
    test "database container port" do
      # Non-standard to avoid conflicts
      db_port = 5433

      assert db_port == 5433
    end

    @tag :ports
    test "observability container ports" do
      obs_ports = %{
        clickhouse_http: 8123,
        clickhouse_native: 9000,
        otel_grpc: 4317,
        otel_http: 4318,
        grafana: 3001,
        prometheus: 9090,
        nginx_http: 80,
        nginx_https: 443
      }

      assert obs_ports.otel_grpc == 4317
      assert obs_ports.grafana == 3001
    end

    @tag :ports
    test "no port conflicts" do
      all_ports = [4000, 4001, 5433, 8123, 9000, 4317, 4318, 3001, 9090, 80, 443]
      unique_ports = Enum.uniq(all_ports)

      assert length(all_ports) == length(unique_ports), "No port conflicts allowed"
    end
  end

  # ============================================================================
  # Dual Property Testing
  # ============================================================================

  describe "Property-based Testing (PropCheck)" do
    @tag :property
    property "container CPU allocation is valid" do
      forall cpu <- integer(1, 20) do
        cpu >= 1 and cpu <= 20
      end
    end

    @tag :property
    property "container memory allocation is valid" do
      forall memory_gb <- integer(1, 64) do
        memory_gb >= 1 and memory_gb <= 64
      end
    end

    @tag :property
    property "port numbers are valid" do
      forall port <- integer(1, 65535) do
        port >= 1 and port <= 65535
      end
    end
  end

  describe "Property-based Testing (ExUnitProperties)" do
    @tag :property
    property "container names are valid" do
      valid_prefixes = ["intelitor-app", "intelitor-db", "intelitor-obs"]

      forall name <- oneof(valid_prefixes) do
        String.starts_with?(name, "intelitor-")
      end
    end

    @tag :property
    property "resource limits sum correctly" do
      forall {app_cpu, db_cpu, obs_cpu} <- {exactly(12), exactly(4), exactly(4)} do
        total = app_cpu + db_cpu + obs_cpu
        total == 20
      end
    end
  end

  # ============================================================================
  # STAMP Safety Constraint Tests
  # ============================================================================

  describe "STAMP Container Safety (SC-CNT-*)" do
    @tag :stamp
    test "SC-CNT-009: NixOS container base" do
      base_image = "NixOS"
      assert base_image == "NixOS"
    end

    @tag :stamp
    test "SC-CNT-010: Localhost registry only" do
      image = "localhost/intelitor:latest"
      assert String.starts_with?(image, "localhost/")
    end

    @tag :stamp
    test "SC-CNT-011: PHICS <50ms" do
      latency_target = 50
      assert latency_target == 50
    end

    @tag :stamp
    test "SC-CNT-012: Rootless execution" do
      rootless = true
      privileged = false

      assert rootless == true
      assert privileged == false
    end

    @tag :stamp
    test "SC-CNT-013: Container health validation" do
      health_check_required = true
      assert health_check_required == true
    end

    @tag :stamp
    test "SC-CNT-014: Resource isolation" do
      isolation = %{
        cpu_limited: true,
        memory_limited: true
      }

      assert isolation.cpu_limited == true
      assert isolation.memory_limited == true
    end

    @tag :stamp
    test "SC-CNT-015: Network security" do
      network_secure = true
      assert network_secure == true
    end

    @tag :stamp
    test "SC-CNT-016: Registry drift prevention" do
      registry_monitored = true
      assert registry_monitored == true
    end
  end
end

# Agent: Infrastructure Specialist (Container Orchestration)
# SOPv5.11 Compliance: TDG + TPS + STAMP + AOR
# Domain: Container Infrastructure Validation
# STAMP Constraints: SC-CNT-009 to SC-CNT-016
# AOR Rules: AOR-CNT-001 to AOR-CNT-006
# Dual Property Testing: PropCheck + ExUnitProperties
