# Project Cleanup Action Plan

## Executive Summary

This plan outlines the systematic cleanup and reorganization of the Indrajaal project to align with Mix project conventions and establish maintainable structure.

## Current State Analysis

### Files in Root Directory (TO BE MOVED)
```
Root directory cluttered with 30+ .exs files:
- Setup scripts (setup_*.exs)
- Test scripts (test_*.exs)
- Update scripts (update_*.exs)
- Analysis scripts (*_analyzer.exs, *_rca.exs)
- Execution artifacts (*.json)
- Documentation files (CLAUDE-*.md)
```

### Issues Identified (5-Level RCA)
1. **Disorganized Structure**: Scripts scattered without categorization
2. **No Mix Integration**: Standalone scripts instead of Mix tasks
3. **Documentation Misalignment**: Docs reference old structure
4. **Artifact Accumulation**: Runtime outputs in root
5. **unified-4.exs Isolation**: Not integrated with Mix

## Phase-by-Phase Cleanup Plan

### Phase 1: Directory Structure (Day 1)
```bash
# Create organized structure
mkdir -p docs/{journal,archive,test_reports}
mkdir -p scripts/{setup,testing,maintenance,installation,archive}
mkdir -p lib/mix/tasks/{project,test,docs}
mkdir -p logs
mkdir -p test_results
mkdir -p backups
```

### Phase 2: File Organization (Day 1-2)

#### Documentation Files
```bash
# Move all CLAUDE-*.md to docs/
mv CLAUDE-*.md docs/

# Keep only README.md in root
echo "See docs/ for all documentation" >> README.md
```

#### Script Organization
```bash
# Setup scripts
mv setup_*.exs scripts/setup/

# Test scripts
mv test_*.exs scripts/testing/

# Analysis scripts
mv *_analyzer.exs scripts/maintenance/
mv *_rca.exs scripts/maintenance/

# Update scripts
mv update_*.exs scripts/maintenance/

# Installation
mv unified-4.exs scripts/installation/

# Backup old scripts
mv *.exs.backup backups/
```

#### Artifacts Cleanup
```bash
# Move JSON artifacts
mv *.json test_results/

# Move logs
mv *.log logs/

# Clean tmp
rm -rf tmp/
```

### Phase 3: Mix Task Creation (Day 2-3)

#### Core Mix Tasks to Create

**1. Mix.Tasks.Setup**
```elixir
defmodule Mix.Tasks.Setup do
  use Mix.Task
  @shortdoc "Complete project setup"

  def run(_) do
    Mix.Task.run("deps.get")
    Mix.Task.run("ecto.create")
    Mix.Task.run("ecto.migrate")
    # Additional setup
  end
end
```

**2. Mix.Tasks.Test.Coverage**
```elixir
defmodule Mix.Tasks.Test.Coverage do
  use Mix.Task
  @shortdoc "Run tests with full coverage analysis"

  def run(args) do
    Mix.Task.run("test", ["--cover" | args])
    # Generate coverage report
  end
end
```

**3. Mix.Tasks.Project.Analyze**
```elixir
defmodule Mix.Tasks.Project.Analyze do
  use Mix.Task
  @shortdoc "Analyze project structure and quality"

  def run(_) do
    # Run analysis from scripts
  end
end
```

**4. Mix.Tasks.Unified.Install**
```elixir
defmodule Mix.Tasks.Unified.Install do
  use Mix.Task
  @shortdoc "Run unified installer"

  def run(args) do
    # Execute unified-4.exs with args
  end
end
```

### Phase 4: Documentation Updates (Day 3-4)

#### Update Each CLAUDE-*.md File

**CLAUDE.md Updates:**
- Change all script references to Mix tasks
- Update file paths to new structure
- Add Mix conventions section
- Include cleanup rules

**CLAUDE-CODEGEN.md Updates:**
- Update generation paths to lib/
- Add Mix module conventions
- Update test generation paths

**CLAUDE-TESTING.md Updates:**
- Replace script commands with mix test
- Update coverage commands
- Add ExUnit patterns

**CLAUDE-DEPLOYMENT.md Updates:**
- Use Mix releases
- Update Docker for Mix
- Add systemd examples

**CLAUDE-DEVELOPMENT.md Updates:**
- Update for Mix/devenv.sh
- Add iex -S mix usage
- Include Mix aliases

### Phase 5: Integration & Validation (Day 4-5)

#### unified-4.exs Integration
1. Update paths in unified-4.exs
2. Create Mix wrapper task
3. Test installation flow
4. Update TUI for Mix paths

#### Validation Steps
```bash
# Test all Mix tasks
mix setup
mix test.coverage
mix project.analyze
mix unified.install

# Verify documentation
mix docs

# Clean check
mix project.clean --check
```

#### Update Configuration Files

**.gitignore additions:**
```
/logs
/test_results
/backups
*.log
*.json
/tmp
```

**mix.exs aliases:**
```elixir
defp aliases do
  [
    setup: ["deps.get", "ecto.setup"],
    "test.all": ["test", "credo --strict", "dialyzer"],
    clean: ["project.clean", "logs.clean"],
    analyze: ["project.analyze", "test.coverage"]
  ]
end
```

## Success Criteria

### Clean Root Directory
Only these files in root:
- README.md
- mix.exs
- .formatter.exs
- .credo.exs
- .gitignore
- .tool-versions (if needed)

### Organized Structure
- All docs in `docs/`
- All scripts in `scripts/` or Mix tasks
- All tests in `test/`
- No loose .exs files

### Mix Integration
- Common tasks as Mix tasks
- Unified installer integrated
- All paths use Mix project structure

### Updated Documentation
- All CLAUDE-*.md files updated
- README.md reflects new structure
- Journal tracking in docs/journal/

## Maintenance Going Forward

### Daily
- Keep root clean
- Use proper directories
- Run `mix project.clean --check`

### Weekly
- Archive old logs
- Clean test results
- Review scripts folder

### Monthly
- Audit file organization
- Update documentation
- Archive unused scripts

## Benefits

1. **Clean Structure**: Easy navigation
2. **Mix Integration**: Standard Elixir workflow
3. **Maintainability**: Clear organization
4. **Documentation**: Always current
5. **Automation**: Mix tasks for everything

## Timeline

- **Day 1**: Create directories, basic file moves
- **Day 2**: Complete file organization, start Mix tasks
- **Day 3**: Finish Mix tasks, start doc updates
- **Day 4**: Complete doc updates, integrate unified
- **Day 5**: Validation, testing, final cleanup

Total effort: 5 days for complete transformation

## Conclusion

This cleanup will transform the project from a collection of scripts to a properly organized Mix project, improving maintainability, discoverability, and adherence to Elixir conventions.