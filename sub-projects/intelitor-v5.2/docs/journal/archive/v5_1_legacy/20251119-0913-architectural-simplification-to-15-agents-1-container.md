**Date**: 2025-11-19 09:13:00 CEST
**Author**: Gemini
**Task**: 1.1.3 (Assumed) - Refactor architecture to 15-agent and single application container model.

## Summary

In response to the directive to simplify the project's architecture, `CLAUDE-SHORT.md` has been updated to reflect a major shift from a complex, microservices-style architecture to a more streamlined model. The two primary changes are:

1.  **Agent Architecture Reduction**: The system is now defined with a **15-agent architecture**, down from 50.
2.  **Application Container Consolidation**: All Elixir/Phoenix application logic is now defined to run in a **single monolithic container**, moving away from the 10-container domain-driven model.

This journal entry details the specific changes made to the official ruleset.

## Architectural Changes

### 1. From 50 Agents to 15 Agents

The previous 4-layer, 15-agent model was deemed overly complex. The new 15-agent model simplifies this to a 3-layer hierarchy, which is easier to manage and reason about while retaining the core principles of cybernetic control.

-   **Old Structure**: 1 Executive Director, 10 Domain Supervisors, 15 Functional Supervisors, 24 Workers.
-   **New Structure**:
    -   **Layer 1: Executive Supervisor (1 Agent)**: Retains supreme strategic oversight.
    -   **Layer 2: Functional Supervisors (4 Agents)**: Manages core operational areas (Compilation, Testing, Infrastructure, Performance).
    -   **Layer 3: Worker Agents (10 Agents)**: A general-purpose pool for task execution.

### 2. From 10 Containers to 1 Application Container

The 10-container model, where each container represented a specific application domain, was also simplified.

-   **Old Structure**: 10 separate containers for domains like `access_control`, `alarms`, `analytics`, etc.
-   **New Structure**:
    -   **`indrajaal-app-mono` (1 Container)**: A single container that runs the entire Phoenix application, including all 19 Ash domains and the web API.
    -   **Backing Services**: It is assumed and noted in the rules that essential backing services (e.g., PostgreSQL, Redis, MinIO) will continue to run in their own separate, dedicated containers.

## Document Updates in `CLAUDE-SHORT.md`

To reflect these changes, the following sections of the ruleset were modified:

1.  **Section 1.1 (SOPv5.11 Cybernetic Framework & AEE)**: The text was updated to reference the new "15-Agent Architecture".

2.  **Section 4.0 (AI Agent Operations & Git Workflow)**: The text here was also updated to reference the "15-agent cybernetic architecture".

3.  **Section 6.0 (Architectural Specifications)**: This section was completely replaced. The previous tables detailing the 15-agent and 10-container models were removed. The new content explicitly defines the new 15-agent hierarchy and the monolithic application container model, clarifying the separation of the application container from backing services.

## Rationale & Impact

The primary driver for this change is to reduce complexity. While the microservices-style architecture offered domain isolation, it introduced significant overhead in coordination, resource management, and local development. The new, simpler model is expected to be more efficient for the current scale of the project, while still adhering to all core safety and operational principles (STAMP, TPS, Patient Mode, etc.). The agent's operational space is still strictly bounded, but within a more manageable architectural framework.
