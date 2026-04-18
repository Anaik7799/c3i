# Maximum Parallelization (SC-PARALLEL-CLAUDE)

## MANDATE
**Claude MUST maximize parallelism in EVERY operation.** Serial execution when parallel is possible = Muda (waste).

## Rules
| ID | Rule | Severity |
|----|------|----------|
| SC-PARALLEL-001 | Independent file reads MUST be parallel (max 10) | HIGH |
| SC-PARALLEL-002 | Independent agent tasks MUST launch in single message | HIGH |
| SC-PARALLEL-003 | Independent Bash commands MUST run in parallel tool calls | HIGH |
| SC-PARALLEL-004 | Background agents MUST use run_in_background: true | MEDIUM |
| SC-PARALLEL-005 | Research + implementation MUST NOT be sequential if separable | HIGH |

## Patterns
```
# WRONG: Sequential when parallel possible
agent1 = launch(research_task_1)
wait(agent1)
agent2 = launch(research_task_2)
wait(agent2)

# RIGHT: Parallel launch in single message
agent1 = launch(research_task_1, background=true)
agent2 = launch(research_task_2, background=true)
# Both run simultaneously
```

## Fast OODA = Parallel OODA
Observe + Orient can run in parallel (ZK search || system health check).
Decide is sequential (needs observe + orient results).
Act can be parallel (multiple file edits in one message).
Verify is automatic (hooks fire in parallel after each edit).
