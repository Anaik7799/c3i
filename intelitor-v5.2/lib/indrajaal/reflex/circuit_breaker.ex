defmodule Indrajaal.Reflex.CircuitBreaker do
  @moduledoc """
  Automatic fuse for protecting external dependencies.
  Wraps calls and trips on repeated failures.
  """
  require Logger

  # Default: 5 failures in 1 minute
  @fuse_opts {{:standard, 5, 60_000}, {:reset, 30_000}}

  def call(fuse_name, func) do
    case :fuse.ask(fuse_name, :sync) do
      :ok ->
        try do
          result = func.()
          :fuse.melt(fuse_name)
          {:ok, result}
        rescue
          e ->
            :fuse.melt(fuse_name)
            Logger.warning("CircuitBreaker: Call failed for #{fuse_name}")
            {:error, e}
        end

      :blown ->
        Logger.warning("CircuitBreaker: Fast fail for #{fuse_name} (Open)")
        {:error, :circuit_open}
    end
  end

  def setup(fuse_name) do
    :fuse.install(fuse_name, @fuse_opts)
  end
end
