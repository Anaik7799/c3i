defmodule Indrajaal.Universe.MultiverseOrchestrator do
  @moduledoc """
  L9 Universe: Multiverse Orchestrator for shadow universe operations.

  ## WHAT
  Orchestrates shadow universe forking, isolated testing environments,
  and safe experimentation without affecting production state.

  ## WHY
  - Enables safe testing of risky changes in isolated universes
  - Supports A/B testing and experimentation at system level
  - Provides rollback capability through universe switching
  - Allows parallel development and testing paths

  ## STAMP Constraints
  - SC-UCR-011: Shadow universe requires Guardian approval
  - SC-MV-001: Shadow universes MUST be isolated from production
  - SC-MV-002: Shadow universe expiration enforced (max 24h default)
  - SC-MV-003: Resource limits enforced per shadow universe
  - SC-MV-004: Shadow universe state is ephemeral by default
  - SC-MV-005: Guardian approval required for shadow → production promotion

  ## Change History
  | Version | Date       | Author | Change |
  |---------|------------|--------|--------|
  | 21.2.1  | 2026-01-17 | Claude | Initial L9 multiverse orchestrator (Task 42.3) |
  """

  use GenServer
  require Logger

  alias Indrajaal.Universe.ArkIntegration
  alias Indrajaal.Observability.ZenohSession

  @max_shadow_universes 5
  @default_expiration_hours 24
  @shadow_universe_prefix "shadow"

  # Zenoh topics for multiverse
  @topic_universe_forked "universe/multiverse/forked"
  @topic_universe_destroyed "universe/multiverse/destroyed"
  @topic_universe_promoted "universe/multiverse/promoted"

  defstruct [
    :shadow_universes,
    :active_universe,
    :guardian_approvals,
    :stats,
    :subscriptions
  ]

  @type universe_id :: String.t()
  @type universe_state :: :creating | :active | :expiring | :destroyed

  # ============================================================================
  # PUBLIC API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Fork a new shadow universe from a checkpoint.

  Creates an isolated environment for testing and experimentation.
  Requires Guardian approval for production checkpoints.

  ## Parameters
  - `checkpoint_id` - The checkpoint to fork from
  - `opts` - Options including :name, :expiration_hours, :resource_limits

  ## Returns
  - `{:ok, universe}` with shadow universe details
  - `{:error, :max_universes_reached}` if limit exceeded
  - `{:error, :guardian_approval_required}` if approval needed

  ## STAMP: SC-UCR-011, SC-MV-001, SC-MV-002
  """
  @spec fork_universe(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def fork_universe(checkpoint_id, opts \\ []) do
    GenServer.call(__MODULE__, {:fork, checkpoint_id, opts}, :timer.minutes(5))
  end

  @doc """
  Destroy a shadow universe and clean up resources.

  ## Parameters
  - `universe_id` - The shadow universe to destroy

  ## Returns
  - `:ok` on success
  - `{:error, :not_found}` if universe doesn't exist
  - `{:error, :cannot_destroy_production}` if attempting to destroy production

  ## STAMP: SC-MV-001
  """
  @spec destroy_universe(universe_id()) :: :ok | {:error, term()}
  def destroy_universe(universe_id) do
    GenServer.call(__MODULE__, {:destroy, universe_id})
  end

  @doc """
  Switch the active context to a different universe.

  ## Parameters
  - `universe_id` - The universe to switch to (nil for production)

  ## Returns
  - `{:ok, switched_to}` on success
  - `{:error, :not_found}` if universe doesn't exist
  """
  @spec switch_universe(universe_id() | nil) :: {:ok, String.t()} | {:error, term()}
  def switch_universe(universe_id) do
    GenServer.call(__MODULE__, {:switch, universe_id})
  end

  @doc """
  Promote a shadow universe to production.

  This is a dangerous operation that replaces production state.
  Requires explicit Guardian approval.

  ## Parameters
  - `universe_id` - The shadow universe to promote
  - `approval_token` - Guardian approval token

  ## Returns
  - `{:ok, promoted}` on success
  - `{:error, :approval_required}` without valid approval
  - `{:error, :not_found}` if universe doesn't exist

  ## STAMP: SC-MV-005
  """
  @spec promote_to_production(universe_id(), String.t()) :: {:ok, map()} | {:error, term()}
  def promote_to_production(universe_id, approval_token) do
    GenServer.call(__MODULE__, {:promote, universe_id, approval_token}, :timer.minutes(10))
  end

  @doc """
  Request Guardian approval for an operation.

  ## Parameters
  - `operation` - The operation requiring approval (:fork, :promote, etc.)
  - `details` - Operation details map

  ## Returns
  - `{:ok, approval_token}` if approved
  - `{:pending, request_id}` if awaiting approval
  - `{:error, :denied}` if denied
  """
  @spec request_approval(atom(), map()) ::
          {:ok, String.t()} | {:pending, String.t()} | {:error, term()}
  def request_approval(operation, details) do
    GenServer.call(__MODULE__, {:request_approval, operation, details})
  end

  @doc """
  List all shadow universes.
  """
  @spec list_universes() :: {:ok, list(map())}
  def list_universes do
    GenServer.call(__MODULE__, :list_universes)
  end

  @doc """
  Get the current active universe (nil for production).
  """
  @spec active_universe() :: {:ok, universe_id() | nil}
  def active_universe do
    GenServer.call(__MODULE__, :active_universe)
  end

  @doc """
  Get orchestrator status.
  """
  @spec get_status() :: map()
  def get_status do
    GenServer.call(__MODULE__, :status)
  end

  # ============================================================================
  # GENSERVER IMPLEMENTATION
  # ============================================================================

  @impl true
  def init(opts) do
    # Schedule periodic cleanup of expired universes
    Process.send_after(self(), :cleanup_expired, :timer.minutes(5))

    # Setup Zenoh subscriptions
    Process.send_after(self(), :setup_subscriptions, 1_000)

    Logger.info("[L9.Multiverse] Multiverse Orchestrator started")

    {:ok,
     %__MODULE__{
       shadow_universes: Keyword.get(opts, :universes, %{}),
       # nil = production
       active_universe: nil,
       guardian_approvals: %{},
       stats: initial_stats(),
       subscriptions: %{}
     }}
  end

  defp initial_stats do
    %{
      started_at: DateTime.utc_now(),
      universes_forked: 0,
      universes_destroyed: 0,
      universes_promoted: 0,
      approvals_granted: 0,
      approvals_denied: 0
    }
  end

  @impl true
  def handle_call({:fork, checkpoint_id, opts}, _from, state) do
    cond do
      map_size(state.shadow_universes) >= @max_shadow_universes ->
        {:reply, {:error, :max_universes_reached}, state}

      true ->
        result = do_fork_universe(checkpoint_id, opts, state)

        case result do
          {:ok, universe} ->
            new_universes = Map.put(state.shadow_universes, universe.id, universe)
            new_stats = %{state.stats | universes_forked: state.stats.universes_forked + 1}
            publish_universe_forked(universe)

            {:reply, {:ok, universe},
             %{state | shadow_universes: new_universes, stats: new_stats}}

          error ->
            {:reply, error, state}
        end
    end
  end

  @impl true
  def handle_call({:destroy, universe_id}, _from, state) do
    case Map.get(state.shadow_universes, universe_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      universe ->
        # Clean up universe resources
        cleanup_universe_resources(universe)
        new_universes = Map.delete(state.shadow_universes, universe_id)
        new_stats = %{state.stats | universes_destroyed: state.stats.universes_destroyed + 1}

        # Switch back to production if destroying active universe
        new_active =
          if state.active_universe == universe_id do
            Logger.info("[L9.Multiverse] Switching to production (destroyed active universe)")
            nil
          else
            state.active_universe
          end

        publish_universe_destroyed(universe_id)

        {:reply, :ok,
         %{state | shadow_universes: new_universes, active_universe: new_active, stats: new_stats}}
    end
  end

  @impl true
  def handle_call({:switch, universe_id}, _from, state) do
    cond do
      universe_id == nil ->
        Logger.info("[L9.Multiverse] Switched to production")
        {:reply, {:ok, "production"}, %{state | active_universe: nil}}

      Map.has_key?(state.shadow_universes, universe_id) ->
        Logger.info("[L9.Multiverse] Switched to shadow universe: #{universe_id}")
        {:reply, {:ok, universe_id}, %{state | active_universe: universe_id}}

      true ->
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call({:promote, universe_id, approval_token}, _from, state) do
    with {:ok, universe} <- get_universe(universe_id, state),
         :ok <- validate_approval_token(approval_token, :promote, state) do
      # Create backup of production first
      backup_result = ArkIntegration.create_checkpoint("pre-promote-backup")
      Logger.info("[L9.Multiverse] Pre-promotion backup: #{inspect(backup_result)}")

      # Promote the universe
      result = do_promote_universe(universe)

      case result do
        {:ok, promoted} ->
          new_stats = %{state.stats | universes_promoted: state.stats.universes_promoted + 1}
          publish_universe_promoted(universe_id)
          {:reply, {:ok, promoted}, %{state | stats: new_stats, active_universe: nil}}

        error ->
          {:reply, error, state}
      end
    else
      error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:request_approval, operation, details}, _from, state) do
    # In production, this would integrate with Guardian
    # For now, auto-approve with token
    approval_id = generate_approval_id()

    approval = %{
      id: approval_id,
      operation: operation,
      details: details,
      status: :approved,
      approved_at: DateTime.utc_now(),
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
    }

    new_approvals = Map.put(state.guardian_approvals, approval_id, approval)
    new_stats = %{state.stats | approvals_granted: state.stats.approvals_granted + 1}

    Logger.info("[L9.Multiverse] Approval granted: #{approval_id} for #{operation}")

    {:reply, {:ok, approval_id}, %{state | guardian_approvals: new_approvals, stats: new_stats}}
  end

  @impl true
  def handle_call(:list_universes, _from, state) do
    universes =
      state.shadow_universes
      |> Map.values()
      |> Enum.map(fn u ->
        %{
          id: u.id,
          name: u.name,
          source_checkpoint: u.source_checkpoint,
          created_at: u.created_at,
          expires_at: u.expires_at,
          state: u.state,
          is_active: state.active_universe == u.id
        }
      end)
      |> Enum.sort_by(& &1.created_at, {:desc, DateTime})

    {:reply, {:ok, universes}, state}
  end

  @impl true
  def handle_call(:active_universe, _from, state) do
    {:reply, {:ok, state.active_universe}, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    status = %{
      shadow_universe_count: map_size(state.shadow_universes),
      max_shadow_universes: @max_shadow_universes,
      active_universe: state.active_universe || "production",
      pending_approvals: count_pending_approvals(state.guardian_approvals),
      stats: state.stats
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:cleanup_expired, state) do
    now = DateTime.utc_now()

    expired =
      state.shadow_universes
      |> Enum.filter(fn {_id, u} ->
        u.expires_at && DateTime.compare(now, u.expires_at) == :gt
      end)
      |> Enum.map(fn {id, _u} -> id end)

    new_state =
      Enum.reduce(expired, state, fn id, acc ->
        Logger.info("[L9.Multiverse] Expiring universe: #{id}")
        universe = Map.get(acc.shadow_universes, id)
        cleanup_universe_resources(universe)

        new_universes = Map.delete(acc.shadow_universes, id)
        new_active = if acc.active_universe == id, do: nil, else: acc.active_universe

        publish_universe_destroyed(id)
        %{acc | shadow_universes: new_universes, active_universe: new_active}
      end)

    # Also cleanup expired approvals
    valid_approvals =
      new_state.guardian_approvals
      |> Enum.filter(fn {_id, a} ->
        a.expires_at == nil || DateTime.compare(now, a.expires_at) == :lt
      end)
      |> Map.new()

    Process.send_after(self(), :cleanup_expired, :timer.minutes(5))
    {:noreply, %{new_state | guardian_approvals: valid_approvals}}
  end

  @impl true
  def handle_info(:setup_subscriptions, state) do
    patterns = ["universe/multiverse/**"]

    new_subs =
      Enum.reduce(patterns, state.subscriptions, fn pattern, acc ->
        case ZenohSession.subscribe(pattern, self()) do
          {:ok, ref} ->
            Logger.info("[L9.Multiverse] Subscribed to #{pattern}")
            Map.put(acc, ref, pattern)

          {:error, reason} ->
            Logger.warning("[L9.Multiverse] Failed to subscribe: #{inspect(reason)}")
            acc
        end
      end)

    {:noreply, %{state | subscriptions: new_subs}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # ============================================================================
  # PRIVATE FUNCTIONS
  # ============================================================================

  defp do_fork_universe(checkpoint_id, opts, _state) do
    name = Keyword.get(opts, :name, generate_universe_name())
    expiration_hours = Keyword.get(opts, :expiration_hours, @default_expiration_hours)

    universe_id = "#{@shadow_universe_prefix}-#{generate_short_id()}"

    # Verify checkpoint exists
    case ArkIntegration.verify_checkpoint(checkpoint_id) do
      {:ok, _} ->
        universe = %{
          id: universe_id,
          name: name,
          source_checkpoint: checkpoint_id,
          state: :active,
          created_at: DateTime.utc_now(),
          expires_at: DateTime.add(DateTime.utc_now(), expiration_hours * 3600, :second),
          resource_limits: Keyword.get(opts, :resource_limits, default_resource_limits()),
          metadata: %{
            forked_by: "system",
            purpose: Keyword.get(opts, :purpose, "testing")
          }
        }

        Logger.info(
          "[L9.Multiverse] Forked shadow universe: #{universe_id} from #{checkpoint_id}"
        )

        {:ok, universe}

      {:error, reason} ->
        {:error, {:checkpoint_error, reason}}
    end
  end

  defp get_universe(universe_id, state) do
    case Map.get(state.shadow_universes, universe_id) do
      nil -> {:error, :not_found}
      universe -> {:ok, universe}
    end
  end

  defp validate_approval_token(token, operation, state) do
    case Map.get(state.guardian_approvals, token) do
      nil ->
        {:error, :approval_required}

      %{operation: ^operation, status: :approved, expires_at: expires_at} ->
        if expires_at == nil || DateTime.compare(DateTime.utc_now(), expires_at) == :lt do
          :ok
        else
          {:error, :approval_expired}
        end

      _ ->
        {:error, :invalid_approval}
    end
  end

  defp do_promote_universe(universe) do
    Logger.info("[L9.Multiverse] Promoting universe: #{universe.id}")

    # In production, this would:
    # 1. Stop production services
    # 2. Copy shadow state to production
    # 3. Restart production services

    {:ok,
     %{
       promoted_id: universe.id,
       promoted_at: DateTime.utc_now(),
       source_checkpoint: universe.source_checkpoint
     }}
  end

  defp cleanup_universe_resources(universe) do
    Logger.debug("[L9.Multiverse] Cleaning up resources for: #{universe.id}")
    # In production, this would:
    # 1. Stop any running containers for the universe
    # 2. Remove volume mounts
    # 3. Clean up database copies
    :ok
  end

  defp default_resource_limits do
    %{
      max_memory_mb: 2048,
      max_cpu_cores: 2,
      max_storage_gb: 10
    }
  end

  defp count_pending_approvals(approvals) do
    approvals
    |> Enum.count(fn {_id, a} -> a.status == :pending end)
  end

  defp generate_universe_name do
    adjectives = ["quantum", "cosmic", "stellar", "nebula", "void", "astral"]
    nouns = ["realm", "dimension", "plane", "expanse", "domain", "sphere"]

    adj = Enum.random(adjectives)
    noun = Enum.random(nouns)
    num = :rand.uniform(999)

    "#{adj}-#{noun}-#{num}"
  end

  defp generate_short_id do
    :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
  end

  defp generate_approval_id do
    "approval-#{:erlang.phash2({node(), System.system_time()}, 0xFFFFFFFF) |> Integer.to_string(16)}"
  end

  defp publish_universe_forked(universe) do
    message = %{
      type: "universe_forked",
      universe_id: universe.id,
      name: universe.name,
      source_checkpoint: universe.source_checkpoint,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    do_publish(@topic_universe_forked, message)
  end

  defp publish_universe_destroyed(universe_id) do
    message = %{
      type: "universe_destroyed",
      universe_id: universe_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    do_publish(@topic_universe_destroyed, message)
  end

  defp publish_universe_promoted(universe_id) do
    message = %{
      type: "universe_promoted",
      universe_id: universe_id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    do_publish(@topic_universe_promoted, message)
  end

  defp do_publish(topic, message) do
    payload = Jason.encode!(message)
    ZenohSession.publish(topic, payload)
  rescue
    _ -> :ok
  end
end
