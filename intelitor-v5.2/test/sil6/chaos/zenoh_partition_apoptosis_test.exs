defmodule Indrajaal.Chaos.ZenohPartitionApoptosisTest do
  use ExUnit.Case, async: false

  alias Indrajaal.Cluster.Apoptosis
  alias Indrajaal.Cluster.Sentinel

  @moduledoc """
  S54-T109: Zenoh Partition / Apoptosis Chaos Test (P1)

  Validates SC-SIL6-015 and SC-SIL6-011: 
  A network partition dropping the node below floor(N/2)+1 quorum 
  MUST trigger the 6-phase Apoptosis protocol and prevent split-brain.
  """

  # Define a mock for the Zenoh session to simulate network partition
  defmodule MockZenohSession do
    use GenServer

    def start_link(_) do
      GenServer.start_link(__MODULE__, %{partitioned: false},
        name: Indrajaal.Observability.ZenohSession
      )
    end

    def init(state), do: {:ok, state}

    def simulate_partition do
      # In this mock, we simulate dropping all peer connections
      # by sending :nodedown to Sentinel
      send(Sentinel, {:nodedown, :"app-2@tailnet.ts.net", %{}})
      send(Sentinel, {:nodedown, :"app-3@tailnet.ts.net", %{}})
    end

    # Mock the emergency publish to capture the dying gasp
    def handle_call({:publish_emergency, topic, payload}, _from, state) do
      send(:test_runner, {:dying_gasp, topic, payload})
      {:reply, :ok, state}
    end
  end

  setup do
    # 1. Setup Mock Zenoh and Sentinel
    Process.register(self(), :test_runner)

    {:ok, _mock_zenoh} = MockZenohSession.start_link([])

    # Mock the Apoptosis target to send a message instead of actually terminating the VM
    original_stop = Application.get_env(:indrajaal, :apoptosis_terminator, &System.stop/1)

    Application.put_env(:indrajaal, :apoptosis_terminator, fn exit_code ->
      send(:test_runner, {:system_terminated, exit_code})
    end)

    # Start Sentinel with total_expected=3, so Quorum is div(3,2)+1 = 2
    {:ok, sentinel_pid} = Sentinel.start_link(total_expected: 3)

    on_exit(fn ->
      Application.put_env(:indrajaal, :apoptosis_terminator, original_stop)
      if Process.alive?(sentinel_pid), do: GenServer.stop(sentinel_pid)
      if pid = Process.whereis(Indrajaal.Observability.ZenohSession), do: GenServer.stop(pid)
    end)

    {:ok, %{sentinel_pid: sentinel_pid}}
  end

  test "network partition triggers apoptosis and dying gasp", %{sentinel_pid: sentinel_pid} do
    # 1. Verify initial healthy quorum state (simulated)
    # We'll pretend app-2 and app-3 are up
    send(sentinel_pid, {:nodeup, :"app-2@tailnet.ts.net", %{}})
    send(sentinel_pid, {:nodeup, :"app-3@tailnet.ts.net", %{}})

    Process.sleep(100)
    status = Sentinel.get_status(sentinel_pid)
    assert status.status == :healthy

    # 2. Simulate Network Partition
    # Loss of 2 nodes leaves only current node (1), which is < 2 quorum
    MockZenohSession.simulate_partition()

    # 3. Wait for Sentinel to detect the loss and trigger Apoptosis
    # In test mode, we might need to trigger the check manually or wait

    # 4. Validate Dying Gasp message (captured via MockZenohSession.publish_emergency)
    # We expect Sentinel to call Apoptosis which calls ZenohSession.publish_emergency
    # Since we mocked ZenohSession, we need to make sure Apoptosis calls it correctly.

    assert_receive {:dying_gasp, "indrajaal/cluster/apoptosis", payload}, 10000

    assert payload.reason =~ "Quorum lost"
    assert Map.has_key?(payload, :timestamp)

    # 5. Validate process termination
    assert_receive {:system_terminated, 137}, 5000
  end
end
