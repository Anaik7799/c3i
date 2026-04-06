---
paths: lib/indrajaal/**/*.ex
---
# Ash 3.x Resource Rules
When working with Ash resources in this project:
# Required Patterns (SC-ASH-*)
- Use `Indrajaal.BaseResource` as base (SC-DB-001)
- Table names: `snake_case`, NO domain prefix
- Always use `uuid_primary_key :id` (SC-DB-005)
- Access tenant via `query.tenant` NOT context (SC-ASH3-001)
- Pass actor in `for_update(..., actor: actor)` (SC-ASH3-004)
# Action Patterns
- Use `force_change_attribute` in `before_action` (SC-ASH-001)
- Add `require_atomic? false` for function-based changes (SC-ASH-004)
- Pagination returns struct - use `.results` to access data
# Index Patterns
- Always use `create_if_not_exists` for indexes (SC-DB-012)
- Index names must be unique across all resources