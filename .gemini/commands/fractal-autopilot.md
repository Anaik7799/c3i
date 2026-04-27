# /fractal-autopilot
Run full autonomous feature-evolution loop for a task.

## Usage
`/fractal-autopilot <task-id>`

## Steps
1. `bash sub-projects/c3i/scripts/fractal_feature_evolution_suite.sh <task-id>`
2. `bash sub-projects/c3i/scripts/recursive_feature_convergence.sh <task-id> 3`
3. `cd sub-projects/c3i && ./scripts/update_task_link_registry.sh <task-id>`
4. Attach and email journal+analysis+deck via `./sa-plan send-email`.
5. Mark task complete in Smriti.
