defmodule Indrajaal.Holon.DatabasePath do
  @moduledoc """
  Universal Holon Database Path Resolution.

  ## WHAT
  Provides deterministic path resolution for all holon-specific databases
  using the Universal Holon Identifier (UHI) naming system.

  ## WHY
  - Ensures consistent database path structure across all holons
  - Enables cross-holon database discovery
  - Supports migration from legacy paths
  - Enforces SC-DBNAME-001 to SC-DBNAME-010 constraints

  ## CONSTRAINTS
  - SC-DBNAME-001: All holon databases MUST follow UHI naming
  - SC-DBNAME-002: FQDN resolution MUST be deterministic
  - SC-DBNAME-008: Cross-runtime access MUST use Zenoh
  - SC-DBNAME-009: LOCAL access MUST be direct (no Zenoh)

  ## UHI Format
  {runtime}:{layer}:{domain}:{type}:{instance}

  Examples:
    "ex:l3:kms:srv:main"           -> Elixir L3 KMS Service
    "fs:l4:prj:agt:cockpit"        -> F# L4 Prajna Agent
    "ex:l5:grd:reg:guardian"       -> Elixir L5 Guardian Register

  ## FQDN Format
  {UHI}:{database_type}

  Examples:
    "ex:l3:kms:srv:main:state"     -> state.sqlite
    "ex:l3:kms:srv:main:history"   -> history.duckdb
  """

  @base_path "data/holons"

  # Runtime codes
  @runtimes ~w(ex fs zig rs)

  # Fractal layers
  @layers ~w(l0 l1 l2 l3 l4 l5 l6 l7)

  # Domain codes (registered domains)
  @domains %{
    "kms" => "Knowledge Management System",
    "prj" => "Prajna C3I Cockpit",
    "grd" => "Guardian Safety Kernel",
    "snt" => "Sentinel Health Monitor",
    "imm" => "Immutable Register",
    "fnd" => "Founder Directive",
    "zen" => "Zenoh Communication",
    "bio" => "Biomorphic Systems",
    "pln" => "Planning System",
    "evo" => "Evolution Engine",
    "ctx" => "Cortex AI",
    "tst" => "Test Infrastructure",
    "dev" => "Developer Knowledge",
    "sre" => "SRE Operations",
    "prd" => "Product Lifecycle",
    "obs" => "Observability"
  }

  # Holon types
  @types ~w(srv agt reg str brg pub sub wrk)

  # Database file types
  @db_types %{
    "state" => "state.sqlite",
    "history" => "history.duckdb",
    "vectors" => "vectors.sqlite",
    "cache" => "cache.sqlite",
    "register" => "register.duckdb",
    "analytics" => "analytics.duckdb"
  }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Resolves a Fully Qualified Database Name (FQDN) to a file path.

  ## Examples

      iex> DatabasePath.resolve("ex:l3:kms:srv:main:state")
      {:ok, "data/holons/ex/l3/kms/main/state.sqlite"}

      iex> DatabasePath.resolve("invalid")
      {:error, :invalid_fqdn}
  """
  @spec resolve(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def resolve(fqdn) when is_binary(fqdn) do
    case parse_fqdn(fqdn) do
      {:ok,
       %{runtime: runtime, layer: layer, domain: domain, instance: instance, db_type: db_type}} ->
        file_name = Map.get(@db_types, db_type)
        path = Path.join([@base_path, runtime, layer, domain, instance, file_name])
        {:ok, path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Resolves FQDN to path, raising on error.
  """
  @spec resolve!(String.t()) :: String.t()
  def resolve!(fqdn) do
    case resolve(fqdn) do
      {:ok, path} -> path
      {:error, reason} -> raise ArgumentError, "Invalid FQDN #{fqdn}: #{reason}"
    end
  end

  @doc """
  Builds a UHI from components.

  ## Examples

      iex> DatabasePath.build_uhi(:elixir, :l3, :kms, :srv, "main")
      {:ok, "ex:l3:kms:srv:main"}
  """
  @spec build_uhi(atom(), atom(), atom(), atom(), String.t()) ::
          {:ok, String.t()} | {:error, atom()}
  def build_uhi(runtime, layer, domain, type, instance) do
    runtime_code = runtime_to_code(runtime)
    layer_code = Atom.to_string(layer)
    domain_code = Atom.to_string(domain)
    type_code = Atom.to_string(type)

    with :ok <- validate_runtime(runtime_code),
         :ok <- validate_layer(layer_code),
         :ok <- validate_domain(domain_code),
         :ok <- validate_type(type_code),
         :ok <- validate_instance(instance) do
      {:ok, "#{runtime_code}:#{layer_code}:#{domain_code}:#{type_code}:#{instance}"}
    end
  end

  @doc """
  Builds a FQDN from UHI and database type.
  """
  @spec build_fqdn(String.t(), atom()) :: {:ok, String.t()} | {:error, atom()}
  def build_fqdn(uhi, db_type) when is_atom(db_type) do
    db_type_str = Atom.to_string(db_type)

    if Map.has_key?(@db_types, db_type_str) do
      {:ok, "#{uhi}:#{db_type_str}"}
    else
      {:error, :invalid_db_type}
    end
  end

  @doc """
  Returns the directory path for a holon (without database file).

  ## Examples

      iex> DatabasePath.holon_dir("ex:l3:kms:srv:main")
      {:ok, "data/holons/ex/l3/kms/main"}
  """
  @spec holon_dir(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def holon_dir(uhi) when is_binary(uhi) do
    case parse_uhi(uhi) do
      {:ok, %{runtime: runtime, layer: layer, domain: domain, instance: instance}} ->
        path = Path.join([@base_path, runtime, layer, domain, instance])
        {:ok, path}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns all database paths for a holon.

  ## Examples

      iex> DatabasePath.all_databases("ex:l3:kms:srv:main")
      {:ok, %{
        state: "data/holons/ex/l3/kms/main/state.sqlite",
        history: "data/holons/ex/l3/kms/main/history.duckdb",
        vectors: "data/holons/ex/l3/kms/main/vectors.sqlite"
      }}
  """
  @spec all_databases(String.t()) :: {:ok, map()} | {:error, atom()}
  def all_databases(uhi) when is_binary(uhi) do
    case holon_dir(uhi) do
      {:ok, dir} ->
        databases =
          @db_types
          |> Enum.map(fn {type, file} ->
            {String.to_atom(type), Path.join(dir, file)}
          end)
          |> Map.new()

        {:ok, databases}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks if a UHI represents an Elixir holon.
  """
  @spec elixir_holon?(String.t()) :: boolean()
  def elixir_holon?(uhi) when is_binary(uhi) do
    String.starts_with?(uhi, "ex:")
  end

  @doc """
  Checks if a UHI represents an F# holon.
  """
  @spec fsharp_holon?(String.t()) :: boolean()
  def fsharp_holon?(uhi) when is_binary(uhi) do
    String.starts_with?(uhi, "fs:")
  end

  @doc """
  Returns the Zenoh topic for cross-holon database access.

  ## Examples

      iex> DatabasePath.zenoh_topic("ex:l3:kms:srv:main", :query)
      "indrajaal/db/ex/l3/kms/main/query"
  """
  @spec zenoh_topic(String.t(), atom()) :: String.t()
  def zenoh_topic(uhi, operation) when is_binary(uhi) and is_atom(operation) do
    {:ok, %{runtime: runtime, layer: layer, domain: domain, instance: instance}} = parse_uhi(uhi)
    "indrajaal/db/#{runtime}/#{layer}/#{domain}/#{instance}/#{operation}"
  end

  @doc """
  Maps a legacy path to the new naming system.
  """
  @spec from_legacy(String.t()) :: {:ok, String.t()} | {:error, :unknown_legacy_path}
  def from_legacy(legacy_path) do
    legacy_mappings = %{
      "data/kms/holons.db" => "ex:l3:kms:srv:main:state",
      "data/kms/analytics.duckdb" => "ex:l3:kms:srv:main:history",
      "data/holons/founder_directive/state.sqlite" => "ex:l5:fnd:reg:founder:state",
      "data/holons/founder_directive/history.duckdb" => "ex:l5:fnd:reg:founder:history",
      "data/holons/prajna_register.duckdb" => "ex:l5:prj:srv:prajna:register",
      "data/smriti/planning.db" => "fs:l4:pln:srv:main:state",
      "data/kms/smriti.db" => "ex:l3:kms:str:smriti:state"
    }

    # Check direct match first
    case Map.get(legacy_mappings, legacy_path) do
      nil ->
        # Check pattern matches for node-specific paths
        cond do
          String.match?(legacy_path, ~r/^data\/kms\/[^\/]+\/holons\.db$/) ->
            node = legacy_path |> String.split("/") |> Enum.at(2)
            {:ok, "ex:l3:kms:srv:#{node}:state"}

          String.match?(legacy_path, ~r/^data\/kms\/[^\/]+\/analytics\.duckdb$/) ->
            node = legacy_path |> String.split("/") |> Enum.at(2)
            {:ok, "ex:l3:kms:srv:#{node}:history"}

          String.match?(legacy_path, ~r/^data\/smriti\/[^\/]+\/holons\.db$/) ->
            node = legacy_path |> String.split("/") |> Enum.at(2)
            {:ok, "ex:l3:kms:srv:#{node}:state"}

          true ->
            {:error, :unknown_legacy_path}
        end

      fqdn ->
        {:ok, fqdn}
    end
  end

  @doc """
  Returns all registered domain codes.
  """
  @spec domains() :: map()
  def domains, do: @domains

  @doc """
  Returns all valid database types.
  """
  @spec db_types() :: map()
  def db_types, do: @db_types

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp parse_fqdn(fqdn) do
    parts = String.split(fqdn, ":")

    case parts do
      [runtime, layer, domain, type, instance, db_type] ->
        with :ok <- validate_runtime(runtime),
             :ok <- validate_layer(layer),
             :ok <- validate_domain(domain),
             :ok <- validate_type(type),
             :ok <- validate_instance(instance),
             :ok <- validate_db_type(db_type) do
          {:ok,
           %{
             runtime: runtime,
             layer: layer,
             domain: domain,
             type: type,
             instance: instance,
             db_type: db_type
           }}
        end

      _ ->
        {:error, :invalid_fqdn_format}
    end
  end

  defp parse_uhi(uhi) do
    parts = String.split(uhi, ":")

    case parts do
      [runtime, layer, domain, type, instance] ->
        with :ok <- validate_runtime(runtime),
             :ok <- validate_layer(layer),
             :ok <- validate_domain(domain),
             :ok <- validate_type(type),
             :ok <- validate_instance(instance) do
          {:ok,
           %{
             runtime: runtime,
             layer: layer,
             domain: domain,
             type: type,
             instance: instance
           }}
        end

      _ ->
        {:error, :invalid_uhi_format}
    end
  end

  defp runtime_to_code(:elixir), do: "ex"
  defp runtime_to_code(:fsharp), do: "fs"
  defp runtime_to_code(:zig), do: "zig"
  defp runtime_to_code(:rust), do: "rs"
  defp runtime_to_code(atom) when is_atom(atom), do: Atom.to_string(atom)

  defp validate_runtime(runtime) when runtime in @runtimes, do: :ok
  defp validate_runtime(_), do: {:error, :invalid_runtime}

  defp validate_layer(layer) when layer in @layers, do: :ok
  defp validate_layer(_), do: {:error, :invalid_layer}

  defp validate_domain(domain) do
    if Map.has_key?(@domains, domain), do: :ok, else: {:error, :invalid_domain}
  end

  defp validate_type(type) when type in @types, do: :ok
  defp validate_type(_), do: {:error, :invalid_type}

  defp validate_instance(instance) when is_binary(instance) and byte_size(instance) > 0, do: :ok
  defp validate_instance(_), do: {:error, :invalid_instance}

  defp validate_db_type(db_type) do
    if Map.has_key?(@db_types, db_type), do: :ok, else: {:error, :invalid_db_type}
  end
end
