# Plan: 20260327-1500-chrome-devtools-ui-verification.md

**Created**: 20260327-1500 CEST
**Last Updated**: 20260327-1500 CEST
**Status**: DRAFT
**Framework**: SOPv5.11 + SIL-6 Biomorphic Evolution + chrome-devtools

## 1.0 Objective
Verify the operational readiness and visual integrity of the new **UNICON** UI using high-fidelity browser instrumentation. This plan ensures that the "Color Rich" paradigm, product branding, and safety-critical FSMs are functioning as specified across the 8x8 fractal matrix.

## 2.0 KPI Dashboard (Testing Phase)

| Test Category | Target | Progress | Status |
|:---|:---:|:---:|:---|
| **Visual Check** | 100% Palette Match | 0% | ⚪ PENDING |
| **Branding Check** | Logo + Pulse Active | 0% | ⚪ PENDING |
| **Navigability** | 46/46 Routes | 0% | ⚪ PENDING |
| **Safety FSM** | Arm & Fire Verified | 0% | ⚪ PENDING |
| **Connectivity** | Dead Man's Switch | 0% | ⚪ PENDING |

## 3.0 5-Level Execution Detail

### 3.1 - Browser Instrumentation Readiness
#### 3.1.1 - Target Acquisition
- 3.1.1.1 - Connect to `http://localhost:4000/` using `chrome-devtools`.
- 3.1.1.2 - Verify page title: "System Navigation Portal".

### 3.2 - Visual & Theme Audit
#### 3.2.1 - Chromatic Verification
- 3.2.1.1 - Check DOM for `.color-rich` class application.
- 3.2.1.2 - Verify CSS variable injection: `--surface-primary`, `--status-healthy`.
#### 3.2.2 - Branding Verification
- 3.2.2.1 - Verify SVG logo presence in the header.
- 3.2.2.2 - Verify `.health-pulse` animation state.

### 3.3 - Navigability Audit (G = (V, E))
#### 3.3.1 - Outbound Path Exhaustion
- 3.3.1.1 - Automate clicks to all 46 system routes from the root portal.
- 3.3.1.2 - Verify HTTP 200/OK for each terminal vertex $v$.
#### 3.3.2 - Inbound Path Verification
- 3.3.2.1 - Verify "System Portal" link in global header on all sampled pages.

### 3.4 - Safety-Critical FSM Verification
#### 3.4.1 - Arm & Fire Charge Cycle
- 3.4.1.1 - Simulate "Sustained Hold" on critical action buttons.
- 3.4.1.2 - Verify button "charge" CSS transition and Zenoh publication.
#### 3.4.2 - Dead Man's Switch
- 3.4.2.1 - Simulate offline state (>2000ms).
- 3.4.2.2 - Verify overlay visibility and input lockout.

### 3.5 - Reporting & Documentation
- 3.5.1 - Capture screenshots of all 4 Interface Profiles.
- 3.5.2 - Document all findings in `docs/journal/20260327-1500-chrome-devtools-ui-verification.md`.

## 4.0 Verification Gate
Testing is complete when all 46 system routes are proven navigable and the "Color Rich" mechanism is confirmed active across all 8 layers.
