defmodule Indrajaal.Integration.GraphQLFederation.SchemaTest do
  @moduledoc """
  TDG tests for Indrajaal.Integration.GraphQLFederation.Schema Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.GraphQLFederation.Schema

  describe "Schema Ash resource" do
    test "module is defined and accessible" do
      assert Code.ensure_loaded?(Schema)
    end

    test "is an Ash resource" do
      assert function_exported?(Schema, :spark_dsl_config, 0)
    end

    test "has expected schema fields" do
      fields = Schema.__schema__(:fields)
      assert :id in fields
      assert :name in fields
    end

    test "has active field" do
      fields = Schema.__schema__(:fields)
      assert :active in fields
    end

    test "has description field" do
      fields = Schema.__schema__(:fields)
      assert :description in fields
    end

    test "has timestamp fields" do
      fields = Schema.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end

    test "can be constructed as a struct" do
      struct = %Schema{}
      assert is_struct(struct, Schema)
    end
  end
end
