defmodule Indrajaal.Observability.KMSLoggerBackend do
  @moduledoc """
  KMS Logger Backend (L1 -> L2 Persistence).
  Writes all Elixir logs to the Fractal Execution Log.
  Context: SIL-6 Observability.
  """
  @behaviour :gen_event

  def init(_args) do
    path = "data/kms/fractal_execution.log"
    File.mkdir_p!(Path.dirname(path))
    {:ok, %{path: path}}
  end

  def handle_event({level, _gl, {Logger, msg, ts, _md}}, state) do
    write_log(level, msg, ts, state.path)
    {:ok, state}
  end

  def handle_event(_, state), do: {:ok, state}

  def handle_call(_, state), do: {:ok, :ok, state}
  def handle_info(_, state), do: {:ok, state}
  def terminate(_, _state), do: :ok
  def code_change(_old, state, _extra), do: {:ok, state}

  defp write_log(level, msg, {{y, m, d}, {h, min, s, _}}, path) do
    timestamp =
      :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B.000", [y, m, d, h, min, s])

    # Format: [TIMESTAMP] [LEVEL] [CONTEXT] Message
    # We map Elixir metadata to Context if possible, otherwise use "ELIXIR"
    formatted = "[#{timestamp}] [#{String.upcase(Atom.to_string(level))}] [ELIXIR] #{msg}\n"
    File.write(path, formatted, [:append])
  rescue
    # Fail safe
    _ -> :ok
  end
end
