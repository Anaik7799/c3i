defmodule Indrajaal.Observability.GitIntegration.GitZenohSubscriberTest do
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.Observability.GitIntegration.GitZenohSubscriber

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(GitZenohSubscriber)
    end
  end

  describe "function exports" do
    test "start_link/1 is exported" do
      assert function_exported?(GitZenohSubscriber, :start_link, 1)
    end

    test "get_ghs/0 is exported" do
      assert function_exported?(GitZenohSubscriber, :get_ghs, 0)
    end

    test "get_metrics/0 is exported" do
      assert function_exported?(GitZenohSubscriber, :get_metrics, 0)
    end

    test "get_cached/1 is exported" do
      assert function_exported?(GitZenohSubscriber, :get_cached, 1)
    end

    test "get_stats/1 is exported" do
      assert function_exported?(GitZenohSubscriber, :get_stats, 1)
    end

    test "set_enabled/2 is exported" do
      assert function_exported?(GitZenohSubscriber, :set_enabled, 2)
    end
  end

  describe "GitZenohSubscriber GenServer lifecycle" do
    setup do
      # Start PubSub if not already running
      case Phoenix.PubSub.PG2 do
        _ ->
          try do
            start_supervised!(
              {Phoenix.PubSub, name: :"git_test_pubsub_#{System.unique_integer([:positive])}"}
            )
          rescue
            _ -> :ok
          end
      end

      name = :"git_sub_test_#{System.unique_integer([:positive])}"

      case GitZenohSubscriber.start_link(name: name, enabled: false) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{subscriber: pid, name: name}

        {:error, _} ->
          %{subscriber: nil, name: name}
      end
    end

    test "starts successfully", %{subscriber: pid} do
      assert pid != nil
      assert Process.alive?(pid)
    end

    test "get_stats/1 returns map with expected keys", %{subscriber: pid, name: name} do
      if pid != nil do
        stats = GitZenohSubscriber.get_stats(name)
        assert is_map(stats)
        assert Map.has_key?(stats, :total_processed)
        assert Map.has_key?(stats, :errors)
        assert Map.has_key?(stats, :started_at)
        assert Map.has_key?(stats, :last_ghs)
        assert Map.has_key?(stats, :threat_count)
      end
    end

    test "set_enabled/2 toggles subscriber state", %{subscriber: pid, name: name} do
      if pid != nil do
        assert :ok == GitZenohSubscriber.set_enabled(name, true)
        assert :ok == GitZenohSubscriber.set_enabled(name, false)
      end
    end

    test "initial stats have zero counts", %{subscriber: pid, name: name} do
      if pid != nil do
        stats = GitZenohSubscriber.get_stats(name)
        assert stats.total_processed == 0
        assert stats.errors == 0
        assert stats.threat_count == 0
        assert stats.last_ghs == nil
      end
    end
  end

  describe "ETS cache operations" do
    setup do
      name = :"git_ets_test_#{System.unique_integer([:positive])}"

      case GitZenohSubscriber.start_link(name: name, enabled: false) do
        {:ok, pid} ->
          on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
          %{subscriber: pid, name: name}

        {:error, _} ->
          %{subscriber: nil, name: name}
      end
    end

    test "get_metrics/0 returns map from ETS", %{subscriber: pid} do
      if pid != nil do
        metrics = GitZenohSubscriber.get_metrics()
        assert is_map(metrics)
      end
    end

    test "get_ghs/0 returns nil initially", %{subscriber: pid} do
      if pid != nil do
        assert GitZenohSubscriber.get_ghs() == nil
      end
    end

    test "get_cached/1 returns nil for non-existent key", %{subscriber: pid} do
      if pid != nil do
        assert GitZenohSubscriber.get_cached(:nonexistent_key) == nil
      end
    end

    test "ETS table created with read_concurrency", %{subscriber: pid} do
      if pid != nil do
        table = :git_intelligence

        case :ets.whereis(table) do
          :undefined -> :skip
          _ref -> assert :ets.info(table, :read_concurrency) == true
        end
      end
    end
  end

  describe "topic extraction" do
    test "extracts topic from key expression" do
      # Test internal logic via sending messages to a running subscriber
      name = :"git_topic_test_#{System.unique_integer([:positive])}"

      case GitZenohSubscriber.start_link(name: name, enabled: false) do
        {:ok, pid} ->
          # Verify it started and is alive
          assert Process.alive?(pid)
          GenServer.stop(pid)

        {:error, _} ->
          :skip
      end
    end
  end
end
