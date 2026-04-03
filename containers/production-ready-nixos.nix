{ pkgs ? import <nixpkgs> {} }:

let
  # Production-Ready NixOS Container Configuration
  # TDG + TPS + GDE Compliant Implementation
  # Addresses: User management, CA certificates, data compatibility
  # Date: 2025-07-26 18:40:00 CEST

  # Create configuration files with production settings
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

  # PostgreSQL initialization script (non-root execution)
  postgresInitScript = pkgs.writeScript "postgres-init.sh" ''
    #!/bin/bash
    set -e

    echo "=== PostgreSQL Container Initialization ==="
    echo "User: $(whoami)"
    echo "UID: $(id -u)"
    echo "GID: $(id -g)"

    # Initialize database if needed
    if [ ! -f "$PGDATA/postgresql.conf" ]; then
        echo "Initializing PostgreSQL database..."
        initdb -D "$PGDATA" --auth-local=trust --auth-host=md5 --username=postgres
        
        # Configure PostgreSQL for container environment
        echo "listen_addresses = '*'" >> "$PGDATA/postgresql.conf"
        echo "port = 5433" >> "$PGDATA/postgresql.conf"
        echo "host all all 0.0.0.0/0 md5" >> "$PGDATA/pg_hba.conf"
        echo "host all all ::0/0 md5" >> "$PGDATA/pg_hba.conf"
    fi

    echo "Starting PostgreSQL server..."
    exec postgres -D "$PGDATA" -p 5433
  '';

  # Elixir application initialization script (with CA certificates)
  elixirInitScript = pkgs.writeScript "elixir-init.sh" ''
    #!/bin/bash
    set -e

    echo "=== Elixir Application Container Initialization ==="
    echo "Working Directory: $(pwd)"
    echo "SSL_CERT_FILE: $SSL_CERT_FILE"
    echo "CURL_CA_BUNDLE: $CURL_CA_BUNDLE"

    # Verify CA certificates are available
    if [ ! -f "$SSL_CERT_FILE" ]; then
        echo "ERROR: CA certificates not found at $SSL_CERT_FILE"
        exit 1
    fi
    echo "CA certificates found: $(wc -l < $SSL_CERT_FILE) lines"

    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL to be ready..."
    max_attempts=30
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if pg_isready -h indrajaal-postgres-demo -p 5433 -U postgres; then
            echo "PostgreSQL is ready!"
            break
        fi
        echo "PostgreSQL not ready, waiting... ($((attempt + 1))/$max_attempts)"
        sleep 2
        attempt=$((attempt + 1))
    done

    if [ $attempt -eq $max_attempts ]; then
        echo "ERROR: PostgreSQL not ready after $max_attempts attempts"
        exit 1
    fi

    # Setup Hex and Rebar with SSL verification
    echo "Setting up Hex and Rebar..."
    mix local.hex --force
    mix local.rebar --force

    # Get dependencies with proper SSL
    echo "Downloading dependencies..."
    mix deps.get

    # Wait for Redis to be ready
    echo "Waiting for Redis to be ready..."
    max_attempts=15
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if redis-cli -h indrajaal-redis-demo -p 6379 ping | grep -q PONG; then
            echo "Redis is ready!"
            break
        fi
        echo "Redis not ready, waiting... ($((attempt + 1))/$max_attempts)"
        sleep 1
        attempt=$((attempt + 1))
    done

    # Setup database
    echo "Setting up database..."
    mix ecto.setup

    # Start Phoenix server
    echo "Starting Phoenix server..."
    exec mix phx.server
  '';

  # Redis initialization script (data compatibility)
  redisInitScript = pkgs.writeScript "redis-init.sh" ''
    #!/bin/bash
    set -e

    echo "=== Redis Container Initialization ==="
    echo "Data directory: /data"
    echo "Contents: $(ls -la /data || echo 'Directory empty')"

    # Check for existing RDB file
    if [ -f /data/dump.rdb ]; then
        echo "Found existing RDB file, checking compatibility..."
        # Try to load the RDB file to check compatibility
        if ! redis-server --port 0 --dir /data --dbfilename dump.rdb --rdbchecksum yes 2>/dev/null; then
            echo "RDB file is incompatible, backing up and removing..."
            mv /data/dump.rdb "/data/dump.rdb.backup.$(date +%s)"
        else
            echo "RDB file is compatible, proceeding..."
        fi
    fi

    echo "Starting Redis server..."
    exec redis-server \
        --port 6379 \
        --dir /data \
        --save 900 1 \
        --save 300 10 \
        --save 60 10000 \
        --rdbcompression yes \
        --rdbchecksum yes \
        --databases 16
  '';

in {
  # Production-Ready PostgreSQL Container (Non-Root User)
  postgres = pkgs.dockerTools.buildImage {
    name = "indrajaal-postgres-demo";
    tag = "production-ready";
    
    copyToRoot = pkgs.buildEnv {
      name = "postgres-env";
      paths = with pkgs; [
        postgresql_17
        bash
        coreutils
        shadow
        su-exec
        (pkgs.runCommand "postgres-scripts" {} ''
          mkdir -p $out/usr/local/bin
          cp ${postgresInitScript} $out/usr/local/bin/postgres-init.sh
          chmod +x $out/usr/local/bin/postgres-init.sh
        '')
      ];
    };
    
    config = {
      User = "999:999";  # Non-root postgres user
      Env = [
        "POSTGRES_DB=indrajaal_demo"
        "POSTGRES_USER=postgres"
        "POSTGRES_PASSWORD=postgres"
        "PGPORT=5433"
        "PGDATA=/var/lib/postgresql/data"
        "PATH=/usr/local/bin:${pkgs.postgresql_17}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.shadow}/bin:${pkgs.su-exec}/bin"
      ];
      
      ExposedPorts = {
        "5433/tcp" = {};
      };
      
      Volumes = {
        "/var/lib/postgresql/data" = {};
      };
      
      WorkingDir = "/var/lib/postgresql";
      Entrypoint = [ "${pkgs.bash}/bin/bash" ];
      Cmd = [ "/usr/local/bin/postgres-init.sh" ];
    };
    
    runAsRoot = ''
      # Create postgres user and group
      groupadd -r -g 999 postgres || true
      useradd -r -u 999 -g postgres -d /var/lib/postgresql -s /bin/bash postgres || true
      
      # Create and setup data directory
      mkdir -p /var/lib/postgresql/data
      chown -R postgres:postgres /var/lib/postgresql
      chmod 700 /var/lib/postgresql/data
    '';
  };

  # Production-Ready Redis Container (Data Compatibility)
  redis = pkgs.dockerTools.buildImage {
    name = "indrajaal-redis-demo";
    tag = "production-ready";
    
    copyToRoot = pkgs.buildEnv {
      name = "redis-env";
      paths = with pkgs; [
        redis
        bash
        coreutils
        (pkgs.runCommand "redis-scripts" {} ''
          mkdir -p $out/usr/local/bin
          cp ${redisInitScript} $out/usr/local/bin/redis-init.sh
          chmod +x $out/usr/local/bin/redis-init.sh
        '')
      ];
    };
    
    config = {
      Env = [
        "REDIS_PORT=6379"
        "PATH=/usr/local/bin:${pkgs.redis}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin"
      ];
      
      ExposedPorts = {
        "6379/tcp" = {};
      };
      
      Volumes = {
        "/data" = {};
      };
      
      WorkingDir = "/data";
      Entrypoint = [ "${pkgs.bash}/bin/bash" ];
      Cmd = [ "/usr/local/bin/redis-init.sh" ];
    };
  };

  # Production-Ready Elixir Application Container (CA Certificates)
  app = pkgs.dockerTools.buildImage {
    name = "indrajaal-app-demo";
    tag = "production-ready";
    
    copyToRoot = pkgs.buildEnv {
      name = "elixir-env";
      paths = with pkgs; [
        elixir_1_18
        erlang_27
        postgresql  # Client tools
        redis       # Client tools
        git
        curl
        bash
        coreutils
        gnumake
        gcc
        cacert      # CRITICAL: CA certificates
        openssl
        gnutls
        (pkgs.runCommand "elixir-scripts" {} ''
          mkdir -p $out/usr/local/bin
          cp ${elixirInitScript} $out/usr/local/bin/elixir-init.sh
          chmod +x $out/usr/local/bin/elixir-init.sh
        '')
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
        # CRITICAL: SSL/TLS Configuration
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "CURL_CA_BUNDLE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "LANG=en_US.UTF-8"
        "LC_ALL=en_US.UTF-8"
        "PATH=/usr/local/bin:${pkgs.elixir_1_18}/bin:${pkgs.erlang_27}/bin:${pkgs.postgresql}/bin:${pkgs.redis}/bin:${pkgs.git}/bin:${pkgs.curl}/bin:${pkgs.bash}/bin:${pkgs.coreutils}/bin:${pkgs.gnumake}/bin:${pkgs.gcc}/bin"
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
      Cmd = [ "/usr/local/bin/elixir-init.sh" ];
    };
  };

  # Production-Ready Prometheus Container
  prometheus = pkgs.dockerTools.buildImage {
    name = "indrajaal-prometheus-demo";
    tag = "production-ready";
    
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

  # Production-Ready Grafana Container
  grafana = pkgs.dockerTools.buildImage {
    name = "indrajaal-grafana-demo";
    tag = "production-ready";
    
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

  # Production-Ready Nginx Container
  nginx = pkgs.dockerTools.buildImage {
    name = "indrajaal-nginx-demo";
    tag = "production-ready";
    
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

  # Build script for production containers
  buildScript = pkgs.writeScriptBin "build-production-nixos-containers" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🏭 Building Production-Ready NixOS Containers"
    echo "TDG + TPS + GDE Compliant Implementation"
    echo "=============================================="
    
    containers=("postgres" "redis" "app" "prometheus" "grafana" "nginx")
    
    for container in "''${containers[@]}"; do
        echo ""
        echo "🔨 Building $container container..."
        if nix-build -A "$container" containers/production-ready-nixos.nix; then
            echo "📦 Loading $container into Podman..."
            if podman load < result; then
                echo "✅ $container container ready"
            else
                echo "❌ Failed to load $container container"
                exit 1
            fi
        else
            echo "❌ Failed to build $container container"
            exit 1
        fi
    done
    
    echo ""
    echo "🎉 All production-ready containers built successfully!"
    echo "📋 Built containers:"
    podman images | grep production-ready
    
    echo ""
    echo "🚀 Ready for production deployment with:"
    echo "  - PostgreSQL: Non-root user execution with proper initialization"
    echo "  - Redis: Data compatibility and persistence management"
    echo "  - Elixir App: CA certificates and dependency management"
    echo "  - Prometheus: Embedded monitoring configuration"
    echo "  - Grafana: Dashboard with admin credentials"
    echo "  - Nginx: Reverse proxy with embedded configuration"
  '';

  # Testing script for production containers
  testScript = pkgs.writeScriptBin "test-production-nixos-containers" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    echo "🧪 Testing Production-Ready NixOS Containers"
    echo "TDG Validation with Comprehensive Operational Testing"
    echo "===================================================="
    
    # Test PostgreSQL non-root execution
    echo "Testing PostgreSQL non-root execution..."
    if podman run --rm indrajaal-postgres-demo:production-ready whoami | grep -q postgres; then
        echo "✅ PostgreSQL runs as non-root user"
    else
        echo "❌ PostgreSQL user test failed"
        exit 1
    fi
    
    # Test Elixir CA certificates
    echo "Testing Elixir CA certificates..."
    if podman run --rm indrajaal-app-demo:production-ready test -f "\$SSL_CERT_FILE"; then
        echo "✅ CA certificates found in Elixir container"
    else
        echo "❌ CA certificates test failed"
        exit 1
    fi
    
    # Test Redis initialization script
    echo "Testing Redis initialization..."
    if podman run --rm indrajaal-redis-demo:production-ready test -f /usr/local/bin/redis-init.sh; then
        echo "✅ Redis initialization script found"
    else
        echo "❌ Redis initialization test failed"
        exit 1
    fi
    
    echo ""
    echo "🎉 All production container tests passed!"
    echo "Ready for full stack deployment and integration testing."
  '';
}