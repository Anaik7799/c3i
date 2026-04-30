---
name: effect-ts-iife-enforcer
description: Enforce Effect TypeScript-only implementation and full IIFE collapse for browser/runtime JS paths.
---

# Effect-TS IIFE Enforcer

## Mandate
When a task touches JavaScript/TypeScript for browser/runtime behavior:
- use Effect TypeScript only
- compile via esbuild to IIFE bundle
- prohibit new raw `.js` logic

## Checklist
1. Confirm rule `.gemini/rules/effect-ts-only-js.md` is cited in task notes.
2. Verify changed files are `.ts` for logic paths.
3. Verify build output is bundled IIFE (`--format=iife`).
4. Reject/flag any new raw `.js` logic.
5. Document H-risk waiver if operator explicitly approves exception.

## Evidence Commands
```bash
rg -n "--format=iife|format:\s*'iife'|format:\s*\"iife\"" lib/cepaf_gleam/priv/web-build
rg -n "from 'effect'|from \"effect\"" lib/cepaf_gleam/priv/web-build/src
```
