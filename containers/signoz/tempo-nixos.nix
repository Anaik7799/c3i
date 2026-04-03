{ pkgs ? import <nixpkgs> {} }:

let
  # Tempo configuration
  tempoConfig = pkgs.writeText "tempo.yaml" ''
    server:
      http_listen_port: 3200
      grpc_listen_port: 9095

    distributor:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318

    ingester:
      max_block_duration: 5m

    compactor:
      compaction:
        block_retention: 1h

    storage:
      trace:
        backend: local
        wal:
          path: /var/lib/tempo/wal
        local:
          path: /var/lib/tempo/blocks

    overrides:
      defaults:
        metrics_generator:
          processors: [service-graphs, span-metrics]
  '';

  # Health check script
  healthCheckScript = pkgs.writeShellScriptBin "health-check.sh" ''
    exec ${pkgs.curl}/bin/curl -sf http://localhost:3200/ready || exit 1
  '';

  # Startup script
  startScript = pkgs.writeShellScriptBin "start-tempo.sh" ''
    #!/bin/bash
    set -e

    echo "Starting Tempo..."

    # Create necessary directories
    mkdir -p /var/lib/tempo/wal
    mkdir -p /var/lib/tempo/blocks

    # Start Tempo
    exec ${pkgs.tempo}/bin/tempo \
      -config.file=/etc/tempo/tempo.yaml
  '';

in pkgs.dockerTools.buildLayeredImage {
  name = "localhost/signoz-tempo";
  tag = "latest";

  contents = with pkgs; [
    tempo
    bash
    coreutils
    curl
    cacert
    healthCheckScript
    startScript
  ];

  extraCommands = ''
    # Create directory structure
    mkdir -p etc/tempo
    mkdir -p var/lib/tempo/wal
    mkdir -p var/lib/tempo/blocks
    mkdir -p tmp

    # Copy config
    cp ${tempoConfig} etc/tempo/tempo.yaml

    # Set permissions
    chmod 755 var/lib/tempo
    chmod 755 var/lib/tempo/wal
    chmod 755 var/lib/tempo/blocks
    chmod 777 tmp
  '';

  config = {
    Cmd = ["${startScript}/bin/start-tempo.sh"];

    ExposedPorts = {
      "3200/tcp" = {};
      "4317/tcp" = {};
      "4318/tcp" = {};
      "9095/tcp" = {};
    };

    Env = [
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
      "org.opencontainers.image.description" = "Grafana Tempo - NixOS";
      "indrajaal.component" = "observability";
      "indrajaal.subsystem" = "tempo";
    };

    WorkingDir = "/var/lib/tempo";
  };
}
