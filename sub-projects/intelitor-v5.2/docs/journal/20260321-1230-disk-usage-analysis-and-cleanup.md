# Disk Usage Analysis & Cleanup — 84% → 54%

**Date**: 2026-03-21 12:30 CEST
**Author**: Claude Opus 4.6
**Type**: Infrastructure / Operations
**Impact**: 346G freed, disk usage reduced from 84% to 54%

---

## 1. Problem Statement

System disk (`/dev/sda2`, 1.2T) reached 84% utilization (940G used, 181G available). Triggered investigation to identify root causes and reclaim space.

## 2. Root Cause Analysis (5-Why)

```
WHY is disk at 84%?
  → 725G consumed by ~/.local/share/containers/storage

WHY is container storage 725G?
  → 358 Podman images accumulated, only 52 active (14.5%)

WHY are there 306 unused images?
  → 70 dangling images at ~16GB each from iterative container rebuilds
  → Old base images (zenoh, postgres, elixir, dotnet) never pruned

WHY were they never pruned?
  → No automated image cleanup policy (no cron, no post-build hook)

WHY is there no cleanup policy?
  → Infrastructure hygiene not yet codified in SIL-6 operational procedures
```

## 3. Full Disk Breakdown (Pre-Cleanup)

### Top-Level Filesystem

| Path | Size | % of 940G | Notes |
|------|------|-----------|-------|
| `/home` | 786G | 83.6% | Dominated by container storage |
| `/nix` | 77G | 8.2% | Nix store, 33,607 packages |
| `/var` | 53G | 5.6% | Logs (29G) + Buildah temp (20G) |
| `/usr` | 15G | 1.6% | System packages |
| `/snap` | 11G | 1.2% | Snap packages |
| `/swap.img` | 8.1G | 0.9% | Swap file |

### Home Directory Breakdown

| Path | Size | Notes |
|------|------|-------|
| `~/.local/share/containers/storage` | 725G | **PRIMARY CULPRIT** |
| `~/dev/` | 34G | Project + archives |
| `~/.nuget/` | 4.8G | .NET package cache |
| `~/.npm/` | 4.8G | Node package cache |
| `~/.claude/` | 4.2G | Claude Code data (3.6G projects) |
| `~/.vscode-server/` | 4.1G | VS Code remote |
| `~/.cache/` | 3.7G | General cache |
| `~/.gemini/` | 1.7G | Gemini data |

### Podman Image Analysis (Pre-Cleanup)

| Metric | Value |
|--------|-------|
| Total images | 358 |
| Active images | 52 (14.5%) |
| Dangling images | 70 (~16GB each) |
| Total image storage | 413G |
| Reclaimable | 401.9G (97%) |
| Active containers | 12 |
| Volumes | 30 (27 active) |

### /var Breakdown

| Path | Size | Cause |
|------|------|-------|
| `/var/log/syslog.1` | 20G | Rotated syslog not compressed |
| `/var/log/syslog` | 5.2G | Active syslog |
| `/var/log/journal/` | 4.1G | Systemd journal |
| `/var/tmp/buildah*` | 20G | 4 stale Buildah build layers |

### Project Directory

| Path | Size | Notes |
|------|------|-------|
| `~/dev/ver/intelitor-v5.2/` | 13G | Active project |
| `~/dev/intelitor-demo/` | 14G | Demo copy |
| `~/dev/ver/2026111-intelitor-v5.2.tgz` | 4.5G | Archive tarball |
| `~/dev/ver/intelitor-v5.2.tar.gz` | 2.3G | Archive tarball |
| `~/dev/intelitor-demo-20250909.tar.gz` | 1.8G | Old demo archive |

## 4. Cleanup Action Taken

### Executed: `podman image prune -a --force`

Removed 302 unused images. 6 images skipped (in use by active containers).

### Results

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Disk usage | 940G (84%) | 594G (54%) | **-346G (-37%)** |
| Available space | 181G | 527G | **+346G** |
| Podman images | 358 | 56 | -302 removed |
| Image storage | 413G | 51G | -362G |
| Reclaimable | 401.9G | 29.3G | -372.6G |

## 5. Remaining Cleanup Opportunities

| Action | Estimated Savings | Risk | Priority |
|--------|-------------------|------|----------|
| `rm -rf /var/tmp/buildah*` | ~20G | Low | P1 |
| Truncate/rotate syslog | ~25G | Low (needs sudo) | P1 |
| `journalctl --vacuum-size=500M` | ~3.5G | Low (needs sudo) | P2 |
| `nix-collect-garbage -d` | ~10-30G | Medium | P2 |
| Remove old tarballs | ~8.6G | Low | P2 |
| Remove `~/dev/intelitor-demo/` | ~14G | Medium (verify unused) | P3 |

**Total additional reclaimable**: ~80-100G (would bring usage to ~40%)

## 6. Prevention Recommendations

### SC-OPS-DISK-001: Periodic Podman Prune
```bash
# Add to crontab or devenv hook:
# Weekly prune of dangling images
0 3 * * 0 podman image prune --force 2>&1 | logger -t podman-prune
```

### SC-OPS-DISK-002: Disk Usage Monitoring
- Alert threshold: 75% (warning), 85% (critical)
- Monitor `~/.local/share/containers/storage` specifically

### SC-OPS-DISK-003: Build Hygiene
- After `podman build`, prune dangling images from previous build
- Buildah temp dirs should be cleaned post-build

### SC-OPS-DISK-004: Log Rotation
- Configure logrotate for syslog: maxsize 1G, rotate 4, compress
- Cap journal: `SystemMaxUse=1G` in `/etc/systemd/journald.conf`

## 7. STAMP Alignment

| Constraint | Relevance |
|------------|-----------|
| SC-FUNC-001 | System remains functional — no data lost |
| SC-CNT-009 | Active containers unaffected (12/14 running) |
| Ψ₀ (Existence) | System survival improved — more headroom |
| SC-EMR-057 | Emergency stop capability preserved |

---

**Conclusion**: Podman image accumulation was the sole significant cause of 84% disk usage. A single `podman image prune -a` reclaimed 346G (37% of total disk), bringing usage to a healthy 54%. No data loss, no service interruption. Recommend periodic automated pruning to prevent recurrence.
