defmodule Indrajaal.Authentication.TokenRevocationCache do
  @moduledoc """
  Token Revocation Cache System
  """
  use GenServer
  require Logger

  @cache_table :token_revocation_cache

  @default_ttl :timer.hours(24)

  @spec child_spec(list()) :: map()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @spec start_link(list()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec revoked?(String.t()) :: boolean()
  def revoked?(jti) when is_binary(jti) do
    case :ets.lookup(@cache_table, jti) do
      [{^jti, :revoked, expires_at}] ->
        System.system_time(:second) < expires_at

      [] ->
        false
    end
  end

  @spec revoke_token(String.t(), integer()) :: :ok
  def revoke_token(jti, ttl \\ @default_ttl) when is_binary(jti) do
    GenServer.call(__MODULE__, {:revoke, jti, ttl})
  end

  @impl true
  def init(_opts) do
    :ets.new(@cache_table, [:set, :public, :named_table, {:read_concurrency, true}])
    {:ok, %{}}
  end

  @impl true
  def handle_call({:revoke, jti, ttl}, _from, state) do
    expires_at = System.system_time(:second) + div(ttl, 1000)
    :ets.insert(@cache_table, {jti, :revoked, expires_at})

    # ZUIP: Publish token revocation to Zenoh mesh (SC-ZTEST-008 dual-write)
    safe_publish(:publish_sentinel_quarantine, [jti, "token_revoked"])

    {:reply, :ok, state}
  end

  defp safe_publish(function, args) do
    try do
      case Code.ensure_loaded(Indrajaal.Observability.ZenohSafetyPublisher) do
        {:module, mod} -> apply(mod, function, args)
        _ -> :ok
      end
    rescue
      _ -> :ok
    end
  end
end
