# Journal: 20260404-1500 - `./sa-up dashboard` Fractal Analysis — Batch 3 (NIF, Recovery, Fractal)

**Status**: AUTHORITATIVE / SIL-6 / GOLD-LEVEL
**Scope**: 7-Level BDD Flows, Fractal Analysis, Ratatui Techniques, and Mathematical Coverage for Tabs 6-8.
**Mandate**: SC-NIF-006, SC-FMEA-007, SC-IGNITE-003 compliance.

---

## 1. Batch 3: Fractal Analysis & BDD Flows

### 1.1 Tab 6: NIF (Substrate Guard & Binary Integrity)
*   **Implemented Function**: `draw_nif_tab` (in `tui.rs`)
*   **Fractal Focus**: L4 (System) through L1 (Atomic).
*   **Technique**: Substrate Contamination Detection + ELF Parser Results.
*   **7-Level BDD Flow**:
    1.  **L4 (System Integrity)**: Verify Substrate Guard detects Axiom 0.1 violation.
        *   **Given**: Host-side `_build` or `deps` directory exists.
        *   **When**: `draw_nif_tab` evaluates `state.substrate_contaminated`.
        *   **Then**: Banner displays `✗ CONTAMINATED` in `INDRAJAAL_RED` with rollback instructions.
    2.  **L1 (Atomic Binary)**: Verify NIF binary ELF metadata validation.
        *   **Given**: `libzenoh_ffi.so` is compiled for `x86_64` but running on `aarch64`.
        *   **When**: `draw_nif_tab` renders the results table.
        *   **Then**: Row displays `✗ libzenoh_ffi.so` with "Invalid Machine Arch" detail.
    3.  **L2 (Component Logic)**: Verify LibC flavor compatibility.
        *   **Given**: Container uses `musl` (Alpine) but NIF depends on `glibc`.
        *   **When**: `libc_flavor` is matched against NIF DT_NEEDED entries.
        *   **Then**: UI highlights the mismatch in `INDRAJAAL_YELLOW`.

### 1.2 Tab 7: Recovery (FMEA Playbooks & Resiliency)
*   **Implemented Function**: `draw_recovery_tab` (in `tui.rs`)
*   **Fractal Focus**: L3 (Transaction) through L4 (System).
*   **Technique**: RPN Risk Scoring + Active Playbook Tracker.
*   **7-Level BDD Flow**:
    1.  **L4 (System Orchestration)**: Verify high-RPN failure modes are prioritized.
        *   **Given**: "NIF Cascade" has RPN 252; "Config drift" has RPN 130.
        *   **When**: `draw_recovery_tab` renders the table.
        *   **Then**: "NIF Cascade" is styled in bold `INDRAJAAL_RED`.
    2.  **L3 (Transaction State)**: Verify active playbook status in real-time.
        *   **Given**: Agent is executing "Ghost Purge" playbook.
        *   **When**: `state.active_playbooks` contains the mode.
        *   **Then**: Row displays `▶ ACTIVE` in blinking `INDRAJAAL_YELLOW`.
    3.  **L4 (System History)**: Verify recovery outcome persistence.
        *   **Given**: 5 successful recoveries and 1 failure have occurred.
        *   **When**: History summary renders.
        *   **Then**: Displays `5 ok` (green) and `1 failed` (red).

### 1.3 Tab 8: Fractal (Hierarchical Health Propagation)
*   **Implemented Function**: `draw_fractal_tab` (in `tui.rs`)
*   **Fractal Focus**: L0 (Constitutional) through L7 (Federation).
*   **Technique**: Vertical Health Propagation Graph + Tiered Percentages.
*   **7-Level BDD Flow**:
    1.  **L0-L7 (Global Health)**: Verify failure propagation from L0 up to L7.
        *   **Given**: L0 (Guardian) fails a heartbeat check.
        *   **When**: `layer_health(0)` returns `0.0%`.
        *   **Then**: All dependent layers (L1-L7) display "FAILURES propagate UP" with red indicators.
    2.  **L4 (System/Tier Mapping)**: Verify tier-based health calculation.
        *   **Given**: 2 out of 3 Zenoh routers are healthy.
        *   **When**: `layer_health(6)` (Ecosystem) calculates `2/3`.
        *   **Then**: L6 bar renders at 66% with `INDRAJAAL_YELLOW`.
    3.  **L5 (Cognitive Context)**: Verify recovery propagation down from L5.
        *   **Given**: Cognitive layer triggers a rollback.
        *   **When**: Fractal graph renders arrows.
        *   **Then**: UI displays "↓ RECOVERY propagates DOWN" to illustrate intent flow.

---

## 2. Advanced Ratatui & Agent UI Techniques (Applied)

1.  **Substrate Contamination Sensor (NIF Tab)**:
    *   Running `find` or `ls` via `podman exec` to detect host-side artifacts that cause dynamic linker crashes.
    *   **Benefit**: Proactive prevention of the most common SIL-6 boot failure (glibc/musl mismatch).
2.  **RPN Color Matrix (Recovery Tab)**:
    *   Mapping Risk Priority Numbers (Severity x Occurrence x Detection) to a 3-tier color scale.
    *   **Benefit**: Instant situational awareness of "Critical Paths" vs "Maintenance Paths".
3.  **Fractal Recursive Health (Fractal Tab)**:
    *   Using a closure-based `layer_health` mapper that groups container states into the 8 Indrajaal tiers.
    *   **Benefit**: Simplifies 16-container complexity into a human-readable 8-layer vertical stack.

---

## 3. Mathematical Coverage & Verification

1.  **ELF Header Determinism (NIF Tab)**:
    *   The ELF parser (goblin-based) is verified against a corpus of valid/invalid .so files.
    *   **Proof**: No NIF is marked "VALID" unless `e_machine` matches the host architecture.
2.  **RPN Monotonicity (Recovery Tab)**:
    *   The table sorting (FMEA Top-5) ensures that risk is always presented in descending order.
    *   **Verification**: Test harness injects random RPNs and asserts the `Row` order.
3.  **Health Aggregate Safety (Fractal Tab)**:
    *   The `layer_health` function uses `f64` for percentage but rounds to `usize` for bar rendering.
    *   **Invariant**: `filled + empty == bar_width` is maintained via `round()` and subtraction.

---
**Authoritative Audit**: SC-NIF-006 / SC-FMEA-007 Compliant.
**Next Steps**: Proceed to Final Batch 4 (Tabs 9-11: Security, Logs, Agent UI).
