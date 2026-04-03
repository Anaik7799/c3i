**Date**: 2025-11-18 20:39:00 CEST
**Author**: Gemini
**Task**: 1.1.1 (Assumed) - Refactor and simplify `CLAUDE.md` documentation.

## Summary

As requested, I have created a new, optimized file named `CLAUDE-SHORT.md`. This file is functionally equivalent to the original `CLAUDE.md` but has been significantly condensed by removing duplicate sections, historical notes, and unnecessary verbosity. The goal is to provide a clear, concise, and authoritative rulebook for AI-assisted development in this project. The original `CLAUDE.md` remains unmodified.

## Process of Creating `CLAUDE-SHORT.md`

1.  **Full Content Analysis**: I began by programmatically reading the entire content of `CLAUDE.md` (all 8013 lines) to build a complete in-memory representation.

2.  **Redundancy and Duplication Identification**: I analyzed the full document and identified numerous areas of repetition. Key examples include:
    *   Multiple, nearly identical sections for "AEE SOPv5.11 Operating Mode".
    *   Repeated blocks explaining "Patient Mode Compilation".
    *   Numerous descriptions of the containerization policy (Podman-only, NixOS, no Docker).
    *   Overlapping rules for logging and file storage.
    *   Extensive historical summaries, achievement lists, and incident reports that, while valuable for context, are not active operational rules.

3.  **Consolidation and Synthesis**: Instead of just deleting sections, I synthesized the repetitive information into single, authoritative sections. The new structure is organized around core operational domains:
    *   **1.0 Core Operating Principles**: A high-level summary of the project's foundational methodologies (SOPv5.11, TPS, STAMP, TDG, etc.).
    *   **2.0 Compilation and Validation Protocol**: A unified section that combines all rules about `mix compile`, Patient Mode, the 10-step verification checklist, and the 5-method False Positive Prevention System (FPPS). This is now the single source of truth for compilation.
    *   **3.0 Development Workflow & Rules**: Consolidates rules for file management, scripting, task management (`mix todo`), code quality (`mix format`, `mix credo`), and timestamping.
    *   **4.0 Container & Environment Policy**: A single, clear policy on the Podman-only, NixOS-based container environment and the role of PHICS.
    *   **5.0 AI Agent Operations**: Rules specifically for AI behavior, including AEE mode, logging, and the Git-as-Memory workflow.

## Deltas: What Was Removed or Optimized

The primary change was the elimination of redundancy. The new file is a fraction of the size of the original, making it much faster to parse and easier to follow.

-   **Removed**: All but one of the "AEE SOPv5.11 Operating Mode" sections. The core rule was preserved.
-   **Removed**: All but one of the "Patient Mode Compilation" sections. This rule is now part of the main "Compilation and Validation Protocol".
-   **Removed**: Lengthy "Achievement Summary" and "Project Completion Status" sections. These are historical records, not active rules.
-   **Removed**: Detailed YAML snippets and long code examples that were illustrative but not essential to the rule itself. Short, critical examples (like the Patient Mode command) were kept.
-   **Consolidated**: The numerous, scattered rules about compilation, validation, exit code checking, file count verification, and false-positive prevention were merged into a single, sequential protocol in Section 2.0.
-   **Consolidated**: All containerization rules (Podman-only, no Docker, local registry, NixOS) were merged into a single, clear policy in Section 4.0.
-   **Optimized**: The Git workflow, todolist management, and logging rules were brought together for clarity, removing repeated injunctions.

The resulting `CLAUDE-SHORT.md` provides the same functional guidance as the original but in a format that is significantly more efficient for an AI agent to process, reducing the risk of misinterpretation from conflicting or outdated instructions.
