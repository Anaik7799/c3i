{
  description = "Indrajaal SIL-6 Observability Container";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };

      # In a real offline Nix environment, we would use buildDotnetModule and fetch deps.
      # For this container generation, we construct the image declaratively.
      # Config files as a separate derivation — Nix merges into container layer
      obsConfigs = pkgs.runCommand "obs-configs" {} ''
        # Prometheus config
        mkdir -p $out/etc/prometheus
        cat > $out/etc/prometheus/prometheus.yml << 'PROMEOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['localhost:8888']
  - job_name: 'indrajaal-app'
    static_configs:
      - targets: ['172.28.0.10:4001']
    metrics_path: '/metrics'
PROMEOF

        # Grafana config
        mkdir -p $out/etc/grafana/provisioning/datasources
        cat > $out/etc/grafana/grafana.ini << 'GRAFEOF'
[server]
http_port = 3000
[security]
admin_user = admin
admin_password = indrajaal
[paths]
data = /var/lib/grafana
logs = /var/lib/grafana/log
plugins = /var/lib/grafana/plugins
provisioning = /etc/grafana/provisioning
[log]
mode = console
level = info
GRAFEOF
        cat > $out/etc/grafana/provisioning/datasources/prometheus.yml << 'DSEOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: true
DSEOF

        # OTEL Collector config
        mkdir -p $out/etc/otel-collector
        cat > $out/etc/otel-collector/config.yaml << 'OTELEOF'
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
processors:
  batch:
    timeout: 5s
    send_batch_size: 256
exporters:
  debug:
    verbosity: basic
  prometheus:
    endpoint: 0.0.0.0:8888
    namespace: indrajaal
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus]
OTELEOF

        # Runtime data directories (pre-created with correct permissions)
        mkdir -p $out/tmp
        chmod 1777 $out/tmp
        mkdir -p $out/var/lib/grafana/log
        mkdir -p $out/var/lib/grafana/plugins
        chmod -R 777 $out/var/lib/grafana
        mkdir -p $out/prometheus
        chmod 777 $out/prometheus
      '';
    in
    {
      packages.${system}.default = pkgs.dockerTools.buildLayeredImage {
        name = "localhost/indrajaal-obs-unified";
        tag = "nixos-native";
        contents = [
          obsConfigs
        ] ++ (with pkgs; [
          tini
          prometheus
          grafana
          clickhouse
          opentelemetry-collector
          dotnet-sdk_10
          bash
          coreutils
          curl
          netcat
          findutils
          gnugrep
          procps
        ]);

        config = {
          Entrypoint = [ "${pkgs.tini}/bin/tini" "--" ];
          Cmd = [ "${pkgs.bash}/bin/bash" "-c" "export HOME=/tmp && export DOTNET_CLI_HOME=/tmp && cd /workspace/lib/cepaf/src/Cepaf.ObsSupervisor && dotnet exec bin/Release/net10.0/Cepaf.ObsSupervisor.dll" ];
          Env = [
            "PATH=${pkgs.tini}/bin:${pkgs.prometheus}/bin:${pkgs.grafana}/bin:${pkgs.clickhouse}/bin:${pkgs.opentelemetry-collector}/bin:${pkgs.dotnet-sdk_10}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:$PATH"
            "DOTNET_ROOT=${pkgs.dotnet-sdk_10}"
            "DOTNET_RUNNING_IN_CONTAINER=true"
            "DOTNET_CLI_TELEMETRY_OPTOUT=1"
            "DOTNET_NOLOGO=1"
            "DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1"
            "DOTNET_CLI_HOME=/tmp"
            "HOME=/tmp"
            "GF_PATHS_HOME=${pkgs.grafana}/share/grafana"
          ];
          WorkingDir = "/workspace";
        };
      };
    };
}