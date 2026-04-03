{ pkgs ? import <nixpkgs> {} }:

let
  # Working NixOS Container Configuration 
  # Based on successful patterns from existing containers
  # Pure NixOS-Only Infrastructure with embedded configurations

  # Create monitoring configuration files
  prometheusConfigFile = pkgs.writeTextFile {
    name = "prometheus.yml";
    text = ''
      global:
        scrape_interval: 15s
        evaluation_interval: 15s

      scrape_configs:
        - job_name: 'prometheus'
          static_configs:
            - targets: ['localhost:9090']

        - job_name: 'indrajaal-app'
          static_configs:
            - targets: ['indrajaal-app-demo:4000']
          metrics_path: '/metrics'

        - job_name: 'postgresql'
          static_configs:
            - targets: ['indrajaal-postgres-demo:5433']

        - job_name: 'redis'
          static_configs:
            - targets: ['indrajaal-redis-demo:6379']
    '';
  };

  grafanaConfigFile = pkgs.writeTextFile {
    name = "grafana.ini";
    text = ''
      [server]
      http_addr = 0.0.0.0
      http_port = 3000
      domain = localhost

      [security]
      admin_user = admin
      admin_password = demo_admin_password

      [users]
      allow_sign_up = false

      [auth.anonymous]
      enabled = false

      [database]
      type = sqlite3
      path = /var/lib/grafana/grafana.db

      [paths]
      data = /var/lib/grafana
      logs = /var/lib/grafana/logs
      plugins = /var/lib/grafana/plugins
    '';
  };

  nginxConfigFile = pkgs.writeTextFile {
    name = "nginx.conf";
    text = ''
      events {
          worker_connections 1024;
      }

      http {
          upstream indrajaal_app {
              server indrajaal-app-demo:4000;
          }

          server {
              listen 80;
              server_name localhost;

              location / {
                  proxy_pass http://indrajaal_app;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              }

              location /health {
                  proxy_pass http://indrajaal_app/health;
              }
          }
      }
    '';
  };

in {
  # Working PostgreSQL Container (Simplified)
  postgres = pkgs.dockerTools.buildImage {
    name = "indrajaal-postgres-demo";
    tag = "nixos-devenv";
    
    copyToRoot = pkgs.buildEnv {
      name = "postgres-env";
      paths = with pkgs; [
        postgresql_17
        bash
        coreutils
      ];
    };
    
    config = {
      Env = [
        "POSTGRES_DB=indrajaal_demo"
        "POSTGRES_USER=postgres"
        "POSTGRES_PASSWORD=postgres"
        "PGPORT=5433"
        "PGDATA=/var/lib/postgresql/data"
      ];
      
      ExposedPorts = {
        "5433/tcp" = {};
      };
      
      Volumes = {
        "/var/lib/postgresql/data" = {};
      };
      
      WorkingDir = "/var/lib/postgresql";
      
      Entrypoint = [ "${pkgs.bash}/bin/bash" ];
      Cmd = [ "-c" "mkdir -p /var/lib/postgresql/data && if [ ! -f /var/lib/postgresql/data/postgresql.conf ]; then ${pkgs.postgresql_17}/bin/initdb -D /var/lib/postgresql/data --auth-local=trust --auth-host=md5; fi && ${pkgs.postgresql_17}/bin/postgres -D /var/lib/postgresql/data -p 5433" ];
    };
  };

  # Working Redis Container
  redis = pkgs.dockerTools.buildImage {
    name = "indrajaal-redis-demo";
    tag = "nixos-devenv";
    
    copyToRoot = pkgs.buildEnv {
      name = "redis-env";
      paths = with pkgs; [
        redis
        bash
        coreutils
      ];
    };
    
    config = {
      Env = [
        "REDIS_PORT=6379"
      ];
      
      ExposedPorts = {
        "6379/tcp" = {};
      };
      
      Volumes = {
        "/data" = {};
      };
      
      WorkingDir = "/data";
      
      Entrypoint = [ "${pkgs.redis}/bin/redis-server" ];
      Cmd = [ "--port" "6379" "--dir" "/data" ];
    };
  };

  # Working Elixir Application Container
  app = pkgs.dockerTools.buildImage {
    name = "indrajaal-app-demo";
    tag = "nixos-devenv";
    
    copyToRoot = pkgs.buildEnv {
      name = "elixir-env";
      paths = with pkgs; [
        elixir_1_18
        erlang_27
        postgresql  # Client tools
        git
        curl
        bash
        coreutils
        gnumake
        gcc
      ];
    };
    
    config = {
      Env = [
        "MIX_ENV=demo"
        "ELIXIR_ERL_OPTIONS=+S 16"
        "DATABASE_URL=postgres://postgres:postgres@indrajaal-postgres-demo:5433/indrajaal_demo"
        "REDIS_URL=redis://indrajaal-redis-demo:6379"
        "PHX_HOST=0.0.0.0"
        "PHX_PORT=4000"
        "CONTAINER_ENFORCEMENT=true"
        "PHICS_ENABLED=true"
        "SOP_V51_MODE=enabled"
      ];
      
      ExposedPorts = {
        "4000/tcp" = {};
        "4001/tcp" = {};
      };
      
      Volumes = {
        "/workspace" = {};
        "/workspace/deps" = {};
        "/workspace/_build" = {};
      };
      
      WorkingDir = "/workspace";
      
      Entrypoint = [ "${pkgs.bash}/bin/bash" ];
      Cmd = [ "-c" "mix local.hex --force && mix local.rebar --force && mix deps.get && mix ecto.setup && mix phx.server" ];
    };
  };

  # Working Prometheus Container with Configuration
  prometheus = pkgs.dockerTools.buildImage {
    name = "indrajaal-prometheus-demo";
    tag = "nixos-devenv";
    
    copyToRoot = pkgs.buildEnv {
      name = "prometheus-env";
      paths = with pkgs; [
        prometheus
        bash
        coreutils
        (pkgs.runCommand "prometheus-config" {} ''
          mkdir -p $out/etc/prometheus
          cp ${prometheusConfigFile} $out/etc/prometheus/prometheus.yml
        '')
      ];
    };
    
    config = {
      Env = [
        "PROMETHEUS_CONFIG_FILE=/etc/prometheus/prometheus.yml"
      ];
      
      ExposedPorts = {
        "9090/tcp" = {};
      };
      
      Volumes = {
        "/prometheus" = {};
      };
      
      WorkingDir = "/prometheus";
      
      Entrypoint = [ "${pkgs.prometheus}/bin/prometheus" ];
      Cmd = [
        "--config.file=/etc/prometheus/prometheus.yml"
        "--storage.tsdb.path=/prometheus"
        "--web.console.libraries=/usr/share/prometheus/console_libraries"
        "--web.console.templates=/usr/share/prometheus/consoles"
        "--web.enable-lifecycle"
        "--web.listen-address=0.0.0.0:9090"
      ];
    };
  };

  # Working Grafana Container with Configuration
  grafana = pkgs.dockerTools.buildImage {
    name = "indrajaal-grafana-demo";
    tag = "nixos-devenv";
    
    copyToRoot = pkgs.buildEnv {
      name = "grafana-env";
      paths = with pkgs; [
        grafana
        bash
        coreutils
        (pkgs.runCommand "grafana-config" {} ''
          mkdir -p $out/etc/grafana
          cp ${grafanaConfigFile} $out/etc/grafana/grafana.ini
        '')
      ];
    };
    
    config = {
      Env = [
        "GF_SECURITY_ADMIN_PASSWORD=demo_admin_password"
        "GF_USERS_ALLOW_SIGN_UP=false"
        "GF_PATHS_DATA=/var/lib/grafana"
        "GF_PATHS_LOGS=/var/lib/grafana/logs"
        "GF_PATHS_PLUGINS=/var/lib/grafana/plugins"
        "GF_PATHS_CONFIG=/etc/grafana/grafana.ini"
      ];
      
      ExposedPorts = {
        "3000/tcp" = {};
      };
      
      Volumes = {
        "/var/lib/grafana" = {};
      };
      
      WorkingDir = "/var/lib/grafana";
      
      Entrypoint = [ "${pkgs.grafana}/bin/grafana-server" ];
      Cmd = [
        "--config=/etc/grafana/grafana.ini"
        "--homepath=${pkgs.grafana}/share/grafana"
      ];
    };
  };

  # Working Nginx Container with Configuration
  nginx = pkgs.dockerTools.buildImage {
    name = "indrajaal-nginx-demo";
    tag = "nixos-devenv";
    
    copyToRoot = pkgs.buildEnv {
      name = "nginx-env";
      paths = with pkgs; [
        nginx
        bash
        coreutils
        (pkgs.runCommand "nginx-config" {} ''
          mkdir -p $out/etc/nginx
          cp ${nginxConfigFile} $out/etc/nginx/nginx.conf
        '')
      ];
    };
    
    config = {
      Env = [
        "NGINX_CONFIG_FILE=/etc/nginx/nginx.conf"
      ];
      
      ExposedPorts = {
        "80/tcp" = {};
        "443/tcp" = {};
      };
      
      Volumes = {
        "/var/log/nginx" = {};
      };
      
      WorkingDir = "/etc/nginx";
      
      Entrypoint = [ "${pkgs.nginx}/bin/nginx" ];
      Cmd = [ "-g" "daemon off;" ];
    };
  };

  # Build script for all containers
  buildScript = pkgs.writeScriptBin "build-working-nixos-containers" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🐳 Building Working NixOS Demo Containers"
    echo "=========================================="
    
    echo "Building PostgreSQL container..."
    nix-build -A postgres containers/working-nixos.nix
    podman load < result
    
    echo "Building Redis container..."
    nix-build -A redis containers/working-nixos.nix
    podman load < result
    
    echo "Building Elixir Application container..."
    nix-build -A app containers/working-nixos.nix
    podman load < result
    
    echo "Building Prometheus container..."
    nix-build -A prometheus containers/working-nixos.nix
    podman load < result
    
    echo "Building Grafana container..."
    nix-build -A grafana containers/working-nixos.nix
    podman load < result
    
    echo "Building Nginx container..."
    nix-build -A nginx containers/working-nixos.nix
    podman load < result
    
    echo "✅ All working NixOS containers built successfully"
    echo "🚀 Ready for pure NixOS demo execution"
  '';
}