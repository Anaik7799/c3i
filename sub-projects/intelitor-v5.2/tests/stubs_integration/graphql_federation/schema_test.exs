defmodule Intelitor.Integration.GraphQLFederation.SchemaTest do
  @moduledoc """
  Test suite for Intelitor.Integration.GraphQLFederation.Schema.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/integration/graphql_federation/schema.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Integration.GraphQLFederation.Schema

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Schema)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Schema, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Schema.__info__(:module)
      assert info == Intelitor.Integration.GraphQLFederation.Schema
    end
  end
end
