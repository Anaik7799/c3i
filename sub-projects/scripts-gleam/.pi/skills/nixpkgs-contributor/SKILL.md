---
name: nixpkgs-contributor
description: Workflows for contributing to the Nixpkgs ecosystem. Use this skill to package new software, update existing definitions, and follow Nixpkgs PR standards.
---

# Nixpkgs Contributor Skill

This skill provides standardized workflows for packaging and contributing to Nixpkgs.

## 1. Packaging Checklist
1. **Name/Version**: Define `pname` and `version`.
2. **Source**: Use `fetchurl`, `fetchFromGitHub`, etc. Always provide the `sha256` or `hash`.
3. **Build System**: Choose the correct builder (e.g., `buildPythonApplication`, `buildGoModule`).
4. **Metadata**: Always include `meta = { description = "..."; license = lib.licenses.mit; };`.

## 2. Testing Workflows
- **Build**: `nix-build -A package_name`
- **Lint**: Use `statix` or `deadnix` to check for code quality.
- **Integration**: `nixos-rebuild switch -I nixpkgs=./local-nixpkgs`

## 3. PR Standards
- Follow the **Commit Message Convention**: `pname: init at version`, `pname: fix build`.
- Maintain a **Minimal Reproducible Example** when reporting bugs.
- Always check the `contributing/how-to-contribute` guide for language-specific requirements (e.g., Python `propagatedBuildInputs`).
