defmodule Indrajaal.KmsRepoTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KmsRepo

  test "module exists" do
    assert Code.ensure_loaded?(KmsRepo)
  end

  test "is an Ecto.Repo" do
    assert function_exported?(KmsRepo, :__adapter__, 0)
  end
end
