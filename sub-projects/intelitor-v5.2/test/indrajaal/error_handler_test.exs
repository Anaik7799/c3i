defmodule Indrajaal.ErrorHandlerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.ErrorHandler

  test "module exists" do
    assert Code.ensure_loaded?(ErrorHandler)
  end

  test "handle_error/2 is exported" do
    assert function_exported?(ErrorHandler, :handle_error, 2)
  end
end
