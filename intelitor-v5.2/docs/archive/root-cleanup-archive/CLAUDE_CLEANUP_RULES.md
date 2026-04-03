# CLAUDE.md - Cleanup and Organization Rules

## 🎯 Project Organization Rules

### File Creation Rules
1. **NEVER create files in root directory** except:
   - `README.md`
   - `mix.exs`
   - Configuration files (`.formatter.exs`, `.credo.exs`, `.gitignore`)

2. **ALWAYS use proper directories**:
   - Documentation → `docs/`
   - Scripts → `scripts/` or `lib/mix/tasks/`
   - Tests → `test/`
   - Web files → `lib/indrajaal_web/`
   - Core logic → `lib/indrajaal/`

### Script Management Rules
1. **Convert recurring scripts to Mix tasks**
   - Place in `lib/mix/tasks/`
   - Use proper Mix.Task behaviour
   - Document with `@shortdoc` and `@moduledoc`

2. **One-time scripts**:
   - Place in `scripts/` with subdirectory by purpose
   - Add `.exs` extension
   - Include shebang: `#!/usr/bin/env elixir`

### Documentation Rules
1. **All markdown docs go in `docs/`** except `README.md`
2. **Update documentation when code changes**
3. **Use `docs/journal/` for progress tracking**
4. **Archive old docs in `docs/archive/`**

### Artifact Management Rules
1. **Runtime outputs**:
   - Logs → `logs/`
   - Test results → `test_results/`
   - Temporary files → `tmp/`

2. **Build artifacts**:
   - Use `_build/`
   - Never commit build outputs

3. **Backups**:
   - Use `backups/`
   - Add to `.gitignore`

## 🔧 Mix Integration Rules

### When Creating New Functionality
1. **Check if it should be a Mix task**:
   ```elixir
   # Good: Recurring task
   defmodule Mix.Tasks.Project.Analyze do
     use Mix.Task
     @shortdoc "Analyzes project structure"
     def run(_args), do: # implementation
   end

   # Bad: Creating standalone script for recurring task
   # setup_something.exs in root
   ```

2. **Use Mix aliases for command chains**:
   ```elixir
   # In mix.exs
   defp aliases do
     [
       setup: ["deps.get", "ecto.setup", "npm.install"],
       "test.all": ["test", "credo --strict", "dialyzer"]
     ]
   end
   ```

### unified-4.exs Integration
1. **Wrap unified installer as Mix task**:
   ```elixir
   defmodule Mix.Tasks.Unified.Install do
     use Mix.Task
     @shortdoc "Runs unified installation"

     def run(args) do
       # Call unified-4.exs from scripts/installation/
     end
   end
   ```

2. **Use Mix config for unified settings**
3. **Integrate with Mix releases for deployment**

## 📁 Directory Structure Compliance

### Before Creating Any File
Ask yourself:
1. Is this documentation? → `docs/`
2. Is this a test? → `test/`
3. Is this a recurring task? → `lib/mix/tasks/`
4. Is this a one-time script? → `scripts/`
5. Is this application code? → `lib/indrajaal/`
6. Is this web-related? → `lib/indrajaal_web/`

### Standard Paths
```elixir
# Use these helper functions
defmodule Indrajaal.Paths do
  def docs_path, do: Path.join(File.cwd!(), "docs")
  def scripts_path, do: Path.join(File.cwd!(), "scripts")
  def logs_path, do: Path.join(File.cwd!(), "logs")
  def test_results_path, do: Path.join(File.cwd!(), "test_results")
end
```

## 🚫 What NOT to Do

1. **DON'T create .exs files in root** - Use proper directories
2. **DON'T write logs to root** - Use `logs/`
3. **DON'T create backup files everywhere** - Use `backups/`
4. **DON'T duplicate functionality** - Check for existing Mix tasks
5. **DON'T hardcode paths** - Use configuration

## ✅ Cleanup Checklist

When working on the project:
- [ ] Check for files in wrong locations
- [ ] Move misplaced files to correct directories
- [ ] Convert repeated scripts to Mix tasks
- [ ] Update paths in existing scripts
- [ ] Clean up execution artifacts
- [ ] Update documentation references
- [ ] Verify `.gitignore` covers artifacts

## 🔄 Continuous Maintenance

### After Each Session
1. Run cleanup check: `mix project.clean --check`
2. Move any new files to proper locations
3. Update journal in `docs/journal/`
4. Commit only source files, not artifacts

### Weekly Maintenance
1. Archive old logs: `mix logs.archive`
2. Clean test results: `mix test.clean`
3. Review and organize scripts
4. Update documentation

## 📝 Documentation Update Protocol

When changing code:
1. Update relevant `CLAUDE-*.md` files
2. Update `docs/PROJECT_STATUS.md`
3. Add entry to `docs/journal/YYYY-MM-DD.md`
4. Update `README.md` if user-facing changes

## 🎯 Goal

Maintain a clean, organized Mix project structure that:
- Follows Elixir/Mix conventions
- Keeps root directory minimal
- Organizes artifacts properly
- Integrates all tools with Mix
- Maintains clear documentation

Remember: **Organization is not optional - it's mandatory for maintainability!**