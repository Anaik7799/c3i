defmodule Indrajaal.Zenoh.RouterPlugin do
  @moduledoc """
  Zenoh Router-Side ProofToken Enforcement Plugin.

  ## WHAT
  A GenServer that acts as a router-side enforcement layer for ProofToken
  verification across the Zenoh federation control plane. All messages
  matching registered key expression filters are inspected for a valid
  ProofToken before forwarding is permitted.

  ## WHY
  Wire-level protection ensures that even if an Elixir application layer is
  bypassed (e.g. via direct NIF injection or container-internal routing), the
  router still gates control-plane keys behind cryptographic proof.

  ## STAMP Compliance
  - SC-NIF-005: ProofToken enforcement at NIF boundary (control-plane gate).
    This module extends that guarantee to the router tier, closing the gap
    between the NIF and the application where messages might be in-flight.
  - SC-HASH-002: Constant-time HMAC comparison is delegated to
    `Indrajaal.Prometheus.Verifier.verify_proof_token/1`, which internally
    uses `:crypto.mac/4` and constant-length Base16 comparison.

  ## Architecture
  ```
  Zenoh message arrives
        │
        ▼
  RouterPlugin.verify_message/2
        │
        ├─ key_expr matches a registered filter?
        │         NO  → {:ok, :pass_through}
        │
        ├─ payload contains valid ProofToken JSON?
        │         NO  → {:error, :missing_proof_token}
        │
        └─ Prometheus.Verifier.verify_proof_token/1 passes?
                  NO  → {:error, :invalid_proof_token}
                  YES → {:ok, :verified}
  ```

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.1 | 2026-03-28 | Claude Sonnet 4.6 | Initial implementation — SC-NIF-005 router tier |
  """

  use GenServer
  require Logger

  @stats_table :router_plugin_stats
  @default_control_filters [
    "indrajaal/control/**",
    "indrajaal/guardian/**",
    "indrajaal/evolution/**",
    "indrajaal/immune/**"
  ]

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @type key_expr :: String.t()
  @type payload :: binary()

  @type verify_result ::
          {:ok, :pass_through}
          | {:ok, :verified}
          | {:error, :missing_proof_token}
          | {:error, :invalid_proof_token}
          | {:error, :decode_error}

  @type stats :: %{
          total: non_neg_integer(),
          passed: non_neg_integer(),
          rejected: non_neg_integer(),
          latency_avg_us: float()
        }

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Starts the RouterPlugin GenServer.

  ## Options
  - `:filters` — list of key expression glob patterns to enforce (default: control-plane patterns)
  - `:name` — GenServer registration name (default: `#{__MODULE__}`)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Verifies a Zenoh message identified by `key_expr` carrying `payload`.

  Returns:
  - `{:ok, :pass_through}` — key_expr does not match any registered filter; message is allowed.
  - `{:ok, :verified}` — message matched a filter and the ProofToken is cryptographically valid.
  - `{:error, :missing_proof_token}` — matched filter but payload lacks a `proof_token` field.
  - `{:error, :invalid_proof_token}` — matched filter but signature verification failed.
  - `{:error, :decode_error}` — payload is not valid JSON.

  Emits `:telemetry.execute([:zenoh, :router_plugin, :verify], ...)` on every call.
  Publishes rejection events to `"prajna:security"` and `"zenoh:security_events"`.
  """
  @spec verify_message(key_expr(), payload()) :: verify_result()
  def verify_message(key_expr, payload) when is_binary(key_expr) and is_binary(payload) do
    GenServer.call(__MODULE__, {:verify_message, key_expr, payload})
  end

  @doc """
  Registers an additional key expression filter for enforcement.

  The filter uses glob-style matching (`**` for multi-segment wildcard).
  """
  @spec register_filter(key_expr()) :: :ok
  def register_filter(key_expr) when is_binary(key_expr) do
    GenServer.call(__MODULE__, {:register_filter, key_expr})
  end

  @doc """
  Returns current verification statistics from the ETS stats table.

  ## Return map
  - `:total` — total messages verified (matched a filter)
  - `:passed` — messages that passed verification
  - `:rejected` — messages that failed verification
  - `:latency_avg_us` — rolling average verification latency in microseconds
  """
  @spec stats() :: stats()
  def stats do
    ensure_stats_table()

    total = read_counter(:total)
    passed = read_counter(:passed)
    rejected = read_counter(:rejected)
    latency_sum = read_counter(:latency_sum_us)

    avg =
      if total > 0 do
        latency_sum / total
      else
        0.0
      end

    %{
      total: total,
      passed: passed,
      rejected: rejected,
      latency_avg_us: avg
    }
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    filters = Keyword.get(opts, :filters, @default_control_filters)
    ensure_stats_table()

    Logger.info("[RouterPlugin] Started with #{length(filters)} filter(s): #{inspect(filters)}")

    {:ok, %{filters: MapSet.new(filters)}}
  end

  @impl true
  def handle_call({:verify_message, key_expr, payload}, _from, state) do
    result = do_verify(key_expr, payload, state.filters)
    {:reply, result, state}
  end

  @impl true
  def handle_call({:register_filter, key_expr}, _from, state) do
    new_filters = MapSet.put(state.filters, key_expr)
    Logger.info("[RouterPlugin] Registered filter: #{key_expr}")
    {:reply, :ok, %{state | filters: new_filters}}
  end

  # ---------------------------------------------------------------------------
  # Internal verification logic
  # ---------------------------------------------------------------------------

  @spec do_verify(key_expr(), payload(), MapSet.t()) :: verify_result()
  defp do_verify(key_expr, payload, filters) do
    t0 = System.monotonic_time(:microsecond)

    result =
      if matches_any_filter?(key_expr, filters) do
        perform_proof_token_verification(key_expr, payload)
      else
        {:ok, :pass_through}
      end

    t1 = System.monotonic_time(:microsecond)
    elapsed_us = t1 - t0

    # Emit telemetry event for every call regardless of result
    emit_telemetry(key_expr, result, elapsed_us)

    # Update ETS stats only for filtered (verified) messages
    case result do
      {:ok, :pass_through} ->
        :ok

      {:ok, :verified} ->
        record_stat(:total, 1)
        record_stat(:passed, 1)
        record_stat(:latency_sum_us, elapsed_us)

      {:error, _reason} ->
        record_stat(:total, 1)
        record_stat(:rejected, 1)
        record_stat(:latency_sum_us, elapsed_us)
        broadcast_rejection(key_expr, result)
    end

    result
  end

  @spec perform_proof_token_verification(key_expr(), payload()) ::
          {:ok, :verified} | {:error, :missing_proof_token | :invalid_proof_token | :decode_error}
  defp perform_proof_token_verification(key_expr, payload) do
    case Jason.decode(payload) do
      {:ok, decoded} ->
        case Map.get(decoded, "proof_token") || Map.get(decoded, :proof_token) do
          nil ->
            Logger.warning("[RouterPlugin] Missing proof_token for key_expr=#{key_expr}")

            {:error, :missing_proof_token}

          raw_token ->
            verify_token_struct(key_expr, raw_token)
        end

      {:error, _reason} ->
        Logger.warning("[RouterPlugin] JSON decode error for key_expr=#{key_expr}")

        {:error, :decode_error}
    end
  end

  @spec verify_token_struct(key_expr(), map() | term()) ::
          {:ok, :verified} | {:error, :invalid_proof_token}
  defp verify_token_struct(key_expr, raw_token) when is_map(raw_token) do
    # Normalise string keys → atom keys for the struct
    token_map = %{
      id: Map.get(raw_token, "id") || Map.get(raw_token, :id),
      timestamp:
        parse_timestamp(Map.get(raw_token, "timestamp") || Map.get(raw_token, :timestamp)),
      claims: Map.get(raw_token, "claims") || Map.get(raw_token, :claims) || %{},
      signature: Map.get(raw_token, "signature") || Map.get(raw_token, :signature)
    }

    case call_verifier(token_map) do
      {:ok, :valid} ->
        Logger.debug("[RouterPlugin] ProofToken verified for key_expr=#{key_expr}")
        {:ok, :verified}

      {:error, reason} ->
        Logger.warning("[RouterPlugin] ProofToken invalid for key_expr=#{key_expr}: #{reason}")

        {:error, :invalid_proof_token}
    end
  end

  defp verify_token_struct(key_expr, _raw_token) do
    Logger.warning("[RouterPlugin] Malformed proof_token structure for key_expr=#{key_expr}")

    {:error, :invalid_proof_token}
  end

  # Graceful degradation: call Prometheus.Verifier if available, otherwise
  # reject with :invalid_proof_token to fail-closed (SC-SIL4-001).
  @spec call_verifier(map()) :: {:ok, :valid} | {:error, atom()}
  defp call_verifier(token_map) do
    verifier_mod =
      Application.get_env(:indrajaal, :proof_token_verifier, Indrajaal.Prometheus.Verifier)

    if Code.ensure_loaded?(verifier_mod) and
         function_exported?(verifier_mod, :verify_proof_token, 1) do
      verifier_mod.verify_proof_token(token_map)
    else
      # Fail-closed: verifier unavailable → reject
      Logger.error(
        "[RouterPlugin] ProofToken verifier module #{inspect(verifier_mod)} not available — failing closed (SC-SIL4-001)"
      )

      {:error, :verifier_unavailable}
    end
  end

  # ---------------------------------------------------------------------------
  # Filter matching (glob-style: ** matches any number of segments)
  # ---------------------------------------------------------------------------

  @spec matches_any_filter?(key_expr(), MapSet.t()) :: boolean()
  defp matches_any_filter?(key_expr, filters) do
    Enum.any?(filters, fn pattern -> glob_match?(pattern, key_expr) end)
  end

  @spec glob_match?(String.t(), String.t()) :: boolean()
  defp glob_match?(pattern, key_expr) do
    regex_source =
      pattern
      |> Regex.escape()
      |> String.replace("\\*\\*", ".*")
      |> String.replace("\\*", "[^/]*")

    case Regex.compile("^#{regex_source}$") do
      {:ok, regex} -> Regex.match?(regex, key_expr)
      {:error, _} -> false
    end
  end

  # ---------------------------------------------------------------------------
  # Telemetry
  # ---------------------------------------------------------------------------

  @spec emit_telemetry(key_expr(), verify_result(), non_neg_integer()) :: :ok
  defp emit_telemetry(key_expr, result, elapsed_us) do
    outcome =
      case result do
        {:ok, :pass_through} -> :pass_through
        {:ok, :verified} -> :verified
        {:error, reason} -> reason
      end

    :telemetry.execute(
      [:zenoh, :router_plugin, :verify],
      %{latency_us: elapsed_us},
      %{key_expr: key_expr, outcome: outcome}
    )

    :ok
  end

  # ---------------------------------------------------------------------------
  # PubSub broadcast for rejection events
  # ---------------------------------------------------------------------------

  @spec broadcast_rejection(key_expr(), verify_result()) :: :ok
  defp broadcast_rejection(key_expr, {:error, reason}) do
    event = %{
      event: :proof_token_rejected,
      key_expr: key_expr,
      reason: reason,
      timestamp: DateTime.utc_now()
    }

    for topic <- ["prajna:security", "zenoh:security_events"] do
      try do
        Phoenix.PubSub.broadcast(Indrajaal.PubSub, topic, event)
      rescue
        ArgumentError ->
          # PubSub not started in test/dev — safe to ignore
          :ok
      catch
        :exit, _ ->
          :ok
      end
    end

    :ok
  end

  defp broadcast_rejection(_key_expr, _result), do: :ok

  # ---------------------------------------------------------------------------
  # ETS stats helpers
  # ---------------------------------------------------------------------------

  @spec ensure_stats_table() :: :ets.tid() | atom()
  defp ensure_stats_table do
    case :ets.whereis(@stats_table) do
      :undefined ->
        :ets.new(@stats_table, [:named_table, :set, :public, write_concurrency: true])

      _tid ->
        @stats_table
    end
  end

  @spec record_stat(atom(), non_neg_integer()) :: true
  defp record_stat(key, increment) do
    ensure_stats_table()
    :ets.update_counter(@stats_table, key, increment, {key, 0})
  end

  @spec read_counter(atom()) :: non_neg_integer()
  defp read_counter(key) do
    ensure_stats_table()

    case :ets.lookup(@stats_table, key) do
      [{^key, value}] -> value
      [] -> 0
    end
  end

  # ---------------------------------------------------------------------------
  # Timestamp parsing helper
  # ---------------------------------------------------------------------------

  @spec parse_timestamp(String.t() | DateTime.t() | nil) :: DateTime.t()
  defp parse_timestamp(%DateTime{} = dt), do: dt

  defp parse_timestamp(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _offset} -> dt
      {:error, _} -> DateTime.utc_now()
    end
  end

  defp parse_timestamp(_), do: DateTime.utc_now()
end
