#!/usr/bin/env elixir
# KMS Test Tracker
# Usage: track_test.exs <run_id> <suite_name> <status> <duration_ms> [metric_name metric_value]

Mix.install([{:exqlite, "~> 0.13"}])

defmodule TestTracker do
  def run([run_id, suite_name, status, duration_ms | metrics]) do
    {:ok, conn} = Exqlite.Basic.open("data/kms/test_tracking.db")
    
    ts = DateTime.utc_now() |> DateTime.to_iso8601()
    
    # Insert Test Run
    statement = "INSERT OR REPLACE INTO test_runs (id, timestamp, suite_name, mode, status, duration_ms) VALUES (?1, ?2, ?3, 'fractal', ?4, ?5)"
    Exqlite.Basic.exec(conn, statement, [run_id, ts, suite_name, status, String.to_integer(duration_ms)])
    
    # Insert Metrics (if any)
    if length(metrics) >= 2 do
      [name, value | _] = metrics
      m_stmt = "INSERT INTO metrics (run_id, metric_name, value) VALUES (?1, ?2, ?3)"
      Exqlite.Basic.exec(conn, m_stmt, [run_id, name, String.to_float(value)])
    end

    IO.puts(">>> [KMS] Tracked: #{suite_name} -> #{status}")
    Exqlite.Basic.close(conn)
  end
end

System.argv() |> TestTracker.run()
