import os

def update_file(path, search_marker, new_content):
    if not os.path.exists(path):
        print(f"File not found: {path}")
        return
    with open(path, 'r') as f:
        content = f.read()
    
    if search_marker in content:
        updated_content = content.replace(search_marker, search_marker + new_content)
        with open(path, 'w') as f:
            f.write(updated_content)
        print(f"Updated {path}")
    else:
        # If marker not found, append to end
        with open(path, 'a') as f:
            f.write("\n" + new_content)
        print(f"Appended to {path}")

new_rules = """
## 98.0 Plan & Journal Synchronization Mandate (SC-SYNC-DOC)

### 98.1 Mandatory Timestamps
All plan files (`doc/plans/*.md`) MUST feature a standard journal-style timestamp in the header:
- Format: `YYYYMMDD-HHMM CEST`
- Position: Top of file, below title.

### 98.2 Mandatory Journaling
Every plan creation or significant update MUST trigger a corresponding entry in `docs/journal/`.
- The journal MUST reference the plan ID/name.
- The plan MUST reference the journal entry for detailed analysis.

## 99.0 Color Rich Mechanism & Interface Profiles (SC-HMI-010)

### 99.1 Paradigm Shift: Dark Cockpit → Color Rich
Indrajaal is migrating from the "Dark Cockpit" (dim-by-default) to a **"Color Rich Mechanism"**.
- **Active Chromaticism**: Use vibrant, high-saturation colors to represent real-time system health and metabolic rate.
- **Dynamic Feedback**: UI elements should pulsate and shift hue based on live telemetry (Zenoh streams).

### 99.2 Universal Interface Profiles
All UI artifacts (Web, Desktop, TUI) MUST support selectable **Interface Profiles**:
1.  **Dark Cockpit**: Nominal states dimmed; alarm-centric focus.
2.  **Color Rich**: High-vibrancy health visualization; metabolic awareness.
3.  **Google Compliant**: Material Design 3 alignment; extreme accessibility.
4.  **Functionally Clean**: minimalist, high-density data; zero aesthetic overhead.

### 99.3 8x8 Fractal Matrix Audit (SC-HMI-011)
All UI testing and auditing MUST follow the **8x8 Fractal Matrix**:
- **Dimensions**: 8 Elements (Alarms, Guardian, etc.) x 8 Layers (L0 to L7).
- **Goal**: 100% path coverage for all data/control flows across all matrix cells.
"""

update_file("GEMINI.md", "## 97.0 WebUI and HMI Operational Guidelines (Dark Cockpit)", new_rules)
update_file("CLAUDE.md", "## 97.0 WebUI and HMI Operational Guidelines (Dark Cockpit)", new_rules)
update_file("AGENT_BOOTSTRAP.md", "## 97.0 WebUI and HMI Operational Guidelines (Dark Cockpit)", new_rules)

