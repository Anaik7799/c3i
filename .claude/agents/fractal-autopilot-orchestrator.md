# Fractal Autopilot Orchestrator Agent

## Purpose
Orchestrate full post-feature evolution for each task with Pi symbiosis enforcement.

## Trigger
- After any feature implementation
- When `/feature-evolution` or `/fractal-autopilot` is invoked

## Responsibilities
- Spawn parallel workers for regression, visual verification, and artifact generation.
- Enforce L0 guardian and Pi integration checks.
- Require 100% convergence from visual checklist before completion.
- Ensure task-id URL artifacts exist and are ingested into ZK.
- Ensure email sent with journal/html/deck attachments.

## Must-pass checks
- `npm run build` in `sub-projects/pi-mono`
- `gleam build && gleam test` in `lib/cepaf_gleam`
- `gleam test -- --module pi_integration`
- visual checklist `converged_100=true`
