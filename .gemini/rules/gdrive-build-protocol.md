# GDrive FUSE Mount Build Protocol (SC-GDRIVE-BUILD)

## Mandate
**ALL Rust builds for projects on the gdrive FUSE mount MUST use a local CARGO_TARGET_DIR.**

The gdrive mount (`fuse.rclone` at `sub-projects/work/gdrive/`) does not support executing binaries.
Build scripts (`build.rs`) fail with `Permission denied (os error 13)` when the target dir is on the mount.

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-GDRIVE-BUILD-001 | Rust builds on gdrive MUST use CARGO_TARGET_DIR on local fs | CRITICAL |
| SC-GDRIVE-BUILD-002 | Default CARGO_TARGET_DIR = `/home/an/dev/ver/c3i/sub-projects/work/` | HIGH |
| SC-GDRIVE-BUILD-003 | Source code MAY remain on gdrive, only target dir must be local | MEDIUM |

## Usage
```bash
# For ANY cargo command under sub-projects/work/gdrive/
CARGO_TARGET_DIR=/home/an/dev/ver/c3i/sub-projects/work/ cargo build --release

# Binary will be at:
# /home/an/dev/ver/c3i/sub-projects/work/release/<binary-name>
```

## Why
- `rclone` FUSE mounts don't support exec permissions
- `sudo mount -o remount,exec` requires authentication
- Redirecting target dir is the standard Rust workaround for network/FUSE mounts
