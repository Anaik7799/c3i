---
name: pi-mono-agent
description: Expert workflows for configuring and extending the pi-mono coding-agent (Pi). Use this skill to manage .pi/settings.json, develop TypeScript extensions, create prompt templates, and customize themes.
---

# Pi-Mono Agent Skill

This skill provides specialized knowledge and procedures for the `pi-mono` coding-agent environment.

## 1. Configuration Lifecycle
Pi uses hierarchical configuration (`~/.pi/agent/` and `.pi/`).

- **Settings**: Manage `.pi/settings.json` for project-specific model overrides or keybindings.
- **System Prompts**: 
    - Use `.pi/SYSTEM.md` to completely replace the system prompt.
    - Use `APPEND_SYSTEM.md` to add context without overwriting.
- **Context Loading**: Pi automatically merges `AGENTS.md` and `CLAUDE.md` from the current and parent directories.

## 2. Extension Development (TypeScript)
Extensions allow for arbitrary tool and command registration.

- **Structure**: Create a `.ts` file in `.pi/extensions/` with a default export:
  ```typescript
  export default function (pi: ExtensionAPI) {
    pi.registerTool({
      name: "my_tool",
      description: "Description...",
      execute: async (args) => { ... }
    });
  }
  ```
- **Capabilities**: Register tools, slash commands, hotkeys, and hook into `tool_call` events.

## 3. Prompt Templates
Prompt templates are expanded in the editor using `/filename`.

- **Location**: Store templates in `.pi/prompts/*.md`.
- **Logic**: Supports Handlebars `{{variable}}` syntax.
- **Workflow**: Create a template and invoke it via `/name` to inject complex instructions.

## 4. Skills Management
Pi skills follow the Markdown-based `SKILL.md` standard.

- **Search Path**: `.pi/skills/` or `.agents/skills/`.
- **Usage**: Trigger manually via `/skill:name` or let the agent auto-load them based on task relevance.

## 5. Themes & UI
- **Live Reload**: Modifying files in `.pi/themes/` applies changes instantly to the terminal UI.
- **Command**: Use `/theme <name>` to switch.

## 6. Packaging & Installation
- **pi install**: Use to fetch packages from `npm` or `git`.
- **package.json**: Define a `"pi"` key to export extensions, skills, and templates.
