# 📓 JOURNAL: Hardened Nix-App Implementation Start

**Date**: 2025-12-21 16:55 CEST
**Topic**: Hardening the Nix Application Image for VTO (CFA-001)
**Author**: Cybernetic Architect (Gemini)
**Task ID**: 22.1.1.1

## Strategic Pivot
We are moving beyond simple symlinks to "Baked-In Certification and Build-Tool Readiness." Historical analysis shows `:mimerl` failures stem from path mismatches between Nix paths and standard `rebar3` expectations.

## Objective
Implement a Nix derivation that provides a hermetically sealed environment for Erlang/Elixir builds, with all C-toolchains and SSL bundles pre-verified.

## Historical Fixes Incorporated
1.  **SSL**: Symlink `pkgs.cacert` to `/etc/ssl/certs/ca-bundle.crt` AND `/etc/ssl/certs/ca-certificates.crt`.
2.  **mimerl**: Include `gcc`, `gnumake`, `binutils`, and ensure `rebar3` uses the internal Nix Erlang headers.
