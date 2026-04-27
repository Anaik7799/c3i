# https://vm-1.tail55d152.ts.net:8443/task-id/1a92520c

# Fractal-Criticality Integration Update (Rules/Commands/Agents/Skills/Hooks/Flows)

## Scope
System-wide policy update to enforce:
- all fractal layers (L0-L7)
- all fractal components
- RETE-UL + ruliological evidence
- STAMP + FMEA/FEMA controls
- criticality-first execution order (P0→P3)

## Updated Artifacts

### Rules
- Added: `.claude/rules/fractal-criticality-ruliology-fmea.md`
- Mirrored: `.gemini/rules/fractal-criticality-ruliology-fmea.md`
- Updated: `.claude/.gemini/rules/feature-evolution-protocol.md`
- Updated: `.claude/.gemini/rules/pi-symbiosis-automation.md`

### Commands
- Updated: `.claude/.gemini/commands/feature-evolution.md`
- Updated: `.claude/.gemini/commands/pi-symbiosis-evolve.md`

### Agents
- Updated: `.claude/.gemini/agents/feature-evolution-agent.md`
- Updated: `.claude/.gemini/agents/pi-evolution-verifier.md`

### Skills
- Updated: `.claude/.gemini/skills/fractal-autopilot/SKILL.md`

### Flows
- Added flow script: `sub-projects/c3i/scripts/generate_fractal_criticality_matrix.sh`
- Integrated into suite flow: `sub-projects/c3i/scripts/fractal_feature_evolution_suite.sh`

### Hooks
- Governance behavior is now policy-bound through updated rule/command/agent/skill contracts.
- Existing runtime hooks remain structurally intact and are now semantically aligned with the new matrix requirement.

## Compliance Notes
- Parity preserved between `.claude` and `.gemini` for changed artifacts.
- Task/page URL header rule preserved in generated analysis artifacts.
- Execution model remains fully aligned with sa-plan service boundaries.

## Next Recommended Action
Run for active task-id:
```bash
cd /home/an/dev/ver/c3i/sub-projects/c3i
./scripts/fractal_feature_evolution_suite.sh 1a92520c
```
This now auto-generates matrix artifacts before build/test phases.
