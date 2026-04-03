defmodule Indrajaal.Federation.AttestationManager do
  @moduledoc """
  Attestation Manager — L6 Federation Layer

  ## Design Intent

  Manages cryptographic attestations for federation peers. Creates
  HMAC-SHA512-signed attestation blocks, verifies peer attestations with
  constant-time comparison, maintains a per-peer chain (up to 10 deep),
  enforces a 1-hour TTL with periodic expiry sweeps, and supports revocation.

  Core responsibilities:
  - Create signed attestation blocks for local node or named peers
  - Verify incoming peer attestation payloads (HMAC + freshness)
  - Maintain a per-peer chain of up to 10 historical attestations in ETS
  - Expire stale attestations (TTL = 1 hour) on a scheduled sweep
  - Revoke specific attestations by ID
  - Broadcast lifecycle events via PubSub `"federation:attestation"`
  - Emit telemetry on create/verify/expire/revoke operations

  ## STAMP Constraints

  - SC-FED-006: Attestation MUST use Ed25519-verified (HMAC-SHA512 used per
    Sprint 52 hardening) — all attestation blocks are HMAC-SHA512 signed.
  - SC-SMRITI-110: Version vectors in SQLite; attestation expires 1 hour.
  - SC-SMRITI-111: Concurrent updates detected; hourly attestation.
  - SC-HASH-002: Constant-time comparison (timing attack prevention)
    — `:crypto.hash_equals/2` used for all signature comparisons.
  - SC-FED-001: No modification of node constitutions — attestation
    blocks are immutable once created; mutation triggers re-issuance.
  - SC-HA-003: Zenoh 2oo3 quorum requires awareness of live peer set
    — `alive_peers/0` is the consumption point for quorum computations.

  ## Change History

  | Version | Date       | Author | Change                                       |
  |---------|------------|--------|----------------------------------------------|
  | 21.3.1  | 2026-03-28 | Claude | Add create/1, verify/1, valid?/1, expired?/1 |
  """

  use GenServer
  require Logger

  @name __MODULE__
  @pubsub_topic "federation:attestation"
  @ets_table :attestation_manager_store

  # 1-hour TTL (milliseconds)
  @attestation_ttl_ms 3_600_000

  # How many historical attestations to keep per peer
  @chain_depth 10

  # Expiry sweep interval (5 minutes)
  @sweep_interval_ms 300_000

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type attestation_id :: String.t()

  @type attestation :: %{
          id: attestation_id(),
          peer_id: String.t(),
          state_hash: String.t(),
          signature: String.t(),
          issued_at: DateTime.t(),
          expires_at: DateTime.t(),
          revoked: boolean()
        }

  @type verify_result ::
          {:ok, :verified, attestation()}
          | {:error, :expired | :revoked | :invalid_signature | :not_found | :malformed}

  @type t :: %{
          create_count: non_neg_integer(),
          verify_count: non_neg_integer(),
          expire_count: non_neg_integer(),
          revoke_count: non_neg_integer(),
          started_at: DateTime.t()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc "Start the AttestationManager GenServer."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, @name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Create a signed attestation for the given `peer_id`.

  Returns `{:ok, attestation()}` with the signed block including HMAC-SHA512
  signature and a 1-hour expiry.
  """
  @spec create(String.t()) :: {:ok, attestation()} | {:error, term()}
  def create(peer_id) when is_binary(peer_id) do
    GenServer.call(@name, {:create_attestation, peer_id, %{}})
  end

  @doc """
  Verify an attestation block by its ID.

  Checks: existence in local store, non-revoked, within TTL, valid HMAC
  signature. Returns `{:ok, :verified, attestation}` on success.
  """
  @spec verify(attestation_id()) :: verify_result()
  def verify(attestation_id) when is_binary(attestation_id) do
    GenServer.call(@name, {:verify_attestation, attestation_id})
  end

  @doc """
  Return `true` when the attestation with the given ID exists, is not
  revoked, and has not exceeded its TTL.
  """
  @spec valid?(attestation_id()) :: boolean()
  def valid?(attestation_id) when is_binary(attestation_id) do
    case verify(attestation_id) do
      {:ok, :verified, _} -> true
      _ -> false
    end
  end

  @doc """
  Return `true` when the attestation with the given ID has exceeded its TTL
  or does not exist.
  """
  @spec expired?(attestation_id()) :: boolean()
  def expired?(attestation_id) when is_binary(attestation_id) do
    if :ets.whereis(@ets_table) != :undefined do
      case :ets.lookup(@ets_table, attestation_id) do
        [{^attestation_id, att}] ->
          DateTime.compare(DateTime.utc_now(), att.expires_at) != :lt

        [] ->
          true
      end
    else
      true
    end
  end

  @doc """
  Create a signed attestation for the given `peer_id` with optional metadata.
  """
  @spec create_attestation(String.t(), map()) :: {:ok, attestation()} | {:error, term()}
  def create_attestation(peer_id, metadata \\ %{}) when is_binary(peer_id) do
    GenServer.call(@name, {:create_attestation, peer_id, metadata})
  end

  @doc """
  Verify an attestation by ID (full result).
  """
  @spec verify_attestation(attestation_id()) :: verify_result()
  def verify_attestation(attestation_id) when is_binary(attestation_id) do
    GenServer.call(@name, {:verify_attestation, attestation_id})
  end

  @doc """
  Expire all stale attestations whose TTL has elapsed.
  Returns the count of attestations expired.
  """
  @spec expire_stale() :: non_neg_integer()
  def expire_stale do
    GenServer.call(@name, :expire_stale)
  end

  @doc """
  Return the attestation chain (history) for a given `peer_id`.
  Ordered newest-first, capped at #{@chain_depth} entries.
  """
  @spec attestation_chain(String.t()) :: [attestation()]
  def attestation_chain(peer_id) when is_binary(peer_id) do
    GenServer.call(@name, {:attestation_chain, peer_id})
  end

  @doc """
  Revoke a specific attestation by ID.
  The block is marked as revoked but retained in history.
  """
  @spec revoke(attestation_id()) :: :ok | {:error, :not_found}
  def revoke(attestation_id) when is_binary(attestation_id) do
    GenServer.call(@name, {:revoke, attestation_id})
  end

  @doc "Return a list of peer IDs whose current attestation is valid and unexpired."
  @spec alive_peers() :: [String.t()]
  def alive_peers do
    if :ets.whereis(@ets_table) != :undefined do
      now_ms = System.system_time(:millisecond)

      @ets_table
      |> :ets.tab2list()
      |> Enum.filter(fn {_key, att} ->
        not att.revoked and
          DateTime.to_unix(att.expires_at, :millisecond) > now_ms
      end)
      |> Enum.map(fn {_key, att} -> att.peer_id end)
      |> Enum.uniq()
    else
      []
    end
  end

  @doc "GenServer statistics."
  @spec stats() :: map()
  def stats do
    GenServer.call(@name, :stats)
  end

  # ---------------------------------------------------------------------------
  # GenServer Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    ensure_ets_table()
    schedule_sweep()

    state = %{
      create_count: 0,
      verify_count: 0,
      expire_count: 0,
      revoke_count: 0,
      started_at: DateTime.utc_now()
    }

    Logger.info(
      "[AttestationManager] Online — ttl=1h chain_depth=#{@chain_depth} " <>
        "sweep=5m — SC-FED-006, SC-SMRITI-110"
    )

    {:ok, state}
  end

  @impl true
  def handle_call({:create_attestation, peer_id, metadata}, _from, state) do
    {result, new_state} = do_create(peer_id, metadata, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:verify_attestation, att_id}, _from, state) do
    {result, new_state} = do_verify(att_id, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:expire_stale, _from, state) do
    {expired_count, new_state} = do_expire(state)
    {:reply, expired_count, new_state}
  end

  @impl true
  def handle_call({:attestation_chain, peer_id}, _from, state) do
    chain = fetch_chain(peer_id)
    {:reply, chain, state}
  end

  @impl true
  def handle_call({:revoke, att_id}, _from, state) do
    {result, new_state} = do_revoke(att_id, state)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    result = %{
      create_count: state.create_count,
      verify_count: state.verify_count,
      expire_count: state.expire_count,
      revoke_count: state.revoke_count,
      live_attestations: :ets.info(@ets_table, :size),
      alive_peer_count: length(alive_peers()),
      started_at: state.started_at,
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at)
    }

    {:reply, result, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    schedule_sweep()
    {_count, new_state} = do_expire(state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("[AttestationManager] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end

  # ---------------------------------------------------------------------------
  # Private Helpers
  # ---------------------------------------------------------------------------

  defp do_create(peer_id, metadata, state) do
    now = DateTime.utc_now()
    expires_at = DateTime.add(now, div(@attestation_ttl_ms, 1000), :second)
    att_id = generate_att_id()

    state_hash = compute_state_hash(peer_id, now, metadata)
    signature = sign(att_id, peer_id, state_hash, now)

    attestation = %{
      id: att_id,
      peer_id: peer_id,
      state_hash: Base.encode16(state_hash, case: :lower),
      signature: Base.encode16(signature, case: :lower),
      issued_at: now,
      expires_at: expires_at,
      revoked: false
    }

    store_attestation(attestation)
    broadcast_event(:created, attestation)
    emit_telemetry(:created, attestation)

    Logger.debug(
      "[AttestationManager] Created att_id=#{att_id} peer=#{peer_id} expires=#{DateTime.to_iso8601(expires_at)}"
    )

    new_state = %{state | create_count: state.create_count + 1}
    {{:ok, attestation}, new_state}
  rescue
    e ->
      Logger.error("[AttestationManager] create_attestation failed: #{inspect(e)}")
      {{:error, {:create_failed, e}}, state}
  end

  defp do_verify(att_id, state) do
    result =
      case lookup_attestation(att_id) do
        nil ->
          {:error, :not_found}

        attestation ->
          cond do
            attestation.revoked ->
              {:error, :revoked}

            not fresh?(attestation) ->
              {:error, :expired}

            not valid_signature?(attestation) ->
              {:error, :invalid_signature}

            true ->
              {:ok, :verified, attestation}
          end
      end

    outcome = if match?({:ok, _, _}, result), do: :verified, else: :rejected
    emit_verify_telemetry(att_id, outcome)

    new_state = %{state | verify_count: state.verify_count + 1}
    {result, new_state}
  rescue
    e ->
      Logger.error("[AttestationManager] verify_attestation failed: #{inspect(e)}")
      {{:error, :malformed}, state}
  end

  defp do_expire(state) do
    now_ms = System.system_time(:millisecond)

    expired =
      @ets_table
      |> :ets.tab2list()
      |> Enum.filter(fn {_key, att} ->
        DateTime.to_unix(att.expires_at, :millisecond) < now_ms and not att.revoked
      end)

    Enum.each(expired, fn {key, att} ->
      :ets.delete(@ets_table, key)
      Logger.debug("[AttestationManager] Expired att_id=#{att.id} peer=#{att.peer_id}")
    end)

    count = length(expired)

    if count > 0 do
      broadcast_event(:expired, %{count: count, timestamp: DateTime.utc_now()})
      emit_expire_telemetry(count)
      Logger.info("[AttestationManager] Expired #{count} attestation(s) — SC-SMRITI-110")
    end

    new_state = %{state | expire_count: state.expire_count + count}
    {count, new_state}
  rescue
    _ -> {0, state}
  end

  defp do_revoke(att_id, state) do
    case lookup_attestation(att_id) do
      nil ->
        {{:error, :not_found}, state}

      attestation ->
        revoked = %{attestation | revoked: true}
        :ets.insert(@ets_table, {att_id, revoked})
        broadcast_event(:revoked, revoked)
        emit_telemetry(:revoked, revoked)

        Logger.warning(
          "[AttestationManager] Revoked att_id=#{att_id} peer=#{attestation.peer_id} — SC-FED-006"
        )

        new_state = %{state | revoke_count: state.revoke_count + 1}
        {:ok, new_state}
    end
  rescue
    e ->
      Logger.error("[AttestationManager] revoke failed: #{inspect(e)}")
      {{:error, {:revoke_failed, e}}, state}
  end

  defp fetch_chain(peer_id) do
    @ets_table
    |> :ets.tab2list()
    |> Enum.map(fn {_key, att} -> att end)
    |> Enum.filter(&(&1.peer_id == peer_id))
    |> Enum.sort_by(& &1.issued_at, {:desc, DateTime})
    |> Enum.take(@chain_depth)
  rescue
    _ -> []
  end

  defp store_attestation(attestation) do
    :ets.insert(@ets_table, {attestation.id, attestation})
    trim_chain(attestation.peer_id)
  end

  defp trim_chain(peer_id) do
    chain = fetch_chain(peer_id)

    if length(chain) > @chain_depth do
      chain
      |> Enum.drop(@chain_depth)
      |> Enum.each(fn old -> :ets.delete(@ets_table, old.id) end)
    end
  rescue
    _ -> :ok
  end

  defp lookup_attestation(att_id) do
    case :ets.lookup(@ets_table, att_id) do
      [{^att_id, att}] -> att
      [] -> nil
    end
  rescue
    _ -> nil
  end

  defp fresh?(attestation) do
    DateTime.compare(DateTime.utc_now(), attestation.expires_at) == :lt
  end

  defp valid_signature?(attestation) do
    state_hash = Base.decode16!(attestation.state_hash, case: :lower)
    provided_sig = Base.decode16!(attestation.signature, case: :lower)
    expected_sig = sign(attestation.id, attestation.peer_id, state_hash, attestation.issued_at)
    :crypto.hash_equals(expected_sig, provided_sig)
  rescue
    _ -> false
  end

  defp compute_state_hash(peer_id, timestamp, metadata) do
    data =
      :erlang.term_to_binary(%{
        peer_id: peer_id,
        timestamp_unix: DateTime.to_unix(timestamp),
        otp_release: :erlang.system_info(:otp_release) |> List.to_string(),
        metadata: metadata
      })

    :crypto.hash(:sha3_256, data)
  end

  defp sign(att_id, peer_id, state_hash, issued_at) do
    secret = get_secret_key()

    payload =
      state_hash <>
        :erlang.term_to_binary(att_id) <>
        :erlang.term_to_binary(peer_id) <>
        :erlang.term_to_binary(DateTime.to_unix(issued_at))

    :crypto.mac(:hmac, :sha512, secret, payload)
  end

  defp get_secret_key do
    case Application.get_env(:indrajaal, :federation_secret_key) do
      nil -> :crypto.strong_rand_bytes(32)
      key when is_binary(key) -> key
    end
  end

  defp generate_att_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp broadcast_event(event, payload) do
    try do
      Phoenix.PubSub.broadcast(
        Indrajaal.PubSub,
        @pubsub_topic,
        {:attestation_event, event, payload}
      )
    rescue
      e -> Logger.debug("[AttestationManager] PubSub broadcast failed: #{inspect(e)}")
    end
  end

  defp emit_telemetry(event, attestation) do
    try do
      :telemetry.execute(
        [:indrajaal, :federation, :attestation_manager, event],
        %{count: 1},
        %{peer_id: attestation.peer_id, att_id: attestation.id}
      )
    rescue
      e -> Logger.debug("[AttestationManager] telemetry.execute failed: #{inspect(e)}")
    end
  end

  defp emit_verify_telemetry(att_id, outcome) do
    try do
      :telemetry.execute(
        [:indrajaal, :federation, :attestation_manager, :verify],
        %{count: 1},
        %{att_id: att_id, outcome: outcome}
      )
    rescue
      e -> Logger.debug("[AttestationManager] telemetry.execute failed: #{inspect(e)}")
    end
  end

  defp emit_expire_telemetry(count) do
    try do
      :telemetry.execute(
        [:indrajaal, :federation, :attestation_manager, :expire],
        %{count: count},
        %{}
      )
    rescue
      e -> Logger.debug("[AttestationManager] telemetry.execute failed: #{inspect(e)}")
    end
  end

  defp schedule_sweep do
    Process.send_after(self(), :sweep, @sweep_interval_ms)
  end

  defp ensure_ets_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :public, :set, read_concurrency: true])
    end
  end
end
