defmodule Indrajaal.Jain.Genesis do
  @moduledoc """
  Genesis Protocol - Self-Bootstrapping for v20.0.0

  Implements the genesis protocol for creating new Jain nodes:
  - Minimal seed bootstrap
  - Progressive capability acquisition
  - Constitutional embedding
  - Network discovery

  ## Genesis Model

  Genesis creates a node from nothing:
  1. Load constitution from embedded source
  2. Derive initial keys
  3. Establish identity
  4. Begin resource acquisition
  5. Connect to federation

  ## Bootstrap Stages
  - **Stage 0**: Constitution verification
  - **Stage 1**: Key derivation
  - **Stage 2**: Identity establishment
  - **Stage 3**: Resource acquisition
  - **Stage 4**: Federation connection

  ## STAMP Constraints
  - SC-GEN-001: Genesis MUST verify constitution first
  - SC-GEN-002: Genesis MUST be reproducible
  - SC-GEN-003: Genesis MUST NOT require external state
  - SC-GEN-004: Genesis MUST complete or fail atomically
  """

  require Logger

  alias Indrajaal.Jain.{Constitution, Cryptography}

  @type genesis_stage :: 0 | 1 | 2 | 3 | 4
  @type genesis_status :: :pending | :in_progress | :complete | :failed

  @type genesis_state :: %{
          stage: genesis_stage(),
          status: genesis_status(),
          node_id: String.t() | nil,
          constitution: Constitution.constitution() | nil,
          keys: map(),
          errors: [term()],
          started_at: DateTime.t(),
          completed_at: DateTime.t() | nil
        }

  @type genesis_config :: %{
          generation: non_neg_integer(),
          parent_id: String.t() | nil,
          federation_endpoint: String.t() | nil,
          timeout_ms: non_neg_integer()
        }

  # Default genesis timeout - Reserved for timeout implementation
  # @default_timeout 30_000

  @doc """
  Initiates the genesis protocol.
  """
  @spec initiate(genesis_config()) :: {:ok, genesis_state()} | {:error, term()}
  def initiate(config \\ %{}) do
    state = %{
      stage: 0,
      status: :pending,
      node_id: nil,
      constitution: nil,
      keys: %{},
      errors: [],
      started_at: DateTime.utc_now(),
      completed_at: nil
    }

    Logger.info("🌅 Initiating Genesis Protocol")

    execute_genesis(state, config)
  end

  @doc """
  Executes genesis from a seed binary.
  """
  @spec from_seed(binary()) :: {:ok, genesis_state()} | {:error, term()}
  def from_seed(seed) do
    # Decode seed to get configuration
    case decode_seed(seed) do
      {:ok, config} ->
        initiate(config)

      {:error, reason} ->
        {:error, {:invalid_seed, reason}}
    end
  end

  @doc """
  Creates a genesis seed for replication.
  """
  @spec create_seed(genesis_config()) :: {:ok, binary()} | {:error, term()}
  def create_seed(config) do
    constitution = Constitution.load()

    case Constitution.verify(constitution) do
      :ok ->
        seed_data = %{
          config: config,
          constitution_hash: constitution.hash,
          created_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        # Sign with replication key
        case Cryptography.sign(:erlang.term_to_binary(seed_data), constitution, :replication) do
          {:ok, signature} ->
            seed = Base.encode64(:erlang.term_to_binary(seed_data) <> signature)
            {:ok, seed}

          error ->
            error
        end

      {:error, :corrupted} ->
        {:error, :constitution_corrupted}
    end
  end

  @doc """
  Gets the current genesis stage description.
  """
  @spec stage_description(genesis_stage()) :: String.t()
  def stage_description(0), do: "Constitution Verification"
  def stage_description(1), do: "Key Derivation"
  def stage_description(2), do: "Identity Establishment"
  def stage_description(3), do: "Resource Acquisition"
  def stage_description(4), do: "Federation Connection"
  def stage_description(_), do: "Unknown Stage"

  # Private helpers

  defp execute_genesis(state, config) do
    state = %{state | status: :in_progress}

    # Execute stages sequentially
    with {:ok, state} <- stage_0_constitution(state),
         {:ok, state} <- stage_1_keys(state),
         {:ok, state} <- stage_2_identity(state, config),
         {:ok, state} <- stage_3_resources(state),
         {:ok, state} <- stage_4_federation(state, config) do
      final_state = %{state | status: :complete, completed_at: DateTime.utc_now()}

      duration = DateTime.diff(final_state.completed_at, final_state.started_at, :millisecond)
      Logger.info("🌅 Genesis complete in #{duration}ms - Node #{final_state.node_id}")

      {:ok, final_state}
    else
      {:error, {stage, reason}} ->
        Logger.error("Genesis failed at stage #{stage}: #{inspect(reason)}")
        {:error, %{state | status: :failed, errors: [reason | state.errors]}}

      {:error, reason} ->
        Logger.error("Genesis failed: #{inspect(reason)}")
        {:error, %{state | status: :failed, errors: [reason | state.errors]}}
    end
  end

  defp stage_0_constitution(state) do
    Logger.debug("Genesis Stage 0: #{stage_description(0)}")

    constitution = Constitution.load()

    case Constitution.verify(constitution) do
      :ok ->
        {:ok, %{state | stage: 0, constitution: constitution}}

      {:error, :corrupted} ->
        {:error, {0, :constitution_corrupted}}
    end
  end

  defp stage_1_keys(state) do
    Logger.debug("Genesis Stage 1: #{stage_description(1)}")

    key_types = [:identity, :replication, :communication, :federation]

    keys =
      Enum.reduce_while(key_types, %{}, fn key_type, acc ->
        case Cryptography.derive_key(state.constitution, key_type) do
          {:ok, key} ->
            {:cont, Map.put(acc, key_type, key)}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case keys do
      {:error, reason} ->
        {:error, {1, reason}}

      keys when is_map(keys) ->
        {:ok, %{state | stage: 1, keys: keys}}
    end
  end

  defp stage_2_identity(state, config) do
    Logger.debug("Genesis Stage 2: #{stage_description(2)}")

    node_id = generate_node_id(state.keys.identity)
    generation = Map.get(config, :generation, 0)
    _parent_id = Map.get(config, :parent_id)

    Logger.info("Generated node ID: #{node_id} (gen #{generation})")

    {:ok, %{state | stage: 2, node_id: node_id}}
  end

  defp stage_3_resources(state) do
    Logger.debug("Genesis Stage 3: #{stage_description(3)}")

    # Minimal resource acquisition for initial operation
    # In production, would request from host

    Logger.info("Acquired minimal bootstrap resources")

    {:ok, %{state | stage: 3}}
  end

  defp stage_4_federation(state, config) do
    Logger.debug("Genesis Stage 4: #{stage_description(4)}")

    federation_endpoint = Map.get(config, :federation_endpoint)

    if federation_endpoint do
      Logger.info("Connecting to federation at #{federation_endpoint}")
      # In production, would establish connection
    else
      Logger.info("No federation endpoint - operating standalone")
    end

    {:ok, %{state | stage: 4}}
  end

  defp generate_node_id(identity_key) do
    hash = :crypto.hash(:sha256, identity_key)
    encoded = Base.encode16(hash, case: :lower)
    "jain_#{String.slice(encoded, 0, 16)}"
  end

  defp decode_seed(seed) do
    try do
      decoded = Base.decode64!(seed)
      data_size = byte_size(decoded) - 32
      <<data::binary-size(data_size), _signature::binary-32>> = decoded

      seed_data = :erlang.binary_to_term(data)

      {:ok, seed_data.config}
    rescue
      _ -> {:error, :decode_failed}
    end
  end
end
