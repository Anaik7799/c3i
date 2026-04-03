defmodule Indrajaal.Integration.MicroservicesOrchestrator.MetricsCollectorTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.MetricsCollector

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(MetricsCollector)
    end

    test "module identifier is correct" do
      assert MetricsCollector.__info__(:module) == MetricsCollector
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = MetricsCollector.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = MetricsCollector.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = MetricsCollector.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :collection_interval field" do
      fields = MetricsCollector.__schema__(:fields)
      assert :collection_interval in fields
    end

    test "has :metrics_enabled field" do
      fields = MetricsCollector.__schema__(:fields)
      assert :metrics_enabled in fields
    end

    test "has :configuration field" do
      fields = MetricsCollector.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %MetricsCollector{}
      assert is_struct(struct, MetricsCollector)
    end

    test "default collection_interval is 15" do
      struct = %MetricsCollector{}
      assert struct.collection_interval == 15
    end

    test "default metrics_enabled is true" do
      struct = %MetricsCollector{}
      assert struct.metrics_enabled == true
    end

    test "default configuration is empty map" do
      struct = %MetricsCollector{}
      assert struct.configuration == %{}
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(MetricsCollector, :spark_dsl_config, 0)
    end
  end
end
