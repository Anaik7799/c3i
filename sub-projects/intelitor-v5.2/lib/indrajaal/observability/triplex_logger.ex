defmodule Indrajaal.Observability.TriplexLogger do
  @moduledoc """
  WHAT: GenServer logger that writes structured log entries to both stdout and a session-scoped log file.
  WHY: Provides a lightweight dual-output logging backend for observability sessions where
       OTEL/SigNoz integration is not required (e.g., lightweight containers or test runs).
  CONSTRAINTS: SC-OBS-069 (dual log: terminal + file)
  """
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    log_path = "logs/triplex-session-#{:os.system_time()}.log"
    File.mkdir_p!(Path.dirname(log_path))
    {:ok, %{log_path: log_path}}
  end

  def handle_info({:log, level, msg, _md}, state) do
    log_string = "[#{level}] #{msg}\n"
    IO.puts(log_string)
    File.write(state.log_path, log_string, [:append])
    # No telemetry or state tracker in triplex
    {:noreply, state}
  end

  def handle_event({level, _group, {Logger, msg, _ts, md}}, state) do
    handle_info({:log, level, msg, md}, state)
  end
end
