defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceInstanceTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.ServiceInstance

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(ServiceInstance)
    end

    test "module identifier is correct" do
      assert ServiceInstance.__info__(:module) == ServiceInstance
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :instance_name field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :instance_name in fields
    end

    test "has :status field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :status in fields
    end

    test "has :host field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :host in fields
    end

    test "has :port field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :port in fields
    end

    test "has :weight field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :weight in fields
    end

    test "has :metadata field" do
      fields = ServiceInstance.__schema__(:fields)
      assert :metadata in fields
    end
  end

  describe "struct construction" do
    test "can be constructed as a bare struct" do
      struct = %ServiceInstance{}
      assert is_struct(struct, ServiceInstance)
    end

    test "default weight is 100" do
      struct = %ServiceInstance{}
      assert struct.weight == 100
    end

    test "default metadata is empty map" do
      struct = %ServiceInstance{}
      assert struct.metadata == %{}
    end

    test "default status is :starting" do
      struct = %ServiceInstance{}
      assert struct.status == :starting
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(ServiceInstance, :spark_dsl_config, 0)
    end

    test "is a valid Ash resource (spark_is/1 present)" do
      assert function_exported?(ServiceInstance, :spark_is, 1) or
               function_exported?(ServiceInstance, :__ash_config__, 0)
    end
  end
end
