defmodule Indrajaal.PropertyTestingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  # PropertyTesting is wrapped in `if false do` so it never compiles.
  # This test verifies that behavior.
  test "module does not exist at runtime (wrapped in if false)" do
    refute Code.ensure_loaded?(Indrajaal.PropertyTesting)
  end
end
