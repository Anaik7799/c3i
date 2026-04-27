# Fractal Autopilot Mandatory Rule (SC-FRACTAL-AUTO-001)

## Mandate
For EVERY new feature implementation, the system MUST automatically execute:
1. `scripts/fractal_feature_evolution_suite.sh <task-id>`
2. `scripts/recursive_feature_convergence.sh <task-id> 3`
3. `scripts/update_task_link_registry.sh <task-id>`
4. `sa-plan ingest-docs`
5. `sa-plan send-email` with journal + analysis + deck attachments

## Required Outputs
- Task journal (.md) with Tailscale URL on first line
- Analysis HTML + summary slide deck HTML
- Screenshots + journey video + visual checklist JSON
- Link registry JSON (task-{id}-links.json)

## Pi Symbiosis Gate
Must include Pi build and `gleam test -- --module pi_integration` in the regression suite.
