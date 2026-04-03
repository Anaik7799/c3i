# Indrajaal Project Cleanup Checklist

## 🗑️ Immediate Deletions

### BEAM Files (8 files - should not be in root)
```bash
rm *.beam
```
- [ ] Elixir.AshDomainAnalyzer.beam
- [ ] Elixir.AshDomainGenerator.beam
- [ ] Elixir.DomainTracker.beam
- [ ] Elixir.Indrajaal.Auth.LocalAuthentication.beam
- [ ] Elixir.LocalAuthSummary.beam
- [ ] Elixir.ProjectJournal.Entry.beam
- [ ] Elixir.ProjectJournal.Progress.beam
- [ ] Elixir.ProjectJournal.beam

### Crash Dumps
```bash
rm erl_crash.dump
```
- [ ] erl_crash.dump

## 📁 File Relocations

### Documentation → `docs/`
```bash
mkdir -p docs/{guides,journal,archive}
mv CLAUDE*.md docs/guides/
mv ash_implementation_journal.md docs/journal/
mv compilation_analysis.md docs/archive/
mv rca-clean.md docs/archive/
mv PROJECT_CLEANUP_ACTION_PLAN.md docs/
```
- [ ] CLAUDE.md → docs/guides/
- [ ] CLAUDE-CODEGEN.md → docs/guides/
- [ ] CLAUDE-DEPLOYMENT.md → docs/guides/
- [ ] CLAUDE-DEVELOPMENT.md → docs/guides/
- [ ] CLAUDE-TESTING.md → docs/guides/
- [ ] CLAUDE_CLEANUP_RULES.md → docs/guides/
- [ ] PROJECT_CLEANUP_ACTION_PLAN.md → docs/
- [ ] ash_implementation_journal.md → docs/journal/
- [ ] compilation_analysis.md → docs/archive/
- [ ] rca-clean.md → docs/archive/

### Scripts → Organized Directories
```bash
mkdir -p scripts/{setup,testing,analysis,maintenance,installation}
```

#### Setup Scripts → `scripts/setup/`
- [ ] initialize_mix_project.exs
- [ ] setup_local_auth_db.exs
- [ ] setup_test_infrastructure.exs

#### Testing Scripts → `scripts/testing/`
- [ ] test_local_auth.exs
- [ ] test_coverage_analysis.exs
- [ ] test_coverage_journal.exs
- [ ] test_coverage_summary.exs
- [ ] comprehensive_test_plan.exs

#### Analysis Scripts → `scripts/analysis/`
- [ ] ash_domain_analyzer.exs
- [ ] rca_warnings_analysis.exs
- [ ] project_cleanup_rca_and_plan.exs
- [ ] local_auth_summary.exs

#### Maintenance Scripts → `scripts/maintenance/`
- [ ] fix_warnings.exs
- [ ] update_journal_progress.exs
- [ ] update_journal_rca.exs
- [ ] update_journal_test_plan.exs
- [ ] update_test_journal.exs
- [ ] update_unified_for_local_auth.exs

#### Installation → `scripts/installation/`
- [ ] unified-4.exs

#### Project Journal → `scripts/maintenance/`
- [ ] project_journal.exs

### Data Files → `data/`
```bash
mkdir -p data/analysis
mv *.json data/analysis/
```
- [ ] ash_domain_analysis.json → data/analysis/
- [ ] ash_implementation_progress.json → data/analysis/

### Archive → `docs/archive/`
```bash
mv build-instructions-v1.txt docs/archive/
```
- [ ] build-instructions-v1.txt → docs/archive/

## 🔧 Mix Task Conversions

Create Mix tasks to replace frequently used scripts:

### High Priority (Used Often)
- [ ] `mix setup` - Replace initialize_mix_project.exs
- [ ] `mix test.coverage` - Replace test_coverage_*.exs scripts
- [ ] `mix project.analyze` - Replace ash_domain_analyzer.exs
- [ ] `mix unified.install` - Wrapper for unified-4.exs

### Medium Priority (Occasional Use)
- [ ] `mix project.journal` - Replace project_journal.exs
- [ ] `mix auth.setup` - Replace setup_local_auth_db.exs
- [ ] `mix project.rca` - Replace rca_*.exs scripts

## 📝 Documentation Updates

### Update Paths in Moved Documentation
- [ ] Update CLAUDE.md with new script locations
- [ ] Update CLAUDE-TESTING.md to reference mix test
- [ ] Update CLAUDE-DEVELOPMENT.md for Mix workflow
- [ ] Update all script references to use new paths

### Create New Documentation
- [ ] Create README.md with project overview
- [ ] Create docs/README.md with documentation index
- [ ] Create scripts/README.md explaining script organization

## 🚀 Final Cleanup Actions

### Update .gitignore
```gitignore
# Add these entries
*.beam
erl_crash.dump
/data/
/logs/
/test_results/
/backups/
```

### Create Directory Structure README
```bash
tree -d -L 3 > docs/FOLDER_STRUCTURE.md
```

### Verify Clean Root
After cleanup, root should only contain:
- [ ] README.md
- [ ] mix.exs
- [ ] mix.lock
- [ ] .formatter.exs
- [ ] .credo.exs
- [ ] .gitignore
- [ ] .sobelow-conf
- [ ] devenv.nix
- [ ] config/ (directory)
- [ ] lib/ (directory)
- [ ] test/ (directory)
- [ ] priv/ (directory)
- [ ] deps/ (directory)
- [ ] _build/ (directory)

## 📊 Cleanup Metrics

Before Cleanup:
- Root files: 45
- BEAM files in root: 8
- Scripts in root: 20
- Docs in root: 10

After Cleanup Target:
- Root files: <10 (only essential config)
- BEAM files in root: 0
- Scripts in root: 0
- Docs in root: 1 (README.md only)

## ✅ Verification Steps

1. [ ] Run `ls -la` and verify clean root
2. [ ] Run `mix compile --warnings-as-errors`
3. [ ] Run `mix test` to ensure nothing broken
4. [ ] Run `mix docs` to generate documentation
5. [ ] Verify all Mix tasks work
6. [ ] Update git with new structure

## 🎯 Success Criteria

- Clean, organized root directory
- All scripts categorized and accessible
- Documentation properly organized
- Mix tasks for common operations
- No compilation artifacts in root
- Clear project structure for new developers