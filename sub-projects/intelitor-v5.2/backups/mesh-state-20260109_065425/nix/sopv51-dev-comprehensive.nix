# SOPv5.11 Comprehensive Development Container
# MANDATORY: Podman-only, NixOS-based development environment
# Purpose: Full development environment for Intelitor application
# Services: Elixir 1.19, Erlang 27, Node.js 20, PostgreSQL client, Redis client
# Features: PHICS v2.1 hot-reloading, SOPv5.11 compliance, external services architecture

{ pkgs ? import <nixpkgs> {}
, gitRev ? "unknown"
, gitBranch ? "unknown"
, buildDate ? "unknown"
}:

let
  # Elixir and Erlang versions
  elixirPackage = pkgs.beam.packagesWith pkgs.erlang_27;
  elixir = elixirPackage.elixir_1_19;

  # PHICS v2.1 configuration
  phicsConfig = pkgs.writeTextFile {
    name = "phics-config";
    text = builtins.toJSON {
      version = "2.1.0";
      enabled = true;
      watch_paths = [
        "/workspace/lib"
        "/workspace/test"
        "/workspace/priv"
        "/workspace/assets"
        "/workspace/config"
      ];
      sync_interval_ms = 50;
      hot_reload = true;
      bidirectional_sync = true;
      container_mode = true;
    };
    destination = "/workspace/.phics/config.json";
  };

  # Environment configuration
  envConfig = pkgs.writeTextFile {
    name = "indrajaal-env";
    text = ''
      export PATH="${elixir}/bin:${pkgs.erlang_27}/bin:${pkgs.nodejs_20}/bin:$PATH"
      export MIX_HOME="/workspace/.mix"
      export HEX_HOME="/workspace/.hex"
      export NPM_CONFIG_PREFIX="/workspace/.npm-global"

      # PHICS configuration
      export PHICS_ENABLED=true
      export PHICS_WATCH_ENABLED=true
      export PHICS_CONTAINER_MODE=development
      export PHICS_HOT_RELOAD=enabled

      # External services (running on host)
      export DATABASE_URL="postgresql://postgres:postgres@host.docker.internal:5433/indrajaal_dev"
      export REDIS_URL="redis://host.docker.internal:6379/0"

      # SOPv5.11 configuration
      export SOPV51_ENABLED=true
      export SOPV51_CYBERNETIC_EXECUTION=true
      export SOPV51_PATIENT_MODE=true
      export SOPV51_CONTAINER_ONLY=true

      # Development settings
      export MIX_ENV=dev
      export NODE_ENV=development
      export ELIXIR_ERL_OPTIONS="+S 16"

      # Locale settings
      export LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive

      # SSL/TLS certificates for Erlang
      export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
    '';
    destination = "/etc/profile.d/indrajaal.sh";
  };

  # Development entrypoint script
  devEntrypoint = pkgs.writeScriptBin "dev-entrypoint" ''
    #!${pkgs.bash}/bin/bash
    set -e

    echo "🚀 Intelitor SOPv5.11 Development Container Starting..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Setup /etc/passwd and /etc/group for su command
    mkdir -p /etc
    if [ ! -f /etc/passwd ]; then
      echo "👤 Creating /etc/passwd and /etc/group..."
      echo "root:x:0:0:root:/root:${pkgs.bash}/bin/bash" > /etc/passwd
      echo "developer:x:1000:1000:developer:/home/developer:${pkgs.bash}/bin/bash" >> /etc/passwd
      echo "root:x:0:" > /etc/group
      echo "developer:x:1000:" >> /etc/group
    fi

    # Create home directory for developer user
    mkdir -p /home/developer
    chown -R 1000:1000 /home/developer || true

    # Setup SSL certificates for Erlang/OTP (multi-path strategy)
    echo "🔒 Setting up SSL certificates for Erlang/OTP..."
    mkdir -p /etc/ssl/certs /etc/pki/tls/certs

    # Create symlinks to NixOS cacert bundle for multiple Erlang lookup paths
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-bundle.crt || true
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/pki/tls/certs/ca-bundle.crt || true
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/cert.pem || true
    ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/ssl/certs/ca-certificates.crt || true

    # Create workspace structure
    echo "📁 Setting up workspace structure..."
    mkdir -p /workspace/{.mix,.hex,.npm-global,.phics}

    # Source environment
    source /etc/profile.d/indrajaal.sh

    # Setup Hex and Rebar (if not already installed)
    if [ ! -f "$HEX_HOME/hex" ]; then
      echo "📦 Installing Hex package manager..."
      ${elixir}/bin/mix local.hex --force
    fi

    if [ ! -f "$MIX_HOME/rebar3" ]; then
      echo "🔧 Installing Rebar3 build tool..."
      ${elixir}/bin/mix local.rebar --force
    fi

    # Change to workspace
    cd /workspace

    # Install Elixir dependencies if mix.exs exists
    if [ -f "mix.exs" ]; then
      echo "📚 Installing Elixir dependencies..."
      ${elixir}/bin/mix deps.get || echo "⚠️  Warning: mix deps.get failed"
    fi

    # Install Node.js dependencies if package.json exists
    if [ -f "assets/package.json" ]; then
      echo "📦 Installing Node.js dependencies..."
      cd assets
      ${pkgs.nodejs_20}/bin/npm install || echo "⚠️  Warning: npm install failed"
      cd /workspace
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Development environment ready!"
    echo ""
    echo "🔧 Available commands:"
    echo "  mix phx.server    - Start Phoenix server (port 4000)"
    echo "  mix test          - Run tests"
    echo "  mix compile       - Compile application"
    echo "  iex -S mix        - Interactive Elixir shell"
    echo ""
    echo "🌐 External services (must be running on host):"
    echo "  PostgreSQL: localhost:5433"
    echo "  Redis:      localhost:6379"
    echo ""
    echo "⚡ PHICS v2.1 hot-reloading: ENABLED"
    echo "🤖 SOPv5.11 cybernetic framework: ACTIVE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Switch to developer user and start interactive shell
    # Use setpriv instead of su to avoid PAM issues
    cd /workspace
    exec ${pkgs.util-linux}/bin/setpriv --reuid=1000 --regid=1000 --init-groups ${pkgs.bash}/bin/bash
  '';

  # Application root with all development packages
  appRoot = pkgs.buildEnv {
    name = "indrajaal-dev-root";
    paths = [
      # Core runtime
      elixir
      pkgs.erlang_27
      pkgs.nodejs_20

      # Database clients
      pkgs.postgresql_17  # PostgreSQL client (server runs on host)
      pkgs.redis          # Redis client (server runs on host)

      # Development tools
      pkgs.git
      pkgs.curl
      pkgs.wget
      pkgs.jq
      pkgs.which
      pkgs.tree
      pkgs.file
      pkgs.gnused
      pkgs.gawk
      pkgs.findutils
      pkgs.coreutils

      # Build tools
      pkgs.gnumake
      pkgs.gcc
      pkgs.pkg-config
      pkgs.autoconf
      pkgs.automake

      # SSL/TLS
      pkgs.cacert
      pkgs.openssl

      # Process management
      pkgs.procps
      pkgs.util-linux
      pkgs.iproute2

      # Text editors
      pkgs.nano
      pkgs.vim

      # Shell utilities
      pkgs.bash
      pkgs.bashInteractive
      pkgs.su

      # Locale support
      pkgs.glibcLocales

      # Python (for some Node.js native modules)
      pkgs.python3

      # Entrypoint
      devEntrypoint
      envConfig
      phicsConfig
    ];
  };

in
pkgs.dockerTools.buildImage {
  name = "indrajaal-dev";
  tag = "nixos-25.05-${gitRev}";

  copyToRoot = appRoot;

  config = {
    Env = [
      "PATH=/bin:/usr/bin:/usr/local/bin"
      "LANG=en_US.UTF-8"
      "LC_ALL=en_US.UTF-8"
      "HOME=/home/developer"
      "SHELL=/bin/bash"
      "TERM=xterm-256color"
    ];

    WorkingDir = "/workspace";

    # Expose ports for Phoenix server and LiveReload
    ExposedPorts = {
      "4000/tcp" = {};  # Phoenix server
      "4001/tcp" = {};  # LiveReload WebSocket
    };

    # Volume mount point for source code
    Volumes = {
      "/workspace" = {};
    };

    # Entrypoint script
    Entrypoint = [ "${devEntrypoint}/bin/dev-entrypoint" ];

    # Labels for metadata
    Labels = {
      "maintainer" = "Intelitor Development Team";
      "description" = "SOPv5.11 Comprehensive Development Container";
      "version" = "nixos-25.05-${gitRev}";
      "git.branch" = gitBranch;
      "build.date" = buildDate;
      "phics.version" = "2.1.0";
      "sopv51.enabled" = "true";
      "container.policy" = "podman-only";
    };
  };
}
