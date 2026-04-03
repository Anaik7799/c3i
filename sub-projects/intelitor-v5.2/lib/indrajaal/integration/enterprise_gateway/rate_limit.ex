defmodule Indrajaal.Integration.Enterprise.RateLimit do
  @moduledoc """
  WHAT: ETS-backed sliding window rate limiter for the enterprise gateway.
        Provides per-client request counting with configurable windows and limits.
        Also acts as an Ash resource for persisted rate-limit policy configuration.

  WHY: Gateway routes need configurable rate-limit policies that survive restarts
       (PostgreSQL) while per-client request counters live in ETS for sub-millisecond
       hot-path performance.

  CONSTRAINTS:
  - SC-PRF-055:  No blocking operations in the hot path
  - SC-SEC-047:  Rate limiting as a security control
  - AOR-HOLON-001: Real-time counters in ETS; policies persisted in PostgreSQL
  - AOR-AGT-001: mix compile must pass before task complete

  ## Change History
  | Version | Date       | Author | Change                                        |
  |---------|------------|--------|-----------------------------------------------|
  | 21.2.1  | 2026-03-23 | Claude | Real ETS sliding-window implementation        |
  """

  use Indrajaal.BaseResource,
    domain: Indrajaal.Integration.Enterprise,
    extensions: [AshPostgres, AshJsonApi.Resource]

  require Logger

  @table :rate_limit_counters
  @telemetry_prefix [:indrajaal, :integration, :rate_limit]

  # ---------------------------------------------------------------------------
  # Ash resource — persisted rate-limit policy configuration
  # ---------------------------------------------------------------------------

  postgres do
    table "rate_limits"
    repo Indrajaal.Repo
  end

  attributes do
    uuid_primary_key :id
    create_timestamp :inserted_at
    update_timestamp :updated_at

    attribute :name, :string, allow_nil?: false
    attribute :description, :string
    attribute :active, :boolean, default: true

    # Policy attributes
    attribute :max_requests, :integer, default: 1000
    attribute :window_seconds, :integer, default: 60
    attribute :burst_limit, :integer, default: 50

    attribute :key_type, :atom,
      constraints: [one_of: [:ip, :user_id, :api_key, :tenant_id]],
      default: :ip
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :name,
        :description,
        :active,
        :max_requests,
        :window_seconds,
        :burst_limit,
        :key_type
      ]
    end

    update :update do
      accept [
        :name,
        :description,
        :active,
        :max_requests,
        :window_seconds,
        :burst_limit,
        :key_type
      ]
    end
  end

  # ---------------------------------------------------------------------------
  # ETS-backed sliding window rate limiter — hot path API
  # ---------------------------------------------------------------------------

  @doc """
  Ensures the ETS counter table exists. Idempotent.
  """
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [
          :set,
          :public,
          :named_table,
          {:write_concurrency, true},
          {:read_concurrency, true}
        ])

        Logger.debug("RateLimit: ETS table #{@table} created")
        :ok

      _ref ->
        :ok
    end
  end

  @doc """
  Checks whether `client_key` is within the rate limit defined by `limit_config`.

  `limit_config` must contain:
  - `:max_requests`    - integer, maximum allowed requests in the window
  - `:window_seconds`  - integer, sliding window size in seconds

  Returns `{:ok, :allowed, remaining}` or `{:error, :rate_limited, retry_after_seconds}`.
  """
  @spec check_limit(String.t() | atom(), map()) ::
          {:ok, :allowed, non_neg_integer()}
          | {:error, :rate_limited, non_neg_integer()}
  def check_limit(client_key, limit_config \\ %{max_requests: 1000, window_seconds: 60}) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    max = Map.get(limit_config, :max_requests, 1000)
    window = Map.get(limit_config, :window_seconds, 60)
    now = System.system_time(:second)
    window_start = now - window

    # Each ETS entry is {client_key, [{timestamp, count}]}
    result =
      case :ets.lookup(@table, client_key) do
        [{^client_key, timestamps}] ->
          # Prune entries outside the window (sliding window)
          active = Enum.filter(timestamps, fn {ts, _} -> ts >= window_start end)
          total = Enum.reduce(active, 0, fn {_, cnt}, acc -> acc + cnt end)

          if total >= max do
            oldest =
              active
              |> Enum.map(fn {ts, _} -> ts end)
              |> Enum.min(fn -> now end)

            retry_after = window - (now - oldest)
            {:error, :rate_limited, max(retry_after, 1)}
          else
            updated = [{now, 1} | active]
            :ets.insert(@table, {client_key, updated})
            {:ok, :allowed, max - total - 1}
          end

        [] ->
          :ets.insert(@table, {client_key, [{now, 1}]})
          {:ok, :allowed, max - 1}
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :check_limit,
      client_key: client_key,
      allowed: match?({:ok, _, _}, result)
    })

    result
  end

  @doc """
  Resets the rate-limit counter for `client_key`. Useful after ban expiry.
  """
  @spec reset_counter(String.t() | atom()) :: :ok
  def reset_counter(client_key) do
    ensure_table()
    :ets.delete(@table, client_key)
    :ok
  end

  @doc """
  Returns the current request count for `client_key` within the last `window_seconds`.
  """
  @spec current_count(String.t() | atom(), pos_integer()) :: non_neg_integer()
  def current_count(client_key, window_seconds \\ 60) do
    ensure_table()
    now = System.system_time(:second)
    window_start = now - window_seconds

    case :ets.lookup(@table, client_key) do
      [{^client_key, timestamps}] ->
        timestamps
        |> Enum.filter(fn {ts, _} -> ts >= window_start end)
        |> Enum.reduce(0, fn {_, cnt}, acc -> acc + cnt end)

      [] ->
        0
    end
  end

  @doc """
  Cleans up expired entries across all clients. Call periodically to prevent table growth.
  """
  @spec cleanup_expired(pos_integer()) :: non_neg_integer()
  def cleanup_expired(window_seconds \\ 3600) do
    ensure_table()
    now = System.system_time(:second)
    window_start = now - window_seconds

    entries = :ets.tab2list(@table)

    removed =
      Enum.reduce(entries, 0, fn {key, timestamps}, acc ->
        active = Enum.filter(timestamps, fn {ts, _} -> ts >= window_start end)

        if active == [] do
          :ets.delete(@table, key)
          acc + 1
        else
          :ets.insert(@table, {key, active})
          acc
        end
      end)

    Logger.debug("RateLimit: cleaned up #{removed} expired entries")
    removed
  end
end
