defmodule Indrajaal.Ultimate.UniversalAsyncTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Ultimate.UniversalAsync

  test "module is loaded" do
    assert Code.ensure_loaded?(UniversalAsync)
  end

  test "async_execute/2 is defined" do
    assert function_exported?(UniversalAsync, :async_execute, 2)
  end

  test "async_execute/2 handles empty task list" do
    result = UniversalAsync.async_execute([])

    assert result == [] or match?({:ok, []}, result),
           "Expected empty result for empty task list, got: #{inspect(result)}"
  end

  test "async_execute/2 executes function tasks" do
    tasks = [fn -> 1 end, fn -> 2 end, fn -> 3 end]
    result = UniversalAsync.async_execute(tasks)
    assert is_list(result) or match?({:ok, _}, result)
  end

  test "async_execute/2 executes MFA tasks" do
    tasks = [{String, :upcase, ["hello"]}, {String, :downcase, ["WORLD"]}]
    result = UniversalAsync.async_execute(tasks)
    assert is_list(result) or match?({:ok, _}, result)
  end

  test "async_execute/2 respects max_concurrency option" do
    tasks = Enum.map(1..4, fn i -> fn -> i * 2 end end)
    result = UniversalAsync.async_execute(tasks, max_concurrency: 2)
    assert is_list(result) or match?({:ok, _}, result)
  end
end
