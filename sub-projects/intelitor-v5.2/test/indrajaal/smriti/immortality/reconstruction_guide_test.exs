defmodule Indrajaal.SMRITI.Immortality.ReconstructionGuideTest do
  use ExUnit.Case, async: true
  alias Indrajaal.SMRITI.Immortality.ReconstructionGuide

  describe "Reconstruction Guide" do
    test "generates markdown steps" do
      guide = ReconstructionGuide.generate()
      assert is_binary(guide)
      assert guide =~ "# SMRITI Reconstruction Guide"
      assert guide =~ "## Step 1: Bootstrapping"
    end

    test "validates integrity of steps" do
      steps = ReconstructionGuide.list_steps()
      assert length(steps) > 0
      assert Enum.all?(steps, &Map.has_key?(&1, :id))
      assert Enum.all?(steps, &Map.has_key?(&1, :instruction))
    end
  end
end
