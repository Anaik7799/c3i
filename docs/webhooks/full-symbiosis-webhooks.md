# Full Symbiosis Webhooks

## Scope

This document defines local hook/webhook behavior for full symbiosis across Work, C3I, pi-mono, Claude, Gemini, `.agents`, and Codex/GPT.

## Required Webhook Semantics

- **Local first**: prefer local command hooks that emit `systemMessage` JSON over outbound network webhooks.
- **Idempotent**: repeated hook execution must not duplicate tasks, leak secrets, or mutate unrelated files.
- **Timeout-bounded**: every hook must declare a timeout and degrade safely.
- **Non-secret-bearing**: hook messages must never print tokens, passwords, app passwords, cookies, refresh tokens, SSH keys, or vault material.
- **Evidence-backed**: hooks that gate work must point to an actual rule, skill, agent, or journal file.
- **Mirror-aware**: hooks that trigger on rules, skills, agents, settings, or webhooks must remind agents to update Claude, Gemini, `.agents`, Pi-mono, and Codex-compatible mirrors.

## Implemented Hook Classes

| Hook | Event | Purpose |
|---|---|---|
| `full-symbiosis-universal-pre` | `PreToolUse` on `Write|Edit` | Warn before governance files drift from their mirrors. |
| `full-symbiosis-universal-post` | `PostToolUse` on `Write|Edit` | Remind agents to validate JSON, links, mirror coverage, and evidence. |
| `agents-full-symbiosis-pre` | `.agents` `PreToolUse` | Provide Codex/GPT-compatible parity guidance for `.agents` runtimes. |
| `agents-full-symbiosis-post` | `.agents` `PostToolUse` | Provide Codex/GPT-compatible closure checks after edits. |
| `pi-full-symbiosis-pre` | Pi-mono `PreToolUse` | Preserve pi-mono compatibility with Claude/Gemini/.agents mirrors. |
| `pi-full-symbiosis-post` | Pi-mono `PostToolUse` | Require pi-mono mirror and evidence checks before closure. |
| `nested-c3i-full-symbiosis-pre` | Nested C3I `PreToolUse` | Keep nested C3I `.claude`, `.gemini`, `.agents`, docs, and runtime governance aligned. |
| `nested-c3i-full-symbiosis-post` | Nested C3I `PostToolUse` | Require nested C3I mirror and evidence checks before closure. |

## Guard Message Contract

Hook guard output should be a single JSON object:

```json
{"systemMessage":"Full symbiosis gate: mirror rules/skills/agents/hooks across Claude, Gemini, .agents, Codex/Pi/C3I; enforce Effect TS, fp-core Rust, Safe Rust, Gleam/Rust-only automation; update journal evidence; run jq/link checks."}
```

## Trigger Paths

- `.claude/rules/**`
- `.gemini/rules/**`
- `.agents/rules/**`
- `.claude/skills/**`
- `.gemini/skills/**`
- `.agents/skills/**`
- `.claude/agents/**`
- `.gemini/agents/**`
- `.agents/agents/**`
- `settings.json`
- `settings.local.json`
- `docs/webhooks/**`

## Failure Modes

- **No output**: allowed when the edited file does not match a trigger path.
- **Non-zero hook failure**: treat as degraded warning only unless the runtime explicitly enforces blocking hooks.
- **Invalid JSON output**: fix the hook command before making additional governance edits.
- **Secret exposure**: remove the hook output immediately, rotate exposed material if needed, and record the incident.
- **Mirror miss**: create or update the missing mirror before closing the task.

## Validation

- Run `jq empty` on changed hook settings.
- Run the local journal/webhook link checker when available.
- Confirm no `gdrive/` files were changed.
- Confirm every active surface has the rule, skill, agent, and hook needed by its runtime.
