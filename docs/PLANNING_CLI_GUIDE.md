# Indrajaal Planning System: User Guide

**Version**: 1.0.0
**Date**: 2026-04-03
**Status**: ACTIVE

## Overview
Indrajaal uses a **Dual-Bridge Planning System**. You can manage tasks using either the stable F# system (`sa-plan`) or the new high-performance Gleam system (`sa-gleam`). Both systems share the same source of truth: `sub-projects/c3i/data/smriti/planning.db`.

---

## 1. Autoritative Mesh Bootstrap (`./sa-up`)
The `sa-up` command is the primary entry point for starting the entire C3I system. It uses optimized execution waves to ensure dependencies (Database -> Zenoh -> Services) are met.

- **Usage**: `./sa-up`
- **What it does**:
    1. Detects your UID and connects to Podman.
    2. Starts `indrajaal-db-prod` (Wave 1).
    3. Starts `zenoh-router-1,2,3` (Wave 2).
    4. Starts remaining services (Bridge, Cortex, App).
    5. Performs a health check on all 8 core containers.

---

## 2. Stable F# CLI (`./sa-plan`)
The F# CLI is the authoritative tool for project-wide task management and integration with the Chaya Digital Twin.

### Basic Commands
| Command | Description | Example |
|:---|:---|:---|
| `status` | Show overall project task status and active items. | `./sa-plan status` |
| `add <title>` | Add a new task to the project. | `./sa-plan add "Implement NIF security"` |
| `update <id> <status>` | Update a specific task's status (active, pending, completed). | `./sa-plan update 5e07f54a completed` |
| `backup` | Create a timestamped backup of the planning database. | `./sa-plan backup` |
| `sync` | Synchronize `PROJECT_TODOLIST.md` state to Git. | `./sa-plan sync` |

### Chaya Integration (Digital Twin)
| Command | Description | Example |
|:---|:---|:---|
| `chaya status` | Show Chaya health and mesh status. | `./sa-plan chaya status` |
| `chaya ooda` | Run an OODA cycle (Observe, Orient, Decide, Act). | `./sa-plan chaya ooda` |
| `chaya mesh` | Visualize the current mesh topology. | `./sa-plan chaya mesh` |

---

## 2. High-Performance Gleam CLI (`./sa-gleam`)
The Gleam CLI provides a modernized interface with expanded metadata support (like priorities) and is designed for high-concurrency multi-agent environments.

### Core Commands
| Command | Description | Example |
|:---|:---|:---|
| `status` | Show task list with status and priority from SQLite. | `./sa-gleam status` |
| `add "<title>" <priority>`| Add a task with priority (LOW, NORMAL, HIGH, CRITICAL). | `./sa-gleam add "Fix NIF" HIGH` |
| `start <id>` | Move a task to `in_progress`. | `./sa-gleam start 5e07f54a` |
| `complete <id>` | Move a task to `completed`. | `./sa-gleam complete 5e07f54a` |
| `update <id> <st> <pr>` | Batch update status and priority. | `./sa-gleam update ID completed CRITICAL` |
| `delete <id>` | Remove a task from the database. | `./sa-gleam delete ID` |
| `sync` | Import/Export between DB and `PROJECT_TODOLIST.md`. | `./sa-gleam sync` |

### Mesh & Container Management
| Command | Description | Example |
|:---|:---|:---|
| `up` | Start the entire mesh using optimized waves. | `./sa-gleam up` |
| `down` | Stop all core mesh containers. | `./sa-gleam down` |
| `mesh-status` | Show health status of all 8 core containers. | `./sa-gleam mesh-status` |
| `restart-node <name>` | Restart a specific container. | `./sa-gleam restart-node zenoh-router-1` |

### Special Flags
- `--daemon`: Run the system in SIL-6 daemon mode (persists in background).
- By default, `./sa-gleam` exits immediately after executing your command.

---

## 3. Robustness & Fallbacks
The system is designed to work **Offline (Mesh-Down)**:
1.  **NIF Tier**: `./sa-gleam` first attempts to use the high-speed Erlang SQLite NIF.
2.  **CLI Tier**: If the NIF fails (due to environment drift or permissions), it automatically falls back to the `sqlite3` system binary.
3.  **No-Hang**: The CLI will never hang waiting for Zenoh or DuckDB if they are unavailable.

---

## 4. Best Practices
- **Use IDs**: Commands like `update`, `start`, and `complete` require the 8-character hex ID (e.g., `5e07f54a`).
- **Parallel Usage**: You can add a task via `./sa-gleam` and see it immediately in `./sa-plan status`.
- **Git Persistence**: Always run `./sa-plan sync` after major task updates to ensure the markdown file and Git are updated.
