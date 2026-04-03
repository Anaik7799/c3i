#!/usr/bin/env elixir

# KMS Schema Update: Expanded Holon Types (v21.3.0)
# Purpose: Add 'task' type to satisfy the biomorphic todolist mandate.
# STAMP: SC-KMS-001, Axiom 0

Mix.install([{:exqlite, "~> 0.23"}, {:jason, "~> 1.4"}])

defmodule KmsSchemaUpdate do
  @db_path "data/kms/holons.db"

  def execute do
    IO.puts(">>> [KMS] INITIATING SCHEMATIC EVOLUTION...")
    
    {:ok, conn} = Exqlite.Sqlite3.open(@db_path)

    # Transactional Table Swap
    :ok = Exqlite.Sqlite3.execute(conn, "BEGIN TRANSACTION;")

    try do
      # 1. Rename existing table
      :ok = Exqlite.Sqlite3.execute(conn, "ALTER TABLE holons RENAME TO holons_old;")

      # 2. Create new table with expanded CHECK constraint
      :ok = Exqlite.Sqlite3.execute(conn, """
      CREATE TABLE holons (
        id TEXT PRIMARY KEY,
        fqun TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL CHECK(type IN ('knowledge','process','agent','artifact','index','task')),
        name TEXT NOT NULL,
        parent_id TEXT REFERENCES holons(id),
        genome TEXT NOT NULL DEFAULT '{}',
        vital_signs TEXT DEFAULT '{"health":1.0,"stress":0.0,"energy":1.0}',
        membrane TEXT DEFAULT '{}',
        payload TEXT NOT NULL DEFAULT '{}',
        hlc_physical INTEGER NOT NULL,
        hlc_logical INTEGER NOT NULL,
        created_at TEXT DEFAULT (datetime('now')),
        updated_at TEXT DEFAULT (datetime('now'))
      );
      """)

      # 3. Migrate data
      :ok = Exqlite.Sqlite3.execute(conn, "INSERT INTO holons SELECT * FROM holons_old;")

      # 4. Re-create indexes
      :ok = Exqlite.Sqlite3.execute(conn, "CREATE INDEX IF NOT EXISTS idx_holons_parent ON holons(parent_id);")
      :ok = Exqlite.Sqlite3.execute(conn, "CREATE INDEX IF NOT EXISTS idx_holons_type ON holons(type);")
      :ok = Exqlite.Sqlite3.execute(conn, "CREATE INDEX IF NOT EXISTS idx_holons_hlc ON holons(hlc_physical, hlc_logical);")
      :ok = Exqlite.Sqlite3.execute(conn, "CREATE INDEX IF NOT EXISTS idx_holons_name ON holons(name);")

      # 5. Drop old table
      :ok = Exqlite.Sqlite3.execute(conn, "DROP TABLE holons_old;")

      :ok = Exqlite.Sqlite3.execute(conn, "COMMIT;")
      IO.puts(">>> [KMS] SCHEMATIC EVOLUTION COMPLETE: TYPE 'task' ADDED.")
    rescue
      e ->
        Exqlite.Sqlite3.execute(conn, "ROLLBACK;")
        IO.puts(">>> [FATAL] SCHEMATIC EVOLUTION FAILED: #{inspect(e)}")
        System.halt(1)
    end

    Exqlite.Sqlite3.close(conn)
  end
end

KmsSchemaUpdate.execute()
