# Container Script Archival & Unification Plan (Archive-Only)

**Date**: 2025-12-22
**Status**: REVISED & ADOPTED
**Objective**: To enforce the VTO protocol as the Single Source of Truth by archiving all redundant and unsafe container management scripts. **No scripts will be deleted.**

## 1. Revised Strategy: Archive-Only
Based on the principle of data preservation, we will not permanently delete any scripts. Instead, all 34 identified scripts will be moved to a dedicated, non-executable `archive` directory.

**Benefits**:
*   **Safety**: Removes outdated scripts from the `scripts/` directory, preventing accidental execution.
*   **Audit Trail**: Preserves the complete history of the project's orchestration logic for future analysis and audits.
*   **Reversibility**: Allows for easy restoration of a script if a specific piece of logic is needed in the future.

## 2. Archival Structure
A new top-level `archive/` directory will be created. The original directory structure will be preserved within it to maintain context.

**Example Structure**:
```
archive/
└── scripts/
    ├── containers/
    │   ├── complete_environment_rebuild.sh (Archived)
    │   └── nixos_only_container_rebuild.exs (Archived)
    ├── demo/
    │   └── test_pure_nixos_stack.exs (Archived)
    └── security/
        └── container_hardening.sh (Archived)
```

## 3. Execution Plan (Manual Steps)

1.  **Create Archive Directories**:
    *   `mkdir -p archive/scripts/containers`
    *   `mkdir -p archive/scripts/container_operations`
    *   `mkdir -p archive/scripts/demo`
    *   `mkdir -p archive/scripts/security`
    *   `mkdir -p archive/scripts/ga_release`
    *   *...and so on for all relevant parent directories.*

2.  **Move Scripts via `git mv`**:
    *   The `git mv` command is critical as it preserves the file's history within Git.
    ```bash
    git mv scripts/containers/complete_environment_rebuild.sh archive/scripts/containers/
    git mv scripts/containers/nixos_only_container_rebuild.exs archive/scripts/containers/
    # Repeat for all 34 scripts...
    ```

3.  **Commit**:
    *   A single, atomic commit will be made with a clear message referencing this plan.
    *   `git commit -m "refactor: Archive 34 obsolete container scripts to enforce VTO protocol"`

## 4. Verification
After execution, a `find scripts -name "*.sh"` command should yield a significantly reduced list, containing only essential, non-container-related scripts. All archived scripts will be present under `archive/scripts/`.
