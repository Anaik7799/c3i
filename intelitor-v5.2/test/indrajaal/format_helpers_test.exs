defmodule Indrajaal.FormatHelpersTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FormatHelpers

  test "module exists" do
    assert Code.ensure_loaded?(FormatHelpers)
  end

  test "format_ports/1 is exported" do
    assert function_exported?(FormatHelpers, :format_ports, 1)
  end

  test "format_ports/1 with list of ports" do
    result = FormatHelpers.format_ports([4000, 4001])
    assert is_binary(result)
  end

  test "format_ports/1 with empty list" do
    result = FormatHelpers.format_ports([])
    assert is_binary(result)
  end
end
