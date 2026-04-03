defmodule Indrajaal.Integration.MicroservicesOrchestrator.HealthCheckerTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.HealthChecker

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(HealthChecker)
    end

    test "module identifier is correct" do
      assert HealthChecker.__info__(:module) == HealthChecker
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = HealthChecker.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = HealthChecker.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = HealthChecker.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :check_interval field" do
      fields = HealthChecker.__schema__(:fields)
      assert :check_interval in fields
    end

    test "has :timeout field" do
      fields = HealthChecker.__schema__(:fields)
      assert :timeout in fields
    end

    test "has :failure_threshold field" do
      fields = HealthChecker.__schema__(:fields)
      assert :failure_threshold in fields
    end

    test "has :configuration field" do
      fields = HealthChecker.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %HealthChecker{}
      assert is_struct(struct, HealthChecker)
    end

    test "default check_interval is 30 seconds" do
      struct = %HealthChecker{}
      assert struct.check_interval == 30
    end

    test "default timeout is 10 seconds" do
      struct = %HealthChecker{}
      assert struct.timeout == 10
    end

    test "default failure_threshold is 3" do
      struct = %HealthChecker{}
      assert struct.failure_threshold == 3
    end

    test "default configuration is empty map" do
      struct = %HealthChecker{}
      assert struct.configuration == %{}
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(HealthChecker, :spark_dsl_config, 0)
    end
  end
end
