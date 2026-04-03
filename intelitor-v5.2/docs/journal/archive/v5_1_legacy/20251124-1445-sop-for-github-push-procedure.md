# Journal Entry: Standard Operating Procedure for a Safety-Compliant GitHub Push
- **Date**: 2025-11-24 14:45 CEST
- **Author**: Gemini Agent
- **Task**: 1.0 - Document the comprehensive, safety-compliant protocol for pushing code changes to the remote GitHub repository.
- **Status**: Completed

## 1.0.0.0.0: Objective
This document serves as the Standard Operating Procedure (SOP) for executing a `git push` within the Indrajaal project. Adherence to this protocol is mandatory to ensure all changes pushed to the remote repository are verified, compliant with project standards, and maintain system stability, in accordance with the SOPv5.11-Lite framework.

## 2.0.0.0.0: Pre-Push Analysis (Prerequisites)
Before initiating the push protocol, a developer or agent must assess the current state of the local repository.

### 2.1.0.0.0: Initial State Assessment
- **2.1.1.0.0: Action**: Execute `git status` to get a comprehensive overview of the repository.
- **2.1.2.0.0: Analysis**: Review the output to identify:
    - **2.1.2.1.0**: The current active branch.
    - **2.1.2.2.0**: The presence of any modified but uncommitted files.
    - **2.1.2.3.0**: The presence of any staged (added) files.
    - **2.1.2.4.0**: The presence of any untracked files.

### 2.2.0.0.0: Branch Compliance Verification
- **2.2.1.0.0: Action**: Confirm the current active branch is NOT `main`.
- **2.2.2.0.0: Rationale**: This step directly enforces **`R-GIT-001: FORBID(COMMIT to "main")`** from the `CLAUDE-SHORT.md` specification, protecting the primary branch from direct changes.
- **2.2.3.0.0: On-Failure Action**: If on `main`, immediately create and check out a new feature branch (`git checkout -b feat/my-descriptive-branch-name`) before proceeding.

## 3.0.0.0.0: Mandatory Pre-Push Protocol
The following three phases MUST be executed in sequence to ensure a successful and compliant push.

### 3.1.0.0.0: Phase 1: Local Repository Preparation
This phase ensures that all local changes are accounted for and committed correctly.

- **3.1.1.0.0: Stage Relevant Changes**
    - **3.1.1.1.0: Action**: Stage all intentionally modified and newly created files that are part of a single, logical change.
    - **3.1.1.2.0: Command**: `git add <file_path_1> <file_path_2> ...`
    - **3.1.1.3.0: Rationale**: This upholds the principle of atomic commits (**`R-GIT-002`**) by ensuring only related files are grouped together.
- **3.1.2.0.0: Commit Staged Changes**
    - **3.1.2.1.0: Action**: Commit the staged files with a message that adheres to the Conventional Commits specification.
    - **3.1.2.2.0: Command**: `git commit -m "type(scope): descriptive message"` (e.g., `git commit -m "docs(journal): add SOP for git push procedure"`)
    - **3.1.2.3.0: Rationale**: This creates a clear, machine-readable, and auditable history, compliant with **`R-GIT-002`**.
- **3.1.3.0.0: Workspace Hygiene**
    - **3.1.3.1.0: Action**: Review all remaining untracked files identified in step 2.1.2.4.0. If they are temporary artifacts or logs, they should be removed.
    - **3.1.3.2.0: Command**: `git clean -f <path_to_temp_file>` (Use with caution).
    - **3.1.3.3.0: Rationale**: Prevents accidental inclusion of temporary or sensitive files in version control.

### 3.2.0.0.0: Phase 2: Synchronization and Validation
This phase ensures the local changes are compatible with the remote state and meet all quality gates.

- **3.2.1.0.0: Remote Synchronization**
    - **3.2.1.1.0: Action**: Fetch and rebase the local branch on top of the latest changes from the remote branch.
    - **3.2.1.2.0: Command**: `git pull --rebase origin <branch-name>`
    - **3.2.1.3.0: Rationale**: This is the most critical step for preventing merge conflicts and ensuring a clean, linear project history.
- **3.2.2.0.0: Local Quality Gate Execution**
    - **3.2.2.1.0: Action**: Run the full suite of local quality checks as defined by the project.
    - **3.2.2.2.0: Command**: `mix quality.full`
    - **3.2.2.3.0: Rationale**: Enforces **`R-QUAL-001`** by validating code format, style, static analysis, security, and running all tests *before* the code leaves the local machine. This prevents broken commits from entering the remote repository and failing the CI pipeline.
- **3.2.3.0.0: Timestamp Compliance Verification**
    - **3.2.3.1.0: Action**: Run the mandatory timestamp audit to ensure all file timestamps are current.
    - **3.2.3.2.0: Command**: `elixir scripts/maintenance/simple_timestamp_validator.exs --audit`
    - **3.2.3.3.0: Rationale**: Enforces **`R-TIME-002`**, a critical rule for maintaining auditable and consistent documentation.

### 3.3.0.0.0: Phase 3: Remote Push and Review
This phase completes the process by uploading the code and initiating the formal review.

- **3.3.1.0.0: Executing the Push**
    - **3.3.1.1.0: Action**: Push the validated, committed, and synchronized local branch to the remote repository.
    - **3.3.1.2.0: Command**: `git push origin <branch-name>`
- **3.3.2.0.0: Creating a Pull Request**
    - **3.3.2.1.0: Action**: Open a pull request on the GitHub interface to merge the feature branch into the main branch.
    - **3.3.2.2.0: Command**: `gh pr create --web` or using the GitHub web UI.
    - **3.3.2.3.0: Rationale**: This fulfills **`R-GIT-003`** by ensuring all changes undergo a formal review process before integration.

## 4.0.0.0.0: Safety Compliance Rationale Summary
This protocol is not arbitrary; each phase directly maps to and enforces the safety and quality constraints defined in `CLAUDE-SHORT.md` v5.0.

- **Phase 1** enforces atomic and well-documented changes (`R-GIT-002`).
- **Phase 2** acts as the primary safety gate, preventing unsynchronized, low-quality, or non-compliant code from contaminating the remote repository (`R-QUAL-001`, `R-TIME-002`).
- **Phase 3** ensures that even after passing local checks, all code is subject to formal peer review and CI validation before being merged into the main branch (`R-GIT-001`, `R-GIT-003`).

## 5.0.0.0.0: Conclusion
Following this Standard Operating Procedure is mandatory for all contributions. It guarantees that the project's Git history remains clean, coherent, and auditable, and that every change pushed to the remote has been rigorously validated against the system's core safety and quality principles.
