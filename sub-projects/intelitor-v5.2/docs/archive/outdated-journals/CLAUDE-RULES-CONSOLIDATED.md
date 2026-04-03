# Consolidated CLAUDE Rules - Post-Cleanup

## 🎯 Core Principles (MANDATORY)

### 1. Project Structure Rules
- **NEVER create files in root directory** except:
  - `README.md`, `mix.exs`, `.formatter.exs`, `.credo.exs`, `.gitignore`, `devenv.nix`
- **ALWAYS use proper directories**:
  - Code → `lib/`
  - Tests → `test/`
  - Documentation → `docs/`
  - Scripts → `scripts/` or `lib/mix/tasks/`
  - Web → `lib/indrajaal_web/`

### 2. Mix Integration Rules
- **Use Mix tasks for ALL recurring operations**
- **Available Mix tasks**:
  ```bash
  mix setup              # Project setup
  mix test.coverage      # Test with coverage
  mix project.analyze    # Code analysis
  mix unified.install    # Run installer
  mix docs              # Generate docs
  ```
- **Create new Mix tasks** in `lib/mix/tasks/` for any repeated operation

### 3. Testing Rules
- **ALL tests use Mix test framework**:
  ```bash
  mix test                    # Run all tests
  mix test.coverage --html    # Coverage report
  mix test --only tag_name    # Run tagged tests
  ```
- **Test file locations**:
  - Unit tests → `test/indrajaal/domain_name/`
  - Integration → `test/integration/`
  - Web tests → `test/indrajaal_web/`

### 4. Documentation Rules
- **Documentation location**: `docs/`
  - Guides → `docs/guides/`
  - Journal → `docs/journal/`
  - Archive → `docs/archive/`
- **Only README.md stays in root**
- **Update docs when code changes**

### 5. Script Management Rules
- **Utility scripts** → `scripts/category/`
  - Setup → `scripts/setup/`
  - Testing → `scripts/testing/`
  - Maintenance → `scripts/maintenance/`
- **Convert frequently-used scripts to Mix tasks**
- **Archive unused scripts**

### 6. Code Quality Rules
- **Zero tolerance for warnings** - All warnings are errors
- **Must pass ALL quality checks**:
  ```bash
  mix format --check-formatted
  mix credo --strict
  mix dialyzer
  mix sobelow
  ```
- **Minimum 80% test coverage** (target 100%)

### 7. Development Workflow Rules
- **Start with**: `mix setup`
- **Develop with**: `iex -S mix` or `mix phx.server`
- **Test with**: `mix test.coverage`
- **Analyze with**: `mix project.analyze`
- **Document with**: `mix docs`

### 8. File Creation Checklist
Before creating ANY file, ask:
1. Is this a test? → `test/`
2. Is this documentation? → `docs/`
3. Is this a recurring task? → `lib/mix/tasks/`
4. Is this a utility script? → `scripts/`
5. Is this core logic? → `lib/indrajaal/`
6. Is this web-related? → `lib/indrajaal_web/`

### 9. Cleanup Maintenance Rules
- **Daily**: Keep root clean, use proper directories
- **Weekly**: Run `mix project.analyze`
- **Monthly**: Archive unused scripts, clean logs
- **Always**: Follow Mix conventions

### 10. Integration Rules
- **unified-4.exs** → Access via `mix unified.install`
- **All paths** → Use Mix project structure
- **Dependencies** → Manage via `mix.exs` only
- **Configuration** → Use `config/` directory

## 🚫 What NOT to Do

1. **DON'T** create .exs files in root
2. **DON'T** use standalone scripts for tests
3. **DON'T** hardcode paths
4. **DON'T** bypass Mix for dependency management
5. **DON'T** ignore compiler warnings
6. **DON'T** create docs outside of `docs/`
7. **DON'T** write logs/artifacts to root

## ✅ Quick Reference

### Common Commands
```bash
# Development
mix setup                  # Initial setup
iex -S mix phx.server     # Start with shell
mix test.coverage         # Run tests

# Analysis
mix project.analyze       # Full analysis
mix credo --strict       # Code quality
mix dialyzer            # Type checking

# Documentation
mix docs                # Generate docs
```

### Directory Map
```
indrajaal/
├── config/          # App configuration
├── lib/            # Application code
│   ├── indrajaal/  # Core logic
│   ├── indrajaal_web/ # Web layer
│   └── mix/tasks/  # Mix tasks
├── test/           # All tests
├── docs/           # All documentation
├── scripts/        # Utility scripts
└── priv/           # Private files
```

## 📏 Enforcement

These rules are **MANDATORY** and enforced by:
- Compiler warnings as errors
- Credo strict mode
- Code review requirements
- CI/CD pipeline checks

**Remember**: Organization and quality are not optional - they are requirements for a maintainable, production-ready system.