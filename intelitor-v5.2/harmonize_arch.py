import re
import os

def update_file(filepath, replacements):
    if not os.path.exists(filepath):
        print(f"Skipping {filepath} - file not found.")
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    for old, new in replacements:
        if isinstance(old, re.Pattern):
            content = old.sub(new, content)
        else:
            content = content.replace(old, new)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

# Define global biomorphic replacements
global_replacements = [
    ("SIL-4", "SIL-6"),
    ("100ms", "30ms"),
    ("< 100ms", "< 30ms"),
    ("Manual Review", "Bicameral Verification Cycle (BVC)"),
    ("GA Readiness Score", "Shannon Entropy Gate ($H(S) < 0.2$)"),
    ("Log Context", "Epigenetic Tags")
]

# 1. Update Core Architecture Files
arch_files = [
    'docs/architecture/SIL6_FULL_CAPABILITY_ARCHITECTURE.md',
    'docs/architecture/HOLON_DATABASE_NAMING_SYSTEM.md',
    'docs/architecture/UNIVERSAL_HOLON_IDENTIFIER_SYSTEM_V2.md',
    'docs/architecture/HOLON_IMMORTAL_ARCHITECTURE.md',
    'docs/architecture/HOLON_IMMUTABLE_REGISTER.md'
]

for arch_file in arch_files:
    update_file(arch_file, global_replacements)

# 2. Update Master Execution Plans (Surgical update to primary active plans)
plan_files = [
    'docs/plans/BIOMORPHIC_EVOLUTIONARY_PLAN_V1.0.0.md',
    'docs/plans/PHASE4_MASTER_EXECUTION_SPEC.md',
    'docs/plans/20260105-fractal-mesh-completion-plan.md'
]

for plan_file in plan_files:
    update_file(plan_file, global_replacements)

print("Architectural and strategic documents harmonized to SIL-6 / 30ms.")
