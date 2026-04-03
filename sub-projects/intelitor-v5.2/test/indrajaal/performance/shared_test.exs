defmodule Indrajaal.Performance.SharedTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Performance.Shared

  test "module exists" do
    assert Code.ensure_loaded?(Shared)
  end

  test "default_state/0 is exported" do
    assert function_exported?(Shared, :default_state, 0)
  end

  test "init/1 is exported" do
    assert function_exported?(Shared, :init, 1)
  end

  test "default_state/0 returns a map" do
    result = Shared.default_state()
    assert is_map(result)
  end
end
