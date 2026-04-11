# Changelog

All notable changes to the Indrajaal C3I system are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [22.5.0-CORTEX] - 2026-04-10

### Added
- CLAUDE.md §15.0 Chat Processing Pipeline (6-tier hedged inference, PipelineTracer)
- CLAUDE.md §16.0 Voice Processing Pipeline (5-tier cascade, Gemini Live WS)
- CLAUDE.md §17.0 Gleam Cortex & Gateway (ReAct loop, MoZ protocol, chat bridges)
- GEMINI.md Rust Cognitive Cortex section (13-module capability table)
- devenv.nix: SKIP_ZENOH_NIF="0" and WALLABY_ENABLED="true" in env block
- 14 new Rust-only capabilities in rust-gleam-split.md

### Changed
- Version aligned across all artifacts: CLAUDE.md, GEMINI.md, AGENTS.md, AGENT_BOOTSTRAP.md, mix.exs, OpenCode
- ELIXIR_ERL_OPTIONS: +fnu flag added to all compile commands (devenv.nix, CLAUDE.md, rules)
- §9.0 file inventory expanded: 225+ -> 283+ files, ~26K -> ~42K LOC
- rust-gleam-split.md: 21 -> 35 Rust-only capabilities
- operational-architecture.md: ignition_daemon -> planning_daemon (31 modules, 9,104 LOC)

### Fixed
- Version inconsistency: 6 different version strings across artifacts -> unified v22.5.0-CORTEX
- Missing SKIP_ZENOH_NIF=0 in devenv.nix env block (was only in scripts)
- Missing +fnu flag in base ELIXIR_ERL_OPTIONS

## [22.4.1-PLAN] - 2026-04-10

### Added
- Gemini Pro security review documentation
- Cost optimization analysis ($0.06/month)
- Live WebSocket fix for Gemini Live

## [22.4.0-CORTEX] - 2026-04-09

### Added
- 31-module Rust planning daemon (9,104 LOC across 26 modules)
- 6-tier hedged chat inference (Gemini Direct || OpenRouter -> Ollama -> rules)
- 5-tier voice cascade (Gemini Live WS -> REST -> Whisper.cpp -> ack)
- PipelineTracer: zero-write hot path, batch SQLite+Zenoh finish
- RAG pipeline: Smriti FTS5 context injection (~4ms)
- Semantic cache: 24h TTL, SQLite-backed
- 4 circuit breakers: per-tier, 3 failures -> 60s cooldown
- PII scrubber: email, phone, CC, SSN, IP redaction
- SMTP email: lettre crate, OAuth2, attachments
- 400-scenario simulator: 20 categories x 10 x 2 channels
- Ruliology engine: Wolfram-style cellular automata, causal graphs
- FMEA automation: trace-based failure mode analysis
- HA leader election: Primary/Backup/Standby via Zenoh lease
- 25+ chat commands (text + voice + MCP + Zenoh + rules)
- 10 security layers (Gemini-reviewed)

### Changed
- Cost reduced to $0.000002/msg ($0.06/month)

## [22.3.0-GLM] - 2026-04-08

### Added
- Unified c3i_nif (14 NIFs)
- 26 MCP tools (planning, system, knowledge, domain)
- 233 A2UI components
- ZMOF backplane active
- Muda waste reduction enforced
- sa-plan-daemon authoritative
- OpenClaw & HA integrated
