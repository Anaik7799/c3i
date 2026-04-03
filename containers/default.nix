{ pkgs ? import <nixpkgs> {} }:

let
  # Indrajaal Security Monitoring System Container Configuration
  # SOP v5.1 Cybernetic Goal-Oriented Execution Framework
  # Container-Only Infrastructure with PHICS Integration

  # Simplified approach: Build from scratch with NixOS packages
  # This avoids external registry dependencies and provides full control

  # Demo-specific environment variables
  demoEnv = {
    MIX_ENV = "demo";
    ELIXIR_ERL_OPTIONS = "+S 16";
    CONTAINER_ENFORCEMENT = "true";
    PHICS_ENABLED = "true";
    SOP_V51_MODE = "enabled";
    DEMO_MODE = "true";
  };

  # PostgreSQL Demo Container
  postgresContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-postgres-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      postgresql_17
      bash
      coreutils
      su
    ];
    
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
      
      Entrypoint = [ "postgres" ];
      
      Cmd = [ "-p" "5433" ];
    };
  };

  # Redis Demo Container
  redisContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-redis-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      redis
      bash
      coreutils
    ];
    
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
      
      Entrypoint = [ "redis-server" ];
      
      Cmd = [ "--port" "6379" ];
    };
  };

  # Elixir Application Demo Container
  appContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-app-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      elixir_1_18
      erlang_27
      postgresql
      git
      curl
      bash
      coreutils
    ];
    
    config = {
      Env = [
        "MIX_ENV=demo"
        "ELIXIR_ERL_OPTIONS=+S 16"
        "DATABASE_URL=postgres://postgres:postgres@postgres:5433/indrajaal_demo"
        "REDIS_URL=redis://redis:6379"
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
      
      Entrypoint = [ "bash" ];
      
      Cmd = [
        "-c"
        ''
          mix local.hex --force &&
          mix local.rebar --force &&
          mix deps.get &&
          mix ecto.setup &&
          mix phx.server
        ''
      ];
    };
  };

  # Prometheus Monitoring Container
  prometheusContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-prometheus-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      prometheus
    ];
    
    config = {
      Env = [
        "PROMETHEUS_CONFIG_FILE=/etc/prometheus/prometheus.yml"
      ];
      
      ExposedPorts = {
        "9090/tcp" = {};
      };
      
      Volumes = {
        "/etc/prometheus" = {};
        "/prometheus" = {};
      };
      
      WorkingDir = "/prometheus";
      
      Entrypoint = [ "prometheus" ];
      
      Cmd = [
        "--config.file=/etc/prometheus/prometheus.yml"
        "--storage.tsdb.path=/prometheus"
        "--web.console.libraries=/usr/share/prometheus/console_libraries"
        "--web.console.templates=/usr/share/prometheus/consoles"
        "--web.enable-lifecycle"
      ];
    };
  };

  # Grafana Dashboard Container
  grafanaContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-grafana-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      grafana
    ];
    
    config = {
      Env = [
        "GF_SECURITY_ADMIN_PASSWORD=demo_admin_password"
        "GF_USERS_ALLOW_SIGN_UP=false"
        "GF_PATHS_DATA=/var/lib/grafana"
        "GF_PATHS_LOGS=/var/log/grafana"
        "GF_PATHS_PLUGINS=/var/lib/grafana/plugins"
      ];
      
      ExposedPorts = {
        "3000/tcp" = {};
      };
      
      Volumes = {
        "/var/lib/grafana" = {};
        "/var/log/grafana" = {};
      };
      
      WorkingDir = "/var/lib/grafana";
      
      Entrypoint = [ "grafana-server" ];
      
      Cmd = [
        "--config=/etc/grafana/grafana.ini"
        "--homepath=/usr/share/grafana"
      ];
    };
  };

  # Nginx Reverse Proxy Container
  nginxContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-nginx-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      nginx
      openssl
    ];
    
    config = {
      Env = [
        "NGINX_CONFIG_FILE=/etc/nginx/nginx.conf"
      ];
      
      ExposedPorts = {
        "80/tcp" = {};
        "443/tcp" = {};
      };
      
      Volumes = {
        "/etc/nginx" = {};
        "/var/log/nginx" = {};
      };
      
      WorkingDir = "/etc/nginx";
      
      Entrypoint = [ "nginx" ];
      
      Cmd = [ "-g" "daemon off;" ];
    };
  };

in {
  # Container images for demo environment
  postgres = postgresContainer;
  redis = redisContainer;
  app = appContainer;
  prometheus = prometheusContainer;
  grafana = grafanaContainer;
  nginx = nginxContainer;
  
  # Demo environment configuration
  demoEnvironment = demoEnv;
  
  # Container build script
  buildScript = pkgs.writeScriptBin "build-demo-containers" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🐳 Building Indrajaal Demo Containers (SOP v5.1)"
    echo "================================================"
    
    # Build PostgreSQL container
    echo "Building PostgreSQL container..."
    nix-build -A postgres containers/default.nix
    podman load < result
    
    # Build Redis container
    echo "Building Redis container..."
    nix-build -A redis containers/default.nix
    podman load < result
    
    # Build Application container
    echo "Building Application container..."
    nix-build -A app containers/default.nix
    podman load < result
    
    # Build Monitoring containers
    echo "Building Prometheus container..."
    nix-build -A prometheus containers/default.nix
    podman load < result
    
    echo "Building Grafana container..."
    nix-build -A grafana containers/default.nix
    podman load < result
    
    # Build Nginx container
    echo "Building Nginx container..."
    nix-build -A nginx containers/default.nix
    podman load < result
    
    echo "✅ All demo containers built successfully"
    echo "🚀 Ready for comprehensive demo execution"
  '';
  
  # Demo startup script
  startScript = pkgs.writeScriptBin "start-demo-environment" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🚀 Starting Indrajaal Demo Environment (SOP v5.1)"
    echo "================================================="
    
    # Start using podman-compose  # ✅ MANDATORY: Docker-compose equivalent using Podman
    podman-compose  # ✅ MANDATORY: Docker-compose equivalent using Podman -f podman-compose  # ✅ MANDATORY: Docker-compose equivalent using Podman.yml up -d
    
    echo "✅ Demo environment started successfully"
    echo "📊 Access points:"
    echo "  - Application: http://localhost:4000"
    echo "  - Grafana: http://localhost:3000 (admin/demo_admin_password)"
    echo "  - Prometheus: http://localhost:9090"
  '';
}