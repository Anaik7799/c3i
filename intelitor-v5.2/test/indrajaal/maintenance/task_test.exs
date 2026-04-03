defmodule Indrajaal.Maintenance.TaskTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.Maintenance.Task.

  ## SOPv5.11+AEE+GDE Framework Integration
  - TDG Compliance: Tests written BEFORE implementation hardening
  - FPPS Validation: Task lifecycle verified across all status transitions

  ## STAMP Safety Integration
  - SC-COV-001: Critical maintenance task state machine path coverage
  - SC-COV-006: TDG compliance mandatory

  ## Constitutional Verification
  - Psi0 Existence: Task records persist across status transitions
  - Psi1 Regeneration: Task state fully reconstructible from Ash resource

  ## Founder's Directive Alignment
  - Omega0.1: Accurate task tracking ensures equipment maintenance quality

  ## TPS 5-Level RCA Context
  - L1 Symptom: Tasks stuck in :pending or reverting to wrong status after fail
  - L5 Root Cause: Missing retry-count boundary validation for task failure state machine

  ## Change History
  | Version | Date | Author | Change |
  |---------|------|--------|--------|
  | 21.3.0 | 2026-03-21 | Claude | Sprint 54 W3 test generation |

  ## Notes
  - Task status lifecycle: pending→make_ready→ready→start→in_progress→complete→completed
  - pause (in_progress→waiting_parts), resume (waiting_parts|waiting_approval→in_progress)
  - fail: when retry_count+1 < max_retries → status :ready; when >= max_retries → status :failed
  - skip: from :pending or :ready; cancel: from any status except :completed/:failed/:cancelled
  - No maintenance task factory exists — creates via Ash.create directly.
  - work_order_id is allow_nil? false but work orders are in a separate resource;
    tests use a fake UUID as work_order_id since we only test Task actions.
  """

  use Indrajaal.DataCase, async: true
  use PropCheck
  import ExUnitProperties, except: [property: 2, property: 3, check: 2]

  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD
  alias Indrajaal.Maintenance.Task

  @moduletag :zenoh_nif

  @system_admin %{id: "system", is_system_admin: true}

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp create_task(attrs \\ %{}) do
    tenant = random_tenant()

    base = %{
      work_order_id: Ash.UUID.generate(),
      task_number: System.unique_integer([:positive, :monotonic]),
      title: "Inspect CCTV Camera #{System.unique_integer()}",
      description: "Visual inspection of camera housing, lens, and mounting.",
      task_type: :inspection,
      category: :security,
      instructions: "Check all connectors, clean lens, verify mounting bolts.",
      estimated_duration_minutes: 30,
      sequence_order: 1,
      complexity_level: 2,
      tenant_id: tenant.id
    }

    attrs_with_tenant = Map.put_new(attrs, :tenant_id, tenant.id)
    merged = Map.merge(base, attrs_with_tenant)

    {:ok, task} =
      Ash.create(Task, merged, action: :create, authorize?: false, actor: @system_admin)

    task
  end

  defp make_ready(task) do
    {:ok, ready} =
      Ash.update(task, %{}, action: :make_ready, authorize?: false, actor: @system_admin)

    ready
  end

  defp start_task(task) do
    ready = if task.status == :pending, do: make_ready(task), else: task

    {:ok, started} =
      Ash.update(ready, %{}, action: :start, authorize?: false, actor: @system_admin)

    started
  end

  # ---------------------------------------------------------------------------
  # create action
  # ---------------------------------------------------------------------------

  describe "create action" do
    test "creates a task with default status :pending" do
      task = create_task()
      assert task.status == :pending
    end

    test "creates task with default task_type :inspection" do
      task = create_task()
      assert task.task_type == :inspection
    end

    test "creates task with default category :security" do
      task = create_task()
      assert task.category == :security
    end

    test "creates task with default completion_percentage 0" do
      task = create_task()
      assert task.completion_percentage == 0
    end

    test "creates task with default retry_count 0" do
      task = create_task()
      assert task.retry_count == 0
    end

    test "creates task with default max_retries 3" do
      task = create_task()
      assert task.max_retries == 3
    end

    test "creates task with default parallel_execution? true" do
      task = create_task()
      assert task.parallel_execution? == true
    end

    test "creates task with custom task_type :calibration" do
      task = create_task(%{task_type: :calibration})
      assert task.task_type == :calibration
    end

    test "creates task with custom complexity_level 5 (max)" do
      task = create_task(%{complexity_level: 5})
      assert task.complexity_level == 5
    end

    test "creates task with safety_critical? true" do
      task = create_task(%{safety_critical?: true, lockout_tagout_required?: true})
      assert task.safety_critical? == true
      assert task.lockout_tagout_required? == true
    end

    test "rejects complexity_level above 5" do
      tenant = random_tenant()

      result =
        Ash.create(
          Task,
          %{
            work_order_id: Ash.UUID.generate(),
            task_number: 1,
            title: "Test",
            description: "Test desc",
            instructions: "Instructions",
            complexity_level: 10,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # make_ready action (pending → ready)
  # ---------------------------------------------------------------------------

  describe "make_ready action" do
    test "transitions status from :pending to :ready" do
      task = create_task()
      assert task.status == :pending

      {:ok, ready} =
        Ash.update(task, %{}, action: :make_ready, authorize?: false, actor: @system_admin)

      assert ready.status == :ready
    end

    test "returns error when task is not in :pending status" do
      task = create_task() |> make_ready()

      result = Ash.update(task, %{}, action: :make_ready, authorize?: false, actor: @system_admin)
      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # start action (ready → in_progress)
  # ---------------------------------------------------------------------------

  describe "start action" do
    test "transitions status from :ready to :in_progress" do
      task = create_task() |> make_ready()

      {:ok, started} =
        Ash.update(task, %{}, action: :start, authorize?: false, actor: @system_admin)

      assert started.status == :in_progress
    end

    test "sets started_at to current datetime" do
      task = create_task() |> make_ready()
      before_start = DateTime.utc_now()

      {:ok, started} =
        Ash.update(task, %{}, action: :start, authorize?: false, actor: @system_admin)

      assert not is_nil(started.started_at)
      assert DateTime.compare(started.started_at, before_start) != :lt
    end

    test "sets completion_percentage to 0 on start" do
      task = create_task() |> make_ready()

      {:ok, started} =
        Ash.update(task, %{}, action: :start, authorize?: false, actor: @system_admin)

      assert started.completion_percentage == 0
    end

    test "returns error when starting a task not in :ready state" do
      task = create_task()
      result = Ash.update(task, %{}, action: :start, authorize?: false, actor: @system_admin)
      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # update_progress action (in_progress)
  # ---------------------------------------------------------------------------

  describe "update_progress action" do
    test "updates completion_percentage on in_progress task" do
      task = create_task() |> start_task()

      {:ok, updated} =
        Ash.update(
          task,
          %{percentage: 60},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert updated.completion_percentage == 60
    end

    test "returns error when updating progress on a non-in_progress task" do
      task = create_task() |> make_ready()

      result =
        Ash.update(
          task,
          %{percentage: 50},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # pause / resume actions
  # ---------------------------------------------------------------------------

  describe "pause and resume actions" do
    test "pause transitions in_progress task to :waiting_parts" do
      task = create_task() |> start_task()

      {:ok, paused} =
        Ash.update(
          task,
          %{reason: "Waiting for replacement sensor part"},
          action: :pause,
          authorize?: false,
          actor: @system_admin
        )

      assert paused.status == :waiting_parts
    end

    test "pause stores reason as substatus" do
      task = create_task() |> start_task()

      {:ok, paused} =
        Ash.update(
          task,
          %{reason: "Part on order"},
          action: :pause,
          authorize?: false,
          actor: @system_admin
        )

      assert paused.substatus == "Part on order"
    end

    test "resume transitions waiting_parts task back to :in_progress" do
      task = create_task() |> start_task()

      {:ok, paused} =
        Ash.update(task, %{reason: "Pause"},
          action: :pause,
          authorize?: false,
          actor: @system_admin
        )

      {:ok, resumed} =
        Ash.update(paused, %{}, action: :resume, authorize?: false, actor: @system_admin)

      assert resumed.status == :in_progress
    end

    test "pause returns error when task is not in_progress" do
      task = create_task() |> make_ready()

      result =
        Ash.update(
          task,
          %{reason: "Invalid pause"},
          action: :pause,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # complete action (in_progress → completed)
  # ---------------------------------------------------------------------------

  describe "complete action" do
    test "transitions in_progress task to :completed" do
      task = create_task() |> start_task()

      {:ok, completed} =
        Ash.update(
          task,
          %{work_performed: "Inspected CCTV, cleaned lens, tightened all mounts."},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      assert completed.status == :completed
    end

    test "sets completion_percentage to 100" do
      task = create_task() |> start_task()

      {:ok, completed} =
        Ash.update(
          task,
          %{work_performed: "Full inspection completed."},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      assert completed.completion_percentage == 100
    end

    test "sets completed_at to a datetime" do
      task = create_task() |> start_task()
      before_complete = DateTime.utc_now()

      {:ok, completed} =
        Ash.update(
          task,
          %{work_performed: "Done."},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      assert not is_nil(completed.completed_at)
      assert DateTime.compare(completed.completed_at, before_complete) != :lt
    end

    test "returns error when completing a pending task" do
      task = create_task()

      result =
        Ash.update(
          task,
          %{work_performed: "Premature completion"},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # fail action — retry logic
  # ---------------------------------------------------------------------------

  describe "fail action" do
    test "when retry_count+1 < max_retries, status returns to :ready" do
      # default max_retries = 3, retry_count = 0 → 0+1=1 < 3 → :ready
      task = create_task(%{max_retries: 3}) |> start_task()

      {:ok, failed} =
        Ash.update(
          task,
          %{failure_reason: "Calibration instrument out of range"},
          action: :fail,
          authorize?: false,
          actor: @system_admin
        )

      assert failed.status == :ready
      assert failed.retry_count == 1
    end

    test "when retry_count+1 >= max_retries, status becomes :failed" do
      # max_retries = 1, retry_count = 0 → 0+1=1 >= 1 → :failed
      task = create_task(%{max_retries: 1}) |> start_task()

      {:ok, failed} =
        Ash.update(
          task,
          %{failure_reason: "Cannot proceed — equipment damaged"},
          action: :fail,
          authorize?: false,
          actor: @system_admin
        )

      assert failed.status == :failed
      assert failed.retry_count == 1
    end

    test "fail stores failure_reason" do
      task = create_task() |> start_task()

      {:ok, failed} =
        Ash.update(
          task,
          %{failure_reason: "Torque wrench unavailable"},
          action: :fail,
          authorize?: false,
          actor: @system_admin
        )

      assert failed.failure_reason == "Torque wrench unavailable"
    end

    test "increments retry_count on each fail" do
      task = create_task(%{max_retries: 10}) |> start_task()

      {:ok, t1} =
        Ash.update(task, %{failure_reason: "First failure"},
          action: :fail,
          authorize?: false,
          actor: @system_admin
        )

      # t1 is :ready — need to start again before failing again
      {:ok, t1_started} =
        Ash.update(t1, %{}, action: :start, authorize?: false, actor: @system_admin)

      {:ok, t2} =
        Ash.update(t1_started, %{failure_reason: "Second failure"},
          action: :fail,
          authorize?: false,
          actor: @system_admin
        )

      assert t2.retry_count == 2
    end

    test "returns error when failing a completed task" do
      task = create_task() |> start_task()

      {:ok, completed} =
        Ash.update(task, %{work_performed: "Done"},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      result =
        Ash.update(completed, %{failure_reason: "Too late"},
          action: :fail,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # skip action (pending|ready → skipped)
  # ---------------------------------------------------------------------------

  describe "skip action" do
    test "skips a pending task" do
      task = create_task()

      {:ok, skipped} =
        Ash.update(task, %{reason: "Not applicable to this unit"},
          action: :skip,
          authorize?: false,
          actor: @system_admin
        )

      assert skipped.status == :skipped
    end

    test "skips a ready task" do
      task = create_task() |> make_ready()

      {:ok, skipped} =
        Ash.update(task, %{reason: "Already covered by previous task"},
          action: :skip,
          authorize?: false,
          actor: @system_admin
        )

      assert skipped.status == :skipped
    end

    test "stores skip reason as substatus" do
      task = create_task()

      {:ok, skipped} =
        Ash.update(task, %{reason: "Deferred to next sprint"},
          action: :skip,
          authorize?: false,
          actor: @system_admin
        )

      assert skipped.substatus == "Deferred to next sprint"
    end

    test "returns error when skipping an in_progress task" do
      task = create_task() |> start_task()

      result =
        Ash.update(task, %{reason: "Skip while running"},
          action: :skip,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # cancel action
  # ---------------------------------------------------------------------------

  describe "cancel action" do
    test "cancels a pending task" do
      task = create_task()

      {:ok, cancelled} =
        Ash.update(task, %{reason: "Work order cancelled"},
          action: :cancel,
          authorize?: false,
          actor: @system_admin
        )

      assert cancelled.status == :cancelled
    end

    test "cancels a ready task" do
      task = create_task() |> make_ready()

      {:ok, cancelled} =
        Ash.update(task, %{reason: "Superseded by emergency"},
          action: :cancel,
          authorize?: false,
          actor: @system_admin
        )

      assert cancelled.status == :cancelled
    end

    test "cancels an in_progress task" do
      task = create_task() |> start_task()

      {:ok, cancelled} =
        Ash.update(task, %{reason: "Emergency shutdown"},
          action: :cancel,
          authorize?: false,
          actor: @system_admin
        )

      assert cancelled.status == :cancelled
    end

    test "returns error when cancelling a completed task" do
      task = create_task() |> start_task()

      {:ok, completed} =
        Ash.update(task, %{work_performed: "Done"},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      result =
        Ash.update(completed, %{reason: "Too late"},
          action: :cancel,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end

    test "returns error when cancelling an already-cancelled task" do
      task = create_task()

      {:ok, cancelled} =
        Ash.update(task, %{reason: "First cancel"},
          action: :cancel,
          authorize?: false,
          actor: @system_admin
        )

      result =
        Ash.update(cancelled, %{reason: "Double cancel"},
          action: :cancel,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:error, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # PropCheck property tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "created task always has status :pending and retry_count 0" do
    forall _x <- PC.boolean() do
      task = create_task()
      task.status == :pending && task.retry_count == 0
    end
  end

  test "any valid task_type is accepted on create" do
    forall task_type <-
             PC.oneof([
               PC.exactly(:inspection),
               PC.exactly(:cleaning),
               PC.exactly(:lubrication),
               PC.exactly(:adjustment),
               PC.exactly(:replacement),
               PC.exactly(:calibration),
               PC.exactly(:testing),
               PC.exactly(:documentation),
               PC.exactly(:safety_check),
               PC.exactly(:measurement)
             ]) do
      tenant = random_tenant()

      result =
        Ash.create(
          Task,
          %{
            work_order_id: Ash.UUID.generate(),
            task_number: System.unique_integer([:positive]),
            title: "Test Task",
            description: "Test desc",
            instructions: "Test instructions",
            task_type: task_type,
            tenant_id: tenant.id
          },
          action: :create,
          authorize?: false,
          actor: @system_admin
        )

      match?({:ok, _}, result)
    end
  end

  # ---------------------------------------------------------------------------
  # ExUnitProperties tests (EP-GEN-014 compliant)
  # ---------------------------------------------------------------------------

  test "full lifecycle pending→ready→in_progress→completed leaves status :completed" do
    ExUnitProperties.check all(_x <- SD.boolean()) do
      task = create_task()

      {:ok, ready} =
        Ash.update(task, %{}, action: :make_ready, authorize?: false, actor: @system_admin)

      {:ok, started} =
        Ash.update(ready, %{}, action: :start, authorize?: false, actor: @system_admin)

      {:ok, completed} =
        Ash.update(started, %{work_performed: "All steps completed"},
          action: :complete,
          authorize?: false,
          actor: @system_admin
        )

      assert completed.status == :completed
      assert completed.completion_percentage == 100
    end
  end

  test "update_progress with any valid percentage succeeds on in_progress task" do
    ExUnitProperties.check all(percentage <- SD.integer(0..100)) do
      task = create_task() |> start_task()

      result =
        Ash.update(task, %{percentage: percentage},
          action: :update_progress,
          authorize?: false,
          actor: @system_admin
        )

      assert match?({:ok, _}, result)
    end
  end
end
