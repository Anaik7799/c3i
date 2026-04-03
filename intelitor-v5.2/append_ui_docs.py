import os

docs_to_update = ["CLAUDE.md", "GEMINI.md"]
ui_content = """
## 97.0 WebUI and HMI Operational Guidelines (Dark Cockpit)

### 97.1 Core Philosophy: The Dark Cockpit (SC-HMI-001)
The WebUI and TUI follow the "Dark Cockpit" design (NASA-STD-3000, NUREG-0700), reducing cognitive load by ensuring:
*   **Management by Exception**: Only deviations from normal (alarms, errors) are highlighted. Normal states are visually minimal or dim.
*   **Color Semantics**: Standardized RGB hex colors:
    *   **Gray/Blue**: Normal/Nominal states.
    *   **Amber/Red**: Deviations, cautions, and warnings.
    *   **Pure Red (#FF0000)**: Critical alarms and emergency stops.
    *   **Cyan (#00FFFF)**: Active connections and focused elements.
*   **Visual Decay (SC-HMI-003)**: Data not updated within threshold (e.g., 2-5 seconds) MUST be visually grayed out/marked stale.

### 97.2 WebUI Technology & Architecture
*   **F# Bolero Mandate (SC-COCKPIT-002)**: The WebUI MUST be implemented in F# using Bolero (F# on Blazor WebAssembly). NO Phoenix/Elixir LiveView for the primary WebUI.
*   **MVU Pattern**: Implements The Elm Architecture (TEA/MVU) for immutable and predictable state transitions.
*   **Zone Layout (SC-HMI-002)**: Follows strict 4-zone layout (Annunciator Bar, Primary Display, Message Log, Control Surface).
*   **Accessibility (SC-UI-005)**: MUST support WCAG 2.1 AA and be 100% keyboard navigable.

### 97.3 Safety-Critical UI Patterns
*   **Arm & Fire State Machine (SC-SAFETY-001)**: Destructive actions (e.g., Emergency Shutdown) MUST use multi-step sequence: Navigate (Select) → Arm (Enter) → Fire (Sustained Hold 3s). NO single keystroke triggers.
*   **Trend Vectors (SC-HMI-002)**: Real-time metrics MUST display trend indicators (↑, ↓, →).
*   **Supervisory Control**: UI MUST show the automation state (e.g., AUTO-HEALING, MANUAL) instead of just sensor data.
*   **Dead Man's Switch (SC-SAFETY-003)**: If backend connection is lost (>2000ms), a full-screen stale data overlay MUST appear, locking inputs.
"""

for doc in docs_to_update:
    if os.path.exists(doc):
        with open(doc, 'a') as f:
            f.write("\n" + ui_content)
        print(f"Updated {doc}")

# Also update AGENT_BOOTSTRAP.md if it exists
if os.path.exists("AGENT_BOOTSTRAP.md"):
    with open("AGENT_BOOTSTRAP.md", 'a') as f:
        f.write("\n" + ui_content)
    print("Updated AGENT_BOOTSTRAP.md")

