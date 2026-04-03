defmodule Indrajaal.Cluster.SentinelBehaviorTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  alias Indrajaal.Cluster.Sentinel
  require Logger

  @moduledoc """
  STAMP Safety Compliance Test: SC-CLU-002 (Cluster Quorum Integrity)
  TDG Compliance: This test verifies Sentinel behavior *before* implementation.
  """

  # Setup for Sentinel
  setup do
    Application.put_env(:libcluster, :topologies,
      k8s_cluster: [
        strategy: Cluster.Strategy.Kubernetes.DNS,
        config: [
          application_name: :indrajaal,
          polling_interval: 5_000,
          epmd_bind_address: "127.0.0.1"
        ]
      ]
    )

    :ok
  end

  describe "Sentinel Startup and Basic Monitoring" do
    test "Sentinel starts successfully and is a running process" do
      name = Module.concat(Sentinel, "Test_#{System.unique_integer([:positive])}")
      {:ok, pid} = Sentinel.start_link(name: name, total_expected: 1)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end

  describe "Property-Based Quorum Checks (Manual)" do
    test "Sentinel's quorum logic is sound under varying node counts and failures" do
      ExUnitProperties.check all(
                               node_count <- integer(1..5),
                               failed_nodes <- integer(0..5)
                             ) do
        # Clear mailbox from previous iterations
        flush_mailbox()

        # Ensure failed_nodes <= node_count
        failed_nodes = min(failed_nodes, node_count)

        # Assume a simple quorum: > 50% nodes must be up
        min_healthy_nodes = div(node_count, 2) + 1
        healthy_nodes = node_count - failed_nodes

        # Pass node_count as total_expected
        name = Module.concat(Sentinel, "Test_Prop_#{System.unique_integer([:positive])}")

        # Use start_link directly for finer control in property test
        {:ok, pid} = Sentinel.start_link(name: name, total_expected: node_count)

        # Simulate initial cluster
        initial_members = for i <- 1..node_count, do: String.to_atom("node#{i}@example.com")
        send(pid, {:simulate_initial_members, initial_members})
        Process.sleep(10)

        # Simulate failures
        for i <- 1..failed_nodes do
          send(pid, {:simulate_node_leave, String.to_atom("node#{i}@example.com"), self()})
          Process.sleep(2)
        end

        # Wait a bit for processing
        Process.sleep(20)

        is_quorum_lost = Sentinel.is_quorum_lost(pid, node_count - failed_nodes)

        passed =
          if healthy_nodes < min_healthy_nodes do
            # Expect quorum to be lost
            received_lost =
              receive do
                {:quorum_lost, ^pid} -> true
              after
                100 -> false
              end

            received_leave =
              receive do
                {:intentional_leave, ^pid} -> true
              after
                100 -> false
              end

            is_quorum_lost and received_lost and received_leave
          else
            # Expect quorum to be maintained
            received_lost =
              receive do
                {:quorum_lost, ^pid} -> true
              after
                50 -> false
              end

            not is_quorum_lost and not received_lost
          end

        # Cleanup manually
        GenServer.stop(pid)
        passed
      end
    end
  end

  defp flush_mailbox do
    receive do
      _ -> flush_mailbox()
    after
      0 -> :ok
    end
  end
end
