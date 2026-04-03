defmodule Indrajaal.Transform.GraphGrammarTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Transform.GraphGrammar

  test "module exists" do
    assert Code.ensure_loaded?(GraphGrammar)
  end

  test "apply_rule/3 is exported" do
    assert function_exported?(GraphGrammar, :apply_rule, 3)
  end

  test "apply_rule/3 returns {:ok, graph} with stub impl" do
    host_graph = %{nodes: [:a, :b], edges: [{:a, :b}]}
    rule = %{l: %{}, k: %{}, r: %{}}
    match = %{}

    assert {:ok, result_graph} = GraphGrammar.apply_rule(host_graph, rule, match)
    assert is_map(result_graph)
    assert Map.has_key?(result_graph, :nodes)
    assert Map.has_key?(result_graph, :edges)
  end
end
