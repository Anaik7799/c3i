defmodule Indrajaal.Ark.Seeder do
  @moduledoc """
  Ark Seeder: Deep Native Preservation Protocol.

  WHAT: Packages the living holon state into an encrypted, zero-dependency archive.
  WHY: SC-SING-004 ensures survival of the genetic lineage across substrate failures.
  """

  require Logger
  alias Indrajaal.Vault.QuantumSafe

  @holon_data_path "data/holons"

  @doc """
  Generates a new Ark Seed from the current system state.
  """
  def seed_now do
    Logger.info("🛸 [Ark.Seeder] Initiating Seeding Protocol (SC-SING-004)")

    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(~r/[:\-]/, "")
    temp_dir = "data/tmp/ark_seed_#{timestamp}"
    File.mkdir_p!(temp_dir)

    try do
      # 1. Collect Holons
      Logger.info("🛸 [Ark.Seeder] Collecting holon state from #{@holon_data_path}")
      # In production, we would use a more sophisticated copy that handles WAL files
      case File.cp_r(@holon_data_path, Path.join(temp_dir, "holons")) do
        {:ok, _} -> :ok
        _ -> throw({:error, :holon_collection_failed})
      end

      # 2. Add Project Context
      File.cp("PROJECT_TODOLIST.md", Path.join(temp_dir, "PROJECT_TODOLIST.md"))

      # 3. Compress & Seal (Quantum Safe)
      Logger.info("🛸 [Ark.Seeder] Sealing payload with Quantum-Safe Vault")
      payload = build_payload(temp_dir)
      {:ok, sealed_data} = QuantumSafe.encrypt(payload)

      # 4. Reify Ark Binary
      # For now, we write to a .ark file. In L10, this will be appended to the F# binary.
      seed_path = "data/seeds/indrajaal_#{timestamp}.ark"
      File.mkdir_p!("data/seeds")
      File.write!(seed_path, sealed_data)

      Logger.info("✅ [Ark.Seeder] Ark Seed reified: #{seed_path}")
      {:ok, seed_path}
    catch
      e ->
        Logger.error("❌ [Ark.Seeder] Seeding failed: #{inspect(e)}")
        e
    after
      File.rm_rf(temp_dir)
    end
  end

  defp build_payload(dir) do
    # Simple JSON-structured payload for the first reification
    # Future versions will use a custom binary format with Reed-Solomon encoding
    %{
      version: "21.3.0-Ark",
      timestamp: DateTime.utc_now(),
      substrate: "linux-x64",
      holons: list_files_recursively(dir) |> Map.new(fn p -> {p, File.read!(p)} end)
    }
    |> Jason.encode!()
  end

  defp list_files_recursively(dir) do
    Path.wildcard("#{dir}/**/*") |> Enum.filter(&(!File.dir?(&1)))
  end
end
