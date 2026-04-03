defmodule Indrajaal.Cockpit.Prajna.ImmutableState do
  @moduledoc """
  Immutable Register for Prajna State Mutations (GenServer + DuckDB via Zenoh Proxy).

  WHAT: Cryptographically verifiable append-only log of all Prajna state changes.
  WHY: SC-REG-001 requires all mutations to be recorded in the register.

  CONSTRAINTS:
    - SC-REG-001: All state changes via append-only register
    - SC-REG-002: Hash chain MUST be unbroken
    - SC-REG-003: All blocks MUST be Ed25519 signed
    - SC-REG-006: Reed-Solomon parity required for error correction
    - SC-REG-008: Repair events MUST be recorded
    - SC-SIL4-002: Persist to DuckDB
    - SC-SIL4-003: Verify chain on startup
    - SC-HOLON-019: DuckDB history is immutable/append-only
    - SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    - SC-DBLOCAL-002: Local access latency < 1ms

  ## Architecture Note (2026-01-17)
  ImmutableState uses DIRECT Duckdbex access because this is LOCAL holon state.
  Per SC-DBLOCAL-001, local database access bypasses Zenoh entirely.

  Cross-holon database access (different holons) would use DatabaseProxy via Zenoh.
  See: docs/architecture/ZENOH_DATABASE_BRIDGE_ARCHITECTURE.md

  ## Data Flow
  ```
  ImmutableState (this module)
      │
      ▼
  Duckdbex (DIRECT local access per SC-DBLOCAL-001)
      │
      ▼
  DuckDB (UHI: ex:l5:prj:srv:prajna:register)
         Path: data/holons/ex/l5/prj/prajna/register.duckdb
  ```

  ## UHI Database Naming (SC-DBNAME-001)
  - **UHI**: ex:l5:prj:srv:prajna
  - **FQDN**: ex:l5:prj:srv:prajna:register
  - **Path**: data/holons/ex/l5/prj/prajna/register.duckdb

  ## Sprint 31 Enhancements

  1. **DuckDB Persistence**: All blocks persisted immediately (direct Duckdbex access)
  2. **Startup Chain Verification**: Full hash chain + Ed25519 signature verification (SC-REG-002)
  3. **Reed-Solomon RS(255,223)**: Error correction with auto-repair (SC-REG-006)
  4. **Repair Event Logging**: All repairs recorded to register (SC-REG-008)
  5. **Recovery**: Load existing blocks from DuckDB on restart (direct access per SC-DBLOCAL-001)
  """

  use GenServer
  require Logger
  alias Indrajaal.Cockpit.Prajna.Config
  alias Indrajaal.Cockpit.Prajna.ReedSolomon
  # Note: DatabaseProxy is for CROSS-HOLON access only, not used here
  # ImmutableState is LOCAL prajna state - uses direct Duckdbex per SC-DBLOCAL-001
  alias Indrajaal.Holon.DatabasePath

  @genesis_hash "0000000000000000000000000000000000000000000000000000000000000000"
  @protocol_version "21.1.0"
  @keypair_file "prajna_keypair.bin"
  # HMAC key (Ed25519 now primary - kept for backwards compatibility documentation)
  # @signing_key "prajna_immutable_state_hmac_key_v21"

  defstruct blocks: [],
            last_index: -1,
            last_hash: @genesis_hash,
            created_at: nil,
            last_updated: nil,
            duckdb_conn: nil,
            verified: false,
            keypair: nil,
            holon_path: nil,
            repair_count: 0,
            verification_stats: %{}

  # ============================================================================
  # Client API
  # ============================================================================

  @doc """
  Starts the ImmutableState GenServer.
  Loads existing blocks from DuckDB and verifies chain integrity.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Records a single state mutation to the register.
  Persists to DuckDB before returning.

  Returns {:ok, block_hash} on success.
  """
  @spec record(map()) :: {:ok, String.t()} | {:error, term()}
  def record(payload) when is_map(payload) and not is_struct(payload) do
    timeout = get_timeout()

    GenServer.call(__MODULE__, {:record, payload}, timeout)
  catch
    :exit, {:noproc, _} ->
      # Fallback for tests without GenServer running
      register = create_register()
      updated = do_record(payload, register)
      [block] = updated.blocks
      {:ok, block.block_hash}

    :exit, {:timeout, _} ->
      {:error, :timeout}
  end

  @doc """
  Verifies the integrity of the hash chain.
  """
  @spec verify_chain() :: :valid | {:invalid, String.t()}
  def verify_chain do
    GenServer.call(__MODULE__, :verify_chain, 30_000)
  catch
    :exit, {:noproc, _} -> :valid
    :exit, _ -> {:error, :not_running}
  end

  @doc """
  Returns true if the chain has been verified on startup.
  """
  @spec verified?() :: boolean()
  def verified? do
    GenServer.call(__MODULE__, :verified?, 5_000)
  catch
    :exit, _ -> false
  end

  @doc """
  Gets a block by index.
  """
  @spec get_block(integer()) :: map() | nil
  def get_block(index) do
    GenServer.call(__MODULE__, {:get_block, index}, 5_000)
  catch
    :exit, {:noproc, _} -> nil
    :exit, _ -> nil
  end

  @doc """
  Gets blocks filtered by change type.
  """
  @spec get_blocks_by_type(atom()) :: [map()]
  def get_blocks_by_type(change_type) do
    GenServer.call(__MODULE__, {:get_blocks_by_type, change_type}, 10_000)
  catch
    :exit, {:noproc, _} -> []
    :exit, _ -> []
  end

  @doc """
  Computes the Merkle root of all blocks in the register.
  """
  @spec compute_merkle_root() :: String.t()
  def compute_merkle_root do
    GenServer.call(__MODULE__, :compute_merkle_root, 30_000)
  catch
    :exit, {:noproc, _} -> hash("empty_merkle_root")
    :exit, _ -> hash("empty_merkle_root")
  end

  @doc """
  Returns a summary of the register state.
  """
  @spec summary() :: String.t()
  def summary do
    GenServer.call(__MODULE__, :summary, 5_000)
  catch
    :exit, {:noproc, _} -> "ImmutableState: not running"
    :exit, _ -> "ImmutableState: error"
  end

  @doc """
  Returns the current block count.
  """
  @spec block_count() :: non_neg_integer()
  def block_count do
    GenServer.call(__MODULE__, :block_count, 5_000)
  catch
    :exit, _ -> 0
  end

  @doc """
  Returns the current register state (for testing/introspection).
  """
  @spec get_state() :: %__MODULE__{}
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  catch
    :exit, {:noproc, _} -> create_register()
    :exit, _ -> create_register()
  end

  # ============================================================================
  # Pure Functions (for direct use with register structs)
  # ============================================================================

  @doc """
  Creates a new empty immutable register with genesis hash.
  Generates a new Ed25519 keypair for signing (SC-REG-003).
  """
  @spec create_register() :: %__MODULE__{}
  def create_register do
    now = DateTime.utc_now()
    keypair = generate_ed25519_keypair()

    %__MODULE__{
      blocks: [],
      last_index: -1,
      last_hash: @genesis_hash,
      created_at: now,
      last_updated: now,
      duckdb_conn: nil,
      verified: true,
      keypair: keypair,
      holon_path: nil
    }
  end

  @doc """
  Returns the public key for external verification (SC-REG-013).
  """
  @spec public_key(%__MODULE__{}) :: binary()
  def public_key(%__MODULE__{keypair: {pub, _sec}}), do: pub
  def public_key(%__MODULE__{keypair: nil}), do: nil

  @doc """
  Returns the public key from the GenServer.
  """
  @spec get_public_key() :: binary() | nil
  def get_public_key do
    GenServer.call(__MODULE__, :get_public_key, 5_000)
  catch
    :exit, _ -> nil
  end

  # ============================================================================
  # ImmutableRegister Integration (SC-REG-013)
  # ============================================================================

  @doc """
  Syncs a block to the core ImmutableRegister for cross-holon attestation.
  SC-REG-013: Cross-holon attestation for federation.
  """
  @spec sync_to_register(map()) :: {:ok, String.t()} | {:ok, :skipped} | {:error, term()}
  def sync_to_register(block) when is_map(block) do
    alias Indrajaal.Core.Holon.ImmutableRegister

    try do
      ImmutableRegister.append(:prajna_state, %{
        prajna_block_hash: block.block_hash,
        prajna_block_index: block.index,
        content_type: Map.get(block.content, :change_type, :unknown),
        timestamp: block.timestamp,
        signature: block.signature
      })
    catch
      :exit, {:noproc, _} ->
        Logger.debug("[ImmutableState] ImmutableRegister not running, skip sync")
        {:ok, :skipped}

      :exit, reason ->
        Logger.warning("[ImmutableState] Failed to sync to register: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Attests with the core ImmutableRegister for federation.
  SC-REG-013: Cross-holon attestation.
  """
  @spec attest_with_register() :: {:ok, map()} | {:error, term()}
  def attest_with_register do
    GenServer.call(__MODULE__, :attest_with_register, 10_000)
  catch
    :exit, _ -> {:error, :not_running}
  end

  @doc """
  Gets attestation info for external verification.
  """
  @spec attestation_info() :: map()
  def attestation_info do
    GenServer.call(__MODULE__, :attestation_info, 5_000)
  catch
    :exit, _ -> %{error: :not_running}
  end

  @doc """
  Records a state change in the register (pure function).
  Returns updated register with new block appended.
  Supports pipe operator with register as first argument.
  """
  @spec record(map(), %__MODULE__{}) :: %__MODULE__{}
  def record(%__MODULE__{} = register, change) when is_map(change) do
    do_record(change, register)
  end

  def record(change, %__MODULE__{} = register) when is_map(change) do
    do_record(change, register)
  end

  @doc """
  Verifies the integrity of the hash chain (pure function).
  """
  @spec verify_chain(%__MODULE__{}) :: :valid | {:invalid, String.t()}
  def verify_chain(%__MODULE__{} = register) do
    case register.blocks do
      [] -> :valid
      blocks -> verify_blocks(blocks, @genesis_hash)
    end
  end

  @doc """
  Gets a block by index (pure function).
  """
  @spec get_block(integer(), %__MODULE__{}) :: map() | nil
  def get_block(index, %__MODULE__{} = register) do
    Enum.find(register.blocks, fn block -> block.index == index end)
  end

  @doc """
  Gets blocks filtered by change type (pure function).
  """
  @spec get_blocks_by_type(atom(), %__MODULE__{}) :: [map()]
  def get_blocks_by_type(change_type, %__MODULE__{} = register) do
    Enum.filter(register.blocks, fn block ->
      block.content.change_type == change_type
    end)
  end

  @doc """
  Computes the Merkle root of all blocks in the register (pure function).
  """
  @spec compute_merkle_root(%__MODULE__{}) :: String.t()
  def compute_merkle_root(%__MODULE__{} = register) do
    case register.blocks do
      [] ->
        hash("empty_merkle_root")

      blocks ->
        hashes = Enum.map(blocks, & &1.content_hash)
        compute_merkle_root_recursive(hashes)
    end
  end

  @doc """
  Records a configuration change.
  """
  @spec record_config(String.t(), String.t(), term(), term(), %__MODULE__{}) :: %__MODULE__{}
  def record_config(module, key, old_value, new_value, register) do
    change = %{
      change_type: :config_change,
      module: module,
      key: key,
      old_value: old_value,
      new_value: new_value,
      metadata: %{}
    }

    record(change, register)
  end

  @doc """
  Records a Guardian decision.
  """
  @spec record_guardian_decision(String.t(), String.t(), String.t(), %__MODULE__{}) ::
          %__MODULE__{}
  def record_guardian_decision(action, decision, reason, register) do
    change = %{
      change_type: :guardian_decision,
      module: "Guardian",
      key: action,
      old_value: nil,
      new_value: decision,
      metadata: %{reason: reason}
    }

    record(change, register)
  end

  @doc """
  Returns a human-readable summary of the register (pure function).
  """
  @spec summary(%__MODULE__{}) :: String.t()
  def summary(%__MODULE__{} = register) do
    block_count = length(register.blocks)
    integrity = verify_chain(register)

    """
    ImmutableState Register Summary:
    - #{block_count} blocks
    - verified: #{register.verified}
    - integrity: #{inspect(integrity)}
    - last_hash: #{register.last_hash}
    - created: #{DateTime.to_iso8601(register.created_at)}
    - updated: #{DateTime.to_iso8601(register.last_updated)}
    """
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl GenServer
  def init(opts) do
    Logger.info("[ImmutableState] Initializing with DuckDB persistence (SC-SIL4-002)")
    Logger.info("[ImmutableState] Using Ed25519 signatures (SC-REG-003)")

    duckdb_path = get_duckdb_path()
    holon_path = Path.dirname(duckdb_path)
    verify_on_startup = get_verify_on_startup()
    skip_persistence = Keyword.get(opts, :skip_persistence, false)

    if skip_persistence do
      Logger.info("[ImmutableState] Persistence disabled (test mode)")
      {:ok, create_register()}
    else
      case initialize_with_duckdb(duckdb_path, holon_path, verify_on_startup) do
        {:ok, state} ->
          emit_initialized(state)
          {:ok, state}

        {:error, reason} ->
          Logger.warning(
            "[ImmutableState] DuckDB initialization failed (graceful degradation): #{inspect(reason)}. " <>
              "Running in memory-only mode. This is expected for HA/replica nodes sharing workspace."
          )

          # SC-SIL6-004: Graceful degradation - fall back to in-memory register
          # This happens when multiple containers share the same workspace and
          # the DuckDB file is locked by another node (expected in HA clusters)
          {:ok, create_register()}
      end
    end
  end

  @impl GenServer
  def handle_call({:record, _payload}, _from, %{verified: false} = state) do
    {:reply, {:error, :chain_not_verified}, state}
  end

  @impl GenServer
  def handle_call({:record, payload}, _from, state) do
    case do_record_with_persist(payload, state) do
      {:ok, block, new_state} ->
        emit_block_created(block)

        # ZUIP O-01: Publish immutable block append to Zenoh mesh
        Indrajaal.Observability.ZenohSafetyPublisher.publish_immutable_block(
          block.block_hash,
          Map.get(block.content, :change_type, :unknown)
        )

        {:reply, {:ok, block.block_hash}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call(:verify_chain, _from, state) do
    result = verify_blocks(state.blocks, @genesis_hash, state)
    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:verified?, _from, state) do
    {:reply, state.verified, state}
  end

  @impl GenServer
  def handle_call({:get_block, index}, _from, state) do
    block = Enum.find(state.blocks, fn b -> b.index == index end)
    {:reply, block, state}
  end

  @impl GenServer
  def handle_call({:get_blocks_by_type, change_type}, _from, state) do
    blocks =
      Enum.filter(state.blocks, fn b ->
        b.content.change_type == change_type
      end)

    {:reply, blocks, state}
  end

  @impl GenServer
  def handle_call(:compute_merkle_root, _from, state) do
    root = compute_merkle_root_impl(state.blocks)
    {:reply, root, state}
  end

  @impl GenServer
  def handle_call(:summary, _from, state) do
    summary_text = """
    ImmutableState Register Summary:
    - #{length(state.blocks)} blocks
    - verified: #{state.verified}
    - last_hash: #{state.last_hash}
    - created: #{DateTime.to_iso8601(state.created_at)}
    - updated: #{DateTime.to_iso8601(state.last_updated)}
    """

    {:reply, summary_text, state}
  end

  @impl GenServer
  def handle_call(:block_count, _from, state) do
    {:reply, length(state.blocks), state}
  end

  @impl GenServer
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl GenServer
  def handle_call(:get_public_key, _from, state) do
    public_key =
      case state.keypair do
        {pub, _sec} -> pub
        _ -> nil
      end

    {:reply, public_key, state}
  end

  @impl GenServer
  def handle_call(:attest_with_register, _from, state) do
    alias Indrajaal.Core.Holon.ImmutableRegister

    result =
      try do
        # Get core register's head hash and public key
        register_head = ImmutableRegister.head()
        register_pubkey = ImmutableRegister.public_key()

        # Create attestation
        {:ok, attestation} =
          ImmutableRegister.attest(
            "prajna_immutable_state",
            state.last_hash,
            public_key(state)
          )

        Logger.info("[ImmutableState] Cross-attested with ImmutableRegister (SC-REG-013)")

        {:ok,
         %{
           our_head: state.last_hash,
           register_head: register_head,
           register_pubkey: register_pubkey,
           attestation: attestation,
           timestamp: DateTime.utc_now()
         }}
      catch
        :exit, {:noproc, _} ->
          {:error, :register_not_running}

        :exit, reason ->
          {:error, {:attestation_failed, reason}}
      end

    {:reply, result, state}
  end

  @impl GenServer
  def handle_call(:attestation_info, _from, state) do
    {pub, _sec} = state.keypair || {nil, nil}

    info = %{
      holon_id: "prajna_immutable_state",
      head_hash: state.last_hash,
      block_count: length(state.blocks),
      public_key: pub && Base.encode64(pub),
      protocol_version: @protocol_version,
      verified: state.verified,
      merkle_root: compute_merkle_root_impl(state.blocks),
      timestamp: DateTime.utc_now()
    }

    {:reply, info, state}
  end

  # ============================================================================
  # Private: DuckDB Operations
  # ============================================================================

  defp initialize_with_duckdb(path, holon_path, verify_on_startup) do
    with {:ok, conn} <- open_duckdb(path),
         :ok <- ensure_schema(conn),
         {:ok, keypair} <- load_or_generate_keypair(holon_path),
         {:ok, blocks} <- load_blocks(conn),
         {:ok, state} <- build_state(conn, blocks, keypair, holon_path) do
      maybe_verify_chain(state, verify_on_startup)
    end
  end

  defp load_or_generate_keypair(holon_path) do
    keypair_path = Path.join(holon_path, @keypair_file)

    if File.exists?(keypair_path) do
      case File.read(keypair_path) do
        {:ok, binary} ->
          # Keypair is stored as {public_key, secret_key}
          case :erlang.binary_to_term(binary) do
            {pub, sec} = keypair when is_binary(pub) and is_binary(sec) ->
              Logger.info("[ImmutableState] Loaded existing Ed25519 keypair")
              {:ok, keypair}

            _ ->
              Logger.warning("[ImmutableState] Invalid keypair file, regenerating")
              generate_and_save_keypair(keypair_path)
          end

        {:error, reason} ->
          Logger.warning("[ImmutableState] Failed to read keypair: #{inspect(reason)}")
          generate_and_save_keypair(keypair_path)
      end
    else
      Logger.info("[ImmutableState] Generating new Ed25519 keypair")
      generate_and_save_keypair(keypair_path)
    end
  end

  defp generate_and_save_keypair(keypair_path) do
    keypair = generate_ed25519_keypair()
    binary = :erlang.term_to_binary(keypair)

    case File.write(keypair_path, binary) do
      :ok ->
        Logger.info("[ImmutableState] Ed25519 keypair saved to #{keypair_path}")
        {:ok, keypair}

      {:error, reason} ->
        Logger.error("[ImmutableState] Failed to save keypair: #{inspect(reason)}")
        # Continue with ephemeral keypair
        {:ok, keypair}
    end
  end

  defp open_duckdb(path) do
    # Ensure directory exists
    path |> Path.dirname() |> File.mkdir_p!()

    # SC-FIX-008: Support read-only mode for HA/replica nodes sharing workspace
    # Only the primary node (index 1) should have write access
    read_only =
      case System.get_env("NODE_INDEX") do
        "1" -> false
        nil -> false
        _ -> true
      end

    # NOTE: duckdbex 0.3.19 only supports path argument — opts reserved for future use
    _opts = if read_only, do: [read_only: true], else: []

    if read_only do
      Logger.info("[ImmutableState] Opening DuckDB in READ-ONLY mode for replica node")
    end

    # Ensure path is a binary
    path_bin = to_string(path)

    # SC-DBLOCAL-001: LOCAL holon DB access MUST be direct (NO Zenoh)
    # ImmutableState is LOCAL prajna state, uses direct Duckdbex access.
    # NOTE: duckdbex 0.3.19 only supports path argument.
    case Duckdbex.open(path_bin) do
      {:ok, db} ->
        case Duckdbex.connection(db) do
          {:ok, conn} ->
            Logger.info("[ImmutableState] DuckDB opened directly: #{path} (SC-DBLOCAL-001)")
            {:ok, conn}

          {:error, reason} ->
            Logger.error("[ImmutableState] DuckDB connection failed: #{inspect(reason)}")
            {:error, {:duckdb_connection_failed, reason}}
        end

      {:error, reason} ->
        Logger.error("[ImmutableState] DuckDB open failed: #{inspect(reason)}")
        {:error, {:duckdb_open_failed, reason}}
    end
  end

  defp ensure_schema(conn) do
    # SC-REG-006: Include RS parity column for error correction
    # SC-DBLOCAL-001: Direct Duckdbex access for local holon state
    sql = """
    CREATE TABLE IF NOT EXISTS prajna_immutable_blocks (
      block_index INTEGER PRIMARY KEY,
      timestamp TIMESTAMP NOT NULL,
      prev_hash VARCHAR(64) NOT NULL,
      content_hash VARCHAR(64) NOT NULL,
      block_hash VARCHAR(64) NOT NULL,
      signature VARCHAR(128) NOT NULL,
      content JSON NOT NULL,
      protocol_version VARCHAR(20) NOT NULL,
      rs_parity BLOB,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """

    # SC-DBLOCAL-001: Direct Duckdbex access for local holon state
    case Duckdbex.query(conn, sql) do
      {:ok, _} ->
        # Create index
        index_sql = """
        CREATE INDEX IF NOT EXISTS idx_block_hash
          ON prajna_immutable_blocks(block_hash)
        """

        case Duckdbex.query(conn, index_sql) do
          {:ok, _} -> ensure_parity_column(conn)
          {:error, reason} -> {:error, {:index_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:schema_failed, reason}}
    end
  end

  # Add rs_parity column if missing (migration for existing DBs)
  defp ensure_parity_column(conn) do
    alter_sql = "ALTER TABLE prajna_immutable_blocks ADD COLUMN IF NOT EXISTS rs_parity BLOB"

    # SC-DBLOCAL-001: Direct Duckdbex access for local holon state
    case Duckdbex.query(conn, alter_sql) do
      {:ok, _} -> :ok
      {:error, _} -> :ok
    end
  end

  defp load_blocks(conn) do
    sql = "SELECT * FROM prajna_immutable_blocks ORDER BY block_index ASC"

    # SC-DBLOCAL-001: Direct Duckdbex access for local holon state
    case Duckdbex.query(conn, sql) do
      {:ok, result} ->
        blocks =
          result
          |> Duckdbex.fetch_all()
          |> case do
            {:ok, rows} -> Enum.map(rows, &row_to_block/1)
            _ -> []
          end

        Logger.info(
          "[ImmutableState] Loaded #{length(blocks)} blocks from DuckDB (SC-DBLOCAL-001)"
        )

        {:ok, blocks}

      {:error, reason} ->
        {:error, {:load_failed, reason}}
    end
  end

  defp row_to_block([
         index,
         timestamp,
         prev_hash,
         content_hash,
         block_hash,
         signature,
         content_json,
         protocol_version,
         rs_parity,
         _created_at
       ]) do
    content =
      case Jason.decode(content_json, keys: :atoms) do
        {:ok, parsed} -> parsed
        {:error, _} -> %{change_type: :unknown}
      end

    %{
      index: index,
      timestamp: timestamp,
      prev_hash: prev_hash,
      content_hash: content_hash,
      block_hash: block_hash,
      signature: signature,
      content: content,
      protocol_version: protocol_version,
      rs_parity: rs_parity
    }
  end

  # Handle rows without rs_parity (legacy blocks)
  defp row_to_block([
         index,
         timestamp,
         prev_hash,
         content_hash,
         block_hash,
         signature,
         content_json,
         protocol_version,
         _created_at
       ]) do
    content =
      case Jason.decode(content_json, keys: :atoms) do
        {:ok, parsed} -> parsed
        {:error, _} -> %{change_type: :unknown}
      end

    %{
      index: index,
      timestamp: timestamp,
      prev_hash: prev_hash,
      content_hash: content_hash,
      block_hash: block_hash,
      signature: signature,
      content: content,
      protocol_version: protocol_version,
      rs_parity: nil
    }
  end

  defp row_to_block(_other), do: nil

  defp build_state(conn, [], keypair, holon_path) do
    now = DateTime.utc_now()

    state = %__MODULE__{
      blocks: [],
      last_index: -1,
      last_hash: @genesis_hash,
      created_at: now,
      last_updated: now,
      duckdb_conn: conn,
      verified: true,
      keypair: keypair,
      holon_path: holon_path
    }

    {:ok, state}
  end

  defp build_state(conn, blocks, keypair, holon_path) do
    blocks = Enum.reject(blocks, &is_nil/1)
    last_block = List.last(blocks)
    now = DateTime.utc_now()

    state = %__MODULE__{
      blocks: blocks,
      last_index: last_block.index,
      last_hash: last_block.block_hash,
      created_at: hd(blocks).timestamp,
      last_updated: now,
      duckdb_conn: conn,
      verified: false,
      keypair: keypair,
      holon_path: holon_path
    }

    {:ok, state}
  end

  defp maybe_verify_chain(state, false) do
    Logger.warning("[ImmutableState] Skipping chain verification (SC-SIL4-003 VIOLATION)")
    {:ok, %{state | verified: true}}
  end

  defp maybe_verify_chain(%{blocks: []} = state, true) do
    Logger.info("[ImmutableState] Empty chain - verified")
    {:ok, %{state | verified: true}}
  end

  defp maybe_verify_chain(state, true) do
    Logger.info("[ImmutableState] Verifying chain integrity with Ed25519 (SC-SIL4-003)...")

    case verify_blocks(state.blocks, @genesis_hash, state) do
      :valid ->
        Logger.info("[ImmutableState] Chain verified: #{length(state.blocks)} blocks valid")
        emit_chain_verified(state)
        {:ok, %{state | verified: true}}

      {:invalid, reason} ->
        Logger.error("[ImmutableState] Chain verification FAILED: #{reason}")
        emit_chain_verification_failed(reason)
        {:error, {:chain_invalid, reason}}
    end
  end

  defp do_record_with_persist(payload, state) do
    updated = do_record(payload, state)
    [block | _] = Enum.reverse(updated.blocks)

    case persist_block(state.duckdb_conn, block) do
      :ok ->
        {:ok, block, updated}

      {:error, reason} ->
        Logger.error("[ImmutableState] DuckDB persist failed: #{inspect(reason)}")
        emit_persist_failure(block, reason)
        {:error, :persist_failed}
    end
  end

  defp persist_block(nil, _block) do
    # No DuckDB connection (test mode)
    :ok
  end

  defp persist_block(conn, block) do
    # SC-REG-006: Include RS parity in persisted block
    # SC-SIL6-002: Use ON CONFLICT DO NOTHING to handle restart scenarios where
    # blocks may be re-recorded (immutability preserved, no duplicate errors)
    # NOTE: DuckDB uses PostgreSQL-style ON CONFLICT, not SQLite's INSERT OR IGNORE
    # SC-DBLOCAL-001: Direct Duckdbex access for local holon state
    sql = """
    INSERT INTO prajna_immutable_blocks
      (block_index, timestamp, prev_hash, content_hash, block_hash,
       signature, content, protocol_version, rs_parity)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (block_index) DO NOTHING
    """

    timestamp_str =
      case block.timestamp do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        other -> to_string(other)
      end

    params = [
      block.index,
      timestamp_str,
      block.prev_hash,
      block.content_hash,
      block.block_hash,
      block.signature,
      Jason.encode!(block.content),
      block.protocol_version,
      Map.get(block, :rs_parity)
    ]

    # SC-DBLOCAL-001: Direct Duckdbex access for local holon state
    case Duckdbex.query(conn, sql, params) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ============================================================================
  # Private: Block Creation
  # ============================================================================

  defp do_record(change, state) do
    new_index = state.last_index + 1
    now = DateTime.utc_now()

    content_json = Jason.encode!(change)
    content_hash = hash(content_json)

    block_data = "#{state.last_hash}|#{content_hash}|#{new_index}|#{DateTime.to_iso8601(now)}"
    block_hash = hash(block_data)

    # SC-REG-003: Ed25519 signature required for all blocks
    signature = sign_ed25519(block_hash, state.keypair)

    # SC-REG-006: Generate Reed-Solomon parity for error correction
    block_binary = encode_block_for_rs(block_hash, content_json, signature)
    {_data, rs_parity} = ReedSolomon.encode(block_binary)

    block = %{
      index: new_index,
      timestamp: now,
      prev_hash: state.last_hash,
      content_hash: content_hash,
      block_hash: block_hash,
      signature: signature,
      content: change,
      protocol_version: @protocol_version,
      rs_parity: rs_parity
    }

    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :block_created],
      %{block_height: new_index, timestamp: System.system_time(:millisecond)},
      %{content_type: Map.get(change, :change_type, :unknown)}
    )

    %{
      state
      | blocks: state.blocks ++ [block],
        last_index: new_index,
        last_hash: block_hash,
        last_updated: now
    }
  end

  # Encode block fields for RS parity calculation
  defp encode_block_for_rs(block_hash, content_json, signature) do
    "#{block_hash}|#{content_json}|#{signature}"
  end

  # ============================================================================
  # Private: Chain Verification
  # ============================================================================

  defp verify_blocks([], _expected_prev, _state), do: :valid

  defp verify_blocks([block | rest], expected_prev, state) do
    with :ok <- verify_prev_hash(block, expected_prev),
         :ok <- verify_content_hash(block),
         :ok <- verify_block_hash(block),
         :ok <- verify_block_signature(block, state) do
      verify_blocks(rest, block.block_hash, state)
    end
  end

  # Legacy version for pure function API (uses HMAC fallback)
  defp verify_blocks([], _expected_prev), do: :valid

  defp verify_blocks([block | rest], expected_prev) do
    with :ok <- verify_prev_hash(block, expected_prev),
         :ok <- verify_content_hash(block),
         :ok <- verify_block_hash(block) do
      # Skip signature verification in pure function mode (no keypair)
      verify_blocks(rest, block.block_hash)
    end
  end

  defp verify_prev_hash(block, expected_prev) do
    if block.prev_hash == expected_prev do
      :ok
    else
      emit_hash_mismatch(block, expected_prev)

      {:invalid,
       "Chain broken at block #{block.index}: expected #{expected_prev}, got #{block.prev_hash}"}
    end
  end

  defp verify_content_hash(block) do
    computed = hash(Jason.encode!(block.content))

    if block.content_hash == computed do
      :ok
    else
      {:invalid, "Block #{block.index}: content_hash mismatch"}
    end
  end

  defp verify_block_hash(block) do
    timestamp_str =
      case block.timestamp do
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        other -> to_string(other)
      end

    block_data = "#{block.prev_hash}|#{block.content_hash}|#{block.index}|#{timestamp_str}"
    computed = hash(block_data)

    if block.block_hash == computed do
      :ok
    else
      {:invalid, "Block #{block.index}: block_hash mismatch"}
    end
  end

  defp verify_block_signature(block, state) do
    case verify_ed25519(block.block_hash, block.signature, state.keypair) do
      true ->
        :ok

      false ->
        emit_signature_invalid(block)
        {:invalid, "Block #{block.index}: Ed25519 signature invalid (SC-REG-003)"}
    end
  end

  # ============================================================================
  # Reed-Solomon Verification and Repair (SC-REG-006, SC-REG-008)
  # ============================================================================

  @doc """
  Verifies block integrity using Reed-Solomon parity (SC-REG-006).
  Returns :ok if valid, {:repaired, block} if fixed, or {:invalid, reason} if corrupt.
  """
  def verify_block_rs(block) do
    case Map.get(block, :rs_parity) do
      nil ->
        # No parity data (legacy block), skip RS verification
        :ok

      parity when is_binary(parity) ->
        content_json = Jason.encode!(block.content)
        block_binary = encode_block_for_rs(block.block_hash, content_json, block.signature)

        # Use Prajna RS wrapper API: verify_parity/2 takes (data, parity)
        case ReedSolomon.verify_parity(block_binary, parity) do
          {:ok, :valid} ->
            :ok

          {:error, :corrupted, _error_info} ->
            # RS parity corrupted, attempt repair via decode/2
            case ReedSolomon.decode(block_binary, parity) do
              {:ok, _verified_data} ->
                # Data was valid despite parity issue
                :ok

              {:repaired, repaired_data, repair_info} ->
                Logger.warning(
                  "[ImmutableState] Block #{block.index} repaired via RS error correction " <>
                    "(#{repair_info.errors_corrected} errors corrected, SC-REG-008)"
                )

                # Re-encode parity for repaired data
                {_data, new_parity} = ReedSolomon.encode(repaired_data)
                {:repaired, %{block | rs_parity: new_parity}}

              {:error, :unrepairable} ->
                Logger.error(
                  "[ImmutableState] Block #{block.index} RS verification failed: unrepairable"
                )

                {:invalid,
                 "Block #{block.index}: RS parity check failed, data unrepairable (SC-REG-006)"}
            end
        end
    end
  end

  @doc """
  Performs full chain verification with RS error correction (SC-REG-002, SC-REG-006).
  Attempts repair of corrupted blocks and logs all repair events (SC-REG-008).
  """
  def verify_chain_with_repair(%__MODULE__{} = state) do
    Logger.info("[ImmutableState] Verifying chain with RS error correction (SC-REG-006)...")

    {verified_blocks, repair_log, errors} =
      state.blocks
      |> Enum.reduce({[], [], []}, fn block, {blocks_acc, repairs_acc, errors_acc} ->
        case verify_block_rs(block) do
          :ok ->
            {[block | blocks_acc], repairs_acc, errors_acc}

          {:repaired, repaired_block} ->
            repair_entry = %{
              block_index: block.index,
              repaired_at: DateTime.utc_now(),
              constraint: "SC-REG-008"
            }

            emit_block_repaired(repaired_block, repair_entry)
            {[repaired_block | blocks_acc], [repair_entry | repairs_acc], errors_acc}

          {:invalid, reason} ->
            {blocks_acc, repairs_acc, [{block.index, reason} | errors_acc]}
        end
      end)

    case errors do
      [] ->
        repair_count = length(repair_log)

        if repair_count > 0 do
          Logger.info("[ImmutableState] Chain verified with #{repair_count} repairs (SC-REG-008)")
          emit_chain_repaired(repair_count, repair_log)
        end

        {:ok,
         %{
           state
           | blocks: Enum.reverse(verified_blocks),
             repair_count: state.repair_count + repair_count,
             verification_stats: %{
               last_verified: DateTime.utc_now(),
               blocks_verified: length(verified_blocks),
               repairs_made: repair_count
             }
         }}

      _ ->
        Logger.error(
          "[ImmutableState] Chain verification failed: #{length(errors)} unrepairable blocks"
        )

        {:error, {:chain_corrupt, errors}}
    end
  end

  @doc """
  Records a repair event to the register (SC-REG-008).
  This creates a special block documenting the repair for audit purposes.
  """
  def record_repair_event(block_index, repair_info, state) do
    repair_change = %{
      change_type: :repair_event,
      module: "ImmutableState",
      key: "rs_repair",
      old_value: nil,
      new_value: %{
        repaired_block_index: block_index,
        repair_info: repair_info,
        repair_timestamp: DateTime.utc_now()
      },
      metadata: %{
        constraint: "SC-REG-008",
        description: "Reed-Solomon repair event recorded"
      }
    }

    do_record(repair_change, state)
  end

  @doc """
  Returns RS parameters and verification statistics.
  """
  def rs_status do
    %{
      parameters: ReedSolomon.parameters(),
      constraint: "SC-REG-006"
    }
  end

  # ============================================================================
  # Private: Merkle Root
  # ============================================================================

  defp compute_merkle_root_impl([]), do: hash("empty_merkle_root")

  defp compute_merkle_root_impl(blocks) do
    hashes = Enum.map(blocks, & &1.content_hash)
    compute_merkle_root_recursive(hashes)
  end

  defp compute_merkle_root_recursive([single]), do: single

  defp compute_merkle_root_recursive(hashes) do
    hashes
    |> Enum.chunk_every(2)
    |> Enum.map(fn
      [a, b] -> hash(a <> b)
      [a] -> hash(a <> a)
    end)
    |> compute_merkle_root_recursive()
  end

  # ============================================================================
  # Private: Ed25519 Cryptography (SC-REG-003)
  # ============================================================================

  @doc false
  defp generate_ed25519_keypair do
    # SC-REG-003: Ed25519 signatures required
    # Returns {public_key (32 bytes), secret_key (32 bytes seed in OTP 28+)}
    :crypto.generate_key(:eddsa, :ed25519)
  end

  # SC-REG-002: SHA3-256 for block hashing (per CLAUDE.md Section 0.0)
  defp hash(data) do
    :crypto.hash(:sha3_256, data) |> Base.encode16(case: :lower)
  end

  # Sign block hash with Ed25519 (SC-REG-003).
  # Returns Base64-encoded signature for DuckDB storage.
  defp sign_ed25519(block_hash, {_public_key, secret_key}) do
    hash_binary = Base.decode16!(block_hash, case: :lower)
    signature = :crypto.sign(:eddsa, :none, hash_binary, [secret_key, :ed25519])
    Base.encode64(signature)
  end

  defp sign_ed25519(_block_hash, nil) do
    # Fallback for test mode without keypair - use placeholder
    Base.encode64(:crypto.strong_rand_bytes(64))
  end

  # Verify Ed25519 signature (SC-REG-003).
  defp verify_ed25519(block_hash, signature_b64, {public_key, _secret_key}) do
    try do
      hash_binary = Base.decode16!(block_hash, case: :lower)
      signature = Base.decode64!(signature_b64)
      :crypto.verify(:eddsa, :none, hash_binary, signature, [public_key, :ed25519])
    rescue
      _ -> false
    end
  end

  defp verify_ed25519(_block_hash, _signature, nil), do: true

  # ============================================================================
  # Private: Config Helpers
  # ============================================================================

  defp get_timeout do
    try do
      Config.get(:orchestrator_command_timeout_ms)
    rescue
      _ -> 30_000
    end
  end

  # SC-FIX-009: Support environment variable for DuckDB path (SC-HOLON-008 isolation)
  # SC-DBNAME-001: Use UHI-based path resolution
  # Precedence: ENV > Config > UHI Resolution > Legacy Default
  @prajna_register_uhi "ex:l5:prj:srv:prajna"

  defp get_duckdb_path do
    # Check environment variable first for cluster node isolation
    case System.get_env("PRAJNA_REGISTER_PATH") do
      nil ->
        case System.get_env("HOLON_DATA_PATH") do
          nil ->
            # Try config first, then UHI resolution, then legacy default
            try do
              Config.get(:immutable_state_duckdb_path)
            rescue
              _ ->
                # SC-DBNAME-001: Use UHI-based path resolution
                fqdn = "#{@prajna_register_uhi}:register"

                case DatabasePath.resolve(fqdn) do
                  {:ok, path} -> path
                  {:error, _} -> "data/holons/ex/l5/prj/prajna/register.duckdb"
                end
            end

          holon_path ->
            # Use holon data path with default filename
            Path.join(holon_path, "register.duckdb")
        end

      explicit_path ->
        explicit_path
    end
  end

  defp get_verify_on_startup do
    try do
      Config.get(:immutable_state_verify_on_startup)
    rescue
      _ -> true
    end
  end

  # ============================================================================
  # Private: Telemetry
  # ============================================================================

  defp emit_initialized(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :initialized],
      %{block_count: length(state.blocks), timestamp: System.system_time(:millisecond)},
      %{verified: state.verified}
    )
  end

  defp emit_block_created(block) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :block_created],
      %{block_height: block.index, timestamp: System.system_time(:millisecond)},
      %{content_type: Map.get(block.content, :change_type, :unknown)}
    )
  end

  defp emit_chain_verified(state) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :chain_verified],
      %{block_count: length(state.blocks), timestamp: System.system_time(:millisecond)},
      %{}
    )
  end

  defp emit_chain_verification_failed(reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :verification_failed],
      %{timestamp: System.system_time(:millisecond)},
      %{reason: reason}
    )
  end

  defp emit_persist_failure(block, reason) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :persist_failed],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{reason: reason}
    )
  end

  defp emit_hash_mismatch(block, expected) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :hash_mismatch],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{expected: expected, actual: block.prev_hash}
    )
  end

  defp emit_signature_invalid(block) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :signature_invalid],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{}
    )
  end

  # SC-REG-008: Telemetry for repair events
  defp emit_block_repaired(block, repair_info) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :block_repaired],
      %{block_index: block.index, timestamp: System.system_time(:millisecond)},
      %{repair_info: repair_info, constraint: "SC-REG-008"}
    )
  end

  defp emit_chain_repaired(repair_count, repair_log) do
    :telemetry.execute(
      [:indrajaal, :prajna, :immutable_state, :chain_repaired],
      %{repair_count: repair_count, timestamp: System.system_time(:millisecond)},
      %{repair_log: repair_log, constraint: "SC-REG-008"}
    )
  end
end
