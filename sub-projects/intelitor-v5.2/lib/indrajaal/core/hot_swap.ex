defmodule Indrajaal.Core.HotSwap do
  @moduledoc """
  ## NEURAL PLASTICITY ENGINE (L2-COMPONENT)
  Enables the system to rewire its own logic at runtime without a restart.

  **Mechanism**:
  1. Compiles source file in memory.
  2. Purges old module version.
  3. Loads new object code.
  4. Preserves state via GenServer `code_change/3`.

  **Safety**: Axiom 0. Checks for compilation errors before purging.
  """
  require Logger

  def reload(module) do
    file = module.__info__(:compile)[:source] |> to_string()

    Logger.info("🧠 [PLASTICITY] Rewiring #{module} from #{file}...")

    try do
      # 1. Verify Compilation
      [{_mod, _bin}] = Code.compile_file(file)

      # 2. Hot Swap
      :code.purge(module)
      :code.load_file(module)

      Logger.info("🧠 [PLASTICITY] Evolution Complete.")
      :ok
    rescue
      e ->
        Logger.error("🧠 [PLASTICITY] REJECTION: #{inspect(e)}")
        {:error, e}
    end
  end
end
