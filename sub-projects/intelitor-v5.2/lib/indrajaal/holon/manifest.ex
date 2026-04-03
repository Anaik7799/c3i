defmodule Indrajaal.Holon.Manifest do
  @moduledoc """
  Holon Manifest Generator and Manager.

  ## WHAT
  Creates and manages manifest.json files for holons, containing metadata
  about the holon's identity, databases, capabilities, and schema versions.

  ## WHY
  - Enables holon discovery and introspection
  - Tracks schema versions for migration
  - Documents database capabilities
  - Supports cross-holon communication setup

  ## CONSTRAINTS
  - SC-DBNAME-010: Manifest MUST exist for every holon
  - SC-HOLON-016: Format stability for future reconstruction
  - SC-HOLON-017: SHA-256 checksum for integrity
  """

  alias Indrajaal.Holon.DatabasePath

  @manifest_version "1.0.0"
  @schema_version 1

  # ============================================================================
  # Types
  # ============================================================================

  @type t :: %{
          version: String.t(),
          uhi: String.t(),
          fqun: String.t(),
          created_at: String.t(),
          updated_at: String.t(),
          runtime: runtime_info(),
          databases: map(),
          capabilities: [String.t()],
          parent_uhi: String.t() | nil,
          children_uhi: [String.t()],
          zenoh_topics: zenoh_info(),
          checksum: String.t()
        }

  @type runtime_info :: %{
          type: String.t(),
          version: String.t(),
          otp: String.t()
        }

  @type zenoh_info :: %{
          publish: [String.t()],
          subscribe: [String.t()]
        }

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Creates a new manifest for a holon.

  ## Examples

      iex> Manifest.create("ex:l3:kms:srv:main")
      {:ok, %{version: "1.0.0", uhi: "ex:l3:kms:srv:main", ...}}
  """
  @spec create(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def create(uhi, opts \\ []) do
    case DatabasePath.holon_dir(uhi) do
      {:ok, _dir} ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()

        manifest = %{
          "$schema" => "https://indrajaal.dev/schemas/holon-manifest-v1.json",
          "version" => @manifest_version,
          "uhi" => uhi,
          "fqun" => build_fqun(uhi),
          "created_at" => Keyword.get(opts, :created_at, now),
          "updated_at" => now,
          "runtime" => runtime_info(),
          "databases" => database_info(uhi, opts),
          "capabilities" => Keyword.get(opts, :capabilities, ["read", "write"]),
          "parent_uhi" => Keyword.get(opts, :parent_uhi),
          "children_uhi" => Keyword.get(opts, :children_uhi, []),
          "zenoh_topics" => zenoh_topics(uhi),
          "checksum" => ""
        }

        # Calculate checksum
        manifest_without_checksum = Map.delete(manifest, "checksum")
        checksum = calculate_checksum(manifest_without_checksum)
        manifest = Map.put(manifest, "checksum", checksum)

        {:ok, manifest}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Writes a manifest to the holon directory.
  """
  @spec write(String.t(), t()) :: :ok | {:error, term()}
  def write(uhi, manifest) do
    case DatabasePath.holon_dir(uhi) do
      {:ok, dir} ->
        path = Path.join(dir, "manifest.json")
        File.mkdir_p!(dir)

        json = Jason.encode!(manifest, pretty: true)
        File.write(path, json)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Reads a manifest from the holon directory.
  """
  @spec read(String.t()) :: {:ok, t()} | {:error, term()}
  def read(uhi) do
    case DatabasePath.holon_dir(uhi) do
      {:ok, dir} ->
        path = Path.join(dir, "manifest.json")

        case File.read(path) do
          {:ok, content} ->
            case Jason.decode(content) do
              {:ok, manifest} -> {:ok, manifest}
              {:error, reason} -> {:error, {:json_decode, reason}}
            end

          {:error, reason} ->
            {:error, {:file_read, reason}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Verifies a manifest's checksum.
  """
  @spec verify(t()) :: :ok | {:error, :checksum_mismatch}
  def verify(manifest) do
    stored_checksum = Map.get(manifest, "checksum")
    manifest_without_checksum = Map.delete(manifest, "checksum")
    calculated_checksum = calculate_checksum(manifest_without_checksum)

    if stored_checksum == calculated_checksum do
      :ok
    else
      {:error, :checksum_mismatch}
    end
  end

  @doc """
  Updates a manifest with new values.
  """
  @spec update(String.t(), map()) :: {:ok, t()} | {:error, term()}
  def update(uhi, updates) do
    case read(uhi) do
      {:ok, manifest} ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()

        updated = Map.merge(manifest, updates)
        updated = Map.put(updated, "updated_at", now)

        # Recalculate checksum
        updated_without_checksum = Map.delete(updated, "checksum")
        checksum = calculate_checksum(updated_without_checksum)
        updated = Map.put(updated, "checksum", checksum)

        {:ok, updated}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Initializes a new holon with manifest and directory structure.
  """
  @spec init_holon(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def init_holon(uhi, opts \\ []) do
    case DatabasePath.holon_dir(uhi) do
      {:ok, dir} ->
        # Create directory structure
        File.mkdir_p!(dir)

        # Create manifest
        {:ok, manifest} = create(uhi, opts)

        # Write manifest
        :ok = write(uhi, manifest)

        # Create empty database files if requested
        if Keyword.get(opts, :create_databases, false) do
          create_empty_databases(uhi)
        end

        {:ok, manifest}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Lists all holons with manifests.
  """
  @spec list_holons() :: [{String.t(), String.t()}]
  def list_holons do
    base_path = "data/holons"

    if File.exists?(base_path) do
      find_manifests(base_path)
    else
      []
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp runtime_info do
    %{
      "type" => "elixir",
      "version" => System.version(),
      "otp" => :erlang.system_info(:otp_release) |> to_string()
    }
  end

  defp database_info(_uhi, opts) do
    base_info = %{
      "state" => %{
        "type" => "sqlite",
        "version" => "3.47.0",
        "wal_mode" => true,
        "schema_version" => @schema_version
      },
      "history" => %{
        "type" => "duckdb",
        "version" => "1.2.0",
        "schema_version" => @schema_version
      }
    }

    # Add vectors if requested
    if Keyword.get(opts, :with_vectors, false) do
      Map.put(base_info, "vectors", %{
        "type" => "sqlite",
        "version" => "3.47.0",
        "schema_version" => @schema_version
      })
    else
      base_info
    end
  end

  defp zenoh_topics(uhi) do
    %{
      "publish" => [
        DatabasePath.zenoh_topic(uhi, :state),
        DatabasePath.zenoh_topic(uhi, :events)
      ],
      "subscribe" => [
        "indrajaal/coord/heartbeat",
        "indrajaal/mesh/control"
      ]
    }
  end

  defp build_fqun(uhi) do
    [_runtime, _layer, domain, _type, instance] = String.split(uhi, ":")
    "kms/l3/#{domain}/default/#{instance}"
  end

  defp calculate_checksum(data) do
    json = Jason.encode!(data, pretty: false)
    hash = :crypto.hash(:sha256, json)
    "sha256:#{Base.encode16(hash, case: :lower)}"
  end

  defp create_empty_databases(uhi) do
    case DatabasePath.all_databases(uhi) do
      {:ok, databases} ->
        Enum.each(databases, fn {_type, path} ->
          dir = Path.dirname(path)
          File.mkdir_p!(dir)

          unless File.exists?(path) do
            File.touch!(path)
          end
        end)

      {:error, _} ->
        :ok
    end
  end

  defp find_manifests(base_path) do
    Path.wildcard("#{base_path}/**/manifest.json")
    |> Enum.map(fn path ->
      case File.read(path) do
        {:ok, content} ->
          case Jason.decode(content) do
            {:ok, %{"uhi" => uhi}} -> {uhi, path}
            _ -> nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end
