defmodule Indrajaal.TracingTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Tracing

  test "module exists" do
    assert Code.ensure_loaded?(Tracing)
  end

  test "with_span/3 is exported" do
    assert function_exported?(Tracing, :with_span, 3)
  end

  test "set_error/2 is exported" do
    assert function_exported?(Tracing, :set_error, 2)
  end
end
