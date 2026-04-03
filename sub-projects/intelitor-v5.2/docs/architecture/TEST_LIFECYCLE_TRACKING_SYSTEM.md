# Indrajaal Unified Test Lifecycle Tracking System (UTLTS)

**Version**: 1.0.0 | **Date**: 2026-03-09 | **Status**: DESIGN
**Author**: Claude Opus 4.6 | **Sprint**: 47
**Compliance**: IEC 61508 SIL-6, SC-ZTEST-*, SC-COV-*, AOR-TEST-*
**Database**: SQLite (WAL mode) — Single portable artifact

---

## 0. Executive Summary

The Unified Test Lifecycle Tracking System (UTLTS) consolidates all test execution data across
**Elixir** (977 test files), **F#** (69 test files), **Rust** (6 NIF source files), and
**1,560 scripts** into a single SQLite database (`data/holons/test/utlts.db`).

### Why SQLite?
- **Portable**: Single file, zero-config, CI/CD artifact-friendly
- **Queryable**: Full SQL for flaky test detection, trend analysis, log correlation
- **Proven**: Used by pytest-monitor, testres-db, and internally by test_tracking.db
- **Aligned**: Consistent with Ω₇ (Holon State Sovereignty — SQLite is authoritative)
- **Performant**: WAL mode handles concurrent test writers without locks

### Current State (Fragmented)
| System | Location | Tables | Limitation |
|--------|----------|--------|------------|
| test_tracking.db | backups/kms/ | 3 | Basic, no log refs, no language coverage |
| test_manager.db | backups/kms/ | 6 | Better schema but unused in CI path |
| test_evolution_*.db | data/ | 1 | AI-only, evolution events |
| ZenohTestOrchestrator | in-memory | 0 (GenServer) | Ephemeral, lost on restart |
| KMS log_test_result.exs | data/kms/ | 0 (JSONL) | Append-only, no SQL queries |
| DuckDB analytics | data/kms/ | N/A | Analytics, not test lifecycle |

### Target State (Unified)
One `utlts.db` file with 14 tables covering the complete test lifecycle from definition
through execution to analytics, with log references, coverage tracking, flaky detection,
and CI/CD artifact integration.

---

## 1. Requirements

### 1.1 Functional Requirements

| ID | Requirement | Priority | Source |
|----|-------------|----------|--------|
| FR-001 | Track ALL test runs across Elixir, F#, Rust, and scripts | P0 | Core |
| FR-002 | Store individual test case results with pass/fail/skip/error status | P0 | Core |
| FR-003 | Link test results to log files and Zenoh checkpoint messages | P0 | SC-ZTEST-008 |
| FR-004 | Track code coverage per module, file, and function | P0 | SC-COV-001 |
| FR-005 | Detect flaky tests via flip-rate analysis across runs | P0 | Analytics |
| FR-006 | Store performance metrics (CPU, memory, duration) per test | P1 | pytest-monitor |
| FR-007 | Track test suites and their hierarchical organization | P0 | Core |
| FR-008 | Support querying historical trends (duration regression, failure patterns) | P0 | Analytics |
| FR-009 | Store STAMP constraint mappings per test | P1 | SC-COV-006 |
| FR-010 | Track Git context (commit, branch, diff) per test run | P0 | Traceability |
| FR-011 | Support concurrent writes from parallel test execution | P0 | SC-METRICS-003 |
| FR-012 | Store test definitions separately from executions | P0 | TestRail pattern |
| FR-013 | Track test environment (OS, runtime versions, container state) | P1 | Reproducibility |
| FR-014 | Provide CI/CD artifact export (single .db file) | P0 | Portability |
| FR-015 | Track property test (PropCheck/FsCheck) generation data | P1 | Ω₄ TDG |
| FR-016 | Store fractal layer (L0-L7) classification per test | P1 | Fractal arch |
| FR-017 | Track test evolution and AI-generated test fitness | P2 | SC-GDE-* |
| FR-018 | Store F# Expecto test results alongside Elixir ExUnit results | P0 | Multi-runtime |
| FR-019 | Track Rust cargo test results from NIF compilation | P0 | Multi-runtime |
| FR-020 | Store script execution results (1,560 .exs/.fsx scripts) | P0 | Multi-runtime |
| FR-021 | Support DuckDB export for heavy analytics queries | P2 | AOR-HOLON-007 |
| FR-022 | Track test dependencies and prerequisite chains | P2 | DAG analysis |
| FR-023 | Store FMEA RPN scores linked to test coverage | P1 | SC-BDD-008 |
| FR-024 | Provide Zenoh topic publishing of key events | P1 | SC-ZTEST-* |
| FR-025 | Track compilation status as test prerequisite | P0 | SC-FUNC-001 |

### 1.2 Non-Functional Requirements

| ID | Requirement | Target | Constraint |
|----|-------------|--------|------------|
| NFR-001 | Write latency per test result | < 1ms | WAL mode |
| NFR-002 | Concurrent writer support | 16 threads | WAL + busy_timeout |
| NFR-003 | Database size per 10K test runs | < 50MB | Normalized schema |
| NFR-004 | Query latency (recent 100 runs) | < 10ms | Indexed |
| NFR-005 | Flaky detection query | < 100ms | Materialized view |
| NFR-006 | CI artifact upload size | < 100MB | Compacted |
| NFR-007 | Data retention | 365 days | Configurable purge |
| NFR-008 | Schema migration support | Forward compatible | Version table |

---

## 2. Industry Reference Systems

### 2.1 Systems Analyzed

| System | Schema Model | Storage | Key Innovation |
|--------|-------------|---------|----------------|
| **testres-db** | TestSuite→TestCase→TestLog | SQLite | CLI importer for JUnit XML/Cucumber JSON |
| **pytest-monitor** | TEST_SESSIONS + TEST_METRICS | SQLite (.pymon) | CPU/memory/kernel time per test |
| **pytest-history** | .test-results.db | SQLite | Flip-rate flaky detection, SQL queries |
| **Allure** | Suite→Test→Step→Attachment | JSON+SQL | Rich reporting, historical trends |
| **TestRail** | Suite→Section→Case→Run→Result | PostgreSQL | Enterprise test management lifecycle |
| **Zephyr Scale** | TestCase→TestCycle→TestExecution | PostgreSQL | Jira integration, traceability |
| **ReportPortal** | Launch→Suite→Test→Log | PostgreSQL | Real-time reporting, ML-based analysis |
| **Azure DevOps** | TestPlan→TestSuite→TestPoint→TestRun→TestResult | SQL Server | 15 outcome states, CI/CD native |
| **Atlassian Flakinator** | TestExecution history | Internal | Bayesian flaky detection, flip-rate EWMA |
| **BuildPulse** | Test execution history | SaaS | Automated quarantine, ownership tracking |

### 2.2 Key Patterns Adopted

| Pattern | Source | Adoption |
|---------|--------|----------|
| Separate definitions from executions | TestRail, Azure DevOps | `test_definitions` vs `test_results` |
| Flip-rate for flaky detection | Atlassian Flakinator, pytest-history | `flaky_analysis` view |
| Resource metrics per test | pytest-monitor | `test_metrics` table |
| Log correlation via trace_id | ReportPortal, test_manager.db | `test_logs` table |
| Environment fingerprinting | pytest-monitor (TEST_SESSIONS) | `test_environments` table |
| STAMP/Safety constraint mapping | Indrajaal-specific | `test_constraints` table |
| Fractal layer classification | Indrajaal-specific | `fractal_layer` column |
| Multi-runtime support | Novel | `runtime` column (elixir/fsharp/rust/script) |

---

## 3. Schema Design (14 Tables)

### 3.0 Configuration

```sql
-- UTLTS Schema v1.0.0
-- SQLite WAL mode for concurrent access
PRAGMA journal_mode = WAL;
PRAGMA busy_timeout = 5000;
PRAGMA foreign_keys = ON;
PRAGMA synchronous = NORMAL;
PRAGMA cache_size = -64000; -- 64MB cache
```

### 3.1 Entity-Relationship Diagram

```
┌─────────────────────┐     ┌────────────────────┐     ┌──────────────────────┐
│  schema_versions    │     │  test_environments │     │  test_projects       │
│  (migration track)  │     │  (env fingerprint) │     │  (runtime grouping)  │
└─────────────────────┘     └────────┬───────────┘     └──────────┬───────────┘
                                     │                            │
                            ┌────────┴───────────┐               │
                            │    test_runs       │◄──────────────┘
                            │  (execution batch) │
                            └────────┬───────────┘
                                     │
               ┌─────────────────────┼─────────────────────┐
               │                     │                     │
    ┌──────────┴──────────┐ ┌───────┴────────┐  ┌────────┴──────────┐
    │  test_suites        │ │ run_metrics    │  │  run_artifacts    │
    │  (logical grouping) │ │ (run-level)    │  │  (log files)      │
    └──────────┬──────────┘ └────────────────┘  └───────────────────┘
               │
    ┌──────────┴──────────┐
    │  test_definitions   │
    │  (test identity)    │
    └──────────┬──────────┘
               │
    ┌──────────┴──────────┐
    │  test_results       │─────────┐
    │  (per-run outcome)  │         │
    └──────────┬──────────┘         │
               │                    │
    ┌──────────┴──────┐   ┌────────┴──────────┐   ┌──────────────────┐
    │  test_metrics   │   │  test_logs        │   │ test_constraints │
    │  (perf data)    │   │  (log references) │   │ (STAMP mapping)  │
    └─────────────────┘   └───────────────────┘   └──────────────────┘

    ┌──────────────────┐   ┌──────────────────┐
    │  coverage_data   │   │  flaky_analysis  │
    │  (code coverage) │   │  (materialized)  │
    └──────────────────┘   └──────────────────┘
```

### 3.2 Table Definitions

#### Table 1: `schema_versions` — Migration tracking

```sql
CREATE TABLE IF NOT EXISTS schema_versions (
    version     TEXT PRIMARY KEY,          -- '1.0.0'
    applied_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    description TEXT
);

INSERT INTO schema_versions (version, description)
VALUES ('1.0.0', 'Initial UTLTS schema - 14 tables');
```

#### Table 2: `test_projects` — Runtime/language grouping

```sql
CREATE TABLE IF NOT EXISTS test_projects (
    id          TEXT PRIMARY KEY,          -- UUID
    name        TEXT NOT NULL UNIQUE,      -- 'indrajaal-elixir', 'cepaf-fsharp', 'zenoh-nif-rust'
    runtime     TEXT NOT NULL,             -- 'elixir' | 'fsharp' | 'rust' | 'script'
    framework   TEXT NOT NULL,             -- 'exunit' | 'expecto' | 'cargo_test' | 'elixir_script'
    root_path   TEXT NOT NULL,             -- 'test/' | 'lib/cepaf/test/' | 'native/zenoh_nif/'
    config      TEXT,                      -- JSON: framework-specific config
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Seed data for Indrajaal
INSERT OR IGNORE INTO test_projects (id, name, runtime, framework, root_path) VALUES
    ('proj-elixir-main',    'indrajaal-elixir',     'elixir',  'exunit',         'test/'),
    ('proj-fsharp-cepaf',   'cepaf-fsharp-tests',   'fsharp',  'expecto',        'lib/cepaf/test/Cepaf.Tests/'),
    ('proj-fsharp-indra',   'cepaf-indrajaal-tests', 'fsharp', 'expecto',        'lib/cepaf/test/Cepaf.IndrajaalTest/'),
    ('proj-rust-zenoh',     'zenoh-nif-rust',       'rust',    'cargo_test',     'native/zenoh_nif/'),
    ('proj-rust-lineage',   'lineage-auth-rust',    'rust',    'cargo_test',     'native/lineage_auth/'),
    ('proj-scripts-test',   'elixir-test-scripts',  'script',  'elixir_script',  'scripts/testing/'),
    ('proj-scripts-demo',   'elixir-demo-scripts',  'script',  'elixir_script',  'scripts/demo/'),
    ('proj-scripts-ga',     'ga-release-scripts',   'script',  'elixir_script',  'scripts/ga-release/'),
    ('proj-scripts-fsharp', 'fsharp-scripts',       'script',  'fsharp_script',  'lib/cepaf/scripts/');
```

#### Table 3: `test_environments` — Environment fingerprint

```sql
CREATE TABLE IF NOT EXISTS test_environments (
    id              TEXT PRIMARY KEY,      -- SHA-256 of fingerprint
    hostname        TEXT NOT NULL,
    os_name         TEXT NOT NULL,         -- 'Linux'
    os_version      TEXT,                  -- '6.17.0-14-generic'
    elixir_version  TEXT,                  -- '1.19.x'
    otp_version     TEXT,                  -- '28'
    dotnet_version  TEXT,                  -- '10.0.100'
    rust_version    TEXT,                  -- '1.8x'
    podman_version  TEXT,                  -- '5.4.1'
    cpu_count       INTEGER,              -- 16
    memory_mb       INTEGER,              -- Total RAM
    container_mode  TEXT,                  -- 'standalone' | 'fractal-cluster' | 'none'
    zenoh_enabled   INTEGER DEFAULT 0,    -- SKIP_ZENOH_NIF value (0=enabled)
    patient_mode    INTEGER DEFAULT 1,    -- PATIENT_MODE env
    env_vars        TEXT,                  -- JSON: relevant env vars
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX idx_env_hostname ON test_environments(hostname);
```

#### Table 4: `test_runs` — Execution batch (one per `mix test` / `dotnet test` / `cargo test`)

```sql
CREATE TABLE IF NOT EXISTS test_runs (
    id              TEXT PRIMARY KEY,      -- UUID
    project_id      TEXT NOT NULL,         -- FK → test_projects
    environment_id  TEXT,                  -- FK → test_environments
    run_type        TEXT NOT NULL,         -- 'unit' | 'integration' | 'property' | 'e2e' | 'smoke' | 'chaos' | 'soak' | 'demo' | 'ga_release'
    status          TEXT NOT NULL,         -- 'running' | 'passed' | 'failed' | 'errored' | 'cancelled'
    trigger         TEXT,                  -- 'manual' | 'ci' | 'pre_commit' | 'scheduled' | 'zenoh_orchestrator'

    -- Git context
    git_commit      TEXT,                  -- Full SHA
    git_branch      TEXT,                  -- Branch name
    git_dirty       INTEGER DEFAULT 0,    -- Uncommitted changes?
    git_message     TEXT,                  -- Commit message (first line)

    -- Timing
    started_at      TEXT NOT NULL,
    finished_at     TEXT,
    duration_ms     INTEGER,              -- Total wall time

    -- Aggregate stats
    total_tests     INTEGER DEFAULT 0,
    passed          INTEGER DEFAULT 0,
    failed          INTEGER DEFAULT 0,
    skipped         INTEGER DEFAULT 0,
    errored         INTEGER DEFAULT 0,

    -- Coverage
    line_coverage   REAL,                 -- 0.0 - 100.0
    branch_coverage REAL,
    function_coverage REAL,

    -- SIL-6 context
    sil_level       INTEGER,              -- 2 | 4 | 6
    fractal_mode    TEXT,                  -- 'standalone' | 'cluster' | 'federation'
    state_vector    TEXT,                  -- '[1,1,1,1,1,1]' (SC-ZTEST-006)

    -- Zenoh integration
    zenoh_session_id TEXT,                -- Zenoh session if connected
    checkpoint_id   TEXT,                  -- CP-TEST-* checkpoint ID

    -- Metadata
    tags            TEXT,                  -- JSON array: ['nightly', 'regression', 'sprint-47']
    config          TEXT,                  -- JSON: run configuration
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY(project_id) REFERENCES test_projects(id),
    FOREIGN KEY(environment_id) REFERENCES test_environments(id)
);

CREATE INDEX idx_runs_project     ON test_runs(project_id);
CREATE INDEX idx_runs_status      ON test_runs(status);
CREATE INDEX idx_runs_started     ON test_runs(started_at);
CREATE INDEX idx_runs_git_commit  ON test_runs(git_commit);
CREATE INDEX idx_runs_git_branch  ON test_runs(git_branch);
CREATE INDEX idx_runs_checkpoint  ON test_runs(checkpoint_id);
```

#### Table 5: `test_suites` — Logical grouping (module/namespace/category)

```sql
CREATE TABLE IF NOT EXISTS test_suites (
    id              TEXT PRIMARY KEY,      -- UUID
    project_id      TEXT NOT NULL,         -- FK → test_projects
    name            TEXT NOT NULL,         -- 'Indrajaal.Analytics.AlertCorrelationTest'
    file_path       TEXT NOT NULL,         -- 'test/indrajaal/analytics/alert_correlation_test.exs'
    runtime         TEXT NOT NULL,         -- 'elixir' | 'fsharp' | 'rust' | 'script'
    fractal_layer   TEXT,                  -- 'L0'..'L7'
    domain          TEXT,                  -- 'analytics' | 'mesh' | 'observability' | 'security' | ...
    category        TEXT,                  -- 'unit' | 'integration' | 'property' | 'bdd' | 'fmea' | 'tdg'
    line_count      INTEGER,              -- File line count
    test_count      INTEGER DEFAULT 0,    -- Number of tests in suite
    property_count  INTEGER DEFAULT 0,    -- Number of property tests
    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY(project_id) REFERENCES test_projects(id),
    UNIQUE(project_id, file_path)
);

CREATE INDEX idx_suites_project  ON test_suites(project_id);
CREATE INDEX idx_suites_runtime  ON test_suites(runtime);
CREATE INDEX idx_suites_layer    ON test_suites(fractal_layer);
CREATE INDEX idx_suites_domain   ON test_suites(domain);
CREATE INDEX idx_suites_category ON test_suites(category);
```

#### Table 6: `test_definitions` — Test identity (decoupled from results)

```sql
CREATE TABLE IF NOT EXISTS test_definitions (
    id              TEXT PRIMARY KEY,      -- UUID
    suite_id        TEXT NOT NULL,         -- FK → test_suites
    name            TEXT NOT NULL,         -- 'test calculates alert score correctly'
    full_name       TEXT NOT NULL,         -- 'Indrajaal.Analytics.AlertCorrelationTest.test calculates...'
    test_type       TEXT NOT NULL,         -- 'test' | 'property' | 'describe' | 'feature' | 'scenario'
    framework       TEXT NOT NULL,         -- 'exunit' | 'propcheck' | 'ex_unit_properties' | 'expecto' | 'fscheck' | 'cargo'
    tags            TEXT,                  -- JSON: ['@async', '@integration', '@wip']
    line_number     INTEGER,              -- Source line number

    -- Property test metadata
    property_generator TEXT,              -- 'PC.integer()' | 'SD.list_of(SD.atom())'
    property_num_tests INTEGER,           -- Number of generated cases

    -- STAMP/Safety
    stamp_constraints TEXT,               -- JSON: ['SC-COV-001', 'SC-ZTEST-005']
    fmea_rpn         INTEGER,             -- Risk Priority Number if FMEA-linked

    -- Classification
    fractal_layer   TEXT,                  -- 'L0'..'L7' (inherited from suite or overridden)
    criticality     TEXT,                  -- 'P0' | 'P1' | 'P2' | 'P3'

    first_seen_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    last_seen_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY(suite_id) REFERENCES test_suites(id),
    UNIQUE(suite_id, full_name)
);

CREATE INDEX idx_defs_suite     ON test_definitions(suite_id);
CREATE INDEX idx_defs_type      ON test_definitions(test_type);
CREATE INDEX idx_defs_framework ON test_definitions(framework);
CREATE INDEX idx_defs_layer     ON test_definitions(fractal_layer);
```

#### Table 7: `test_results` — Per-run outcome for each test

```sql
CREATE TABLE IF NOT EXISTS test_results (
    id              TEXT PRIMARY KEY,      -- UUID
    run_id          TEXT NOT NULL,         -- FK → test_runs
    definition_id   TEXT NOT NULL,         -- FK → test_definitions

    -- Outcome
    status          TEXT NOT NULL,         -- 'passed' | 'failed' | 'skipped' | 'errored' | 'excluded' | 'pending'
    duration_us     INTEGER,              -- Microseconds (ExUnit native unit)
    duration_ms     REAL GENERATED ALWAYS AS (CAST(duration_us AS REAL) / 1000.0) STORED,

    -- Failure details (SC-ZTEST-007: full context)
    failure_type    TEXT,                  -- 'assertion' | 'error' | 'timeout' | 'exit' | 'compile'
    failure_message TEXT,                  -- Error message
    failure_left    TEXT,                  -- Actual value (for assertions)
    failure_right   TEXT,                  -- Expected value
    stacktrace      TEXT,                  -- Full stacktrace

    -- Property test results
    num_generated   INTEGER,              -- Properties: how many cases generated
    num_shrinks     INTEGER,              -- Properties: shrink count on failure
    counterexample  TEXT,                  -- Properties: JSON counterexample

    -- Retry/Flaky tracking
    attempt         INTEGER DEFAULT 1,    -- Retry attempt number
    is_retry        INTEGER DEFAULT 0,    -- Was this a retry?
    previous_status TEXT,                  -- Status on previous attempt

    -- Assertions
    assertion_count INTEGER DEFAULT 0,

    -- Zenoh checkpoint
    checkpoint_id   TEXT,                  -- CP-TEST-TX-xx
    zenoh_topic     TEXT,                  -- Published Zenoh topic

    -- Timing
    started_at      TEXT,
    finished_at     TEXT,

    FOREIGN KEY(run_id) REFERENCES test_runs(id) ON DELETE CASCADE,
    FOREIGN KEY(definition_id) REFERENCES test_definitions(id)
);

CREATE INDEX idx_results_run    ON test_results(run_id);
CREATE INDEX idx_results_def    ON test_results(definition_id);
CREATE INDEX idx_results_status ON test_results(status);
CREATE INDEX idx_results_failed ON test_results(status) WHERE status = 'failed';
CREATE INDEX idx_results_timing ON test_results(duration_us);
```

#### Table 8: `test_metrics` — Performance measurements per test (pytest-monitor inspired)

```sql
CREATE TABLE IF NOT EXISTS test_metrics (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    result_id       TEXT NOT NULL,         -- FK → test_results

    -- Time metrics (pytest-monitor: TOTAL_TIME, USER_TIME, KERNEL_TIME)
    wall_time_us    INTEGER,              -- Wall clock time
    user_time_us    INTEGER,              -- User CPU time
    kernel_time_us  INTEGER,              -- Kernel/system CPU time
    cpu_percent     REAL,                  -- CPU usage % (100% = 1 core)

    -- Memory metrics (pytest-monitor: MEM_USAGE)
    memory_before_kb INTEGER,             -- Heap before test
    memory_after_kb  INTEGER,             -- Heap after test
    memory_peak_kb   INTEGER,             -- Peak memory during test
    memory_delta_kb  INTEGER GENERATED ALWAYS AS (memory_after_kb - memory_before_kb) STORED,

    -- Process metrics
    process_count   INTEGER,              -- BEAM processes (Elixir) or threads (F#/Rust)
    gc_count        INTEGER,              -- Garbage collections during test
    reductions      INTEGER,              -- BEAM reductions (Elixir only)

    -- I/O metrics
    io_read_bytes   INTEGER,
    io_write_bytes  INTEGER,
    db_queries      INTEGER,              -- SQL queries executed

    -- Network metrics (for integration tests)
    http_requests   INTEGER,
    zenoh_publishes INTEGER,

    FOREIGN KEY(result_id) REFERENCES test_results(id) ON DELETE CASCADE
);

CREATE INDEX idx_metrics_result ON test_metrics(result_id);
```

#### Table 9: `test_logs` — Log references and entries linked to tests

```sql
CREATE TABLE IF NOT EXISTS test_logs (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    result_id       TEXT,                  -- FK → test_results (nullable for run-level logs)
    run_id          TEXT NOT NULL,         -- FK → test_runs

    -- Log entry
    timestamp       TEXT NOT NULL,         -- ISO 8601 UTC
    level           TEXT NOT NULL,         -- 'debug' | 'info' | 'warning' | 'error' | 'critical'
    source          TEXT,                  -- 'exunit' | 'application' | 'zenoh' | 'otel' | 'phoenix'
    message         TEXT NOT NULL,

    -- Log file reference
    log_file_path   TEXT,                  -- './data/tmp/1-compile.log' | 'test.log'
    log_line_start  INTEGER,              -- Line number in log file
    log_line_end    INTEGER,

    -- Correlation
    trace_id        TEXT,                  -- OpenTelemetry trace ID
    span_id         TEXT,                  -- OpenTelemetry span ID
    zenoh_topic     TEXT,                  -- Zenoh topic if published
    checkpoint_id   TEXT,                  -- CP-* checkpoint ID

    -- Structured data
    metadata        TEXT,                  -- JSON: additional context

    FOREIGN KEY(result_id) REFERENCES test_results(id) ON DELETE CASCADE,
    FOREIGN KEY(run_id) REFERENCES test_runs(id) ON DELETE CASCADE
);

CREATE INDEX idx_logs_result     ON test_logs(result_id);
CREATE INDEX idx_logs_run        ON test_logs(run_id);
CREATE INDEX idx_logs_level      ON test_logs(level);
CREATE INDEX idx_logs_trace      ON test_logs(trace_id);
CREATE INDEX idx_logs_checkpoint ON test_logs(checkpoint_id);
CREATE INDEX idx_logs_timestamp  ON test_logs(timestamp);
```

#### Table 10: `test_constraints` — STAMP constraint ↔ test mapping

```sql
CREATE TABLE IF NOT EXISTS test_constraints (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    definition_id   TEXT NOT NULL,         -- FK → test_definitions
    constraint_id   TEXT NOT NULL,         -- 'SC-ZTEST-005' | 'SC-COV-001' | 'AOR-TEST-NIF-001'
    constraint_type TEXT NOT NULL,         -- 'STAMP' | 'AOR' | 'FMEA' | 'BDD'
    severity        TEXT,                  -- 'CRITICAL' | 'HIGH' | 'MEDIUM' | 'LOW'
    verification    TEXT,                  -- How this test verifies the constraint

    FOREIGN KEY(definition_id) REFERENCES test_definitions(id) ON DELETE CASCADE,
    UNIQUE(definition_id, constraint_id)
);

CREATE INDEX idx_constraints_def  ON test_constraints(definition_id);
CREATE INDEX idx_constraints_type ON test_constraints(constraint_type);
CREATE INDEX idx_constraints_id   ON test_constraints(constraint_id);
```

#### Table 11: `run_metrics` — Run-level aggregate metrics

```sql
CREATE TABLE IF NOT EXISTS run_metrics (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id          TEXT NOT NULL,         -- FK → test_runs

    metric_name     TEXT NOT NULL,         -- 'compilation_time_ms' | 'memory_peak_mb' | 'beam_file_count'
    value           REAL NOT NULL,
    unit            TEXT,                  -- 'ms' | 'MB' | 'count' | '%'
    baseline_value  REAL,                 -- Previous baseline for comparison
    delta           REAL GENERATED ALWAYS AS (value - baseline_value) STORED,

    FOREIGN KEY(run_id) REFERENCES test_runs(id) ON DELETE CASCADE
);

CREATE INDEX idx_run_metrics_run  ON run_metrics(run_id);
CREATE INDEX idx_run_metrics_name ON run_metrics(metric_name);
```

#### Table 12: `run_artifacts` — Log files, coverage reports, screenshots

```sql
CREATE TABLE IF NOT EXISTS run_artifacts (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id          TEXT NOT NULL,         -- FK → test_runs

    artifact_type   TEXT NOT NULL,         -- 'log' | 'coverage' | 'screenshot' | 'junit_xml' | 'cobertura' | 'lcov'
    name            TEXT NOT NULL,         -- 'compile.log' | 'cover/excoveralls.json'
    file_path       TEXT NOT NULL,         -- Relative to project root
    file_size_bytes INTEGER,
    content_hash    TEXT,                  -- SHA-256 of file content
    mime_type       TEXT,                  -- 'text/plain' | 'application/json' | 'text/xml'

    created_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY(run_id) REFERENCES test_runs(id) ON DELETE CASCADE
);

CREATE INDEX idx_artifacts_run  ON run_artifacts(run_id);
CREATE INDEX idx_artifacts_type ON run_artifacts(artifact_type);
```

#### Table 13: `coverage_data` — Per-module/file coverage tracking

```sql
CREATE TABLE IF NOT EXISTS coverage_data (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id          TEXT NOT NULL,         -- FK → test_runs

    -- Source identification
    runtime         TEXT NOT NULL,         -- 'elixir' | 'fsharp' | 'rust'
    module_name     TEXT NOT NULL,         -- 'Indrajaal.Safety.SymbioticDefense'
    file_path       TEXT NOT NULL,         -- 'lib/indrajaal/safety/symbiotic_defense.ex'

    -- Coverage metrics
    lines_total     INTEGER NOT NULL,
    lines_covered   INTEGER NOT NULL,
    lines_missed    INTEGER NOT NULL,
    line_coverage   REAL GENERATED ALWAYS AS (
        CASE WHEN lines_total > 0 THEN CAST(lines_covered AS REAL) / lines_total * 100.0 ELSE 0.0 END
    ) STORED,

    branches_total  INTEGER DEFAULT 0,
    branches_covered INTEGER DEFAULT 0,
    branch_coverage REAL GENERATED ALWAYS AS (
        CASE WHEN branches_total > 0 THEN CAST(branches_covered AS REAL) / branches_total * 100.0 ELSE 0.0 END
    ) STORED,

    functions_total INTEGER DEFAULT 0,
    functions_covered INTEGER DEFAULT 0,
    function_coverage REAL GENERATED ALWAYS AS (
        CASE WHEN functions_total > 0 THEN CAST(functions_covered AS REAL) / functions_total * 100.0 ELSE 0.0 END
    ) STORED,

    -- Fractal layer
    fractal_layer   TEXT,                  -- 'L0'..'L7'
    domain          TEXT,                  -- Domain classification

    -- Uncovered lines (for targeted test generation)
    uncovered_lines TEXT,                  -- JSON array: [45, 67, 89, ...]

    FOREIGN KEY(run_id) REFERENCES test_runs(id) ON DELETE CASCADE
);

CREATE INDEX idx_coverage_run    ON coverage_data(run_id);
CREATE INDEX idx_coverage_module ON coverage_data(module_name);
CREATE INDEX idx_coverage_file   ON coverage_data(file_path);
CREATE INDEX idx_coverage_pct    ON coverage_data(line_coverage);
```

#### Table 14: `flaky_analysis` — Materialized flaky test detection

```sql
CREATE TABLE IF NOT EXISTS flaky_analysis (
    definition_id   TEXT PRIMARY KEY,      -- FK → test_definitions

    -- Run history window
    window_size     INTEGER NOT NULL,      -- Number of runs analyzed
    window_start    TEXT NOT NULL,          -- Earliest run in window
    window_end      TEXT NOT NULL,          -- Latest run in window

    -- Pass/fail counts
    total_runs      INTEGER NOT NULL,
    pass_count      INTEGER NOT NULL,
    fail_count      INTEGER NOT NULL,
    skip_count      INTEGER NOT NULL,
    error_count     INTEGER NOT NULL,

    -- Flaky metrics (Atlassian Flakinator inspired)
    flip_count      INTEGER NOT NULL,      -- Number of status flips (pass→fail or fail→pass)
    flip_rate       REAL NOT NULL,          -- flip_count / (total_runs - 1)
    flip_rate_ewma  REAL NOT NULL,          -- Exponentially weighted moving average

    -- Classification
    is_flaky        INTEGER NOT NULL,      -- 1 if flip_rate > threshold
    flaky_score     REAL NOT NULL,          -- 0.0 (stable) to 1.0 (always flipping)
    confidence      REAL NOT NULL,          -- Statistical confidence (0.0-1.0)

    -- Timing analysis
    avg_duration_ms REAL,
    stddev_duration REAL,
    p50_duration_ms REAL,
    p95_duration_ms REAL,
    p99_duration_ms REAL,
    duration_trend  TEXT,                   -- 'stable' | 'increasing' | 'decreasing' | 'volatile'

    -- Quarantine status
    quarantined     INTEGER DEFAULT 0,
    quarantined_at  TEXT,
    quarantine_reason TEXT,

    -- Last update
    updated_at      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),

    FOREIGN KEY(definition_id) REFERENCES test_definitions(id)
);

CREATE INDEX idx_flaky_score    ON flaky_analysis(flaky_score DESC);
CREATE INDEX idx_flaky_is_flaky ON flaky_analysis(is_flaky) WHERE is_flaky = 1;
CREATE INDEX idx_flaky_quarantine ON flaky_analysis(quarantined) WHERE quarantined = 1;
```

---

## 4. Key SQL Views

### 4.1 Dashboard Summary View

```sql
CREATE VIEW IF NOT EXISTS v_dashboard_summary AS
SELECT
    tp.name AS project,
    tp.runtime,
    tr.id AS run_id,
    tr.status AS run_status,
    tr.started_at,
    tr.duration_ms,
    tr.total_tests,
    tr.passed,
    tr.failed,
    tr.skipped,
    tr.line_coverage,
    tr.git_branch,
    tr.git_commit,
    ROUND(CAST(tr.passed AS REAL) / NULLIF(tr.total_tests, 0) * 100, 1) AS pass_rate
FROM test_runs tr
JOIN test_projects tp ON tr.project_id = tp.id
ORDER BY tr.started_at DESC;
```

### 4.2 Flaky Tests Report View

```sql
CREATE VIEW IF NOT EXISTS v_flaky_tests AS
SELECT
    td.full_name,
    ts.file_path,
    ts.runtime,
    ts.fractal_layer,
    fa.flip_rate,
    fa.flip_rate_ewma,
    fa.flaky_score,
    fa.total_runs,
    fa.pass_count,
    fa.fail_count,
    fa.avg_duration_ms,
    fa.quarantined,
    fa.confidence
FROM flaky_analysis fa
JOIN test_definitions td ON fa.definition_id = td.id
JOIN test_suites ts ON td.suite_id = ts.id
WHERE fa.is_flaky = 1
ORDER BY fa.flaky_score DESC;
```

### 4.3 Duration Regression View

```sql
CREATE VIEW IF NOT EXISTS v_duration_regression AS
SELECT
    td.full_name,
    ts.runtime,
    tr.git_branch,
    tres.duration_ms,
    fa.avg_duration_ms,
    fa.p95_duration_ms,
    ROUND(tres.duration_ms - fa.avg_duration_ms, 2) AS delta_ms,
    CASE
        WHEN tres.duration_ms > fa.p95_duration_ms THEN 'REGRESSION'
        WHEN tres.duration_ms < fa.avg_duration_ms * 0.5 THEN 'IMPROVEMENT'
        ELSE 'NORMAL'
    END AS verdict
FROM test_results tres
JOIN test_runs tr ON tres.run_id = tr.id
JOIN test_definitions td ON tres.definition_id = td.id
JOIN test_suites ts ON td.suite_id = ts.id
LEFT JOIN flaky_analysis fa ON td.id = fa.definition_id
WHERE tres.status IN ('passed', 'failed')
ORDER BY delta_ms DESC;
```

### 4.4 Coverage Trend View

```sql
CREATE VIEW IF NOT EXISTS v_coverage_trend AS
SELECT
    tr.started_at,
    tr.git_branch,
    tp.runtime,
    ROUND(AVG(cd.line_coverage), 2) AS avg_line_coverage,
    ROUND(AVG(cd.branch_coverage), 2) AS avg_branch_coverage,
    COUNT(DISTINCT cd.module_name) AS modules_covered,
    SUM(CASE WHEN cd.line_coverage >= 95.0 THEN 1 ELSE 0 END) AS modules_above_95,
    SUM(CASE WHEN cd.line_coverage < 50.0 THEN 1 ELSE 0 END) AS modules_below_50
FROM coverage_data cd
JOIN test_runs tr ON cd.run_id = tr.id
JOIN test_projects tp ON tr.project_id = tp.id
GROUP BY tr.id, tr.started_at, tr.git_branch, tp.runtime
ORDER BY tr.started_at DESC;
```

### 4.5 STAMP Constraint Coverage View

```sql
CREATE VIEW IF NOT EXISTS v_stamp_coverage AS
SELECT
    tc.constraint_id,
    tc.constraint_type,
    tc.severity,
    COUNT(DISTINCT tc.definition_id) AS test_count,
    SUM(CASE WHEN tres.status = 'passed' THEN 1 ELSE 0 END) AS last_pass_count,
    SUM(CASE WHEN tres.status = 'failed' THEN 1 ELSE 0 END) AS last_fail_count,
    GROUP_CONCAT(DISTINCT ts.runtime) AS runtimes_covered
FROM test_constraints tc
JOIN test_definitions td ON tc.definition_id = td.id
JOIN test_suites ts ON td.suite_id = ts.id
LEFT JOIN test_results tres ON td.id = tres.definition_id
    AND tres.run_id = (SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1)
GROUP BY tc.constraint_id, tc.constraint_type, tc.severity
ORDER BY tc.severity, tc.constraint_id;
```

### 4.6 Cross-Runtime Summary View

```sql
CREATE VIEW IF NOT EXISTS v_cross_runtime_summary AS
SELECT
    tp.runtime,
    tp.framework,
    COUNT(DISTINCT ts.id) AS suite_count,
    COUNT(DISTINCT td.id) AS test_count,
    COUNT(DISTINCT CASE WHEN td.test_type = 'property' THEN td.id END) AS property_count,
    (SELECT COUNT(*) FROM test_results tres2
     JOIN test_runs tr2 ON tres2.run_id = tr2.id
     WHERE tr2.project_id = tp.id
       AND tr2.id = (SELECT id FROM test_runs WHERE project_id = tp.id ORDER BY started_at DESC LIMIT 1)
       AND tres2.status = 'passed') AS last_run_passed,
    (SELECT COUNT(*) FROM test_results tres3
     JOIN test_runs tr3 ON tres3.run_id = tr3.id
     WHERE tr3.project_id = tp.id
       AND tr3.id = (SELECT id FROM test_runs WHERE project_id = tp.id ORDER BY started_at DESC LIMIT 1)
       AND tres3.status = 'failed') AS last_run_failed
FROM test_projects tp
LEFT JOIN test_suites ts ON tp.id = ts.project_id
LEFT JOIN test_definitions td ON ts.id = td.suite_id
GROUP BY tp.id, tp.runtime, tp.framework;
```

---

## 5. Features Supported

### 5.1 Core Features

| # | Feature | Tables Used | Query Example |
|---|---------|-------------|---------------|
| 1 | **Test Run Tracking** | test_runs, test_results | `SELECT * FROM v_dashboard_summary LIMIT 10` |
| 2 | **Multi-Runtime Support** | test_projects, test_suites | `SELECT * FROM v_cross_runtime_summary` |
| 3 | **Flaky Test Detection** | flaky_analysis | `SELECT * FROM v_flaky_tests WHERE flaky_score > 0.3` |
| 4 | **Duration Regression** | test_results, flaky_analysis | `SELECT * FROM v_duration_regression WHERE verdict = 'REGRESSION'` |
| 5 | **Coverage Tracking** | coverage_data | `SELECT * FROM v_coverage_trend WHERE avg_line_coverage < 95` |
| 6 | **Log Correlation** | test_logs | `SELECT * FROM test_logs WHERE result_id = ? ORDER BY timestamp` |
| 7 | **STAMP Compliance** | test_constraints | `SELECT * FROM v_stamp_coverage WHERE last_fail_count > 0` |
| 8 | **Git Bisection** | test_runs, test_results | See 5.2 |
| 9 | **Performance Profiling** | test_metrics | See 5.2 |
| 10 | **CI/CD Artifact** | run_artifacts | `SELECT * FROM run_artifacts WHERE run_id = ?` |

### 5.2 Advanced Query Examples

#### Find which commit broke a test
```sql
SELECT
    tr.git_commit,
    tr.git_message,
    tr.started_at,
    tres.status,
    tres.failure_message
FROM test_results tres
JOIN test_runs tr ON tres.run_id = tr.id
JOIN test_definitions td ON tres.definition_id = td.id
WHERE td.full_name = 'Indrajaal.Mesh.ZoneManagerTest.test zone failover'
ORDER BY tr.started_at DESC
LIMIT 20;
```

#### Find slowest tests in last run
```sql
SELECT
    td.full_name,
    ts.runtime,
    tres.duration_ms,
    tm.memory_peak_kb,
    tm.cpu_percent
FROM test_results tres
JOIN test_definitions td ON tres.definition_id = td.id
JOIN test_suites ts ON td.suite_id = ts.id
LEFT JOIN test_metrics tm ON tres.id = tm.result_id
WHERE tres.run_id = (SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1)
ORDER BY tres.duration_us DESC
LIMIT 20;
```

#### Tests that failed on main but pass on feature branch
```sql
SELECT td.full_name, ts.file_path
FROM test_results tres_main
JOIN test_runs tr_main ON tres_main.run_id = tr_main.id
JOIN test_definitions td ON tres_main.definition_id = td.id
JOIN test_suites ts ON td.suite_id = ts.id
WHERE tr_main.git_branch = 'main'
  AND tres_main.status = 'failed'
  AND td.id IN (
    SELECT tres_feat.definition_id
    FROM test_results tres_feat
    JOIN test_runs tr_feat ON tres_feat.run_id = tr_feat.id
    WHERE tr_feat.git_branch = 'feature/my-branch'
      AND tres_feat.status = 'passed'
  );
```

#### Coverage gaps per fractal layer
```sql
SELECT
    cd.fractal_layer,
    COUNT(*) AS modules,
    ROUND(AVG(cd.line_coverage), 1) AS avg_coverage,
    MIN(cd.line_coverage) AS min_coverage,
    GROUP_CONCAT(
        CASE WHEN cd.line_coverage < 50 THEN cd.module_name END, ', '
    ) AS critical_gaps
FROM coverage_data cd
WHERE cd.run_id = (SELECT id FROM test_runs ORDER BY started_at DESC LIMIT 1)
GROUP BY cd.fractal_layer
ORDER BY cd.fractal_layer;
```

#### Flaky test quarantine candidates (Atlassian-style)
```sql
SELECT
    td.full_name,
    fa.flip_rate,
    fa.flip_rate_ewma,
    fa.total_runs,
    fa.flaky_score,
    fa.avg_duration_ms,
    CASE
        WHEN fa.flaky_score > 0.7 THEN 'AUTO-QUARANTINE'
        WHEN fa.flaky_score > 0.4 THEN 'REVIEW-NEEDED'
        WHEN fa.flaky_score > 0.2 THEN 'MONITOR'
        ELSE 'STABLE'
    END AS recommendation
FROM flaky_analysis fa
JOIN test_definitions td ON fa.definition_id = td.id
WHERE fa.is_flaky = 1
ORDER BY fa.flaky_score DESC;
```

---

## 6. Integration Architecture

### 6.1 Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    UTLTS DATA FLOW ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │  mix test     │  │  dotnet test │  │  cargo test  │  │  elixir    │  │
│  │  (ExUnit)     │  │  (Expecto)   │  │  (Rust)      │  │  script.exs│  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬─────┘  │
│         │                 │                 │                 │          │
│         ▼                 ▼                 ▼                 ▼          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌────────────┐  │
│  │ UTLTS.Elixir │  │ UTLTS.FSharp │  │ UTLTS.Rust   │  │ UTLTS.     │  │
│  │ Formatter    │  │ Reporter     │  │ Parser       │  │ Script     │  │
│  │ (ExUnit      │  │ (Expecto     │  │ (cargo JSON  │  │ Runner     │  │
│  │  Formatter)  │  │  TestSummary)│  │  output)     │  │            │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬─────┘  │
│         │                 │                 │                 │          │
│         └────────────┬────┴─────────┬───────┘                │          │
│                      │              │                         │          │
│                      ▼              ▼                         │          │
│              ┌──────────────────────────────┐                │          │
│              │     UTLTS.Writer             │◄───────────────┘          │
│              │  (Async SQLite writer)       │                           │
│              │  - Batched inserts           │                           │
│              │  - WAL mode                  │                           │
│              │  - busy_timeout=5000         │                           │
│              └──────────┬───────────────────┘                           │
│                         │                                               │
│                         ▼                                               │
│              ┌──────────────────────────────┐                           │
│              │  data/holons/test/utlts.db   │  ← Single file artifact  │
│              │  (SQLite WAL, 14 tables)     │                           │
│              └──────────┬───────────────────┘                           │
│                         │                                               │
│           ┌─────────────┼────────────────────┐                          │
│           ▼             ▼                    ▼                          │
│  ┌──────────────┐ ┌───────────┐  ┌──────────────────┐                  │
│  │ Zenoh Pub    │ │ Phoenix   │  │ DuckDB Export    │                  │
│  │ (real-time)  │ │ LiveView  │  │ (heavy analytics)│                  │
│  └──────────────┘ └───────────┘  └──────────────────┘                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Elixir Integration (ExUnit Formatter)

```elixir
# lib/indrajaal/testing/utlts_formatter.ex
defmodule Indrajaal.Testing.UTLTSFormatter do
  @moduledoc """
  ExUnit formatter that writes test lifecycle events to the UTLTS SQLite database.

  Replaces/augments ZenohTestFormatter with persistent storage.
  Runs alongside existing formatters (ExUnit.CLIFormatter, ZenohTestFormatter).

  ## Configuration
  ```elixir
  # test/test_helper.exs
  ExUnit.configure(formatters: [
    ExUnit.CLIFormatter,
    Indrajaal.Testing.ZenohTestFormatter,
    Indrajaal.Testing.UTLTSFormatter
  ])
  ```

  ## STAMP Constraints
  - SC-ZTEST-004: Non-blocking (async writes via GenServer)
  - SC-ZTEST-008: Log fallback preserved
  """
  use GenServer

  # GenServer callbacks that handle:
  # {:suite_started, opts}
  # {:suite_finished, times_us, state}
  # {:module_started, %ExUnit.TestModule{}}
  # {:module_finished, %ExUnit.TestModule{}}
  # {:test_started, %ExUnit.Test{}}
  # {:test_finished, %ExUnit.Test{}}
end
```

### 6.3 F# Integration (Expecto Reporter)

```fsharp
// lib/cepaf/src/Cepaf/Testing/UTLTSReporter.fs
module Cepaf.Testing.UTLTSReporter

open Expecto
open Microsoft.Data.Sqlite

/// Writes Expecto test results to UTLTS SQLite database
let utltsReporter (dbPath: string) : TestResultSink =
    fun (summary: TestRunSummary) ->
        use conn = new SqliteConnection($"Data Source={dbPath}")
        conn.Open()
        // Insert test_run record
        // Insert test_results for each test
        // Insert test_metrics for timing data
```

### 6.4 Rust Integration (Cargo Test Parser)

```elixir
# lib/indrajaal/testing/utlts_cargo_parser.ex
defmodule Indrajaal.Testing.UTLTSCargoParser do
  @moduledoc """
  Parses `cargo test --format json` output and inserts into UTLTS.

  Usage:
    cargo test --format json 2>&1 | mix utlts.import_cargo
  """
end
```

### 6.5 Script Integration (Wrapper)

```elixir
# lib/indrajaal/testing/utlts_script_runner.ex
defmodule Indrajaal.Testing.UTLTSScriptRunner do
  @moduledoc """
  Wraps script execution with UTLTS tracking.

  Usage:
    UTLTSScriptRunner.run("scripts/testing/tdg_validator.exs")
  """
end
```

---

## 7. Flaky Test Detection Algorithm

### 7.1 Flip-Rate Calculation (Atlassian Flakinator)

```sql
-- Calculate flip rate for a test over last N runs
WITH ordered_results AS (
    SELECT
        tres.definition_id,
        tres.status,
        tres.run_id,
        tr.started_at,
        LAG(tres.status) OVER (
            PARTITION BY tres.definition_id
            ORDER BY tr.started_at
        ) AS prev_status
    FROM test_results tres
    JOIN test_runs tr ON tres.run_id = tr.id
    WHERE tres.definition_id = ?
    ORDER BY tr.started_at DESC
    LIMIT 50  -- Analysis window
)
SELECT
    definition_id,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN status = 'passed' THEN 1 ELSE 0 END) AS pass_count,
    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS fail_count,
    SUM(CASE WHEN status != prev_status AND prev_status IS NOT NULL THEN 1 ELSE 0 END) AS flip_count,
    CAST(SUM(CASE WHEN status != prev_status AND prev_status IS NOT NULL THEN 1 ELSE 0 END) AS REAL) /
        NULLIF(COUNT(*) - 1, 0) AS flip_rate
FROM ordered_results;
```

### 7.2 EWMA Flip Rate

```
EWMA(t) = α × flip_rate(t) + (1 - α) × EWMA(t-1)

where α = 0.3 (sensitivity parameter)
```

### 7.3 Flaky Classification Thresholds

| Flip Rate | Classification | Action |
|-----------|---------------|--------|
| 0.0 | STABLE | No action |
| 0.01 - 0.10 | OCCASIONAL | Monitor |
| 0.10 - 0.30 | FLAKY | Review needed |
| 0.30 - 0.60 | HIGHLY_FLAKY | Auto-quarantine candidate |
| 0.60+ | PATHOLOGICAL | Immediate quarantine |

---

## 8. Database Location & Lifecycle

### 8.1 File Location

```
data/holons/test/
├── utlts.db           # Main database (WAL mode)
├── utlts.db-wal       # Write-ahead log
├── utlts.db-shm       # Shared memory file
├── manifest.json      # Holon manifest (AOR-DBNAME-003)
└── exports/
    ├── utlts-20260309.duckdb    # DuckDB export for analytics
    └── utlts-20260309.parquet   # Parquet export for BI tools
```

### 8.2 Holon Manifest

```json
{
    "uhi": "elx:L3:TST:001",
    "name": "Test Lifecycle Tracking Holon",
    "version": "1.0.0",
    "databases": {
        "sqlite": {
            "file": "utlts.db",
            "schema_version": "1.0.0",
            "wal_mode": true,
            "tables": 14,
            "views": 6
        }
    },
    "created_at": "2026-03-09T00:00:00Z",
    "checksums": {
        "schema": "sha256:..."
    }
}
```

### 8.3 Retention Policy

```sql
-- Purge test results older than 365 days (configurable)
DELETE FROM test_results WHERE run_id IN (
    SELECT id FROM test_runs
    WHERE started_at < datetime('now', '-365 days')
);

-- Keep flaky_analysis indefinitely (small table)
-- Keep test_definitions indefinitely (identity data)
-- Keep coverage_data for last 90 days
DELETE FROM coverage_data WHERE run_id IN (
    SELECT id FROM test_runs
    WHERE started_at < datetime('now', '-90 days')
);
```

---

## 9. STAMP Constraints (UTLTS)

| ID | Constraint | Severity | Verification |
|----|------------|----------|--------------|
| SC-UTLTS-001 | UTLTS database MUST use WAL mode | CRITICAL | PRAGMA check |
| SC-UTLTS-002 | All test runs MUST be recorded regardless of runtime | CRITICAL | Integration test |
| SC-UTLTS-003 | Write latency < 1ms per result (async) | HIGH | Benchmark |
| SC-UTLTS-004 | Flaky analysis MUST run after every test suite completion | HIGH | Post-run hook |
| SC-UTLTS-005 | Coverage data MUST be captured for all runtimes | HIGH | Coverage check |
| SC-UTLTS-006 | Log references MUST link to actual log files | HIGH | File existence check |
| SC-UTLTS-007 | Schema migrations MUST be forward-compatible | HIGH | Migration test |
| SC-UTLTS-008 | Database MUST be portable as single-file CI artifact | CRITICAL | Copy test |
| SC-UTLTS-009 | STAMP constraint mapping MUST cover critical constraints | HIGH | Completeness check |
| SC-UTLTS-010 | Zenoh events MUST be published for key lifecycle changes | MEDIUM | SC-ZTEST integration |
| SC-UTLTS-011 | DuckDB export MUST be available for heavy analytics | MEDIUM | Export test |
| SC-UTLTS-012 | Concurrent access from 16 parallel test threads | CRITICAL | Stress test |

---

## 10. AOR Rules (UTLTS)

| ID | Rule | Violation Response |
|----|------|-------------------|
| AOR-UTLTS-001 | ALL test runs MUST write to utlts.db | Block CI if missing |
| AOR-UTLTS-002 | ExUnit formatter MUST be non-blocking | Performance review |
| AOR-UTLTS-003 | Flaky analysis MUST refresh after every run | Stale data alert |
| AOR-UTLTS-004 | Database backup before schema migration | Rollback available |
| AOR-UTLTS-005 | Upload utlts.db as CI artifact on every pipeline | Artifact missing alert |
| AOR-UTLTS-006 | Query utlts.db for flaky tests before merge | PR gate |
| AOR-UTLTS-007 | DuckDB export weekly for historical analysis | Scheduled job |
| AOR-UTLTS-008 | STAMP coverage gaps MUST be reported in PR | PR template check |

---

## 11. Implementation Roadmap

### Phase 1: Core Schema & Elixir Formatter (Sprint 47)
- [ ] Create utlts.db with all 14 tables and 6 views
- [ ] Implement UTLTSFormatter (ExUnit formatter)
- [ ] Integrate with test_helper.exs
- [ ] Basic flaky detection query
- [ ] Log file reference tracking

### Phase 2: Multi-Runtime Support (Sprint 48)
- [ ] F# Expecto reporter (UTLTSReporter.fs)
- [ ] Rust cargo test JSON parser
- [ ] Script execution wrapper
- [ ] Coverage data import (excoveralls → SQLite)

### Phase 3: Analytics & Reporting (Sprint 49)
- [ ] Flaky analysis materialization (post-run hook)
- [ ] Duration regression detection
- [ ] DuckDB export pipeline
- [ ] Prajna dashboard integration (LiveView)

### Phase 4: CI/CD Integration (Sprint 50)
- [ ] CI artifact upload/download
- [ ] PR gate (flaky check, coverage check)
- [ ] Historical trend reports
- [ ] STAMP constraint coverage dashboard

---

## 12. Migration from Existing Systems

### 12.1 Data Migration Plan

| Source | Target | Strategy |
|--------|--------|----------|
| test_tracking.db (3 tables) | test_runs, test_results, run_metrics | SQL transform + import |
| test_manager.db (6 tables) | test_definitions, test_results, test_constraints | SQL transform |
| test_evolution_*.db | test_definitions (enrichment) | Merge evolution metadata |
| ZenohTestOrchestrator state | test_runs (enrichment) | Real-time capture |
| KMS JSONL logs | test_logs | Parse + import |
| cover/lcov.coverdata | coverage_data | lcov parser |

### 12.2 Backward Compatibility

- ZenohTestFormatter continues to work (Zenoh pub/sub for real-time)
- UTLTSFormatter runs alongside (persistent storage)
- DuckDB analytics databases remain for holon-level analytics
- JSONL logs continue as tertiary backup

---

## 13. Related Documents

| Document | Location |
|----------|----------|
| Zenoh Test Messaging | `.claude/rules/zenoh-test-messaging.md` |
| Fractal Test Framework | `docs/testing/FRACTAL_TEST_FRAMEWORK_MASTER_PLAN.md` |
| Holon Database Naming | `docs/architecture/HOLON_DATABASE_NAMING_SYSTEM.md` |
| Change Management | `.claude/rules/change-management.md` |
| CLAUDE.md §14 | BEP Test/Demo Integration |
| test_tracking.db | `backups/mesh-state-*/kms/test_tracking.db` |
| test_manager.db | `backups/mesh-state-*/kms/test_manager.db` |
