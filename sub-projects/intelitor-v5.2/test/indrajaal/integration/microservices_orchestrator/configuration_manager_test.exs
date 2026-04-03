defmodule Indrajaal.Integration.MicroservicesOrchestrator.ConfigurationManagerTest do
  @moduledoc """
  Tests for ConfigurationManager Ash resource.
  """

  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.ConfigurationManager

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(ConfigurationManager)
    end

    test "module identifier is correct" do
      assert ConfigurationManager.__info__(:module) == ConfigurationManager
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = ConfigurationManager.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = ConfigurationManager.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = ConfigurationManager.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :version field" do
      fields = ConfigurationManager.__schema__(:fields)
      assert :version in fields
    end

    test "has :configuration field" do
      fields = ConfigurationManager.__schema__(:fields)
      assert :configuration in fields
    end

    test "has :active field" do
      fields = ConfigurationManager.__schema__(:fields)
      assert :active in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %ConfigurationManager{}
      assert is_struct(struct, ConfigurationManager)
    end

    test "default configuration is empty map" do
      struct = %ConfigurationManager{}
      assert struct.configuration == %{}
    end

    test "default active is false" do
      struct = %ConfigurationManager{}
      assert struct.active == false
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(ConfigurationManager, :spark_dsl_config, 0)
    end

    test "is a valid Ash resource" do
      assert function_exported?(ConfigurationManager, :spark_is, 1) or
               function_exported?(ConfigurationManager, :__ash_config__, 0)
    end
  end
end
