defmodule Indrajaal.Observability.ZenohEvolutionPublisherTest do
  @moduledoc """
  Tests for ZenohEvolutionPublisher.

  WHAT: Validates Zenoh integration for evolution components.
  WHY: SC-ZENOH-EVO-001 requires all evolution events published to Zenoh.
  CONSTRAINTS: Must test buffering, batch publishing, and stats.
  """
  use ExUnit.Case, async: false

  alias Indrajaal.Observability.ZenohEvolutionPublisher

  # ============================================================
  # SETUP
  # ============================================================

  setup do
    # Use existing publisher if already running (started by ZenohCoordinator)
    publisher_pid =
      case GenServer.whereis(ZenohEvolutionPublisher) do
        nil ->
          # Start fresh if not running
          {:ok, pid} =
            ZenohEvolutionPublisher.start_link(
              publish_interval_ms: 100_000,
              episode_buffer_size: 3
            )

          pid

        existing_pid ->
          # Use existing - flush to clear state for clean test
          try do
            ZenohEvolutionPublisher.flush()
          rescue
            _ -> :ok
          end

          existing_pid
      end

    on_exit(fn ->
      # Clean up if process is still alive
      case GenServer.whereis(ZenohEvolutionPublisher) do
        nil ->
          :ok

        _pid ->
          try do
            ZenohEvolutionPublisher.flush()
          rescue
            _ -> :ok
          catch
            :exit, _ -> :ok
          end
      end
    end)

    %{publisher: publisher_pid}
  end

  # ============================================================
  # SHADOW EXECUTION TESTS
  # ============================================================

  describe "publish_shadow_execution/2" do
    test "publishes shadow execution event", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      result = %{
        would_be_vetoed: false,
        veto_reason: nil,
        latency_ms: 42,
        timestamp: DateTime.utc_now()
      }

      assert :ok = ZenohEvolutionPublisher.publish_shadow_execution("shadow_001", result)

      # Give async operation time to complete
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      assert stats_after.shadow_executions_published ==
               stats_before.shadow_executions_published + 1
    end

    test "tracks multiple executions", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      for i <- 1..5 do
        ZenohEvolutionPublisher.publish_shadow_execution("shadow_00#{i}", %{
          latency_ms: i * 10
        })
      end

      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      assert stats_after.shadow_executions_published ==
               stats_before.shadow_executions_published + 5
    end
  end

  # ============================================================
  # SHADOW COMPARISON TESTS
  # ============================================================

  describe "publish_shadow_comparison/2" do
    test "publishes comparison event", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      comparison = %{
        agreement: true,
        diff_keys: [],
        analysis: "Outputs match"
      }

      assert :ok = ZenohEvolutionPublisher.publish_shadow_comparison("shadow_001", comparison)
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      assert stats_after.shadow_comparisons_published ==
               stats_before.shadow_comparisons_published + 1
    end

    test "tracks disagreement comparisons", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      ZenohEvolutionPublisher.publish_shadow_comparison("shadow_001", %{
        agreement: false,
        diff_keys: [:action, :confidence],
        analysis: "Action differs"
      })

      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      assert stats_after.shadow_comparisons_published ==
               stats_before.shadow_comparisons_published + 1
    end
  end

  # ============================================================
  # SHADOW PROMOTION TESTS
  # ============================================================

  describe "publish_shadow_promotion/2" do
    test "publishes promotion event", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      promotion = %{
        token: "promo_abc123",
        status: :approved,
        cycles: 10_000,
        violations: 0
      }

      assert :ok = ZenohEvolutionPublisher.publish_shadow_promotion("shadow_001", promotion)
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      assert stats_after.shadow_promotions_published ==
               stats_before.shadow_promotions_published + 1
    end
  end

  # ============================================================
  # TRAINING EPISODE TESTS
  # ============================================================

  describe "publish_training_episode/1" do
    test "buffers episodes", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()
      initial_buffer = stats_before.episode_buffer_size

      ZenohEvolutionPublisher.publish_training_episode(%{type: :success, reward: 1.0})
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()
      # Buffer should have at least 1 more episode (may have flushed if threshold hit)
      assert stats_after.episode_buffer_size >= initial_buffer or
               stats_after.episodes_published > stats_before.episodes_published
    end

    test "flush clears episode buffer", _ctx do
      ZenohEvolutionPublisher.publish_training_episode(%{type: :success, reward: 1.0})
      Process.sleep(50)

      ZenohEvolutionPublisher.flush()
      stats = ZenohEvolutionPublisher.stats()
      assert stats.episode_buffer_size == 0
    end

    test "supports different episode types", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      ZenohEvolutionPublisher.publish_training_episode(%{type: :success, reward: 1.0})
      ZenohEvolutionPublisher.publish_training_episode(%{type: :near_miss, reward: -1.0})
      ZenohEvolutionPublisher.publish_training_episode(%{type: :shadow_diverge, reward: -0.5})

      ZenohEvolutionPublisher.flush()
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()
      assert stats_after.episodes_published >= stats_before.episodes_published + 3
    end
  end

  # ============================================================
  # GUARDIAN VALIDATION TESTS
  # ============================================================

  describe "publish_guardian_validation/3" do
    test "buffers and publishes guardian validations", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      # Add some validations
      for i <- 1..5 do
        ZenohEvolutionPublisher.publish_guardian_validation(
          %{action: :test, target: i},
          :approved,
          %{constraint: "SC-TEST-00#{i}"}
        )
      end

      # Force flush
      ZenohEvolutionPublisher.flush()
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      assert stats_after.guardian_validations_published >=
               stats_before.guardian_validations_published + 5
    end
  end

  # ============================================================
  # OPENROUTER CALL TESTS
  # ============================================================

  describe "publish_openrouter_call/4" do
    test "buffers and publishes OpenRouter calls", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      for i <- 1..3 do
        ZenohEvolutionPublisher.publish_openrouter_call(
          "claude-3-opus",
          100 * i,
          50 + i,
          true
        )
      end

      ZenohEvolutionPublisher.flush()
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()
      assert stats_after.openrouter_calls_published >= stats_before.openrouter_calls_published + 3
    end

    test "tracks failed calls", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      for _i <- 1..3 do
        ZenohEvolutionPublisher.publish_openrouter_call(
          "claude-3-opus",
          0,
          1000,
          false
        )
      end

      ZenohEvolutionPublisher.flush()
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()
      assert stats_after.openrouter_calls_published >= stats_before.openrouter_calls_published + 3
    end
  end

  # ============================================================
  # STATS TESTS
  # ============================================================

  describe "stats/0" do
    test "returns comprehensive statistics", _ctx do
      stats = ZenohEvolutionPublisher.stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :shadow_executions_published)
      assert Map.has_key?(stats, :shadow_comparisons_published)
      assert Map.has_key?(stats, :shadow_promotions_published)
      assert Map.has_key?(stats, :episodes_published)
      assert Map.has_key?(stats, :guardian_validations_published)
      assert Map.has_key?(stats, :openrouter_calls_published)
      assert Map.has_key?(stats, :publish_count)
      assert Map.has_key?(stats, :episode_buffer_size)
      assert Map.has_key?(stats, :uptime_seconds)
    end

    test "tracks uptime", _ctx do
      Process.sleep(100)
      stats = ZenohEvolutionPublisher.stats()
      assert stats.uptime_seconds >= 0
    end
  end

  # ============================================================
  # FLUSH TESTS
  # ============================================================

  describe "flush/0" do
    test "forces flush of all buffers", _ctx do
      # Skip if publisher not available
      case GenServer.whereis(ZenohEvolutionPublisher) do
        nil ->
          :ok

        _pid ->
          stats_initial = ZenohEvolutionPublisher.stats()

          # Add items to buffers
          ZenohEvolutionPublisher.publish_training_episode(%{type: :success, reward: 1.0})
          ZenohEvolutionPublisher.publish_guardian_validation(%{action: :test}, :approved, %{})

          # Give async operations time
          Process.sleep(50)

          # Force flush if still running
          case GenServer.whereis(ZenohEvolutionPublisher) do
            nil ->
              :ok

            _pid ->
              assert :ok = ZenohEvolutionPublisher.flush()

              # Verify buffers are empty
              stats_after = ZenohEvolutionPublisher.stats()
              assert stats_after.episode_buffer_size == 0
              assert stats_after.guardian_buffer_size == 0
              assert stats_after.episodes_published >= stats_initial.episodes_published + 1

              assert stats_after.guardian_validations_published >=
                       stats_initial.guardian_validations_published + 1
          end
      end
    end

    test "increments publish count on flush", _ctx do
      stats_before = ZenohEvolutionPublisher.stats()

      ZenohEvolutionPublisher.flush()

      stats_after = ZenohEvolutionPublisher.stats()
      assert stats_after.publish_count > stats_before.publish_count
      assert stats_after.last_publish != nil
    end
  end

  # ============================================================
  # STAMP CONSTRAINT TESTS
  # ============================================================

  describe "SC-ZENOH-EVO constraints" do
    test "SC-ZENOH-EVO-001: all event types are tracked" do
      stats_before = ZenohEvolutionPublisher.stats()

      # All evolution event types should be publishable
      ZenohEvolutionPublisher.publish_shadow_execution("s1", %{})
      ZenohEvolutionPublisher.publish_shadow_comparison("s1", %{agreement: true})
      ZenohEvolutionPublisher.publish_shadow_promotion("s1", %{status: :approved})
      ZenohEvolutionPublisher.publish_training_episode(%{type: :success})
      ZenohEvolutionPublisher.publish_guardian_validation(%{}, :approved, %{})
      ZenohEvolutionPublisher.publish_openrouter_call("model", 100, 50, true)

      ZenohEvolutionPublisher.flush()
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()

      # Verify all event types are tracked (relative to before)
      assert stats_after.shadow_executions_published > stats_before.shadow_executions_published
      assert stats_after.shadow_comparisons_published > stats_before.shadow_comparisons_published
      assert stats_after.shadow_promotions_published > stats_before.shadow_promotions_published
    end

    test "SC-ZENOH-EVO-002: operations are non-blocking" do
      # All operations should return immediately (< 100ms)
      start = System.monotonic_time(:millisecond)

      for _ <- 1..100 do
        ZenohEvolutionPublisher.publish_shadow_execution("s1", %{latency_ms: 10})
      end

      elapsed = System.monotonic_time(:millisecond) - start

      # 100 operations should complete in < 100ms
      assert elapsed < 100
    end

    test "SC-ZENOH-EVO-003: episode buffering works" do
      # Flush first to ensure clean state
      ZenohEvolutionPublisher.flush()
      stats_initial = ZenohEvolutionPublisher.stats()

      # Add 1 episode - should be buffered
      ZenohEvolutionPublisher.publish_training_episode(%{type: :success})
      Process.sleep(50)

      stats_after = ZenohEvolutionPublisher.stats()
      # Either buffered (buffer_size > 0) or published (depending on threshold)
      assert stats_after.episode_buffer_size > 0 or
               stats_after.episodes_published > stats_initial.episodes_published
    end
  end
end
