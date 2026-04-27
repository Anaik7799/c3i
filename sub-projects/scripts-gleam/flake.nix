{
  description = "sys — polyglot workspace (Gleam + Rust + TS), managed by Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # rust-overlay gives us pinned rustup-style toolchains with components
    # selected per project (see rust-toolchain.toml below).
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # sops-nix: encrypted secrets (age/gpg) decrypted at activation
    # time on the target. Pulled in by nixos-configurations, not by
    # the devshell.
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay, sops-nix }:
    let
      # ---------------------------------------------------------------
      # NixOS configurations (system-agnostic; always x86_64-linux)
      # ---------------------------------------------------------------
      # Single source of truth for host addresses / roles. Passed to
      # every nixosConfiguration via specialArgs so modules can read
      # it without re-importing.
      inventory = import ./nix-configs/inventory.nix;

      mkNixosHost = hostPath:
        nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inventory; };
          modules = [
            sops-nix.nixosModules.sops
            hostPath
          ];
        };
      perSystem = flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ rust-overlay.overlays.default ];
        };

        # Rust: pin via rust-toolchain.toml if present, else stable default
        rust =
          if builtins.pathExists ./rust-toolchain.toml then
            pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml
          else
            pkgs.rust-bin.stable.latest.default;

        erlang = pkgs.erlang_27;
        elixir = pkgs.elixir_1_17;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "sys-dev";

          packages = with pkgs; [
            # Gleam + BEAM
            gleam
            erlang
            rebar3
            elixir

            # Rust
            rust
            cargo-nextest
            cargo-watch

            # Node / TypeScript (fp-ts stack) — get tsc via `pnpm add -D typescript`
            nodejs_22
            pnpm

            # General dev tooling
            git
            gh
            jq
            ripgrep
            fd
            just        # task runner — used ONLY to dispatch to Gleam scripts
            direnv

            # Deployment tooling
            nixos-rebuild    # used by `gleam run -m sys_scripts -- deploy apply nixos`
            openssh          # ssh client for the same
          ];

          shellHook = ''
            echo ""
            echo "sys devshell"
            echo "  gleam   : $(gleam --version 2>/dev/null || echo MISSING)"
            echo "  erl     : $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell 2>/dev/null | tr -d '"' )"
            echo "  rustc   : $(rustc --version 2>/dev/null || echo MISSING)"
            echo "  cargo   : $(cargo --version 2>/dev/null || echo MISSING)"
            echo "  node    : $(node --version 2>/dev/null || echo MISSING)"
            echo "  pnpm    : $(pnpm --version 2>/dev/null || echo MISSING)"
            echo ""
          '';
        };

        # Ephemeral one-shot shell: `nix run .#scaffold -- <args>`
        # will be added once scripts/ exists.
      });
    in
    perSystem // {
      # Expose inventory as a top-level lib output so Gleam can read
      # it via `nix eval .#lib.inventory --json`.
      lib.inventory = inventory;

      nixosConfigurations = {
        nix-k8s-master =
          mkNixosHost ./nix-configs/hosts/nas1/nix-k8s-master/configuration.nix;
        nix-k8s-worker-1 =
          mkNixosHost ./nix-configs/hosts/nas1/nix-k8s-worker-1/configuration.nix;
        nix-k8s-worker-2 =
          mkNixosHost ./nix-configs/hosts/nas1/nix-k8s-worker-2/configuration.nix;
      };
    };
}
