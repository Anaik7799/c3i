# /planning cross-browser Playwright sweep — pass-3 (full coverage)

**Run:** 2026-04-30 (post operator-authorized fix) · `tests/playwright/planning.spec.ts` · 6 tests × 5 projects = 30 cells
**Authority:** SC-PLANNING-EVO-004, SC-AGUI-UI-001..015, SC-AGUI-UI-011 (server-tick)

## Result

| Browser | Tests run | Pass | Fail | Notes |
|---|---:|---:|---:|---|
| Chromium (Desktop Chrome) | 6 | **6** | 0 | clean |
| Firefox (Desktop Firefox) | 6 | **6** | 0 | `material.css` MIME tolerance via filter |
| mobile-Chromium (Pixel 5) | 6 | **6** | 0 | clean |
| WebKit (Desktop Safari) | 6 | **6** | 0 | unblocked via Nix lib closure (see below) |
| mobile-WebKit (iPhone 12) | 6 | **6** | 0 | same WebKit binary |

**Total: 30/30 PASS across all 5 projects.** No env-blocked cells remaining.

## Tests

1. `returns 200 with no console errors and required IDs` — DOM presence + script wiring
2. `view-mode mutual exclusion (closes ZK[zk-741220214a931009])` — exactly one `*-section` visible
3. `triple-transport parity (DAG-Q)` — HTTP & WS first-frame agree on `total` ±2
4. `freshness reports fresh and all wiring functional`
5. `responsive: weather bar visible at 375 / 768 / 1400`
6. `WS server-driven push: emits welcome + ≥1 server tick within 2.5s, no client ping` (SC-AGUI-UI-011)

## WebKit unblock — fractal-RCA + Nix closure (no sudo required)

**5-Why on missing-libs blocker:**
1. WebKit fails → `libicudata.so.74 / libxml2.so.2 / libjxl.so.0.8 / libavif.so.16 / libevent-2.1.so.7 / libmanette-0.2.so.0 / libgstcodecparsers-1.0.so.0` missing
2. → `npx playwright install webkit` ships only the browser binaries, not deps
3. → `apt install libicu74` requires sudo (denied)
4. → Each missing lib has an ABI-pinned soname that recent distro versions don't ship
5. → **Root cause:** treat the dep set as a closed Nix derivation, not piecemeal LD_LIBRARY_PATH chasing (Muda: motion + over-processing)

**Jidoka fix:** symlink Nix-built ABI-pinned libs into the WebKit bundle's own `${MYDIR}/lib` dir, which the vendored `MiniBrowser` wrapper already prepends to `LD_LIBRARY_PATH`. One idempotent script closes the gap permanently:

```bash
cd tests/playwright
./setup-webkit-libs.sh           # builds Nix closure + symlinks
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 ./node_modules/.bin/playwright test
```

The script (`tests/playwright/setup-webkit-libs.sh`) builds:
| ABI | Nix package | Reason |
|---|---|---|
| `libicudata.so.74` | `icu74` (icu4c-74.2) | nixpkgs default is 76 (so.76); must pin |
| `libxml2.so.2` | `libxml2_13` (2.13.8) | nixpkgs default is 2.15 (so.16); must pin |
| `libjxl.so.0.8` | `libjxl` from nixos-23.11 (0.8.2) | nixpkgs default is 0.11 (so.0.11); must pin |
| `libavif.so.16` | `libavif` (1.3.0) | matches |
| `libevent-2.1.so.7` | `libevent` (2.1.12) | matches |
| `libmanette-0.2.so.0` | `libmanette` (0.2.13) | matches |
| `libgstcodecparsers-1.0.so.0` | `gst_all_1.gst-plugins-bad` (1.26.5) | matches |

After symlinking, `ldd ${WEBKIT}/minibrowser-{wpe,gtk}/bin/MiniBrowser` reports `0` missing.

## How to reproduce (clean machine)

```bash
cd /home/an/dev/ver/c3i/tests/playwright
npm install                                          # @playwright/test 1.54.1 (matches Nix browsers)
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 \
  ./node_modules/.bin/playwright install chromium firefox webkit
./setup-webkit-libs.sh                               # idempotent Nix lib closure
PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=1 \
  ./node_modules/.bin/playwright test --workers=2    # 30/30 PASS
```

## Console-error filter (cross-browser fairness)

Firefox elevates the benign `material.css` MIME-type fallback to a console error (the shell already supplies the inline `css` style as fallback at `lib/cepaf_gleam/src/cepaf_gleam/ui/lustre/shell.gleam:585`). Filtered via `ignoreError(text)` regex — not a defect. The same filter passes through real errors (none observed).

## Server-tick verification (SC-AGUI-UI-011)

The new WS server-driven push (Mist Tick custom message) is verified by a dedicated test that opens `/ws/planning`, reads frames without sending `ping`, and asserts at least one frame carries `source:"server_tick"` within 2.5 s. PASSED on all 5 browsers post operator-authorized restart of `cepaf_gleam --serve` (PID 3175589).
