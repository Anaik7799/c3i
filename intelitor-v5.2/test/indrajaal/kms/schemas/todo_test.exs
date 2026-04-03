defmodule Indrajaal.KMS.Schema.TodoTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Schema.Todo.
  Tests Ecto schema structure, changeset validation, and field definitions.
  No DB connection required — schema struct tests only.
  STAMP: SC-KMS-001, SC-MIG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Schema.Todo

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Todo)
    end

    test "has Ecto schema" do
      assert function_exported?(Todo, :__schema__, 1)
    end

    test "has changeset/2" do
      assert function_exported?(Todo, :changeset, 2)
    end
  end

  describe "schema structure" do
    test "has :id primary key" do
      assert :id in Todo.__schema__(:primary_key)
    end

    test "has :title field" do
      assert :title in Todo.__schema__(:fields)
    end

    test "has :status field" do
      assert :status in Todo.__schema__(:fields)
    end

    test "has :priority field" do
      assert :priority in Todo.__schema__(:fields)
    end

    test "has :layer field" do
      assert :layer in Todo.__schema__(:fields)
    end

    test "has :points field" do
      assert :points in Todo.__schema__(:fields)
    end

    test "has :tags field" do
      assert :tags in Todo.__schema__(:fields)
    end

    test "has :parent_id via belongs_to" do
      assocs = Todo.__schema__(:associations)
      assert :parent in assocs
    end
  end

  describe "changeset/2" do
    test "requires title" do
      changeset = Todo.changeset(%Todo{}, %{status: :backlog, priority: :p2})
      refute changeset.valid?
      assert :title in Keyword.keys(changeset.errors)
    end

    test "valid with required fields" do
      changeset =
        Todo.changeset(%Todo{}, %{
          title: "Sprint 54 TDG Test",
          status: :backlog,
          priority: :p1
        })

      assert changeset.valid?
    end

    test "accepts all layer values" do
      for layer <- [:l1, :l2, :l3, :l4, :l5, :l6, :l7, :l8, :l9, :l10] do
        changeset =
          Todo.changeset(%Todo{}, %{
            title: "Layer test",
            status: :backlog,
            priority: :p2,
            layer: layer
          })

        assert changeset.valid?, "Layer #{layer} should be valid"
      end
    end

    test "accepts all status values" do
      for status <- [:backlog, :in_progress, :in_review, :done, :blocked, :archived] do
        changeset =
          Todo.changeset(%Todo{}, %{
            title: "Status test",
            status: status,
            priority: :p2
          })

        assert changeset.valid?, "Status #{status} should be valid"
      end
    end
  end
end
