defmodule Indrajaal.Holon.Database.ConcurrencyHandler do
  @moduledoc """
  Optimistic Concurrency Control (OCC) handler for holon databases.

  WHAT: Version vector-based conflict detection and resolution.
  WHY: SC-XHOLON-006 requires OCC or locking for concurrent access.
       SC-XHOLON-010 mandates lock-free reads.

  CONSTRAINTS:
    - SC-XHOLON-006: Concurrent access uses OCC
    - SC-XHOLON-007: Version vectors monotonically increasing
    - SC-XHOLON-010: Lock-free reads
    - SC-XHOLON-032: No deadlocks permitted
    - SC-XHOLON-033: No starvation permitted

  ## Algorithm

  The OCC protocol works as follows:
  1. Read with version vector (no locks acquired)
  2. Perform local modifications
  3. Compare-and-swap: verify version hasn't changed
  4. If conflict: retry with exponential backoff

  ## Version Vectors

  Version vectors track causality across distributed holons:
  ```
  %{
    "ex:l3:kms:srv:main" => 42,
    "fs:l4:ctx:srv:cortex" => 17
  }
  ```

  A version vector V1 "happens-before" V2 if:
  - For all entries: V1[k] <= V2[k]
  - For at least one entry: V1[k] < V2[k]

  ## Conflict Resolution

  When a conflict is detected, several strategies are available:
  - `:last_write_wins` - Accept the newer write
  - `:merge` - Merge conflicting updates (requires custom merge function)
  - `:reject` - Reject the conflicting write
  """

  require Logger

  @type version_vector :: %{String.t() => non_neg_integer()}
  @type conflict_resolution :: :last_write_wins | :merge | :reject
  @type retry_config :: %{
          max_retries: pos_integer(),
          base_delay_ms: pos_integer(),
          max_delay_ms: pos_integer()
        }

  @default_retry_config %{
    max_retries: 3,
    base_delay_ms: 100,
    max_delay_ms: 2_000
  }

  # ============================================================================
  # Version Vector Operations
  # ============================================================================

  @doc """
  Create a new version vector for a holon.

  ## Parameters
    - `holon_id` - The UHI of the holon

  ## Returns
    - Version vector map with initial count 0
  """
  @spec new_version_vector(String.t()) :: version_vector()
  def new_version_vector(holon_id) do
    %{holon_id => 0}
  end

  @doc """
  Increment the version for a specific holon in the vector.

  ## Parameters
    - `vv` - Current version vector
    - `holon_id` - Holon to increment

  ## Returns
    - Updated version vector
  """
  @spec increment(version_vector(), String.t()) :: version_vector()
  def increment(vv, holon_id) do
    Map.update(vv, holon_id, 1, &(&1 + 1))
  end

  @doc """
  Merge two version vectors by taking the max of each entry.

  ## Parameters
    - `vv1` - First version vector
    - `vv2` - Second version vector

  ## Returns
    - Merged version vector
  """
  @spec merge(version_vector(), version_vector()) :: version_vector()
  def merge(vv1, vv2) do
    Map.merge(vv1, vv2, fn _k, v1, v2 -> max(v1, v2) end)
  end

  @doc """
  Check if version vector v1 is greater than or equal to v2.

  Returns true if v1 >= v2 (all entries in v1 are >= corresponding entries in v2).

  ## Parameters
    - `v1` - First version vector
    - `v2` - Second version vector

  ## Returns
    - `true` if v1 >= v2
    - `false` otherwise
  """
  @spec version_gte?(version_vector(), version_vector()) :: boolean()
  def version_gte?(v1, v2) do
    Enum.all?(v2, fn {k, v2_val} ->
      v1_val = Map.get(v1, k, 0)
      v1_val >= v2_val
    end)
  end

  @doc """
  Check if version vector v1 happens-before v2.

  Returns true if v1 < v2 (causally precedes).

  ## Parameters
    - `v1` - First version vector
    - `v2` - Second version vector

  ## Returns
    - `true` if v1 happens-before v2
    - `false` otherwise (concurrent or v1 >= v2)
  """
  @spec happens_before?(version_vector(), version_vector()) :: boolean()
  def happens_before?(v1, v2) do
    all_lte =
      Enum.all?(v1, fn {k, v1_val} ->
        v2_val = Map.get(v2, k, 0)
        v1_val <= v2_val
      end)

    any_lt =
      Enum.any?(v1, fn {k, v1_val} ->
        v2_val = Map.get(v2, k, 0)
        v1_val < v2_val
      end)

    all_lte and any_lt
  end

  @doc """
  Check if two version vectors are concurrent (neither happens-before the other).

  ## Parameters
    - `v1` - First version vector
    - `v2` - Second version vector

  ## Returns
    - `true` if versions are concurrent
    - `false` if one happens-before the other
  """
  @spec concurrent?(version_vector(), version_vector()) :: boolean()
  def concurrent?(v1, v2) do
    not happens_before?(v1, v2) and not happens_before?(v2, v1)
  end

  # ============================================================================
  # Compare-and-Swap Operations
  # ============================================================================

  @doc """
  Execute an operation with compare-and-swap semantics.

  ## Parameters
    - `expected_version` - Expected version vector
    - `current_version_fn` - Function to get current version (no args)
    - `operation_fn` - Function to perform the operation (no args)
    - `opts` - Options
      - `:resolution` - Conflict resolution strategy (default: :reject)
      - `:retry_config` - Retry configuration

  ## Returns
    - `{:ok, result, new_version}` on success
    - `{:conflict, current_version}` on version mismatch (if :reject)
    - `{:error, reason}` on failure
  """
  @spec compare_and_swap(
          version_vector(),
          (-> {:ok, version_vector()}),
          (-> {:ok, term()} | {:error, term()}),
          keyword()
        ) :: {:ok, term(), version_vector()} | {:conflict, version_vector()} | {:error, term()}
  def compare_and_swap(expected_version, current_version_fn, operation_fn, opts \\ []) do
    resolution = Keyword.get(opts, :resolution, :reject)
    retry_config = Keyword.get(opts, :retry_config, @default_retry_config)

    do_cas(expected_version, current_version_fn, operation_fn, resolution, retry_config, 0)
  end

  defp do_cas(
         expected_version,
         current_version_fn,
         operation_fn,
         resolution,
         retry_config,
         attempt
       ) do
    # Get current version
    {:ok, current_version} = current_version_fn.()

    cond do
      # Version matches or current is ahead, proceed
      version_gte?(current_version, expected_version) ->
        case operation_fn.() do
          {:ok, result} ->
            {:ok, result, increment(current_version, "local")}

          {:error, reason} ->
            {:error, reason}
        end

      # Conflict detected
      resolution == :last_write_wins and attempt < retry_config.max_retries ->
        # Retry with backoff
        delay = calculate_backoff(attempt, retry_config)
        Process.sleep(delay)

        do_cas(
          expected_version,
          current_version_fn,
          operation_fn,
          resolution,
          retry_config,
          attempt + 1
        )

      resolution == :reject ->
        {:conflict, current_version}

      true ->
        {:conflict, current_version}
    end
  end

  @doc """
  Execute an operation with automatic retry on conflict.

  ## Parameters
    - `operation_fn` - Function returning {:ok, result} or {:conflict, version} or {:error, reason}
    - `opts` - Options
      - `:max_retries` - Maximum retry attempts (default: 3)
      - `:base_delay_ms` - Base delay for exponential backoff (default: 100)
      - `:max_delay_ms` - Maximum delay (default: 2000)

  ## Returns
    - `{:ok, result}` on success
    - `{:error, :max_retries_exceeded}` after exhausting retries
    - `{:error, reason}` on non-conflict failure
  """
  @spec with_retry((-> {:ok, term()} | {:conflict, term()} | {:error, term()}), keyword()) ::
          {:ok, term()} | {:error, term()}
  def with_retry(operation_fn, opts \\ []) do
    config = Map.merge(@default_retry_config, Map.new(opts))
    do_with_retry(operation_fn, config, 0)
  end

  defp do_with_retry(operation_fn, config, attempt) do
    case operation_fn.() do
      {:ok, result} ->
        {:ok, result}

      {:conflict, _version} when attempt < config.max_retries ->
        delay = calculate_backoff(attempt, config)

        Logger.debug(
          "[ConcurrencyHandler] Conflict on attempt #{attempt + 1}, retrying in #{delay}ms"
        )

        Process.sleep(delay)
        do_with_retry(operation_fn, config, attempt + 1)

      {:conflict, version} ->
        Logger.warning(
          "[ConcurrencyHandler] Max retries exceeded, last conflict version: #{inspect(version)}"
        )

        {:error, :max_retries_exceeded}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Pessimistic Locking (for critical sections)
  # ============================================================================

  @doc """
  Acquire a lock for a resource with timeout.

  Note: This is implemented using a simple ETS-based locking mechanism.
  For distributed locks, use the Zenoh-based distributed lock manager.

  ## Parameters
    - `resource_id` - Identifier for the resource to lock
    - `owner_id` - Identifier for the lock owner
    - `timeout_ms` - Lock acquisition timeout

  ## Returns
    - `:ok` on successful acquisition
    - `{:error, :timeout}` if lock cannot be acquired
  """
  @spec acquire_lock(String.t(), String.t(), pos_integer()) :: :ok | {:error, :timeout}
  def acquire_lock(resource_id, owner_id, timeout_ms) do
    ensure_lock_table()
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    do_acquire_lock(resource_id, owner_id, deadline)
  end

  defp do_acquire_lock(resource_id, owner_id, deadline) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      {:error, :timeout}
    else
      case :ets.insert_new(:holon_db_locks, {resource_id, owner_id, now}) do
        true ->
          :ok

        false ->
          # Lock held by someone else, check if expired (5s default expiry)
          case :ets.lookup(:holon_db_locks, resource_id) do
            [{^resource_id, _other_owner, acquired_at}] when now - acquired_at > 5_000 ->
              # Lock expired, try to take it
              :ets.delete(:holon_db_locks, resource_id)
              do_acquire_lock(resource_id, owner_id, deadline)

            _ ->
              # Lock still valid, wait and retry
              Process.sleep(10)
              do_acquire_lock(resource_id, owner_id, deadline)
          end
      end
    end
  end

  @doc """
  Release a lock for a resource.

  ## Parameters
    - `resource_id` - Identifier for the resource
    - `owner_id` - Identifier for the lock owner

  ## Returns
    - `:ok` always
  """
  @spec release_lock(String.t(), String.t()) :: :ok
  def release_lock(resource_id, owner_id) do
    ensure_lock_table()

    case :ets.lookup(:holon_db_locks, resource_id) do
      [{^resource_id, ^owner_id, _}] ->
        :ets.delete(:holon_db_locks, resource_id)
        :ok

      _ ->
        # Not our lock, ignore
        :ok
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp calculate_backoff(attempt, config) do
    # Exponential backoff with jitter
    base_delay = config.base_delay_ms * :math.pow(2, attempt)
    jitter = :rand.uniform(div(config.base_delay_ms, 2))
    min(trunc(base_delay) + jitter, config.max_delay_ms)
  end

  defp ensure_lock_table do
    case :ets.whereis(:holon_db_locks) do
      :undefined ->
        :ets.new(:holon_db_locks, [:set, :public, :named_table])

      _ ->
        :ok
    end
  end
end
