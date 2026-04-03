defmodule Indrajaal.Cortex do
  @moduledoc """
  Cortex main module - system-wide status and coordination.

  WHAT: Provides the central Cortex system status interface and health monitoring.
  WHY: Required by cockpit modules for system health monitoring and orchestration.
  CONSTRAINTS: SC-CTX-001 (supervised components), SC-OODA-001 (50ms cycles)

  ## Architecture

  The Cortex is the cognitive center of the Indrajaal system, managing:
  - Self-healing capabilities (Indrajaal.Cortex.SelfHealing)
  - Predictive analysis (Indrajaal.Cortex.Predictor)
  - Fast OODA loops for CAE (Indrajaal.Cortex.FastOODA)
  - AI integration (OpenRouter/Claude/Gemini interfaces)

  ## Document Control

  | Field | Value |
  |-------|-------|
  | Version | 2.0.0 |
  | Updated | 2026-01-21 |
  | Author | Claude Opus 4.5 |
  | STAMP | SC-CTX-001 to SC-CTX-004, SC-AI-001 |
  """
  require Logger

  @cortex_container_url "http://indrajaal-cortex:9877"
  @health_timeout 3_000

  @type cortex_status :: :initializing | :running | :degraded | :stopped

  @doc """
  Returns the current status of the Cortex system.

  Status is determined by checking the health of all Cortex components:
  - :running - All components healthy
  - :degraded - Some components unhealthy but core functions operational
  - :initializing - Supervisor starting up
  - :stopped - Supervisor not running

  ## Examples

      iex> Indrajaal.Cortex.status()
      :running

  """
  @spec status() :: cortex_status()
  def status do
    case Process.whereis(Indrajaal.Cortex.Supervisor) do
      nil ->
        :stopped

      pid when is_pid(pid) ->
        determine_status_from_components()
    end
  end

  @doc """
  Returns detailed health information for all Cortex components.

  ## Returns
  Map with component health details:
  - supervisor_alive: boolean
  - self_healing: :healthy | :unhealthy | :not_running
  - predictor: :healthy | :unhealthy | :not_running
  - fast_ooda: :healthy | :unhealthy | :not_running | :disabled
  - overall_status: cortex_status()

  ## Examples

      iex> Indrajaal.Cortex.health()
      %{
        supervisor_alive: true,
        self_healing: :healthy,
        predictor: :healthy,
        fast_ooda: :healthy,
        overall_status: :running
      }
  """
  @spec health() :: map()
  def health do
    supervisor_alive = Process.whereis(Indrajaal.Cortex.Supervisor) != nil
    self_healing_status = check_component_health(Indrajaal.Cortex.SelfHealing)
    predictor_status = check_component_health(Indrajaal.Cortex.Predictor)
    fast_ooda_status = check_fast_ooda_health()

    overall =
      determine_overall_status(
        supervisor_alive,
        self_healing_status,
        predictor_status,
        fast_ooda_status
      )

    %{
      supervisor_alive: supervisor_alive,
      self_healing: self_healing_status,
      predictor: predictor_status,
      fast_ooda: fast_ooda_status,
      overall_status: overall,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Checks if the Cortex is ready to accept AI requests.

  ## Returns
  - true if Cortex is running and can process requests
  - false otherwise
  """
  @spec ready?() :: boolean()
  def ready? do
    status() == :running
  end

  # Private: Determine status from components
  defp determine_status_from_components do
    # Check critical components
    self_healing_alive = Process.whereis(Indrajaal.Cortex.SelfHealing) != nil
    predictor_alive = Process.whereis(Indrajaal.Cortex.Predictor) != nil

    cond do
      self_healing_alive and predictor_alive ->
        :running

      self_healing_alive or predictor_alive ->
        # At least one critical component running
        :degraded

      true ->
        # Supervisor running but no children (starting up)
        :initializing
    end
  end

  # Private: Check individual component health
  defp check_component_health(module) do
    case Process.whereis(module) do
      nil ->
        :not_running

      pid when is_pid(pid) ->
        # Check if process is alive and responsive
        try do
          case GenServer.call(pid, :ping, 1000) do
            :pong -> :healthy
            _ -> :unhealthy
          end
        catch
          :exit, _ -> :unhealthy
          _, _ -> :unhealthy
        end
    end
  rescue
    _ -> :unhealthy
  end

  # Private: Check FastOODA health (may be disabled by config)
  defp check_fast_ooda_health do
    fast_ooda_config = Application.get_env(:indrajaal, Indrajaal.Cortex.FastOODA, [])
    enabled = Keyword.get(fast_ooda_config, :enabled, true)

    if enabled do
      check_component_health(Indrajaal.Cortex.FastOODA)
    else
      :disabled
    end
  end

  @doc """
  Check if the remote F# Cortex container is reachable.

  Returns health status from the container at http://indrajaal-cortex:9877/health.
  Falls back gracefully when the container is unavailable.
  """
  @spec remote_health() :: {:ok, map()} | {:error, :unavailable}
  def remote_health do
    url = @cortex_container_url <> "/health"

    case :httpc.request(:get, {String.to_charlist(url), []}, [{:timeout, @health_timeout}], []) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        case Jason.decode(to_string(body)) do
          {:ok, data} -> {:ok, data}
          _ -> {:ok, %{"status" => "ok"}}
        end

      _ ->
        {:error, :unavailable}
    end
  rescue
    _ -> {:error, :unavailable}
  end

  @doc """
  Returns combined health including remote Cortex container status.
  """
  @spec full_health() :: map()
  def full_health do
    local = health()
    remote = remote_health()

    remote_status =
      case remote do
        {:ok, _data} -> :connected
        {:error, :unavailable} -> :unavailable
      end

    Map.merge(local, %{
      remote_cortex: remote_status,
      remote_url: @cortex_container_url
    })
  end

  # Private: Determine overall status from component statuses
  defp determine_overall_status(supervisor_alive, self_healing, predictor, fast_ooda) do
    cond do
      not supervisor_alive ->
        :stopped

      self_healing == :healthy and predictor == :healthy and fast_ooda in [:healthy, :disabled] ->
        :running

      self_healing in [:healthy, :not_running] and predictor in [:healthy, :not_running] ->
        if self_healing == :not_running and predictor == :not_running do
          :initializing
        else
          :degraded
        end

      true ->
        :degraded
    end
  end
end
