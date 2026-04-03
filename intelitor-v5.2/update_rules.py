import os

def append_to_rule(filename, content):
    path = os.path.join(".claude/rules/", filename)
    if os.path.exists(path):
        with open(path, 'a') as f:
            f.write("\n" + content)
        print(f"Updated {path}")

ui_rules = """
### Color Rich & Interface Profiles (SC-HMI-010)
- **Mandate**: Shift from Dark Cockpit to **Color Rich Mechanism**.
- **Implementation**: Support 4 selectable profiles: Dark Cockpit, Color Rich, Google Compliant, Functionally Clean.
- **Visuals**: Vibrant colors for healthy states; dynamic chromaticism linked to Zenoh telemetry.
- **Audit**: Follow **8x8 Fractal Matrix** (8 Elements x 8 Layers) for all UI verification.
- **Completeness**: 100% path coverage for data/control flows across all matrix cells.
"""

doc_rules = """
### Plan & Journal Synchronization (SC-SYNC-DOC)
- **Timestamp**: All plan headers MUST include `YYYYMMDD-HHMM CEST`.
- **Mirroring**: Every plan MUST have a corresponding detailed journal entry.
"""

append_to_rule("prajna-biomorphic.md", ui_rules)
append_to_rule("safety-critical.md", ui_rules)
append_to_rule("change-management.md", doc_rules)

