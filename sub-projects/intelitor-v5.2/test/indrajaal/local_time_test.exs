defmodule Indrajaal.LocalTimeTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.LocalTime

  test "module exists" do
    assert Code.ensure_loaded?(LocalTime)
  end

  test "now/0 is exported" do
    assert function_exported?(LocalTime, :now, 0)
  end

  test "timestamp_string/0 is exported" do
    assert function_exported?(LocalTime, :timestamp_string, 0)
  end

  test "for_filename/0 is exported" do
    assert function_exported?(LocalTime, :for_filename, 0)
  end

  test "now/0 returns a DateTime" do
    result = LocalTime.now()
    assert %DateTime{} = result
  end

  test "timestamp_string/0 returns a binary" do
    result = LocalTime.timestamp_string()
    assert is_binary(result)
  end

  test "for_filename/0 returns a binary safe for filenames" do
    result = LocalTime.for_filename()
    assert is_binary(result)
    refute String.contains?(result, " ")
  end
end
