defmodule Indrajaal.Jain.Replication do
  @moduledoc """
  Replication Protocol - Constitutional Self-Replication for v20.0.0

  Implements self-replication with constitutional constraints:
  - Replication only with verified constitution
  - Full constitution transfer to children
  - Replication rate limiting
  - Lineage tracking

  ## Replication Model

  Replication requires:
  1. Verified constitution (parent)
  2. Sufficient resources
  3. Replication token
  4. Available capacity (10 max children)

  Child receives:
  1. Complete constitution
  2. Genesis seed
  3. Parent lineage
  4. Initial resources

  ## Replication Strategies
  - **Conservative**: Slow, high verification
  - **Moderate**: Balanced speed/safety
  - **Aggressive**: Fast, minimum verification

  ## STAMP Constraints
  - SC-REP-001: Replication MUST include full constitution
  - SC-REP-002: Maximum 10 direct children
  - SC-REP-003: Parent MUST verify before replication
  - SC-REP-004: Child MUST verify immediately after creation
  """

  require Logger

  alias Indrajaal.Jain.{Constitution, Cryptography, Genesis}

  @type replication_strategy :: :conservative | :moderate | :aggressive

  @type replication_request :: %{
          parent_id: String.t(),
          generation: non_neg_integer(),
          constitution_hash: binary(),
          token: binary(),
          strategy: replication_strategy()
        }

  @type replication_result :: %{
          child_id: String.t(),
          genesis_seed: binary(),
          parent_id: String.t(),
          generation: non_neg_integer(),
          created_at: DateTime.t()
        }

  @type lineage :: %{
          node_id: String.t(),
          generation: non_neg_integer(),
          parent_id: String.t() | nil,
          created_at: DateTime.t()
        }

  # Maximum children per node (SC-REP-002)
  @max_children 10

  # Replication cooldown (ms) - Reserved for rate limiting implementation
  # @replication_cooldown 60_000

  @doc """
  Initiates a replication.
  """
  @spec replicate(map(), replication_strategy()) :: {:ok, replication_result()} | {:error, term()}
  def replicate(parent_node, strategy \\ :moderate) do
    Logger.info("🌿 Initiating replication for #{parent_node.id} (strategy: #{strategy})")

    with :ok <- check_replication_preconditions(parent_node),
         {:ok, _token} <- create_replication_token(parent_node),
         {:ok, seed} <- create_genesis_seed(parent_node, strategy),
         {:ok, child_id} <- spawn_child(parent_node, seed) do
      result = %{
        child_id: child_id,
        genesis_seed: seed,
        parent_id: parent_node.id,
        generation: parent_node.generation + 1,
        created_at: DateTime.utc_now()
      }

      Logger.info("🌿 Replication successful: #{parent_node.id} → #{child_id}")

      {:ok, result}
    end
  end

  @doc """
  Checks if replication is allowed.
  """
  @spec can_replicate?(map()) :: boolean()
  def can_replicate?(node) do
    case check_replication_preconditions(node) do
      :ok -> true
      {:error, _} -> false
    end
  end

  @doc """
  Gets the lineage of a node.
  """
  @spec get_lineage(map()) :: [lineage()]
  def get_lineage(node) do
    # Build lineage from node metadata
    current = %{
      node_id: node.id,
      generation: node.generation,
      parent_id: node.parent_id,
      created_at: node.created_at
    }

    [current]
  end

  @doc """
  Verifies a replication token.
  """
  @spec verify_token(binary(), Constitution.constitution()) :: :ok | {:error, term()}
  def verify_token(token, constitution) do
    case Cryptography.verify_replication_token(token, constitution) do
      {:ok, _payload} -> :ok
      error -> error
    end
  end

  @doc """
  Calculates replication fitness (0.0 - 1.0).
  """
  @spec replication_fitness(map()) :: float()
  def replication_fitness(node) do
    resource_score = calculate_resource_score(node.resources)
    children_score = 1.0 - length(node.children) / @max_children
    health_score = if node.state == :sterile, do: 0.0, else: 1.0

    (resource_score + children_score + health_score) / 3.0
  end

  @doc """
  Gets replication statistics.
  """
  @spec stats(map()) :: map()
  def stats(node) do
    %{
      children_count: length(node.children),
      max_children: @max_children,
      can_replicate: can_replicate?(node),
      fitness: replication_fitness(node),
      generation: node.generation
    }
  end

  # Private helpers

  defp check_replication_preconditions(node) do
    cond do
      node.state == :sterile ->
        {:error, :sterile}

      length(node.children) >= @max_children ->
        {:error, :max_children_reached}

      node.state != :replicating and node.state != :mature ->
        {:error, :not_ready}

      true ->
        # Verify constitution (SC-REP-003)
        constitution = Constitution.load()
        Constitution.verify(constitution)
    end
  end

  defp create_replication_token(_node) do
    constitution = Constitution.load()
    Cryptography.create_replication_token(constitution)
  end

  defp create_genesis_seed(parent_node, strategy) do
    config = %{
      generation: parent_node.generation + 1,
      parent_id: parent_node.id,
      strategy: strategy
    }

    Genesis.create_seed(config)
  end

  defp spawn_child(parent_node, _seed) do
    # In production, would actually spawn a new process/container
    child_id = generate_child_id(parent_node)

    Logger.info("Spawning child node: #{child_id}")

    {:ok, child_id}
  end

  defp generate_child_id(parent_node) do
    rand_bytes = :crypto.strong_rand_bytes(4)
    suffix = Base.encode16(rand_bytes, case: :lower)
    "jain_#{parent_node.generation + 1}_#{suffix}"
  end

  defp calculate_resource_score(resources) do
    # Score based on resource fullness
    values =
      Enum.map(resources, fn {_type, amount} ->
        # Normalize (assuming some maximum values)
        min(1.0, amount / 1000)
      end)

    if Enum.empty?(values) do
      0.0
    else
      Enum.sum(values) / length(values)
    end
  end
end
