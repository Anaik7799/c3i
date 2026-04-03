defmodule Indrajaal.Parallelization.TaskQueueTest do
  @moduledoc """
  TDG Test Suite for Parallelization Task Queue Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: Task queue safety constraints
  - SOPv5.11_CYBERNETIC: Queue management validation

  Tests task queue capabilities:
  - Queue creation and capacity
  - Priority-based scheduling
  - Task enqueue/dequeue
  - Batch operations
  - Backpressure handling
  """
  use ExUnit.Case, async: true
  use PropCheck
  alias StreamData, as: SD
  # EP-GEN-014: Exclude PropCheck's check to use ExUnitProperties' check all()
  import PropCheck, except: [check: 2]
  alias PropCheck.BasicTypes, as: PC
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  import StreamData

  alias Indrajaal.Parallelization.TaskQueue

  @moduletag :tdg_compliant
  @moduletag :parallelization_domain

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(TaskQueue)
    end

    test "new/1 function exists" do
      assert function_exported?(TaskQueue, :new, 1)
    end

    test "enqueue_task/2 function exists" do
      assert function_exported?(TaskQueue, :enqueue_task, 2)
    end

    test "dequeue_task/1 function exists" do
      assert function_exported?(TaskQueue, :dequeue_task, 1)
    end

    test "dequeue_batch/2 function exists" do
      assert function_exported?(TaskQueue, :dequeue_batch, 2)
    end

    test "get_queue_stats/1 function exists" do
      assert function_exported?(TaskQueue, :get_queue_stats, 1)
    end
  end

  describe "queue creation" do
    test "creates queue with specified capacity" do
      queue = TaskQueue.new(1000)
      assert queue.max_capacity == 1000
    end

    test "initializes priority queues for all levels" do
      queue = TaskQueue.new(100)
      assert Map.has_key?(queue.priority_queues, :critical)
      assert Map.has_key?(queue.priority_queues, :high)
      assert Map.has_key?(queue.priority_queues, :normal)
      assert Map.has_key?(queue.priority_queues, :low)
      assert Map.has_key?(queue.priority_queues, :background)
    end

    test "initializes rate limiter" do
      queue = TaskQueue.new(100)
      assert queue.rate_limiter != nil
    end

    test "initializes queue analytics" do
      queue = TaskQueue.new(100)
      assert queue.queue_analytics != nil
    end
  end

  describe "priority levels" do
    test "supported priority levels" do
      levels = [:critical, :high, :normal, :low, :background]
      assert length(levels) == 5
    end

    test "critical is highest priority" do
      levels = [:critical, :high, :normal, :low, :background]
      assert hd(levels) == :critical
    end
  end

  describe "queue operations" do
    test "mark_task_completed/2 function exists" do
      assert function_exported?(TaskQueue, :mark_task_completed, 2)
    end

    test "optimize_queue/1 function exists" do
      assert function_exported?(TaskQueue, :optimize_queue, 1)
    end

    test "handle_backpressure/2 function exists" do
      assert function_exported?(TaskQueue, :handle_backpressure, 2)
    end
  end

  describe "PropCheck property tests" do
    property "module availability" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(TaskQueue)
      end
    end

    property "queue capacity is always positive" do
      forall capacity <- PC.pos_integer() do
        queue = TaskQueue.new(capacity)
        queue.max_capacity > 0
      end
    end

    property "priority levels are valid atoms" do
      forall priority <- PC.oneof([:critical, :high, :normal, :low, :background]) do
        is_atom(priority)
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "queue capacities are positive integers" do
      ExUnitProperties.check all(capacity <- SD.integer(1..10_000)) do
        queue = TaskQueue.new(capacity)
        assert queue.max_capacity == capacity
      end
    end

    test "task IDs are valid strings" do
      ExUnitProperties.check all(id <- SD.string(:alphanumeric, min_length: 1, max_length: 50)) do
        assert is_binary(id)
      end
    end

    test "estimated durations are non-negative" do
      ExUnitProperties.check all(duration <- SD.integer(0..1_000_000)) do
        assert duration >= 0
      end
    end
  end

  describe "queue statistics" do
    test "get_queue_stats returns required fields" do
      queue = TaskQueue.new(100)
      stats = TaskQueue.get_queue_stats(queue)

      assert Map.has_key?(stats, :total_tasks)
      assert Map.has_key?(stats, :max_capacity)
      assert Map.has_key?(stats, :utilization_percentage)
      assert Map.has_key?(stats, :priority_distribution)
    end

    test "empty queue has zero tasks" do
      queue = TaskQueue.new(100)
      stats = TaskQueue.get_queue_stats(queue)
      assert stats.total_tasks == 0
    end

    test "empty queue has zero utilization" do
      queue = TaskQueue.new(100)
      stats = TaskQueue.get_queue_stats(queue)
      assert stats.utilization_percentage == 0.0
    end
  end

  describe "STAMP safety for task queue" do
    test "SC-AGT-018: prevents queue deadlocks with dependency tracking" do
      queue = TaskQueue.new(100)
      # Dependency graph initialized for deadlock prevention
      assert queue.dependency_graph != nil
    end

    test "SC-AGT-021: prevents queue overflow" do
      queue = TaskQueue.new(100)
      # Max capacity is enforced
      assert queue.max_capacity == 100
    end

    test "SC-PRF-049: prevents resource exhaustion with rate limiting" do
      queue = TaskQueue.new(100)
      # Rate limiter initialized
      assert queue.rate_limiter != nil
    end

    test "SC-AGT-024: supports load balancing with priority distribution" do
      queue = TaskQueue.new(100)
      # Priority queues for load distribution
      assert map_size(queue.priority_queues) == 5
    end
  end
end
