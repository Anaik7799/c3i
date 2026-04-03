defmodule Indrajaal.Native.Zenoh do
  @moduledoc """
  Elixir wrapper for Zenoh Rust NIF.

  ## WHAT
  Low-level NIF bindings to Zenoh native protocol for <1ms latency
  pub/sub messaging between Indrajaal and CEPAF F# cockpit.

  ## WHY
  - Native protocol provides <1ms latency (SC-ZENOH-INT-001)
  - Rust safety guarantees prevent memory errors
  - Async runtime handles concurrent connections

  ## CONSTRAINTS
  - SC-NIF-001: NIF functions must not block scheduler
  - SC-NIF-002: Resource cleanup on process exit
  - SC-NIF-003: Error propagation to Elixir
  - SC-NIF-005: ProofToken enforcement at NIF boundary (control-plane gate)
  - SC-HASH-002: Constant-time signature comparison in Rust layer

  ## Usage
  ```elixir
  # Open session
  {:ok, session} = Indrajaal.Native.Zenoh.open_session(%{
    connect: ["tcp/zenoh:7447"],
    mode: "client",
    multicast_scouting: true
  })

  # Publish message
  :ok = Indrajaal.Native.Zenoh.publish(session, "indrajaal/fractal/l3/alarms", payload)

  # Subscribe to topic
  {:ok, subscriber} = Indrajaal.Native.Zenoh.subscribe(session, "indrajaal/control/**", self())

  # Poll messages
  {:ok, messages} = Indrajaal.Native.Zenoh.poll_messages(subscriber, 100)

  # Query stored data
  {:ok, results} = Indrajaal.Native.Zenoh.get(session, "indrajaal/kpi/**")

  # Close session
  :ok = Indrajaal.Native.Zenoh.close_session(session)
  ```
  """

  # SC-NIF-004: Cargo must be available for NIF compilation
  # TPS/Jidoka: Only compile when Rust toolchain is present
  @cargo_available System.find_executable("cargo") != nil

  use Rustler,
    otp_app: :indrajaal,
    crate: :zenoh_nif,
    mode: if(Mix.env() == :prod, do: :release, else: :debug),
    skip_compilation?: not @cargo_available

  require Logger

  # =============================================================================
  # Session Management
  # =============================================================================

  @doc """
  Open a new Zenoh session.

  ## Parameters
  - `config` - Configuration map with:
    - `:connect` - List of endpoints (e.g., ["tcp/zenoh:7447"])
    - `:mode` - "peer", "client", or "router" (default: "client")
    - `:multicast_scouting` - Enable multicast discovery (default: true)

  ## Returns
  - `{:ok, session_ref}` - Session reference for subsequent operations
  - `{:error, reason}` - Error with description

  ## STAMP
  - SC-ZENOH-SES-001: Single session per node
  """
  @spec open_session(map()) :: {:ok, reference()} | {:error, String.t()}
  def open_session(config) when is_map(config) do
    config_json = Jason.encode!(config)
    zenoh_open_session(config_json)
  end

  def open_session(_config), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Close a Zenoh session.

  ## Parameters
  - `session` - Session reference from open_session/1

  ## Returns
  - `:ok` - Session closed successfully

  ## STAMP
  - SC-ZENOH-SES-003: Graceful shutdown with drain
  """
  @spec close_session(reference()) :: :ok | {:error, String.t()}
  def close_session(session), do: zenoh_close_session(session)

  @doc """
  Get session statistics.

  ## Parameters
  - `session` - Session reference

  ## Returns
  - Map with stats: messages_sent, messages_received, reconnect_count,
    uptime_seconds, last_publish_latency_us
  """
  @spec session_info(reference()) :: map()
  def session_info(session), do: zenoh_session_info(session)

  @doc """
  Get session connection status.

  ## Parameters
  - `session` - Session reference

  ## Returns
  - Map with: connected, router_endpoint, session_id
  """
  @spec session_status(reference()) :: map()
  def session_status(session), do: zenoh_session_status(session)

  # =============================================================================
  # Publishing
  # =============================================================================

  @doc """
  Publish a message to a key expression.

  ## Parameters
  - `session` - Session reference
  - `key` - Key expression (e.g., "indrajaal/fractal/l3/alarms")
  - `payload` - Binary payload

  ## Returns
  - `:ok` - Published successfully
  - `{:error, reason}` - Publication failed

  ## STAMP
  - SC-ZENOH-PUB-001: Non-blocking publication
  - SC-ZENOH-PUB-002: Latency monitoring (<1ms target)
  - SC-EVO-002: Substrate-level ProofToken enforcement
  - SC-NIF-005: ProofToken also enforced at Rust NIF boundary
  """
  @spec publish(reference(), String.t(), binary()) :: :ok | {:error, String.t()}
  def publish(session, key, payload) do
    case verify_substrate_safety(key, payload) do
      :ok ->
        zenoh_publish(session, key, payload)

      {:error, reason} ->
        Logger.error("[SubstrateSafety] Dropping un-proven signal on #{key}: #{reason}")
        {:error, "Substrate safety violation: #{reason}"}
    end
  end

  @doc """
  Put (publish with store) a message.

  Same as publish/3 for Zenoh 1.0.
  """
  @spec put(reference(), String.t(), binary()) :: :ok | {:error, String.t()}
  def put(session, key, payload) do
    case verify_substrate_safety(key, payload) do
      :ok ->
        zenoh_put(session, key, payload)

      {:error, reason} ->
        Logger.error("[SubstrateSafety] Dropping un-proven signal on #{key}: #{reason}")
        {:error, "Substrate safety violation: #{reason}"}
    end
  end

  @doc """
  Delete a key from Zenoh storage.

  ## Parameters
  - `session` - Session reference
  - `key` - Key to delete

  ## Returns
  - `:ok` - Deleted successfully
  """
  @spec delete(reference(), String.t()) :: :ok | {:error, String.t()}
  def delete(session, key), do: zenoh_delete(session, key)

  @doc """
  Publish a batch of messages.

  ## Parameters
  - `session` - Session reference
  - `messages` - List of `%{key: String.t(), payload: binary()}`

  ## Returns
  - `{:ok, count}` - Number of messages published
  - `{:error, reason}` - Partial failure with count and last error

  ## STAMP
  - SC-ZENOH-PUB-003: Batch support for efficiency
  """
  @spec publish_batch(reference(), list(map())) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def publish_batch(session, messages) do
    # Batch verification: All control signals in the batch must be proven
    verified_messages =
      Enum.filter(messages, fn msg ->
        case verify_substrate_safety(msg.key, msg.payload) do
          :ok -> true
          _ -> false
        end
      end)

    if length(verified_messages) == length(messages) do
      zenoh_publish_batch(session, messages)
    else
      Logger.warning(
        "[SubstrateSafety] Dropping #{length(messages) - length(verified_messages)} un-proven signals from batch."
      )

      if verified_messages == [],
        do: {:ok, 0},
        else: zenoh_publish_batch(session, verified_messages)
    end
  end

  # =============================================================================
  # ProofToken Fast-Path Verification (SC-NIF-005)
  # =============================================================================

  @doc """
  Verify a ProofToken payload at the Rust NIF layer.

  Fast-path verification that runs HMAC-SHA256 in the Rust NIF without performing
  a publish.  Useful for pre-validation before constructing a full control-plane
  message.

  ## Parameters
  - `token_binary` — Raw JSON binary of the outer payload containing `proof_token`

  ## Returns
  - `{:ok, :valid}` — Token is present and HMAC signature is correct
  - `{:error, reason}` — Token is absent, malformed, or signature is invalid

  ## STAMP
  - SC-NIF-005: ProofToken enforcement at NIF boundary
  - SC-HASH-002: Constant-time comparison in Rust
  """
  @spec verify_proof_token(binary()) :: {:ok, :valid} | {:error, String.t()}
  def verify_proof_token(token_binary) when is_binary(token_binary) do
    zenoh_verify_proof_token(token_binary)
  end

  def verify_proof_token(_), do: {:error, "token_binary must be a binary"}

  @doc """
  Verify a ProofToken with session caching (Tier 1) at the Rust NIF layer.

  For inference-plane keys (`indrajaal/inference/**`, `indrajaal/neural/**`),
  the first verification performs a full HMAC-SHA256 check, then caches the
  result for 60 seconds.  Subsequent calls with the same payload return
  immediately from the cache.

  ## Parameters
  - `token_binary` — Raw JSON binary of the payload containing `proof_token`

  ## Returns
  - `{:ok, :valid}` — Token is present and signature is correct (possibly cached)
  - `{:error, reason}` — Token is absent, malformed, or signature is invalid

  ## STAMP
  - SC-NIF-011: Session token caching with 60s TTL
  - SC-HASH-002: Constant-time comparison in Rust
  """
  @spec verify_session_token(binary()) :: {:ok, :valid} | {:error, String.t()}
  def verify_session_token(token_binary) when is_binary(token_binary) do
    zenoh_verify_session_token(token_binary)
  end

  def verify_session_token(_), do: {:error, "token_binary must be a binary"}

  @doc """
  Classify a Zenoh key expression into its enforcement tier at the Rust NIF layer.

  Returns an atom indicating the ProofToken enforcement level:
  - `:bypass`  — Tier 0: telemetry, logs, health, metrics (no enforcement)
  - `:session` — Tier 1: inference, neural (session-cached HMAC, 60s TTL)
  - `:full`    — Tier 2: control, evolution (full HMAC per call)

  ## Parameters
  - `key_expr` — Zenoh key expression string

  ## Returns
  - `:bypass` | `:session` | `:full`

  ## STAMP
  - SC-NIF-010: Tiered enforcement classification
  """
  @spec classify_tier(String.t()) :: :bypass | :session | :full
  def classify_tier(key_expr) when is_binary(key_expr) do
    zenoh_classify_tier(key_expr)
  end

  def classify_tier(_), do: :bypass

  # =============================================================================
  # Substrate Safety Gate (SC-EVO-002)
  # =============================================================================

  # Tier 0 bypass prefixes — MUST stay in sync with proof_token.rs BYPASS_PREFIXES
  @bypass_prefixes ["indrajaal/logs/", "indrajaal/metrics/", "indrajaal/health/"]
  # Tier 1 session prefixes — MUST stay in sync with proof_token.rs SESSION_PREFIXES
  @session_prefixes ["indrajaal/inference/", "indrajaal/neural/"]
  # Tier 2 full enforcement prefixes — MUST stay in sync with proof_token.rs FULL_PREFIXES
  @full_prefixes ["indrajaal/control/", "indrajaal/evolution/"]

  # Pure Elixir tier classification — no NIF dependency.
  # Mirrors Rust `classify_tier()` but runs in BEAM, so verify_substrate_safety
  # works even when the NIF library isn't loaded (graceful degradation).
  defp classify_tier_elixir(key) do
    cond do
      Enum.any?(@bypass_prefixes, &String.starts_with?(key, &1)) -> :bypass
      Enum.any?(@session_prefixes, &String.starts_with?(key, &1)) -> :session
      Enum.any?(@full_prefixes, &String.starts_with?(key, &1)) -> :full
      true -> :bypass
    end
  end

  # 3-tier enforcement matching Rust `enforce_tiered()` in publisher.rs (SC-NIF-010).
  # This Elixir gate provides defence-in-depth: even if this check is bypassed,
  # the Rust NIF boundary enforces the same tiers independently.
  #
  # | Tier | Key Prefix                         | Enforcement            |
  # |------|------------------------------------|------------------------|
  # | 0    | logs, metrics, health, unknown      | :bypass — no check     |
  # | 1    | inference, neural                   | Elixir Verifier check  |
  # | 2    | control, evolution                  | Elixir Verifier check  |
  defp verify_substrate_safety(key, payload) do
    case classify_tier_elixir(key) do
      :bypass ->
        :ok

      tier when tier in [:session, :full] ->
        case Jason.decode(payload) do
          {:ok, %{"proof_token" => token_map}} ->
            Indrajaal.Prometheus.Verifier.verify_proof_token(token_map)
            |> case do
              {:ok, :valid} -> :ok
              {:error, reason} -> {:error, "ProofToken rejected (#{tier}): #{reason}"}
            end

          {:ok, _} ->
            {:error, "Missing proof_token in #{tier}-tier payload"}

          {:error, _} ->
            {:error, "#{tier}-tier payload must be JSON with ProofToken"}
        end
    end
  end

  # =============================================================================
  # Subscribing
  # =============================================================================

  @doc """
  Subscribe to a key expression.

  ## Parameters
  - `session` - Session reference
  - `key_expr` - Key expression pattern (e.g., "indrajaal/fractal/**")
  - `callback_pid` - PID to receive messages (for future callback support)

  ## Returns
  - `{:ok, subscriber_ref}` - Subscriber reference for polling
  - `{:error, reason}` - Subscription failed

  ## STAMP
  - SC-ZENOH-SUB-001: Async message delivery
  - SC-ZENOH-SUB-002: Callback to Elixir process
  """
  @spec subscribe(reference(), String.t(), pid()) :: {:ok, reference()} | {:error, String.t()}
  def subscribe(session, key_expr, callback_pid),
    do: zenoh_subscribe(session, key_expr, callback_pid)

  @doc """
  Unsubscribe from a key expression.

  ## Parameters
  - `subscriber` - Subscriber reference from subscribe/3

  ## Returns
  - `:ok` - Unsubscribed successfully

  ## STAMP
  - SC-ZENOH-SUB-003: Graceful unsubscribe
  """
  @spec unsubscribe(reference()) :: :ok | {:error, String.t()}
  def unsubscribe(subscriber), do: zenoh_unsubscribe(subscriber)

  @doc """
  Poll for received messages (non-blocking).

  ## Parameters
  - `subscriber` - Subscriber reference
  - `max_messages` - Maximum number of messages to retrieve

  ## Returns
  - `{:ok, messages}` - List of received messages
  """
  @spec poll_messages(reference(), non_neg_integer()) :: {:ok, list(map())} | {:error, String.t()}
  def poll_messages(subscriber, max_messages), do: zenoh_poll_messages(subscriber, max_messages)

  @doc """
  Get subscription statistics.

  ## Parameters
  - `subscriber` - Subscriber reference from subscribe/3

  ## Returns
  - Map with subscription stats: messages_received, last_message_timestamp,
    key_expression, active
  """
  @spec subscription_stats(reference()) :: {:ok, map()} | {:error, String.t()}
  def subscription_stats(subscriber), do: zenoh_subscription_stats(subscriber)

  # =============================================================================
  # Queries
  # =============================================================================

  @doc """
  Query Zenoh storage with default timeout (10s).

  ## Parameters
  - `session` - Session reference
  - `key_expr` - Key expression to query

  ## Returns
  - `{:ok, messages}` - List of stored messages
  - `{:error, reason}` - Query failed
  """
  @spec get(reference(), String.t()) :: {:ok, list(map())} | {:error, String.t()}
  def get(session, key_expr), do: zenoh_get(session, key_expr)

  @doc """
  Query Zenoh storage with custom timeout.

  ## Parameters
  - `session` - Session reference
  - `key_expr` - Key expression to query
  - `timeout_ms` - Timeout in milliseconds

  ## Returns
  - `{:ok, messages}` - List of stored messages
  - `{:error, reason}` - Query failed or timed out
  """
  @spec get_timeout(reference(), String.t(), non_neg_integer()) ::
          {:ok, list(map())} | {:error, String.t()}
  def get_timeout(session, key_expr, timeout_ms),
    do: zenoh_get_timeout(session, key_expr, timeout_ms)

  # =============================================================================
  # NIF Binding Stubs (TPS/Jidoka)
  # =============================================================================
  defp zenoh_open_session(_config_json), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_close_session(_session), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_session_info(_session), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_session_status(_session), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_publish(_session, _key, _payload), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_put(_session, _key, _payload), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_delete(_session, _key), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_publish_batch(_session, _messages), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_subscribe(_session, _key_expr, _callback_pid), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_unsubscribe(_subscriber), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_poll_messages(_subscriber, _max_messages), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_subscription_stats(_subscriber), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_get(_session, _key_expr), do: :erlang.nif_error(:nif_not_loaded)
  defp zenoh_get_timeout(_session, _key_expr, _timeout_ms), do: :erlang.nif_error(:nif_not_loaded)
  # SC-NIF-005: ProofToken NIF binding stub — implemented in proof_token.rs
  defp zenoh_verify_proof_token(_token_binary), do: :erlang.nif_error(:nif_not_loaded)
  # SC-NIF-011: Session token NIF binding stub — verify_session in proof_token.rs
  defp zenoh_verify_session_token(_token_binary), do: :erlang.nif_error(:nif_not_loaded)
  # SC-NIF-010: Tier classification NIF binding stub — classify_tier in proof_token.rs
  defp zenoh_classify_tier(_key_expr), do: :erlang.nif_error(:nif_not_loaded)
end

# Supporting structs for NIF interop
defmodule Indrajaal.Native.Zenoh.Config do
  @moduledoc """
  Configuration struct for Zenoh session.
  """
  defstruct connect: ["tcp/localhost:7447"],
            mode: "client",
            multicast_scouting: true
end

defmodule Indrajaal.Native.Zenoh.Message do
  @moduledoc """
  Message received from Zenoh subscription.
  """
  defstruct key: "",
            payload: <<>>,
            timestamp: nil,
            encoding: "application/octet-stream",
            source: nil
end

defmodule Indrajaal.Native.Zenoh.Stats do
  @moduledoc """
  Session statistics.
  """
  defstruct messages_sent: 0,
            messages_received: 0,
            reconnect_count: 0,
            uptime_seconds: 0,
            last_publish_latency_us: 0
end

defmodule Indrajaal.Native.Zenoh.BatchRequest do
  @moduledoc """
  Batch publish request.
  """
  defstruct key: "",
            payload: <<>>
end
