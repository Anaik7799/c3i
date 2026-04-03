#!/usr/bin/env elixir
# Advanced Test Database Initializer (The "Test Manager" Brain)
# Compliance: SC-KMS-009, SC-SIL6-020 (Data Vector Analysis)

Mix.install([{:exqlite, "~> 0.13"}])

defmodule AdvancedDB do
  def init do
    db_path = "data/kms/test_manager.db"
    File.mkdir_p!(Path.dirname(db_path))
    
    {:ok, conn} = Exqlite.Basic.open(db_path)
    
    # 1. Test Definitions (The Invariant)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS test_definitions (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type TEXT NOT NULL, -- 'unit', 'integration', 'chaos', 'soak'
        description TEXT,
        stamp_constraints TEXT -- JSON list of SC-* IDs
      );
    """)

    # 2. System Configuration (The Environment)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS system_configs (
        id TEXT PRIMARY KEY,
        topology_hash TEXT,
        sil_level INTEGER,
        container_manifest TEXT -- JSON mapping images to hashes
      );
    """)

    # 3. Code Mutations (The Change)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS code_mutations (
        id TEXT PRIMARY KEY,
        git_hash TEXT,
        files_changed TEXT, -- JSON list
        commit_message TEXT
      );
    """)

    # 4. Test Executions (The Event)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS test_executions (
        id TEXT PRIMARY KEY,
        def_id TEXT,
        config_id TEXT,
        mutation_id TEXT,
        start_time TEXT,
        end_time TEXT,
        verdict TEXT, -- 'pass', 'fail', 'degraded', 'improved'
        FOREIGN KEY(def_id) REFERENCES test_definitions(id),
        FOREIGN KEY(config_id) REFERENCES system_configs(id),
        FOREIGN KEY(mutation_id) REFERENCES code_mutations(id)
      );
    """)

    # 5. Telemetry Signals (The Evidence)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS telemetry_signals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        execution_id TEXT,
        fractal_level TEXT, -- 'L1'..'L5'
        source_component TEXT,
        log_data TEXT, -- JSON structure
        trace_id TEXT,
        FOREIGN KEY(execution_id) REFERENCES test_executions(id)
      );
    """)

    # 6. KPI Metrics (The Analysis)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS kpi_metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        execution_id TEXT,
        metric_name TEXT,
        value REAL,
        unit TEXT,
        baseline_delta REAL, -- Evolution impact (+/-)
        FOREIGN KEY(execution_id) REFERENCES test_executions(id)
      );
    """)

    IO.puts(">>> [TEST MANAGER] Advanced Schema Initialized: #{db_path}")
    Exqlite.Basic.close(conn)
  end
end

AdvancedDB.init()
