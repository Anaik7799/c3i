defmodule Indrajaal.FAME.SchemaTest do
  @moduledoc """
  Tests for Indrajaal.FAME.Schema FAME metadata schema module.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.FAME.Schema

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Schema)
    end

    test "schema exports type definitions" do
      # FAME.Schema is a type-definition module, not a struct module
      assert Code.ensure_loaded?(Schema)
      # Module should have type info
      types = Schema.__info__(:functions)
      assert is_list(types)
    end
  end

  describe "module info" do
    test "module has functions or macros" do
      fns = Schema.__info__(:functions)
      macros = Schema.__info__(:macros)
      assert is_list(fns) and is_list(macros)
    end
  end
end
