#!/bin/bash
echo "--- Podman Rootless Diagnostic ---"

# Check if subuid/subgid are configured
USER_NAME=$(whoami)
if grep -q "$USER_NAME" /etc/subuid && grep -q "$USER_NAME" /etc/subgid; then
    echo "[OK] SubUID/SubGID configured for $USER_NAME"
else
    echo "[ERROR] SubUID/SubGID NOT configured for $USER_NAME. Run: sudo usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER_NAME"
fi

# Check if unshare works
if podman unshare cat /proc/self/uid_map > /dev/null 2>&1; then
    echo "[OK] User namespace (unshare) functional"
else
    echo "[ERROR] User namespace NOT functional. Check kernel.unprivileged_userns_clone"
fi

# Check for slirp4netns
if command -v slirp4netns > /dev/null; then
    echo "[OK] slirp4netns installed"
else
    echo "[WARNING] slirp4netns not found. Network performance may be degraded."
fi

# Check socket status
if [ -S "/run/user/$(id -u)/podman/podman.sock" ]; then
    echo "[OK] Podman API socket active"
else
    echo "[INFO] Podman API socket inactive. Start with: systemctl --user enable --now podman.socket"
fi
