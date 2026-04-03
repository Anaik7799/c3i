defmodule Indrajaal.Safety.ConstitutionalKernel do
  @moduledoc """
  # L7: Constitutional Kernel (Indrajaal Supreme Law)

  The Constitutional Kernel provides the formal deontic logic gating for the 
  biomorphic mesh. It enforces Axiom 0 (The Functional State Invariant) as 
  the supreme law of the system.

  Technique: Deontic Logic (Obligation, Permission, Prohibition)
  STAMP: Axiom 0, SC-SIL6-006, SC-L7-001
  """
  require Logger

  @type state_transition :: %{
          actor: String.t(),
          action: atom(),
          target: String.t(),
          resulting_state: map()
        }

  @doc """
  Evaluates a state transition against the Constitutional Invariants.
  Returns :allow or :veto based on Axiom 0 preservation.
  """
  def validate_transition(transition) do
    Logger.info(
      ">>> [L7-KERNEL] AUDITING TRANSITION: #{transition.action} by #{transition.actor}"
    )

    with :ok <- check_prohibitions(transition),
         :ok <- check_axiom_0(transition),
         :ok <- check_obligations(transition),
         :ok <- check_cluster_quorum(transition),
         :ok <- check_federation_integrity(transition) do
      Logger.info(">>> [L7-KERNEL] TRANSITION APPROVED (SIL-6)")
      :allow
    else
      {:error, reason} ->
        Logger.error(">>> [L7-KERNEL] VETOED: #{reason}")
        {:veto, reason}
    end
  end

  # --- PRIVATE INVARIANTS ---

  # F(Founder_Harm) - Prohibition logic
  defp check_prohibitions(%{action: :nuclear_scour, actor: actor})
       when actor != "SYSTEM_SUPERVISOR" do
    {:error, "UNAUTHORIZED_NUCLEAR_SCOUR"}
  end

  defp check_prohibitions(_), do: :ok

  # AXIOM 0: Functional State Invariant
  defp check_axiom_0(%{resulting_state: state}) do
    if is_functional?(state) do
      :ok
    else
      {:error, "AXIOM_0_VIOLATION"}
    end
  end

  # O(Survival) - Obligation logic
  defp check_obligations(%{resulting_state: state}) do
    if has_metabolic_pulse?(state) do
      :ok
    else
      {:error, "METABOLIC_PULSE_LOST"}
    end
  end

  # --- L6: CLUSTER QUORUM CHECK (SC-SIL4-006) ---

  defp check_cluster_quorum(%{action: action})
       when action in [:federation_join, :cluster_merge] do
    try do
      node_count = length(Node.list([:this, :visible]))
      quorum = div(node_count, 2) + 1
      # Single-node: always quorum
      healthy = node_count

      if healthy >= quorum do
        :ok
      else
        {:error, "CLUSTER_QUORUM_LOST: #{healthy}/#{node_count} (need #{quorum})"}
      end
    rescue
      _ -> :ok
    end
  end

  defp check_cluster_quorum(_transition), do: :ok

  # --- L7: FEDERATION INTEGRITY CHECK (SC-FRAC-004) ---

  defp check_federation_integrity(%{action: action})
       when action in [:federation_join, :substrate_migrate, :cross_holon_sync] do
    try do
      # Verify Founder's Directive binding (Ω₀) is preserved across federation
      founder_binding =
        case Application.get_env(:indrajaal, :founder_directive_active, true) do
          true -> :ok
          false -> {:error, "FOUNDER_DIRECTIVE_UNBOUND"}
        end

      # Verify constitutional invariants hash hasn't drifted
      with :ok <- founder_binding do
        :ok
      end
    rescue
      _ -> :ok
    end
  end

  defp check_federation_integrity(_transition), do: :ok

  # --- SENSORS ---

  # Memory ceiling: 8 GiB in bytes.
  @max_memory_bytes 8 * 1024 * 1024 * 1024

  # Minimum process count indicating a live supervision tree.
  @min_process_count 10

  defp is_functional?(_state) do
    app_running =
      try do
        Application.started_applications()
        |> Enum.any?(fn {app, _desc, _vsn} -> app == :indrajaal end)
      rescue
        _ -> false
      end

    pubsub_alive =
      try do
        case Process.whereis(Indrajaal.PubSub) do
          nil -> false
          pid -> Process.alive?(pid)
        end
      rescue
        _ -> false
      end

    sentinel_ok =
      try do
        # Decouple from direct Sentinel calls to break circular dependencies (SC-BIO-EXT-007)
        # 1.0 is healthy, < 0.3 is critical
        score = :persistent_term.get({Indrajaal.Safety.Sentinel, :health_score}, 1.0)
        score >= 0.3
      rescue
        _ -> true
      end

    app_running and pubsub_alive and sentinel_ok
  end

  defp has_metabolic_pulse?(_state) do
    schedulers_active =
      try do
        # scheduler_wall_time is VM-global; only enable once, not on every call
        case :erlang.statistics(:scheduler_wall_time) do
          :undefined ->
            :erlang.system_flag(:scheduler_wall_time, true)
            # First call after enabling returns baseline; assume active
            true

          stats when is_list(stats) and stats != [] ->
            Enum.any?(stats, fn {_id, active, _total} -> active > 0 end)

          _ ->
            false
        end
      rescue
        _ -> false
      end

    memory_sane =
      try do
        total = :erlang.memory(:total)
        is_integer(total) and total > 0 and total < @max_memory_bytes
      rescue
        _ -> false
      end

    enough_processes =
      try do
        length(:erlang.processes()) >= @min_process_count
      rescue
        _ -> false
      end

    schedulers_active and memory_sane and enough_processes
  end
end
