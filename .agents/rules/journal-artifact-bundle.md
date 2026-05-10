# Journal Artifact Bundle Rule for .agents

All .agents-compatible journal publication bundles must include:

- Markdown journal;
- HTML analysis report;
- HTML slide deck;
- email draft;
- operator handoff index;
- links manifest;
- sa-plan task evidence.

Use Rust/Gleam-only publication tooling. Validate local paths, relative links, route status, sa-plan evidence, and JSON manifests; run `sa-plan status`, `sa-plan sync`, and `sa-plan ingest-docs --dry-run` before closure when available. Record degraded-mode failures explicitly, separating historical evidence from current-pass evidence. Do not touch or stage `gdrive/` unless requested.
