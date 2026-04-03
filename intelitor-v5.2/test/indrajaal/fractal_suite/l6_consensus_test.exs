defmodule Indrajaal.FractalSuite.L6ConsensusTest do
  use ExUnit.Case
  alias Indrajaal.Cluster.Consensus

  test "L6: Consensus leader election returns boolean" do
    Consensus.start_link()
    assert is_boolean(Consensus.is_leader?())
  end
end
