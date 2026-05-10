---
name: full-symbiosis
description: Use when Codex, Claude, Gemini, Pi-mono, C3I, rules, skills, agents, hooks, webhooks, journals, task ledgers, or cross-agent compatibility must be synchronized into a full symbiotic state.
---

# Full Symbiosis

## Use When

- The user asks for symbiosis, compatibility, cross-agent sync, rules, skills, agents, hooks, webhooks, task ledgers, journals, or Codex/GPT parity.
- A change touches `.claude`, `.gemini`, `.agents`, `.pi`, `AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, settings hooks, or cross-agent docs.
- A generated TypeScript/Rust rule must be made enforceable across all active agent runtimes.

## Workflow

1. Read nearest `AGENTS.md` and `full-symbiosis.md`.
2. Identify all affected mirrors: `.claude`, `.gemini`, `.agents`, `.pi`, Codex skills, work adapter, C3I root, nested C3I, pi-mono, and any repo-local agent surface with settings hooks.
3. Update rules first, then skills, agents, hooks/webhooks, task ledgers, and journal evidence.
4. Keep hooks/webhooks idempotent, timeout-bounded, non-secret-bearing, and safe under repeated execution.
5. Preserve language mandates: TypeScript uses Effect, browser JS is Effect TS IIFE output, Rust uses fp-core where applicable, automation is Gleam or Rust.
6. Validate changed JSON with `jq empty`; validate Markdown links when a local checker exists.
7. Report exact files changed and any mirror intentionally not touched.

## Mirror Checklist

- Rule files: `.claude/rules/full-symbiosis.md`, `.gemini/rules/full-symbiosis.md`, `.agents/rules/full-symbiosis.md`.
- Skill files: `.claude/skills/full-symbiosis/SKILL.md`, `.gemini/skills/full-symbiosis/SKILL.md`, `.agents/skills/full-symbiosis/SKILL.md`, and user-local Codex skill when available.
- Agent files: `.claude/agents/full-symbiosis-supervisor.md`, `.gemini/agents/full-symbiosis-supervisor.md`, `.agents/agents/full-symbiosis-supervisor.md`.
- Hook files: `.claude/settings.json`, `.gemini/settings.json`, `.agents/settings.json`, `.claude/settings.local.json`, and pi-mono equivalents where present.
- Nested C3I files: when `sub-projects/c3i/.claude`, `.gemini`, or `.agents` exists, mirror the same rule, skill, agent, settings hook, and webhook evidence there.
- Webhook docs: `docs/webhooks/full-symbiosis-webhooks.md` in work, root C3I, nested C3I, and pi-mono when docs exist or are created for hook evidence.

## Execution Rules

- Prefer patching Markdown/JSON directly; do not introduce new non-Gleam/non-Rust automation.
- Do not rewrite broad existing settings; append the smallest safe hook entries.
- Do not stage, commit, or modify `gdrive/` unless the user explicitly asks.
- Do not hide pre-existing dirty work; isolate the full-symbiosis delta in the final report.
- If a mirror cannot be written, record the exact blocked path and validation already completed.

## Required Checks

- `jq empty` for changed `settings.json` / `settings.local.json`.
- `rg -n "fp-ts|TaskEither"` for touched TypeScript paths.
- `rg -n "unwrap\\(|expect\\(|panic!"` for touched Rust paths.
- Local link checker for journal/webhook docs when available.
