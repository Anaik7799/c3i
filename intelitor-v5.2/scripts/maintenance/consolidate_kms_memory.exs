# ═══════════════════════════════════════════════════════════════════════════════
# AUTONOMOUS KMS SEPARATION SCRIPT (V23.3.1)
# ═══════════════════════════════════════════════════════════════════════════════

Mix.start()
Application.ensure_all_started(:indrajaal)

require Logger

defmodule AutonomousSeparator do
  alias Indrajaal.KMS.Todo
  alias Indrajaal.KMSRepo

  def execute do
    IO.puts("🧠 INITIATING KMS SEPARATION...")
    
    # 1. Initialize Repo (ensure file exists)
    # KMSRepo should be started by Application, but let's ensure
    
    # 2. Create Table
    create_table_sql = """
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
    
    try do
      Ecto.Adapters.SQL.query!(KMSRepo, create_table_sql, [])
      IO.puts("✅ Table 'todos' created in data/kms/todos.db")
    rescue
      e -> IO.puts("⚠️  Table creation warning: #{inspect(e)}")
    end

    # 3. Seed Memory (Re-seed into new DB)
    seed_memory()

    # 4. Cleanup Legacy Holons (Optional - let's keep them as backup for now)
    # cleanup_holons()

    IO.puts("✨ KMS Separation Complete. Todos are now in todos.db.")
  end

  defp seed_memory do
    IO.puts("🌱 Seeding Core Task Holons to NEW DB...")
    tasks = [
      {"Stabilize Substrate", :p0, :l1},
      {"Enable Neural Plasticity", :p1, :l2},
      {"Activate Telepathy", :p1, :l3},
      {"Optimize Metabolism", :p2, :l4},
      {"Begin Dreaming", :p2, :l5},
      {"Unify Swarm", :p1, :l6},
      {"Establish Federation", :p0, :l7}
    ]

    for {title, priority, layer} <- tasks do
      id = String.downcase(String.replace(title, " ", "_"))
      fqun = "kms/l5/task/default/#{title}##{id}"
      
      # Check if exists
      exists? = case Todo.get_by_fqun(fqun) do
         {:ok, results} when is_list(results) and length(results) > 0 -> true
         _ -> false
      end

      unless exists? do
            try do
              Todo.create!(%{
                name: title,
                fqun: fqun,
                status: :pending,
                priority: priority,
                layer: layer,
                payload: %{}
              })
              IO.puts("  + Implanted: #{title}")
            rescue
              e -> IO.puts("  ! Failed to implant #{title}: #{inspect(e)}")
            end
      end
    end
  end
end

AutonomousSeparator.execute()
