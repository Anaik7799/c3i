defmodule Indrajaal.System.SporeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.System.Spore

  test "module exists" do
    assert Code.ensure_loaded?(Spore)
  end

  test "replicate/0 is exported" do
    assert function_exported?(Spore, :replicate, 0)
  end

  test "replicate/0 returns a bash script string" do
    result = Spore.replicate()
    assert is_binary(result)
    assert String.contains?(result, "#!/bin/bash")
    assert String.contains?(result, "INDRAJAAL SPORE")
  end
end
