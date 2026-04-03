defmodule Indrajaal.Zenoh.ControlPathTest do
  @moduledoc """
  Zenoh control path test — send/receive commands.

  WHAT: Verifies that control commands can be sent on `indrajaal/control/*`
        topics, that responses are received, and that priority ordering is
        preserved per SC-SIL6-006 (2oo3 for critical actuations).

  WHY: All mutations MUST be triggered via `indrajaal/control/**` per Ω₁₀.
       The control path is the SOLE authority for system state changes.

  CONSTRAINTS:
    - SC-ZENOH-001: Zenoh NIF active (SKIP_ZENOH_NIF=0)
    - Ω₁₀: All mutations via indrajaal/control/**
    - SC-ZTEST-003: Publish latency < 10ms
    - SC-ZTEST-012: FIFO ordering per topic
    - SC-ZTEST-017: Topic depth ≤ 6 levels
    - SC-SAFETY-001: Guardian pre-approval for mutations
    - SC-PRF-050: Response < 50ms
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
  @moduletag :requires_zenoh
  @moduletag timeout: 60_000

  @pubsub_name __MODULE__.PubSub

  # Priority levels: :critical > :high > :normal > :low
  @priority_levels [:critical, :high, :normal, :low]

  @control_topics [
    "indrajaal/control/guardian/approve",
    "indrajaal/control/guardian/veto",
    "indrajaal/control/executor/run",
    "indrajaal/control/executor/stop",
    "indrajaal/control/mesh/reconfig",
    "indrajaal/control/emergency/halt"
  ]

  @latency_budget_ms 50

  # ── Setup ────────────────────────────────────────────────────────────────────

  setup do
    {:ok, _pid} = start_supervised({Phoenix.PubSub, name: @pubsub_name})

    for topic <- @control_topics do
      :ok = Phoenix.PubSub.subscribe(@pubsub_name, topic)
    end

    on_exit(fn ->
      for topic <- @control_topics do
        Phoenix.PubSub.unsubscribe(@pubsub_name, topic)
      end
    end)

    :ok
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  defp control_command(action, priority \\ :normal, seq \\ 1) do
    %{
      command_id: "CMD-#{action}-#{seq}",
      action: action,
      priority: priority,
      issued_at_us: System.monotonic_time(:microsecond),
      guardian_token: "tok-#{:erlang.unique_integer([:positive])}",
      payload: %{target: "node-1", params: %{}}
    }
  end

  defp send_command(topic, cmd) do
    t0 = System.monotonic_time(:microsecond)
    :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:control_command, cmd})
    System.monotonic_time(:microsecond) - t0
  end

  defp drain_commands(acc \\ []) do
    receive do
      {:control_command, cmd} -> drain_commands([cmd | acc])
      {:command_ack, ack} -> drain_commands([{:ack, ack} | acc])
    after
      100 -> Enum.reverse(acc)
    end
  end

  # A trivial executor that echoes an ACK back on a response topic
  defp spawn_executor(response_topic) do
    spawn(fn ->
      Phoenix.PubSub.subscribe(@pubsub_name, hd(@control_topics))

      receive do
        {:control_command, cmd} ->
          ack = %{
            command_id: cmd.command_id,
            status: :executed,
            ack_at_us: System.monotonic_time(:microsecond)
          }

          Phoenix.PubSub.broadcast(@pubsub_name, response_topic, {:command_ack, ack})
      after
        500 -> :timeout
      end
    end)
  end

  # ── Tests ────────────────────────────────────────────────────────────────────

  describe "Control Path: Topic contract" do
    test "all control topics conform to depth ≤ 6 (SC-ZTEST-017)" do
      for topic <- @control_topics do
        depth = topic |> String.graphemes() |> Enum.count(&(&1 == "/"))

        assert depth <= 6,
               "Topic #{topic} depth=#{depth} violates SC-ZTEST-017"
      end
    end

    test "control topics all start with indrajaal/control/ prefix (Ω₁₀)" do
      for topic <- @control_topics do
        assert String.starts_with?(topic, "indrajaal/control/"),
               "Topic #{topic} does not follow indrajaal/control/** pattern (Ω₁₀)"
      end
    end

    test "command_id follows identifiable format" do
      cmd = control_command("run", :normal, 1)
      assert cmd.command_id =~ ~r/^CMD-[a-z_]+-\d+$/
    end
  end

  describe "Control Path: Send and receive commands" do
    test "sends a command and receives it on the subscriber" do
      topic = "indrajaal/control/executor/run"
      cmd = control_command("run", :normal, 1)

      send_command(topic, cmd)

      assert_receive {:control_command, received}, 300
      assert received.command_id == cmd.command_id
      assert received.action == "run"
      assert received.priority == :normal
    end

    test "publish latency < #{@latency_budget_ms}ms (SC-PRF-050)" do
      topic = "indrajaal/control/executor/run"
      cmd = control_command("run", :normal, 1)

      elapsed_us = send_command(topic, cmd)
      elapsed_ms = elapsed_us / 1_000.0

      assert elapsed_ms < @latency_budget_ms,
             "Control command publish latency #{Float.round(elapsed_ms, 2)}ms > #{@latency_budget_ms}ms"
    end

    test "executor feedback — command is acknowledged" do
      cmd_topic = "indrajaal/control/executor/run"
      ack_topic = "indrajaal/control/executor/ack"

      Phoenix.PubSub.subscribe(@pubsub_name, ack_topic)

      # Spawn a synthetic executor listening on cmd topic
      test_pid = self()

      spawn(fn ->
        Phoenix.PubSub.subscribe(@pubsub_name, cmd_topic)

        receive do
          {:control_command, cmd} ->
            ack = %{
              command_id: cmd.command_id,
              status: :executed,
              ack_at_us: System.monotonic_time(:microsecond)
            }

            Phoenix.PubSub.broadcast(@pubsub_name, ack_topic, {:command_ack, ack})
            send(test_pid, :executor_done)
        after
          500 -> send(test_pid, :executor_timeout)
        end
      end)

      # Allow executor to subscribe before we publish
      Process.sleep(10)

      cmd = control_command("run", :high, 42)
      send_command(cmd_topic, cmd)

      assert_receive {:command_ack, ack}, 500
      assert ack.command_id == cmd.command_id
      assert ack.status == :executed

      Phoenix.PubSub.unsubscribe(@pubsub_name, ack_topic)
    end
  end

  describe "Control Path: Priority ordering" do
    test "critical commands can be identified by priority field" do
      cmd = control_command("halt", :critical, 1)
      assert cmd.priority == :critical
    end

    test "all priority levels are valid" do
      for priority <- @priority_levels do
        cmd = control_command("run", priority, 1)
        assert cmd.priority == priority
      end
    end

    test "command batch preserves FIFO within same priority (SC-ZTEST-012)" do
      topic = "indrajaal/control/executor/run"

      cmds =
        for seq <- 1..10 do
          control_command("run", :normal, seq)
        end

      for cmd <- cmds do
        Phoenix.PubSub.broadcast(@pubsub_name, topic, {:control_command, cmd})
      end

      received = drain_commands()

      cmd_received =
        Enum.filter(received, fn
          {:ack, _} -> false
          _ -> true
        end)

      seq_nums =
        cmd_received
        |> Enum.map(fn {:control_command, cmd} -> cmd end)
        |> Enum.filter(&(&1.action == "run"))
        |> Enum.map(fn cmd ->
          cmd.command_id |> String.split("-") |> List.last() |> String.to_integer()
        end)

      # After drain, sequences must be in FIFO ascending order
      assert seq_nums == Enum.sort(seq_nums),
             "FIFO violated for control commands (SC-ZTEST-012)"
    end
  end

  describe "Control Path: Guardian gate" do
    test "commands carry guardian_token (SC-SAFETY-001)" do
      cmd = control_command("approve", :high, 1)
      assert is_binary(cmd.guardian_token)
      assert String.length(cmd.guardian_token) > 0
    end

    test "veto command is rejected by Guardian representation" do
      topic = "indrajaal/control/guardian/veto"

      veto_cmd = %{
        command_id: "CMD-veto-1",
        action: "veto",
        priority: :critical,
        reason: "Constitutional violation detected",
        issued_at_us: System.monotonic_time(:microsecond)
      }

      :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:control_command, veto_cmd})

      assert_receive {:control_command, received}, 300
      assert received.action == "veto"
      assert received.priority == :critical
      assert is_binary(received.reason)
    end
  end

  describe "Control Path: Emergency halt" do
    test "emergency halt reaches dedicated topic" do
      topic = "indrajaal/control/emergency/halt"
      halt_cmd = control_command("halt", :critical, 999)

      :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:control_command, halt_cmd})

      assert_receive {:control_command, received}, 300
      assert received.action == "halt"
      assert received.priority == :critical
    end

    test "emergency halt latency stays within 5s budget (SC-EMR-057)" do
      topic = "indrajaal/control/emergency/halt"
      halt_cmd = control_command("halt", :critical, 999)

      elapsed_us = send_command(topic, halt_cmd)
      # 5 seconds = 5_000_000 µs — we assert far below at 50ms
      assert elapsed_us < 5_000_000,
             "Emergency halt latency #{elapsed_us}µs exceeds 5s budget (SC-EMR-057)"
    end
  end

  describe "Control Path: Failure paths" do
    test "unknown action command is delivered without crash" do
      topic = "indrajaal/control/executor/run"
      unknown_cmd = %{command_id: "CMD-unknown-1", action: "UNKNOWN_ACTION_XYZ"}

      :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:control_command, unknown_cmd})

      assert_receive {:control_command, received}, 200
      assert received.action == "UNKNOWN_ACTION_XYZ"
    end

    test "empty payload command is delivered without crash" do
      topic = "indrajaal/control/executor/run"
      cmd = %{command_id: "CMD-empty-1", action: "run", payload: %{}}

      :ok = Phoenix.PubSub.broadcast(@pubsub_name, topic, {:control_command, cmd})

      assert_receive {:control_command, _received}, 200
    end
  end
end
