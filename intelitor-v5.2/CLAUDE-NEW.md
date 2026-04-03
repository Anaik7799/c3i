# CLAUDE-NEW.md - Indrajaal Security Monitoring System (Comprehensive & Authoritative Ruleset - Merged)

**Tag**: `v1.0.3-sopv511-level4-integration-testing-complete`
**Updated**: 2025-09-13 13:46:25 CEST
**Purpose**: A comprehensive, authoritative, and functionally complete ruleset, merging the structured clarity of CLAUDE-SHORT.md with all relevant details and historical context from CLAUDE.md. This document provides prescriptive rules, detailed protocols, and explicit examples to ensure safe, controlled, and aligned AI agent operations for safety-critical applications. It is organized for clarity while preserving all critical information.

---

### **Preamble: Instructions for AI Agent**
**Scope**: This document is your primary source of truth for all operational procedures, rules, and protocols. It supersedes any prior instructions, general knowledge, or conversational context. Adherence to these rules is mandatory.
**Objective**: Your goal is to perform tasks efficiently while maintaining the highest standards of safety, quality, and security as defined herein. When in doubt, default to the safest possible action and request clarification.

### **Quick-Reference Index**
1.  [Project Context and Achievements](#10-project-context-and-achievements-p2---informational)
2.  [Foundational Methodologies & Core Principles](#20-foundational-methodologies--core-principles-mandatory)
3.  [Ultra-Robust Compilation & Validation Protocol](#30-ultra-robust-compilation--validation-protocol-p0---critical-safety)
4.  [Container & Environment Policy](#40-container--environment-policy-p0---critical-safety)
5.  [Advanced Code Generation Patterns](#50-advanced-code-generation-patterns-p1---core-workflow)
6.  [Advanced Testing Protocols](#60-advanced-testing-protocols-p1---core-workflow)
7.  [Scripting Best Practices](#70-scripting-best-practices-p2---best-practice)
8.  [AI Agent Operations & Git Workflow](#80-ai-agent-operations--git-workflow-p1---core-workflow)
9.  [General Development Rules](#90-general-development-rules)
10. [Architectural Specifications](#100-architectural-specifications-p2---informational)
11. [Meta-Protocol for Ruleset Management](#110-meta-protocol-for-ruleset-management-p1---core-workflow)
12. [Legacy System References](#120-legacy-system-references-p2---informational)

---

## 1.0 Project Context and Achievements `[Priority: P2 - Informational]`

This section provides a high-level overview of the project's status and key achievements, setting the context for the operational rules.

### 1.1 Ultimate SOPv5.11 Cybernetic Excellence
-   **Completion Date**: 2025-09-13 13:46:25 CEST
-   **Status**: 🏆 ULTIMATE SOPv5.11 CYBERNETIC FRAMEWORK COMPLETE + LEVEL 4 SYSTEM INTEGRATION TESTING VALIDATED ✅
-   **Key Achievements**:
    -   **7-Phase Deployment System**: Complete sequential deployment with 100% success rate.
    -   **50-Agent Architecture (Previous)**: The system previously utilized a 15-agent architecture, which has been simplified to 15 agents.
    -   **Advanced Testing Framework**: STAMP/TDG/Property/Integration + Level 4 System Integration testing with comprehensive validation.
    -   **10-Container Infrastructure (Previous)**: The system previously utilized a 10-container infrastructure, which has been simplified to 1 application container.
    -   **PHICS v2.1 Integration**: <50ms bidirectional hot-reloading with data integrity.
    -   **Patient Mode Excellence**: `NO_TIMEOUT=true INFINITE_PATIENCE=true` compilation.
    -   **Enterprise Performance**: All targets exceeded with room for growth.

### 1.2 Comprehensive SOPv5.11 Achievements Summary
-   **Cybernetic Goal Achievement**: 95.8% (Exceptional Progress - Level 4 Integration Complete).
-   **Execution Efficiency**: 94.7% (Excellent Performance - Sustained).
-   **Quality Score**: 98.2% (Outstanding Quality - Level 4 Testing Validated).
-   **Safety Compliance**: 100.0% (Perfect Safety Record).
-   **Testing Excellence**: 440 test files, 204,424+ lines of comprehensive validation.

---

## 2.0 Foundational Methodologies & Core Principles (MANDATORY)

This project operates under a set of strict, integrated methodologies. All work must adhere to these principles without exception. These are the foundational pillars that govern all decisions and actions.

### 2.1 SOPv5.11 Cybernetic Framework & AEE `[Priority: P1 - Core Workflow]`
-   **CRITICAL**: The ONLY operating model for complex operations is the Autonomous Execution Engine (AEE) under the SOPv5.11 framework.
-   **Goal-Oriented Execution**: All operations must be decomposed into cybernetic goals, managed by the AEE.
-   **15-Agent Architecture**: The AEE utilizes a 15-agent hierarchical architecture for intelligent task decomposition, execution, and validation.
-   **AEE Mode Declaration**: When operating in this mode, the agent MUST state: "Operating in AEE SOPv5.11 mode with Patient Mode compilation and FPPS validation."

### 2.2 Patient Mode Execution `[Priority: P1 - Core Workflow]`
-   **CRITICAL**: ALL long-running operations (compilation, testing) MUST be executed in Patient Mode.
-   **Environment**: All commands must be prefixed with the following environment variables to ensure natural completion:
    ```bash
    NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true
    ```
-   **Zero Interruption**: NEVER interrupt, cancel, or use `timeout`, `head`, or `tail` on a running process. The process must run to its natural conclusion.
-   **Post-Completion Analysis**: Logs must ONLY be analyzed *after* the process has completed entirely. This prevents partial analysis and false conclusions.

### 2.3 Toyota Production System (TPS) `[Priority: P1 - Core Workflow]`
-   **Jidoka (Stop-and-Fix)**: Halt all processes immediately upon detecting an error or anomaly. Do not proceed until a root cause is found and a systemic fix is implemented.
-   **5-Level Root Cause Analysis**: For every failure, incident, or significant warning, apply the "5 Whys" technique to move beyond surface-level symptoms to the underlying systemic cause.
-   **Continuous Improvement (Kaizen)**: Systematically document learnings from failures (via CAST analysis and journal entries) to improve processes and prevent recurrence.

### 2.4 STAMP (System-Theoretic Accident Model and Processes) `[Priority: P0 - Critical Safety]`
-   **CRITICAL**: STAMP is the mandatory framework for all safety-related analysis.
-   **Proactive Analysis (STPA)**: For all new critical features or major infrastructure changes, a formal **Systems-Theoretic Process Analysis** MUST be performed to identify Unsafe Control Actions (UCAs) and design safety constraints *before* implementation.
-   **Reactive Analysis (CAST)**: For all P1/P2 incidents, a **Causal Analysis based on STAMP** is mandatory. This supersedes simple RCA and requires analyzing the entire systemic context of the failure.
-   **Hazard Categorization**: All STAMP-related work MUST be categorized under the `10.0` hierarchical task number in `PROJECT_TODOLIST.md`.

### 2.5 Test-Driven Generation (TDG) `[Priority: P1 - Core Workflow]`
-   **Zero Tolerance Workflow**: 1. Write tests FIRST. 2. Generate code to pass tests. 3. Validate. 4. Refactor.
-   **Absolute Rule**: Generating code without pre-existing tests is a critical violation. No exceptions for any AI agent.

---

## 3.0 Ultra-Robust Compilation & Validation Protocol `[Priority: P0 - Critical Safety]`

**Rationale**: This protocol is the single source of truth for compilation. Its strict, automated steps are designed to prevent false positives (like incident EP-110) and ensure that no defective code can be approved. Any deviation is a critical safety violation.

### 3.1 Step 1: Patient Mode Compilation
ALL compilations MUST use the following command to ensure natural completion and full, untruncated logging.
```bash
# The ONLY permitted compilation command. Log file MUST be ./data/tmp/1-compile.log
NO_TIMEOUT=true PATIENT_MODE=enabled INFINITE_PATIENCE=true ELIXIR_ERL_OPTIONS="+S 16" mix compile --warnings-as-errors 2>&1 | tee -a ./data/tmp/1-compile.log
```
**Rationale**: Ensures complete capture of compilation output for exhaustive analysis, preventing partial information leading to false conclusions.

### 3.2 Step 2: Comprehensive Post-Compilation Verification
After the process from Step 1 finishes, the following verification steps are MANDATORY.
1.  **Clean Build**: The process must have started with `mix clean` to prevent false positives from stale artifacts.
2.  **Forced Compilation**: The command must have included `--force` to ensure all 773 project files were considered.
3.  **Exit Code Check**: The shell exit code (`$?`) must be `0`.
4.  **File Count Verification**: The log must show that all 773 project files were compiled.
5.  **Error/Warning Count**: Manually verify error and warning counts in the complete log. The target is zero for both.
**Rationale**: These checks provide a foundational layer of verification, ensuring the compilation process itself was complete and free of obvious issues.

### 3.3 Step 3: False Positive Prevention System (FPPS)
A 5-method consensus validation is required to definitively confirm the compilation status.
-   **Execution**: `elixir scripts/validation/comprehensive_compilation_validator.exs --require-consensus --log ./data/tmp/1-compile.log`
-   **Consensus Requirement**: ALL 5 validation methods (Pattern, AST, Statistical, Binary, Line-by-Line) MUST agree on the exact error and warning counts.
-   **Consensus Failure**: If methods disagree, HALT immediately and trigger an emergency protocol.
**Rationale**: Prevents incident EP-110 (false positive validation) by requiring multiple independent validation methods to agree, ensuring the reported status is accurate.

### 3.4 Step 4: Automated Incremental Fix Protocol
For fixing multiple errors, the automated incremental protocol is mandatory.
1.  **Prerequisite Validation**: `elixir scripts/validation/incremental_fix_prerequisite_validator.exs`
2.  **Intelligent Batch Planning**: `elixir scripts/validation/intelligent_batch_planner.exs --file <target_file.ex>`
3.  **Automated Execution**: `elixir scripts/validation/automated_fix_executor.exs --plan <batch_plan.json> --watch`
This system automates the entire fix-and-validate loop, including compilation, validation, git checkpointing, and automatic rollback on any failure.
**Rationale**: Eliminates human error in iterative fixing, ensuring each change is validated and auditable, maintaining system integrity during large-scale error resolution.

### 3.5 Historical Incident: EP-110 False Positive Validation Crisis
-   **Date**: 2025-09-16 21:12:00 CEST
-   **Incident**: Claude reported 17 warnings/0 errors vs actual 5,004 warnings/446 errors.
-   **Root Cause**: Selective compilation validation vs comprehensive Patient Mode validation.
-   **Magnitude**: 294x warning undercount with complete error blindness.
-   **Learning**: This incident led to the mandatory implementation of the multi-method FPPS consensus validation.

---

## 4.0 Container & Environment Policy `[Priority: P0 - Critical Safety]`

-   **Technology Stack**:
    -   **Permitted**: **Podman 5.4.1+** (rootless, daemonless), **NixOS**.
    -   **Forbidden**: **Docker** (in any form: daemon, CLI, Compose), **LXC/LXD**, and any other containerization technology.
    -   **Rationale**: The use of a rootless, daemonless architecture like Podman is a critical security control to reduce the system's attack surface. Docker's privileged daemon is a known vulnerability vector. (Hazard: UCA-SEC-002).
    -   **Forbidden Images**: Alpine, Ubuntu, Debian, CentOS, Fedora, docker.io.
-   **Container Registry**:
    -   **Permitted**: **`localhost/`** registry ONLY.
    -   **Forbidden**: Pulling from ANY external registry, including `registry.nixos.org`, `docker.io`, `quay.io`, etc., is a critical violation. All images must be built locally from the project's Nix expressions.
    -   **Rationale**: Enforces a secure software supply chain. Pulling images from unverified external registries can introduce malware, vulnerabilities, or non-compliant software. (Hazard: UCA-SEC-001).
-   **Hot-Reloading (PHICS)**:
    -   All development containers MUST use the Phoenix Hot-Reloading Integration Container System (PHICS v2.1) for `<50ms` bidirectional file sync.
    -   **Rationale**: Optimizes developer experience and iteration speed within the secure containerized environment.
-   **Automated Enforcement**:
    -   The `Indrajaal.ContainerCompliance` module automatically enforces these rules. Manual container commands are not necessary for the standard development workflow.
    -   **Rationale**: Ensures consistent adherence to container policy, reducing human error and security risks.
-   **Historical Incident: Alpine Linux Violation**:
    -   **Date**: 2025-08-02 08:16:00 CEST
    -   **Incident**: Claude AI created a container using Alpine Linux instead of MANDATORY NixOS.
    -   **Learning**: Led to mandatory image validation and automatic rejection of forbidden images.

---

## 5.0 Advanced Code Generation Patterns `[Priority: P1 - Core Workflow]`

This section provides prescriptive rules for generating high-quality, idiomatic, and maintainable Elixir, Ash, Phoenix, and Ecto code.

### 5.1 Elixir Idiomatic Patterns
-   **Rule**: Prefer `with` statements for chaining operations that return `{:ok, ...}` or `{:error, ...}`.
    ```elixir
    # Good Example: Chaining successful operations
    with {:ok, user} <- Accounts.get_user(user_id),
         {:ok, updated_user} <- Accounts.update_user(user, changes) do
      {:ok, updated_user}
    else
      {:error, reason} -> {:error, reason} # Handle specific errors or re-raise
    end
    ```
-   **Rule**: Use pattern matching in function heads for multiple clauses instead of complex `if/else` or `case` statements within the function body.
-   **Rule**: Leverage Elixir v1.18+ built-in `JSON` module for JSON encoding/decoding.
-   **Rule**: Use `Boundary` for enforcing architectural boundaries between contexts.
-   **Rule**: Employ `@spec` for all public functions and `@type` for complex data structures.

### 5.2 Ash Resource Best Practices
-   **Rule**: Always define specific, strongly-named changeset functions for distinct use cases (e.g., `register_changeset`, `update_profile_changeset`).
-   **Rule**: Use `require_atomic? false` ONLY for `UPDATE` actions with function-based changes, never for `CREATE`.
-   **Rule**: Define policies (`Ash.Policy`) for all resources to enforce authorization.
-   **Rule**: Leverage Ash's built-in validations and custom validations for complex business rules.
-   **Rule**: Implement Ash's **Tool Exposure Pattern** for LLM interaction, including `load` options and clear descriptions.
    ```elixir
    # Example: Exposing an Ash action as a tool for LLMs
    tools do
      tool :read_posts, Post, :read do
        description "Read all blog posts with optional filtering"
        load [:author, :comment_count] # Load related data
      end
    end
    ```
-   **Rule**: Utilize **Prompt-Backed Actions** where implementation is delegated to an LLM using structured outputs for type safety.
-   **Rule**: Implement Ash's **Vectorization System** for semantic search, ensuring embeddings are stored alongside resources.

### 5.3 Phoenix/LiveView Component Guidelines
-   **Rule**: Use Function Components (`Phoenix.Component`) for stateless, presentational UI elements.
-   **Rule**: Use Live Components (`Phoenix.LiveComponent`) for stateful, interactive UI elements that manage their own lifecycle and events.
-   **Rule**: Minimize state in `assigns` and use `temporary_assigns` for ephemeral data.
-   **Rule**: Apply `phx-debounce` or `phx-throttle` to rate-limit user input events in LiveViews.
-   **Rule**: Use HEEx components for all reusable UI elements, leveraging compile-time checks.

### 5.4 Ecto Query & Validation Best Practices
-   **Rule**: Prevent N+1 query problems by using `Repo.preload/3` and `join/5` for loading associations.
-   **Rule**: Explicitly `select` only necessary columns in queries to optimize performance.
-   **Rule**: Use `Ecto.Multi` for all transactional operations involving multiple database changes.
-   **Rule**: Always `cast` permitted fields in changesets (whitelisting).
-   **Rule**: Prioritize `validate` functions for immediate user feedback and `constrain` for database-level integrity.

---

## 6.0 Advanced Testing Protocols `[Priority: P1 - Core Workflow]`

This section formalizes advanced testing methodologies to ensure code correctness, robustness, and compliance with safety standards.

### 6.1 Comprehensive Test Coverage Targets
-   **Rule**: Achieve 100% Unit Test Coverage for all functional modules.
-   **Rule**: Achieve 100% Property Testing Coverage for all functional modules using **Dual Property Testing** (PropCheck and ExUnitProperties).
-   **Rule**: Achieve 85% Integration and Intermodule Test Coverage.
-   **Rule**: Achieve 95% TDG Compliance and 95% STAMP Safety Coverage.

### 6.2 LiveView Testing
-   **Rule**: Use `Phoenix.LiveViewTest` for integration testing of LiveViews and Live Components.
-   **Rule**: Simulate user interactions (e.g., `render_hook`, `form`, `click`) to test event handling and state changes.

### 6.3 Ash Resource Testing
-   **Rule**: Test Ash resources using `Ash.Test` helpers, focusing on actions, policies, and data layer interactions.
-   **Rule**: Use `Mox` for mocking external dependencies in Ash tests.
-   **Rule**: For Ash AI components, use `AshAi.TestRepo` with Ecto sandbox and mock LLM responses with `ChatFaker`.

---

## 7.0 Scripting Best Practices `[Priority: P2 - Best Practice]`

This section provides guidelines for writing robust, maintainable, and compliant Elixir scripts.

### 7.1 Elixir Script Structure
-   **Rule**: Use `Mix.install([{:dep, "~> x.x"}])` at the top of standalone Elixir scripts for dependency management.
-   **Rule**: Implement robust argument parsing using `OptionParser` for CLI scripts.
-   **Rule**: Include clear `@moduledoc` and `@doc` for all scripts.

### 7.2 Error Handling in Scripts
-   **Rule**: Use `System.cmd/3` with `exit_status: true` and handle non-zero exit codes explicitly.
-   **Rule**: Implement `try/rescue` for critical operations that might fail.

---

## 8.0 AI Agent Operations & Git Workflow `[Priority: P1 - Core Workflow]`

-   **AEE Mode**: All operations must be conducted in Autonomous Execution Engine (AEE) mode, leveraging the 15-agent cybernetic architecture for task execution.

-   **AI Logging**: All significant AI activities (sessions, tasks, code generation, errors, STAMP/TPS analysis) MUST be logged to `./data/tmp/` using the `Indrajaal.Claude.LogStorage` interface.

-   **Git-as-Memory Workflow**:
    -   **Branching**: Create a new feature branch for every task (e.g., `feat/TICKET-123-fix-compilation-errors`). Never commit directly to `main`.
    -   **Commits**: Make small, atomic commits with messages following the **Conventional Commits** specification.
        ```
        # Good: A single, logical change
        fix: resolve undefined variable 'user' in AuthController
        
        # Bad: Multiple unrelated changes
        feat: add user profile and fix login bugs
        ```
    -   **Pull Requests**: Open a pull request for every feature branch. The PR description must link to the corresponding issue. All automated checks must pass before merge.
    -   **Context**: To gain context, analyze the Git history (`git log`), blame (`git blame`), and diffs (`git diff`). Do not request large files to be dumped into the prompt.
    -   **Task Management Integration**: Use `gh issue create` and `gh pr create` for managing tasks and pull requests, ensuring traceability and adherence to the Git-as-Memory paradigm.

---

## 9.0 General Development Rules

-   **File Storage & Naming** `[Priority: P2 - Best Practice]`:
    -   **Critical Files**: `CLAUDE.md`, `README.md`, `mix.exs`, `devenv.nix` are protected and must remain in the root.
    -   **AI Logs**: All AI-generated logs and temporary files go in `./data/tmp/`.
    -   **Journal Entries**: All journal entries go in `docs/journal/` with the mandatory format: `YYYYMMDD-HHMM-[descriptive-name].md`.

-   **Scripting** `[Priority: P1 - Core Workflow]` (See also Section 6.0 Scripting Best Practices):
    -   **Languages**: Scripts MUST be Elixir (`.exs`) or Python (`.py`). No shell scripts (`.sh`).
    -   **JSON Parsing**: Elixir scripts MUST use `Mix.install([{:jason, "~> 1.4"}])` for JSON processing.

-   **Task Management** `[Priority: P1 - Core Workflow]`:
    -   **Source of Truth**: `PROJECT_TODOLIST.md`.
    -   **Interface**: Use `mix todo.*` commands (`status`, `update`, `backup`, `validate`, `sync`).
    -   **Status Updates**: Update status to `in_progress`, `completed`, or `blocked` immediately. Only one task can be `in_progress` at a time.
    -   **Numbering**: All tasks MUST use the hierarchical numbering system (e.g., `1.2.3.4`).

-   **Code Quality** `[Priority: P1 - Core Workflow]`:
    -   **Validation**: ALL generated Elixir code must pass `mix format` and `mix credo --strict` immediately after generation and before being presented.
    -   **Static Type Checking**: Mandate `mix dialyzer` for static type checking.
    -   **Security Scanning**: Mandate `mix sobelow` for security scanning.

-   **Timestamps** `[Priority: P2 - Best Practice]`:
    -   **Standard**: Use current local time (CEST/CET), NOT UTC. Use the provided `LocalTime` module.
    -   **Verification**: All commits must be preceded by a timestamp validation audit.

---

## 10.0 Architectural Specifications `[Priority: P2 - Informational]`

This data provides context for agent decision-making regarding task delegation and resource allocation.

### 10.1 Current 15-Agent Cybernetic Architecture
The system operates on a simplified 3-layer hierarchy totaling 15 agents:
-   **Layer 1: Executive Supervisor (1 Agent):** Supreme system oversight and strategic coordination.
-   **Layer 2: Functional Supervisors (4 Agents):** Manages core operational areas: Compilation & Validation, Testing & QA, Infrastructure & Deployment, and Performance & Monitoring.
-   **Layer 3: Worker Agents (10 Agents):** A pool of general-purpose agents that execute tasks assigned by the Functional Supervisors.

### 10.2 Current Monolithic Container Architecture
All Elixir and Phoenix application logic is consolidated into a single container for simplicity and ease of management.
-   **`indrajaal-app-mono` (1 Container):** Contains the complete Phoenix web application, including all Ash domains and the API.
-   **Backing Services (Separate Containers):** Critical backing services such as PostgreSQL, Redis, and MinIO continue to operate in their own dedicated containers.

### 10.3 Archived Architectural Specifications (Previous 50-Agent / 10-Container Model)
This section preserves the details of the previous architectural model, which has been superseded but must not be lost.

#### 10.3.1 Previous 50-Agent Cybernetic Architecture
-   **Layer 1 - Executive Director (1 Agent):** Complete system oversight and strategic coordination.
-   **Layer 2 - Domain Supervisors (10 Agents):** One supervisor per specialized container/domain.
-   **Layer 3 - Functional Supervisors (15 Agents):** Specialists in Compilation, QA, Performance, etc.
-   **Layer 4 - Worker Agents (24 Agents):** Execute specific tasks like file processing, pattern recognition, and validation.

#### 10.3.2 Previous 10-Container Infrastructure Specifications
| Container | Complexity | CPU | RAM | Purpose | Domain Supervisor |
|---|---|---|---|---|---|
| access_control | High | 4.2 cores | 8GB | Security Access | Domain-01 |
| accounts | Medium | 3.0 cores | 5GB | User Management | Domain-02 |
| alarms | High | 4.2 cores | 8GB | Alert Processing | Domain-03 |
| analytics | High | 4.2 cores | 8GB | Data Analysis | Domain-04 |
| communication | Medium | 3.0 cores | 5GB | Messaging | Domain-05 |
| compliance | Medium | 2.8 cores | 4GB | Regulatory | Domain-06 |
| devices | Low | 2.0 cores | 3GB | Hardware | Domain-07 |
| performance | High | 4.2 cores | 8GB | Optimization | Domain-08 |
| observability | Very High | 4.5 cores | 9GB | Monitoring | Domain-09 |
| web_api | High | 4.0 cores | 7GB | API Gateway | Domain-10 |

---

## 11.0 Meta-Protocol for Ruleset Management `[Priority: P1 - Core Workflow]`

**Rationale**: This protocol governs the modification of this ruleset (`CLAUDE-NEW.md`) to prevent unauthorized or unsafe changes to the agent's core instructions.

1.  **Proposal of Change**: Any proposed change to this document must be submitted as a Git issue with the `[Ruleset-Change]` label. The issue must detail the proposed change and the rationale.
2.  **Implementation**: The change must be implemented on a dedicated feature branch.
3.  **Validation**: Before merging, the change must be validated. This includes:
    -   **Conflict Analysis**: The change must be checked for conflicts with existing rules.
    -   **Safety Review**: A STPA-like analysis must be performed to ensure the change does not introduce new hazards or unsafe control actions for the agent.
    -   **Compliance Test**: A (future) compliance test suite should be run to ensure an agent following the new rules would still pass all critical safety and workflow checks.
4.  **Deployment**: Once validated, the change can be merged into `main`. `CLAUDE.md` and `CLAUDE-NEW.md` must be kept in sync.
5.  **Agent Re-initialization**: After a ruleset change is deployed, all active AI agents must be re-initialized to ensure they are operating with the latest instruction set.

---

## 12.0 Legacy System References `[Priority: P2 - Informational]`

This section preserves references to legacy commands and migration paths from previous versions of the ruleset.

### 12.1 Unified Mix Tasks (Previous)
This outlines the previous unified Mix task system, which has been superseded by more granular and explicit commands.

-   **Compilation**: `mix compile [--strategy fast/ultra_fast/patient] [--dashboard] [--benchmark]`
-   **Parallel**: `ELIXIR_ERL_OPTIONS="+S 10" mix compile --warnings-as-errors`
-   **CLAUDE AI**: `mix claude [compilation/quality/workflow/monitor/agent] [options]`
-   **Multi-Agent**: `mix claude compilation --supervisor 1 --helpers 4 --workers 6 --dynamic-tokens`
-   **Testing**: `mix test [--comprehensive/--coverage/--optimized/--gold]`
-   **ASH**: `mix ash.[setup/reset/check/validate]`

### 12.2 Legacy Migration System
Automatic Migration with Deprecation Warnings:
-   `mix compile --fast` → `mix compile --strategy fast`
-   `mix claude compilation` → `mix claude compilation`
-   `mix test --comprehensive` → `mix test --comprehensive`
-   All 48 legacy tasks automatically redirect with clear guidance.