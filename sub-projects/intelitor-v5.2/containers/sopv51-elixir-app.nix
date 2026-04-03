# ACE v3.6.0 - THE HIGH-PERFORMANCE STACK
# Stack: Erlang 28.3, Elixir 1.19.4, Rebar 3.25.1
{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/nixos-unstable.tar.gz") {} }:
let
  releaseSrc = builtins.path {
    name = "indrajaal-release-src";
    path = ../_build/demo/rel/indrajaal;
  };

  # High-Performance Entrypoint (ACE v3.6.0)
  appEntrypoint = pkgs.writeShellScriptBin "app-entrypoint" ''
    set -e
    echo "🛡️  ACE v3.6.0: High-Performance Stack (OTP 28 / Elixir 1.19)..."
    cd /workspace
    
    # CRITICAL: Remove the host-specific ERTS to force fallback to optimized container runtime
    rm -rf /workspace/erts-*
    
    mkdir -p /workspace/tmp /workspace/logs
    
    # Path injection: Prioritize container-native high-performance runtime
    export PATH="${pkgs.beam28Packages.erlang}/bin:${pkgs.beam28Packages.elixir_1_19}/bin:${pkgs.beam28Packages.rebar3}/bin:$PATH"
    export PATH="$PATH:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.nettools}/bin:${pkgs.openssl}/bin"
    
    echo "🚀 Starting High-Performance Release..."
    exec /workspace/bin/indrajaal start
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "indrajaal-app-hardened";
  tag = "latest";
  contents = [ 
    pkgs.coreutils 
    pkgs.glibc.bin 
    pkgs.bashInteractive 
    pkgs.util-linux 
    pkgs.gnused 
    pkgs.gnugrep
    pkgs.nettools
    pkgs.openssl
    pkgs.beam28Packages.erlang
    pkgs.beam28Packages.elixir_1_19
    pkgs.beam28Packages.rebar3
    appEntrypoint 
  ];
  
  extraCommands = ''
    mkdir -p workspace etc
    cp -r ${releaseSrc}/* workspace/
    chmod -R 777 workspace
  '';

  config = {
    Entrypoint = [ "${appEntrypoint}/bin/app-entrypoint" ];
    WorkingDir = "/workspace";
    User = "1000:1000";
    Env = [
      "MIX_ENV=demo"
      "RELEASE_MODE=true"
      "PORT=4000"
      "PHX_HOST=localhost"
      "DATABASE_URL=ecto://indrajaal:indrajaal_dev@postgres/indrajaal_dev"
      "SECRET_KEY_BASE=certified_autonomic_secret_key_base"
    ];
  };
}
