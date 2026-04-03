defmodule Indrajaal.KMS.Resources.TodoDependencyTest do
  @moduledoc """
  TDG Sprint 54: Coverage note for kms/resources/todo_dependency.ex (TOMBSTONE).
  This file was migrated to kms/schemas/todo_dependency.ex (v21.3.0 Ash→Ecto shift).
  The actual schema is Indrajaal.KMS.Schema.TodoDependency.
  Tests here verify the migration path is understood.
  STAMP: SC-KMS-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "migration verification" do
    test "tombstone source path is understood — real module is KMS.Schema.TodoDependency" do
      # The file lib/indrajaal/kms/resources/todo_dependency.ex is a tombstone.
      # It does NOT define a module. The canonical module lives in schemas/.
      assert Code.ensure_loaded?(Indrajaal.KMS.Schema.TodoDependency)
    end

    test "schema module has expected Ecto schema structure" do
      assert function_exported?(Indrajaal.KMS.Schema.TodoDependency, :__schema__, 1)
    end

    test "changeset/2 is exported" do
      assert function_exported?(Indrajaal.KMS.Schema.TodoDependency, :changeset, 2)
    end
  end
end
