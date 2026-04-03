# Documentation Refactoring & Grand Unification Plan (v20.0.0)

**Objective**: Align the `docs/` and `docs/journal/` file structure with the **Indrajaal v20.0.0 "Grand Unification"** architecture. Ensure specific clarity between "Active/Canonical" specifications and "Historical/Archive" artifacts.

## 1. Classification Schema

We will classify all artifacts into four states:
*   **🟢 CANONICAL (Active)**: Core v20.0.0 specifications, current operational guides, and active plans.
*   **🟡 REFERENCE (Supporting)**: Deep dives, theoretical analysis, and educational material that remains valid.
*   **🔴 ARCHIVE (Historical)**: v19, v5.1, and v5.2 execution logs, old journals, and completed task lists.
*   **🟣 TRANSIENT (To Process)**: Temp analysis files or scratchpads to be merged or deleted.

## 2. Organization Strategy (The "Fractal Sort")

### A. Journal Archiving (`docs/journal/`)
The journal folder contains 100+ files. We will structure them by "Era":
*   `docs/journal/archive/v5_1_legacy/`: Entries prior to Dec 2025 (SOPv5.1 era).
*   `docs/journal/archive/v19_convergence/`: Entries from Dec 01 - Dec 29 (The lead-up to Unification).
*   `docs/journal/active/`: Entries from Dec 30 onwards (v20.0.0 Era).

### B. Documentation Root (`docs/`)
Clean up the root `docs/` folder by enforcing the domain-driven directory structure:
*   **Move**: `container-architecture.md` -> `docs/architecture/containers/`
*   **Move**: `implementation-final.md` -> `docs/implementation/reports/`
*   **Update**: `README.md` to explicitly point to `PROJECT_INDEX.md` as the entry point.

### C. Indexing (`PROJECT_INDEX.md`)
*   Regenerate `PROJECT_INDEX.md` to reflect the new structure.
*   Add a "Quick Links" section for the v20 Core Axioms (CLAUDE.md/GEMINI.md).

### D. Knowledge Management & Zettelkasten
*   **UID Standardization**: Enforce `YYYYMMDD-HHMM-[slug]` as the immutable Zettel ID for all atomic notes.
*   **Graph Linking**: Introduce a `## Connections` footer in all docs for explicit backlinking (e.g., `Ref: [[20251230-0020]]`).
*   **AI Enablement**: Create `docs/cortex/` to house high-density context summaries (token-optimized) for RAG retrieval.

## 3. Execution Plan

### Phase 1: Journal Archiving (Immediate)
1.  Create archive directories: `docs/journal/archive/{v5_1_legacy,v19_convergence}`.
2.  Batch move journal files based on timestamp/filename.
    *   `202507*` to `202511*` -> `v5_1_legacy`
    *   `20251201` to `20251229` -> `v19_convergence`
3.  Verify only v20 relevant journals remain in `docs/journal`.

### Phase 2: Root Cleanup
1.  Analyze loose files in `docs/` (`advanced-compilation-...`, `ash_coverage...`).
2.  Move to `docs/analysis/` or `docs/scripts/` (if executable).
3.  Delete `.~lock.*` files.

### Phase 3: Header Standardization (The "v20 Stamp")
1.  Identify the "Core 10" documents (Architecture, Safety, Setup).
2.  Prepend/Update the YAML metadata or Header to:
    ```markdown
    **Version**: 20.0.0-GRAND-UNIFICATION
    **Status**: ACTIVE
    **Zettel-ID**: [YYYYMMDD-HHMM]
    ```

### Phase 4: Index Regeneration
1.  Run a script to crawl the new structure.
2.  Generate a fresh `PROJECT_INDEX.md` with emoji indicators for status (🟢, 🔴).

### Phase 5: Fractal Knowledge Base Transformation (Holonic Architecture)
**Objective**: Convert static documentation into a **Complex Adaptive System** where notes are "Holons" (Whole/Part entities).

#### 1. The Holonic Metadata Schema Implementation
Create `docs/architecture/HOLONIC_SCHEMA_V1.md` defining the 4-layer metadata model for YAML frontmatter:
*   **Layer 1: Fractal (Scale)**: `holon_level` (Atomic/Molecular/Organism/Ecosystem), `parent_holon_id`, `fractal_path`.
*   **Layer 2: Evolutionary (Time)**: `entropy_score` (calculated via decay_rate), `version`, `genealogy`.
*   **Layer 3: Richness (Semantics)**: `rhetorical_function` (Axiom/Hypothesis/Evidence), `confidence_score`.
*   **Layer 4: Actionable (Utility)**: `potential_output`, `bridge_note_candidates`.

#### 2. Identity & Graph Injection
*   **UUID Assignment**: Assign a UUID (`uuid:`) to every file in `docs/` and `docs/journal/active`.
*   **Change Tracking**: Add `agent_comments` and `references_used` fields to frontmatter to track AI modifications.
*   **Link Normalization**: Convert file paths to UUID-based graph links where possible.

#### 3. The "Gardener" Agent Scripts
Develop `scripts/knowledge/gardener.exs` to automate system evolution:
*   **Entropy Calculator**: $\text{Entropy} = \frac{\Delta t \times \text{decay\_rate}}{\text{verification\_status}}$
*   **Pruning Bot**: Suggest archiving for High Entropy + Low Utility nodes.
*   **Grafting Bot**: Identify contradictions between Atomic nodes.

## 4. Verification
*   Check that `docs/journal` is clean (contains only recent/active entries).
*   Confirm `PROJECT_INDEX.md` links are valid.
*   **Schema Validation**: Verify 5 random active docs possess valid Holonic Frontmatter.
*   **Entropy Check**: Run the `gardener.exs` script (dry run) to generate an Entropy Report.

---
**Status**: Ready for Execution
**Author**: Gemini (Cybernetic Architect)
