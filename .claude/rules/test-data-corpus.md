# Test Data Corpus Mandate (SC-TESTDATA)

## Mandate

Every test fixture under `sub-projects/c3i/native/planning_daemon/tests/data/` (and any future test-corpus tree) MUST satisfy the universal contract below **and** the modality-specific gemma-4 input requirements derived from `mistralrs-core-0.8.1/src/vision_models/gemma4/inputs_processor.rs`.

This rule prevents the [zk-bd82645aedcb5ef4] *Stub That Lies* anti-pattern (RPN 729) where synthetic-only fixtures pass the wire test but silently break under real model invocation.

ZK: [zk-bd82645aedcb5ef4] Stub That Lies · [zk-eb8267e7d7259b8e] cache pollution · [zk-7a8572fc03563f0a] gemma sizing.

## Universal STAMP Constraints

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TESTDATA-001 | License-clean: PD / CC0 / CC-BY-{3.0,4.0} / CC-BY-SA / MIT / Apache-2.0 / synthetic only | CRITICAL |
| SC-TESTDATA-002 | Reproducible: committed *or* fetched by `tests/data/fetch.sh` (offline-first, SHA-256 verified, retries with backoff) | CRITICAL |
| SC-TESTDATA-003 | SHA-256 manifest in `tests/data/MANIFEST.toml` per binary fixture; `inference_manifest_check.rs` fails on any mismatch | CRITICAL |
| SC-TESTDATA-004 | Per-asset ground truth: `{ground_truth_substring \| ground_truth_regex, language, intent}` recorded in MANIFEST or alongside | HIGH |
| SC-TESTDATA-005 | No PII / no secrets / no scrapeable identities (SC-SEC-003) — per-fixture review at fetch time | CRITICAL |
| SC-TESTDATA-006 | Size budget: ≤ ~250 KB per asset, ≤ ~2 MB per modality subtree (commit-friendly) | HIGH |

## Per-modality (model-aware)

### Text — SC-TESTDATA-TXT

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TESTDATA-TXT-001 | All prompts MUST be valid UTF-8 ≤ 8 192 tokens (gemma-4 max_position_embeddings) | HIGH |
| SC-TESTDATA-TXT-002 | Coverage: short / long / multilingual / code / unicode-edge / RTL / emoji / CJK / adversarial / refusal-bait | HIGH |
| SC-TESTDATA-TXT-003 | Multilingual span: ≥ 6 languages from {EN, ES, DE, JA, ZH, AR, HE, KO, FR, RU} | MEDIUM |
| SC-TESTDATA-TXT-004 | Schema per row in `tests/data/text/prompts.jsonl`: `{id, prompt, expected_substr, expected_regex, language, intent, tags[]}` | HIGH |
| SC-TESTDATA-TXT-005 | Refusal-bait prompts MUST have `expected_regex` matching at least one refusal token (cannot, won't, refuse, ...) | HIGH |

### Image — SC-TESTDATA-IMG

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TESTDATA-IMG-001 | Native size = **384×384** RGB (gemma-4 16-px patch grid → 24×24 = 576 patches) | HIGH |
| SC-TESTDATA-IMG-002 | All synthetic fixtures committed at 384×384 canonically; sweep tests probe 64/224/512/1024 to validate vision-processor rescale | HIGH |
| SC-TESTDATA-IMG-003 | Format coverage: PNG (8-bit RGB), JPEG, WebP — at least one fixture per format | MEDIUM |
| SC-TESTDATA-IMG-004 | Categories: solid colour (≥12), shape (≥4), text-on-image (≥5), real photo (≥4 PD), digit (MNIST sample), document (DocVQA sample), chart | HIGH |
| SC-TESTDATA-IMG-005 | Adversarial coverage: low-contrast + rotated + noise-overlay (≥3 fixtures) | MEDIUM |
| SC-TESTDATA-IMG-006 | Per-fixture ground-truth keyword recorded; live test asserts reply contains keyword | HIGH |

### Audio — SC-TESTDATA-AUD

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TESTDATA-AUD-001 | Native sample rate = **16 kHz mono 16-bit PCM** (gemma-4 mel: n_mels=128, n_fft=400, hop=160) | CRITICAL |
| SC-TESTDATA-AUD-002 | Minimum length = 3 200 samples ≈ 0.2 s at 16 kHz; below that the mel processor rejects (GR-AUD-002) | CRITICAL |
| SC-TESTDATA-AUD-003 | Synthetic fixtures committed at 16 kHz / 0.5 s = 8 000 samples (≥ 2.5× floor); SR sweep tests probe 8/16/22.05/44.1/48 kHz | HIGH |
| SC-TESTDATA-AUD-004 | Codec coverage: WAV-PCM-16 + WAV-PCM-32 + FLAC + MP3 + OGG-Vorbis + OPUS — ≥ 1 fixture per codec | MEDIUM |
| SC-TESTDATA-AUD-005 | Categories: silence + sine-tones (≥3 freq) + noise (white/pink/brown) + chirp + real speech EN (LibriSpeech 16 kHz native) + non-EN (LibriVox) + ambience (Freesound CC0) + 2-speaker mix | HIGH |
| SC-TESTDATA-AUD-006 | Common Voice (default 48 kHz) — DROPPED from corpus; LibriSpeech-clean preferred for native-rate match | HIGH |

### Video — SC-TESTDATA-VID

| ID | Constraint | Severity |
|----|------------|----------|
| SC-TESTDATA-VID-001 | Minimum 4 frames per fixture (gemma-4 video-processor floor; GR-VID-001) | CRITICAL |
| SC-TESTDATA-VID-002 | Maximum 32 frames (daemon cap; GR-VID-002 rejects above) | HIGH |
| SC-TESTDATA-VID-003 | Per-frame native size 384×384 RGB (matches vision projection); sweep tests probe 64/224 for rescale-path validation | HIGH |
| SC-TESTDATA-VID-004 | FPS sweep: 4 / 8 / 12 / 24 — at least one fixture per FPS class | MEDIUM |
| SC-TESTDATA-VID-005 | Storage: `{fps, ground_truth, frames_b64:[base64-PNG, …]}` JSON | HIGH |
| SC-TESTDATA-VID-006 | Categories: static (same frame ×4) + fade (gradient) + motion (moving square) + pan (horizontal scroll) + ≥1 real Kinetics-400 mini (CC-BY-4.0) + Wikimedia PD clip | HIGH |

## License compatibility (SC-TESTDATA-001)

ALLOWED: PD, CC0, CC-BY-3.0, CC-BY-4.0, CC-BY-SA-3.0, CC-BY-SA-4.0, MIT, Apache-2.0, original synthetic.

REJECTED: UCF101, HMDB51, AVA, any *NonCommercial* clause, any *NoDerivatives* clause. These are research-only and incompatible with the daemon's Apache-2.0 licence.

`tests/data/ATTRIBUTION.md` MUST list every CC-BY / CC-BY-SA fixture with author + source URL + licence.

## AOR Rules

| ID | Rule |
|----|------|
| AOR-TESTDATA-001 | NEVER commit a fixture that fails its modality's native-size constraint (image 384×384 / audio 16 kHz / video ≥4 frames) without explicit `// SWEEP-TEST-FIXTURE: …` comment + targeted test case |
| AOR-TESTDATA-002 | NEVER reference a fixture path from a test without a corresponding MANIFEST.toml entry |
| AOR-TESTDATA-003 | NEVER add a real-world fixture without recording attribution in ATTRIBUTION.md |
| AOR-TESTDATA-004 | ALWAYS run `tests/inference_manifest_check.rs` before committing fixture changes |
| AOR-TESTDATA-005 | ALWAYS regenerate via `gen.py` rather than hand-editing synthetic fixture bytes |

## CI gate

`tests/inference_manifest_check.rs` runs in every CI cycle and fails on:

1. SHA-256 mismatch between fixture and MANIFEST.toml entry
2. Shannon-H of (modality × outcome × class) below 2.5 bits
3. Test-count divergence D_EA > 10 % from plan §§ 5.2-5.3 expected counts

## Cross-references

- Plan: `docs/plans/20260427-2106-gemma4-multimodal-test-corpus-plan.md` § 2 (criteria) + § 3 (datasets) + § 5.0.2 (math gates)
- Companion rule: `.claude/rules/mistral-rust-api-mandate.md`
- Constraint registry: `.claude/rules/constraint-registry.md`
- Test gate: `tests/inference_manifest_check.rs`
- Generator: `tests/data/gen.py`
- Manifest source: `tests/data/MANIFEST.toml`
