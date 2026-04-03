defmodule Indrajaal.IntegrationContextTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.IntegrationContext

  test "module exists" do
    assert Code.ensure_loaded?(IntegrationContext)
  end
end
