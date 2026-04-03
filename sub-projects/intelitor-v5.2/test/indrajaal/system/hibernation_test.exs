defmodule Indrajaal.System.HibernationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.System.Hibernation

  test "module exists" do
    assert Code.ensure_loaded?(Hibernation)
  end

  test "start_link/1 is exported" do
    assert function_exported?(Hibernation, :start_link, 1)
  end
end
