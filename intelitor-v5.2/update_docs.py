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

# 1. Update Morphogenesis Roadmap
roadmap_file = 'journal/2026-03/20260322-0100-fractal-organic-evolution-implementation-plan.md'
roadmap_replacements = [
    ("Implementation Plan", "Morphogenesis Roadmap"),
    ("GA Readiness Score", "Shannon Entropy Gate ($H(S) < 0.2$)"),
    ("YAML validation", "Self-Extracting Biomorphic Ark Binary (Reed-Solomon + BLAKE3)"),
    ("Markdown backups", "Self-Extracting Biomorphic Ark Binary (Reed-Solomon + BLAKE3)"),
    ("Manual Review", "Bicameral Verification Cycle (BVC)"),
    ("Files/Directories", "UHI-Identified Holons"),
    (re.compile(r'## 6\. Season 1 — SEED: Foundation Planting \(L0-L1\)'),
     r'## 6. Season 1 (Mutations 1-2) — SEED: Foundation Planting (L0-L1)\n*   **IKE Ingestion**: Execute initial IKE ingestion before commencing season tasks.'),
    (re.compile(r'## 7\. Season 2 — SPROUT: First Differentiation \(L1-L2\)'),
     r'## 7. Season 2 (Mutations 3-4) — SPROUT: First Differentiation (L1-L2)\n*   **IKE Ingestion**: Execute IKE ingestion before commencing season tasks.\n*   **Adversarial FMEA Injection**: Prioritize Adversarial FMEA Injection for RPN > 50.'),
    (re.compile(r'## 8\. Season 3 — GROW: Structural Formation \(L2-L3\)'),
     r'## 8. Season 3 (Mutations 5-6) — GROW: Structural Formation (L2-L3)\n*   **IKE Ingestion**: Execute IKE ingestion before commencing season tasks.\n*   **UIR-Zenoh-SyncAdapter**: Implement cross-holon sync adapter.\n*   **Fractal Layer Boundary Verification**: Add verification tasks using Quint Model Checking.'),
    (re.compile(r'## 9\. Season 4 — BRANCH: Fractal Multiplication \(L3-L5\)'),
     r'## 9. Season 4 (Mutations 7-8) — BRANCH: Fractal Multiplication (L3-L5)\n*   **IKE Ingestion**: Execute IKE ingestion before commencing season tasks.'),
    (re.compile(r'## 10\. Season 5 — BLOOM: Full Observability \(L4-L6\)'),
     r'## 10. Season 5 (Mutations 9-10) — BLOOM: Full Observability (L4-L6)\n*   **IKE Ingestion**: Execute IKE ingestion before commencing season tasks.\n*   **Metabolic Heartbeat Synchronization**: Sync 30s global and 30ms local loops.'),
    (re.compile(r'## 11\. Season 6 — FRUIT: Morphogenesis Activation \(L5-L7\)'),
     r'## 11. Season 6 (Mutations 11-12) — FRUIT: Morphogenesis Activation (L5-L7)\n*   **IKE Ingestion**: Execute IKE ingestion before commencing season tasks.\n*   **Apoptosis 2oo3 Voting Verification**: Execute 2oo3 verification.\n*   **Agda Formal Proofs**: Verify formal proofs.'),
    (re.compile(r'## 12\. Season 7 — RESEED: Self-Reproducing Evolution \(L6-L7\+\)'),
     r'## 12. Season 7 (Evolution Gate) — RESEED: Self-Reproducing Evolution (L6-L7+)\n*   **IKE Ingestion**: Execute IKE ingestion before commencing season tasks.\n*   **Founder-Symbiosis Telemetry Integration ($H_{sym}$)**: Primary KPI.'),
]
update_file(roadmap_file, roadmap_replacements)

# 2. Update Morphogenesis Design
design_file = 'journal/2026-03/20260321-2221-fsharp-test-infra-ai-optimized-morphogenesis-design.md'
design_replacements = [
    ("indrajaal/morph/", "indrajaal/cepaf/evolution/"),
    (re.compile(r'< 100ms'), "30ms"),
    ("Dimension 10: User Experience", "Dimension 10: Founder-Alignment Reflection ($A_{founder}$)"),
    (re.compile(r'### 25\.1 The Five Pillars of SIL-6 Biomorphic Morphogenesis.*?\n\n', re.DOTALL),
     r'### 25.1 The Five Pillars of SIL-6 Biomorphic Morphogenesis (§59)\n\n'
     r'**The Bicameral Verification Cycle (BVC) Pipeline:**\n'
     r'0.5. **Pure Intent Interpretation**: Evaluate free monads.\n'
     r'1. **Semantic Probe**: Semantic check.\n'
     r'2. **Formal Audit**: Structural check.\n'
     r'3. **Security Gate**: Security audit.\n'
     r'4. **Math Check**: Numeric validation.\n\n'),
    (re.compile(r'(## 11\. Dimension 4.*?)(?=## 12\.)', re.DOTALL),
     r'\1\n### 11.X FFI Memory Safety & Wire Parity\nDimension 11: FFI Memory Safety & Wire Parity ensures zero-copy binary contracts between Elixir Rustler and F# csbindgen.\n\n'),
    ("Topological Defect Map", "Topological Defect Map (Monoidal Error Accumulation for F# Expecto integration)"),
]
update_file(design_file, design_replacements)

# 3. Update GEMINI.md
gemini_file = 'GEMINI.md'
gemini_replacements = [
    ("<= 100ms", "<= 30ms"),
    (re.compile(r'(\*\*SC-ZEN-003\*\*: Topic Hierarchy:.*?\n    - `indrajaal/cepaf/query/\*` \(Synchronous Data\))', re.DOTALL),
     r'\1\n*   **SC-ZEN-004**: Enforce UHI path resolution for all cross-holon database lookups.\n*   **SC-ZEN-005**: Pi-Calculus Bisimulation Checking mandated for EvolutionBus topology.'),
    (re.compile(r'(## 107\.0 Biomorphic.*?)(?=\n\n)', re.DOTALL),
     r'\1\n\n## 108.0 The Bicameral Verification Cycle (BVC)\n\nThe BVC is the mandatory gate for autonomic mutations:\n1. Semantic\n2. Formal\n3. Security\n4. Math'),
    (re.compile(r'(\*   `elixir scripts/agents/elixir_oracle\.exs \[FILE\]` \(Elixir AST probe\))', re.DOTALL),
     r'\1\n*   `fsharp-intelligence`, `elixir-oracle`, `math-oracle`, `security-sentry` (Specialized MCP Oracles registered).'),
    (re.compile(r'(\*\*TOTAL\*\* \| \*\*170\*\* \| \*\*89\*\* \| \*\*70\*\* \| \*\*36\*\* \| \*\*365\*\*)', re.DOTALL),
     r'\1\n\n*Note: The 365-test minimum is enforced for GA release sign-off.*'),
    (re.compile(r'100ms \(SC-OODA-001\)', re.IGNORECASE), "30ms (SC-OODA-001)"),
    (re.compile(r'100ms cycle', re.IGNORECASE), "30ms cycle")
]
update_file(gemini_file, gemini_replacements)

print("Files updated successfully.")
