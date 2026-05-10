# Effect TS IIFE Rule for .agents

Browser/runtime JavaScript behavior must be authored in Effect TypeScript and shipped as generated IIFE output. This mirror keeps `.agents` compatible with the Claude/Gemini IIFE rules:

- `.claude/rules/effect-ts-only-js.md`
- `.gemini/rules/effect-ts-only-js.md`

## Mandate

- Do not add hand-authored runtime `.js` behavior.
- Author browser behavior in `.ts` using `effect` and relevant `@effect/*` packages.
- Bundle runtime browser output with `esbuild --format=iife` or equivalent checked configuration.
- Treat edited `.js` as generated output only when the source `.ts` and build path are present.
- Apply the universal Effect TS rule to all TypeScript, including non-browser modules.

## Evidence

```bash
rg -n "--format=iife|format:\\s*['\"]iife['\"]" .
rg -n "from ['\"]effect['\"]|from ['\"]@effect/" <changed-browser-ts-paths>
rg -n "from ['\"]fp-ts|fp-ts/" <changed-browser-ts-paths>
```
