defmodule Indrajaal.KMS.Schema.TodoDependencyTest do
  @moduledoc """
  TDG Sprint 54: Module coverage tests for Indrajaal.KMS.Schema.TodoDependency.
  Tests Ecto join-table schema structure and changeset.
  No DB connection required.
  STAMP: SC-KMS-001, SC-MIG-001
  """
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.Schema.TodoDependency

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TodoDependency)
    end

    test "has Ecto schema" do
      assert function_exported?(TodoDependency, :__schema__, 1)
    end

    test "has changeset/2" do
      assert function_exported?(TodoDependency, :changeset, 2)
    end
  end

  describe "schema structure" do
    test "has :id primary key" do
      assert :id in TodoDependency.__schema__(:primary_key)
    end

    test "has :blocking_id via belongs_to" do
      assocs = TodoDependency.__schema__(:associations)
      assert :blocking in assocs
    end

    test "has :blocked_id via belongs_to" do
      assocs = TodoDependency.__schema__(:associations)
      assert :blocked in assocs
    end
  end

  describe "changeset/2" do
    test "requires blocking_id and blocked_id" do
      changeset = TodoDependency.changeset(%TodoDependency{}, %{})
      refute changeset.valid?
    end

    test "valid with both ids" do
      blocking_id = Ecto.UUID.generate()
      blocked_id = Ecto.UUID.generate()

      changeset =
        TodoDependency.changeset(%TodoDependency{}, %{
          blocking_id: blocking_id,
          blocked_id: blocked_id
        })

      assert changeset.valid?
    end
  end
end
