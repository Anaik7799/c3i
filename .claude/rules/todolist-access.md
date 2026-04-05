# Task Management Authority (SC-TODO-AUTHORITY)
**Status**: CRITICAL | **Mandate**: SC-TODO-001

## 1. Authoritative Tooling
All updates to tasks, status transitions, and `PROJECT_TODOLIST.md` MUST be performed exclusively via the Rust `sa-plan-daemon` binary at `./sub-projects/intelitor-v5.2/target/release/sa-plan-daemon` (or the `./sa-plan` wrapper script at repo root).

## 2. Strict Prohibitions
- **NO Manual Edits**: Direct modification of `PROJECT_TODOLIST.md` using `write_file`, `replace`, `echo`, or editors is STRICTLY FORBIDDEN.
- **NO Elixir/Shell Scripts**: Use of `mix todo`, `elixir scripts/planning/todolist_manager.exs`, or any other shell-based task manager is FORBIDDEN and DEPRECATED.
- **NO F# CLI**: The legacy `dotnet run --project lib/cepaf/src/Cepaf.Planning.CLI` is DEPRECATED and FORBIDDEN. Use the Rust binary only.
- **NO Bypassing**: Any attempt to modify the planning state without `sa-plan-daemon` is a violation of the SIL-6 Safety Kernel.

## 3. Enforcement Logic
- **Read-Only Artifact**: `PROJECT_TODOLIST.md` is a derived artifact. It is overwritten by `sa-plan-daemon` based on the authoritative SQLite/DuckDB planning state. Manual changes will be LOST.
- **Audit Trail**: `sa-plan-daemon` generates Zenoh events and OTel spans for every task update. Manual edits bypass this audit trail and are thus considered non-compliant.
- **Binary**: The Rust daemon (`./target/release/sa-plan-daemon`) is the sole implementation. The `./sa-plan` wrapper at repo root delegates directly to it.

## 4. Usage
- `./sa-plan status` or `sa-plan-daemon status`
- `./sa-plan add "Description" P1`
- `./sa-plan update <ID> <status>`

## 5. MCP+Zenoh Integration
`sa-plan-daemon` operations are available as MCP tools via the Zenoh backplane (SC-ZMOF-001, SC-ZMOF-003). Task mutations publish OTel spans to `indrajaal/plan/spans/**` for distributed audit.
