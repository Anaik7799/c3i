# Rust-Only Tooling Mandate (SC-RUST-TOOL)
# केवल रस्ट — Only Rust (no shell scripts)

## Supreme Mandate (सर्वोच्च आदेश)
**ALL operational tooling MUST be Rust. Shell scripts are PROHIBITED.**

## STAMP Constraints
| ID | Constraint | Severity |
|----|------------|----------|
| SC-RUST-TOOL-001 | New operational tools MUST be Rust subcommands of sa-plan-daemon | CRITICAL |
| SC-RUST-TOOL-002 | Shell scripts (.sh) for operations are FORBIDDEN | CRITICAL |
| SC-RUST-TOOL-003 | Existing shell scripts MUST be migrated to Rust | HIGH |
| SC-RUST-TOOL-004 | Only exceptions: gleam build/test/run (Gleam toolchain) | MEDIUM |

## Rationale (कारण)
- Type safety: Rust catches errors at compile time
- Integration: sa-plan-daemon is the single binary authority
- Performance: Rust is faster than bash
- SC-ARCH-SPLIT: monitoring + ops = Rust only
- Muda: shell scripts are fragile waste

## Required Rust Subcommands
| Command | Replaces | Status |
|---------|----------|--------|
| `sa-plan-daemon fitness` | scripts/fitness-check.sh | PENDING |
| `sa-plan-daemon evolve-page` | scripts/evolve-page.sh | PENDING |
| `sa-plan-daemon hot-reload` | scripts/hot-reload.sh | PENDING |
