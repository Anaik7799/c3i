{ pkgs ? import <nixpkgs> {} }:

let
  # Import Tailscale Library
  ts = import ./lib/tailscale.nix { inherit pkgs; };

  # Define original entrypoint
  entrypoint = pkgs.writeShellScriptBin "docker-entrypoint" ''
    exec ${pkgs.redis}/bin/redis-server --bind 0.0.0.0 --dir /data
  '';
in
pkgs.dockerTools.buildImage {
  name = "localhost/indrajaal-redis-demo";
  tag = "nixos-devenv";

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = with pkgs; [
      redis
      coreutils
      hostname
      bash
      cacert
      ts.package # Inject Tailscale
      entrypoint
    ];
  };

  config = {
    Env = [
      "PATH=/bin:/usr/bin:/usr/local/bin"
    ];
    ExposedPorts = {
      "6379/tcp" = {};
    };
    Cmd = [ "${ts.wrap entrypoint}/bin/entrypoint-with-tailscale" ];
  };
}