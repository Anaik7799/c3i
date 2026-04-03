defmodule Indrajaal.Core.VSM.Supervisor do
  @moduledoc """
  VSM (Viable System Model) Supervisor — Systems 1–5 supervision tree.

  Implements Beer's VSM hierarchy:
  - System 1: Operations (pure functional module — no process)
  - System 2: Coordination (GenServer — anti-oscillation PubSub gossip)
  - System 3: Control (pure functional module — no process)
  - System 3*: Sporadic Audit (GenServer — 30s deep-dive audits)
  - System 4: Intelligence (pure functional module — no process)
  - System 5: Policy (pure functional module — no process)

  System 2 (`System2Coordinator`) and System 3* (`System3StarAudit`) run
  as supervised processes. Systems 1, 3, 4, and 5 are pure functional
  modules and require no child specification.

  ## STAMP Constraints
  - SC-MORPH-001: Stage N depends on Stage N-1
  - SC-VSM-001: All 5 systems MUST be supervised (or confirmed stateless)
  - SC-S2-001: Coordination MUST NOT block S1 operations
  - SC-PRF-055: No blocking operations in supervision path

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.2.1 | 2026-03-21 | Claude | Add System3StarAudit to supervision tree |
  | 21.2.1 | 2026-03-19 | Claude | Initial implementation (GAP-P2-004) |
  """

  use Supervisor

  require Logger

  alias Indrajaal.Core.VSM.System2Coordinator
  alias Indrajaal.Core.VSM.System3StarAudit

  @doc """
  Starts the VSM supervision tree.

  ## Options
  - `:holon_id` – identifier for this holon (passed to System2Coordinator, default: node name)
  - `:gossip_interval_ms` – gossip period for System2Coordinator (default: 5000)
  - `:name` – registered name for this supervisor (default: `__MODULE__`)
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    {name_opts, init_opts} = Keyword.split(opts, [:name])
    name = Keyword.get(name_opts, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, init_opts, name: name)
  end

  @impl Supervisor
  def init(opts) do
    holon_id = Keyword.get(opts, :holon_id, to_string(node()))
    gossip_interval_ms = Keyword.get(opts, :gossip_interval_ms, 5_000)

    Logger.info("[VSM.Supervisor] starting VSM systems for holon=#{holon_id}")

    children = [
      # System 2: Coordination (anti-oscillation PubSub gossip)
      {System2Coordinator,
       [
         holon_id: holon_id,
         gossip_interval_ms: gossip_interval_ms,
         name: System2Coordinator
       ]},
      # System 3*: Sporadic Audit (30s deep-dive checks)
      {System3StarAudit, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns aggregated VSM health status across all five systems.

  Queries the live System2Coordinator for dynamic state and reports
  Systems 1, 3, 4, and 5 as always `:functional` (pure modules).
  """
  @spec status() :: map()
  def status do
    system2_info = safe_system2_summary()

    %{
      vsm: :operational,
      systems: %{
        system1: %{status: :functional, role: :operations, type: :pure_module},
        system2: system2_info,
        system3: %{status: :functional, role: :control, type: :pure_module},
        system3_star: safe_s3star_summary(),
        system4: %{status: :functional, role: :intelligence, type: :pure_module},
        system5: %{status: :functional, role: :policy, type: :pure_module}
      },
      timestamp: DateTime.utc_now()
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @spec safe_s3star_summary() :: map()
  defp safe_s3star_summary do
    base = %{status: :functional, role: :sporadic_audit, type: :genserver}

    try do
      audit = System3StarAudit.last_audit()

      if audit do
        Map.merge(base, %{
          last_status: audit.status,
          anomaly_count: audit.anomaly_count,
          last_audit_at: audit.timestamp
        })
      else
        base
      end
    catch
      :exit, _ -> Map.put(base, :status, :unavailable)
      _kind, _reason -> Map.put(base, :status, :unavailable)
    end
  end

  @spec safe_system2_summary() :: map()
  defp safe_system2_summary do
    base = %{status: :functional, role: :coordination, type: :genserver}

    try do
      summary = System2Coordinator.get_summary(System2Coordinator)
      Map.merge(base, summary)
    catch
      :exit, _ ->
        Map.put(base, :status, :unavailable)

      _kind, _reason ->
        Map.put(base, :status, :unavailable)
    end
  end
end
