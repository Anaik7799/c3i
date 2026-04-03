defmodule Indrajaal.Distributed.FQUN do
  @moduledoc """
  Fully Qualified Unique Name (FQUN) Generator and Registry.

  WHAT: Generates and validates globally unique names for all distributed artifacts.
  WHY: SC-DIST-001 requires all dynamic resources to be uniquely addressable in the mesh.
  CONSTRAINTS: Names must be deterministic, collision-free, and Zenoh key-expression compatible.

  ## FQUN Format

  ```
  indrajaal/<layer>/<type>/<namespace>/<name>@<node>#<instance>
  ```

  ### Components:
  - `layer`: System layer (agent, worker, supervisor, dashboard, resource)
  - `type`: Specific type within layer (e.g., domain, flame, sentinel)
  - `namespace`: Logical grouping (e.g., cybernetic, observability, cluster)
  - `name`: Human-readable identifier
  - `node`: Erlang node name (for distribution)
  - `instance`: Unique instance ID (HLC timestamp + random suffix)

  ## Examples

  ```
  indrajaal/agent/domain/cybernetic/ooda_controller@indrajaal-app.ts.net#01HWXYZ123
  indrajaal/worker/flame/analytics/batch_processor@indrajaal-app.ts.net#01HWXYZ456
  indrajaal/supervisor/cluster/sentinel/quorum_guardian@indrajaal-app.ts.net#01HWXYZ789
  indrajaal/dashboard/cepaf/main/control_center@indrajaal-app.ts.net#01HWXYZABC
  ```

  ## STAMP Constraints
  - SC-DIST-001: All resources MUST have FQUN
  - SC-DIST-002: FQUNs MUST be Zenoh key-expression compatible
  - SC-DIST-003: FQUNs MUST be deterministically derivable
  - SC-DIST-004: FQUN registry MUST support mesh-wide lookup

  ## Mathematical Specification

  ```
  FQUN := Layer × Type × Namespace × Name × Node × Instance

  where:
    Layer ∈ {agent, worker, supervisor, dashboard, resource}
    Type ∈ TypeRegistry[Layer]
    Namespace ∈ String (alphanumeric + underscore)
    Name ∈ String (alphanumeric + underscore)
    Node := NodeName@Domain (Erlang node format)
    Instance := HLCTimestamp ⊕ RandomSuffix

  Uniqueness Invariant:
    ∀ fqun₁, fqun₂ ∈ FQUN: fqun₁ ≠ fqun₂ ⟹ key(fqun₁) ≠ key(fqun₂)
  ```
  """

  use GenServer
  require Logger

  alias Indrajaal.Observability.Fractal.HybridLogicalClock, as: HLC

  # ============================================================
  # TYPE DEFINITIONS
  # ============================================================

  @type layer :: :agent | :worker | :supervisor | :dashboard | :resource
  @type fqun :: String.t()
  @type fqun_components :: %{
          layer: layer(),
          type: atom(),
          namespace: String.t(),
          name: String.t(),
          node: atom(),
          instance: String.t()
        }

  alias Indrajaal.Observability.Fractal.HybridLogicalClock, as: HLC

  # ============================================================
  # LAYER AND TYPE REGISTRY
  # ============================================================

  @layers [:agent, :worker, :supervisor, :dashboard, :resource]

  @type_registry %{
    agent: [
      # Domain-specific agents (Accounts, Alarms, etc.)
      :domain,
      # OODA, ACE, Cortex agents
      :cybernetic,
      # Machine learning agents
      :ml,
      # External integration agents
      :integration,
      # Monitoring and telemetry agents
      :observability,
      # Security and compliance agents
      :security
    ],
    worker: [
      # FLAME elastic compute workers
      :flame,
      # Background job workers
      :oban,
      # Data pipeline workers
      :broadway,
      # Batch processing workers
      :batch
    ],
    supervisor: [
      # Cluster management supervisors
      :cluster,
      # Domain supervisors
      :domain,
      # Worker pool supervisors
      :pool,
      # Health and quorum supervisors
      :sentinel
    ],
    dashboard: [
      # CEPAF control dashboard
      :cepaf,
      # Metrics dashboard
      :metrics,
      # KPI dashboard
      :kpi,
      # Admin dashboard
      :admin
    ],
    resource: [
      # Compute resources (FLAME nodes, VMs)
      :compute,
      # Storage resources (databases, caches)
      :storage,
      # Network resources (connections, routes)
      :network,
      # Container resources (Podman)
      :container
    ]
  }

  # ============================================================
  # ETS TABLE FOR REGISTRY
  # ============================================================

  @registry_table :fqun_registry
  @reverse_table :fqun_reverse

  # ============================================================
  # CLIENT API
  # ============================================================

  @doc "Start the FQUN registry GenServer."
  @spec start_link(Keyword.t()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Generate a new FQUN for a resource.

  ## Parameters
  - `layer`: The system layer (:agent, :worker, :supervisor, :dashboard, :resource)
  - `type`: The specific type within the layer
  - `namespace`: Logical grouping namespace
  - `name`: Human-readable name

  ## Options
  - `:node` - Override the node name (defaults to Node.self())
  - `:instance` - Override the instance ID (defaults to generated)

  ## Examples

      iex> FQUN.generate(:agent, :cybernetic, "ooda", "controller")
      {:ok, "indrajaal/agent/cybernetic/ooda/controller@node.ts.net#01HWX..."}
  """
  @spec generate(layer(), atom(), String.t(), String.t(), keyword()) ::
          {:ok, fqun()} | {:error, term()}
  def generate(layer, type, namespace, name, opts \\ []) do
    with :ok <- validate_layer(layer),
         :ok <- validate_type(layer, type),
         :ok <- validate_namespace(namespace),
         :ok <- validate_name(name) do
      node = Keyword.get(opts, :node, Node.self())
      instance = Keyword.get_lazy(opts, :instance, &generate_instance/0)

      fqun = build_fqun(layer, type, namespace, name, node, instance)

      # Register if not already registered
      case register(fqun, %{layer: layer, type: type, namespace: namespace, name: name}) do
        :ok -> {:ok, fqun}
        {:error, :already_registered} -> {:ok, fqun}
        error -> error
      end
    end
  end

  @doc """
  Generate FQUN for a process and link it to the process.

  The FQUN will be automatically unregistered when the process terminates.
  """
  @spec generate_for_process(layer(), atom(), String.t(), String.t(), pid(), keyword()) ::
          {:ok, fqun()} | {:error, term()}
  def generate_for_process(layer, type, namespace, name, pid, opts \\ []) do
    with {:ok, fqun} <- generate(layer, type, namespace, name, opts) do
      GenServer.call(__MODULE__, {:link_process, fqun, pid})
      {:ok, fqun}
    end
  end

  @doc "Parse a FQUN into its components."
  @spec parse(fqun()) :: {:ok, fqun_components()} | {:error, :invalid_fqun}
  def parse(fqun) when is_binary(fqun) do
    case Regex.run(
           ~r/^indrajaal\/(\w+)\/(\w+)\/(\w+)\/(\w+)@([^#]+)#(.+)$/,
           fqun
         ) do
      [_, layer, type, namespace, name, node, instance] ->
        {:ok,
         %{
           layer: String.to_existing_atom(layer),
           type: String.to_existing_atom(type),
           namespace: namespace,
           name: name,
           node: String.to_atom(node),
           instance: instance
         }}

      _ ->
        {:error, :invalid_fqun}
    end
  rescue
    ArgumentError -> {:error, :invalid_fqun}
  end

  @doc "Convert FQUN to Zenoh key expression."
  @spec to_zenoh_key(fqun()) :: String.t()
  def to_zenoh_key(fqun) do
    fqun
    |> String.replace("@", "/node/")
    |> String.replace("#", "/instance/")
  end

  @doc "Convert Zenoh key expression back to FQUN."
  @spec from_zenoh_key(String.t()) :: {:ok, fqun()} | {:error, :invalid_key}
  def from_zenoh_key(key) do
    case Regex.run(
           ~r/^indrajaal\/(\w+)\/(\w+)\/(\w+)\/(\w+)\/node\/([^\/]+)\/instance\/(.+)$/,
           key
         ) do
      [_, layer, type, namespace, name, node, instance] ->
        {:ok, "indrajaal/#{layer}/#{type}/#{namespace}/#{name}@#{node}##{instance}"}

      _ ->
        {:error, :invalid_key}
    end
  end

  @doc "Register a FQUN with metadata."
  @spec register(fqun(), map()) :: :ok | {:error, term()}
  def register(fqun, metadata) do
    GenServer.call(__MODULE__, {:register, fqun, metadata})
  end

  @doc "Lookup a FQUN in the registry."
  @spec lookup(fqun()) :: {:ok, map()} | {:error, :not_found}
  def lookup(fqun) do
    case :ets.lookup(@registry_table, fqun) do
      [{^fqun, metadata}] -> {:ok, metadata}
      [] -> {:error, :not_found}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  @doc "Find FQUNs by pattern (supports wildcards)."
  @spec find(String.t()) :: [fqun()]
  def find(pattern) do
    regex = pattern_to_regex(pattern)
    entries = :ets.tab2list(@registry_table)

    entries
    |> Enum.filter(fn {fqun, _} -> Regex.match?(regex, fqun) end)
    |> Enum.map(fn {fqun, _} -> fqun end)
  rescue
    ArgumentError -> []
  end

  @doc "Find all FQUNs by layer."
  @spec find_by_layer(layer()) :: [fqun()]
  def find_by_layer(layer) do
    find("indrajaal/#{layer}/**")
  end

  @doc "Find all FQUNs by layer and type."
  @spec find_by_type(layer(), atom()) :: [fqun()]
  def find_by_type(layer, type) do
    find("indrajaal/#{layer}/#{type}/**")
  end

  @doc "Unregister a FQUN."
  @spec unregister(fqun()) :: :ok
  def unregister(fqun) do
    GenServer.call(__MODULE__, {:unregister, fqun})
  end

  @doc "Get all registered FQUNs."
  @spec all() :: [fqun()]
  def all do
    entries = :ets.tab2list(@registry_table)

    entries
    |> Enum.map(fn {fqun, _} -> fqun end)
  rescue
    ArgumentError -> []
  end

  @doc "Get all registered FQUNs with metadata."
  @spec list_all() :: [{fqun(), map()}]
  def list_all do
    :ets.tab2list(@registry_table)
  rescue
    ArgumentError -> []
  end

  @doc "Lookup a FQUN by components (layer, type, namespace, name)."
  @spec lookup(layer(), atom(), String.t(), String.t()) :: {:ok, fqun()} | {:error, :not_found}
  def lookup(layer, type, namespace, name) do
    # Find FQUNs matching the pattern
    pattern = "indrajaal/#{layer}/#{type}/#{namespace}/#{name}@"
    entries = :ets.tab2list(@registry_table)

    result =
      entries
      |> Enum.find(fn {fqun, _} -> String.starts_with?(fqun, pattern) end)

    case result do
      {fqun, _metadata} -> {:ok, fqun}
      nil -> {:error, :not_found}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  @doc "List FQUNs by layer with metadata."
  @spec list_by_layer(layer()) :: [{fqun(), map()}]
  def list_by_layer(layer) do
    pattern = "indrajaal/#{layer}/"
    entries = :ets.tab2list(@registry_table)

    entries
    |> Enum.filter(fn {fqun, _} -> String.starts_with?(fqun, pattern) end)
  rescue
    ArgumentError -> []
  end

  @doc "Get registry statistics."
  @spec stats() :: map()
  def stats do
    all_fquns = all()

    %{
      total: length(all_fquns),
      by_layer:
        Enum.reduce(@layers, %{}, fn layer, acc ->
          count = Enum.count(all_fquns, &String.contains?(&1, "/#{layer}/"))
          Map.put(acc, layer, count)
        end),
      by_node:
        all_fquns
        |> Enum.group_by(fn fqun ->
          case parse(fqun) do
            {:ok, %{node: node}} -> node
            _ -> :unknown
          end
        end)
        |> Enum.map(fn {node, fquns} -> {node, length(fquns)} end)
        |> Map.new()
    }
  end

  @doc "Validate FQUN format."
  @spec valid?(fqun()) :: boolean()
  def valid?(fqun), do: match?({:ok, _}, parse(fqun))

  @doc "Get available layers."
  @spec layers() :: [layer()]
  def layers, do: @layers

  @doc "Get available types for a layer."
  @spec types(layer()) :: [atom()]
  def types(layer), do: Map.get(@type_registry, layer, [])

  # ============================================================
  # GENSERVER CALLBACKS
  # ============================================================

  @impl true
  def init(_opts) do
    # Create ETS tables
    :ets.new(@registry_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ets.new(@reverse_table, [
      :set,
      :public,
      :named_table,
      read_concurrency: true
    ])

    Logger.info("[FQUN] Registry initialized - SC-DIST-001")
    {:ok, %{monitors: %{}}}
  end

  @impl true
  def handle_call({:register, fqun, metadata}, _from, state) do
    case :ets.lookup(@registry_table, fqun) do
      [] ->
        full_metadata =
          Map.merge(metadata, %{
            registered_at: DateTime.utc_now(),
            node: node()
          })

        :ets.insert(@registry_table, {fqun, full_metadata})
        Logger.debug("[FQUN] Registered: #{fqun}")
        {:reply, :ok, state}

      _ ->
        {:reply, {:error, :already_registered}, state}
    end
  end

  @impl true
  def handle_call({:unregister, fqun}, _from, state) do
    :ets.delete(@registry_table, fqun)
    Logger.debug("[FQUN] Unregistered: #{fqun}")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:link_process, fqun, pid}, _from, state) do
    ref = Process.monitor(pid)
    :ets.insert(@reverse_table, {pid, fqun})
    new_monitors = Map.put(state.monitors, ref, {fqun, pid})
    {:reply, :ok, %{state | monitors: new_monitors}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    case Map.get(state.monitors, ref) do
      {fqun, ^pid} ->
        :ets.delete(@registry_table, fqun)
        :ets.delete(@reverse_table, pid)
        Logger.debug("[FQUN] Process terminated, unregistered: #{fqun}")
        {:noreply, %{state | monitors: Map.delete(state.monitors, ref)}}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================
  # PRIVATE FUNCTIONS
  # ============================================================

  defp build_fqun(layer, type, namespace, name, node, instance) do
    node_str = Atom.to_string(node)
    "indrajaal/#{layer}/#{type}/#{namespace}/#{name}@#{node_str}##{instance}"
  end

  defp generate_instance do
    # Use HLC timestamp if available, otherwise use system time + random
    timestamp =
      if Code.ensure_loaded?(HLC) do
        case HLC.now() do
          {:ok, {physical, logical}} ->
            # Combine physical and logical into a single number
            physical * 1000 + logical

          _ ->
            System.system_time(:nanosecond)
        end
      else
        System.system_time(:nanosecond)
      end

    # Encode as base62 for compactness
    random_bytes = :crypto.strong_rand_bytes(4)
    suffix = Base.encode16(random_bytes, case: :lower)
    "#{base62_encode(timestamp)}#{suffix}"
  end

  defp base62_encode(n) when n >= 0 do
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    encoded_list = do_base62_encode(n, alphabet, [])

    encoded_list
    |> Enum.join()
    |> String.pad_leading(11, "0")
  end

  defp do_base62_encode(0, _alphabet, []), do: ["0"]
  defp do_base62_encode(0, _alphabet, acc), do: acc

  defp do_base62_encode(n, alphabet, acc) do
    char = String.at(alphabet, rem(n, 62))
    do_base62_encode(div(n, 62), alphabet, [char | acc])
  end

  defp validate_layer(layer) when layer in @layers, do: :ok
  defp validate_layer(layer), do: {:error, {:invalid_layer, layer}}

  defp validate_type(layer, type) do
    valid_types = Map.get(@type_registry, layer, [])

    if type in valid_types do
      :ok
    else
      {:error, {:invalid_type, type, valid_types}}
    end
  end

  defp validate_namespace(ns) when is_binary(ns) and byte_size(ns) > 0 do
    if Regex.match?(~r/^[a-z][a-z0-9_]*$/, ns), do: :ok, else: {:error, {:invalid_namespace, ns}}
  end

  defp validate_namespace(ns), do: {:error, {:invalid_namespace, ns}}

  defp validate_name(name) when is_binary(name) and byte_size(name) > 0 do
    if Regex.match?(~r/^[a-z][a-z0-9_]*$/, name), do: :ok, else: {:error, {:invalid_name, name}}
  end

  defp validate_name(name), do: {:error, {:invalid_name, name}}

  defp pattern_to_regex(pattern) do
    pattern
    |> String.replace("**", "<<<GLOBSTAR>>>")
    |> String.replace("*", "[^/]+")
    |> String.replace("<<<GLOBSTAR>>>", ".*")
    |> then(&Regex.compile!("^#{&1}$"))
  end
end
