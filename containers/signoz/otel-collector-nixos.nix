{ pkgs ? import <nixpkgs> {} }:

let
  # OTEL Collector configuration for ClickHouse export
  otelConfig = pkgs.writeText "otel-collector-config.yaml" ''
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318

      prometheus:
        config:
          scrape_configs:
            - job_name: 'otel-collector'
              scrape_interval: 10s
              static_configs:
                - targets: ['localhost:8888']

    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024

      memory_limiter:
        check_interval: 1s
        limit_mib: 1800
        spike_limit_mib: 500

    exporters:
      clickhouse:
        endpoint: tcp://signoz-clickhouse:9000
        database: signoz_traces
        logs_table_name: logs
        traces_table_name: traces
        metrics_table_name: metrics
        timeout: 10s
        retry_on_failure:
          enabled: true
          initial_interval: 5s
          max_interval: 30s
          max_elapsed_time: 300s

      otlp:
        endpoint: signoz-tempo:4317
        tls:
          insecure: true

      prometheus:
        endpoint: 0.0.0.0:8889
        namespace: otel

      debug:
        verbosity: basic

    extensions:
      health_check:
        endpoint: 0.0.0.0:13133

      zpages:
        endpoint: 0.0.0.0:55679

    service:
      extensions: [health_check, zpages]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp, debug]

        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch]
          exporters: [prometheus, debug]

        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [debug]

      telemetry:
        logs:
          level: info
        metrics:
          address: 0.0.0.0:8888
  '';

  # Health check script
  healthCheckScript = pkgs.writeShellScriptBin "health-check.sh" ''
    exec ${pkgs.curl}/bin/curl -sf http://localhost:13133/ || exit 1
  '';

  # Startup script
  startScript = pkgs.writeShellScriptBin "start-collector.sh" ''
    #!/bin/bash
    set -e

    echo "Starting OpenTelemetry Collector..."
    echo "Config: /etc/otelcol/config.yaml"

    # Create necessary directories
    mkdir -p /var/lib/otel-collector/queue

    # Start the collector with the config
    exec ${pkgs.opentelemetry-collector-contrib}/bin/otelcol-contrib \
      --config=/etc/otelcol/config.yaml
  '';

in pkgs.dockerTools.buildLayeredImage {
  name = "localhost/signoz-otel-collector";
  tag = "latest";

  contents = with pkgs; [
    opentelemetry-collector-contrib
    bash
    coreutils
    curl
    procps
    findutils
    netcat-gnu
    tzdata
    cacert
    healthCheckScript
    startScript
  ];

  extraCommands = ''
    # Create directory structure
    mkdir -p etc/otelcol
    mkdir -p var/lib/otel-collector/queue
    mkdir -p tmp

    # Copy config
    cp ${otelConfig} etc/otelcol/config.yaml

    # Set permissions
    chmod 755 var/lib/otel-collector
    chmod 755 var/lib/otel-collector/queue
    chmod 777 tmp
  '';

  config = {
    Cmd = ["${startScript}/bin/start-collector.sh"];

    ExposedPorts = {
      "4317/tcp" = {};   # OTLP gRPC
      "4318/tcp" = {};   # OTLP HTTP
      "8888/tcp" = {};   # Prometheus metrics
      "8889/tcp" = {};   # Prometheus exporter
      "13133/tcp" = {};  # Health check
      "55679/tcp" = {};  # zpages
    };

    Env = [
      "GOGC=80"
      "GOMEMLIMIT=2GiB"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
    ];

    Healthcheck = {
      Test = ["CMD" "${healthCheckScript}/bin/health-check.sh"];
      Interval = 30000000000;
      Timeout = 5000000000;
      Retries = 3;
      StartPeriod = 40000000000;
    };

    Labels = {
      "org.opencontainers.image.source" = "https://github.com/open-telemetry/opentelemetry-collector-contrib";
      "org.opencontainers.image.description" = "OpenTelemetry Collector Contrib - NixOS";
      "org.opencontainers.image.version" = pkgs.opentelemetry-collector-contrib.version;
      "indrajaal.component" = "observability";
      "indrajaal.subsystem" = "otel-collector";
    };

    WorkingDir = "/var/lib/otel-collector";
  };
}
