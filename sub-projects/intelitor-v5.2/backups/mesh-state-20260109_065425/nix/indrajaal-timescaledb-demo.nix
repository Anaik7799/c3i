{ pkgs ? import <nixpkgs> {} }:

let
  # PostgreSQL with TimescaleDB extension
  postgresqlWithExtensions = pkgs.postgresql_17.withPackages (ps: [
    ps.timescaledb
  ]);

  # Import Tailscale Library
  ts = import ./lib/tailscale.nix { inherit pkgs; };

  # Create entrypoint script
  entrypoint = pkgs.writeShellScriptBin "docker-entrypoint" ''
    set -e

    # Create postgres user if it doesn't exist
    if ! id -u postgres > /dev/null 2>&1; then
      ${pkgs.shadow}/bin/useradd -r -u 999 -d /var/lib/postgresql -s /bin/sh postgres 2>/dev/null || true
    fi

    # Create data directory if it doesn't exist
    mkdir -p /var/lib/postgresql/data
    mkdir -p /run/postgresql
    chown -R postgres:postgres /var/lib/postgresql /run/postgresql
    chmod 700 /var/lib/postgresql/data

    # Initialize database if needed
    if [ ! -f /var/lib/postgresql/data/PG_VERSION ]; then
      ${pkgs.su-exec}/bin/su-exec postgres ${postgresqlWithExtensions}/bin/initdb -D /var/lib/postgresql/data
      echo "host all all 0.0.0.0/0 md5" >> /var/lib/postgresql/data/pg_hba.conf
      echo "listen_addresses = '*'" >> /var/lib/postgresql/data/postgresql.conf
      echo "shared_preload_libraries = 'timescaledb'" >> /var/lib/postgresql/data/postgresql.conf
    fi

    # Start postgres as postgres user
    exec ${pkgs.su-exec}/bin/su-exec postgres ${postgresqlWithExtensions}/bin/postgres
  '';
in
pkgs.dockerTools.buildImage {
  name = "localhost/indrajaal-timescaledb-demo";
  tag = "nixos-devenv";

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = with pkgs; [
      postgresqlWithExtensions
      coreutils
      bash
      cacert
      shadow  # For adduser
      su-exec  # For running as postgres user
      hostname # For the entrypoint script
      ts.package # Inject Tailscale binaries
      glibcLocales # For locale support
      entrypoint
    ];
  };

  config = {
    Env = [
      "PATH=/bin:/usr/bin"
      "PGDATA=/var/lib/postgresql/data"
      "LANG=en_US.UTF-8"
      "LOCALE_ARCHIVE=${pkgs.glibcLocales}/lib/locale/locale-archive"
    ];
    ExposedPorts = {
      "5432/tcp" = {};
    };
    # Use the Tailscale wrapper
    Cmd = [ "${ts.wrap entrypoint}/bin/entrypoint-with-tailscale" ];
  };
}
