defmodule Indrajaal.Observability.QuadplexLogger do
  @moduledoc """
  Quadplex logging GenServer that writes logs to file, emits telemetry,
  and records to StateTracker.

  WHAT: Multi-output log handler (file + telemetry + state tracker)
  WHY: SC-OBS-069 requires dual logging (Terminal + SigNoz/OTEL)
  CONSTRAINTS: SC-OBS-069, SC-OBS-071
  """

  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_opts) do
    log_path = "logs/session-#{:os.system_time()}.log"
    File.mkdir_p!(Path.dirname(log_path))
    {:ok, %{log_path: log_path}}
  end

  def handle_info({:log, level, msg, md}, state) do
    log_string = "[#{level}] #{msg}\n"
    Logger.debug(log_string)
    File.write(state.log_path, log_string, [:append])
    :telemetry.execute([:quadplex, :log, level], %{count: 1}, Map.put(md, :message, msg))
    Indrajaal.Observability.StateTracker.record_log(level, to_string(msg), Map.new(md))
    {:noreply, state}
  end

  def handle_event({level, _group, {Logger, msg, _ts, md}}, state) do
    # This remains for compatibility if directly used by Logger backend
    handle_info({:log, level, msg, md}, state)
  end
end
