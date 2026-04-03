defmodule Indrajaal.FLAME.SafeRunner do
  @moduledoc """
  Runtime guard for FLAME runners.
  Enforces SC-FLM-001 (No Local State).
  """
  require Logger
  alias Indrajaal.Logging.Control

  def guard_state do
    # Verify no accidental state leakage via Process Dictionary
    keys = Process.get_keys()

    # Filter out standard OTP/BEAM keys
    unsafe_keys =
      Enum.reject(keys, fn k ->
        k in [:"$initial_call", :"$ancestors", :"$callers"]
      end)

    if length(unsafe_keys) > 0 do
      Logger.warning(
        "⚠️ FLAME Runner: Potential State Leakage detected! Keys: #{inspect(unsafe_keys)}"
      )

      # In strict mode, we might raise here
    else
      if Control.should_log?(:flame_runner, :debug) do
        Logger.debug("✅ FLAME Runner: State clean.")
      end
    end

    :ok
  end
end
