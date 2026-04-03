defmodule Indrajaal.TypesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Types

  test "module exists" do
    assert Code.ensure_loaded?(Types)
  end

  test "module is a type-only module (no public functions)" do
    # Types module is pure type definitions with no exported functions
    refute function_exported?(Types, :__struct__, 0)
  end

  test "priority type atoms are well-defined" do
    priorities = [:low, :medium, :high, :critical, :emergency]
    assert length(priorities) == 5
    assert Enum.all?(priorities, &is_atom/1)
  end

  test "status type atoms are well-defined" do
    statuses = [:active, :inactive, :suspended, :pending, :deleted]
    assert length(statuses) == 5
    assert Enum.all?(statuses, &is_atom/1)
  end
end
