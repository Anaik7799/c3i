defmodule Indrajaal.Cortex.Evolution.TrainingGymTest do
  @moduledoc """
  Tests for Training GYM Data Capture.

  WHAT: Validates RL training data capture and episode management.
  WHY: SC-TRAIN-001 to SC-TRAIN-004 require systematic episode capture.
  CONSTRAINTS: Must not impact production performance (async only).
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Cortex.Evolution.TrainingGym
  alias Indrajaal.Safety.Guardian

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Ensure Guardian is running (start if not, use existing if already running)
    guardian_pid =
      case GenServer.whereis(Guardian) do
        nil ->
          {:ok, pid} = Guardian.start_link()
          pid

        existing_pid ->
          existing_pid
      end

    # Stop any existing TrainingGym and start fresh for each test
    case GenServer.whereis(TrainingGym) do
      nil ->
        :ok

      pid ->
        try do
          GenServer.stop(pid, :normal, 5000)
        catch
          :exit, _ -> :ok
        end
    end

    # Small delay to ensure stop completes
    Process.sleep(10)

    {:ok, gym_pid} = TrainingGym.start_link()

    on_exit(fn ->
      # Only stop TrainingGym on exit (Guardian is shared across tests)
      case GenServer.whereis(TrainingGym) do
        nil ->
          :ok

        pid ->
          try do
            GenServer.stop(pid, :normal, 5000)
          catch
            :exit, _ -> :ok
          end
      end
    end)

    %{gym: gym_pid, guardian: guardian_pid}
  end

  # ============================================================
  # RECORDING TESTS
  # ============================================================

  describe "record_near_miss/3" do
    test "records Guardian veto as near-miss", _ctx do
      state_before = %{alarm_active: true, door_locked: false}
      action = %{action: :unlock_door, force: true}
      veto_reason = %{reason: :safety_violation, constraint: "SC-SEC-001"}

      # Record should be async and return immediately
      assert :ok = TrainingGym.record_near_miss(state_before, action, veto_reason)

      # Give async operation time to complete
      :timer.sleep(50)

      # Verify it was recorded
      stats = TrainingGym.stats()
      assert stats.near_miss_count == 1
    end

    test "assigns negative reward to near-misses", _ctx do
      TrainingGym.record_near_miss(%{}, %{action: :test}, %{reason: :test})
      :timer.sleep(50)

      episodes = TrainingGym.get_episodes(1)
      assert length(episodes) == 1

      [episode] = episodes
      assert episode.type == :near_miss
      assert episode.reward < 0
    end
  end

  describe "record_success/3" do
    test "records successful action", _ctx do
      state_before = %{sensor: :normal}
      action = %{action: :arm_system}
      result = %{success: true, new_state: :armed}

      assert :ok = TrainingGym.record_success(state_before, action, result)
      :timer.sleep(50)

      stats = TrainingGym.stats()
      assert stats.success_count == 1
    end

    test "assigns positive reward to successes", _ctx do
      TrainingGym.record_success(%{}, %{action: :test}, %{success: true})
      :timer.sleep(50)

      episodes = TrainingGym.get_episodes(1)
      [episode] = episodes
      assert episode.type == :success
      assert episode.reward > 0
    end
  end

  describe "record_shadow_diverge/4" do
    test "records shadow model divergence", _ctx do
      model_id = "test-model-001"
      context = %{sensor: :alarm}
      production_action = %{action: :lock}
      shadow_action = %{action: :unlock}

      assert :ok =
               TrainingGym.record_shadow_diverge(
                 model_id,
                 context,
                 production_action,
                 shadow_action
               )

      :timer.sleep(50)

      stats = TrainingGym.stats()
      assert stats.shadow_diverge_count == 1
    end
  end

  describe "record_shadow_agree/3" do
    test "records shadow model agreement", _ctx do
      model_id = "test-model-002"
      context = %{sensor: :normal}
      action = %{action: :monitor}

      assert :ok = TrainingGym.record_shadow_agree(model_id, context, action)
      :timer.sleep(50)

      stats = TrainingGym.stats()
      assert stats.shadow_agree_count == 1
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0" do
    test "returns comprehensive statistics", _ctx do
      stats = TrainingGym.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :episode_count)
      assert Map.has_key?(stats, :near_miss_count)
      assert Map.has_key?(stats, :success_count)
      assert Map.has_key?(stats, :shadow_diverge_count)
      assert Map.has_key?(stats, :shadow_agree_count)
      assert Map.has_key?(stats, :buffer_size)
      assert Map.has_key?(stats, :buffer_utilization)
      assert Map.has_key?(stats, :reward_balance)
    end

    test "calculates reward balance correctly", _ctx do
      # Record mixed episodes
      TrainingGym.record_success(%{}, %{}, %{})
      TrainingGym.record_success(%{}, %{}, %{})
      TrainingGym.record_near_miss(%{}, %{}, %{})
      :timer.sleep(100)

      stats = TrainingGym.stats()

      # 2 successes (+2.0) + 1 near_miss (-1.0) = +1.0
      assert stats.reward_balance > 0
    end
  end

  # ============================================================
  # EPISODE RETRIEVAL TESTS
  # ============================================================

  describe "get_episodes/1" do
    test "returns episodes up to limit", _ctx do
      # Record 5 episodes
      for i <- 1..5 do
        TrainingGym.record_success(%{i: i}, %{action: i}, %{})
      end

      :timer.sleep(100)

      episodes = TrainingGym.get_episodes(3)
      assert length(episodes) == 3
    end

    test "episodes have required fields", _ctx do
      TrainingGym.record_success(%{state: :test}, %{action: :test}, %{result: :ok})
      :timer.sleep(50)

      [episode] = TrainingGym.get_episodes(1)

      assert Map.has_key?(episode, :id)
      assert Map.has_key?(episode, :type)
      assert Map.has_key?(episode, :timestamp)
      assert Map.has_key?(episode, :context)
      assert Map.has_key?(episode, :state_before)
      assert Map.has_key?(episode, :action)
      assert Map.has_key?(episode, :result)
      assert Map.has_key?(episode, :reward)
      assert Map.has_key?(episode, :metadata)
    end

    test "episode IDs are unique", _ctx do
      for _ <- 1..10 do
        TrainingGym.record_success(%{}, %{}, %{})
      end

      :timer.sleep(100)

      episodes = TrainingGym.get_episodes(10)
      ids = Enum.map(episodes, & &1.id)

      assert length(Enum.uniq(ids)) == length(ids)
    end
  end

  # ============================================================
  # FLUSH TESTS
  # ============================================================

  describe "flush/0" do
    test "flushes episodes and returns count", _ctx do
      for _ <- 1..5 do
        TrainingGym.record_success(%{}, %{}, %{})
      end

      :timer.sleep(100)

      {:ok, count} = TrainingGym.flush()

      assert count == 5
    end

    test "clears buffer after flush", _ctx do
      TrainingGym.record_success(%{}, %{}, %{})
      :timer.sleep(50)

      TrainingGym.flush()

      stats = TrainingGym.stats()
      assert stats.buffer_size == 0
    end

    test "returns 0 when buffer empty", _ctx do
      {:ok, count} = TrainingGym.flush()
      assert count == 0
    end
  end

  # ============================================================
  # EXPORT TESTS
  # ============================================================

  describe "export_training_data/1" do
    test "exports all episodes in RL format", _ctx do
      TrainingGym.record_success(%{state: :a}, %{action: :b}, %{})
      TrainingGym.record_near_miss(%{state: :c}, %{action: :d}, %{reason: :e})
      :timer.sleep(100)

      {:ok, data} = TrainingGym.export_training_data()

      assert length(data) == 2

      Enum.each(data, fn item ->
        assert Map.has_key?(item, :observation)
        assert Map.has_key?(item, :action)
        assert Map.has_key?(item, :reward)
        assert Map.has_key?(item, :done)
        assert Map.has_key?(item, :info)
      end)
    end

    test "filters by episode type", _ctx do
      TrainingGym.record_success(%{}, %{}, %{})
      TrainingGym.record_near_miss(%{}, %{}, %{})
      TrainingGym.record_success(%{}, %{}, %{})
      :timer.sleep(100)

      {:ok, data} = TrainingGym.export_training_data(type: :success)

      assert length(data) == 2
    end

    test "filters by minimum reward", _ctx do
      TrainingGym.record_success(%{}, %{}, %{})
      TrainingGym.record_near_miss(%{}, %{}, %{})
      :timer.sleep(100)

      {:ok, data} = TrainingGym.export_training_data(min_reward: 0.0)

      assert length(data) == 1
    end
  end

  # ============================================================
  # SUBSCRIPTION TESTS
  # ============================================================

  describe "subscribe/0 and unsubscribe/0" do
    test "receives episode notifications when subscribed", _ctx do
      TrainingGym.subscribe()

      TrainingGym.record_success(%{test: true}, %{action: :notify}, %{})
      :timer.sleep(50)

      assert_receive {:training_gym_episode, episode}
      assert episode.type == :success

      TrainingGym.unsubscribe()
    end

    test "stops receiving after unsubscribe", _ctx do
      TrainingGym.subscribe()
      TrainingGym.unsubscribe()

      TrainingGym.record_success(%{}, %{}, %{})
      :timer.sleep(50)

      refute_receive {:training_gym_episode, _}
    end
  end

  # ============================================================
  # PII ANONYMIZATION TESTS
  # ============================================================

  describe "PII anonymization (SC-TRAIN-004)" do
    test "redacts email fields", _ctx do
      state_with_pii = %{
        user: %{
          name: "Test User",
          email: "test@example.com",
          phone: "555-1234"
        }
      }

      TrainingGym.record_success(state_with_pii, %{}, %{})
      :timer.sleep(50)

      [episode] = TrainingGym.get_episodes(1)

      # Email and phone should be redacted
      assert episode.state_before.user.email == "[REDACTED]"
      assert episode.state_before.user.phone == "[REDACTED]"
      # Name should be preserved
      assert episode.state_before.user.name == "Test User"
    end

    test "removes sensitive keys completely", _ctx do
      state_with_secrets = %{
        password: "secret123",
        api_key: "key_abc",
        data: "safe_data"
      }

      TrainingGym.record_success(state_with_secrets, %{}, %{})
      :timer.sleep(50)

      [episode] = TrainingGym.get_episodes(1)

      # Sensitive keys should be dropped
      refute Map.has_key?(episode.state_before, :password)
      refute Map.has_key?(episode.state_before, :api_key)
      # Safe data preserved
      assert episode.state_before.data == "safe_data"
    end
  end

  # ============================================================
  # BUFFER LIMIT TESTS
  # ============================================================

  describe "buffer management (SC-TRAIN-002)" do
    test "buffer utilization is tracked", _ctx do
      stats = TrainingGym.stats()
      assert is_float(stats.buffer_utilization)
      assert stats.buffer_utilization >= 0
      assert stats.buffer_utilization <= 100
    end
  end

  # ============================================================
  # CONTEXT CAPTURE TESTS
  # ============================================================

  describe "context capture" do
    test "captures system context with each episode", _ctx do
      TrainingGym.record_success(%{}, %{}, %{})
      :timer.sleep(50)

      [episode] = TrainingGym.get_episodes(1)

      assert is_map(episode.context)
      assert Map.has_key?(episode.context, :memory_mb)
      assert Map.has_key?(episode.context, :process_count)
      assert is_integer(episode.context.memory_mb)
    end

    test "includes guardian status in metadata", _ctx do
      TrainingGym.record_success(%{}, %{}, %{})
      :timer.sleep(50)

      [episode] = TrainingGym.get_episodes(1)

      assert Map.has_key?(episode.metadata, :guardian_running)
      assert episode.metadata.guardian_running == true
    end
  end
end
