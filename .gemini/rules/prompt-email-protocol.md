# Prompt Email Protocol (SC-NOTIFY-005)

## MANDATE
When operator says "send prompts by email" or "email the prompts", the agent MUST:

1. Collect ALL prompts used in the current session
2. For each prompt: document its function, when to use it, and improvements
3. Send via SMTP (`sa-plan-daemon send-email`) to Abhijit.Naik@bountytek.com
4. After sending, trigger the prompt-analysis agent to suggest optimizations
5. Log the prompts to a journal entry

## STAMP
| ID | Constraint | Severity |
|----|------------|----------|
| SC-NOTIFY-005 | Prompt email MUST include context, function, and improvements | HIGH |
| SC-NOTIFY-006 | Prompt analysis agent MUST be triggered after email | HIGH |

## Format
Each prompt entry must include:
- The exact prompt text
- FUNCTION: What it triggers
- WHEN TO USE: Operational context
- IMPROVEMENT: How to make it more effective
- CATEGORY: design / implementation / testing / operations / meta
