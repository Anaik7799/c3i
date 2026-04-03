---
description: "[DEPRECATED → /sil6] IEC 61508 SIL-6 validation — use /sil6 instead"
allowed-tools: Read
argument-hint: [file-path|module-name|system|subsystem]
---

# /sil4 → /sil6 (RENAMED)

**This skill has been renamed to `/sil6`** to accurately reflect the SIL-6 Biomorphic Extended safety level.

The `/sil4` name was a legacy artifact from the IEC 61508 SIL-4 baseline. The system has evolved to SIL-6 Biomorphic Extended with:
- 30 safety modules (11 F#, 19 Elixir)
- 641+ STAMP constraints across 55+ families
- 385+ safety tests across 16 test files
- 12 MCP tools for live verification
- Full 6-phase SDLC coverage (Specification → Evolution)

## Use `/sil6` instead:
```
/sil6 system                              # Full system SIL-6 assessment
/sil6 lib/indrajaal/safety/sentinel.ex     # Module-level validation
/sil6 Indrajaal.Safety.Guardian            # Module by name
/sil6 tmr                                  # TMR 2oo3 voting subsystem
/sil6 apoptosis                            # 6-phase apoptosis protocol
/sil6 constitutional                       # Ψ₀-Ψ₅ invariants
/sil6 fpps                                 # FPPS 5-method consensus
/sil6 boot                                 # 5-stage mesh boot
/sil6 immune                               # Digital immune system
```

## Migration History
- **v1.0** (2026-01): Original SIL-4 compliance checker (IEC 61508 baseline)
- **v2.0** (2026-03-22): Upgraded to comprehensive SIL-6 with 30 modules, 641+ constraints
- **v3.0** (2026-03-22): Renamed to `/sil6` — this file preserved as redirect

## Related
- `/sil6` — The active SIL-6 validation skill (full content)
- `.claude/agents/sil6-validator.md` — SIL-6 validator agent definition
