#!/bin/bash
# Finish a partial single-user Nix install that failed at profile-link time
# because we ran as root and 'nixbld' group didn't exist.
set -euo pipefail

LOG=/mnt/c/dev/elixir/sys/.pi/bootstrap/03-nix-finalize.log
exec > >(tee "$LOG") 2>&1

echo "[$(date -Is)] creating nixbld group + 10 build users (no-op if exists)"
if ! getent group nixbld >/dev/null; then
  groupadd -r nixbld
fi
for i in $(seq 1 10); do
  u="nixbld${i}"
  if ! id "$u" >/dev/null 2>&1; then
    useradd --system --home-dir /var/empty --no-create-home \
      --gid nixbld --groups nixbld --shell /usr/sbin/nologin \
      "$u"
  fi
done

echo "[$(date -Is)] locating nix binary in /nix/store"
NIX_BIN="$(ls -d /nix/store/*-nix-*/bin 2>/dev/null | head -1 || true)"
if [ -z "$NIX_BIN" ] || [ ! -x "$NIX_BIN/nix-env" ]; then
  echo "ERROR: no nix store entry found; installer did not unpack Nix"
  exit 1
fi
echo "found: $NIX_BIN"

echo "[$(date -Is)] creating /nix/var/nix/profiles/default pointing at nix pkg"
# Install Nix into root's profile using nix-env from the store
export PATH="$NIX_BIN:$PATH"
export USER=root
export HOME=/root
mkdir -p /nix/var/nix/profiles/per-user/root

# The tarball has an 'unpack' dir with a self-install helper. If the install
# failed partway we can still use nix-env -i directly.
NIX_PKG="$(ls -d /nix/store/*-nix-* 2>/dev/null | grep -v '\.drv$' | grep -v '/nix-[0-9].*\.' | head -1 || true)"
# pick the package dir (not the -man, not the .drv): the bin/nix-env we just used lives here
NIX_PKG="$(dirname "$NIX_BIN")"
echo "installing $NIX_PKG into default profile"
nix-env -p /nix/var/nix/profiles/default -i "$NIX_PKG"

echo "[$(date -Is)] writing /etc/profile.d/nix.sh so new shells pick it up"
cat > /etc/profile.d/nix.sh <<'EOF'
# Nix single-user init (managed by pi bootstrap)
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix.sh
elif [ -n "${USER:-}" ] && [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi
EOF
chmod 0644 /etc/profile.d/nix.sh

echo "[$(date -Is)] linking root profile (idempotent)"
# If an existing /root/.nix-profile points somewhere wrong, replace it.
if [ -L /root/.nix-profile ] || [ -e /root/.nix-profile ]; then
  rm -f /root/.nix-profile
fi
ln -s /nix/var/nix/profiles/default /root/.nix-profile
mkdir -p /root/.nix-defexpr

echo "[$(date -Is)] verifying"
/nix/var/nix/profiles/default/bin/nix --version
/nix/var/nix/profiles/default/bin/nix-env --version

echo "[$(date -Is)] done"
