defmodule Indrajaal.Intelligence.EntryTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Intelligence.Entry

  test "module exists" do
    assert Code.ensure_loaded?(Entry)
  end

  test "health_check/0 is exported" do
    assert function_exported?(Entry, :health_check, 0)
  end

  test "health_check/0 returns a map" do
    result = Entry.health_check()
    assert is_map(result)
  end
end
