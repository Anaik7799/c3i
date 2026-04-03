defmodule Indrajaal.Changes.TraceAndAuditTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Changes.TraceAndAudit

  test "module exists" do
    assert Code.ensure_loaded?(TraceAndAudit)
  end

  test "implements Ash.Resource.Change behaviour" do
    assert function_exported?(TraceAndAudit, :change, 3)
  end
end
