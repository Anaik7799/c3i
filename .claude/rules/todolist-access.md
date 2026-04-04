# Task Management Authority (SC-TODO-AUTHORITY)
**Status**: CRITICAL | **Mandate**: SC-TODO-001

## 1. Authoritative Tooling
All updates to tasks, status transitions, and `PROJECT_TODOLIST.md` MUST be performed exclusively via the `sa-plan` F# tool. 

## 2. Strict Prohibitions
- **NO Manual Edits**: Direct modification of `PROJECT_TODOLIST.md` using `write_file`, `replace`, `echo`, or editors is STRICTLY FORBIDDEN.
- **NO Elixir/Shell Scripts**: Use of `mix todo`, `elixir scripts/planning/todolist_manager.exs`, or any other shell-based task manager is FORBIDDEN and DEPRECATED.
- **NO Bypassing**: Any attempt to modify the planning state without `sa-plan` is a violation of the SIL-6 Safety Kernel.

## 3. Enforcement Logic
- **Read-Only Artifact**: `PROJECT_TODOLIST.md` is a derived artifact. It is overwritten by `sa-plan` based on the authoritative SQLite/DuckDB planning state. Manual changes will be LOST.
- **Audit Trail**: `sa-plan` generates Zenoh events and OTel spans for every task update. Manual edits bypass this audit trail and are thus considered non-compliant.

## 4. Usage
- `sa-plan add "Description" P1`
- `sa-plan update <ID> --status completed`
- `sa-plan status`
