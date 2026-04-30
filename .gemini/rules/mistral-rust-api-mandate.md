# mistral.rs Rust-API-only Mandate (SC-INFER-RUST-API)

## Mandate

**mistral.rs MUST be wired into Gemma-4-E2B-it through its native in-process Rust API only.** No external server, no HTTP shim, no Python bridge, no GPU-required path, no streaming-only API, no quantisation without explicit operator opt-in.

The current daemon at `sub-projects/c3i/native/planning_daemon/src/{mcp_inference,inference_daemon}.rs` already complies; this rule encodes the constraint so future PRs cannot regress it.

ZK: [zk-bc5968dec2854bf0] daemon-only consolidation · [zk-7a8572fc03563f0a] gemma sizing.

## STAMP Constraints

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-INFER-RUST-API-001 | Gemma-4 model load MUST use `mistralrs::MultimodalModelBuilder::new(...).build().await` directly in `mcp_inference::init_mistral_text` | CRITICAL | grep `MultimodalModelBuilder::new` shows exactly one call site |
| SC-INFER-RUST-API-002 | All inference dispatch MUST go through `mistralrs::Model::send_chat_request(req: impl RequestLike)` — no `mistralrs-server`, `mistralrs-bench`, `mistralrs-pyo3` | CRITICAL | `cargo tree -p planning_daemon \| grep -E 'mistralrs-(server\|pyo3\|bench)'` empty |
| SC-INFER-RUST-API-003 | Multimodal payload assembly MUST use `mistralrs::MultimodalMessages` + `add_image_message` / `add_audio_message` / `add_video_message` | HIGH | grep matches all three; never `TextMessages` for multimodal |
| SC-INFER-RUST-API-004 | The model handle MUST live in a process-singleton `OnceLock<mistralrs::Model>` so cost is amortised across requests | CRITICAL | one `OnceLock` declaration; no per-request `build()` |
| SC-INFER-RUST-API-005 | Model decoding MUST detach from the request future (fixed v22.11.4) so `tokio::time::timeout` cannot drop a mistralrs `chat()` future mid-flight | CRITICAL | `tokio::spawn` + `oneshot` pattern in dispatch; live test `z_live_infer_text_deadline_zero_rejects` proves channel survives cancellation |
| SC-INFER-RUST-API-006 | Audio inputs MUST flow through `mistralrs::AudioInput::from_bytes` (which wraps symphonia); no pre-decoded PCM hand-rolled into the daemon | HIGH | only call site in `infer_multimodal_via_mistral` |
| SC-INFER-RUST-API-007 | Video inputs MUST flow through `mistralrs::VideoInput::from_frames(Vec<DynamicImage>, fps, None)` | HIGH | one call site in daemon; `image::DynamicImage` decoded per-frame from base64 PNG/JPEG |
| SC-INFER-RUST-API-008 | Future modality features (tool calls, structured output, embeddings reuse) MUST use the corresponding mistralrs Rust APIs (`Tool`, `generate_structured`, `EmbeddingModelBuilder`) — never an HTTP wrapper | HIGH | review-time check; new code must show direct API usage |

## Forbidden APIs (do not introduce)

- `mistralrs-server` crate (HTTP server wrapper)
- `mistralrs-pyo3` crate (Python bridge)
- `mistralrs-bench` crate (use our own `tests/inference_bench.rs`)
- `Model::stream_chat_request` (SSE — out of scope; see plan §15)
- HTTP shims around the Rust `Model`
- GPU-required `with_paged_attn` flags
- `IsqBits::*` / `IsqSetting` (quantisation — operator opt-in only)

## Currently-used surface (audit 2026-04-27)

14 mistralrs Rust APIs in active use across 2 files:

| File | API |
|---|---|
| `mcp_inference.rs` | `MultimodalModelBuilder::new`, `with_logging`, `build` (one call site each) |
| `mcp_inference.rs` | `Model::chat`, `Model::send_chat_request` |
| `mcp_inference.rs` | `MultimodalMessages::new` + `add_image_message` + `add_audio_message` + `add_video_message` |
| `mcp_inference.rs` | `AudioInput::from_bytes` |
| `mcp_inference.rs` | `VideoInput::from_frames` |
| `embedding.rs` | `EmbeddingModelBuilder::new` (separate vector pipeline) |
| `inference_daemon.rs` | `tokio::spawn` + `oneshot` (detached dispatch) |

## AOR Rules

| ID | Rule |
|----|------|
| AOR-INFER-RUST-API-001 | NEVER add `mistralrs-server`, `mistralrs-pyo3`, or `mistralrs-bench` to `Cargo.toml` |
| AOR-INFER-RUST-API-002 | NEVER call `Model::stream_chat_request*` from the daemon dispatch path |
| AOR-INFER-RUST-API-003 | ALWAYS construct multimodal requests with `MultimodalMessages`, never `TextMessages` |
| AOR-INFER-RUST-API-004 | ALWAYS detach mistralrs futures via `tokio::spawn` + `oneshot` before applying `timeout` |
| AOR-INFER-RUST-API-005 | ALWAYS hold `Model` in a `OnceLock` singleton; one model per process |

## CI mandate gate

The verification recipe in plan § 7 step 1 runs these greps — all must return empty:

```bash
cargo tree -p planning_daemon | grep -E '^(│ +)?(├|└|│)─ mistralrs(-server|-pyo3|-bench)' && exit 1
grep -RnE '(stream_chat_request|with_paged_attn|IsqBits)' \
   sub-projects/c3i/native/planning_daemon/src/ && exit 1
```

A future `cargo deny` rule should also `[[bans]]` `mistralrs-server`, `mistralrs-pyo3`, `mistralrs-bench` to fail closed.

## Cross-references

- Plan: `sub-projects/c3i/docs/plans/20260427-2106-gemma4-multimodal-test-corpus-plan.md` § 0 + § 0.1
- Implementation: `sub-projects/c3i/native/planning_daemon/src/mcp_inference.rs:106-176`, `sub-projects/c3i/native/planning_daemon/src/inference_daemon.rs:200-296`
- Test gate: `sub-projects/c3i/native/planning_daemon/tests/inference_live.rs::z_live_infer_text_deadline_zero_rejects`
- Companion rule: `.claude/rules/test-data-corpus.md` (corpus contract)
- Constraint registry: `.claude/rules/constraint-registry.md` (family registration)
