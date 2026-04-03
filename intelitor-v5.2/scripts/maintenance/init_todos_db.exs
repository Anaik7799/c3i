Mix.install([{:exqlite, "~> 0.13"}])

defmodule InitTodosDB do
  def run do
    db_path = "data/kms/todos.db"
    
    {:ok, conn} = Exqlite.Sqlite3.open(db_path)
    
    sql = """
    CREATE TABLE IF NOT EXISTS todos (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      priority TEXT NOT NULL DEFAULT 'p2',
      layer TEXT NOT NULL DEFAULT 'l1',
      fqun TEXT NOT NULL,
      payload TEXT DEFAULT '{}',
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    );
    """
    
    :ok = Exqlite.Sqlite3.execute(conn, sql)
    IO.puts("✅ Created table 'todos' in #{db_path}")
    
    Exqlite.Sqlite3.close(conn)
  end
end

InitTodosDB.run()
