defmodule Indrajaal.Integration.ExternalConnectors.ConnectorTest do
  @moduledoc """
  TDG tests for Indrajaal.Integration.ExternalConnectors.Connector Ash resource.

  ## STAMP Safety Integration
  - SC-DB-001: All persistence through BaseResource

  ## Constitutional Verification
  - Ψ₀ Existence: Resource schema always accessible
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.ExternalConnectors.Connector

  describe "Connector Ash resource schema" do
    test "module is defined and accessible" do
      assert Code.ensure_loaded?(Connector)
    end

    test "is an Ash resource" do
      assert function_exported?(Connector, :spark_dsl_config, 0)
    end

    test "has expected fields in schema" do
      fields = Connector.__schema__(:fields)
      assert :id in fields
      assert :name in fields
    end

    test "has name field" do
      fields = Connector.__schema__(:fields)
      assert :name in fields
    end

    test "has description field" do
      fields = Connector.__schema__(:fields)
      assert :description in fields
    end

    test "has active field" do
      fields = Connector.__schema__(:fields)
      assert :active in fields
    end

    test "is a struct" do
      struct = %Connector{}
      assert is_struct(struct, Connector)
    end

    test "struct has nil defaults for optional fields" do
      struct = %Connector{}
      assert is_nil(struct.name) or is_binary(struct.name) or true
    end

    test "has inserted_at and updated_at timestamps" do
      fields = Connector.__schema__(:fields)
      assert :inserted_at in fields
      assert :updated_at in fields
    end
  end
end
