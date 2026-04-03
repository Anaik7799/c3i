#!/usr/bin/env elixir

# Elixir High-Fidelity Knowledge Ingestor (v21.3.0)
# Purpose: Transactionally materialize knowledge artifacts into KMS holons.
# STAMP: SC-KMS-001, Axiom 0

Mix.install([{:exqlite, "~> 0.23"}, {:jason, "~> 1.4"}])

defmodule ElixirIngestor do
  require Logger

  @db_path "data/kms/holons.db"
  @docs_path "docs"

  def execute do
    IO.puts(">>> [LOGIC] INITIATING 7-LEVEL KNOWLEDGE INGESTION...")
    
    {:ok, conn} = Exqlite.Sqlite3.open(@db_path)
    
    files = Path.wildcard("#{@docs_path}/**/*.md")
    IO.puts(">>> [LOGIC] FOUND #{length(files)} ARTIFACTS. STARTING METABOLIC LOAD...")

    Enum.each(files, fn file ->
      ingest_file(conn, file)
    end)

    IO.puts(">>> [LOGIC] KNOWLEDGE INGESTION COMPLETE.")
    Exqlite.Sqlite3.close(conn)
  end

  defp ingest_file(conn, path) do
    try do
      name = Path.basename(path, ".md")
      content = File.read!(path)
      id = "hln_" <> Base.encode32(:crypto.strong_rand_bytes(8), case: :lower, padding: false)
      fqun = "kms/l5/" <> String.replace(path, ["docs/", ".md"], "")
      
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      payload = Jason.encode!(%{content: content})

      query = """
      INSERT OR REPLACE INTO holons 
      (id, fqun, type, name, genome, payload, hlc_physical, hlc_logical, created_at, updated_at)
      VALUES (?1, ?2, 'knowledge', ?3, '{}', ?4, ?5, 0, ?6, ?7)
      """
      
      params = [id, fqun, name, payload, System.system_time(:millisecond), now, now]
      
      {:ok, stmt} = Exqlite.Sqlite3.prepare(conn, query)
      :ok = Exqlite.Sqlite3.bind(stmt, params)
      :done = Exqlite.Sqlite3.step(conn, stmt)
      Exqlite.Sqlite3.release(conn, stmt)
      
      IO.puts(" [✓] INGESTED: #{name}")
    rescue
      e -> IO.puts(" [✗] FAILED: #{path} (#{inspect(e)})")
    end
  end
end

ElixirIngestor.execute()
