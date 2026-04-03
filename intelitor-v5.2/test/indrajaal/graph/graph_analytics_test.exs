defmodule Indrajaal.Graph.GraphAnalyticsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Graph.GraphAnalytics

  test "module exists" do
    assert Code.ensure_loaded?(GraphAnalytics)
  end

  test "centrality/3 is exported" do
    assert function_exported?(GraphAnalytics, :centrality, 3)
  end
end
