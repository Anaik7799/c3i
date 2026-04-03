defmodule Indrajaal.Integration.IntegrationTest do
  @moduledoc """
  TDG tests for Indrajaal.Integration.Integration Ecto schema.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.Integration

  describe "Integration Ecto schema" do
    test "has expected fields" do
      fields = Integration.__schema__(:fields)
      assert :id in fields
      assert :name in fields
      assert :description in fields
      assert :active in fields
      assert :metadata in fields
      assert :type in fields
      assert :status in fields
      assert :tags in fields
    end

    test "has tenant_id field for multi-tenant isolation" do
      fields = Integration.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has audit fields" do
      fields = Integration.__schema__(:fields)
      assert :created_by_id in fields
      assert :updated_by_id in fields
    end

    test "has timestamps" do
      fields = Integration.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "changeset validates required name" do
      changeset = Integration.changeset(%Integration{}, %{})
      refute changeset.valid?
      assert {:name, _} = List.keyfind(changeset.errors, :name, 0)
    end

    test "changeset accepts valid attributes" do
      changeset = Integration.changeset(%Integration{}, %{name: "Test Integration"})
      assert changeset.valid?
    end

    test "changeset validates name max length" do
      long_name = String.duplicate("a", 256)
      changeset = Integration.changeset(%Integration{}, %{name: long_name})
      refute changeset.valid?
    end

    test "changeset validates description max length" do
      long_desc = String.duplicate("a", 1001)

      changeset =
        Integration.changeset(%Integration{}, %{name: "valid", description: long_desc})

      refute changeset.valid?
    end

    test "default active is true" do
      struct = %Integration{}
      assert struct.active == true
    end

    test "default metadata is empty map" do
      struct = %Integration{}
      assert struct.metadata == %{}
    end

    test "default tags is empty list" do
      struct = %Integration{}
      assert struct.tags == []
    end
  end
end
