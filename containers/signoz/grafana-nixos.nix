{ pkgs ? import <nixpkgs> {} }:

let
  # Grafana configuration
  grafanaConfig = pkgs.writeText "grafana.ini" ''
    [server]
    http_port = 3000
    root_url = %(protocol)s://%(domain)s:%(http_port)s/
    serve_from_sub_path = false

    [database]
    type = sqlite3
    path = /var/lib/grafana/grafana.db

    [analytics]
    reporting_enabled = false
    check_for_updates = false
    check_for_plugin_updates = false

    [security]
    admin_user = admin
    admin_password = admin
    disable_gravatar = true

    [users]
    allow_sign_up = false
    auto_assign_org = true
    auto_assign_org_role = Editor

    [auth.anonymous]
    enabled = true
    org_name = Main Org.
    org_role = Viewer

    [log]
    mode = console
    level = info

    [log.console]
    format = json

    [paths]
    data = /var/lib/grafana
    logs = /var/log/grafana
    plugins = /var/lib/grafana/plugins
    provisioning = /etc/grafana/provisioning
  '';

  # Datasources provisioning
  datasourcesConfig = pkgs.writeText "datasources.yaml" ''
    apiVersion: 1
    datasources:
      - name: ClickHouse
        type: grafana-clickhouse-datasource
        access: proxy
        url: http://signoz-clickhouse:8123
        jsonData:
          defaultDatabase: signoz_traces
        isDefault: false

      - name: Tempo
        type: tempo
        access: proxy
        url: http://signoz-tempo:3200
        jsonData:
          httpMethod: GET
        isDefault: false

      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://signoz-otel-collector:8889
        isDefault: true
  '';

  # Dashboards provisioning
  dashboardsConfig = pkgs.writeText "dashboards.yaml" ''
    apiVersion: 1
    providers:
      - name: 'default'
        orgId: 1
        folder: ""
        type: file
        disableDeletion: false
        updateIntervalSeconds: 30
        options:
          path: /var/lib/grafana/dashboards
  '';

  # Health check script
  healthCheckScript = pkgs.writeShellScriptBin "health-check.sh" ''
    exec ${pkgs.curl}/bin/curl -sf http://localhost:3000/api/health || exit 1
  '';

  # Startup script
  startScript = pkgs.writeShellScriptBin "start-grafana.sh" ''
    #!/bin/bash
    set -e

    echo "Starting Grafana..."

    # Create necessary directories
    mkdir -p /var/lib/grafana/dashboards
    mkdir -p /var/lib/grafana/plugins
    mkdir -p /var/log/grafana

    # Start Grafana
    exec ${pkgs.grafana}/bin/grafana server \
      --homepath=${pkgs.grafana}/share/grafana \
      --config=/etc/grafana/grafana.ini
  '';

in pkgs.dockerTools.buildLayeredImage {
  name = "localhost/signoz-grafana";
  tag = "latest";

  contents = with pkgs; [
    grafana
    bash
    coreutils
    curl
    cacert
    healthCheckScript
    startScript
  ];

  extraCommands = ''
    # Create directory structure
    mkdir -p etc/grafana/provisioning/datasources
    mkdir -p etc/grafana/provisioning/dashboards
    mkdir -p var/lib/grafana/dashboards
    mkdir -p var/lib/grafana/plugins
    mkdir -p var/log/grafana
    mkdir -p tmp

    # Copy config files
    cp ${grafanaConfig} etc/grafana/grafana.ini
    cp ${datasourcesConfig} etc/grafana/provisioning/datasources/datasources.yaml
    cp ${dashboardsConfig} etc/grafana/provisioning/dashboards/dashboards.yaml

    # Set permissions
    chmod 755 var/lib/grafana
    chmod 755 var/log/grafana
    chmod 777 tmp
  '';

  config = {
    Cmd = ["${startScript}/bin/start-grafana.sh"];

    ExposedPorts = {
      "3000/tcp" = {};
    };

    Env = [
      "GF_PATHS_CONFIG=/etc/grafana/grafana.ini"
      "GF_PATHS_DATA=/var/lib/grafana"
      "GF_PATHS_LOGS=/var/log/grafana"
      "GF_PATHS_PLUGINS=/var/lib/grafana/plugins"
      "GF_PATHS_PROVISIONING=/etc/grafana/provisioning"
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
      "org.opencontainers.image.description" = "Grafana - NixOS";
      "indrajaal.component" = "observability";
      "indrajaal.subsystem" = "grafana";
    };

    WorkingDir = "/var/lib/grafana";
  };
}
