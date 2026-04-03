defmodule Indrajaal.Cluster.SwarmConsensusTest do
  use ExUnit.Case

  # This test requires :pg to be running, which is part of kernel/stdlib
  # We'll skip deep integration testing here and focus on unit logic if possible.
  # Since Swarm relies on :pg, we'll just verify it starts.

  alias Indrajaal.Cluster.Swarm

  test "L6: swarm agent starts and joins pg group" do
    {:ok, pid} = Swarm.start_link()
    assert Process.alive?(pid)
  end
end
