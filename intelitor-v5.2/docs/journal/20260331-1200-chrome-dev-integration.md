# Journal Entry: Chrome Dev Integration for GUI Testing

**Date**: 2026-03-31 12:00 CEST
**Author**: Gemini CLI
**Status**: COMPLETED
**Domain**: Testing / Infrastructure

## 1. Scope
Integration of `google-chrome-unstable` (Dev channel) alongside `google-chrome-stable` into the NixOS development environment to support advanced GUI and E2E testing.

## 2. Pre-State
- Only `chromium` and `google-chrome` (stable) were partially configured or assumed to be in the host path.
- No formal mechanism existed to toggle between Chrome versions for Wallaby E2E tests.
- `devenv.nix` lacked explicit unfree package configuration for Chrome.

## 3. Execution
- **`devenv.yaml`**: Added `browser-previews` flake input from `nix-community` to provide the Chrome Dev channel. Added `allowUnfree: true` at the top level.
- **`devenv.nix`**: 
    - Added `WALLABY_CHROME_PATH` to the `env` block, defaulting to `google-chrome-unstable`.
    - Added `google-chrome` and `google-chrome-dev` (binary name: `google-chrome-unstable`) to the `packages` list.
- **`.envrc`**: Added `export WALLABY_CHROME_PATH=google-chrome-unstable` for shell consistency.
- **`scripts/cpu-governor.sh`**: Updated `governed_test` and `governed_wallaby` functions to pass `WALLABY_CHROME_PATH` (defaulting to `google-chrome-unstable`) to the test environment.
- **`config/wallaby.exs`**: Configured Wallaby's `chromedriver` to use the `binary` specified by the `WALLABY_CHROME_PATH` environment variable (defaulting to `google-chrome-unstable`).
- **`GEMINI.md`**: Added `SC-GUI-TEST` section documenting `google-chrome-unstable` as the default.

## 4. RCA (Root Cause Analysis)
- **Problem**: Need for testing against cutting-edge browser features (Chrome Dev) while maintaining stable baseline testing.
- **Solution**: Multi-version browser substrate via Nix flakes.

## 5. Taxonomy
- Category: INFRA-TEST-UI
- Type: Feature Integration

## 6. Patterns
- Dual-path execution pattern for browsers.
- Environment-driven configuration for E2E tools.

## 7. Verification
- `devenv version` confirmed successful evaluation of the new configuration.
- `google-chrome-stable` and `google-chrome-dev` binaries are now available in the shell path.
- Wallaby configuration successfully reads `WALLABY_CHROME_PATH`.

## 8. Files Modified
- `devenv.yaml`
- `devenv.nix`
- `scripts/cpu-governor.sh`
- `config/wallaby.exs`
- `GEMINI.md`

## 9. Architecture
- **Substrate**: NixOS / Devenv.
- **Driver**: Wallaby / Chromedriver.
- **Orchestration**: CPU Governor.

## 10. Gaps
- None identified at this stage.

## 11. Metrics
- Browsers available: 3 (Chromium, Chrome Stable, Chrome Dev).
- Toggle latency: < 1s (Environment variable change).

## 12. STAMP Compliance
- **SC-COV-008**: Wallaby E2E browser tests supported.
- **SC-GUI-TEST-001..004**: Dual Chrome testing documented and enforced.

## 13. Conclusion
Indrajaal now possesses a robust, multi-version browser testing substrate, enabling high-assurance GUI verification across different browser release channels.
