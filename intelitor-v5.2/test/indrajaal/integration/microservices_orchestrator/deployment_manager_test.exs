defmodule Indrajaal.Integration.MicroservicesOrchestrator.DeploymentManagerTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.DeploymentManager

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(DeploymentManager)
    end

    test "module identifier is correct" do
      assert DeploymentManager.__info__(:module) == DeploymentManager
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :strategy field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :strategy in fields
    end

    test "has :version field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :version in fields
    end

    test "has :status field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :status in fields
    end

    test "has :configuration field" do
      fields = DeploymentManager.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %DeploymentManager{}
      assert is_struct(struct, DeploymentManager)
    end

    test "default strategy is :rolling" do
      struct = %DeploymentManager{}
      assert struct.strategy == :rolling
    end

    test "default status is :pending" do
      struct = %DeploymentManager{}
      assert struct.status == :pending
    end

    test "default configuration is empty map" do
      struct = %DeploymentManager{}
      assert struct.configuration == %{}
    end
  end

  describe "strategy and status enumerations" do
    test "all deployment strategies are valid atoms" do
      strategies = [:rolling, :blue_green, :canary, :recreate]
      assert length(strategies) == 4
      assert Enum.all?(strategies, &is_atom/1)
    end

    test "all deployment statuses are valid atoms" do
      statuses = [:pending, :in_progress, :completed, :failed, :rolled_back]
      assert length(statuses) == 5
      assert Enum.all?(statuses, &is_atom/1)
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(DeploymentManager, :spark_dsl_config, 0)
    end
  end
end
