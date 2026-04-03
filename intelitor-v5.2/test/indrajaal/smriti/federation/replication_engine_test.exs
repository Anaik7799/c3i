defmodule Indrajaal.SMRITI.Federation.ReplicationEngineTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Federation.ReplicationEngine
  alias Indrajaal.SMRITI.Federation.VersionVector

  describe "Replication Engine" do
    test "calculates delta between vectors" do
      local_vv = VersionVector.new() |> VersionVector.increment("node_a")

      remote_vv =
        VersionVector.new()
        |> VersionVector.increment("node_a")
        |> VersionVector.increment("node_a")

      # Remote is ahead by 1 on node_a
      delta = ReplicationEngine.calculate_delta(local_vv, remote_vv)
      # Needs update up to 2
      assert delta == %{"node_a" => 2}
    end

    test "identifies conflict" do
      local_vv = VersionVector.new() |> VersionVector.increment("node_a")
      remote_vv = VersionVector.new() |> VersionVector.increment("node_b")

      assert {:conflict, _details} = ReplicationEngine.resolve_state(local_vv, remote_vv)
    end
  end
end
