# STAMP/TDG/GDE Mix Tasks Reference

Complete reference for all Mix tasks added by the STAMP/TDG/GDE enhancement.

---

## STAMP Tasks

### mix stamp.stpa
Perform System-Theoretic Process Analysis on a feature or domain.

```bash
mix stamp.stpa --domain access_control
mix stamp.stpa --feature user_authentication --init
mix stamp.stpa --feature payment_processing --generate-requirements
```

**Options:**
- `--domain` - Analyze an entire domain
- `--feature` - Analyze a specific feature
- `--init` - Initialize new STPA analysis
- `--generate-requirements` - Generate safety requirements from analysis
- `--export` - Export analysis results (json, md, pdf)

### mix stamp.cast
Conduct Causal Analysis based on STAMP for incidents.

```bash
mix stamp.cast --incident INC-12345
mix stamp.cast --emergency --incident INC-99999
mix stamp.cast --review INC-12345
```

**Options:**
- `--incident` - Incident ID to investigate
- `--emergency` - Fast-track emergency investigation
- `--review` - Review previous CAST analysis
- `--export` - Export investigation report

### mix stamp.validate
Validate STAMP compliance across codebase.

```bash
mix stamp.validate
mix stamp.validate --domain billing
mix stamp.validate --comprehensive
mix stamp.validate --fix
```

**Options:**
- `--domain` - Validate specific domain
- `--comprehensive` - Full system validation
- `--fix` - Attempt automatic fixes
- `--report` - Generate compliance report

### mix stamp.monitor
Real-time STAMP compliance monitoring.

```bash
mix stamp.monitor
mix stamp.monitor --dashboard
mix stamp.monitor --alerts-only
```

---

## TDG Tasks

### mix tdg.validate
Validate Test-Driven Generation compliance.

```bash
mix tdg.validate --pre-generation
mix tdg.validate --post-generation
mix tdg.validate --module MyApp.Feature
mix tdg.validate --comprehensive
```

**Options:**
- `--pre-generation` - Check tests exist before implementation
- `--post-generation` - Verify all code is tested
- `--module` - Check specific module
- `--comprehensive` - Full codebase validation
- `--fix` - Generate missing tests

### mix tdg.coverage
Analyze and report TDG coverage metrics.

```bash
mix tdg.coverage
mix tdg.coverage --watch
mix tdg.coverage --threshold 95
mix tdg.coverage --by-domain
```

**Options:**
- `--watch` - Real-time coverage monitoring
- `--threshold` - Set minimum coverage requirement
- `--by-domain` - Group coverage by domain
- `--export` - Export coverage report

### mix tdg.generate
Generate test templates from specifications.

```bash
mix tdg.generate --from-spec specs/feature.md
mix tdg.generate --from-stpa results/analysis.json
mix tdg.generate --property-based
```

**Options:**
- `--from-spec` - Generate from specification file
- `--from-stpa` - Generate from STPA analysis
- `--property-based` - Include property tests
- `--dual-strategy` - Use both PropCheck and ExUnitProperties

### mix tdg.enforce
Configure and manage TDG enforcement.

```bash
mix tdg.enforce --enable
mix tdg.enforce --git-hooks install
mix tdg.enforce --ci-cd configure
```

---

## GDE Tasks

### mix gde.define
Define new goals with measurable targets.

```bash
mix gde.define --name "reduce_response_time" --target "< 50ms" --deadline "2025-09-01"
mix gde.define --interactive
mix gde.define --from-file goals.json
```

**Options:**
- `--name` - Goal identifier
- `--target` - Measurable target value
- `--deadline` - Achievement deadline
- `--priority` - Goal priority (critical, high, medium, low)
- `--team` - Assign to team
- `--interactive` - Interactive goal definition

### mix gde.track
Track progress toward goals.

```bash
mix gde.track --name "reduce_response_time" --value 65
mix gde.track --bulk updates.csv
mix gde.track --auto
```

**Options:**
- `--name` - Goal to update
- `--value` - Current value
- `--bulk` - Bulk update from file
- `--auto` - Automatic tracking from metrics

### mix gde.progress
View goal progress and predictions.

```bash
mix gde.progress
mix gde.progress --goal "reduce_response_time"
mix gde.progress --dashboard
mix gde.progress --at-risk
```

**Options:**
- `--goal` - Specific goal progress
- `--dashboard` - Open web dashboard
- `--at-risk` - Show only at-risk goals
- `--export` - Export progress report

### mix gde.intervene
Manage automated interventions.

```bash
mix gde.intervene --list
mix gde.intervene --trigger "scale_resources"
mix gde.intervene --disable "aggressive_caching"
```

---

## Combined Tasks

### mix stamp.tdg.gde
Unified commands for all three systems.

```bash
mix stamp.tdg.gde validate
mix stamp.tdg.gde report
mix stamp.tdg.gde dashboard
```

### mix health.check
Combined health check for all systems.

```bash
mix health.check --stamp --tdg --gde
mix health.check --comprehensive
mix health.check --quick
```

### mix compliance.report
Generate comprehensive compliance report.

```bash
mix compliance.report
mix compliance.report --format pdf
mix compliance.report --period "last-month"
```

---

## Dashboard Tasks

### mix telemetry.dashboard
Launch the unified monitoring dashboard.

```bash
mix telemetry.dashboard
mix telemetry.dashboard --port 4001
mix telemetry.dashboard --read-only
```

### mix alerts.status
View current alert status.

```bash
mix alerts.status
mix alerts.status --critical
mix alerts.status --acknowledge ALERT-123
```

---

## Training and Help

### mix learn.stamp
Interactive STAMP tutorial.

```bash
mix learn.stamp
mix learn.stamp --advanced
```

### mix learn.tdg
TDG hands-on exercises.

```bash
mix learn.tdg
mix learn.tdg --challenge
```

### mix learn.gde
Goal setting workshop.

```bash
mix learn.gde
mix learn.gde --examples
```

### mix stamp.tdg.gde.help
Comprehensive help system.

```bash
mix stamp.tdg.gde.help
mix stamp.tdg.gde.help --topic stpa
mix stamp.tdg.gde.help --search "safety constraints"
```

---

## Configuration Tasks

### mix config.stamp.tdg.gde
Configure all systems.

```bash
mix config.stamp.tdg.gde --interactive
mix config.stamp.tdg.gde --export
mix config.stamp.tdg.gde --validate
```

---

## CI/CD Integration

These tasks are designed for CI/CD pipelines:

```bash
# Pre-commit
mix tdg.validate --pre-generation --fail-fast

# CI Build
mix stamp.validate --comprehensive --junit-output
mix tdg.coverage --threshold 95 --fail-under

# Pre-deployment
mix health.check --stamp --tdg --gde --required

# Post-deployment
mix gde.progress --verify-deployment
```

---

## Environment Variables

Configure behavior via environment variables:

```bash
STAMP_COMPLIANCE_THRESHOLD=95
TDG_COVERAGE_MINIMUM=98
GDE_INTERVENTION_AUTO=true
STAMP_TDG_GDE_VERBOSE=true
```

---

## Examples

### Daily Developer Workflow
```bash
# Morning
mix gde.progress --my-goals
mix stamp.validate --my-changes

# Before coding
mix tdg.validate --pre-generation

# After coding
mix tdg.validate --post-generation
mix stamp.validate --comprehensive

# End of day
mix gde.track --my-goals
mix compliance.report --today
```

### Team Lead Workflow
```bash
# Team status
mix gde.progress --team
mix tdg.coverage --by-developer
mix stamp.monitor --dashboard

# Planning
mix gde.define --team-goals
mix stamp.stpa --upcoming-features
```

### Emergency Response
```bash
# Incident occurs
mix stamp.cast --emergency --incident INC-99999
mix health.check --comprehensive
mix alerts.status --critical

# Recovery
mix gde.intervene --emergency-scale
mix compliance.report --incident INC-99999
```

---

For more information on any task, use:
```bash
mix help <task.name>
```

Or visit the full documentation at `/docs/stamp_tdg_gde/`