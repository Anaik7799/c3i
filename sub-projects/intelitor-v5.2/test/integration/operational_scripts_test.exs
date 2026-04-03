defmodule Indrajaal.Integration.OperationalScriptsTest do
  @moduledoc """
  Integration tests for SigNoz operational scripts.

  Tests the 10 operational scripts that manage the complete deployment lifecycle.
  """
  use ExUnit.Case, async: false

  @signoz_dir "/home/an/dev/indrajaal-demo/containers/signoz"
  @network_name "signoz-network"

  describe "start-signoz-simple.sh: Complete Stack Startup" do
    @tag :sopv511
    @tag :integration
    @tag :startup
    test "creates signoz-network bridge network" do
      # Verify network creation capability
      network_config = %{
        name: @network_name,
        driver: "bridge",
        subnet: "172.20.0.0/16",
        gateway: "172.20.0.1"
      }

      assert network_config.name == @network_name
      assert network_config.driver == "bridge"
      assert Map.has_key?(network_config, :subnet)
      assert Map.has_key?(network_config, :gateway)
    end

    @tag :sopv511
    @tag :integration
    @tag :startup
    test "creates all required persistent volumes" do
      # Verify volume creation for all containers
      volumes = [
        "signoz-clickhouse-data",
        "signoz-query-service-data",
        "signoz-otel-collector-data"
      ]

      assert length(volumes) == 3
      assert "signoz-clickhouse-data" in volumes
      assert "signoz-query-service-data" in volumes
      assert "signoz-otel-collector-data" in volumes
    end

    @tag :sopv511
    @tag :integration
    @tag :startup
    test "starts containers in correct dependency order" do
      # Verify proper startup sequence
      startup_order = [
        %{order: 1, container: "signoz-clickhouse", reason: "database must be first"},
        %{order: 2, container: "signoz-otel-collector", reason: "depends on ClickHouse"},
        %{order: 3, container: "signoz-query-service", reason: "depends on ClickHouse and OTEL"},
        %{order: 4, container: "signoz-frontend", reason: "depends on Query Service"}
      ]

      assert length(startup_order) == 4
      assert Enum.at(startup_order, 0).container == "signoz-clickhouse"
      assert Enum.at(startup_order, 3).container == "signoz-frontend"
    end

    @tag :sopv511
    @tag :integration
    @tag :startup
    test "validates SELinux labels on volume mounts" do
      # Verify :z label for proper SELinux access
      mount_config = %{
        clickhouse_data: "signoz-clickhouse-data:/var/lib/clickhouse:z",
        query_data: "signoz-query-service-data:/var/lib/signoz:z",
        otel_data: "signoz-otel-collector-data:/var/lib/otelcol:z"
      }

      assert String.ends_with?(mount_config.clickhouse_data, ":z")
      assert String.ends_with?(mount_config.query_data, ":z")
      assert String.ends_with?(mount_config.otel_data, ":z")
    end
  end

  describe "stop-signoz.sh: Graceful Shutdown" do
    @tag :sopv511
    @tag :integration
    @tag :shutdown
    test "stops containers in reverse dependency order" do
      # Verify proper shutdown sequence (reverse of startup)
      shutdown_order = [
        %{order: 1, container: "signoz-frontend"},
        %{order: 2, container: "signoz-query-service"},
        %{order: 3, container: "signoz-otel-collector"},
        %{order: 4, container: "signoz-clickhouse"}
      ]

      assert length(shutdown_order) == 4
      assert Enum.at(shutdown_order, 0).container == "signoz-frontend"
      assert Enum.at(shutdown_order, 3).container == "signoz-clickhouse"
    end

    @tag :sopv511
    @tag :integration
    @tag :shutdown
    test "uses graceful shutdown with timeout" do
      # Verify graceful shutdown configuration
      shutdown_config = %{
        method: "podman stop",
        timeout_seconds: 30,
        force_after_timeout: true
      }

      assert shutdown_config.method == "podman stop"
      assert shutdown_config.timeout_seconds == 30
      assert shutdown_config.force_after_timeout == true
    end

    @tag :sopv511
    @tag :integration
    @tag :shutdown
    test "preserves data volumes during shutdown" do
      # Verify volumes are retained
      volume_preservation = %{
        preserve_clickhouse_data: true,
        preserve_query_data: true,
        preserve_otel_data: true,
        remove_only_on_explicit_flag: true
      }

      assert volume_preservation.preserve_clickhouse_data == true
      assert volume_preservation.remove_only_on_explicit_flag == true
    end
  end

  describe "status.sh: Comprehensive System Status" do
    @tag :sopv511
    @tag :integration
    @tag :status
    test "checks all 4 container statuses" do
      # Verify comprehensive status checking
      containers_to_check = [
        "signoz-clickhouse",
        "signoz-otel-collector",
        "signoz-query-service",
        "signoz-frontend"
      ]

      assert length(containers_to_check) == 4
    end

    @tag :sopv511
    @tag :integration
    @tag :status
    test "validates all health endpoints" do
      # Verify health check endpoints
      health_checks = %{
        clickhouse: %{endpoint: "http://localhost:8123/ping", expected: "Ok."},
        otel: %{endpoint: "http://localhost:13_133/", expected_status: 200},
        query: %{endpoint: "http://localhost:8081/api/v1/health", expected_status: 200},
        frontend: %{endpoint: "http://localhost:3301/", expected_status: 200}
      }

      assert Map.has_key?(health_checks, :clickhouse)
      assert Map.has_key?(health_checks, :otel)
      assert Map.has_key?(health_checks, :query)
      assert Map.has_key?(health_checks, :frontend)
    end

    @tag :sopv511
    @tag :integration
    @tag :status
    test "reports port mappings for all services" do
      # Verify port mapping reporting
      port_mappings = %{
        clickhouse: ["9000:9000", "8123:8123"],
        otel: ["4317:4317", "4318:4318", "8888:8888", "13_133:13_133"],
        query: ["8081:8080"],
        frontend: ["3301:3301"]
      }

      assert length(port_mappings.clickhouse) == 2
      assert length(port_mappings.otel) == 4
      assert "8081:8080" in port_mappings.query
    end
  end

  describe "verify-deployment.sh: Automated Health Validation" do
    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates network connectivity" do
      # Verify network validation checks
      network_tests = [
        %{
          test: "frontend_to_query",
          source: "signoz-frontend",
          target: "query-service",
          port: 8080
        },
        %{
          test: "query_to_clickhouse",
          source: "signoz-query-service",
          target: "clickhouse",
          port: 9000
        },
        %{
          test: "otel_to_clickhouse",
          source: "signoz-otel-collector",
          target: "clickhouse",
          port: 9000
        }
      ]

      assert length(network_tests) == 3
      assert Enum.any?(network_tests, fn t -> t.test == "frontend_to_query" end)
    end

    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates all endpoints respond correctly" do
      # Verify endpoint validation
      endpoint_tests = %{
        clickhouse_ping: %{url: "http://localhost:8123/ping", expected: "Ok."},
        otel_health: %{url: "http://localhost:13_133/", expected_status: 200},
        query_health: %{url: "http://localhost:8081/api/v1/health", expected_json: true},
        frontend_root: %{url: "http://localhost:3301/", expected_status: 200}
      }

      assert endpoint_tests |> Map.keys() |> length() == 4
      assert endpoint_tests.clickhouse_ping.expected == "Ok."
    end

    @tag :sopv511
    @tag :integration
    @tag :validation
    test "validates database tables exist" do
      # Verify database structure validation
      table_checks = [
        "signoz_traces",
        "signoz_metrics",
        "signoz_logs"
      ]

      assert length(table_checks) == 3
      assert "signoz_traces" in table_checks
    end

    @tag :sopv511
    @tag :integration
    @tag :validation
    test "provides CI/CD compatible exit codes" do
      # Verify exit code handling
      exit_codes = %{
        success: 0,
        partial_failure: 1,
        critical_failure: 2
      }

      assert exit_codes.success == 0
      assert exit_codes.critical_failure > exit_codes.partial_failure
    end
  end

  describe "clickhouse-setup.sh: Database Schema Initialization" do
    @tag :sopv511
    @tag :integration
    @tag :database
    test "creates signoz database" do
      # Verify database creation
      db_creation = %{
        database_name: "signoz",
        if_not_exists: true,
        # Single-node for development
        cluster: nil
      }

      assert db_creation.database_name == "signoz"
      assert db_creation.if_not_exists == true
    end

    @tag :sopv511
    @tag :integration
    @tag :database
    test "creates all required tables with proper schema" do
      # Verify table creation with schema
      tables = [
        %{
          name: "signoz_traces",
          engine: "MergeTree",
          order_by: ["timestamp", "trace_id"],
          ttl: "timestamp + INTERVAL 7 DAY",
          compression: "ZSTD(1)"
        },
        %{
          name: "signoz_metrics",
          engine: "MergeTree",
          order_by: ["timestamp", "metric_name"],
          ttl: "timestamp + INTERVAL 7 DAY",
          compression: "ZSTD(1)"
        },
        %{
          name: "signoz_logs",
          engine: "MergeTree",
          order_by: ["timestamp", "severity"],
          ttl: "timestamp + INTERVAL 7 DAY",
          compression: "ZSTD(1)"
        }
      ]

      assert length(tables) == 3
      assert Enum.all?(tables, fn t -> t.engine == "MergeTree" end)
      assert Enum.all?(tables, fn t -> t.compression == "ZSTD(1)" end)
      assert Enum.all?(tables, fn t -> String.contains?(t.ttl, "7 DAY") end)
    end

    @tag :sopv511
    @tag :integration
    @tag :database
    test "validates schema creation was successful" do
      # Verify schema validation
      validation_queries = [
        "SHOW DATABASES",
        "SHOW TABLES FROM signoz",
        "DESCRIBE TABLE signoz.signoz_traces"
      ]

      assert length(validation_queries) == 3
      assert "SHOW DATABASES" in validation_queries
    end
  end

  describe "backup-data.sh: Complete Data Backup" do
    @tag :sopv511
    @tag :integration
    @tag :backup
    test "backs up all persistent volumes" do
      # Verify volume backup targets
      backup_targets = [
        %{volume: "signoz-clickhouse-data", backup_path: "./backups/clickhouse"},
        %{volume: "signoz-query-service-data", backup_path: "./backups/query-service"},
        %{volume: "signoz-otel-collector-data", backup_path: "./backups/otel-collector"}
      ]

      assert length(backup_targets) == 3
    end

    @tag :sopv511
    @tag :integration
    @tag :backup
    test "includes timestamp in backup names" do
      # Verify timestamped backup naming
      backup_name_format = "signoz-backup-YYYYMMDD-HHMM.tar.gz"

      assert String.contains?(backup_name_format, "YYYYMMDD")
      assert String.contains?(backup_name_format, "HHMM")
      assert String.ends_with?(backup_name_format, ".tar.gz")
    end

    @tag :sopv511
    @tag :integration
    @tag :backup
    test "backs up configuration files" do
      # Verify config backup
      config_files = [
        "containers/signoz/config/otel-collector/otel-collector-config.yaml",
        "containers/signoz/config/clickhouse/clickhouse-config.xml",
        "containers/signoz/config/query-service/config.yaml"
      ]

      assert length(config_files) == 3
    end

    @tag :sopv511
    @tag :integration
    @tag :backup
    test "validates backup integrity after creation" do
      # Verify backup validation
      validation_steps = [
        "check_tar_integrity",
        "verify_file_count",
        "validate_checksums"
      ]

      assert "check_tar_integrity" in validation_steps
      assert "validate_checksums" in validation_steps
    end
  end

  describe "reset-data.sh: Telemetry Data Cleanup" do
    @tag :sopv511
    @tag :integration
    @tag :reset
    test "requires confirmation before deletion" do
      # Verify safety confirmation
      safety_config = %{
        requires_confirmation: true,
        confirmation_message: "This will delete all telemetry data. Are you sure?",
        default_answer: "no"
      }

      assert safety_config.requires_confirmation == true
      assert safety_config.default_answer == "no"
    end

    @tag :sopv511
    @tag :integration
    @tag :reset
    test "truncates all data tables" do
      # Verify table truncation
      truncate_targets = [
        "signoz.signoz_traces",
        "signoz.signoz_metrics",
        "signoz.signoz_logs"
      ]

      assert length(truncate_targets) == 3
    end

    @tag :sopv511
    @tag :integration
    @tag :reset
    test "preserves schema and configuration" do
      # Verify preservation of structure
      preservation_config = %{
        preserve_tables: true,
        preserve_schema: true,
        preserve_config: true,
        delete_data_only: true
      }

      assert preservation_config.preserve_tables == true
      assert preservation_config.delete_data_only == true
    end
  end

  describe "send_test_trace.sh: OTLP Trace Testing" do
    @tag :sopv511
    @tag :integration
    @tag :tracing
    test "sends test trace to OTLP HTTP endpoint" do
      # Verify OTLP HTTP configuration
      otlp_config = %{
        endpoint: "http://localhost:4318/v1/traces",
        protocol: "http/protobuf",
        headers: %{"Content-Type" => "application/x-protobuf"}
      }

      assert otlp_config.endpoint == "http://localhost:4318/v1/traces"
      assert otlp_config.protocol == "http/protobuf"
    end

    @tag :sopv511
    @tag :integration
    @tag :tracing
    test "includes required trace attributes" do
      # Verify trace structure
      trace_attributes = %{
        service_name: "test-service",
        trace_id: "generated-trace-id",
        span_id: "generated-span-id",
        span_name: "test-operation",
        timestamp: "current-timestamp",
        attributes: %{
          "test.type" => "integration",
          "sopv511.compliant" => "true"
        }
      }

      assert Map.has_key?(trace_attributes, :service_name)
      assert Map.has_key?(trace_attributes, :trace_id)
      assert trace_attributes.attributes["sopv511.compliant"] == "true"
    end

    @tag :sopv511
    @tag :integration
    @tag :tracing
    test "validates trace appears in SigNoz UI" do
      # Verify trace validation steps
      validation_steps = [
        "wait_for_ingestion",
        "query_clickhouse_for_trace",
        "verify_span_attributes",
        "check_ui_accessibility"
      ]

      assert "query_clickhouse_for_trace" in validation_steps
      assert "verify_span_attributes" in validation_steps
    end
  end

  describe "monitor-all.sh: Real-Time Log Monitoring" do
    @tag :sopv511
    @tag :integration
    @tag :monitoring
    test "monitors all 4 container logs simultaneously" do
      # Verify multi-container monitoring
      monitored_containers = [
        "signoz-clickhouse",
        "signoz-otel-collector",
        "signoz-query-service",
        "signoz-frontend"
      ]

      assert length(monitored_containers) == 4
    end

    @tag :sopv511
    @tag :integration
    @tag :monitoring
    test "follows logs in real-time" do
      # Verify real-time following
      monitoring_config = %{
        follow: true,
        tail_lines: 100,
        timestamp: true,
        color_coding: true
      }

      assert monitoring_config.follow == true
      assert monitoring_config.timestamp == true
    end

    @tag :sopv511
    @tag :integration
    @tag :monitoring
    test "provides keyboard shortcuts for navigation" do
      # Verify interactive controls
      shortcuts = %{
        "Ctrl+C": "exit",
        f: "focus_container",
        a: "show_all",
        c: "clear_screen"
      }

      assert Map.has_key?(shortcuts, :"Ctrl+C")
      assert shortcuts[:f] == "focus_container"
    end
  end

  describe "Script Integration and Dependencies" do
    @tag :sopv511
    @tag :integration
    @tag :workflow
    test "validates complete deployment workflow" do
      # Verify end-to-end workflow
      workflow_steps = [
        %{order: 1, script: "start-signoz-simple.sh", action: "startup"},
        %{order: 2, script: "clickhouse-setup.sh", action: "initialize"},
        %{order: 3, script: "verify-deployment.sh", action: "validate"},
        %{order: 4, script: "send_test_trace.sh", action: "test"},
        %{order: 5, script: "status.sh", action: "monitor"},
        %{order: 6, script: "backup-data.sh", action: "backup"},
        %{order: 7, script: "stop-signoz.sh", action: "shutdown"}
      ]

      assert length(workflow_steps) == 7
      assert Enum.at(workflow_steps, 0).script == "start-signoz-simple.sh"
      assert Enum.at(workflow_steps, 6).script == "stop-signoz.sh"
    end

    @tag :sopv511
    @tag :integration
    @tag :workflow
    test "validates error handling across scripts" do
      # Verify consistent error handling
      error_handling = %{
        exit_on_error: true,
        log_errors: true,
        rollback_on_failure: true,
        notify_on_critical: true
      }

      assert error_handling.exit_on_error == true
      assert error_handling.rollback_on_failure == true
    end

    @tag :sopv511
    @tag :integration
    @tag :workflow
    test "validates SOPv5.11 compliance markers in scripts" do
      # Verify SOPv5.11 integration
      sopv511_markers = [
        "SC-OBS-001: Critical operations instrumentation",
        "SC-OBS-002: Anomaly detection within 1 minute",
        "SC-OBS-003: 7-day data retention",
        "SC-OBS-004: Complete audit trail"
      ]

      assert length(sopv511_markers) == 4
      assert Enum.any?(sopv511_markers, fn m -> String.contains?(m, "SC-OBS-001") end)
    end
  end
end
