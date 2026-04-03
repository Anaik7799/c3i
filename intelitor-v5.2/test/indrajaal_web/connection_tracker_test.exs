defmodule IndrajaalWeb.ConnectionTrackerTest do
  @moduledoc """
  TDG comprehensive test suite for IndrajaalWeb.ConnectionTracker.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation fixes
  - FPPS Validation: 5-method consensus verification

  ## STAMP Safety Integration
  - SC-TEST-NIF-001: SKIP_ZENOH_NIF=0 for all tests
  - SC-CNT-010: ConnectionTracker enforces max 10 connections per user

  ## Constitutional Verification
  - Psi0 Existence: ConnectionTracker never crashes for any input — returns
    error tuple rather than raising
  - Psi3 Verification: get_connection_stats/0 always returns {:ok, map} with
    active_connections and uptime_seconds keys
  - Psi5 Truthfulness: increment/decrement maintain monotonic consistency;
    increment after decrement never goes negative

  ## Founder's Directive Alignment
  - Omega0.1: Connection tracker enables real-time web infrastructure monitoring

  ## TPS 5-Level RCA Context
  - L1 Symptom: Connections accepted beyond per-user limit
  - L5 Root Cause: validate_connection_limits/2 bypassed when user_id is nil
    (anonymous connections have no limit); limit enforced only for non-nil user_ids
  """

  use ExUnit.Case, async: false
  use PropCheck

  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  # MANDATORY: Disambiguate generators (EP-GEN-014)
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  # MANDATORY: SKIP_ZENOH_NIF=0 for NIF tests (SC-TEST-NIF-001)
  @moduletag :zenoh_nif

  alias IndrajaalWeb.ConnectionTracker

  # ==========================================================================
  # Setup — start a fresh ConnectionTracker for each test
  # ==========================================================================

  setup do
    # Start a named-process-aware supervised ConnectionTracker
    # The module registers under its own name, so we must stop any running one
    case Process.whereis(ConnectionTracker) do
      nil ->
        :ok

      pid ->
        ref = Process.monitor(pid)
        GenServer.stop(pid, :normal)

        receive do
          {:DOWN, ^ref, _, _, _} -> :ok
        after
          1_000 -> :ok
        end
    end

    {:ok, _pid} = start_supervised!(ConnectionTracker)
    :ok
  end

  # ==========================================================================
  # track_connection/2
  # ==========================================================================

  describe "track_connection/2" do
    test "tracks a connection and returns {:ok, connection_id} (Psi0)" do
      conn_id = "conn-#{:erlang.unique_integer([:positive])}"

      result =
        ConnectionTracker.track_connection(conn_id, %{
          user_id: "user-#{:erlang.unique_integer([:positive])}",
          ip: "192.168.1.1",
          type: :websocket,
          endpoint: "/socket"
        })

      assert {:ok, ^conn_id} = result
    end

    test "allows anonymous (nil user_id) connections without limit" do
      conn_id = "anon-conn-#{:erlang.unique_integer([:positive])}"

      result =
        ConnectionTracker.track_connection(conn_id, %{
          user_id: nil,
          ip: "10.0.0.1",
          type: :http,
          endpoint: "/health"
        })

      assert {:ok, ^conn_id} = result
    end

    test "allows up to 10 connections per user (max limit)" do
      user_id = "user-limit-#{:erlang.unique_integer([:positive])}"

      results =
        Enum.map(1..10, fn i ->
          ConnectionTracker.track_connection("conn-#{i}-#{user_id}", %{
            user_id: user_id,
            type: :websocket
          })
        end)

      # All 10 should succeed
      Enum.each(results, fn result ->
        assert match?({:ok, _}, result)
      end)
    end

    test "rejects 11th connection per user with :max_connections_exceeded (SC-CNT-010)" do
      user_id = "user-max-#{:erlang.unique_integer([:positive])}"

      # Track exactly 10
      Enum.each(1..10, fn i ->
        ConnectionTracker.track_connection("conn-#{i}-#{user_id}", %{
          user_id: user_id,
          type: :websocket
        })
      end)

      # 11th should fail
      result =
        ConnectionTracker.track_connection("conn-11-#{user_id}", %{
          user_id: user_id,
          type: :websocket
        })

      assert {:error, :max_connections_exceeded} = result
    end

    test "different users have independent limits" do
      user_a = "user-a-#{:erlang.unique_integer([:positive])}"
      user_b = "user-b-#{:erlang.unique_integer([:positive])}"

      # Fill user_a to limit
      Enum.each(1..10, fn i ->
        ConnectionTracker.track_connection("conn-a-#{i}", %{user_id: user_a, type: :websocket})
      end)

      # user_b can still connect
      result = ConnectionTracker.track_connection("conn-b-1", %{user_id: user_b, type: :http})
      assert {:ok, "conn-b-1"} = result
    end

    test "connection record created with expected defaults" do
      conn_id = "conn-defaults-#{:erlang.unique_integer([:positive])}"
      user_id = "user-defaults-#{:erlang.unique_integer([:positive])}"

      {:ok, _} =
        ConnectionTracker.track_connection(conn_id, %{
          user_id: user_id,
          type: :websocket
        })

      {:ok, conn} = ConnectionTracker.get_connection(conn_id)

      assert conn.status == :active
      assert conn.bytes_sent == 0
      assert conn.bytes_received == 0
      assert conn.request_count == 0
      assert %DateTime{} = conn.connected_at
      assert %DateTime{} = conn.last_activity
    end

    test "duplicate connection_id overwrites previous record" do
      conn_id = "conn-dup-#{:erlang.unique_integer([:positive])}"
      user_id = "user-dup-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection(conn_id, %{user_id: user_id, type: :http})

      {:ok, _} =
        ConnectionTracker.track_connection(conn_id, %{user_id: user_id, type: :websocket})

      {:ok, conn} = ConnectionTracker.get_connection(conn_id)
      assert conn.type == :websocket
    end
  end

  # ==========================================================================
  # get_connection/1
  # ==========================================================================

  describe "get_connection/1" do
    test "returns {:ok, connection} for tracked connection (Psi3)" do
      conn_id = "conn-get-#{:erlang.unique_integer([:positive])}"

      {:ok, _} =
        ConnectionTracker.track_connection(conn_id, %{
          user_id: "user-get",
          type: :websocket,
          endpoint: "/live"
        })

      result = ConnectionTracker.get_connection(conn_id)

      assert {:ok, conn} = result
      assert conn.connection_id == conn_id
      assert conn.type == :websocket
    end

    test "returns {:error, :not_found} for untracked connection (Psi0)" do
      result = ConnectionTracker.get_connection("nonexistent-conn-id")
      assert {:error, :not_found} = result
    end

    test "returns {:error, :not_found} after untrack_connection" do
      conn_id = "conn-after-untrack-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection(conn_id, %{user_id: "user-x", type: :http})

      ConnectionTracker.untrack_connection(conn_id)
      # untrack_connection is a cast — wait for it to process
      Process.sleep(50)

      result = ConnectionTracker.get_connection(conn_id)
      assert {:error, :not_found} = result
    end

    test "returns :not_found for empty string connection_id" do
      result = ConnectionTracker.get_connection("")
      assert {:error, :not_found} = result
    end
  end

  # ==========================================================================
  # get_user_connections/1
  # ==========================================================================

  describe "get_user_connections/1" do
    test "returns {:ok, list} for user with connections" do
      user_id = "user-list-#{:erlang.unique_integer([:positive])}"

      {:ok, _} =
        ConnectionTracker.track_connection("c1-#{user_id}", %{user_id: user_id, type: :websocket})

      {:ok, _} =
        ConnectionTracker.track_connection("c2-#{user_id}", %{user_id: user_id, type: :http})

      {:ok, connections} = ConnectionTracker.get_user_connections(user_id)

      assert length(connections) == 2
      assert Enum.all?(connections, fn c -> c.user_id == user_id end)
    end

    test "returns {:ok, []} for user with no connections (Psi0)" do
      result =
        ConnectionTracker.get_user_connections(
          "nonexistent-user-#{:erlang.unique_integer([:positive])}"
        )

      assert {:ok, []} = result
    end

    test "does not return connections belonging to other users" do
      user_a = "user-a-iso-#{:erlang.unique_integer([:positive])}"
      user_b = "user-b-iso-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection("ca-1", %{user_id: user_a, type: :websocket})
      {:ok, _} = ConnectionTracker.track_connection("cb-1", %{user_id: user_b, type: :websocket})

      {:ok, user_a_conns} = ConnectionTracker.get_user_connections(user_a)

      assert length(user_a_conns) == 1
      assert hd(user_a_conns).user_id == user_a
    end
  end

  # ==========================================================================
  # update_connection/2
  # ==========================================================================

  describe "update_connection/2" do
    test "update_connection is a cast that does not crash (Psi0)" do
      conn_id = "conn-update-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection(conn_id, %{user_id: "user-upd", type: :http})

      # update_connection returns :ok (cast)
      result = ConnectionTracker.update_connection(conn_id, %{bytes_sent: 1024, status: :idle})
      assert result == :ok

      # wait for cast to process
      Process.sleep(50)

      {:ok, conn} = ConnectionTracker.get_connection(conn_id)
      assert conn.bytes_sent == 1024
      assert conn.status == :idle
    end

    test "update_connection on nonexistent connection does not crash" do
      result = ConnectionTracker.update_connection("ghost-conn-id", %{bytes_sent: 9999})
      assert result == :ok
    end
  end

  # ==========================================================================
  # untrack_connection/1
  # ==========================================================================

  describe "untrack_connection/1" do
    test "removes connection from tracking (cast, Psi0)" do
      conn_id = "conn-rm-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection(conn_id, %{user_id: "user-rm", type: :http})

      result = ConnectionTracker.untrack_connection(conn_id)
      assert result == :ok

      Process.sleep(50)

      assert {:error, :not_found} = ConnectionTracker.get_connection(conn_id)
    end

    test "untrack_connection on nonexistent id does not crash" do
      result = ConnectionTracker.untrack_connection("nonexistent-id-to-untrack")
      assert result == :ok
    end
  end

  # ==========================================================================
  # disconnect_user_connections/1
  # ==========================================================================

  describe "disconnect_user_connections/1" do
    test "returns {:ok, count} of disconnected connections (Psi3)" do
      user_id = "user-disc-#{:erlang.unique_integer([:positive])}"

      {:ok, _} =
        ConnectionTracker.track_connection("d1-#{user_id}", %{user_id: user_id, type: :websocket})

      {:ok, _} =
        ConnectionTracker.track_connection("d2-#{user_id}", %{user_id: user_id, type: :http})

      {:ok, _} =
        ConnectionTracker.track_connection("d3-#{user_id}", %{user_id: user_id, type: :websocket})

      result = ConnectionTracker.disconnect_user_connections(user_id)
      assert {:ok, 3} = result
    end

    test "returns {:ok, 0} for user with no connections (Psi0)" do
      result =
        ConnectionTracker.disconnect_user_connections(
          "nobody-#{:erlang.unique_integer([:positive])}"
        )

      assert {:ok, 0} = result
    end

    test "removes all user connections from tracking" do
      user_id = "user-clear-#{:erlang.unique_integer([:positive])}"

      {:ok, _} =
        ConnectionTracker.track_connection("e1-#{user_id}", %{user_id: user_id, type: :http})

      {:ok, _} =
        ConnectionTracker.track_connection("e2-#{user_id}", %{user_id: user_id, type: :websocket})

      {:ok, 2} = ConnectionTracker.disconnect_user_connections(user_id)

      {:ok, conns} = ConnectionTracker.get_user_connections(user_id)
      assert conns == []
    end

    test "does not disconnect connections belonging to other users" do
      user_a = "user-a-nd-#{:erlang.unique_integer([:positive])}"
      user_b = "user-b-nd-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection("fa1", %{user_id: user_a, type: :http})
      {:ok, _} = ConnectionTracker.track_connection("fb1", %{user_id: user_b, type: :http})

      ConnectionTracker.disconnect_user_connections(user_a)

      {:ok, b_conns} = ConnectionTracker.get_user_connections(user_b)
      assert length(b_conns) == 1
    end
  end

  # ==========================================================================
  # increment/1 and decrement/1
  # ==========================================================================

  describe "increment/1 and decrement/1" do
    test "increment returns integer count starting from 1 (Psi5)" do
      key = "count-key-#{:erlang.unique_integer([:positive])}"
      result = ConnectionTracker.increment(key)
      assert is_integer(result)
      assert result == 1
    end

    test "increment increments by 1 each call" do
      key = "count-inc-#{:erlang.unique_integer([:positive])}"

      assert 1 = ConnectionTracker.increment(key)
      assert 2 = ConnectionTracker.increment(key)
      assert 3 = ConnectionTracker.increment(key)
    end

    test "decrement returns :ok (Psi0 - async cast)" do
      key = "count-dec-#{:erlang.unique_integer([:positive])}"
      ConnectionTracker.increment(key)
      result = ConnectionTracker.decrement(key)
      assert result == :ok
    end

    test "decrement reduces count by 1" do
      key = "count-balance-#{:erlang.unique_integer([:positive])}"

      ConnectionTracker.increment(key)
      ConnectionTracker.increment(key)
      ConnectionTracker.increment(key)
      ConnectionTracker.decrement(key)
      # Wait for cast
      Process.sleep(50)

      # After 3 increments, 1 decrement, next increment should be 3 (not 4)
      result = ConnectionTracker.increment(key)
      assert result == 3
    end

    test "decrement at zero does not go negative (Psi5)" do
      key = "count-floor-#{:erlang.unique_integer([:positive])}"

      # Decrement a key that was never incremented
      ConnectionTracker.decrement(key)
      Process.sleep(50)

      # First increment should be 1, proving floor is 0
      result = ConnectionTracker.increment(key)
      assert result == 1
    end

    test "different keys maintain independent counts" do
      key_a = "key-a-#{:erlang.unique_integer([:positive])}"
      key_b = "key-b-#{:erlang.unique_integer([:positive])}"

      ConnectionTracker.increment(key_a)
      ConnectionTracker.increment(key_a)
      ConnectionTracker.increment(key_b)

      assert 3 = ConnectionTracker.increment(key_a)
      assert 2 = ConnectionTracker.increment(key_b)
    end

    test "decrement to 0 removes key — next increment starts at 1" do
      key = "count-remove-#{:erlang.unique_integer([:positive])}"

      ConnectionTracker.increment(key)
      ConnectionTracker.decrement(key)
      Process.sleep(50)

      # After hitting 0, key removed; next increment starts from 1
      assert 1 = ConnectionTracker.increment(key)
    end
  end

  # ==========================================================================
  # get_connection_stats/0
  # ==========================================================================

  describe "get_connection_stats/0" do
    test "returns {:ok, stats_map} (Psi3)" do
      result = ConnectionTracker.get_connection_stats()
      assert {:ok, stats} = result
      assert is_map(stats)
    end

    test "stats include active_connections key" do
      {:ok, stats} = ConnectionTracker.get_connection_stats()
      assert Map.has_key?(stats, :active_connections)
      assert is_integer(stats.active_connections)
    end

    test "stats include uptime_seconds key" do
      {:ok, stats} = ConnectionTracker.get_connection_stats()
      assert Map.has_key?(stats, :uptime_seconds)
      assert is_integer(stats.uptime_seconds)
      assert stats.uptime_seconds >= 0
    end

    test "stats include connections_by_type key" do
      {:ok, stats} = ConnectionTracker.get_connection_stats()
      assert Map.has_key?(stats, :connections_by_type)
      assert is_map(stats.connections_by_type)
    end

    test "stats include total_connections key" do
      {:ok, stats} = ConnectionTracker.get_connection_stats()
      assert Map.has_key?(stats, :total_connections)
      assert is_integer(stats.total_connections)
    end

    test "active_connections reflects tracked connections" do
      {:ok, initial} = ConnectionTracker.get_connection_stats()
      initial_count = initial.active_connections

      user_id = "user-stat-#{:erlang.unique_integer([:positive])}"
      ConnectionTracker.track_connection("stat-c1", %{user_id: user_id, type: :websocket})
      ConnectionTracker.track_connection("stat-c2", %{user_id: user_id, type: :http})

      {:ok, after_stats} = ConnectionTracker.get_connection_stats()
      assert after_stats.active_connections == initial_count + 2
    end

    test "connections_by_type reflects connection types" do
      user_id = "user-type-#{:erlang.unique_integer([:positive])}"
      ConnectionTracker.track_connection("type-ws-1", %{user_id: user_id, type: :websocket})
      ConnectionTracker.track_connection("type-ws-2", %{user_id: user_id, type: :websocket})
      ConnectionTracker.track_connection("type-http-1", %{user_id: user_id, type: :http})

      {:ok, stats} = ConnectionTracker.get_connection_stats()
      by_type = stats.connections_by_type

      assert Map.get(by_type, :websocket, 0) >= 2
      assert Map.get(by_type, :http, 0) >= 1
    end
  end

  # ==========================================================================
  # get_realtime_metrics/0
  # ==========================================================================

  describe "get_realtime_metrics/0" do
    test "returns {:ok, metrics_map} (Psi3)" do
      result = ConnectionTracker.get_realtime_metrics()
      assert {:ok, metrics} = result
      assert is_map(metrics)
    end

    test "metrics include timestamp key" do
      {:ok, metrics} = ConnectionTracker.get_realtime_metrics()
      assert Map.has_key?(metrics, :timestamp)
      assert %DateTime{} = metrics.timestamp
    end

    test "metrics include active_connections key" do
      {:ok, metrics} = ConnectionTracker.get_realtime_metrics()
      assert Map.has_key?(metrics, :active_connections)
      assert is_integer(metrics.active_connections)
      assert metrics.active_connections >= 0
    end

    test "metrics include memory_usage key" do
      {:ok, metrics} = ConnectionTracker.get_realtime_metrics()
      assert Map.has_key?(metrics, :memory_usage)
      assert is_integer(metrics.memory_usage)
      assert metrics.memory_usage > 0
    end

    test "metrics include process_count key" do
      {:ok, metrics} = ConnectionTracker.get_realtime_metrics()
      assert Map.has_key?(metrics, :process_count)
      assert is_integer(metrics.process_count)
      assert metrics.process_count > 0
    end
  end

  # ==========================================================================
  # get_connection_analytics/1
  # ==========================================================================

  describe "get_connection_analytics/1" do
    test "returns {:ok, analytics_map} with default filters (Psi0)" do
      result = ConnectionTracker.get_connection_analytics()
      assert {:ok, analytics} = result
      assert is_map(analytics)
    end

    test "analytics include timeframe key" do
      {:ok, analytics} = ConnectionTracker.get_connection_analytics()
      assert Map.has_key?(analytics, :timeframe)
      assert analytics.timeframe == :last_hour
    end

    test "analytics include generated_at timestamp" do
      {:ok, analytics} = ConnectionTracker.get_connection_analytics()
      assert Map.has_key?(analytics, :generated_at)
      assert %DateTime{} = analytics.generated_at
    end

    test "analytics include analytics nested map" do
      {:ok, analytics} = ConnectionTracker.get_connection_analytics()
      assert Map.has_key?(analytics, :analytics)
      assert is_map(analytics.analytics)
    end

    test "accepts custom timeframe filter" do
      result = ConnectionTracker.get_connection_analytics(%{timeframe: :last_24_hours})
      assert {:ok, analytics} = result
      assert analytics.timeframe == :last_24_hours
    end

    test "empty filter map uses defaults" do
      {:ok, analytics} = ConnectionTracker.get_connection_analytics(%{})
      assert analytics.timeframe == :last_hour
    end
  end

  # ==========================================================================
  # PropCheck Property Tests
  # ==========================================================================

  property "increment always returns a positive integer (Psi5)" do
    forall key <- PC.non_empty(PC.utf8()) do
      result = ConnectionTracker.increment(key)
      is_integer(result) and result > 0
    end
  end

  property "track_connection with any connection_id returns ok or max_exceeded error" do
    forall {conn_id, user_id} <- {PC.non_empty(PC.utf8()), PC.non_empty(PC.utf8())} do
      result = ConnectionTracker.track_connection(conn_id, %{user_id: user_id, type: :http})

      case result do
        {:ok, ^conn_id} -> true
        {:error, :max_connections_exceeded} -> true
        _ -> false
      end
    end
  end

  property "get_connection_stats always returns {:ok, map} (Psi3)" do
    forall _ <- PC.boolean() do
      case ConnectionTracker.get_connection_stats() do
        {:ok, stats} -> is_map(stats)
        _ -> false
      end
    end
  end

  property "get_connection for any string returns ok or not_found (Psi0)" do
    forall conn_id <- PC.non_empty(PC.utf8()) do
      case ConnectionTracker.get_connection(conn_id) do
        {:ok, conn} when is_map(conn) -> true
        {:error, :not_found} -> true
        _ -> false
      end
    end
  end

  property "disconnect_user_connections always returns {:ok, non_neg_integer} (Psi0)" do
    forall user_id <- PC.non_empty(PC.utf8()) do
      case ConnectionTracker.disconnect_user_connections(user_id) do
        {:ok, count} when is_integer(count) and count >= 0 -> true
        _ -> false
      end
    end
  end

  # ==========================================================================
  # ExUnitProperties Tests
  # ==========================================================================

  test "track and retrieve connection preserves connection_id field" do
    ExUnitProperties.check all(
                             conn_id <- SD.string(:alphanumeric, min_length: 1, max_length: 50),
                             user_id <- SD.string(:alphanumeric, min_length: 1, max_length: 36),
                             conn_type <- SD.member_of([:websocket, :http, :longpoll])
                           ) do
      info = %{user_id: "chk-#{user_id}", type: conn_type}
      unique_id = "chk-#{conn_id}-#{:erlang.unique_integer([:positive])}"

      case ConnectionTracker.track_connection(unique_id, info) do
        {:ok, _} ->
          {:ok, conn} = ConnectionTracker.get_connection(unique_id)
          assert conn.connection_id == unique_id

        {:error, :max_connections_exceeded} ->
          # Acceptable outcome when user is at limit
          true
      end
    end
  end

  test "update_rate_limit is a cast returning :ok for any connection_id" do
    ExUnitProperties.check all(conn_id <- SD.string(:alphanumeric, min_length: 1, max_length: 50)) do
      result = ConnectionTracker.update_connection(conn_id, %{bytes_sent: 0})
      assert result == :ok
    end
  end

  test "decrement returns :ok for any key regardless of state" do
    ExUnitProperties.check all(key <- SD.string(:alphanumeric, min_length: 1, max_length: 50)) do
      result = ConnectionTracker.decrement("sd-#{key}")
      assert result == :ok
    end
  end

  test "get_user_connections always returns {:ok, list}" do
    ExUnitProperties.check all(user_id <- SD.string(:alphanumeric, min_length: 1, max_length: 36)) do
      case ConnectionTracker.get_user_connections("sd-user-#{user_id}") do
        {:ok, list} -> assert is_list(list)
        _ -> flunk("Expected {:ok, list}")
      end
    end
  end

  # ==========================================================================
  # SIL-6 Safety Tests
  # ==========================================================================

  describe "SIL-6 Requirements" do
    test "Psi0 existence: ConnectionTracker exports required callbacks" do
      assert function_exported?(ConnectionTracker, :start_link, 1)
      assert function_exported?(ConnectionTracker, :track_connection, 2)
      assert function_exported?(ConnectionTracker, :get_connection, 1)
      assert function_exported?(ConnectionTracker, :get_user_connections, 1)
      assert function_exported?(ConnectionTracker, :get_connection_stats, 0)
      assert function_exported?(ConnectionTracker, :get_realtime_metrics, 0)
      assert function_exported?(ConnectionTracker, :disconnect_user_connections, 1)
      assert function_exported?(ConnectionTracker, :increment, 1)
      assert function_exported?(ConnectionTracker, :decrement, 1)
    end

    test "concurrent increments are linearizable (Psi5)" do
      key = "sil4-concurrent-#{:erlang.unique_integer([:positive])}"

      tasks =
        Enum.map(1..10, fn _ ->
          Task.async(fn -> ConnectionTracker.increment(key) end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 5_000))

      # All results must be integers 1..10 (unique, monotonically increasing set)
      assert Enum.all?(results, &is_integer/1)
      assert Enum.all?(results, &(&1 > 0))
      assert length(Enum.uniq(results)) == 10
      assert Enum.max(results) == 10
    end

    test "concurrent track_connection for same user enforces limit" do
      user_id = "sil4-user-#{:erlang.unique_integer([:positive])}"

      tasks =
        Enum.map(1..15, fn i ->
          Task.async(fn ->
            ConnectionTracker.track_connection("sil4-c#{i}-#{user_id}", %{
              user_id: user_id,
              type: :websocket
            })
          end)
        end)

      results = Enum.map(tasks, &Task.await(&1, 5_000))

      ok_count = Enum.count(results, fn r -> match?({:ok, _}, r) end)
      err_count = Enum.count(results, fn r -> match?({:error, :max_connections_exceeded}, r) end)

      # No more than 10 should succeed
      assert ok_count <= 10
      assert ok_count + err_count == 15
    end

    test "GenServer survives rapid cast/call interleaving (Psi0)" do
      user_id = "sil4-chaos-#{:erlang.unique_integer([:positive])}"

      # Mix of calls and casts
      Enum.each(1..5, fn i ->
        ConnectionTracker.track_connection("chaos-#{i}", %{user_id: user_id, type: :http})
        ConnectionTracker.update_connection("chaos-#{i}", %{bytes_sent: i * 100})
        ConnectionTracker.increment("chaos-key")
        ConnectionTracker.decrement("chaos-key")
      end)

      # GenServer must still be alive and responsive
      assert {:ok, stats} = ConnectionTracker.get_connection_stats()
      assert is_integer(stats.active_connections)
    end

    test "connection tracker process is alive after test setup (Psi0)" do
      pid = Process.whereis(ConnectionTracker)
      assert pid != nil
      assert Process.alive?(pid)
    end
  end

  # ==========================================================================
  # FMEA Critical Paths
  # ==========================================================================

  describe "FMEA Critical Paths" do
    @tag :fmea
    test "FMEA-CT-001: track_connection with nil user_id does not crash (Psi0)" do
      result =
        ConnectionTracker.track_connection("anon-#{:erlang.unique_integer([:positive])}", %{
          user_id: nil,
          type: :http
        })

      case result do
        {:ok, _} -> assert true
        {:error, _} -> assert true
      end
    end

    @tag :fmea
    test "FMEA-CT-002: track_connection with empty info map does not crash" do
      conn_id = "empty-info-#{:erlang.unique_integer([:positive])}"
      result = ConnectionTracker.track_connection(conn_id, %{})

      case result do
        {:ok, _} ->
          # Connection created with defaults; user_id nil skips limit check
          assert true

        {:error, _} ->
          assert true
      end
    end

    @tag :fmea
    test "FMEA-CT-003: get_connection with very long connection_id does not crash" do
      long_id = String.duplicate("x", 256)
      result = ConnectionTracker.get_connection(long_id)
      assert {:error, :not_found} = result
    end

    @tag :fmea
    test "FMEA-CT-004: get_connection_stats is always ok (Psi3 — never returns error)" do
      # Even with no connections, stats is always {:ok, map}
      {:ok, stats} = ConnectionTracker.get_connection_stats()
      assert stats.active_connections == 0
      assert stats.uptime_seconds >= 0
    end

    @tag :fmea
    test "FMEA-CT-005: get_realtime_metrics is always ok (Psi3)" do
      {:ok, metrics} = ConnectionTracker.get_realtime_metrics()
      assert is_integer(metrics.active_connections)
      assert is_integer(metrics.memory_usage)
    end

    @tag :fmea
    test "FMEA-CT-006: increment after decrement to zero starts from 1 again (Psi5)" do
      key = "fmea-floor-#{:erlang.unique_integer([:positive])}"

      assert 1 = ConnectionTracker.increment(key)
      ConnectionTracker.decrement(key)
      Process.sleep(50)

      # Key removed; fresh increment
      assert 1 = ConnectionTracker.increment(key)
    end

    @tag :fmea
    test "FMEA-CT-007: disconnect_user_connections is idempotent" do
      user_id = "fmea-idemp-#{:erlang.unique_integer([:positive])}"

      {:ok, _} = ConnectionTracker.track_connection("fmea-c1", %{user_id: user_id, type: :http})
      {:ok, 1} = ConnectionTracker.disconnect_user_connections(user_id)

      # Second call returns 0 — no crash
      {:ok, 0} = ConnectionTracker.disconnect_user_connections(user_id)
    end

    @tag :fmea
    test "FMEA-CT-008: update_connection on ghost id returns :ok (cast, not error)" do
      # cast-based; always returns :ok even for nonexistent connections
      result =
        ConnectionTracker.update_connection("ghost-id-#{:erlang.unique_integer([:positive])}", %{
          bytes_sent: 42
        })

      assert result == :ok
    end

    @tag :fmea
    test "FMEA-CT-009: cleanup_connections message does not crash server" do
      pid = Process.whereis(ConnectionTracker)
      assert pid != nil

      send(pid, :cleanup_connections)
      Process.sleep(100)

      # Server still alive
      assert Process.alive?(pid)
      assert {:ok, _} = ConnectionTracker.get_connection_stats()
    end

    @tag :fmea
    test "FMEA-CT-010: max connections error message is :max_connections_exceeded atom" do
      user_id = "fmea-max-#{:erlang.unique_integer([:positive])}"

      Enum.each(1..10, fn i ->
        ConnectionTracker.track_connection("fmea-m#{i}-#{user_id}", %{
          user_id: user_id,
          type: :websocket
        })
      end)

      {:error, reason} =
        ConnectionTracker.track_connection("fmea-m11-#{user_id}", %{
          user_id: user_id,
          type: :websocket
        })

      assert reason == :max_connections_exceeded
      assert is_atom(reason)
    end
  end
end
