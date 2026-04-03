defmodule Indrajaal.Observability.ClusterInstrumentationTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias Indrajaal.Observability.ClusterInstrumentation

  @moduledoc """
  TDG Compliance: Tests for ClusterInstrumentation
  Covers: Telemetry attachment, Event handling, Metric polling
  """

  describe "setup/0" do
    test "attaches telemetry handlers" do
      # We can't easily check internal handler list, but we can verify
      # that executing an event logs output.
      ClusterInstrumentation.setup()

      log =
        capture_log(fn ->
          :telemetry.execute(
            [:libcluster, :handler, :nodeup],
            %{},
            %{node: :node@test, topology: :local}
          )
        end)

      assert log =~ "Cluster Node UP"
      assert log =~ "node@test"
    end
  end

  describe "handle_info/2 polling" do
    test "emits cluster size metrics" do
      # Start the GenServer in isolation
      {:ok, pid} = ClusterInstrumentation.start_link()

      # Subscribe to the metric event
      self_pid = self()

      :telemetry.attach(
        "test-cluster-size",
        [:indrajaal, :cluster, :size],
        fn _name, measurements, metadata, _config ->
          send(self_pid, {:metric, measurements, metadata})
        end,
        nil
      )

      # Trigger poll manually
      send(pid, :poll_metrics)

      assert_receive {:metric, %{value: size}, %{node: _node}}
      # At least self
      assert size >= 1

      # Cleanup
      :telemetry.detach("test-cluster-size")
      GenServer.stop(pid)
    end
  end

  describe "telemetry handlers" do
    test "logs nodeup" do
      log =
        capture_log(fn ->
          ClusterInstrumentation.handle_event(
            [:libcluster, :handler, :nodeup],
            %{},
            %{node: :new@test, topology: :test},
            %{}
          )
        end)

      assert log =~ "Cluster Node UP"
      assert log =~ "new@test"
    end

    test "logs nodedown" do
      log =
        capture_log(fn ->
          ClusterInstrumentation.handle_event(
            [:libcluster, :handler, :nodedown],
            %{},
            %{node: :dead@test, topology: :test},
            %{}
          )
        end)

      assert log =~ "Cluster Node DOWN"
      assert log =~ "dead@test"
    end

    test "logs reconnect" do
      log =
        capture_log(fn ->
          ClusterInstrumentation.handle_event(
            [:libcluster, :handler, :reconnect],
            %{},
            %{node: :retry@test, topology: :test},
            %{}
          )
        end)

      assert log =~ "Cluster Node Reconnecting"
      assert log =~ "retry@test"
    end
  end
end
