defmodule Indrajaal.SMRITI.Automation.NodeBootstrapTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Automation.NodeBootstrap

  describe "Node Bootstrap" do
    test "generates bootstrap sequence" do
      steps = NodeBootstrap.generate_sequence("node_test_1")
      assert length(steps) > 0
      assert List.first(steps) =~ "Initializing node_test_1"
    end

    test "verifies bootstrap status" do
      assert NodeBootstrap.status("node_test_1") == :pending
    end
  end
end
