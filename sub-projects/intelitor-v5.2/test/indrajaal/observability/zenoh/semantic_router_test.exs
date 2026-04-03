defmodule Indrajaal.Observability.Zenoh.SemanticRouterTest do
  use ExUnit.Case
  alias Indrajaal.Observability.Zenoh.SemanticRouter

  test "L3: routes critical messages to urgent lane" do
    payload = %{priority: :critical, data: "test"}
    {topic, _} = SemanticRouter.route("base/topic", payload)
    assert String.ends_with?(topic, "/urgent")
  end

  test "L3: routes background messages to batch lane" do
    payload = %{priority: :background, data: "test"}
    {topic, _} = SemanticRouter.route("base/topic", payload)
    assert String.ends_with?(topic, "/batch")
  end
end
