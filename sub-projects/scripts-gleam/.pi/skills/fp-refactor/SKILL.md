---
name: fp-refactor
description: Expert workflows for refactoring imperative TypeScript to functional patterns using fp-ts. Use this when you need to replace null checks with Option, try-catch with Either, or async/await with TaskEither.
---

# Functional Programming Refactor (fp-ts)

This skill provides precise patterns and instructions for migrating imperative code to the `fp-ts` ecosystem.

## 1. Core Translation Patterns

| Imperative | fp-ts Target | Instruction |
| :--- | :--- | :--- |
| `null` / `undefined` | `Option` | Use `O.fromNullable` and `O.fold`. |
| `try-catch` | `Either` | Use `E.tryCatch` to define explicit error types. |
| `async-await` | `TaskEither` | Use `TE.fromPromise` and `TE.chain`. |
| Loops / Mutation | `ReadonlyArray` | Use `A.map`, `A.filter`, `A.traverse`. |

## 2. Refactoring Workflow

### Step 1: Wrap Inputs
Lift raw values into functional contexts early.
- `const value = O.fromNullable(input);`

### Step 2: Compose with Pipe
Use the `pipe` function to chain transformations.
- Always prefer `TE.chain` over manual `await`.
- Use `flow` for reusable function composition.

### Step 3: Handle the Result
Use `fold` or `match` at the "edge" of your application to handle all branches (Left/Right, Some/None).

## 3. Best Practices
- **No Side Effects in Pipes**: Wrap mutations in `IO` or `Task`.
- **Typed Errors**: Do not use `Error` as the Left side; use specific domain unions (e.g., `NotFoundError | ValidationError`).
- **Avoid Nested Pipes**: If a chain exceeds 5 steps, refactor into smaller named functions.
