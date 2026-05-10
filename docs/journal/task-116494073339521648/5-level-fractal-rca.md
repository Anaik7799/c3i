# 5-Level Fractal RCA — Plaintext API Key in `.pi/config.json`

**Discovered**: 2026-04-30 during pass-31 hygiene sweep
**Severity**: INFINITE (per SC-VAULT-004 once registered)
**ZK**: [zk-c1e9c949422ed9e7] secrets module RCA precedent · [zk-bd82645aedcb5ef4] Stub-That-Lies family · [zk-d64b60994dfeee3b] Claude ZK Blindness pattern

---

## Trigger

Working-tree `grep -rE "sk-ant-api03"` during gitignore hygiene found **two** files with a live Anthropic API key:
- `.pi/config.json:13`
- `.pi/config.example.json:13`

Plus `./sa-plan list-prefs --category secrets` revealed **8 plaintext** entries in the `UserPreferences` SQLite table (`gemini_api_key`, `gemini_api_key_live`, `openrouter_api_key`, `gmail_app_password`, `telegram_token`, `google_client_id`, `google_client_secret`, `google_oauth_refresh`).

The `.pi/config.example.json` is supposed to be a placeholder; instead it had the real key.

---

## 5-Why Decomposition

### Why-1 (L1 — atomic event)
**Why was the live Anthropic API key in `.pi/config.json`?**

→ Pi-mono's first-run setup (`.pi/pi-ctl.mjs:onboard()`) reads `ANTHROPIC_API_KEY` from environment and writes it into `config.json` as a JSON-serialized object. There is no encryption step. There is no "is this committable?" check.

### Why-2 (L2 — local-system event)
**Why was `config.json` not gitignored when the key was written?**

→ `.pi/` was added to `.gitignore` during pass-31 hygiene (commit `5d40b451`, 2026-04-30). The file was already on disk before that, having been written by Pi-mono onboarding at session start (visible in git history). The gitignore-after-the-fact pattern means the file existed in working tree, would have been seen by `grep`, and could have been committed accidentally. Saved only by us never running `git add .pi/`.

### Why-3 (L3 — process / tooling event)
**Why did no scanner catch the key on disk?**

→ No pre-commit hook scans for API key shapes. No CI step runs `git secrets` or `gitleaks`. No periodic cron scans the working tree. The `cargo audit` we run is for dependency vulnerabilities, not secrets-on-disk.

→ The Pi-mono PII scrubber (`.pi/pii-scrubber.ts`) runs at message-send time only, not at file-write time. It would have masked the key in a *log* but did nothing to prevent it being *written* to JSON.

### Why-4 (L4 — architectural event)
**Why was the architectural pattern "secret in JSON next to source code" allowed at all?**

→ No vault primitive existed. Pi-mono needs a way to authenticate to Anthropic. Without a vault, the choices were: (a) env var (lost on shell exit), (b) shell config / dotfile (committed accidentally), (c) JSON config (the chosen path). Option (c) is the worst from a confidentiality standpoint but the most ergonomic for "first-run onboarding" UX.

→ The C3I-side existing pattern was `UserPreferences[secrets]` — also plaintext, but at least inside a SQLite file in `data/kms/`. Pi-mono is a sibling Node.js project that didn't know about it. **Architectural pattern: each subsystem invents its own secret storage**.

### Why-5 (L5 — governance / institutional event)
**Why was no governance forbidding plaintext secrets at any layer?**

→ SC-SEC-049 ("never commit production secrets to version control") existed in the constraint registry. But:
1. It had **no enforcing rule** — no RETE-UL rule fires on plaintext-at-rest detection
2. It had **no tested invariant** — no wiring guard test asserts `forall secret: encrypted_at_rest`
3. It had **no formal spec** — no TLA+ / Apalache / Agda predicate
4. It had **no pre-commit hook** — Jidoka principle violated

→ This is the [zk-d64b60994dfeee3b] "advisory rule with no enforcement" anti-pattern, applied to security governance instead of ZK recall. The result is identical: the rule exists in docs, agents nominally know it, but the system never trips when it's violated.

---

## Single root cause

**Vault primitive missing.** Every other finding above is downstream of this one:
- L1 (Pi-mono writes JSON) → no vault to write into
- L2 (gitignore-after-the-fact) → no vault, so `.pi/` was an unmanaged staging area
- L3 (no scanner) → no canonical place to scan; secrets could be anywhere
- L4 (each subsystem invents its own) → no shared primitive to standardize on
- L5 (no enforcing governance) → no enforcement target — what would you measure compliance against?

A vault primitive **enables** the governance: `cargo tree | grep tongsuo` enforces SC-VAULT-CRYPTO-001 because there's a thing called a vault that can be audited; `forall callers: vault.get not db::get_preference("secrets")` enforces SC-VAULT-003; `pre-commit refuse plaintext API-key shapes` enforces SC-VAULT-004 because the safe path (vault) exists.

---

## Counter-factual analysis

If the vault had existed:
- L1: Pi-mono onboarding would write to vault REST endpoint, not JSON
- L2: no `.pi/config.json` with secrets to gitignore
- L3: secret-shape grep would find nothing on disk
- L4: standardized primitive shared by C3I + Pi-mono + future subsystems
- L5: SC-VAULT-004 enforces by construction; pre-commit hook is the safety net

The single fix (vault primitive) cascades through all 5 levels.

---

## Ruliological view (Wolfram-style)

| Cellular rule analogue | Maps to | Observation |
|---|---|---|
| **Rule 30 (chaos)** | Sliding-window entropy of "places where secrets live" | High entropy (8 SQL + 2 JSON + various env vars) → fragile |
| **Rule 110 (complexity emergence)** | Each subsystem's secret-handling pattern as a cell | 3 distinct patterns (env, JSON, SQL) — no convergence |
| **Rule 184 (traffic / backpressure)** | Frequency of secret-related incidents | Every hygiene sweep uncovers something new |
| **Lyapunov on diversity** | `λ = d(distinct_secret_locations) / d(time)` | λ > 0 historically — diversifying not converging |
| **Causal graph** | Nodes = secret-bearing artifacts, edges = "modifies" | Disconnected components → no central authority |

**Vault primitive forces λ < 0**: distinct secret locations decreases over time as callers migrate to the vault. Convergence to a single canonical location.

---

## FMEA on this incident

| Failure mode | Sev (S) | Occur (O) | Detect (D) | RPN | Mitigation |
|---|---:|---:|---:|---:|---|
| Plaintext key on disk | 9 | 7 | 5 | **315** | Vault primitive (Slice B) + pre-commit hook (Slice F) |
| Plaintext key in JSON committed to git | 10 | 4 | 7 | **280** | gitignore + pre-commit + vault |
| Plaintext key in SQLite | 8 | 8 | 4 | **256** | Vault encrypted K/V (Slice B) |
| Pi-mono writes JSON without confirmation | 7 | 6 | 6 | 252 | REST endpoint + Wisp gate (Slice E) |
| Each subsystem invents own secret store | 9 | 6 | 8 | **432** | Standardized vault primitive |
| Governance rule with no enforcement | 8 | 9 | 9 | **648** | RETE-UL + wiring guard + formal spec |

**Top RPN** (governance with no enforcement) = 648 → addressed by Slice F (rules + tests + formal spec + pre-commit hook).

**ΣRPN before mitigation**: 2,183
**ΣRPN after Slices A-F (target)**: < 600 (72% reduction)

---

## Action items (each tracked as sa-plan task)

| # | Action | Closes | sa-plan ID |
|---|---|---|---|
| 1 | Vendor RustyVault + scrub | L1, L2, L4 root cause | 116494258501316658 ✅ |
| 2 | Build NIF + Gleam wrapper | L4 root cause | 116494259017971447 |
| 3 | Boot KEK chain | L4 root cause | 116494259021299827 |
| 4 | GCP sync actor | L4 root cause | 116494259024062400 |
| 5 | Caller flip + .pi/ placeholder | L1, L2 | 116494259026350434 |
| 6 | Slice F governance + tests + specs | L5 root cause | 116494259028115525 |
| 7 | RCA + TPS countermeasures journal | L5 root cause | 116494259704460565 ✅ (this doc) |
| 8 | Pre-commit secret-scan hook | L3 | 116494259712597823 |
| 9 | Anthropic key rotation | L1 (immediate) | 116494259719342353 |

---

## Closure criteria (5-level)

This RCA is **closed** when:
- ✅ L1 fixed: vault primitive shipped, Pi-mono uses REST endpoint
- ✅ L2 fixed: pre-commit hook refuses plaintext API-key shapes
- ✅ L3 fixed: weekly cargo-audit + secret-scan cron active
- ✅ L4 fixed: SC-ARCH-SPLIT extended with "all subsystems use vault REST"
- ✅ L5 fixed: SC-VAULT-001..025 + tests + TLA+/Agda spec + RETE-UL rules in production

Estimated closure: **end of Slice F** (4-6 sessions from now).
