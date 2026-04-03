defmodule Indrajaal.Analytics.FlameRunnerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Analytics.FlameRunner

  test "module exists" do
    assert Code.ensure_loaded?(FlameRunner)
  end

  test "aggregate/2 is exported" do
    assert function_exported?(FlameRunner, :aggregate, 2)
  end

  test "generate_report/3 is exported" do
    assert function_exported?(FlameRunner, :generate_report, 3)
  end

  test "analyze_time_series/3 is exported" do
    assert function_exported?(FlameRunner, :analyze_time_series, 3)
  end
end
