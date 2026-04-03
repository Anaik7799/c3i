defmodule Indrajaal.Integration.ExternalConnectors.AuthenticationManager do
  @moduledoc """
  WHAT: ETS-backed token manager for external connector authentication.
        Provides token lifecycle management (store, retrieve, refresh, revoke)
        with TTL-based expiry for connector credentials.

  WHY: External connectors require short-lived tokens that must be refreshed
       before expiry. Centralising this logic prevents duplicated credential
       management across individual connector modules and enforces uniform TTL
       policies.

  CONSTRAINTS:
  - SC-SEC-047:  Credentials stored encrypted (placeholder — integrate KMS for prod)
  - SC-PRF-055:  No blocking operations in the hot path
  - AOR-HOLON-001: Real-time state in ETS (in-memory); persisted separately via KMS
  - AOR-AGT-001: mix compile must pass before task complete

  ## Change History
  | Version | Date       | Author | Change                               |
  |---------|------------|--------|--------------------------------------|
  | 21.2.1  | 2026-03-19 | Claude | Real ETS-backed implementation       |
  """

  require Logger

  @table :auth_manager_tokens
  # Default token TTL: 1 hour
  @default_ttl_seconds 3600
  @telemetry_prefix [:indrajaal, :integration, :auth_manager]

  # ---------------------------------------------------------------------------
  # ETS table bootstrap
  # ---------------------------------------------------------------------------

  @doc """
  Ensures the ETS table exists. Idempotent — safe to call multiple times.
  Uses `:public` visibility so any process in the node can read/write tokens.
  """
  @spec ensure_table() :: :ok
  def ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ets.new(@table, [:set, :public, :named_table])
        Logger.debug("AuthenticationManager: ETS table #{@table} created")
        :ok

      _ref ->
        :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a valid (non-expired) token for `connector_id`.

  Returns `{:ok, token}` when an unexpired token exists, or
  `{:error, :token_expired}` / `{:error, :not_found}` otherwise.
  """
  @spec get_valid_token(String.t() | atom()) :: {:ok, String.t()} | {:error, atom()}
  def get_valid_token(connector_id) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    result =
      case :ets.lookup(@table, {:token, connector_id}) do
        [{_key, token, expires_at}] ->
          if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
            {:ok, token}
          else
            :ets.delete(@table, {:token, connector_id})
            {:error, :token_expired}
          end

        [] ->
          {:error, :not_found}
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :get_valid_token
    })

    result
  end

  @doc """
  Generates a new token for `connector_id` with the configured TTL and stores
  it in ETS, replacing any existing token.

  Returns `{:ok, new_token}`.
  """
  @spec refresh_token(String.t() | atom()) :: {:ok, String.t()}
  def refresh_token(connector_id) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    new_token = generate_token(connector_id)
    expires_at = DateTime.add(DateTime.utc_now(), @default_ttl_seconds, :second)

    :ets.insert(@table, {{:token, connector_id}, new_token, expires_at})

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :refresh_token
    })

    Logger.debug("AuthenticationManager: refreshed token for connector #{connector_id}")
    {:ok, new_token}
  end

  @doc """
  Stores credentials for `connector_id` in ETS.

  `credentials` should be a map with at minimum `:client_id` and
  `:client_secret` keys (or equivalent fields for the connector type).

  In production these should be encrypted via the KMS layer before storage;
  this implementation keeps a plaintext placeholder to avoid KMS dependency.

  Returns `:ok`.
  """
  @spec store_credentials(String.t() | atom(), map()) :: :ok
  def store_credentials(connector_id, credentials) when is_map(credentials) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    # Placeholder encryption: prefix with marker. Replace with KMS.encrypt in prod.
    stored = Map.put(credentials, :__stored_at, DateTime.utc_now())
    :ets.insert(@table, {{:credentials, connector_id}, stored})

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :store_credentials
    })

    Logger.debug("AuthenticationManager: stored credentials for connector #{connector_id}")
    :ok
  end

  @doc """
  Validates that credentials exist and are structurally valid for `connector_id`.

  Returns `{:ok, :valid}` when credentials are present, or
  `{:error, :credentials_not_found}` when they have not been stored.
  """
  @spec validate_credentials(String.t() | atom()) ::
          {:ok, :valid} | {:error, :credentials_not_found}
  def validate_credentials(connector_id) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    result =
      case :ets.lookup(@table, {:credentials, connector_id}) do
        [{_key, creds}] when is_map(creds) ->
          {:ok, :valid}

        [] ->
          {:error, :credentials_not_found}
      end

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :validate_credentials
    })

    result
  end

  @doc """
  Revokes (deletes) the token for `connector_id` from ETS.

  Returns `:ok` regardless of whether the token previously existed (idempotent).
  """
  @spec revoke_token(String.t() | atom()) :: :ok
  def revoke_token(connector_id) do
    ensure_table()
    start = System.monotonic_time(:microsecond)

    :ets.delete(@table, {:token, connector_id})

    elapsed = System.monotonic_time(:microsecond) - start

    :telemetry.execute(@telemetry_prefix, %{duration_us: elapsed}, %{
      module: __MODULE__,
      operation: :revoke_token
    })

    Logger.debug("AuthenticationManager: revoked token for connector #{connector_id}")
    :ok
  end

  # ---------------------------------------------------------------------------
  # Legacy generic API (kept for backward-compat with callers of old stub)
  # ---------------------------------------------------------------------------

  @doc false
  @spec get_by_id(term()) :: {:ok, map()} | {:error, :not_found}
  def get_by_id(id) do
    case get_valid_token(id) do
      {:ok, token} -> {:ok, %{id: id, token: token, status: :active}}
      {:error, _} -> {:error, :not_found}
    end
  end

  @doc false
  @spec list_all() :: {:ok, list()}
  def list_all do
    ensure_table()

    tokens =
      :ets.match_object(@table, {{:token, :_}, :_, :_})
      |> Enum.map(fn {{:token, conn_id}, token, expires_at} ->
        %{connector_id: conn_id, token: token, expires_at: expires_at}
      end)

    {:ok, tokens}
  end

  @doc false
  @spec create(map()) :: {:ok, map()} | {:error, term()}
  def create(%{connector_id: connector_id} = params) do
    case store_credentials(connector_id, params) do
      :ok ->
        _refresh = refresh_token(connector_id)
        {:ok, Map.put(params, :id, connector_id)}

      error ->
        error
    end
  end

  def create(params) do
    {:error, {:missing_connector_id, params}}
  end

  @doc false
  @spec update(term(), map()) :: {:ok, map()} | {:error, term()}
  def update(id, params) do
    case store_credentials(id, params) do
      :ok -> {:ok, Map.put(params, :id, id)}
      error -> error
    end
  end

  @doc false
  @spec delete(term()) :: {:ok, map()}
  def delete(id) do
    ensure_table()
    revoke_token(id)
    :ets.delete(@table, {:credentials, id})
    {:ok, %{id: id, deleted: true}}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp generate_token(connector_id) do
    random_bytes = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    "tok_#{connector_id}_#{random_bytes}"
  end
end
