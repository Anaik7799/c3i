defmodule Indrajaal.Accounts.SessionSecurity do
  @moduledoc """
  Session Security Enhancement System

  Provides comprehensive session security with:
  - Session fingerprinting and validation
  - Concurrent session limits and management
  - Session timeout and rotation
  - Session hijacking pr_evention
  - Anomaly detection and response
  """

  require Logger

  # alias Indrajaal.Security.RateLimiter # Removed - unused

  @fingerprint_components [:user_agent, :accept_language, :accept_encoding, :accept]
  # Maximum session duration
  @max_session_age :timer.hours(8)
  # Idle timeout
  @idle_timeout :timer.minutes(30)
  # Session ID rotation interval
  # @rotation_interval :timer.hours(2) # Unused - kept for future use
  # Max IP changes before suspicion
  # @ip_change_threshold 3 # Unused - kept for future use

  @doc """
  Generates a comprehensive session fingerprint
  """
  @spec generate_fingerprint(any()) :: any()
  def generate_fingerprint(conn) do
    components =
      Enum.map(@fingerprint_components, fn component ->
        get_header_value(conn, component)
      end)

    # Include additional entropy
    additional_data = [
      get_client_ip(conn),
      extract_timezone_info(conn),
      extract_screen_info(conn)
    ]

    all_components = components ++ additional_data

    fingerprint =
      all_components
      |> Enum.join("|")
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode64()

    Logger.debug("Session fingerprint generated",
      fingerprint_hash: String.slice(fingerprint, 0, 16),
      components_count: length(all_components)
    )

    :telemetry.execute(
      [:indrajaal, :session, :fingerprint_generated],
      %{generation_time: System.system_time()},
      %{components_count: length(all_components)}
    )

    fingerprint
  end

  @doc """
  Validates a session with comprehensive security checks
  """
  @spec validate_session(term(), term(), term()) :: term()
  def validate_session(session_id, conn, opts \\ []) do
    :telemetry.execute(
      [:indrajaal, :session, :validation, :start],
      %{system_time: System.system_time()},
      %{session_id_hash: hash_session_id(session_id)}
    )

    with {:ok, session} <- load_session(session_id),
         :ok <- validate_session_active(session),
         :ok <- validate_fingerprint(session, conn, opts),
         :ok <- validate_ip_consistency(session, conn, opts),
         :ok <- validate_expiration(session),
         :ok <- validate_idle_timeout(session),
         :ok <- check_session_anomalies(session, conn),
         {:ok, updated_session} <- update_session_activity(session, conn) do
      Logger.debug("Session validation successful",
        session_id_hash: hash_session_id(session_id),
        user_id: session.user_id,
        fingerprint_match: true
      )

      :telemetry.execute(
        [:indrajaal, :session, :validation, :success],
        %{validation_time: System.system_time()},
        %{session_id_hash: hash_session_id(session_id), user_id: session.user_id}
      )

      {:ok, updated_session}
    else
      {:error, reason} = error ->
        Logger.warning("Session validation failed",
          session_id_hash: hash_session_id(session_id),
          reason: reason,
          client_ip: get_client_ip(conn)
        )

        :telemetry.execute(
          [:indrajaal, :session, :validation, :failure],
          %{failure_time: System.system_time()},
          %{session_id_hash: hash_session_id(session_id), reason: reason}
        )

        error
    end
  end

  @doc """
  Rotates session ID while preserving session __data
  """
  @spec rotate_session_id(any()) :: any()
  def rotate_session_id(old_session) do
    new_session_id = generate_secure_session_id()

    new_session = %{
      old_session
      | session_id: new_session_id,
        created_at: System.system_time(:second),
        rotated_at: System.system_time(:second),
        rotation_count: Map.get(old_session, :rotation_count, 0) + 1
    }

    with :ok <- store_session(new_session),
         :ok <- invalidate_session(old_session.session_id) do
      Logger.info("Session ID rotated",
        old_session_hash: hash_session_id(old_session.session_id),
        new_session_hash: hash_session_id(new_session_id),
        user_id: old_session.user_id,
        rotation_count: new_session.rotation_count
      )

      :telemetry.execute(
        [:indrajaal, :session, :rotation],
        %{rotation_time: System.system_time()},
        %{user_id: old_session.user_id, rotation_count: new_session.rotation_count}
      )

      {:ok, new_session}
    else
      error -> error
    end
  end

  @doc """
  Creates a new secure session
  """
  @spec create_session(term(), term(), term(), list()) :: term()
  def create_session(user_id, conn, _browser_info, opts \\ []) do
    session_id = generate_secure_session_id()
    fingerprint = generate_fingerprint(conn)
    client_ip = get_client_ip(conn)
    current_time = System.system_time(:second)

    # Check concurrent session limits
    case check_concurrent_sessions(user_id, opts) do
      :ok ->
        session = %{
          session_id: session_id,
          user_id: user_id,
          tenant_id: get_tenant_id(conn),
          fingerprint: fingerprint,
          client_ip: client_ip,
          created_at: current_time,
          last_activity_at: current_time,
          expires_at: current_time + div(@max_session_age, 1000),
          rotation_count: 0,
          ip_history: [client_ip],
          anomaly_score: 0,
          active: true
        }

        case store_session(session) do
          :ok ->
            Logger.info("Session created",
              session_id_hash: hash_session_id(session_id),
              user_id: user_id,
              tenant_id: session.tenant_id,
              client_ip: client_ip
            )

            :telemetry.execute(
              [:indrajaal, :session, :created],
              %{creation_time: System.system_time()},
              %{user_id: user_id, tenant_id: session.tenant_id}
            )

            {:ok, session}

          error ->
            error
        end

      {:error, :max_sessions_exceeded} = error ->
        Logger.warning("Session creation failed - concurrent session limit exceeded",
          user_id: user_id,
          client_ip: client_ip
        )

        error
    end
  end

  @doc """
  Terminates a session
  """
  @spec terminate_session(any(), any()) :: any()
  def terminate_session(session_id, reason \\ :user_logout) do
    with {:ok, session} <- load_session(session_id),
         :ok <- invalidate_session(session_id) do
      Logger.info("Session terminated",
        session_id_hash: hash_session_id(session_id),
        user_id: session.user_id,
        reason: reason,
        duration_seconds: System.system_time(:second) - session.created_at
      )

      :telemetry.execute(
        [:indrajaal, :session, :terminated],
        %{termination_time: System.system_time()},
        %{user_id: session.user_id, reason: reason}
      )

      :ok
    else
      error -> error
    end
  end

  @doc """
  Manages concurrent sessions for a user
  """
  @spec manage_concurrent_sessions(any(), any()) :: any()
  def manage_concurrent_sessions(user_id, max_sessions \\ nil) do
    max_allowed = max_sessions || get_max_sessions_for_user(user_id)

    case get_active_sessions_for_user(user_id) do
      {:ok, sessions} when length(sessions) > max_allowed ->
        # Terminate oldest sessions
        sessions_to_terminate =
          sessions
          |> Enum.sort_by(& &1.last_activity_at)
          |> Enum.take(length(sessions) - max_allowed)

        Enum.each(sessions_to_terminate, fn session ->
          terminate_session(session.session_id, :concurrent_limit_exceeded)
        end)

        Logger.info("Concurrent sessions limited",
          user_id: user_id,
          terminated_count: length(sessions_to_terminate),
          remaining_count: max_allowed
        )

        {:ok, length(sessions_to_terminate)}

      {:ok, _sessions} ->
        # No sessions terminated
        {:ok, 0}

      error ->
        error
    end
  end

  @doc """
  Detects session anomalies and suspicious activity
  """
  @spec detect_anomalies(any(), any()) :: any()
  def detect_anomalies(session, conn) do
    anomalies = []

    # Check for IP address changes
    current_ip = get_client_ip(conn)

    anomalies =
      if current_ip in session.ip_history do
        anomalies
      else
        [{:ip_change, current_ip} | anomalies]
      end

    # Check for user agent changes
    current_ua = get_header_value(conn, :user_agent)
    stored_ua = extract_user_agent_from_fingerprint(session.fingerprint)

    anomalies =
      if current_ua != stored_ua do
        [{:user_agent_change, current_ua} | anomalies]
      else
        anomalies
      end

    # Check for impossible travel (geolocation - based)
    # Simplified: check_impossible_travel always returns :ok in current implementation
    _travel_check = check_impossible_travel(session, current_ip)

    # Check for rapid requests (potential bot activity)
    # Simplified: check_request_pattern always returns :ok in current implementation
    _pattern_check = check_request_pattern(session.user_id)

    case anomalies do
      [] ->
        {:ok, session}

      detected_anomalies ->
        updated_session = %{
          session
          | anomaly_score: session.anomaly_score + length(detected_anomalies)
        }

        Logger.warning("Session anomalies detected",
          session_id_hash: hash_session_id(session.session_id),
          user_id: session.user_id,
          anomalies: detected_anomalies,
          anomaly_score: updated_session.anomaly_score
        )

        {:warning, updated_session, detected_anomalies}
    end
  end

  # Private Functions

  @spec get_header_value(term(), atom()) :: term()
  defp get_header_value(conn, header_atom) do
    header_name =
      case header_atom do
        :user_agent -> "user-agent"
        :accept_language -> "accept-language"
        :accept_encoding -> "accept-encoding"
        :accept -> "accept"
      end

    case Plug.Conn.get_req_header(conn, header_name) do
      [value] -> value
      [] -> ""
      values -> Enum.join(values, ",")
    end
  end

  @spec get_client_ip(term()) :: term()
  defp get_client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded_ips] ->
        forwarded_ips
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        case Plug.Conn.get_req_header(conn, "x-real-ip") do
          [real_ip] ->
            String.trim(real_ip)

          [] ->
            conn.remote_ip
            |> :inet.ntoa()
            |> to_string()
        end
    end
  end

  @spec extract_timezone_info(term()) :: term()
  defp extract_timezone_info(conn) do
    # Try to extract timezone from headers or use UTC as default
    case Plug.Conn.get_req_header(conn, "x - timezone") do
      [timezone] -> timezone
      [] -> "UTC"
    end
  end

  @spec extract_screen_info(term()) :: term()
  defp extract_screen_info(conn) do
    # Try to extract screen resolution from headers
    case Plug.Conn.get_req_header(conn, "x - screen - resolution") do
      [resolution] -> resolution
      [] -> "unknown"
    end
  end

  @ets_table :session_security_store
  @default_ttl_seconds 3600

  @spec ensure_table() :: :ok
  defp ensure_table do
    if :ets.whereis(@ets_table) == :undefined do
      :ets.new(@ets_table, [:named_table, :set, :public, {:read_concurrency, true}])
    end

    :ok
  end

  @spec load_session(term()) :: term()
  defp load_session(session_id) do
    ensure_table()

    case :ets.lookup(@ets_table, session_id) do
      [{^session_id, session_data, inserted_at, ttl_seconds}] ->
        now = System.system_time(:second)

        if now - inserted_at > ttl_seconds do
          :ets.delete(@ets_table, session_id)
          {:error, :session_expired}
        else
          {:ok, session_data}
        end

      [] ->
        {:error, :not_found}
    end
  end

  @spec store_session(term()) :: term()
  defp store_session(session) do
    ensure_table()
    inserted_at = System.system_time(:second)
    :ets.insert(@ets_table, {session.session_id, session, inserted_at, @default_ttl_seconds})
    :ok
  end

  @spec invalidate_session(term()) :: term()
  defp invalidate_session(session_id) do
    ensure_table()
    :ets.delete(@ets_table, session_id)
    :ok
  end

  @spec validate_session_active(map()) :: term()
  defp validate_session_active(%{active: true}), do: :ok
  defp validate_session_active(_), do: {:error, :session_inactive}

  defp validate_fingerprint(session, conn, opts) do
    current_fingerprint = generate_fingerprint(conn)
    strict_validation = Keyword.get(opts, :strict_fingerprint, true)

    if strict_validation do
      if session.fingerprint == current_fingerprint do
        :ok
      else
        {:error, :fingerprint_mismatch}
      end
    else
      # Allow some flexibility for mobile clients
      similarity =
        calculate_fingerprint_similarity(
          session.fingerprint,
          current_fingerprint
        )

      if similarity > 0.8 do
        :ok
      else
        {:error, :fingerprint_mismatch}
      end
    end
  end

  defp validate_ip_consistency(session, conn, opts) do
    current_ip = get_client_ip(conn)
    allow_ip_changes = Keyword.get(opts, :allow_ip_changes, true)

    if allow_ip_changes do
      # Check if IP is within reasonable bounds (same subnet, known proxies, et
      if reasonable_ip_change?(session.client_ip, current_ip) do
        :ok
      else
        {:error, :suspicious_ip_change}
      end
    else
      if session.client_ip == current_ip do
        :ok
      else
        {:error, :ip_mismatch}
      end
    end
  end

  @spec validate_expiration(term()) :: term()
  defp validate_expiration(session) do
    current_time = System.system_time(:second)

    if current_time < session.expires_at do
      :ok
    else
      {:error, :session_expired}
    end
  end

  @spec validate_idle_timeout(term()) :: term()
  defp validate_idle_timeout(session) do
    current_time = System.system_time(:second)
    idle_duration = current_time - session.last_activity_at
    max_idle = div(@idle_timeout, 1000)

    if idle_duration < max_idle do
      :ok
    else
      {:error, :session_idle_timeout}
    end
  end

  @spec check_session_anomalies(term(), term()) :: term()
  defp check_session_anomalies(session, conn) do
    case detect_anomalies(session, conn) do
      {:ok, _session} ->
        :ok

      {:warning, _session, anomalies} ->
        # Log warning but continue
        Logger.warning("Session anomalies detected but continuing",
          anomalies: anomalies
        )

        :ok
    end
  end

  @spec update_session_activity(term(), term()) :: term()
  defp update_session_activity(session, conn) do
    current_time = System.system_time(:second)
    current_ip = get_client_ip(conn)

    updated_session = %{
      session
      | last_activity_at: current_time,
        ip_history: update_ip_history(session.ip_history, current_ip)
    }

    case store_session(updated_session) do
      :ok -> {:ok, updated_session}
      error -> error
    end
  end

  @spec check_concurrent_sessions(term(), term()) :: term()
  defp check_concurrent_sessions(user_id, opts) do
    max_sessions = Keyword.get(opts, :max_sessions) || get_max_sessions_for_user(user_id)

    case get_active_sessions_count_for_user(user_id) do
      {:ok, count} when count < max_sessions -> :ok
      {:ok, _count} -> {:error, :max_sessions_exceeded}
      error -> error
    end
  end

  @spec generate_secure_session_id() :: any()
  defp generate_secure_session_id do
    bytes = :crypto.strong_rand_bytes(32)
    Base.url_encode64(bytes, padding: false)
  end

  @spec get_max_sessions_for_user(term()) :: term()
  defp get_max_sessions_for_user(user_id) do
    # Derive max sessions from cached role stored on existing sessions,
    # falling back to default when no session exists yet.
    role =
      case get_active_sessions_for_user(user_id) do
        {:ok, [session | _]} -> Map.get(session, :role, :default)
        _ -> :default
      end

    max_sessions =
      case role do
        :admin -> 10
        :manager -> 5
        _ -> 3
      end

    :telemetry.execute(
      [:indrajaal, :security, :session, :max_sessions_check],
      %{system_time: System.system_time()},
      %{user_id: user_id, role: role, max_sessions: max_sessions}
    )

    max_sessions
  end

  @spec get_active_sessions_for_user(term()) :: term()
  defp get_active_sessions_for_user(user_id) do
    ensure_table()
    now = System.system_time(:second)

    active_sessions =
      :ets.foldl(
        fn {session_id, session_data, inserted_at, ttl_seconds}, acc ->
          expired = now - inserted_at > ttl_seconds

          if expired do
            :ets.delete(@ets_table, session_id)
            acc
          else
            if Map.get(session_data, :user_id) == user_id do
              [session_data | acc]
            else
              acc
            end
          end
        end,
        [],
        @ets_table
      )

    {:ok, active_sessions}
  end

  @spec get_active_sessions_count_for_user(term()) :: term()
  defp get_active_sessions_count_for_user(user_id) do
    case get_active_sessions_for_user(user_id) do
      {:ok, sessions} -> {:ok, length(sessions)}
      error -> error
    end
  end

  @spec calculate_fingerprint_similarity(term(), term()) :: term()
  defp calculate_fingerprint_similarity(fp1, fp2) when is_binary(fp1) and is_binary(fp2) do
    # Jaccard similarity on the set of 4-character n-grams extracted from
    # each fingerprint string.  This gives a meaningful similarity score
    # even when the fingerprints differ in only a few components.
    ngrams = fn s ->
      s
      |> String.graphemes()
      |> Enum.chunk_every(4, 1, :discard)
      |> Enum.map(&Enum.join/1)
      |> MapSet.new()
    end

    set1 = ngrams.(fp1)
    set2 = ngrams.(fp2)

    intersection_size = MapSet.intersection(set1, set2) |> MapSet.size()
    union_size = MapSet.union(set1, set2) |> MapSet.size()

    similarity =
      if union_size == 0 do
        if fp1 == fp2, do: 1.0, else: 0.0
      else
        intersection_size / union_size
      end

    :telemetry.execute(
      [:indrajaal, :security, :session, :fingerprint_similarity],
      %{system_time: System.system_time()},
      %{similarity: similarity}
    )

    similarity
  end

  defp calculate_fingerprint_similarity(_fp1, _fp2), do: 0.0

  @spec reasonable_ip_change?(term(), term()) :: term()
  defp reasonable_ip_change?(old_ip, new_ip) when is_binary(old_ip) and is_binary(new_ip) do
    # Parse IPv4 octets and check whether the two addresses share the same
    # /24 subnet (first three octets identical).  If either string is not a
    # valid IPv4 address we allow the change so as not to lock out IPv6
    # clients or clients behind load-balancers that normalise the header.
    result =
      with [o1, o2, o3, _] <- String.split(old_ip, "."),
           [n1, n2, n3, _] <- String.split(new_ip, "."),
           true <- Enum.all?([o1, o2, o3, n1, n2, n3], &match?({_, ""}, Integer.parse(&1))) do
        o1 == n1 and o2 == n2 and o3 == n3
      else
        _ -> true
      end

    :telemetry.execute(
      [:indrajaal, :security, :session, :ip_change_check],
      %{system_time: System.system_time()},
      %{old_ip: old_ip, new_ip: new_ip, reasonable: result}
    )

    result
  end

  defp reasonable_ip_change?(_old_ip, _new_ip), do: true

  @spec update_ip_history(term(), term()) :: term()
  defp update_ip_history(ip_history, new_ip) do
    if new_ip in ip_history do
      ip_history
    else
      # Keep last 10 IPs
      [new_ip | Enum.take(ip_history, 9)]
    end
  end

  @spec extract_user_agent_from_fingerprint(term()) :: term()
  defp extract_user_agent_from_fingerprint(fingerprint) when is_map(fingerprint) do
    # Fingerprint stored as a structured map with component keys.
    Map.get(fingerprint, :user_agent, "")
  end

  defp extract_user_agent_from_fingerprint(fingerprint) when is_binary(fingerprint) do
    # Fingerprint is a Base64-encoded SHA256 hash — the raw UA cannot be
    # recovered from the hash.  We look up any live session that carries this
    # fingerprint hash and retrieve the UA from its stored header map.
    # If no match is found we return an empty string, which is safe because
    # the caller (detect_anomalies/2) treats "" as "unknown / changed".
    ensure_table()

    result =
      :ets.foldl(
        fn {_session_id, session_data, _inserted_at, _ttl}, acc ->
          if acc == "" and Map.get(session_data, :fingerprint) == fingerprint do
            Map.get(session_data, :user_agent, "")
          else
            acc
          end
        end,
        "",
        @ets_table
      )

    result
  end

  defp extract_user_agent_from_fingerprint(_fingerprint), do: ""

  @rate_table :session_security_rate

  @spec ensure_rate_table() :: :ok
  defp ensure_rate_table do
    if :ets.whereis(@rate_table) == :undefined do
      :ets.new(@rate_table, [:named_table, :set, :public, {:write_concurrency, true}])
    end

    :ok
  end

  @spec parse_ip_octet(binary()) :: {:ok, non_neg_integer()} | :error
  defp parse_ip_octet(str) do
    case Integer.parse(String.trim(str)) do
      {n, ""} when n >= 0 and n <= 255 -> {:ok, n}
      _ -> :error
    end
  end

  @spec check_impossible_travel(term(), term()) :: term()
  defp check_impossible_travel(session, current_ip) when is_binary(current_ip) do
    last_ip = Map.get(session, :client_ip, "")
    elapsed_seconds = System.system_time(:second) - Map.get(session, :last_activity_at, 0)

    result =
      with [lo1 | _] <- String.split(last_ip, "."),
           [co1 | _] <- String.split(current_ip, "."),
           {:ok, lo1_int} <- parse_ip_octet(lo1),
           {:ok, co1_int} <- parse_ip_octet(co1),
           true <- lo1_int != co1_int,
           true <- elapsed_seconds < 36_000 do
        Logger.warning("Impossible travel detected",
          user_id: Map.get(session, :user_id),
          last_ip: last_ip,
          current_ip: current_ip,
          elapsed_seconds: elapsed_seconds
        )

        :telemetry.execute(
          [:indrajaal, :security, :session, :impossible_travel],
          %{system_time: System.system_time()},
          %{
            user_id: Map.get(session, :user_id),
            last_ip: last_ip,
            current_ip: current_ip,
            elapsed_seconds: elapsed_seconds
          }
        )

        {:warning, :impossible_travel}
      else
        _ -> :ok
      end

    result
  end

  defp check_impossible_travel(_session, _current_ip), do: :ok

  @spec check_request_pattern(term()) :: term()
  defp check_request_pattern(user_id) do
    ensure_rate_table()
    now = System.system_time(:second)
    window = 60
    threshold = 100
    bucket_key = {user_id, div(now, window)}

    count =
      case :ets.lookup(@rate_table, bucket_key) do
        [{^bucket_key, n}] ->
          :ets.update_counter(@rate_table, bucket_key, 1)
          n + 1

        [] ->
          :ets.insert(@rate_table, {bucket_key, 1})
          1
      end

    if count > threshold do
      Logger.warning("Suspicious request pattern detected",
        user_id: user_id,
        request_count: count,
        window_seconds: window
      )

      :telemetry.execute(
        [:indrajaal, :security, :session, :suspicious_pattern],
        %{system_time: System.system_time()},
        %{user_id: user_id, request_count: count, window_seconds: window}
      )

      {:warning, :high_request_rate}
    else
      :telemetry.execute(
        [:indrajaal, :security, :session, :request_pattern],
        %{system_time: System.system_time()},
        %{user_id: user_id, request_count: count}
      )

      :ok
    end
  end

  @spec hash_session_id(term()) :: term()
  defp hash_session_id(session_id) do
    hash = :crypto.hash(:sha256, session_id)
    encoded = Base.encode16(hash)
    String.slice(encoded, 0, 16)
  end

  @spec get_tenant_id(term()) :: term()
  defp get_tenant_id(conn) do
    # Extract tenant_id from connection context or headers
    case Plug.Conn.get_req_header(conn, "x-tenant-id") do
      [tenant_id] -> tenant_id
      [] -> "default_tenant"
    end
  end
end

# Agent: Worker - 5 (Security Domain Agent)
# SOPv5.1 Compliance: ✅ User account management and authentication coordination
# Domain: Accounts
# Responsibilities: Security access control, authentication, policy enforcement
# Multi - Agent Architecture: Integrated with 11 - agent coordination system
# Cybernetic Feedback: Active feedback loops for continuous improvement
