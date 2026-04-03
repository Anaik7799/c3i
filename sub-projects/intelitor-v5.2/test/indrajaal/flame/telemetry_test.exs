defmodule Indrajaal.FLAME.TelemetryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FLAME.Telemetry, as: FlameTelemetry

  # Use a unique handler name prefix per test run to avoid conflicts with
  # other test processes attaching the same handler ID.
  @handler_id "indrajaal-flame-telemetry"

  setup do
    # Ensure the handler is detached before each test
    :telemetry.detach(@handler_id)
    on_exit(fn -> :telemetry.detach(@handler_id) end)
    :ok
  end

  describe "attach/0" do
    test "returns :ok on first attach" do
      assert :ok = FlameTelemetry.attach()
    end

    test "registers the handler under the expected handler id" do
      FlameTelemetry.attach()
      handlers = :telemetry.list_handlers([:flame, :pool, :start])
      ids = Enum.map(handlers, & &1.id)
      assert @handler_id in ids
    end

    test "attaches a handler that covers all 8 FLAME event types" do
      FlameTelemetry.attach()

      flame_events = [
        [:flame, :pool, :start],
        [:flame, :pool, :stop],
        [:flame, :runner, :start],
        [:flame, :runner, :stop],
        [:flame, :runner, :exception],
        [:flame, :call, :start],
        [:flame, :call, :stop],
        [:flame, :call, :exception]
      ]

      for event <- flame_events do
        handlers = :telemetry.list_handlers(event)
        ids = Enum.map(handlers, & &1.id)

        assert @handler_id in ids,
               "Expected handler #{@handler_id} to be attached for event #{inspect(event)}"
      end
    end
  end

  describe "detach/0" do
    test "returns :ok when handler was attached" do
      FlameTelemetry.attach()
      assert :ok = FlameTelemetry.detach()
    end

    test "removes the handler from all FLAME events" do
      FlameTelemetry.attach()
      FlameTelemetry.detach()
      handlers = :telemetry.list_handlers([:flame, :pool, :start])
      ids = Enum.map(handlers, & &1.id)
      refute @handler_id in ids
    end

    test "detach after detach does not crash" do
      FlameTelemetry.attach()
      FlameTelemetry.detach()
      # Second detach — telemetry returns error tuple but we do not crash
      result = FlameTelemetry.detach()
      assert result in [:ok, {:error, :not_found}]
    end
  end

  describe "handle_event/4 — pool stop" do
    test "pool stop event emits re-broadcast telemetry event" do
      test_pid = self()

      :telemetry.attach(
        "test-flame-pool-stop-#{inspect(test_pid)}",
        [:indrajaal, :flame, :pool, :stop],
        fn _event, measurements, metadata, _cfg ->
          send(test_pid, {:rebroadcast, measurements, metadata})
        end,
        nil
      )

      FlameTelemetry.handle_event(
        [:flame, :pool, :stop],
        %{duration: 5_000_000},
        %{pool: MyPool},
        nil
      )

      assert_receive {:rebroadcast, measurements, metadata}, 500
      assert measurements.duration_ms == 5
      assert metadata.pool_name == MyPool
    after
      :telemetry.detach("test-flame-pool-stop-#{inspect(self())}")
    end
  end

  describe "handle_event/4 — call stop" do
    test "call stop event re-broadcasts with duration_ms computed" do
      test_pid = self()

      :telemetry.attach(
        "test-flame-call-stop-#{inspect(test_pid)}",
        [:indrajaal, :flame, :call, :complete],
        fn _event, measurements, _metadata, _cfg ->
          send(test_pid, {:call_complete, measurements})
        end,
        nil
      )

      FlameTelemetry.handle_event(
        [:flame, :call, :stop],
        %{duration: 2_000_000},
        %{pool: OtherPool},
        nil
      )

      assert_receive {:call_complete, measurements}, 500
      assert measurements.duration_ms == 2
    after
      :telemetry.detach("test-flame-call-stop-#{inspect(self())}")
    end
  end

  describe "handle_event/4 — catch-all" do
    test "unrecognised event returns :ok" do
      result =
        FlameTelemetry.handle_event(
          [:flame, :unknown, :event],
          %{some: :measurement},
          %{},
          nil
        )

      assert result == :ok
    end
  end
end
