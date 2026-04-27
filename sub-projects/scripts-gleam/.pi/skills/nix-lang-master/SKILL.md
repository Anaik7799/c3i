---
name: nix-lang-master
description: Expert patterns for the Nix expression language. Use this skill for writing complex derivations, functional composition, and debugging Nix logic (attributes, recursion, flakes).
---

# Nix Language Master Skill

This skill provides deep technical patterns for the purely functional Nix language.

## 1. Core Data Structures
- **Attribute Sets**: `{ x = 1; y = 2; }`. Access via `set.x`.
- **Recursion**: Use `rec { x = 1; y = x + 1; }` to allow self-referencing.
- **Functions**: `arg: logic`. Example: `x: x * 2`.
- **Pattern Matching**: `{ pkgs, ... }: { ... }`.

## 2. Scope Management
- **`let...in`**: Define local variables.
- **`with pkgs; [ htop ripgrep ]`**: Pull attributes into the current scope (use sparingly).
- **`inherit x;`**: Shorthand for `x = x;`.

## 3. Derivations
Standard pattern for building software:
```nix
pkgs.stdenv.mkDerivation {
  pname = "my-app";
  version = "1.0.0";
  src = ./.;
  buildInputs = [ pkgs.openssl ];
}
```

## 4. Advanced Debugging
- Use `builtins.trace value expression` to print values during evaluation.
- Use `nix repl` to interactively explore attribute sets and functions.
