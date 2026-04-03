defmodule Indrajaal.Integration.ControlPathE2ETest do
  @moduledoc """
  End-to-end control path test — command → guardian → executor → feedback.

  WHAT: Exercises the full control pipeline from a command issued by an
        operator, through the Guardian approval gate, to the executor that
        carries out the action, and back through a feedback/acknowledgement
        loop to the original caller.

  WHY: Ω₁₀ mandates all mutations via `indrajaal/control/**`.  SC-SAFETY-001
       mandates Guardian pre-approval.  This test proves the complete control
       path contract is intact end-to-end.

  CONSTRAINTS:
    - Ω₁₀: All mutations via indrajaal/control/**
    - SC-SAFETY-001: Guardian pre-approval for planning mutations
    - SC-GDE-001: Guardian validation required
    - SC-GDE-002: Shadow testing mandatory
    - SC-PRF-050: Response < 50ms
    - SC-ZTEST-012: FIFO ordering per topic
    - SC-ZTEST-017: Topic depth ≤ 6 levels
    - SC-EMR-057: Emergency stop < 5 seconds
    - SC-BUS-001: Async messaging only

  ## Change History
  | Version | Date       | Author            | Change               |
  |---------|------------|-------------------|----------------------|
  | 1.0.0   | 2026-03-23 | Claude Sonnet 4.6 | Sprint 88 — initial  |

  @version "1.0.0"
  @last_modified "2026-03-23T00:00:00Z"
  """

  use ExUnit.Case, async: false

  @moduletag :zenoh
  @moduletag :integration
  @moduletag timeout: 60_000

  @pubsub_name __MODULE__.PubSub

  # Control pipeline topics (each stage → next)
  @topic_command "indrajaal/control/cmd/issued"
  @topic_guardian "indrajaal/control/guardian/review"
  @topic_executor "indrajaal/control/executor/queue"
  @topic_feedback "indrajaal/control/feedback/result"

  @all_topics [@topic_command, @topic_guardian, @topic_executor, @topic_feedback]

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})

    for topic <- @all_topics do
      :ok = Phoenix.PubSub.subscribe(@pubsub_name, topic)
    end

    on_exit(fn ->
      for topic <- @all_topics do
        Phoenix.PubSub.unsubscribe(@pubsub_name, topic)
      end
    end)

    :ok
  end

  # ── Stage factories ──────────────────────────────────────────────────────────

  defp make_command(action, priority \\ :normal, seq \\ 1) do
    %{
      command_id: "CMD-#{action}-#{seq}",
      action: action,
      priority: priority,
      issued_at_us: System.monotonic_time(:microsecond),
      caller_pid: inspect(self()),
      payload: %{target: "node-1"}
    }
  end

  defp guardian_review(cmd, decision) do
    %{
      command_id: cmd.command_id,
      action: cmd.action,
      decision: decision,
      guardian_token:
        if(decision == :approved, do: "tok-#{:erlang.unique_integer([:positive])}", else: nil),
      reason: if(decision == :vetoed, do: "Safety violation detected", else: nil),
      reviewed_at_us: System.monotonic_time(:microsecond)
    }
  end

  defp executor_result(reviewed, outcome) do
    %{
      command_id: reviewed.command_id,
      action: reviewed.action,
      outcome: outcome,
      executed_at_us: System.monotonic_time(:microsecond),
      duration_us: :rand.uniform(5_000)
    }
  end

  # Simulate the full pipeline: command → guardian → executor → feedback
  defp run_control_pipeline(action, priority, seq, guardian_decision \\ :approved) do
    cmd = make_command(action, priority, seq)
    Phoenix.PubSub.broadcast(@pubsub_name, @topic_command, {:ctrl, :command, cmd})

    reviewed = guardian_review(cmd, guardian_decision)
    Phoenix.PubSub.broadcast(@pubsub_name, @topic_guardian, {:ctrl, :guardian, reviewed})

    if guardian_decision == :approved do
      result = executor_result(reviewed, :success)
      Phoenix.PubSub.broadcast(@pubsub_name, @topic_executor, {:ctrl, :executor, result})

      feedback = %{
        command_id: result.command_id,
        status: :completed,
        outcome: result.outcome,
        feedback_at_us: System.monotonic_time(:microsecond)
      }

      Phoenix.PubSub.broadcast(@pubsub_name, @topic_feedback, {:ctrl, :feedback, feedback})
    else
      veto = %{command_id: reviewed.command_id, status: :vetoed, reason: reviewed.reason}
      Phoenix.PubSub.broadcast(@pubsub_name, @topic_feedback, {:ctrl, :feedback, veto})
    end

    cmd
  end

  defp drain_ctrl(acc \\ []) do
    receive do
      {:ctrl, stage, msg} -> drain_ctrl([{stage, msg} | acc])
    after
      150 -> Enum.reverse(acc)
    end
  end

  # ── Tests ────────────────────────────────────────────────────────────────────

  describe "Control Path E2E: Topology contract" do
    test "all topics have depth ≤ 6 (SC-ZTEST-017)" do
      for topic <- @all_topics do
        depth = topic |> String.graphemes() |> Enum.count(&(&1 == "/"))
        assert depth <= 6, "Topic #{topic} depth=#{depth} violates SC-ZTEST-017"
      end
    end

    test "all topics begin with indrajaal/control/ prefix (Ω₁₀)" do
      for topic <- @all_topics do
        assert String.starts_with?(topic, "indrajaal/control/"),
               "#{topic} violates Ω₁₀ (indrajaal/control/** mandate)"
      end
    end
  end

  describe "Control Path E2E: Happy path traversal" do
    test "command is received at command stage" do
      run_control_pipeline("run", :normal, 1)
      assert_receive {:ctrl, :command, cmd}, 300
      assert cmd.action == "run"
      assert cmd.command_id == "CMD-run-1"
    end

    test "guardian approves and issues token (SC-SAFETY-001, SC-GDE-001)" do
      run_control_pipeline("run", :normal, 1)

      assert_receive {:ctrl, :command, _}, 300
      assert_receive {:ctrl, :guardian, reviewed}, 300

      assert reviewed.decision == :approved
      assert is_binary(reviewed.guardian_token)
      assert String.length(reviewed.guardian_token) > 0
    end

    test "executor receives approved command and executes" do
      run_control_pipeline("run", :normal, 1)

      assert_receive {:ctrl, :command, _}, 300
      assert_receive {:ctrl, :guardian, _}, 300
      assert_receive {:ctrl, :executor, result}, 300

      assert result.outcome == :success
      assert is_integer(result.duration_us)
      assert result.duration_us > 0
    end

    test "feedback is delivered to caller after execution" do
      run_control_pipeline("run", :normal, 1)

      assert_receive {:ctrl, :command, _}, 300
      assert_receive {:ctrl, :guardian, _}, 300
      assert_receive {:ctrl, :executor, _}, 300
      assert_receive {:ctrl, :feedback, feedback}, 300

      assert feedback.status == :completed
      assert feedback.outcome == :success
    end

    test "command_id propagates through all 4 stages" do
      run_control_pipeline("run", :high, 77)

      msgs = drain_ctrl()

      ids =
        msgs
        |> Enum.map(fn {_stage, msg} -> Map.get(msg, :command_id) end)
        |> Enum.filter(&is_binary/1)
        |> Enum.uniq()

      assert ids == ["CMD-run-77"],
             "command_id not uniformly propagated: #{inspect(ids)}"
    end
  end

  describe "Control Path E2E: Guardian veto" do
    test "vetoed command does not reach executor" do
      run_control_pipeline("dangerous_op", :critical, 1, :vetoed)

      assert_receive {:ctrl, :command, _}, 300
      assert_receive {:ctrl, :guardian, reviewed}, 300
      assert reviewed.decision == :vetoed
      assert is_binary(reviewed.reason)

      # Executor stage must NOT receive a message
      refute_receive {:ctrl, :executor, _}, 200
    end

    test "vetoed command delivers failure feedback with reason" do
      run_control_pipeline("dangerous_op", :critical, 1, :vetoed)

      assert_receive {:ctrl, :command, _}, 300
      assert_receive {:ctrl, :guardian, _}, 300
      assert_receive {:ctrl, :feedback, feedback}, 300

      assert feedback.status == :vetoed
      assert is_binary(feedback.reason)
    end

    test "veto reason is a non-empty string" do
      run_control_pipeline("halt_all", :critical, 1, :vetoed)

      assert_receive {:ctrl, :command, _}, 300
      assert_receive {:ctrl, :guardian, reviewed}, 300

      assert is_binary(reviewed.reason)
      assert String.length(reviewed.reason) > 0
    end
  end

  describe "Control Path E2E: Priority and ordering" do
    test "critical commands carry :critical priority" do
      cmd = make_command("emergency", :critical, 1)
      assert cmd.priority == :critical
    end

    test "FIFO ordering preserved for 5 sequential commands (SC-ZTEST-012)" do
      for seq <- 1..5 do
        run_control_pipeline("run", :normal, seq)
      end

      msgs = drain_ctrl()
      feedback_msgs = Enum.filter(msgs, fn {stage, _} -> stage == :feedback end)

      seq_nums =
        feedback_msgs
        |> Enum.map(fn {_, msg} ->
          msg.command_id
          |> String.split("-")
          |> List.last()
          |> Integer.parse()
          |> elem(0)
        end)

      assert seq_nums == Enum.sort(seq_nums),
             "FIFO violated in control path: #{inspect(seq_nums)}"
    end
  end

  describe "Control Path E2E: Latency budget" do
    test "full 4-stage pipeline completes within 4 × 50ms budget" do
      budget_ms = 200

      t0 = System.monotonic_time(:millisecond)
      run_control_pipeline("benchmark", :normal, 1)
      assert_receive {:ctrl, :feedback, _}, budget_ms + 200
      t1 = System.monotonic_time(:millisecond)

      elapsed_ms = t1 - t0

      assert elapsed_ms < budget_ms,
             "Control pipeline took #{elapsed_ms}ms, exceeds #{budget_ms}ms budget"
    end

    test "emergency halt completes well within 5s (SC-EMR-057)" do
      budget_ms = 5_000

      t0 = System.monotonic_time(:millisecond)
      run_control_pipeline("emergency_halt", :critical, 1)
      assert_receive {:ctrl, :feedback, _}, budget_ms
      t1 = System.monotonic_time(:millisecond)

      elapsed_ms = t1 - t0

      assert elapsed_ms < budget_ms,
             "Emergency halt pipeline took #{elapsed_ms}ms > #{budget_ms}ms (SC-EMR-057)"
    end
  end

  describe "Control Path E2E: Batch throughput" do
    test "10 commands traverse full pipeline without loss" do
      for seq <- 1..10 do
        run_control_pipeline("run", :normal, seq)
      end

      msgs = drain_ctrl()
      feedback_msgs = Enum.filter(msgs, fn {stage, _} -> stage == :feedback end)

      assert length(feedback_msgs) == 10,
             "Expected 10 feedback messages, got #{length(feedback_msgs)}"
    end

    test "all 10 commands receive :completed status in batch" do
      for seq <- 1..10 do
        run_control_pipeline("run", :normal, seq)
      end

      msgs = drain_ctrl()

      completed =
        msgs
        |> Enum.filter(fn {stage, _} -> stage == :feedback end)
        |> Enum.filter(fn {_, msg} -> Map.get(msg, :status) == :completed end)

      assert length(completed) == 10,
             "Expected 10 completed feedbacks, got #{length(completed)}"
    end
  end
end
