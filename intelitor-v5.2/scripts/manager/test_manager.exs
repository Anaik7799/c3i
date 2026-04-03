#!/usr/bin/env elixir
# Indrajaal Test Manager (The Examiner)
# WHAT: Central API for managing test lifecycles and evolutionary data.
# COMPLIANCE: SC-KMS-009

Mix.install([{:exqlite, "~> 0.13"}, {:jason, "~> 1.4"}])

defmodule TestManager do
  @db_path "data/kms/test_manager.db"

  def run(args) do
    case args do
      ["register", name, type | constraints] -> register_test(name, type, constraints)
      ["start", def_id, config_id] -> start_execution(def_id, config_id)
      ["finish", exec_id, verdict] -> finish_execution(exec_id, verdict)
      ["metric", exec_id, name, value] -> log_metric(exec_id, name, value)
      ["telemetry", exec_id, level, source, data] -> log_telemetry(exec_id, level, source, data)
      _ -> IO.puts("Usage: test_manager.exs [register|start|finish|metric|telemetry] ...")
    end
  end

  defp db_conn do
    {:ok, conn} = Exqlite.Basic.open(@db_path)
    conn
  end

  def register_test(name, type, constraints) do
    conn = db_conn()
    id = "test_#{System.unique_integer([:positive])}"
    constraints_json = Jason.encode!(constraints)
    
    Exqlite.Basic.exec(conn, 
      "INSERT INTO test_definitions (id, name, type, stamp_constraints) VALUES (?1, ?2, ?3, ?4)", 
      [id, name, type, constraints_json]
    )
    IO.puts(id) # Return ID to caller
    Exqlite.Basic.close(conn)
  end

  def start_execution(def_id, config_id) do
    conn = db_conn()
    id = "run_#{System.unique_integer([:positive])}"
    ts = DateTime.utc_now() |> DateTime.to_iso8601()
    
    # Placeholder for mutation_id (would come from git)
    mutation_id = "git_current" 

    Exqlite.Basic.exec(conn, 
      "INSERT INTO test_executions (id, def_id, config_id, mutation_id, start_time, verdict) VALUES (?1, ?2, ?3, ?4, ?5, 'pending')", 
      [id, def_id, config_id, mutation_id, ts]
    )
    IO.puts(id)
    Exqlite.Basic.close(conn)
  end

  def finish_execution(id, verdict) do
    conn = db_conn()
    ts = DateTime.utc_now() |> DateTime.to_iso8601()
    
    Exqlite.Basic.exec(conn, 
      "UPDATE test_executions SET end_time = ?1, verdict = ?2 WHERE id = ?3", 
      [ts, verdict, id]
    )
    IO.puts("EXECUTION_FINISHED")
    Exqlite.Basic.close(conn)
  end

  def log_metric(id, name, value) do
    conn = db_conn()
    val = String.to_float(value)
    
    # Evolution: Check previous run for this test def
    # (Simplified for CLI usage - real version would query complex history)
    delta = 0.0 
    
    Exqlite.Basic.exec(conn, 
      "INSERT INTO kpi_metrics (execution_id, metric_name, value, baseline_delta) VALUES (?1, ?2, ?3, ?4)", 
      [id, name, val, delta]
    )
    Exqlite.Basic.close(conn)
  end

  def log_telemetry(id, level, source, data) do
    conn = db_conn()
    # Ensure data is valid JSON-ish string or escape it
    safe_data = inspect(data) 
    
    Exqlite.Basic.exec(conn,
      "INSERT INTO telemetry_signals (execution_id, fractal_level, source_component, log_data) VALUES (?1, ?2, ?3, ?4)",
      [id, level, source, safe_data]
    )
    Exqlite.Basic.close(conn)
  end
end

System.argv() |> TestManager.run()
