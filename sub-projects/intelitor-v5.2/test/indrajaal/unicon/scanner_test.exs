defmodule Indrajaal.Unicon.ScannerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Unicon.Scanner

  test "module exists" do
    assert Code.ensure_loaded?(Scanner)
  end

  test "scan/2 macro is exported" do
    assert macro_exported?(Scanner, :scan, 2)
  end

  test "move/1 is exported" do
    assert function_exported?(Scanner, :move, 1)
  end

  test "tab/1 is exported" do
    assert function_exported?(Scanner, :tab, 1)
  end

  test "find/1 is exported" do
    assert function_exported?(Scanner, :find, 1)
  end

  test "upto/1 is exported" do
    assert function_exported?(Scanner, :upto, 1)
  end

  test "many/1 is exported" do
    assert function_exported?(Scanner, :many, 1)
  end
end
