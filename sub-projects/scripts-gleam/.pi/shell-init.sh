#!/bin/bash
# Sourced by every pi `bash` invocation (via shellCommandPrefix in
# .pi/settings.json). Keep this FAST — it runs before every command.
#
# Responsibilities:
#   1. Put Nix on PATH (single-user install under /nix).
#   2. Make `nix develop` / `nix shell` available without extra flags.
#
# We do NOT automatically enter `nix develop` here because that would fork
# a subshell per command and defeat pi's process model. Instead, commands
# that need the devshell should be invoked via:
#     nix develop --command <cmd>
# or, for convenience, the `in-shell` helper defined below.

# --- Nix profile ---
# Pi invokes us with `bash -c "source this-file && <user command>"`, so we
# must NOT leave `set -u` / `set -e` active when we return — they'd abort
# perfectly valid user commands that reference unset vars (which is pi's
# whole Windows→WSL env-variable-stripping quirk, see AGENTS.md).
if [ -z "${__PI_NIX_INIT_DONE:-}" ]; then
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
  fi
  export __PI_NIX_INIT_DONE=1
fi

# --- Helper: run a command inside the project devshell ---
# Usage: in-shell <cmd> [args...]
in-shell() {
  nix develop --quiet --command "$@"
}
export -f in-shell 2>/dev/null || true
