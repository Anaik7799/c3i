# https://vm-1.tail55d152.ts.net:8443/task-id/1a92520c

# sa-plan ACME Unification — Code Merge Plan (Ultrathink)

**Generated:** 2026-04-21 07:20 UTC
**Scope:** make `sa-plan` the single, coherent ACME/TLS authority across all hosts
(public + tailnet) using a strategy selector and a unified config.

---

## 1. Current state (verified by code inspection)

### 1.1 Two parallel ACME implementations exist

| Aspect | Path A — `serve --acme` | Path B — `serve-tls` / `acme-*` |
|---|---|---|
| Source | `web/server.rs::start_server_with_acme` | `tls.rs::cmd_serve_tls` + `cmd_acme_issue` + `cmd_acme_status` + `cmd_acme_renew` + `cmd_acme_preflight` |
| LOC | ~80 | 524 |
| Challenge type | TLS-ALPN-01 only | HTTP-01 only |
| Ports | HTTPS only (1) | HTTP + HTTPS (2) |
| Domain validation | none | `validate_domain()` blocks `.ts.net` and bare hostnames |
| Auto port fallback | yes (443→8443) | no |
| HTTP→HTTPS redirect | no | yes (`redirect_http`) |
| Cache | optional `DirCache` | mandatory `DirCache` |
| Preflight | none | `cmd_acme_preflight` (also exposed via API) |
| Issue/status/renew CLI | no | yes |
| systemd unit | no | `deploy/systemd/sa-plan-tls.service` |
| Env example | no | `deploy/systemd/sa-plan-tls.env.example` |
| Setup script | no | `scripts/sa-plan-tls-setup.sh` |
| Wired in CLI | `Commands::Serve { acme, ... }` | `Commands::AcmeIssue/Status/Renew/Preflight/ServeTls` |

### 1.2 Operationally relevant truth
- `vm-1.tail55d152.ts.net` is a **tailnet-only** host. Let's Encrypt **cannot** reach it for HTTP-01 or TLS-ALPN-01.
- Path B's `validate_domain` correctly rejects `.ts.net` ⇒ `serve-tls` cannot serve our actual host.
- Path A does not reject ⇒ would silently fail at LE challenge time.
- Today's deployed solution (this session): tailscale-issued cert via `tailscale serve --https=443` and a self-signed local terminator on `:8443`.
- Neither in-tree path supports tailscale-cert or self-signed strategies, so the production path lives **outside** sa-plan.

### 1.3 Code redundancy and contradictions
- `start_server_with_acme` and `cmd_serve_tls` duplicate the rustls-acme state initialization (`AcmeConfig::new(...).cache(...).directory(...).state()`).
- `cmd_acme_renew` simply calls `cmd_acme_issue` (no force-renew flag).
- `cmd_acme_issue` writes `let mut deployed = false;` then immediately rebinds; first assignment is dead code.
- Two cache-dir defaults exist:
  - Path A: `--acme-cache-dir` (optional, no default)
  - Path B: `data/tls/acme-cache` (hard-coded fallback)
- ACME preflight tests port bind and LE reachability, but **does not** test tailscale-cert capability or self-signed generation — both are required strategies for our deployment.

---

## 2. Target unified design

### 2.1 Single `tls/` module tree
```
native/planning_daemon/src/tls/
  mod.rs                # public API: serve(), issue(), status(), renew(), preflight()
  config.rs             # TlsConfig, Strategy enum, defaults, env loaders
  validation.rs         # validate_domain(), allow_tailnet override
  acme.rs               # rustls-acme integration (TLS-ALPN-01 + HTTP-01)
  tailscale.rs          # `tailscale cert` strategy
  selfsigned.rs         # rcgen-based self-signed strategy (replaces python proxy)
  preflight.rs          # PreflightReport + checks for all strategies
  serve.rs              # axum_server bind + acceptor wiring + redirect router
```

Move `start_server_with_acme` out of `web/server.rs`. Keep `web/server.rs` as routing-only; expose `build_router()` (already done) for all serve paths.

### 2.2 Strategy enum
```rust
pub enum Strategy {
    None,                          // plain HTTP
    AcmeLetsencryptStaging,        // Let's Encrypt staging (LE-stg)
    AcmeLetsencryptProduction,     // Let's Encrypt production (LE-prod)
    TailscaleCert,                 // tailscale cert <domain>
    SelfSigned,                    // rcgen-generated self-signed
    PemFiles { cert: PathBuf, key: PathBuf }, // operator-supplied files
}
```

### 2.3 ACME challenge selector
```rust
pub enum AcmeChallenge { TlsAlpn01, Http01 }
```
- `TlsAlpn01`: single-port HTTPS bind, no separate :80
- `Http01`:    dual-port (challenge :80 + HTTPS :443), HTTP→HTTPS redirect router

### 2.4 Unified CLI surface
Replace **all** existing TLS subcommands with one `tls` group:

```
sa-plan tls preflight   [--strategy <s>] [--domain D] [--challenge http01|tls-alpn-01] [--cache-dir P] [--port N] [--check-privileged] [--check-directories] [--json]
sa-plan tls issue       --strategy <s>  [--domain D] [--email E] [--challenge ...] [--cache-dir P] [--challenge-port 80] [--tls-port 8443]
sa-plan tls renew       --strategy <s>  [--domain D] [--email E] [--force]
sa-plan tls status      --strategy <s>  [--domain D] [--cache-dir P] [--json]
sa-plan tls serve       --strategy <s>  [--domain D] [--email E] [--http-port 80] [--https-port 443] [--redirect-http]  [--auto-port-fallback] [--fallback-port 8443]
sa-plan serve --port 4200                 # plain HTTP (unchanged)
sa-plan serve --tls-strategy <s> ...      # one-shot equivalent of `tls serve` + start
```
Deprecate (alias-with-warning for one release):
- `acme-issue` → `tls issue --strategy acme-le-prod`
- `acme-status` → `tls status --strategy acme-le-prod`
- `acme-renew` → `tls renew --strategy acme-le-prod`
- `acme-preflight` → `tls preflight --strategy acme-le-prod`
- `serve-tls` → `tls serve --strategy acme-le-prod --challenge http01 --redirect-http`
- `serve --acme --acme-prod ...` → `serve --tls-strategy acme-le-prod ...`

### 2.5 Defaults
- Default cache: `data/tls/acme-cache`
- Default tailscale cert path: `data/tls/tailscale/<domain>.{crt,key}`
- Default self-signed path: `data/tls/selfsigned/<domain>.{crt,key}` (already exists for vm-1)
- Default fallback port: `8443`
- Default redirect: `--redirect-http=true` for `serve` strategies that bind :80

### 2.6 Env-driven config (systemd-friendly)
- `SA_PLAN_TLS_STRATEGY` (one of strategies above)
- `SA_PLAN_DOMAIN`
- `SA_PLAN_EMAIL`
- `SA_PLAN_TLS_CACHE_DIR`
- `SA_PLAN_HTTP_PORT`, `SA_PLAN_HTTPS_PORT`
- `SA_PLAN_TLS_REDIRECT_HTTP=1`
- `SA_PLAN_TLS_ALLOW_TAILNET=1` (override domain validation for testing)
- `SA_PLAN_TS_CERT_REFRESH_HOURS` (tailscale-cert refresh cadence)

---

## 3. Code merge map (file-by-file)

| # | Source | Action | Destination | Notes | RPN |
|---:|---|---|---|---|---:|
| 1 | `web/server.rs::start_server_with_acme` | **MOVE** | `tls/serve.rs::serve_acme()` | Keep TLS-ALPN-01 default; add HTTP-01 mode | 252 |
| 2 | `web/server.rs` rustls-acme imports | **REMOVE** | (after move) | `web/server.rs` becomes routing-only | 144 |
| 3 | `tls.rs::TlsConfig` | **SPLIT** | `tls/config.rs` | Add `Strategy` enum + env loaders | 200 |
| 4 | `tls.rs::validate_domain` | **EXTRACT** | `tls/validation.rs` | Add `--allow-tailnet` override + warning log | 168 |
| 5 | `tls.rs::cmd_acme_issue` | **REFACTOR** | `tls/acme.rs::issue()` | Use `TlsConfig` + `AcmeChallenge` selector | 200 |
| 6 | `tls.rs::cmd_serve_tls` | **REFACTOR** | `tls/serve.rs::serve()` | Reuse Path A's auto-fallback logic | 200 |
| 7 | `tls.rs::cmd_acme_renew` | **CONSOLIDATE** | `tls/acme.rs::renew(force: bool)` | Add force flag | 96 |
| 8 | `tls.rs::cmd_acme_status` | **REFACTOR** | `tls/acme.rs::status()` | Add `--json` output | 120 |
| 9 | `tls.rs::cmd_acme_preflight` | **EXTEND** | `tls/preflight.rs::run()` | Add tailscale-cert + self-signed checks | 144 |
| 10 | _new_ | **ADD** | `tls/tailscale.rs` | Shells out to `tailscale cert`; periodic refresh task | 200 |
| 11 | _new_ | **ADD** | `tls/selfsigned.rs` | Uses `rcgen` to generate cert + private key; replaces `/tmp/tls_proxy.py` | 168 |
| 12 | `Commands::Serve { acme, acme_prod, acme_auto_port, ... }` | **REPLACE** | `Commands::Serve { tls_strategy, ... }` | Strategy enum drives behavior | 162 |
| 13 | `Commands::AcmeIssue/Status/Renew/Preflight/ServeTls` | **REPLACE** | `Commands::Tls { #[command(subcommand)] op: TlsOp }` | Subcommand group | 162 |
| 14 | `deploy/systemd/sa-plan-tls.service` | **UPDATE** | `deploy/systemd/sa-plan-tls.service` | Use `--tls-strategy ${SA_PLAN_TLS_STRATEGY}` | 120 |
| 15 | `deploy/systemd/sa-plan-tls.env.example` | **UPDATE** | (same) | Add new env vars | 96 |
| 16 | `deploy/systemd/README-sa-plan-tls.md` | **UPDATE** | (same) | Strategy selector matrix + tailscale + self-signed how-to | 96 |
| 17 | `scripts/sa-plan-tls-setup.sh` | **UPDATE** | (same) | Strategy detection wizard | 96 |
| 18 | _new_ | **ADD** | `scripts/enable_https_443_via_tailscale.sh` (already on disk) | Move to `deploy/tailscale/` | 96 |
| 19 | `data/tls/selfsigned/{cert,key}.pem` | **PROMOTE** | tracked as canonical fixture | Git-track or doc-pin via `SC-DRIFT-001`-style note | 120 |
| 20 | `/tmp/tls_proxy.py` | **DEPRECATE** | (delete after `tls/selfsigned.rs` is live) | Provided by Rust serve path | 120 |

Total RPN of pending work = **2,832** (= sum). Pareto: 80% of risk reduction comes from items 1, 3, 5, 6, 9, 10, 11, 12, 13.

---

## 4. Strategy → behavior matrix

| Strategy | Cert source | Listens | Reachable from internet? | Browser trust | Use case |
|---|---|---|---|---|---|
| `acme-le-prod` | LE prod | :80 + :443 (or :8443) | required | ✅ | public domain |
| `acme-le-staging` | LE staging | :80 + :443 (or :8443) | required | ⚠️ (test CA) | dev/CI for public domain |
| `tailscale-cert` | tailscale (LE via TS) | :443 (or :8443) | not required | ✅ | `*.ts.net` (THIS HOST) |
| `self-signed` | rcgen | any port | not required | ❌ (warn) | LAN/dev fallback |
| `pem-files` | operator | any port | not required | depends | air-gapped or BYO PKI |
| `none` | — | :4200 | n/a | n/a | plain HTTP (current) |

**For `vm-1.tail55d152.ts.net` we use `tailscale-cert` (port 443) + `self-signed` (port 8443) as redundant paths.**

---

## 5. Multiverse worktree merge plan (per SC-FRAC-RRF + SC-DRIFT)

```bash
# Open isolated worktrees per concern (RPN-descending)
git worktree add ../mv-tls-core         -b multiverse/tls-core         main
git worktree add ../mv-tls-strategies   -b multiverse/tls-strategies   main
git worktree add ../mv-tls-cli          -b multiverse/tls-cli          main
git worktree add ../mv-tls-deploy       -b multiverse/tls-deploy       main
git worktree add ../mv-tls-deprecation  -b multiverse/tls-deprecation  main
```

### Stream gates (must all be green before ff-only into main)
- `multiverse/tls-core`: builds + unit tests for `tls/{config,validation,acme,serve,preflight}.rs`
- `multiverse/tls-strategies`: integration tests for `tailscale-cert` (mock `tailscale` binary), `self-signed` cert generation, PEM round-trip
- `multiverse/tls-cli`: clap parsing tests; help-text golden tests
- `multiverse/tls-deploy`: systemd unit lint, env file load test, `setcap` capability check
- `multiverse/tls-deprecation`: warning-shim tests for legacy commands

### Merge order (P0 → P3)
1. `multiverse/tls-core` (RPN ≈ 252)
2. `multiverse/tls-strategies` (RPN ≈ 220)
3. `multiverse/tls-cli` (RPN ≈ 162)
4. `multiverse/tls-deploy` (RPN ≈ 120)
5. `multiverse/tls-deprecation` (RPN ≈ 96)

### Mainline functional invariants during the merge
- `cargo build --release -p planning_daemon` green after each ff-only.
- `sa-plan --help` shows expected commands.
- `sa-plan serve --port 4200` (plain HTTP) still works at every step.
- `sa-plan tls preflight --strategy self-signed` returns `all_green=true`.
- `sa-plan tls serve --strategy self-signed --domain vm-1.tail55d152.ts.net --https-port 8443 --no-redirect` replaces the python proxy.
- `sa-plan tls serve --strategy tailscale-cert --domain vm-1.tail55d152.ts.net --https-port 443` works (when invoked via `sudo` or with `cap_net_bind_service`).

---

## 6. Acceptance criteria

| ID | Criterion | Test |
|---|---|---|
| AC-1 | Single `tls/` module tree owns all cert lifecycle | `rg -n "rustls-acme" src/web/` returns no matches |
| AC-2 | `Strategy` enum is the only switch | `rg "AcmeChallenge::|Strategy::" src/tls/` ≥ 5 |
| AC-3 | `validate_domain` runs on all strategies | unit test: ts.net rejected unless `--allow-tailnet` |
| AC-4 | `tls preflight` covers all 6 strategies | `sa-plan tls preflight --strategy <s> --json` returns `all_green:true` for `none|self-signed|tailscale-cert` on this host |
| AC-5 | `serve --acme` continues to work as alias | warning printed, behavior preserved for one release |
| AC-6 | `tls serve --strategy self-signed` replaces python proxy | systemd user unit can be retargeted, no functional regression |
| AC-7 | `tls serve --strategy tailscale-cert` issues a tailscale-trusted cert | curl shows valid cert chain |
| AC-8 | LE production unchanged for public domains | end-to-end smoke against a public test domain |
| AC-9 | systemd unit env-driven | `systemctl edit sa-plan-tls` accepts `Environment=SA_PLAN_TLS_STRATEGY=...` |
| AC-10 | All deprecated commands print 1-line warning | snapshot test of `--help` and command output |

---

## 7. Test plan additions

### 7.1 New unit tests (`tls/`)
- `validation::validate_domain` → 6 cases (good, bare, ts.net, ts.net+override, IP literal, empty)
- `config::Strategy::from_env` → 6 cases mapping env to enum
- `selfsigned::generate` → cert SANs include domain + 127.0.0.1 + IP
- `preflight::run` → matrix per strategy

### 7.2 Integration tests
- `tls::serve(Strategy::SelfSigned)` boots, serves `/api/v1/status`, shuts down via handle
- `tls::issue(Strategy::AcmeLetsencryptStaging, "test.example.com")` against pebble (local LE) if available, else feature-gated
- `tls::issue(Strategy::TailscaleCert, "vm-1.tail55d152.ts.net")` mocked via PATH-injected `tailscale` shim

### 7.3 Public interface sweep
- Re-run `scripts/public_interface_test_suite.sh` against all three URLs:
  - `http://vm-1.tail55d152.ts.net:4200`
  - `https://vm-1.tail55d152.ts.net:8443` (after self-signed serve)
  - `https://vm-1.tail55d152.ts.net/c3i` (after tailscale-cert serve)

---

## 8. Cleanup / deprecation list

| Item | Action | Risk |
|---|---|---|
| `serve --acme --acme-prod --acme-auto-port` flags | alias to `--tls-strategy` for one release | LOW (compat shim) |
| `cmd_acme_renew` direct re-call to `cmd_acme_issue` | replace with `acme::renew(force=false)` | LOW |
| Dead `let mut deployed = false;` | remove | LOW |
| Hard-coded `/tmp/tls_proxy.py` | replace with `tls/selfsigned.rs` + systemd unit | MEDIUM |
| `data/tls/selfsigned/*.pem` (untracked) | move to `data/tls/selfsigned/<domain>/{cert,key}.pem`; add to `.gitignore` (private key) | HIGH (key handling) |
| `deploy/systemd/sa-plan-tls.service` | regenerate via setup script after merge | LOW |
| Mirror copies of ACME journals | already deduped via R2 (mirror notices) | LOW |

---

## 9. Effort + risk table

| Phase | Files touched | LOC delta (est.) | Effort | Risk |
|---|---:|---:|---|---|
| 1. tls-core (move + refactor) | 6 | +250 / -180 | M | LOW (no behavior change) |
| 2. tls-strategies (tailscale + self-signed) | 4 | +320 / -0 | M | MEDIUM (new external `tailscale` invocation) |
| 3. tls-cli (Strategy + clap subgroup) | 2 | +120 / -90 | M | MEDIUM (CLI break w/o aliases) |
| 4. tls-deploy (systemd + env + setup) | 4 | +60 / -30 | S | LOW |
| 5. tls-deprecation (alias warnings) | 1 | +40 / -0 | S | LOW |
| **Total** | **17** | **+790 / -300** | **M+** | **MEDIUM** |

---

## 10. STAMP additions (SC-TLS-MRG-*)

| ID | Constraint | Severity |
|---|---|---|
| SC-TLS-MRG-001 | All cert-lifecycle code MUST live under `src/tls/` | CRITICAL |
| SC-TLS-MRG-002 | Strategy MUST be selected via `Strategy` enum (no boolean ACME flag) | HIGH |
| SC-TLS-MRG-003 | `validate_domain` MUST run before any LE call; `.ts.net` rejected unless `--allow-tailnet` | CRITICAL |
| SC-TLS-MRG-004 | `tls preflight` MUST support every shipped strategy | HIGH |
| SC-TLS-MRG-005 | Self-signed key files MUST never be committed | CRITICAL |
| SC-TLS-MRG-006 | systemd unit MUST be env-driven (no hard-coded domain) | HIGH |
| SC-TLS-MRG-007 | Legacy ACME flags/commands MUST emit deprecation warning for one release | MEDIUM |
| SC-TLS-MRG-008 | `serve --port 4200` plain HTTP MUST remain available as fallback | CRITICAL |

---

## 11. Immediate next steps (this session)

1. Open the 5 multiverse worktrees listed in §5.
2. In `mv-tls-core`: perform items 1–9 from §3 (move + extract + consolidate; no functional regression).
3. In `mv-tls-strategies`: implement `tailscale.rs` + `selfsigned.rs`.
4. In `mv-tls-cli`: introduce `Strategy` enum and `Tls` subcommand; alias old commands.
5. In `mv-tls-deploy`: regenerate systemd unit + env example + README.
6. Run AC-1..AC-10 in respective gate.
7. ff-only merge in §5 order.
8. Re-run `public_interface_test_suite.sh` across the three URL families.
9. Replace user-systemd `c3i-tls-proxy.service` with `sa-plan tls serve --strategy self-signed ...`.
10. Update `.claude/.gemini/rules/fractal-criticality-ruliology-fmea.md` to add SC-TLS-MRG-001..008.

After this, **sa-plan owns the full TLS lifecycle** for every host class, with one strategy selector and one CLI surface.
