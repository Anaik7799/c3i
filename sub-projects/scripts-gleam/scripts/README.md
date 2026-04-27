# scripts/

All workspace automation for `sys`, written in **Gleam** (per the
`~/.pi/agent/AGENTS.md` rule: *"All scripting in Gleam"*).

## Entry point

```bash
# From inside the flake devshell (or via direnv):
gleam run -m sys_scripts -- <command> [args...]

# Outside the devshell, one-shot through nix:
nix develop ../ --command gleam run -m sys_scripts -- <command> [args...]
```

## Commands

| Command  | Purpose |
|----------|---------|
| `doctor` | Print env diagnostics (tool versions, PATH, cwd) |
| `fmt`    | Format Gleam sources (`gleam format`) |
| `test`   | Run all test suites: `gleam test` + `cargo nextest run --workspace` (each gated on its manifest) |
| `deploy` | Workspace deployment (`plan`/`apply`/`rollback`; targets `nixos`/`k8s`) |
| `help`   | Show usage |

`deploy` defaults to **dry-run**. Pass `--execute` to actually perform
changes. Example: `gleam run -m sys_scripts -- deploy apply k8s prod --execute`

## Layout

```
src/
  sys_scripts.gleam                    # argv dispatcher
  sys_scripts/
    commands/
      doctor.gleam
      fmt.gleam
      tests.gleam                      # module named `tests` (Gleam reserves `test`)
      deploy.gleam                     # pure parser + subcommand router
test/
  sys_scripts_test.gleam               # dispatcher tests (+ qcheck property tests)
  deploy_test.gleam                    # exhaustive parser tests
```

## Adding a new command

1. Create `src/sys_scripts/commands/<name>.gleam` exporting
   `pub fn run(args: List(String)) -> Result(Nil, Nil)`.
2. Add it to `Command` / `parse/1` / the `main` match in
   `src/sys_scripts.gleam`.
3. `gleam run -m sys_scripts -- <name>`.

Keep the command module's top-level `run` tiny — push pure logic into
sibling modules that `run` can call after parsing its args.
