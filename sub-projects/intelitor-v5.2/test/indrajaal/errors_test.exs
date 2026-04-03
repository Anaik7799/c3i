defmodule Indrajaal.ErrorsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors

  test "module exists" do
    assert Code.ensure_loaded?(Errors)
  end

  test "normalize_error/1 is exported" do
    assert function_exported?(Errors, :normalize_error, 1)
  end
end
