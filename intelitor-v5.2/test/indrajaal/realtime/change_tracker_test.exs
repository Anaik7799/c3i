defmodule Indrajaal.Realtime.ChangeTrackerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Realtime.ChangeTracker

  test "module exists" do
    assert Code.ensure_loaded?(ChangeTracker)
  end

  test "start_link/1 is exported" do
    assert function_exported?(ChangeTracker, :start_link, 1)
  end

  test "DataChange Ecto schema exists" do
    assert Code.ensure_loaded?(Indrajaal.Realtime.DataChange)
  end
end
