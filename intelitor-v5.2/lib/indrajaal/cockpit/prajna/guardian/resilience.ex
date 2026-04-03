defmodule Indrajaal.Cockpit.Prajna.Guardian.Resilience do
  @moduledoc """
  Handles resilience for the Guardian system, including timeouts and fallbacks.
  STAMP: SC-SIL4-001
  """
  require Logger

  @default_timeout 5000

  def with_timeout(task_fn, timeout \\ @default_timeout) do
    task = Task.async(task_fn)

    try do
      Task.await(task, timeout)
    catch
      :exit, {:timeout, _} ->
        Task.shutdown(task, :brutal_kill)
        Logger.error("Guardian task timed out after #{timeout}ms")
        {:error, :timeout}
    end
  end
end
