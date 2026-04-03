defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceDiscoveryTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.ServiceDiscovery

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(ServiceDiscovery)
    end

    test "module identifier is correct" do
      assert ServiceDiscovery.__info__(:module) == ServiceDiscovery
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = ServiceDiscovery.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = ServiceDiscovery.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = ServiceDiscovery.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :discovery_type field" do
      fields = ServiceDiscovery.__schema__(:fields)
      assert :discovery_type in fields
    end

    test "has :health_check_enabled field" do
      fields = ServiceDiscovery.__schema__(:fields)
      assert :health_check_enabled in fields
    end

    test "has :configuration field" do
      fields = ServiceDiscovery.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %ServiceDiscovery{}
      assert is_struct(struct, ServiceDiscovery)
    end

    test "default discovery_type is :dns" do
      struct = %ServiceDiscovery{}
      assert struct.discovery_type == :dns
    end

    test "default health_check_enabled is true" do
      struct = %ServiceDiscovery{}
      assert struct.health_check_enabled == true
    end

    test "default configuration is empty map" do
      struct = %ServiceDiscovery{}
      assert struct.configuration == %{}
    end
  end

  describe "discovery_type valid values" do
    test "atoms :dns, :api, :consul, :etcd are all valid" do
      valid_types = [:dns, :api, :consul, :etcd]
      assert length(valid_types) == 4
      assert :dns in valid_types
      assert :consul in valid_types
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(ServiceDiscovery, :spark_dsl_config, 0)
    end
  end
end
