#!/usr/bin/env elixir
# Test Tracking Database Initializer
# Compliance: SC-KMS-009 (Test Analytics)

Mix.install([{:exqlite, "~> 0.13"}])

defmodule TestDB do
  def init do
    db_path = "data/kms/test_tracking.db"
    File.mkdir_p!(Path.dirname(db_path))
    
    {:ok, conn} = Exqlite.Basic.open(db_path)
    
    # 1. Test Runs Table
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS test_runs (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        suite_name TEXT NOT NULL,
        mode TEXT,
        status TEXT NOT NULL,
        duration_ms INTEGER,
        git_hash TEXT
      );
    """)

    # 2. Test Cases Table (Granular results)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS test_cases (
        id TEXT PRIMARY KEY,
        run_id TEXT NOT NULL,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        duration_ms INTEGER,
        FOREIGN KEY(run_id) REFERENCES test_runs(id)
      );
    """)

    # 3. Metrics Table (Telemetry)
    Exqlite.Basic.exec(conn, """
      CREATE TABLE IF NOT EXISTS metrics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        run_id TEXT NOT NULL,
        metric_name TEXT NOT NULL,
        value REAL,
        unit TEXT,
        FOREIGN KEY(run_id) REFERENCES test_runs(id)
      );
    """)

    IO.puts(">>> [KMS] Test Tracking Database Initialized: #{db_path}")
    Exqlite.Basic.close(conn)
  end
end

TestDB.init()
