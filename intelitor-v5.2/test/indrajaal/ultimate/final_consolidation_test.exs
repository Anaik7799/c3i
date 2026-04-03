defmodule Indrajaal.Ultimate.FinalConsolidationTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.FinalConsolidation

  test "module is loaded" do
    assert Code.ensure_loaded?(FinalConsolidation)
  end

  test "with_universal macro is defined" do
    # defmacro with_universal(clauses, do: ..., else: ...) — arity varies by Elixir conventions.
    # Check that any arity of with_universal is exported as a macro.
    macros = FinalConsolidation.__info__(:macros)

    assert Enum.any?(macros, fn {name, _arity} -> name == :with_universal end),
           "Expected :with_universal macro to be defined in FinalConsolidation"
  end

  test "universal_pipeline/2 is defined" do
    assert function_exported?(FinalConsolidation, :universal_pipeline, 2)
  end

  test "universal_pipeline/2 processes empty operation list" do
    result = FinalConsolidation.universal_pipeline("data", [])
    assert result == {:ok, "data"}
  end

  test "universal_pipeline/2 applies operations in sequence" do
    ops = [
      fn x -> {:ok, x <> "_step1"} end,
      fn x -> {:ok, x <> "_step2"} end
    ]

    assert {:ok, "start_step1_step2"} = FinalConsolidation.universal_pipeline("start", ops)
  end

  test "universal_pipeline/2 halts on error" do
    ops = [
      fn _x -> {:error, :stopped} end,
      fn x -> {:ok, x <> "_should_not_run"} end
    ]

    assert {:error, :stopped} = FinalConsolidation.universal_pipeline("data", ops)
  end
end
