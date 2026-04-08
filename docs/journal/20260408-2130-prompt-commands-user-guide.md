# Journal Entry: Prompt Commands User Guide Reification - 2026-04-08 21:30 CEST

**Status**: USER GUIDE REIFICATION
**Persona**: Cybernetic Architect
**Focus**: Expanding the documentation for system-level prompt commands (`/evolve-sil6` and `/allium`) with detailed user journeys and scenarios.

## 1. Overview
Following the synchronization of the prompt commands with the 15-day system state, it became necessary to codify *how* a human operator or a delegated AI should interact with these macros. I have generated a comprehensive User Guide that defines the operational procedures for these commands.

## 2. Reification Artifacts

### A. The User Guide (`docs/user_guides/PROMPT_COMMANDS_USER_GUIDE.md`)
I authored a detailed operational manual covering:
- **The `/evolve-sil6` Command**: Mapped out user journeys for adding new subsystems (Drone Orchestrator), refactoring for High Availability, and integrating OpenClaw tools (Slack Gateway).
- **The `/allium` Suite**: Detailed scenarios for "Tending" (designing new components), "Weeding" (auditing for architectural drift), and "Propagating" (generating test files from mathematical invariants).
- **Best Practices**: Established rules for providing intent ("Why"), trusting the formal math, and monitoring the Rust Motor Strip debug hooks.

### B. Command Synchronization
- **Artifacts**: `.claude/commands/evolve.md` and `.claude/commands/allium.md`
- **Change**: Injected direct references to the new User Guide, ensuring that any AI reading its own instructions can immediately access the concrete examples of how to apply them.

## 3. Operational Impact
This reification closes the gap between "abstract mandate" and "concrete execution." By providing explicit scenarios (e.g., how the system should handle an `exec-approvals` scenario vs a `secrets` scenario under the `/evolve-sil6` command), we drastically reduce the cognitive load on the AI agent during future sprints and prevent deviation from the SIL-6 architecture.

## 4. Conclusion
The prompt commands are now fully synchronized, documented, and supported by concrete user journeys. I am committing this User Guide to the master repository.
