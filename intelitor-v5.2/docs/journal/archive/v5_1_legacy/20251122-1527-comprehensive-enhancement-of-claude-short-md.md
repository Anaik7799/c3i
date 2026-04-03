**Date**: 2025-11-22 15:27:00 CEST
**Author**: Gemini
**Task**: 1.1.4 (Assumed) - Implement comprehensive improvements to `CLAUDE-SHORT.md` for enhanced code generation, testing, and scripting quality.

## Summary

Following a comprehensive review of the project codebase and the latest best practices for Elixir, Ash, Phoenix, and Ecto, `CLAUDE-SHORT.md` has been significantly enhanced. The document now integrates highly prescriptive rules, advanced patterns, and explicit quality gates aimed at drastically improving the quality of AI-generated application code, test code, and scripts, especially for safety-critical applications.

## Key Enhancements and Rationale

The improvements were structured around integrating cutting-edge best practices into the agent's operational rules, ensuring clarity, safety, and adherence to project standards.

### 1. Expanded Foundational Methodologies & Core Principles

-   **SOPv5.11 Cybernetic Framework & AEE**: Clarified the roles within the 15-agent architecture for task delegation.
-   **TPS**: Emphasized Jidoka for *all* detected anomalies and mandatory documentation of RCA findings.
-   **STAMP**: Mandated the use of formal STPA/CAST report templates.
-   **TDG**: Specified mandatory **Dual Property Testing** (PropCheck and ExUnitProperties) for critical modules.

### 2. Enhanced Ultra-Robust Compilation & Validation Protocol

-   **Elixir/OTP Versioning**: Explicitly stated target Elixir (v1.19 compatible) and Erlang/OTP (v28 compatible) versions for generated code.
-   **FPPS**: Reinforced that FPPS validation must also check for `CompileError` and `syntax error` patterns.

### 3. Strengthened Container & Environment Policy

-   **Forbidden Images**: Explicitly listed forbidden container images (Alpine, Ubuntu, Debian, etc.) and mandated NixOS 25.05 containers.
-   **Registry Enforcement**: Reiteration that `localhost/` is the *only* permitted registry.

### 4. New Section: Advanced Code Generation Patterns

This major new section integrates best practices for generating high-quality code across the stack:

-   **Elixir Idiomatic Patterns**: Rules for `with` statements, pattern matching in function heads, Elixir v1.18+ `JSON` module, `Boundary` for architectural separation, and comprehensive `@spec`/`@type` usage.
-   **Ash Resource Best Practices**: Rules for specific changeset functions, `require_atomic? false` usage, policy definitions, built-in/custom validations, **Tool Exposure Pattern** for LLM interaction, **Prompt-Backed Actions**, and **Vectorization System** implementation.
-   **Phoenix/LiveView Component Guidelines**: Rules for Function vs. Live Components, state minimization, `phx-debounce`/`phx-throttle`, and HEEx component usage.
-   **Ecto Query & Validation Best Practices**: Rules for N+1 prevention (`preload`/`join`), explicit `select`, `Ecto.Multi` for transactions, `cast` whitelisting, and `validate`/`constrain` prioritization.

### 5. New Section: Advanced Testing Protocols

This section formalizes advanced testing methodologies.

-   **Comprehensive Test Coverage Targets**: Detailed targets for Unit (100%), Property (100% Dual Property), Integration (85%), TDG Compliance (95%), and STAMP Safety (95%).
-   **LiveView Testing**: Rules for `Phoenix.LiveViewTest` and simulating user interactions.
-   **Ash Resource Testing**: Rules for `Ash.Test` helpers, policies, data layer interactions, `Mox` for mocking, and `AshAi.TestRepo` with `ChatFaker` for Ash AI components.

### 6. New Section: Scripting Best Practices

This section provides guidelines for writing robust Elixir scripts.

-   **Elixir Script Structure**: Rules for `Mix.install`, `OptionParser` for argument parsing, and clear `@moduledoc`/`@doc`.
-   **Error Handling in Scripts**: Rules for `System.cmd/3` with `exit_status: true` and `try/rescue`.

### 7. Updates to Existing Sections

-   **AI Agent Operations & Git Workflow**: Enhanced with explicit mentions of `gh issue create` and `gh pr create` for task management and pull requests, reinforcing Git-as-Memory.
-   **General Development Rules**: Under "Code Quality", explicitly mandated `mix dialyzer` for static type checking and `mix sobelow` for security scanning as critical quality gates.

## Conclusion

These enhancements transform `CLAUDE-SHORT.md` from a simple list of rules into a comprehensive, self-governing operational manual for an AI agent. By adding an index, prioritization, rationale, architectural context, and a meta-protocol, we have significantly improved the document's functionality, reduced ambiguity, and increased the safety and reliability of agent operations within this safety-critical environment.
