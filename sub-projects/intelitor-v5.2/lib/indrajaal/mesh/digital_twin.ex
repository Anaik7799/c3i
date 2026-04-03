defmodule Indrajaal.Mesh.DigitalTwin do
  @moduledoc """
  Digital Twin - Full mesh state manager.
  Mirrors F# Cepaf.Mesh.DigitalTwin.

  ## STAMP Compliance
  - SC-CLU-002: Fractal Cluster
  - SC-SIL4-001: Deterministic State
  """

  alias Indrajaal.Mesh.{HolonGenotype, HolonPhenotype, TopologyCache, StateCheckpoint}
  alias Indrajaal.Deployment.StartupWave

  @enforce_keys [:genotypes, :phenotypes, :version, :created_at]
  defstruct [
    :genotypes,
    :phenotypes,
    :cache,
    :last_checkpoint,
    :version,
    :created_at
  ]

  @type t :: %__MODULE__{
          genotypes: %{String.t() => HolonGenotype.t()},
          phenotypes: %{String.t() => HolonPhenotype.t()},
          cache: TopologyCache.t() | nil,
          last_checkpoint: StateCheckpoint.t() | nil,
          version: String.t(),
          created_at: DateTime.t()
        }

  @doc """
  Creates a new Digital Twin with default configuration.
  Matches F# DigitalTwin.createDefaultGenotypes logic.
  """
  @spec create_default() :: t()
  def create_default do
    genotypes = default_genotypes()
    phenotypes = create_initial_phenotypes(genotypes)

    twin = %__MODULE__{
      genotypes: genotypes,
      phenotypes: phenotypes,
      cache: nil,
      last_checkpoint: nil,
      version: "1.0.0",
      created_at: DateTime.utc_now()
    }

    # Auto-compute topology on creation
    case compute_topology(twin) do
      {:ok, cache} -> %{twin | cache: cache}
      _ -> twin
    end
  end

  @doc """
  Computes and caches the topology based on genotype dependencies.
  Implements topological sort and wave grouping.
  """
  @spec compute_topology(t()) :: {:ok, TopologyCache.t()} | {:error, String.t()}
  def compute_topology(twin) do
    config_binary = :erlang.term_to_binary(twin.genotypes)
    config_hash = :crypto.hash(:sha256, config_binary) |> Base.encode16(case: :lower)

    case topological_sort(twin.genotypes) do
      {:ok, sorted_ids} ->
        start_waves = group_into_waves(twin.genotypes, sorted_ids)

        shutdown_waves =
          start_waves
          |> Enum.reverse()
          |> Enum.with_index()
          |> Enum.map(fn {w, i} -> %{w | order: i} end)

        cache = %TopologyCache{
          version: twin.version,
          config_hash: config_hash,
          start_order: start_waves,
          shutdown_order: shutdown_waves,
          created_at: DateTime.utc_now(),
          validated_at: DateTime.utc_now(),
          is_valid: true
        }

        {:ok, cache}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates a phenotype state.
  """
  @spec update_phenotype(t(), String.t(), (HolonPhenotype.t() -> HolonPhenotype.t())) :: t()
  def update_phenotype(twin, id, updater) do
    case Map.get(twin.phenotypes, id) do
      nil ->
        twin

      phenotype ->
        updated = updater.(phenotype)
        put_in(twin.phenotypes[id], updated)
    end
  end

  @doc """
  Creates a state checkpoint (dying gasp).
  """
  @spec create_checkpoint(t(), String.t()) :: StateCheckpoint.t()
  def create_checkpoint(twin, reason) do
    state_binary = :erlang.term_to_binary(twin.phenotypes)
    state_hash = :crypto.hash(:sha256, state_binary) |> Base.encode16(case: :lower)

    %StateCheckpoint{
      id: Ecto.UUID.generate(),
      timestamp: DateTime.utc_now(),
      state_hash: state_hash,
      holons: twin.phenotypes,
      active_operations: [],
      pending_writes: [],
      reason: reason
    }
  end

  # --- Private Helpers ---

  defp topological_sort(genotypes) do
    # Build graph
    graph =
      Enum.map(genotypes, fn {id, g} ->
        deps = g.after ++ g.requires
        {id, deps}
      end)
      |> Map.new()

    # Kahn's Algorithm
    try do
      sorted = run_topological_sort(graph, [], Map.keys(graph))
      {:ok, Enum.reverse(sorted)}
    catch
      :cycle_detected -> {:error, "Cycle detected in dependency graph"}
    end
  end

  defp run_topological_sort(_graph, sorted, []) do
    sorted
  end

  defp run_topological_sort(graph, sorted, remaining) do
    # Find nodes with no dependencies in the remaining set
    ready =
      Enum.filter(remaining, fn id ->
        deps = Map.get(graph, id, [])

        Enum.all?(deps, fn dep ->
          # Dependency is either resolved or external/optional
          dep not in remaining or dep in sorted
        end)
      end)

    if ready == [] and remaining != [] do
      throw(:cycle_detected)
    end

    # For deterministic sort, sort ready nodes by ID
    ready_sorted = Enum.sort(ready)

    new_sorted = ready_sorted ++ sorted
    new_remaining = remaining -- ready_sorted

    run_topological_sort(graph, new_sorted, new_remaining)
  end

  defp group_into_waves(genotypes, sorted_ids) do
    # Simple wave grouping: 
    # 1. Take ready nodes
    # 2. Add to wave
    # 3. Mark as started
    # 4. Repeat

    do_group_waves(genotypes, sorted_ids, [], 0)
  end

  defp do_group_waves(_genotypes, [], waves, _order), do: Enum.reverse(waves)

  defp do_group_waves(genotypes, remaining_ids, waves, order) do
    # Determine which of the remaining IDs can start NOW given that
    # all previous waves have completed.
    # Actually, the sorted_ids list is already a valid serial order.
    # To parallelize, we check dependencies against *already started* nodes.

    started_ids =
      waves
      |> Enum.flat_map(fn w -> w.containers end)
      |> MapSet.new()

    {wave_ids, _next_remaining} =
      Enum.split_with(remaining_ids, fn id ->
        deps = genotypes[id].after ++ genotypes[id].requires

        Enum.all?(deps, fn dep ->
          not Map.has_key?(genotypes, dep) or MapSet.member?(started_ids, dep)
        end)
      end)

    # If sorted correctly, we should always find at least one.
    # If wave_ids is empty but remaining is not, logic error or cycle (but we checked cycles).
    # Fallback to taking head if logic is strict.

    wave_ids = if wave_ids == [], do: [hd(remaining_ids)], else: wave_ids
    next_remaining = remaining_ids -- wave_ids

    wave = %StartupWave{
      order: order,
      containers: wave_ids,
      timeout_ms: 30_000,
      # Enable jitter for non-seed waves
      jitter_enabled: order > 0
    }

    do_group_waves(genotypes, next_remaining, [wave | waves], order + 1)
  end

  defp default_genotypes do
    db = %HolonGenotype{
      id: "db-primary",
      name: "db-primary",
      role: :primary,
      image: "localhost/indrajaal-timescaledb-demo:nixos-devenv",
      ports: [{5433, 5432}],
      environment: %{
        "POSTGRES_USER" => "postgres",
        "POSTGRES_PASSWORD" => "postgres",
        "POSTGRES_DB" => "indrajaal_cluster"
      },
      health_check: "pg_isready -U postgres -p 5432",
      memory_mb: 4096,
      cpu_limit: 4.0,
      network: "indrajaal-cluster-net",
      ip_address: "172.30.0.21"
    }

    obs = %HolonGenotype{
      id: "indrajaal-obs",
      name: "indrajaal-obs",
      role: :controller,
      image: "localhost/indrajaal-obs-unified:nixos-devenv",
      ports: [{4319, 4317}, {4318, 4318}, {9091, 9090}, {3001, 3000}, {3101, 3100}],
      environment: %{
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://172.30.0.30:4317"
      },
      after: ["db-primary"],
      wants: ["db-primary"],
      health_check: "curl -f http://localhost:9090/-/healthy",
      health_interval_ms: 10000,
      memory_mb: 10240,
      cpu_limit: 6.0,
      network: "indrajaal-cluster-net",
      ip_address: "172.30.0.30"
    }

    app1 = %HolonGenotype{
      id: "app-1",
      name: "indrajaal-ex-app-1",
      role: :seed,
      image: "localhost/indrajaal-app-unified:nixos-devenv",
      ports: [{4000, 4000}],
      environment: %{
        "DATABASE_URL" => "ecto://postgres:postgres@172.30.0.21:5432/indrajaal_cluster",
        "PHX_HOST" => "localhost",
        "SECRET_KEY_BASE" => "fractal_cluster_secret_key_base_1234567890",
        "CLUSTERING_ENABLED" => "true",
        "RELEASE_COOKIE" => "fractal_mesh_cookie",
        "RELEASE_NODE" => "indrajaal@172.30.0.11",
        "FLAME_ENABLED" => "true",
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://172.30.0.30:4317"
      },
      after: ["db-primary", "indrajaal-obs"],
      requires: ["db-primary"],
      wants: ["indrajaal-obs"],
      health_check: "curl -f http://localhost:4000/health",
      memory_mb: 8192,
      cpu_limit: 4.0,
      network: "indrajaal-cluster-net",
      ip_address: "172.30.0.11"
    }

    app2 = %HolonGenotype{
      id: "app-2",
      name: "indrajaal-ex-app-2",
      role: :satellite,
      image: "localhost/indrajaal-app-unified:nixos-devenv",
      ports: [{4001, 4000}],
      environment: %{
        "DATABASE_URL" => "ecto://postgres:postgres@172.30.0.21:5432/indrajaal_cluster",
        "PHX_HOST" => "localhost",
        "SECRET_KEY_BASE" => "fractal_cluster_secret_key_base_1234567890",
        "CLUSTERING_ENABLED" => "true",
        "RELEASE_COOKIE" => "fractal_mesh_cookie",
        "RELEASE_NODE" => "indrajaal@172.30.0.12",
        "FLAME_ENABLED" => "true",
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://172.30.0.30:4317"
      },
      after: ["db-primary", "indrajaal-obs", "app-1"],
      requires: ["db-primary", "app-1"],
      wants: ["indrajaal-obs"],
      health_check: "curl -f http://localhost:4000/health",
      memory_mb: 8192,
      cpu_limit: 4.0,
      network: "indrajaal-cluster-net",
      ip_address: "172.30.0.12",
      start_delay_ms: 500,
      max_jitter_ms: 200
    }

    app3 = %HolonGenotype{
      id: "app-3",
      name: "indrajaal-ex-app-3",
      role: :satellite,
      image: "localhost/indrajaal-app-unified:nixos-devenv",
      ports: [{4002, 4000}],
      environment: %{
        "DATABASE_URL" => "ecto://postgres:postgres@172.30.0.21:5432/indrajaal_cluster",
        "PHX_HOST" => "localhost",
        "SECRET_KEY_BASE" => "fractal_cluster_secret_key_base_1234567890",
        "CLUSTERING_ENABLED" => "true",
        "RELEASE_COOKIE" => "fractal_mesh_cookie",
        "RELEASE_NODE" => "indrajaal@172.30.0.13",
        "FLAME_ENABLED" => "true",
        "OTEL_EXPORTER_OTLP_ENDPOINT" => "http://172.30.0.30:4317"
      },
      after: ["db-primary", "indrajaal-obs", "app-1"],
      requires: ["db-primary", "app-1"],
      wants: ["indrajaal-obs"],
      health_check: "curl -f http://localhost:4000/health",
      memory_mb: 8192,
      cpu_limit: 4.0,
      network: "indrajaal-cluster-net",
      ip_address: "172.30.0.13",
      start_delay_ms: 500,
      max_jitter_ms: 200
    }

    %{
      db.id => db,
      obs.id => obs,
      app1.id => app1,
      app2.id => app2,
      app3.id => app3
    }
  end

  defp create_initial_phenotypes(genotypes) do
    genotypes
    |> Enum.map(fn {id, _g} ->
      {id, %HolonPhenotype{genotype_id: id}}
    end)
    |> Map.new()
  end
end
