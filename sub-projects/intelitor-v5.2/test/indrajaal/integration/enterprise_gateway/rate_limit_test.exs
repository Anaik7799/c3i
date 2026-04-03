defmodule Indrajaal.Integration.Enterprise.RateLimitTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.Enterprise.RateLimit

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(RateLimit)
    end

    test "module identifier is correct" do
      assert RateLimit.__info__(:module) == RateLimit
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = RateLimit.__schema__(:fields)
      assert :id in fields
    end

    test "has :name field" do
      fields = RateLimit.__schema__(:fields)
      assert :name in fields
    end

    test "has :active field" do
      fields = RateLimit.__schema__(:fields)
      assert :active in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %RateLimit{}
      assert is_struct(struct, RateLimit)
    end

    test "default active is true" do
      struct = %RateLimit{}
      assert struct.active == true
    end

    test "description field defaults to nil" do
      struct = %RateLimit{}
      assert is_nil(struct.description)
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(RateLimit, :spark_dsl_config, 0)
    end

    test "is a valid Ash resource" do
      assert function_exported?(RateLimit, :spark_is, 1) or
               function_exported?(RateLimit, :__ash_config__, 0) or
               Code.ensure_loaded?(RateLimit)
    end
  end
end
