defmodule Indrajaal.Observability.Fractal.Supervisor do
  @moduledoc """
  Fractal Logging System Supervisor with 4-Agent Architecture.

  WHAT: Supervises the Fractal Logging System components using a RestForOne
        strategy to ensure proper dependency ordering and crash recovery.

  WHY: Provides fault-tolerant supervision for the 5-level Fractal Logging
       System, ensuring observability never crashes the observed system.

  CONSTRAINTS:
  - SC-LOG-001: Async dispatch (never block)
  - SC-LOG-002: Auto-throttle at CPU > 90%
  - SC-CNT-009: Podman rootless containerization

  ## 4-Agent Architecture

  ```
  Supervisor (RestForOne)
  ├── Agent 1: FractalControl (GenServer) - Core state management
  ├── Agent 2: WriteFilter (GenServer) - Bloom filter deduplication
  ├── Agent 3: HLC (GenServer) - Causal ordering timestamps
  ├── Agent 4: CyberneticController (GenServer) - OODA loop control
  └── PartitionSupervisor (BatchEncoder + Logger pools)
  ```

  ## STAMP Compliance

  | Constraint   | Implementation                              |
  |--------------|---------------------------------------------|
  | SC-LOG-001   | Task.start for all async emissions         |
  | SC-LOG-002   | LoadShedder monitors CPU, activates at 90% |
  | SC-LOG-005   | Boost TTL enforced in FractalControl       |
  | SC-LOG-006   | HLC GenServer provides causal timestamps   |

  ## ETS Tables Initialized

  | Table               | Type        | Purpose                    |
  |---------------------|-------------|----------------------------|
  | :fractal_config     | ordered_set | Policy storage             |
  | :fractal_boosts     | set         | Active boosts with TTL     |
  | :fractal_subscriptions | bag      | Zenoh-style subscribers    |
  | :fractal_aliases    | set         | Key alias compression      |
  """

  use Supervisor
  require Logger

  # ============================================================
  # CONSTANTS
  # ============================================================

  @ets_tables [
    {:fractal_config, [:ordered_set, :named_table, :public, read_concurrency: true]},
    {:fractal_boosts, [:set, :named_table, :public, write_concurrency: true]},
    {:fractal_subscriptions, [:bag, :named_table, :public, read_concurrency: true]},
    {:fractal_aliases, [:set, :named_table, :public, read_concurrency: true]}
  ]

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc """
  Starts the Fractal Logging Supervisor.

  ## Options

  - `:name` - Supervisor name (default: `__MODULE__`)
  - `:default_level` - Default fractal level (default: `:l4`)
  - `:enable_cybernetic` - Enable autonomous OODA control (default: `false`)

  ## Examples

      {:ok, pid} = Indrajaal.Observability.Fractal.Supervisor.start_link([])
      {:ok, pid} = Indrajaal.Observability.Fractal.Supervisor.start_link(enable_cybernetic: true)
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Returns the status of all supervised agents.

  ## Returns

      %{
        fractal_control: :running | :stopped,
        write_filter: :running | :stopped,
        hlc: :running | :stopped,
        cybernetic: :running | :stopped | :disabled,
        partitions: non_neg_integer()
      }
  """
  @spec status() :: map()
  def status do
    children = Supervisor.which_children(__MODULE__)

    %{
      fractal_control: agent_status(children, Indrajaal.Observability.Fractal.FractalControl),
      write_filter: agent_status(children, Indrajaal.Observability.Fractal.WriteFilter),
      hlc: agent_status(children, Indrajaal.Observability.Fractal.HLC),
      cybernetic: agent_status(children, Indrajaal.Observability.Fractal.CyberneticController),
      partitions: count_partitions()
    }
  end

  @doc """
  Checks if the Fractal Logging System is healthy.

  Returns `true` if all critical agents (FractalControl, WriteFilter, HLC) are running.
  """
  @spec healthy?() :: boolean()
  def healthy? do
    status = status()

    status.fractal_control == :running and
      status.write_filter == :running and
      status.hlc == :running
  end

  # ============================================================
  # SUPERVISOR CALLBACKS
  # ============================================================

  @impl true
  def init(init_arg) do
    # Initialize ETS tables first (required before children start)
    initialize_ets_tables()

    # Set default configuration
    set_default_config(init_arg)

    enable_cybernetic = Keyword.get(init_arg, :enable_cybernetic, false)
    default_level = Keyword.get(init_arg, :default_level, :l4)

    children = build_children(enable_cybernetic, default_level)

    Logger.info("[FRACTAL] Supervisor starting with #{length(children)} children")

    Supervisor.init(children, strategy: :rest_for_one)
  end

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp build_children(enable_cybernetic, default_level) do
    base_children = [
      # Agent 1: Core State Manager (P0 Critical)
      # Manages: Policies, Boosts, Subscriptions, Load Shedding
      {Indrajaal.Observability.Fractal.FractalControl, [default_policy: default_level]},

      # Agent 2: Write Filtering + Batch Encoding (P0 Critical)
      # SC-LOG-008: <1% false negative rate
      {Indrajaal.Observability.Fractal.WriteFilter, []},
      # SC-LOG-007: Batch flush within 10ms
      {Indrajaal.Observability.Fractal.BatchEncoder, []},

      # Agent 3: Causal Ordering + OTel Integration (P1 High)
      # SC-LOG-006: HLC timestamps for L3+ logs
      {Indrajaal.Observability.Fractal.HLC, []},

      # Agent 4: Content Routing (P2 Medium)
      # Routes logs to SIEM, SigNoz, ErrorTracker based on key expressions
      {Indrajaal.Observability.Fractal.ContentRouter, []}
    ]

    cybernetic_children =
      if enable_cybernetic do
        [
          # OODA Loop Controller (P3 Control Plane)
          # Implements autonomous observability control
          {Indrajaal.Observability.Fractal.CyberneticController, []}
        ]
      else
        []
      end

    # 4-Agent Architecture:
    # Agent 1: FractalControl (Decide/Act)
    # Agent 2: WriteFilter + BatchEncoder (Observe)
    # Agent 3: HLC (Orient - causal ordering)
    # Agent 4: ContentRouter + CyberneticController (Observe/Orient)
    base_children ++ cybernetic_children
  end

  defp initialize_ets_tables do
    for {name, opts} <- @ets_tables do
      unless :ets.whereis(name) != :undefined do
        :ets.new(name, opts)
        Logger.debug("[FRACTAL] Created ETS table: #{name}")
      end
    end

    :ok
  end

  defp set_default_config(init_arg) do
    default_level = Keyword.get(init_arg, :default_level, :l4)

    # Set default policy (must match FractalControl's expected tuple format)
    :ets.insert(:fractal_config, {:default_policy, default_level})

    # Set subsystem-specific policies using nested tuple format {{:policy, key_expr}, level}
    # This format allows ETS ordered_set to store multiple policies (key includes expr)
    :ets.insert(:fractal_config, {{:policy, "Indrajaal"}, default_level})
    :ets.insert(:fractal_config, {{:policy, "Indrajaal/Cortex"}, :l5})
    :ets.insert(:fractal_config, {{:policy, "Indrajaal/Security"}, :l3})

    :ok
  end

  defp agent_status(children, module) do
    case List.keyfind(children, module, 0) do
      {^module, pid, :worker, _} when is_pid(pid) -> :running
      {^module, :restarting, _, _} -> :restarting
      {^module, :undefined, _, _} -> :stopped
      nil -> :disabled
    end
  end

  defp count_partitions do
    # Returns scheduler count for potential future PartitionSupervisor
    System.schedulers_online()
  end
end
