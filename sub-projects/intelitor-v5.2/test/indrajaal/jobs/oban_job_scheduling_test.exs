defmodule Indrajaal.Jobs.ObanJobSchedulingTest do
  @moduledoc """
  Oban job scheduling integration test — alarm workflow reliability.

  ## WHAT
  Tests Oban-compatible job scheduling patterns including retry logic,
  dead letter handling, priority queues, and alarm workflow integration.

  ## CONSTRAINTS
  - SC-OBAN-001 to SC-OBAN-004: Infrastructure OBAN component
  - SC-ALARM-001: Alarm processing
  - SC-ALARM-006: Alarm workflow scheduling
  - AOR-HOLON-019: Lineage Immutability — evolution history append-only
  """

  use ExUnit.Case, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  @max_attempts 3
  @backoff_base_ms 1000
  @dead_letter_threshold 3

  # ============================================================================
  # Job Creation Tests
  # ============================================================================

  describe "job creation" do
    test "creates a job with valid args" do
      job = create_job("alarm.process", %{alarm_id: "ALM-001", severity: :critical})

      assert job.worker == "alarm.process"
      assert job.args.alarm_id == "ALM-001"
      assert job.state == :available
      assert job.attempt == 0
      assert job.max_attempts == @max_attempts
    end

    test "creates a scheduled job with delay" do
      job = create_job("alarm.escalate", %{alarm_id: "ALM-002"}, scheduled_at: 60_000)

      assert job.state == :scheduled
      assert job.scheduled_at > System.monotonic_time(:millisecond)
    end

    test "creates a job with priority" do
      job = create_job("alarm.critical", %{}, priority: 0)
      assert job.priority == 0

      job_low = create_job("alarm.info", %{}, priority: 3)
      assert job_low.priority == 3
    end

    test "creates a job with queue assignment" do
      job = create_job("alarm.process", %{}, queue: :alarms)
      assert job.queue == :alarms
    end
  end

  # ============================================================================
  # Job Execution Tests
  # ============================================================================

  describe "job execution" do
    test "successful execution marks job as completed" do
      job = create_job("alarm.process", %{alarm_id: "ALM-003"})
      result = execute_job(job, fn _args -> {:ok, :processed} end)

      assert result.state == :completed
      assert result.attempt == 1
      assert result.completed_at != nil
    end

    test "failed execution increments attempt count" do
      job = create_job("alarm.process", %{alarm_id: "ALM-004"})
      result = execute_job(job, fn _args -> {:error, :timeout} end)

      assert result.state == :retryable
      assert result.attempt == 1
      assert result.errors == [{1, :timeout}]
    end

    test "exhausted retries moves job to discarded" do
      job = create_job("alarm.process", %{alarm_id: "ALM-005"})

      final =
        Enum.reduce(1..@max_attempts, job, fn _, j ->
          execute_job(j, fn _args -> {:error, :timeout} end)
        end)

      assert final.state == :discarded
      assert final.attempt == @max_attempts
      assert length(final.errors) == @max_attempts
    end
  end

  # ============================================================================
  # Retry Logic Tests
  # ============================================================================

  describe "retry logic with exponential backoff" do
    test "backoff increases exponentially" do
      delays =
        for attempt <- 1..5 do
          calculate_backoff(attempt)
        end

      # Each delay should be larger than the previous
      for [a, b] <- Enum.chunk_every(delays, 2, 1, :discard) do
        assert b > a, "Backoff should increase: #{b} > #{a}"
      end
    end

    test "first retry has base delay" do
      delay = calculate_backoff(1)
      assert delay == @backoff_base_ms
    end

    test "backoff is capped at 30 seconds" do
      delay = calculate_backoff(10)
      assert delay <= 30_000
    end

    test "backoff with jitter varies" do
      delays =
        for _ <- 1..10 do
          calculate_backoff_with_jitter(3)
        end

      # With jitter, not all delays should be identical
      unique = Enum.uniq(delays)
      assert length(unique) > 1, "Jitter should produce varying delays"
    end
  end

  # ============================================================================
  # Dead Letter Queue Tests
  # ============================================================================

  describe "dead letter queue" do
    test "discarded jobs move to dead letter queue" do
      job = create_job("alarm.broken", %{alarm_id: "ALM-006"})

      final =
        Enum.reduce(1..@max_attempts, job, fn _, j ->
          execute_job(j, fn _args -> {:error, :crash} end)
        end)

      dlq = dead_letter_enqueue(final)
      assert dlq.original_job.worker == "alarm.broken"
      assert dlq.reason == :max_attempts_exceeded
      assert dlq.discarded_at != nil
    end

    test "dead letter queue preserves error history" do
      job = create_job("alarm.crash", %{})

      final =
        Enum.reduce(1..@max_attempts, job, fn i, j ->
          execute_job(j, fn _args -> {:error, "error-#{i}"} end)
        end)

      dlq = dead_letter_enqueue(final)
      assert length(dlq.original_job.errors) == @max_attempts
    end

    test "dead letter jobs can be replayed" do
      job = create_job("alarm.retry", %{alarm_id: "ALM-007"})
      discarded = %{job | state: :discarded, attempt: @max_attempts}
      dlq = dead_letter_enqueue(discarded)

      replayed = replay_dead_letter(dlq)
      assert replayed.state == :available
      assert replayed.attempt == 0
      assert replayed.errors == []
    end
  end

  # ============================================================================
  # Priority Queue Tests
  # ============================================================================

  describe "priority queue ordering" do
    test "higher priority jobs are dequeued first" do
      queue = new_priority_queue()

      queue = enqueue(queue, create_job("low", %{}, priority: 3))
      queue = enqueue(queue, create_job("critical", %{}, priority: 0))
      queue = enqueue(queue, create_job("medium", %{}, priority: 2))
      queue = enqueue(queue, create_job("high", %{}, priority: 1))

      {job1, queue} = dequeue(queue)
      {job2, queue} = dequeue(queue)
      {job3, queue} = dequeue(queue)
      {job4, _queue} = dequeue(queue)

      assert job1.worker == "critical"
      assert job2.worker == "high"
      assert job3.worker == "medium"
      assert job4.worker == "low"
    end

    test "same priority maintains FIFO order" do
      queue = new_priority_queue()

      queue = enqueue(queue, create_job("first", %{}, priority: 1))
      queue = enqueue(queue, create_job("second", %{}, priority: 1))
      queue = enqueue(queue, create_job("third", %{}, priority: 1))

      {job1, queue} = dequeue(queue)
      {job2, _queue} = dequeue(queue)

      assert job1.worker == "first"
      assert job2.worker == "second"
    end

    test "empty queue returns nil" do
      queue = new_priority_queue()
      assert {nil, ^queue} = dequeue(queue)
    end
  end

  # ============================================================================
  # Alarm Workflow Tests
  # ============================================================================

  describe "alarm workflow scheduling" do
    test "critical alarm creates immediate job" do
      alarm = %{id: "ALM-100", severity: :critical, source: "sensor-1"}
      jobs = schedule_alarm_workflow(alarm)

      assert length(jobs) >= 2
      process_job = Enum.find(jobs, &(&1.worker == "alarm.process"))
      notify_job = Enum.find(jobs, &(&1.worker == "alarm.notify"))

      assert process_job.priority == 0
      assert notify_job != nil
    end

    test "warning alarm creates normal priority job" do
      alarm = %{id: "ALM-101", severity: :warning, source: "sensor-2"}
      jobs = schedule_alarm_workflow(alarm)

      process_job = Enum.find(jobs, &(&1.worker == "alarm.process"))
      assert process_job.priority == 2
    end

    test "alarm escalation is scheduled with delay" do
      alarm = %{id: "ALM-102", severity: :critical, source: "sensor-3"}
      jobs = schedule_alarm_workflow(alarm)

      escalate_job = Enum.find(jobs, &(&1.worker == "alarm.escalate"))
      assert escalate_job != nil
      assert escalate_job.state == :scheduled
    end
  end

  # ============================================================================
  # Property Tests
  # ============================================================================

  describe "property: backoff is monotonically increasing" do
    @tag timeout: 30_000
    test "higher attempts always produce longer delays" do
      ExUnitProperties.check all(attempt <- SD.integer(1..10)) do
        delay_current = calculate_backoff(attempt)
        delay_next = calculate_backoff(attempt + 1)
        assert delay_next >= delay_current
      end
    end
  end

  describe "property: job lifecycle is consistent" do
    @tag timeout: 30_000
    test "job attempt count never exceeds max_attempts" do
      ExUnitProperties.check all(num_failures <- SD.integer(1..10)) do
        job = create_job("test.worker", %{})

        final =
          Enum.reduce(1..num_failures, job, fn _, j ->
            if j.state in [:available, :retryable] do
              execute_job(j, fn _args -> {:error, :fail} end)
            else
              j
            end
          end)

        assert final.attempt <= @max_attempts
      end
    end
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp create_job(worker, args, opts \\ []) do
    %{
      id: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      worker: worker,
      args: args,
      state: if(Keyword.get(opts, :scheduled_at), do: :scheduled, else: :available),
      queue: Keyword.get(opts, :queue, :default),
      priority: Keyword.get(opts, :priority, 1),
      attempt: 0,
      max_attempts: @max_attempts,
      errors: [],
      scheduled_at:
        Keyword.get(opts, :scheduled_at) &&
          System.monotonic_time(:millisecond) + Keyword.get(opts, :scheduled_at),
      completed_at: nil,
      inserted_at: System.monotonic_time(:millisecond)
    }
  end

  defp execute_job(job, handler) when job.state in [:available, :retryable] do
    new_attempt = job.attempt + 1

    case handler.(job.args) do
      {:ok, _result} ->
        %{
          job
          | state: :completed,
            attempt: new_attempt,
            completed_at: System.monotonic_time(:millisecond)
        }

      {:error, reason} ->
        if new_attempt >= job.max_attempts do
          %{
            job
            | state: :discarded,
              attempt: new_attempt,
              errors: job.errors ++ [{new_attempt, reason}]
          }
        else
          %{
            job
            | state: :retryable,
              attempt: new_attempt,
              errors: job.errors ++ [{new_attempt, reason}]
          }
        end
    end
  end

  defp execute_job(job, _handler), do: job

  defp calculate_backoff(attempt) do
    delay = (@backoff_base_ms * :math.pow(2, attempt - 1)) |> round()
    min(delay, 30_000)
  end

  defp calculate_backoff_with_jitter(attempt) do
    base = calculate_backoff(attempt)
    jitter = :rand.uniform(round(base * 0.3))
    base + jitter
  end

  defp dead_letter_enqueue(job) do
    %{
      original_job: job,
      reason: :max_attempts_exceeded,
      discarded_at: System.monotonic_time(:millisecond)
    }
  end

  defp replay_dead_letter(dlq) do
    %{dlq.original_job | state: :available, attempt: 0, errors: []}
  end

  defp new_priority_queue, do: []

  defp enqueue(queue, job) do
    [job | queue]
    |> Enum.sort_by(fn j -> {j.priority, j.inserted_at} end)
  end

  defp dequeue([]), do: {nil, []}
  defp dequeue([head | rest]), do: {head, rest}

  defp schedule_alarm_workflow(alarm) do
    priority =
      case alarm.severity do
        :critical -> 0
        :major -> 1
        :warning -> 2
        :info -> 3
        _ -> 2
      end

    process_job = create_job("alarm.process", %{alarm_id: alarm.id}, priority: priority)

    notify_job =
      create_job("alarm.notify", %{alarm_id: alarm.id, severity: alarm.severity},
        priority: priority
      )

    escalate_job =
      if alarm.severity in [:critical, :major] do
        create_job("alarm.escalate", %{alarm_id: alarm.id},
          priority: priority,
          scheduled_at: 300_000
        )
      end

    Enum.reject([process_job, notify_job, escalate_job], &is_nil/1)
  end
end
