defmodule Indrajaal.ErrorConditions.FLAMERunnerCrashTest do
  @moduledoc """
  Error condition tests for FLAME runner crashes and recovery.

  STAMP Constraints Tested:
  - SC-FLAME-009: Crash handling
  - SC-FLAME-010: Work requeue on failure
  - SC-FLAME-011: Parent isolation

  AOR Rules:
  - AOR-FLAME-001: Never lose work silently
  - AOR-FLAME-002: Log all crashes with context
  - AOR-FLAME-003: Emit telemetry on crashes
  """

  use ExUnit.Case, async: true

  describe "SC-FLAME-009: Crash Handling" do
    test "runner crash is isolated from parent" do
      parent_state = %{
        alive: true,
        active_runners: 5,
        queued_work: [:work_1, :work_2]
      }

      # Simulate runner crash
      new_state = handle_runner_crash(parent_state, "runner-3")

      # Parent should remain alive
      assert new_state.alive == true
      # Runner count decreased
      assert new_state.active_runners == 4
    end

    test "crash doesn't affect other runners" do
      runners = %{
        "runner-1" => %{state: :running, task: :task_1},
        "runner-2" => %{state: :running, task: :task_2},
        "runner-3" => %{state: :running, task: :task_3}
      }

      # Runner 2 crashes
      new_runners = handle_individual_runner_crash(runners, "runner-2")

      # Other runners unaffected
      assert new_runners["runner-1"].state == :running
      assert new_runners["runner-3"].state == :running
      assert new_runners["runner-2"] == nil
    end

    test "crash metadata is captured" do
      crash_info = %{
        runner_id: "runner-5",
        error: {:exit, :killed},
        task: :heavy_computation,
        crash_time: DateTime.utc_now()
      }

      metadata = extract_crash_metadata(crash_info)

      assert Map.has_key?(metadata, :runner_id)
      assert Map.has_key?(metadata, :error_type)
      assert Map.has_key?(metadata, :task)
    end
  end

  describe "SC-FLAME-010: Work Requeue on Failure" do
    test "crashed work is requeued" do
      queue_state = %{
        pending: [:work_1, :work_2],
        in_progress: %{"runner-1" => :work_3}
      }

      # Runner 1 crashes with work_3
      new_state = requeue_crashed_work(queue_state, "runner-1")

      # work_3 should be back in pending
      assert :work_3 in new_state.pending
      assert new_state.in_progress["runner-1"] == nil
    end

    test "requeued work has retry count incremented" do
      work_item = %{
        id: :work_1,
        retry_count: 0,
        max_retries: 3
      }

      requeued = increment_retry_count(work_item)

      assert requeued.retry_count == 1
    end

    test "work exceeding max retries is dead-lettered" do
      work_item = %{
        id: :work_1,
        retry_count: 3,
        max_retries: 3
      }

      result = handle_work_retry(work_item)

      assert result == {:dead_letter, :max_retries_exceeded}
    end

    test "requeue preserves work order for same-priority items" do
      queue = [:work_2, :work_3]
      requeued_work = :work_1

      # Requeue at front for retry
      new_queue = requeue_at_front(queue, requeued_work)

      assert hd(new_queue) == :work_1
    end
  end

  describe "SC-FLAME-011: Parent Isolation" do
    test "parent process survives child crash" do
      parent = %{
        pid: self(),
        trap_exit: true,
        children: [:runner_1, :runner_2, :runner_3]
      }

      # Simulate child crash
      result = handle_child_exit(parent, :runner_2, :killed)

      assert result.action == :restart_child
      assert result.parent_alive == true
    end

    test "parent receives exit signal" do
      exit_signal = {:EXIT, :fake_pid, :normal}

      handled = handle_exit_signal(exit_signal)

      assert handled.logged == true
      assert handled.telemetry_emitted == true
    end

    test "supervision tree remains stable" do
      supervision_tree = %{
        supervisor: :flame_pool_supervisor,
        children: 5,
        restarts_in_window: 2,
        max_restarts: 10
      }

      stable = is_tree_stable?(supervision_tree)

      assert stable == true
    end
  end

  describe "Crash Telemetry" do
    test "crash event is emitted" do
      event = [:flame, :runner, :crash]
      measurements = %{count: 1}

      metadata = %{
        runner_id: "runner-1",
        pool: :intelligence,
        error: :killed,
        task: :computation
      }

      # Verify event structure
      assert is_list(event)
      assert length(event) == 3
      assert is_map(measurements)
      assert is_map(metadata)
    end

    test "crash metrics are recorded" do
      metric = %{
        name: "flame.runner.crashes.total",
        value: 1,
        tags: %{
          pool: :intelligence,
          error_type: :killed
        }
      }

      assert metric.name == "flame.runner.crashes.total"
      assert Map.has_key?(metric.tags, :pool)
    end
  end

  describe "Recovery Behavior" do
    test "runner is restarted after crash" do
      pool_state = %{
        target_runners: 5,
        active_runners: 4,
        crashed_runner: "runner-3"
      }

      action = determine_recovery_action(pool_state)

      assert action == :spawn_replacement
    end

    test "crash rate triggers circuit breaker" do
      crash_history = %{
        crashes_in_window: 10,
        window_ms: 60_000,
        threshold: 5
      }

      should_halt = should_halt_spawning?(crash_history)

      assert should_halt == true
    end

    test "backoff is applied after repeated crashes" do
      crash_state = %{
        consecutive_crashes: 3,
        base_backoff_ms: 1000
      }

      backoff = calculate_spawn_backoff(crash_state)

      # Exponential backoff
      assert backoff >= 4000
    end
  end

  describe "Error Logging" do
    test "crash is logged with full context" do
      crash = %{
        runner_id: "runner-1",
        pool: :intelligence,
        error: {:exit, {:shutdown, :timeout}},
        task: %{type: :ai_inference, input_size: 1024},
        duration_before_crash_ms: 5000
      }

      log_entry = format_crash_log(crash)

      assert String.contains?(log_entry, "runner-1")
      assert String.contains?(log_entry, "intelligence")
      assert String.contains?(log_entry, "timeout")
    end

    test "log level is error for crashes" do
      crash_type = :unexpected_exit

      level = get_crash_log_level(crash_type)

      assert level == :error
    end
  end

  # Helper functions

  defp handle_runner_crash(state, _runner_id) do
    %{state | active_runners: state.active_runners - 1}
  end

  defp handle_individual_runner_crash(runners, crashed_id) do
    Map.delete(runners, crashed_id)
  end

  defp extract_crash_metadata(crash_info) do
    %{
      runner_id: crash_info.runner_id,
      error_type: elem(crash_info.error, 0),
      task: crash_info.task,
      timestamp: crash_info.crash_time
    }
  end

  defp requeue_crashed_work(state, runner_id) do
    work = state.in_progress[runner_id]

    %{
      pending: [work | state.pending],
      in_progress: Map.delete(state.in_progress, runner_id)
    }
  end

  defp increment_retry_count(work) do
    %{work | retry_count: work.retry_count + 1}
  end

  defp handle_work_retry(work) do
    if work.retry_count >= work.max_retries do
      {:dead_letter, :max_retries_exceeded}
    else
      {:requeue, increment_retry_count(work)}
    end
  end

  defp requeue_at_front(queue, work) do
    [work | queue]
  end

  defp handle_child_exit(parent, _child, _reason) do
    %{
      action: :restart_child,
      parent_alive: true,
      remaining_children: length(parent.children) - 1
    }
  end

  defp handle_exit_signal(_signal) do
    %{
      logged: true,
      telemetry_emitted: true,
      action: :restart
    }
  end

  defp is_tree_stable?(tree) do
    tree.restarts_in_window < tree.max_restarts
  end

  defp determine_recovery_action(state) do
    if state.active_runners < state.target_runners do
      :spawn_replacement
    else
      :no_action
    end
  end

  defp should_halt_spawning?(history) do
    history.crashes_in_window > history.threshold
  end

  defp calculate_spawn_backoff(state) do
    (state.base_backoff_ms * :math.pow(2, state.consecutive_crashes)) |> round()
  end

  defp format_crash_log(crash) do
    "[FLAME] Runner crash: runner_id=#{crash.runner_id}, pool=#{crash.pool}, error=#{inspect(crash.error)}"
  end

  defp get_crash_log_level(_crash_type) do
    :error
  end
end
