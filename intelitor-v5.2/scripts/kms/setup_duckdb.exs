#!/usr/bin/env elixir
# DuckDB Telemetry Initializer
# Role: OLAP Backend for Test Manager

Mix.install([{:duckdbex, "~> 0.3.19"}])

defmodule DuckDBInit do
  def run do
    path = "data/kms/telemetry.duckdb"
    {:ok, db} = Duckdbex.open(path)
    {:ok, conn} = Duckdbex.connection(db)

    # Telemetry Signals Table
    query = """
      CREATE TABLE IF NOT EXISTS telemetry_signals (
        ts TIMESTAMP,
        trace_id VARCHAR,
        execution_id VARCHAR,
        level VARCHAR,
        source_component VARCHAR,
        event_type VARCHAR,
        log_data JSON,
        logical_clock BIGINT
      );
    """
    
    case Duckdbex.query(conn, query) do
      {:ok, _} -> IO.puts(">>> [DuckDB] Telemetry schema initialized: #{path}")
      {:error, reason} -> IO.puts(">>> [DuckDB] Error: #{inspect(reason)}")
    end
  end
end

DuckDBInit.run()
