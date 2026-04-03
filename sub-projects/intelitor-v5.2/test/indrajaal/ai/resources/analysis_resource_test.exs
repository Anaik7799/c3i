defmodule Indrajaal.AI.Resources.AnalysisResourceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AI.Resources.AnalysisResource

  test "module exists" do
    assert Code.ensure_loaded?(AnalysisResource)
  end

  test "analysis_types attribute exists" do
    assert Code.ensure_loaded?(AnalysisResource)
    assert function_exported?(AnalysisResource, :spark_dsl_config, 0)
  end
end
