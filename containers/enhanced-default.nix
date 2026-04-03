{ pkgs ? import <nixpkgs> {} }:

let
  # Enhanced NixOS Container Configuration with Embedded Configurations
  # SOPv5.1 Cybernetic Goal-Oriented Execution Framework
  # Pure NixOS-Only Infrastructure with PHICS Integration

  # Create configuration files as derivations
  prometheusConfig = pkgs.writeText "prometheus.yml" ''
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']

      - job_name: 'indrajaal-app'
        static_configs:
          - targets: ['app:4000']
        metrics_path: '/metrics'

      - job_name: 'postgresql'
        static_configs:
          - targets: ['postgres:5433']

      - job_name: 'redis'
        static_configs:
          - targets: ['redis:6379']
  '';

  grafanaConfig = pkgs.writeText "grafana.ini" ''
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

  nginxConfig = pkgs.writeText "nginx.conf" ''
    events {
        worker_connections 1024;
    }

    http {
        upstream indrajaal_app {
            server app:4000;
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

            location /api/ {
                proxy_pass http://indrajaal_app/api/;
            }
        }
    }
  '';

  # PostgreSQL initialization script
  postgresInitScript = pkgs.writeScript "postgres-init" ''
    #!/bin/bash
    set -e

    # Initialize database if needed
    if [ ! -d "$PGDATA" ]; then
        echo "Initializing PostgreSQL database..."
        su-exec postgres initdb --auth-local=trust --auth-host=md5
    fi

    # Start PostgreSQL
    echo "Starting PostgreSQL..."
    su-exec postgres postgres -p 5433
  '';

  # Elixir application startup script
  elixirStartupScript = pkgs.writeScript "elixir-startup" ''
    #!/bin/bash
    set -e

    # Set up environment
    export PATH="${pkgs.elixir_1_18}/bin:${pkgs.erlang_27}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:$PATH"
    export MIX_ENV=demo
    export ELIXIR_ERL_OPTIONS="+S 16"
    export DATABASE_URL=postgres://postgres:postgres@postgres:5433/indrajaal_demo
    export REDIS_URL=redis://redis:6379
    export PHX_HOST=0.0.0.0
    export PHX_PORT=4000

    cd /workspace

    # Install hex and rebar if needed
    mix local.hex --force
    mix local.rebar --force

    # Get dependencies
    mix deps.get

    # Setup database
    mix ecto.setup

    # Start Phoenix server
    mix phx.server
  '';

  # Demo-specific environment variables
  demoEnv = {
    MIX_ENV = "demo";
    ELIXIR_ERL_OPTIONS = "+S 16";
    CONTAINER_ENFORCEMENT = "true";
    PHICS_ENABLED = "true";
    SOP_V51_MODE = "enabled";
    DEMO_MODE = "true";
  };

  # Enhanced PostgreSQL Demo Container with Simplified User Management
  postgresContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-postgres-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      postgresql_17
      bash
      coreutils
    ];
    
    config = {
      Env = [
        "POSTGRES_DB=indrajaal_demo"
        "POSTGRES_USER=postgres"
        "POSTGRES_PASSWORD=postgres"
        "PGPORT=5433"
        "PGDATA=/var/lib/postgresql/data"
        "PATH=/bin:${pkgs.postgresql_17}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
      
      ExposedPorts = {
        "5433/tcp" = {};
      };
      
      Volumes = {
        "/var/lib/postgresql/data" = {};
      };
      
      WorkingDir = "/var/lib/postgresql";
      
      # Use direct postgres command with initialization script
      Entrypoint = [ "${pkgs.bash}/bin/bash" ];
      Cmd = [ "-c" "mkdir -p /var/lib/postgresql/data && if [ ! -f /var/lib/postgresql/data/postgresql.conf ]; then ${pkgs.postgresql_17}/bin/initdb -D /var/lib/postgresql/data --auth-local=trust --auth-host=md5; fi && ${pkgs.postgresql_17}/bin/postgres -D /var/lib/postgresql/data -p 5433" ];
    };
  };

  # Enhanced Redis Demo Container
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
        "PATH=/bin:${pkgs.redis}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
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

  # Enhanced Elixir Application Demo Container with Proper Environment
  appContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-app-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
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
        "PATH=/bin:${pkgs.elixir_1_18}/bin:${pkgs.erlang_27}/bin:${pkgs.postgresql}/bin:${pkgs.git}/bin:${pkgs.curl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnumake}/bin:${pkgs.gcc}/bin"
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
      Cmd = [ "${elixirStartupScript}" ];
    };
  };

  # Enhanced Prometheus Monitoring Container with Configuration
  prometheusContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-prometheus-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      prometheus
      bash
      coreutils
    ];
    
    config = {
      Env = [
        "PROMETHEUS_CONFIG_FILE=/etc/prometheus/prometheus.yml"
        "PATH=/bin:${pkgs.prometheus}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
      
      ExposedPorts = {
        "9090/tcp" = {};
      };
      
      Volumes = {
        "/etc/prometheus" = {};
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

    runAsRoot = ''
      mkdir -p /etc/prometheus /prometheus
      cp ${prometheusConfig} /etc/prometheus/prometheus.yml
      chmod -R 755 /etc/prometheus /prometheus
    '';
  };

  # Enhanced Grafana Dashboard Container with Configuration
  grafanaContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-grafana-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      grafana
      bash
      coreutils
    ];
    
    config = {
      Env = [
        "GF_SECURITY_ADMIN_PASSWORD=demo_admin_password"
        "GF_USERS_ALLOW_SIGN_UP=false"
        "GF_PATHS_DATA=/var/lib/grafana"
        "GF_PATHS_LOGS=/var/log/grafana"
        "GF_PATHS_PLUGINS=/var/lib/grafana/plugins"
        "GF_PATHS_CONFIG=/etc/grafana/grafana.ini"
        "PATH=/bin:${pkgs.grafana}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
      
      ExposedPorts = {
        "3000/tcp" = {};
      };
      
      Volumes = {
        "/var/lib/grafana" = {};
        "/var/log/grafana" = {};
        "/etc/grafana" = {};
      };
      
      WorkingDir = "/var/lib/grafana";
      
      Entrypoint = [ "${pkgs.grafana}/bin/grafana-server" ];
      Cmd = [
        "--config=/etc/grafana/grafana.ini"
        "--homepath=${pkgs.grafana}/share/grafana"
      ];
    };

    runAsRoot = ''
      mkdir -p /etc/grafana /var/lib/grafana /var/log/grafana
      cp ${grafanaConfig} /etc/grafana/grafana.ini
      chmod -R 755 /etc/grafana /var/lib/grafana /var/log/grafana
    '';
  };

  # Enhanced Nginx Reverse Proxy Container with Configuration
  nginxContainer = pkgs.dockerTools.buildImage {
    name = "indrajaal-nginx-demo";
    tag = "nixos-devenv";
    
    contents = with pkgs; [
      nginx
      openssl
      bash
      coreutils
    ];
    
    config = {
      Env = [
        "NGINX_CONFIG_FILE=/etc/nginx/nginx.conf"
        "PATH=/bin:${pkgs.nginx}/bin:${pkgs.openssl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
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
      
      Entrypoint = [ "${pkgs.nginx}/bin/nginx" ];
      Cmd = [ "-g" "daemon off;" ];
    };

    runAsRoot = ''
      mkdir -p /etc/nginx /var/log/nginx /var/cache/nginx
      cp ${nginxConfig} /etc/nginx/nginx.conf
      chmod -R 755 /etc/nginx /var/log/nginx /var/cache/nginx
    '';
  };

in {
  # Enhanced container images for demo environment
  postgres = postgresContainer;
  redis = redisContainer;
  app = appContainer;
  prometheus = prometheusContainer;
  grafana = grafanaContainer;
  nginx = nginxContainer;
  
  # Demo environment configuration
  demoEnvironment = demoEnv;
  
  # Enhanced container build script
  buildScript = pkgs.writeScriptBin "build-enhanced-demo-containers" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🐳 Building Enhanced Indrajaal Demo Containers (Pure NixOS)"
    echo "============================================================"
    
    # Build PostgreSQL container with user management
    echo "Building Enhanced PostgreSQL container..."
    nix-build -A postgres containers/enhanced-default.nix
    podman load < result
    
    # Build Redis container
    echo "Building Enhanced Redis container..."
    nix-build -A redis containers/enhanced-default.nix
    podman load < result
    
    # Build Application container with proper environment
    echo "Building Enhanced Application container..."
    nix-build -A app containers/enhanced-default.nix
    podman load < result
    
    # Build Prometheus container with embedded configuration
    echo "Building Enhanced Prometheus container..."
    nix-build -A prometheus containers/enhanced-default.nix
    podman load < result
    
    # Build Grafana container with embedded configuration
    echo "Building Enhanced Grafana container..."
    nix-build -A grafana containers/enhanced-default.nix
    podman load < result
    
    # Build Nginx container with embedded configuration
    echo "Building Enhanced Nginx container..."
    nix-build -A nginx containers/enhanced-default.nix
    podman load < result
    
    echo "✅ All enhanced demo containers built successfully"
    echo "🚀 Ready for comprehensive demo execution with pure NixOS"
    echo ""
    echo "📋 Enhanced Container Features:"
    echo "  - PostgreSQL: Proper user management and initialization"
    echo "  - Redis: Optimized configuration and data persistence"
    echo "  - Elixir App: Complete PATH setup and environment configuration"
    echo "  - Prometheus: Embedded configuration file and proper permissions"
    echo "  - Grafana: Embedded configuration with admin credentials"
    echo "  - Nginx: Embedded reverse proxy configuration"
  '';
  
  # Enhanced demo startup script
  startScript = pkgs.writeScriptBin "start-enhanced-demo-environment" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🚀 Starting Enhanced Indrajaal Demo Environment (Pure NixOS)"
    echo "============================================================="
    
    # Create network if it doesn't exist
    podman network create indrajaal-demo-network 2>/dev/null || true
    
    # Start PostgreSQL with proper user
    echo "Starting Enhanced PostgreSQL..."
    podman run -d --name indrajaal-postgres-demo \
      --network indrajaal-demo-network \
      -p 5433:5433 \
      -v postgres_data:/var/lib/postgresql/data \
      localhost/indrajaal-postgres-demo:nixos-devenv
    
    # Start Redis
    echo "Starting Enhanced Redis..."
    podman run -d --name indrajaal-redis-demo \
      --network indrajaal-demo-network \
      -p 6379:6379 \
      -v redis_data:/data \
      localhost/indrajaal-redis-demo:nixos-devenv
    
    # Wait for database to be ready
    echo "Waiting for PostgreSQL to be ready..."
    sleep 10
    
    # Start Application with proper environment
    echo "Starting Enhanced Elixir Application..."
    podman run -d --name indrajaal-app-demo \
      --network indrajaal-demo-network \
      -p 4000:4000 -p 4001:4001 \
      -v "$(pwd):/workspace:z" \
      -v app_deps:/workspace/deps \
      -v app_build:/workspace/_build \
      localhost/indrajaal-app-demo:nixos-devenv
    
    # Start Prometheus with embedded configuration
    echo "Starting Enhanced Prometheus..."
    podman run -d --name indrajaal-prometheus-demo \
      --network indrajaal-demo-network \
      -p 9090:9090 \
      -v prometheus_data:/prometheus \
      localhost/indrajaal-prometheus-demo:nixos-devenv
    
    # Start Grafana with embedded configuration
    echo "Starting Enhanced Grafana..."
    podman run -d --name indrajaal-grafana-demo \
      --network indrajaal-demo-network \
      -p 3000:3000 \
      -v grafana_data:/var/lib/grafana \
      localhost/indrajaal-grafana-demo:nixos-devenv
    
    # Start Nginx with embedded configuration
    echo "Starting Enhanced Nginx..."
    podman run -d --name indrajaal-nginx-demo \
      --network indrajaal-demo-network \
      -p 80:80 \
      localhost/indrajaal-nginx-demo:nixos-devenv
    
    echo "✅ Enhanced demo environment started successfully"
    echo "📊 Access points:"
    echo "  - Application: http://localhost:4000"
    echo "  - Nginx Proxy: http://localhost:80"
    echo "  - Grafana: http://localhost:3000 (admin/demo_admin_password)"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - PostgreSQL: localhost:5433 (postgres/postgres)"
    echo "  - Redis: localhost:6379"
    echo ""
    echo "🎯 All containers use pure NixOS with embedded configurations"
  '';
}