# Script to manually initialize the Core DB (Bifurcation Fix)
# Run with: mix run scripts/fix_core_db_init.exs

require Logger

Logger.info("Starting manual Core DB initialization...")

data_dir = "data/kms"
File.mkdir_p!(data_dir)

# Initialize Core DB
case Indrajaal.KMS.SQLite.init_core(data_dir) do
  :ok ->
    Logger.info("✅ SUCCESS: Core DB initialized at #{Path.join(data_dir, "core.db")}")
    
    # Verify file existence
    if File.exists?(Path.join(data_dir, "core.db")) do
      Logger.info("Verified file existence.")
    else
      Logger.error("❌ ERROR: File not found after init reported success.")
    end

  {:error, reason} ->
    Logger.error("❌ FAILURE: Could not initialize Core DB: #{inspect(reason)}")
end
