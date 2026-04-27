# MCP Tool Federation Verifier Report — Pass 5

**🔗 HTTPS Link**: https://vm-1.tail55d152.ts.net:8443/task-id/116450171390820012/20260422-212140-task-116450171390820012-swarm-ignition-ultrapass5-mcp-federation.md

**Task**: 116450171390820012 · Child: 116450172204441764 · Date: 2026-04-23 05:14 UTC

---

## 1. Summary

| Registry | Module | Tool count |
|---|---|---|
| Gleam MCP | `lib/cepaf_gleam/src/cepaf_gleam/mcp/tools.gleam` | 26 |
| Pi Bridge | `lib/cepaf_gleam/src/cepaf_gleam/bridge/pi_tools.gleam` | 43 |
| Overlap | matched names | 11 |
| Gleam only | unique to C3I | 15 |
| Pi only | unique to Pi bridge | 32 |
| **Total federated (union)** | | **58** |

## 2. Overlapping tools — require handler-match verification

- `knowledge_search`
- `plan_add`
- `plan_list`
- `plan_search`
- `plan_status`
- `plan_update`
- `system_dashboard`
- `system_health`
- `system_immune`
- `system_verification`
- `system_zenoh`

## 3. Gleam-only tools

- `dark_cockpit_mode`
- `evolution_metrics`
- `fractal_status`
- `integrity_check`
- `kms_catalog`
- `mesh_topology`
- `metabolic_state`
- `ooda_decide`
- `ooda_phase`
- `plan_get`
- `plan_list_pending`
- `podman_containers`
- `prajna_health`
- `read_file`
- `verification_run`

## 4. Pi-only tools

- `api_health_check`
- `auto_evolve`
- `bash`
- `edit`
- `edit-diff`
- `file-mutation-queue`
- `file_context`
- `find`
- `gemma_chat`
- `git_status`
- `gleam_build`
- `gleam_compute`
- `gleam_format_check`
- `gleam_test`
- `graph_analyze`
- `grep`
- `knowledge_ingest`
- `ls`
- `monitor`
- `muda_check`
- `page_dom_check`
- `path-utils`
- `pre_commit_audit`
- `read`
- `render-utils`
- `render_diagrams`
- `send_email`
- `server_restart`
- `session_resume`
- `tool-definition-wrapper`
- `truncate`
- `write`

## 5. FMEA (federation)

| Failure | S | O | D | RPN | Mitigation |
|---|---|---|---|---|---|
| Overlap name → handler divergence | 7 | 6 | 4 | 168 | Add schema diff test |
| Pi-only tool missing schema in C3I MCP | 5 | 5 | 3 | 75 | Auto-import Pi schemas |
| Gleam-only tool unreachable from Pi | 6 | 4 | 3 | 72 | Add Pi bridge stubs |

## 6. Next actions (child-task level)
- Schema-diff test: overlap names must share input/output types (new sub-child)
- `mcp/tools.gleam` import policy: both registries export a canonical JSON manifest
- `pi_tools.gleam` should populate into `indrajaal/l3/mcp/catalog/**` on Zenoh so cortex can verify live
