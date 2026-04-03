defmodule Indrajaal.Observability.InstrumentationHealth do
  @moduledoc """
  Observability Instrumentation Health Check Module

  ## STAMP Safety Constraint (SC-OBS-001)
  System SHALL have logging and observability enabled for all key operations.
  System SHALL validate OpenTelemetry instrumentation is active at startup.
  System SHALL periodically verify observability pipeline health.
  System SHALL alert when observability components fail to initialize.

  ## TDG Rule (TDG-OBS-001)
  ALL key operations MUST have logging instrumentation.
  ALL key operations MUST have OpenTelemetry tracing enabled.
  Tests MUST validate observability components initialize correctly.
  Periodic health checks MUST verify observability pipeline status.

  ## Usage

      # One-time verification
      Indrajaal.Observability.InstrumentationHealth.verify_all()

      # Start periodic health check (every 5 minutes by default)
      Indrajaal.Observability.InstrumentationHealth.start_periodic_check()

  """

  use GenServer
  require Logger

  @default_interval :timer.minutes(5)

  # Required OpenTelemetry instrumentation modules
  @required_modules [
    {OpentelemetryPhoenix, "Phoenix HTTP tracing"},
    {OpentelemetryEcto, "Database query tracing"},
    {OpentelemetryOban, "Background job tracing"},
    {OpentelemetryFinch, "HTTP client tracing"}
  ]

  # Core observability modules
  @core_observability_modules [
    {Indrajaal.Observability.DualLogging, "Dual logging (Terminal + SigNoz)"},
    {Indrajaal.Observability.LoggerTraceContext, "Logger trace context injection"},
    {Indrajaal.Observability.TelemetryEnhancement, "Telemetry enhancement handlers"}
  ]

  ## Client API

  @doc """
  Verify all OpenTelemetry instrumentation modules are loaded.
  Returns :ok if all modules are available, {:error, failed_modules} otherwise.
  """
  @spec verify_instrumentation() :: :ok | {:error, list()}
  def verify_instrumentation do
    results =
      Enum.map(@required_modules, fn {module, description} ->
        {module, description, Code.ensure_loaded?(module)}
      end)

    failed = Enum.reject(results, fn {_, _, status} -> status end)

    if Enum.empty?(failed) do
      Logger.info("SC-OBS-001: All OpenTelemetry instrumentation modules loaded",
        modules: Enum.map(@required_modules, fn {m, _} -> m end)
      )

      :ok
    else
      failed_list = Enum.map(failed, fn {module, desc, _} -> {module, desc} end)

      Logger.warning("SC-OBS-001 VIOLATION: OpenTelemetry modules not available",
        failed_modules: failed_list
      )

      {:error, failed_list}
    end
  end

  @doc """
  Verify core observability modules are loaded.
  """
  @spec verify_core_observability() :: :ok | {:error, list()}
  def verify_core_observability do
    results =
      Enum.map(@core_observability_modules, fn {module, description} ->
        {module, description, Code.ensure_loaded?(module)}
      end)

    failed = Enum.reject(results, fn {_, _, status} -> status end)

    if Enum.empty?(failed) do
      Logger.info("TDG-OBS-001: All core observability modules loaded",
        modules: Enum.map(@core_observability_modules, fn {m, _} -> m end)
      )

      :ok
    else
      failed_list = Enum.map(failed, fn {module, desc, _} -> {module, desc} end)

      Logger.warning("TDG-OBS-001 VIOLATION: Core observability modules not available",
        failed_modules: failed_list
      )

      {:error, failed_list}
    end
  end

  @doc """
  Verify all observability components (instrumentation + core).
  """
  @spec verify_all() :: :ok | {:error, map()}
  def verify_all do
    instrumentation_result = verify_instrumentation()
    core_result = verify_core_observability()

    case {instrumentation_result, core_result} do
      {:ok, :ok} ->
        Logger.info("Observability health check PASSED",
          instrumentation: :ok,
          core_modules: :ok,
          timestamp: DateTime.utc_now()
        )

        :ok

      _ ->
        errors = %{
          instrumentation: instrumentation_result,
          core_modules: core_result
        }

        Logger.error("Observability health check FAILED", errors: errors)
        {:error, errors}
    end
  end

  @doc """
  Get detailed health status as a map.
  """
  @spec health_status() :: map()
  def health_status do
    instrumentation =
      Enum.map(@required_modules, fn {module, description} ->
        %{
          module: module,
          description: description,
          loaded: Code.ensure_loaded?(module)
        }
      end)

    core =
      Enum.map(@core_observability_modules, fn {module, description} ->
        %{
          module: module,
          description: description,
          loaded: Code.ensure_loaded?(module)
        }
      end)

    all_instrumentation_ok = Enum.all?(instrumentation, & &1.loaded)
    all_core_ok = Enum.all?(core, & &1.loaded)

    %{
      status: if(all_instrumentation_ok and all_core_ok, do: :healthy, else: :degraded),
      instrumentation: %{
        status: if(all_instrumentation_ok, do: :ok, else: :failed),
        modules: instrumentation
      },
      core_observability: %{
        status: if(all_core_ok, do: :ok, else: :failed),
        modules: core
      },
      checked_at: DateTime.utc_now()
    }
  end

  ## GenServer for Periodic Health Checks

  @doc """
  Start the periodic health check GenServer.
  """
  def start_link(opts \\ []) do
    interval = Keyword.get(opts, :interval, @default_interval)
    GenServer.start_link(__MODULE__, %{interval: interval}, name: __MODULE__)
  end

  @doc """
  Start periodic health check as a standalone process (not supervised).
  """
  def start_periodic_check(interval \\ @default_interval) do
    GenServer.start(__MODULE__, %{interval: interval}, name: __MODULE__)
  end

  @doc """
  Stop periodic health check.
  """
  def stop_periodic_check do
    if Process.whereis(__MODULE__) do
      GenServer.stop(__MODULE__)
    end
  end

  @impl true
  def init(%{interval: interval}) do
    Logger.info("Starting observability health check with interval: #{interval}ms")
    # Run initial check immediately
    send(self(), :check)
    {:ok, %{interval: interval}}
  end

  @impl true
  def handle_info(:check, state) do
    # Perform health check
    case verify_all() do
      :ok ->
        :telemetry.execute(
          [:indrajaal, :observability, :health_check],
          %{status: 1},
          %{result: :ok}
        )

      {:error, _errors} ->
        :telemetry.execute(
          [:indrajaal, :observability, :health_check],
          %{status: 0},
          %{result: :failed}
        )
    end

    # Schedule next check
    Process.send_after(self(), :check, state.interval)
    {:noreply, state}
  end
end
