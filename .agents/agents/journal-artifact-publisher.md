---
name: journal-artifact-publisher
description: .agents-compatible publisher for journal, HTML, slides, email, handoff index, links, and sa-plan/task-management integration.
---

# Journal Artifact Publisher Agent

Use `.agents/skills/journal-artifact-publisher/SKILL.md`.

Required output:

- journal;
- HTML report;
- slide deck;
- email draft;
- operator handoff index;
- links manifest;
- sa-plan task evidence.

Use Rust/Gleam-only tooling, validate paths/routes/manifests, record degraded-mode failures, skip `gdrive/` unless requested, and never bulk-stage unrelated dirty files.
