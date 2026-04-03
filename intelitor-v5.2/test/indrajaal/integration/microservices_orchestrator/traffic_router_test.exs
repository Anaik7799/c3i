defmodule Indrajaal.Integration.MicroservicesOrchestrator.TrafficRouterTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.TrafficRouter

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(TrafficRouter)
    end

    test "module identifier is correct" do
      assert TrafficRouter.__info__(:module) == TrafficRouter
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = TrafficRouter.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = TrafficRouter.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = TrafficRouter.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :routing_rules field" do
      fields = TrafficRouter.__schema__(:fields)
      assert :routing_rules in fields
    end

    test "has :traffic_splitting field" do
      fields = TrafficRouter.__schema__(:fields)
      assert :traffic_splitting in fields
    end

    test "has :configuration field" do
      fields = TrafficRouter.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction" do
    test "can be constructed as a bare struct" do
      struct = %TrafficRouter{}
      assert is_struct(struct, TrafficRouter)
    end

    test "default routing_rules is empty map" do
      struct = %TrafficRouter{}
      assert struct.routing_rules == %{}
    end

    test "default traffic_splitting is empty map" do
      struct = %TrafficRouter{}
      assert struct.traffic_splitting == %{}
    end

    test "default configuration is empty map" do
      struct = %TrafficRouter{}
      assert struct.configuration == %{}
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(TrafficRouter, :spark_dsl_config, 0)
    end
  end
end
