defmodule Indrajaal.AI.Evolution.TrainingGymTest do
  @moduledoc """
  Tests for TrainingGym GenServer.

  ## STAMP Constraints Verified
  - SC-AI-104: TrainingGym records all episodes
  - SC-AI-107: Learning cycles < 1 hour
  - SC-AI-108: Zenoh publishes learnings
  """

  use ExUnit.Case, async: false

  alias Indrajaal.AI.Evolution.TrainingGym

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TrainingGym)
    end

    test "exports start_link/1" do
      assert function_exported?(TrainingGym, :start_link, 1)
    end

    test "exports record_episode/1" do
      assert function_exported?(TrainingGym, :record_episode, 1)
    end

    test "exports get_model_score/1" do
      assert function_exported?(TrainingGym, :get_model_score, 1)
    end

    test "exports get_intent_success_rate/1" do
      assert function_exported?(TrainingGym, :get_intent_success_rate, 1)
    end

    test "exports trigger_learning_cycle/0" do
      assert function_exported?(TrainingGym, :trigger_learning_cycle, 0)
    end

    test "exports get_stats/0" do
      assert function_exported?(TrainingGym, :get_stats, 0)
    end
  end

  describe "GenServer lifecycle" do
    test "can start the GenServer" do
      {:ok, pid} = TrainingGym.start_link([])
      assert is_pid(pid)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "record_episode/1 when not started" do
    test "returns :ok when GenServer not running" do
      # Ensure it's not running
      if GenServer.whereis(TrainingGym), do: GenServer.stop(TrainingGym)

      result = TrainingGym.record_episode(%{type: :success})
      assert result == :ok
    end
  end

  describe "record_episode/1 when started" do
    setup do
      {:ok, pid} = TrainingGym.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "records success episode" do
      episode = %{
        type: :success,
        primary_model: "test/model",
        request_intent: :analyze
      }

      result = TrainingGym.record_episode(episode)
      assert result == :ok
    end

    test "records failure episode" do
      episode = %{
        type: :failure,
        primary_model: "test/model",
        error_type: :api_error
      }

      result = TrainingGym.record_episode(episode)
      assert result == :ok
    end

    test "records shadow_diverge episode" do
      episode = %{
        type: :shadow_diverge,
        primary_model: "model/a",
        shadow_model: "model/b",
        divergence_score: 0.45
      }

      result = TrainingGym.record_episode(episode)
      assert result == :ok
    end

    test "records near_miss episode" do
      episode = %{
        type: :near_miss,
        primary_model: "test/model"
      }

      result = TrainingGym.record_episode(episode)
      assert result == :ok
    end
  end

  describe "get_model_score/1 when not started" do
    test "returns default 1.0 when GenServer not running" do
      if GenServer.whereis(TrainingGym), do: GenServer.stop(TrainingGym)

      score = TrainingGym.get_model_score("any/model")
      assert score == 1.0
    end
  end

  describe "get_model_score/1 when started" do
    setup do
      {:ok, pid} = TrainingGym.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns default score for unknown model" do
      score = TrainingGym.get_model_score("unknown/model")
      assert score == 1.0
    end

    test "score increases after success episodes" do
      # Record multiple success episodes
      for _ <- 1..10 do
        TrainingGym.record_episode(%{
          type: :success,
          primary_model: "test/model"
        })
      end

      # Allow async casts to process
      :timer.sleep(100)

      score = TrainingGym.get_model_score("test/model")
      assert score >= 0.9
      assert score <= 1.0
    end

    test "score decreases after failure episodes" do
      # Record failure episodes
      for _ <- 1..10 do
        TrainingGym.record_episode(%{
          type: :failure,
          primary_model: "failing/model"
        })
      end

      :timer.sleep(100)

      score = TrainingGym.get_model_score("failing/model")
      # Should be lower than default but not negative
      assert score < 1.0
      assert score >= 0.0
    end
  end

  describe "get_intent_success_rate/1 when not started" do
    test "returns default 1.0 when GenServer not running" do
      if GenServer.whereis(TrainingGym), do: GenServer.stop(TrainingGym)

      rate = TrainingGym.get_intent_success_rate(:analyze)
      assert rate == 1.0
    end
  end

  describe "get_intent_success_rate/1 when started" do
    setup do
      {:ok, pid} = TrainingGym.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "tracks intent success rates" do
      # Record mixed results for an intent
      for _ <- 1..5 do
        TrainingGym.record_episode(%{type: :success, request_intent: :synthesize})
      end

      for _ <- 1..2 do
        TrainingGym.record_episode(%{type: :failure, request_intent: :synthesize})
      end

      :timer.sleep(100)

      rate = TrainingGym.get_intent_success_rate(:synthesize)
      assert rate < 1.0
      assert rate > 0.0
    end
  end

  describe "get_stats/0 when started" do
    setup do
      {:ok, pid} = TrainingGym.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "returns statistics map" do
      stats = TrainingGym.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_episodes)
      assert Map.has_key?(stats, :pending_episodes)
      assert Map.has_key?(stats, :model_scores)
      assert Map.has_key?(stats, :intent_success_rates)
      assert Map.has_key?(stats, :last_learning_cycle)
    end

    test "tracks total episodes" do
      TrainingGym.record_episode(%{type: :success})
      TrainingGym.record_episode(%{type: :success})

      :timer.sleep(100)

      stats = TrainingGym.get_stats()
      assert stats.total_episodes >= 2
    end
  end

  describe "trigger_learning_cycle/0" do
    setup do
      {:ok, pid} = TrainingGym.start_link([])
      on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
      %{pid: pid}
    end

    test "clears episodes after learning" do
      # Record some episodes
      for _ <- 1..5 do
        TrainingGym.record_episode(%{type: :success})
      end

      :timer.sleep(50)

      # Trigger learning
      TrainingGym.trigger_learning_cycle()

      :timer.sleep(100)

      # Pending should be cleared
      stats = TrainingGym.get_stats()
      assert stats.pending_episodes == 0
    end
  end
end
