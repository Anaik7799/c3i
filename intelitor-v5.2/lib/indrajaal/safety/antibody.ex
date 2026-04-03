defmodule Indrajaal.Safety.Antibody do
  @moduledoc """
  Antibody: The Targeted Threat Neutralizer (Effector).

  WHAT: Executes specific neutralization strategies against identified threats.
  WHY: Sentinel identifies threats, but Antibody eliminates them.

  LIFECYCLE (Biomorphic):
  1. Search: Locate the specific PID/entity matching the threat signature.
  2. Bind: Attach/Link to the target.
  3. Opsonize: Mark the target for cleanup/logging.
  4. Neutralize: Suspend or Terminate.
  5. Die: Process exit (Ephemeral).

  CONSTRAINTS:
  - SC-IMMUNE-005: Targeted Response.
  - SC-ACT-001: Actuator Limits (Physics).
  """

  use GenServer
  require Logger

  alias Indrajaal.Safety.Guardian

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Spawns an ephemeral Antibody to neutralize a specific threat.
  """
  @spec deploy(map()) :: {:ok, pid()} | {:error, term()}
  def deploy(threat_info) do
    GenServer.start_link(__MODULE__, threat_info)
  end

  # ============================================================
  # SERVER CALLBACKS
  # ============================================================

  @impl true
  def init(threat) do
    Logger.info("[Antibody] Deployed against threat: #{inspect(threat)}")

    # Execute lifecycle immediately
    send(self(), :execute_lifecycle)

    {:ok, %{threat: threat, status: :searching}}
  end

  @impl true
  def handle_info(:execute_lifecycle, state) do
    with :ok <- search(state),
         :ok <- bind(state),
         :ok <- neutralize(state) do
      Logger.info("[Antibody] Threat neutralized. Dissolving.")
      {:stop, :normal, state}
    else
      {:error, reason} ->
        Logger.error("[Antibody] Failed to neutralize: #{inspect(reason)}")
        {:stop, :failure, state}
    end
  end

  # ============================================================
  # PHASES
  # ============================================================

  defp search(%{threat: %{source: pid}}) when is_pid(pid) do
    if Process.alive?(pid) do
      Logger.debug("[Antibody] Target locked: #{inspect(pid)}")
      :ok
    else
      {:error, :target_not_found}
    end
  end

  defp search(_), do: {:error, :invalid_target}

  defp bind(_state) do
    # In a real system, we might link or monitor here
    :ok
  end

  defp neutralize(%{threat: %{source: pid, type: type}} = _state) do
    # SC-ACT-001: Check physics/limits via Guardian before actuation
    proposal = %{
      action: :neutralize_threat,
      target: pid,
      method: if(type == :critical, do: :kill, else: :suspend)
    }

    case Guardian.validate_proposal(proposal) do
      {:ok, _} ->
        perform_actuation(proposal)

      {:veto, reason, _} ->
        {:error, {:guardian_veto, reason}}

      {:error, reason} ->
        {:error, {:guardian_error, reason}}
    end
  end

  defp perform_actuation(%{method: :kill, target: pid}) do
    Process.exit(pid, :kill)
    :ok
  end

  defp perform_actuation(%{method: :suspend, target: pid}) do
    try do
      :erlang.suspend_process(pid)
      :ok
    rescue
      _ -> {:error, :suspend_failed}
    end
  end
end
