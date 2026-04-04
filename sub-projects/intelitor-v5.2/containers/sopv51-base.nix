# SOPv5.1 Base Container Definition
# Agent: This defines the base NixOS container for Intelitor
# Updated: 2025-11-16 08:15:00 CEST
# Framework: SOPv5.1 + PHICS + TPS + STAMP
# Refactored: Eliminated KVM requirement by using copyToRoot instead of runAsRoot

{ pkgs ? import <nixpkgs> {}
, gitRev ? "unknown"
, gitBranch ? "unknown"
, buildDate ? "unknown"
}:

let
  # Create PHICS marker files using writeTextFile
  phicsMarker = pkgs.writeTextFile {
    name = "phics-marker";
    text = "";
    destination = "/.phics-container";
  };

  phicsStatus = pkgs.writeTextFile {
    name = "phics-status";
    text = "enabled\n";
    destination = "/etc/phics_status";
  };

  # Create environment script using writeTextFile
  envScript = pkgs.writeTextFile {
    name = "indrajaal-env.sh";
    text = ''
      export PHICS_ENABLED=true
      export CONTAINER_OS=nixos
      export NO_TIMEOUT=true
      export MAX_PARALLELIZATION=true
      export ELIXIR_ERL_OPTIONS="+fnu +S 16:16 +SDio 16"
      export MIX_OS_DEPS_COMPILE_PARTITION_COUNT=8
      export TMPDIR=/tmp
      export MIX_HOME=/workspace/.mix
      export HEX_HOME=/workspace/.hex
      export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
      export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
      export LANG=C.UTF-8
      export LC_ALL=C.UTF-8
    '';
    destination = "/etc/profile.d/indrajaal.sh";
  };

  # Combine all packages and config files
  baseFS = pkgs.symlinkJoin {
    name = "indrajaal-base-fs";
    paths = with pkgs; [
      # NixOS base essentials
      bashInteractive
      coreutils
      gnugrep
      findutils
      gawk

      # User management
      shadow  # Required for useradd command
      su      # Required for user switching

      # Elixir/Erlang stack (Updated to 1.19 + OTP 28 per mix.exs requirements)
      elixir_1_19
      erlang_28

      # PHICS requirements
      inotify-tools
      entr
      watchman

      # Development tools
      git
      gnumake
      gcc

      # Network tools
      curl
      wget
      netcat

      # Process management
      procps
      htop

      # SSL/TLS certificates
      cacert

      # Config files
      envScript
      phicsStatus
      phicsMarker
    ];
  };

  # Create entrypoint script that performs runtime setup
  entrypoint = pkgs.writeScriptBin "container-entrypoint" ''
    #!${pkgs.bash}/bin/bash
    set -e

    # Create developer user if it doesn't exist
    if ! id -u developer >/dev/null 2>&1; then
      ${pkgs.shadow}/bin/useradd -m -s ${pkgs.bash}/bin/bash -u 1000 developer || true
    fi

    # Create workspace directories
    mkdir -p /workspace/{logs,data,tmp,_build,deps,.mix,.hex,.phics}
    chown -R developer:developer /workspace 2>/dev/null || true

    # Create tmp directory with sticky bit
    mkdir -p /tmp
    chmod 1777 /tmp 2>/dev/null || true

    # Source environment variables
    if [ -f /etc/profile.d/indrajaal.sh ]; then
      source /etc/profile.d/indrajaal.sh
    fi

    # If running bash directly, switch to developer user
    if [ "$1" = "bash" ] || [ "$1" = "/bin/bash" ]; then
      exec ${pkgs.su}/bin/su - developer
    else
      # Otherwise run the command as developer
      exec ${pkgs.su}/bin/su - developer -c "$*"
    fi
  '';
in
pkgs.dockerTools.buildImage {
  name = "indrajaal-sopv51-base";
  tag = "nixos-25.05-${gitRev}";

  # Use copyToRoot instead of runAsRoot to avoid KVM requirement
  copyToRoot = pkgs.buildEnv {
    name = "indrajaal-base-root";
    paths = [ baseFS entrypoint ];
    pathsToLink = [ "/" ];
  };

  # Agent: Container configuration
  config = {
    Cmd = [ "${entrypoint}/bin/container-entrypoint" "/bin/bash" ];
    WorkingDir = "/workspace";

    Env = [
      "CONTAINER_OS=nixos"
      "PHICS_ENABLED=true"
      "NO_TIMEOUT=true"
      "MAX_PARALLELIZATION=true"
      "ELIXIR_ERL_OPTIONS=+S 16"
      "MIX_HOME=/workspace/.mix"
      "HEX_HOME=/workspace/.hex"
      "PATH=/workspace/.mix/escripts:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
      "LANG=C.UTF-8"
      "LC_ALL=C.UTF-8"
      "TMPDIR=/tmp"
    ];

    Labels = {
      "org.indrajaal.sopv51" = "compliant";
      "org.indrajaal.phics" = "enabled";
      "org.indrajaal.build.date" = buildDate;
      "org.indrajaal.git.commit" = gitRev;
      "org.indrajaal.git.branch" = gitBranch;
      "org.indrajaal.os" = "nixos";
      "org.indrajaal.version" = "v5.1.0";
    };

    # Agent: Health check for container monitoring
    # Note: Healthcheck removed due to podman compatibility issue

    # Agent: Volumes for persistent data
    Volumes = {
      "/workspace" = {};
      "/workspace/logs" = {};
      "/workspace/data" = {};
    };
  };
}
