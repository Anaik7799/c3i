import re

def update_file(filepath, replacements):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    for old, new in replacements:
        if isinstance(old, re.Pattern):
            content = old.sub(new, content)
        else:
            content = content.replace(old, new)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

# Update Morphogenesis Roadmap
roadmap_file = 'journal/2026-03/20260322-0100-fractal-organic-evolution-morphogenesis-roadmap.md'
roadmap_replacements = [
    (re.compile(r'## 9\. Season 4 \(Mutations 7-8\) — BRANCH: Fractal Multiplication \(L3-L5\)'),
     r'## 9. Season 4 (Mutations 7-8) — BRANCH: Fractal Multiplication (L3-L5)\n*   **Local Antibody Generation Rules**: Implement decentralized cellular automata-based healing where test failures trigger neighboring nodes to autonomously generate antibody regression tests.'),
    (re.compile(r'## 11\. Season 6 \(Mutations 11-12\) — FRUIT: Morphogenesis Activation \(L5-L7\)'),
     r'## 11. Season 6 (Mutations 11-12) — FRUIT: Morphogenesis Activation (L5-L7)\n*   **LethalMutationGate & Univalence Equality Check**: Implement intent evaluation (Free Monads) and utilize HoTT (Homotopy Type Theory) to prevent redundant attacks on functionally isomorphic mutations.'),
]
update_file(roadmap_file, roadmap_replacements)

# Update Morphogenesis Design Doc
design_file = 'journal/2026-03/20260321-2221-fsharp-test-infra-ai-optimized-morphogenesis-design.md'
design_replacements = [
    (re.compile(r'\*\*The Bicameral Verification Cycle \(BVC\) Pipeline:\*\*'),
     r'**The Bicameral Verification Cycle (BVC) Pipeline:**\n0.5. **Pure Intent Interpretation**: Evaluate AI proposals as Free Monads against formal specs before IO execution to prevent logically fatal code execution.'),
    ("Log Context", "Epigenetic Tags"),
]
update_file(design_file, design_replacements)

print("Additional updates applied successfully.")
