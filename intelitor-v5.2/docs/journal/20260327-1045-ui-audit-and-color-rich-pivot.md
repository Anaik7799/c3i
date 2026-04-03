# Journal Entry: 20260327-1045 - UI Audit and "Color Rich" Paradigm Shift

**Date**: 20260327-1045 CEST
**Status**: INITIALIZED
**Author**: Gemini CLI (Cybernetic Architect)
**Reference Plan**: `doc/plans/20260327-1030-ui-audit-and-verification-fix.md`

## 1.0 Summary of Intent
Today we initiate a major UI/UX pivot from the "Dark Cockpit" philosophy (management by exception) to a **"Color Rich Mechanism"**. This transition is driven by the need for higher cognitive engagement and real-time observability of system vitals, even when in nominal states. Simultaneously, we are recovering from a failure in the "Formal Verification Gates" (G1/G2) caused by syntax errors in our Agda proofs.

## 2.0 Strategic Pivot: 8x8 Fractal Matrix & Color Rich Interface
We are shifting from a simple "Dark Cockpit" model to a **8x8 Fractal Matrix** approach for UI auditing and testing.

### The 8x8 Matrix Paradigm:
- **Rows (8 Elements)**: Alarms, Guardian, Sentinel, Devices, Compliance, Analytics, KMS, Config.
- **Columns (8 Layers)**: L0 (Runtime) through L7 (Federation).
- **Audit Target**: 100% cell coverage across the matrix.

### Path & Flow Exhaustion:
- **Graph-Based Control Flow**: All UI state transitions (Elmish messages) are being mapped as a directed graph $G = (V, E)$. Testing will continue until all paths to terminal nodes are exhausted.
- **Data Flow Verification**: Verification of biomorphic telemetry from substrate (Zenoh) to the final presentation element.
- **User Use Cases**: Mapping 100% of user use cases to the matrix layers.

### Interface Profiles (Selectable):
- **Dark Cockpit**: Management by exception.
- **Color Rich**: Vibrant, active health visualization (Current Default).
- **Google Compliant**: Material Design 3 alignment.
- **Functionally Clean**: minimalist high-density data.

## 3.0 UI Artifact Inventory (Initial Audit)
| Artifact Type | Location | Stack | Current Philosophy |
|---------------|----------|-------|--------------------|
| **Phoenix LiveView** | `lib/indrajaal_web/live/` | Elixir/HEEx | Dark Cockpit |
| **Bolero WebUI** | `lib/cepaf/src/Cepaf.Cockpit.Web/` | F# (Blazor) | Dark Cockpit |
| **Avalonia GUI** | `lib/cepaf/src/Cepaf.Cockpit.Avalonia/` | F# (Desktop) | Dark Cockpit |
| **TUI Cockpit** | `lib/indrajaal/cockpit/prajna/` | Elixir/ANSI | Dark Cockpit |

## 4.0 Formal Verification Failure (G2 Analysis)
- **Error**: `ParseError` in `docs/formal_specs/agda_proofs.agda:226.5`.
- **Root Cause**: Invalid `where` block placement in `SecurityContext` record definition.
- **Resolution**: Move `_∈_` definition outside the record or into a parameterised module to ensure proper scoping for field types.

## 5.0 KPIs & Progress Tracking
- **CI Restoration**: G1/G2 recovery progress (0/2).
- **Audit Coverage**: 0% total.
- **Color Rich Migration**: 0% total.

## 6.0 Action Items (Immediate)
1. Fix Agda syntax in `agda_proofs.agda`.
2. Update `GEMINI.md` and `CLAUDE.md` with the new "Color Rich" mandate.
3. Begin systematic audit of `indrajaal_web` LiveView pages.
