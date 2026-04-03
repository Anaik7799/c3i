defmodule Indrajaal.Intelligence.ModelRegistryTest do
  use ExUnit.Case
  alias Indrajaal.Intelligence.ModelRegistry

  test "register_model returns metadata" do
    {:ok, meta} = ModelRegistry.register_model("gpt-4", "v1", "hash123")
    assert meta.name == "gpt-4"
  end
end
