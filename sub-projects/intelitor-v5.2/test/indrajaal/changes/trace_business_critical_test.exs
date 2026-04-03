defmodule Indrajaal.Changes.TraceBusinessCriticalTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Changes.TraceBusinessCritical

  test "module exists" do
    assert Code.ensure_loaded?(TraceBusinessCritical)
  end

  test "implements Ash.Resource.Change behaviour" do
    assert function_exported?(TraceBusinessCritical, :change, 3)
  end
end
