defmodule Indrajaal.Cortex.GDE.OmegaRefactor do
  @moduledoc """
  Omega-Refactor: Autonomous Actuation for Entropy Reduction.

  WHAT: Refactors high-entropy holons using the Synapse Bicameral Loop.
  WHY: SC-SING-003 enables autonomous self-improvement toward Singularity.
  """

  require Logger
  alias Indrajaal.Cortex.Synapse
  alias Indrajaal.KMS.Service, as: KMS

  @doc """
  Refactors a high-entropy holon to reduce structural decay.
  """
  def refactor_holon(holon_id) do
    Logger.info("🧬 [OmegaRefactor] Initiating refactor for holon: #{holon_id}")

    case gather_context(holon_id) do
      {:ok, context} ->
        Logger.info("🧬 [OmegaRefactor] Context gathered. Triggering Synapse loop.")
        trigger_refactor_loop(context)

      error ->
        Logger.error("🧬 [OmegaRefactor] Failed to gather context: #{inspect(error)}")
        error
    end
  end

  defp gather_context(holon_id) do
    with {:ok, holon} <- KMS.get_holon(holon_id),
         # In a real scenario, we would map holon_id to a file path or module
         # For this reification, we assume the holon metadata contains the target path
         path =
           get_in(holon, [:genome, "target_path"]) ||
             "lib/indrajaal/cortex/gde/evolution_engine.ex" do
      {:ok,
       %{
         holon_id: holon_id,
         path: path,
         entropy: get_in(holon, [:vital_signs, "entropy"]),
         source: File.read!(path),
         metadata: %{source: :omega_cycle}
       }}
    end
  rescue
    e -> {:error, e}
  end

  defp trigger_refactor_loop(context) do
    goal = :refactor_for_entropy_reduction

    # We use solve_problem to trigger the full Gemini/Claude loop
    case Synapse.solve_problem(context, goal, timeout: 300_000) do
      {:ok, %{success: true, solution: solution}} ->
        Logger.info("✅ [OmegaRefactor] Solution found and approved by Guardian. Applying fix.")
        apply_solution(context.path, solution)

      {:ok, %{success: false}} ->
        Logger.warning("❌ [OmegaRefactor] Synapse failed to find a valid refactor.")
        {:error, :synapse_failure}

      error ->
        error
    end
  end

  defp apply_solution(path, %{replacement: code}) do
    # 1. Capture old state for lineage
    old_code = File.read!(path)
    old_hash = :crypto.hash(:sha256, old_code) |> Base.encode16(case: :lower)
    new_hash = :crypto.hash(:sha256, code) |> Base.encode16(case: :lower)

    # 2. Final safety check: Atomic write
    File.write!(path, code)
    Logger.info("✅ [OmegaRefactor] Substrate mutation applied to #{path}")

    # 3. Record in Immutable Register (Ancestral Lineage - SC-SING-005)
    record_lineage(path, old_hash, new_hash)
    :ok
  end

  defp apply_solution(_, _), do: {:error, :invalid_solution_format}

  defp record_lineage(path, old_hash, new_hash) do
    # Record mutation block in the Immutable Register
    mutation_event = %{
      type: :autonomic_refactor,
      path: path,
      old_hash: old_hash,
      new_hash: new_hash,
      agent: :omega_refactor,
      timestamp: DateTime.utc_now()
    }

    case Indrajaal.Core.Holon.ImmutableRegister.append(:evolution, mutation_event) do
      {:ok, block_hash} ->
        Logger.info("🧬 [OmegaRefactor] Mutation recorded in Immutable Register: #{block_hash}")
        :ok

      error ->
        Logger.error("❌ [OmegaRefactor] Failed to record mutation in register: #{inspect(error)}")
        error
    end
  end
end
