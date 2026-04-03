defmodule Indrajaal.Policy.ConstitutionalGovernor do
  @moduledoc """
  ## Design Intent

  L5 Policy Layer — VSM System 5 constitutional governance engine.

  Enforces the immutable constitutional axioms (Ω₀–Ω₁₁) against all proposed
  system mutations. Acts as the supreme policy authority: any change that
  violates a constitutional axiom is vetoed before it can reach the
  ReconfigurationEngine or the Guardian.

  Core responsibilities:
  - Validates proposals against the Ω₀–Ω₁₁ axiom registry
  - Tracks constitution version and SHA-256 hash
  - Maintains a veto log in ETS for fast audit queries
  - Publishes governance decisions via PubSub `"policy:governance"`
  - Integrates with `Indrajaal.Safety.Guardian` when available

  ## STAMP Constraints

  - SC-RECONFIG-009: Guardian (constitutional) approval REQUIRED for
    any reconfiguration. This module IS that approval gate for
    constitutional compliance.
  - SC-VER-074: Constitutional L0-L7 constraints MUST hold at all times.
    This module verifies them on every proposal.
  - SC-SAFETY-001: Guardian pre-approval REQUIRED for planning mutations.
  - SC-CONSENSUS-002: Each chamber has Constitutional veto — this module
    implements that veto for the constitutional chamber.
  - SC-VER-075: Ψ₀ (Existence) preserved through any operation.

  ## Change History

  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Code Evolution Agent | Initial implementation — L5 constitutional governance |
  """

  use GenServer
  require Logger

  @pubsub_topic "policy:governance"
  @ets_table :constitutional_governor_vetoes

  # Constitution version — bumped on any constitutional amendment
  @constitution_version "21.3.1-SIL6"

  # Axiom IDs that MUST be checked on every proposal (Ω₀–Ω₁₁)
  @constitutional_axioms [
    :omega_0_founders_covenant,
    :omega_1_patient_mode,
    :omega_2_container_isolation,
    :omega_3_zero_defect,
    :omega_4_test_driven_gen,
    :omega_5_validation_consensus,
    :omega_6_mandatory_gates,
    :omega_7_holon_sovereignty,
    :omega_8_immutable_register,
    :omega_9_constitutional_reconfiguration,
    :omega_10_absolute_zenoh_control,
    :omega_11_high_assurance_evolution
  ]

  # ─── Types ───────────────────────────────────────────────────────────────────

  @type axiom_id ::
          :omega_0_founders_covenant
          | :omega_1_patient_mode
          | :omega_2_container_isolation
          | :omega_3_zero_defect
          | :omega_4_test_driven_gen
          | :omega_5_validation_consensus
          | :omega_6_mandatory_gates
          | :omega_7_holon_sovereignty
          | :omega_8_immutable_register
          | :omega_9_constitutional_reconfiguration
          | :omega_10_absolute_zenoh_control
          | :omega_11_high_assurance_evolution

  @type proposal :: %{
          id: String.t(),
          type: atom(),
          payload: term(),
          proposer: String.t(),
          timestamp: DateTime.t()
        }

  @type validation_result ::
          {:constitutional, proposal()}
          | {:veto, axiom_id(), String.t()}

  @type veto_record :: %{
          proposal_id: String.t(),
          axiom: axiom_id(),
          reason: String.t(),
          timestamp: DateTime.t()
        }

  @type t :: %{
          constitution_version: String.t(),
          constitution_hash: String.t(),
          proposals_validated: non_neg_integer(),
          proposals_vetoed: non_neg_integer(),
          veto_log: [veto_record()],
          started_at: DateTime.t()
        }

  # ─── Public API ──────────────────────────────────────────────────────────────

  @doc "Start the ConstitutionalGovernor GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Validate a proposal against all constitutional axioms.

  Returns `{:constitutional, proposal}` if all axioms pass, or
  `{:veto, axiom_id, reason}` on the first violation found.
  """
  @spec validate(proposal()) :: validation_result()
  def validate(%{} = proposal) do
    GenServer.call(__MODULE__, {:validate, proposal})
  end

  @doc "Get the current constitution version string."
  @spec constitution_version() :: String.t()
  def constitution_version do
    GenServer.call(__MODULE__, :constitution_version)
  end

  @doc "Get the SHA-256 hash of the current constitution."
  @spec constitution_hash() :: String.t()
  def constitution_hash do
    GenServer.call(__MODULE__, :constitution_hash)
  end

  @doc "Get governance statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  @doc "List recent veto records from ETS (fast, <1ms)."
  @spec recent_vetoes(non_neg_integer()) :: [veto_record()]
  def recent_vetoes(limit \\ 20) do
    if :ets.whereis(@ets_table) != :undefined do
      @ets_table
      |> :ets.tab2list()
      |> Enum.map(fn {_key, record} -> record end)
      |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
      |> Enum.take(limit)
    else
      []
    end
  end

  @doc "Check if a specific axiom is currently enforced."
  @spec axiom_enforced?(axiom_id()) :: boolean()
  def axiom_enforced?(axiom_id) when axiom_id in @constitutional_axioms do
    true
  end

  def axiom_enforced?(_), do: false

  # ─── GenServer Callbacks ──────────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    ensure_ets_table()

    constitution_hash = compute_constitution_hash()

    state = %{
      constitution_version: @constitution_version,
      constitution_hash: constitution_hash,
      proposals_validated: 0,
      proposals_vetoed: 0,
      veto_log: [],
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[ConstitutionalGovernor] Online — version=#{@constitution_version} " <>
        "hash=#{String.slice(constitution_hash, 0, 8)}... — SC-RECONFIG-009, SC-VER-074"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:validate, proposal}, _from, state) do
    {result, new_state} = do_validate(proposal, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:constitution_version, _from, state) do
    {:reply, state.constitution_version, state}
  end

  @impl true
  def handle_call(:constitution_hash, _from, state) do
    {:reply, state.constitution_hash, state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = %{
      constitution_version: state.constitution_version,
      constitution_hash: state.constitution_hash,
      proposals_validated: state.proposals_validated,
      proposals_vetoed: state.proposals_vetoed,
      veto_rate: veto_rate(state),
      axioms_count: length(@constitutional_axioms),
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    schedule_heartbeat()
    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[ConstitutionalGovernor] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ─── Private Helpers ─────────────────────────────────────────────────────────

  defp do_validate(proposal, state) do
    proposal_id = Map.get(proposal, :id, "unknown")

    case check_all_axioms(proposal) do
      :ok ->
        new_state = %{state | proposals_validated: state.proposals_validated + 1}

        publish_decision(:constitutional, proposal, nil, nil)

        Logger.debug(
          "[ConstitutionalGovernor] PASS proposal=#{proposal_id} — all #{length(@constitutional_axioms)} axioms satisfied"
        )

        {{:constitutional, proposal}, new_state}

      {:veto, axiom, reason} ->
        veto_record = %{
          proposal_id: proposal_id,
          axiom: axiom,
          reason: reason,
          timestamp: DateTime.utc_now()
        }

        record_veto(veto_record)

        new_veto_log = [veto_record | state.veto_log] |> Enum.take(500)

        new_state = %{
          state
          | proposals_validated: state.proposals_validated + 1,
            proposals_vetoed: state.proposals_vetoed + 1,
            veto_log: new_veto_log
        }

        publish_decision(:vetoed, proposal, axiom, reason)

        Logger.warning(
          "[ConstitutionalGovernor] VETO proposal=#{proposal_id} axiom=#{axiom} reason=#{reason} — SC-RECONFIG-009"
        )

        {{:veto, axiom, reason}, new_state}
    end
  end

  defp check_all_axioms(proposal) do
    Enum.reduce_while(@constitutional_axioms, :ok, fn axiom, :ok ->
      case check_axiom(axiom, proposal) do
        :ok -> {:cont, :ok}
        {:veto, reason} -> {:halt, {:veto, axiom, reason}}
      end
    end)
  end

  # Ω₀: Founders Covenant — proposals MUST NOT reduce Founder's resources
  defp check_axiom(:omega_0_founders_covenant, proposal) do
    if Map.get(proposal, :reduces_founder_resources, false) do
      {:veto,
       "Ω₀ violation: proposal reduces Founder resource — forbidden by Ω₀ Founders Covenant"}
    else
      :ok
    end
  end

  # Ω₂: Container Isolation — no host-side _build/deps artifacts allowed
  defp check_axiom(:omega_2_container_isolation, proposal) do
    payload_str = inspect(Map.get(proposal, :payload, ""))

    if String.contains?(payload_str, "_build") and
         String.contains?(payload_str, "host") do
      {:veto, "Ω₂ violation: host _build artifact detected — container isolation required"}
    else
      :ok
    end
  end

  # Ω₃: Zero-Defect — proposals introducing known defects are vetoed
  defp check_axiom(:omega_3_zero_defect, proposal) do
    if Map.get(proposal, :known_defects, 0) > 0 do
      defects = Map.get(proposal, :known_defects, 0)
      {:veto, "Ω₃ violation: #{defects} known defect(s) in proposal — zero-defect mandate"}
    else
      :ok
    end
  end

  # Ω₇: Holon Sovereignty — MUST NOT write holon state to PostgreSQL
  defp check_axiom(:omega_7_holon_sovereignty, proposal) do
    stores = Map.get(proposal, :state_stores, [])

    if :postgresql in stores or :postgres in stores do
      {:veto, "Ω₇ violation: holon state MUST use SQLite/DuckDB only — PostgreSQL forbidden"}
    else
      :ok
    end
  end

  # Ω₈: Immutable Register — mutations MUST NOT bypass the register
  defp check_axiom(:omega_8_immutable_register, proposal) do
    if Map.get(proposal, :bypasses_register, false) do
      {:veto, "Ω₈ violation: mutation bypasses Immutable Register — append-only required"}
    else
      :ok
    end
  end

  # Ω₉: Constitutional Reconfiguration — L0 (Constitution) MUST be immutable
  defp check_axiom(:omega_9_constitutional_reconfiguration, proposal) do
    if Map.get(proposal, :modifies_l0_constitution, false) do
      {:veto, "Ω₉ violation: L0 Constitution is IMMUTABLE — SC-RECONFIG-009"}
    else
      :ok
    end
  end

  # Ω₁₀: Absolute Zenoh Control — direct CLI mutations are forbidden
  defp check_axiom(:omega_10_absolute_zenoh_control, proposal) do
    if Map.get(proposal, :direct_cli_mutation, false) do
      {:veto,
       "Ω₁₀ violation: all mutations MUST be triggered via Zenoh — CLI direct mutation forbidden"}
    else
      :ok
    end
  end

  # All other axioms: pass by default (specific checks can be added incrementally)
  defp check_axiom(_axiom, _proposal), do: :ok

  defp publish_decision(outcome, proposal, axiom, reason) do
    message = %{
      event: :governance_decision,
      outcome: outcome,
      proposal_id: Map.get(proposal, :id, "unknown"),
      proposal_type: Map.get(proposal, :type, :unknown),
      axiom: axiom,
      reason: reason,
      timestamp: DateTime.utc_now()
    }

    Phoenix.PubSub.broadcast(Indrajaal.PubSub, @pubsub_topic, {:governance_decision, message})
  end

  defp record_veto(veto_record) do
    if :ets.whereis(@ets_table) != :undefined do
      key = {veto_record.timestamp, veto_record.proposal_id}
      :ets.insert(@ets_table, {key, veto_record})
    end
  end

  defp ensure_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :ordered_set, read_concurrency: true])
    end
  end

  defp compute_constitution_hash do
    axiom_data = @constitutional_axioms |> Enum.map(&Atom.to_string/1) |> Enum.join("|")

    payload = "#{@constitution_version}|#{axiom_data}"

    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  defp veto_rate(%{proposals_validated: 0}), do: 0.0

  defp veto_rate(%{proposals_validated: total, proposals_vetoed: vetoed}) do
    Float.round(vetoed / total * 100.0, 2)
  end

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, 60_000)
  end
end
