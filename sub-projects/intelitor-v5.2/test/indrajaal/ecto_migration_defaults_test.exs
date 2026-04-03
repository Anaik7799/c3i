defmodule Indrajaal.EctoMigrationDefaultsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.EctoMigrationDefaults

  test "module exists" do
    assert Code.ensure_loaded?(EctoMigrationDefaults)
  end
end
