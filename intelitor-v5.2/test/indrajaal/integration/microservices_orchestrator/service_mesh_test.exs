defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceMeshTest do
  use ExUnit.Case, async: true

  alias Indrajaal.Integration.MicroservicesOrchestrator.ServiceMesh

  describe "module definition" do
    test "module is loaded and accessible" do
      assert Code.ensure_loaded?(ServiceMesh)
    end

    test "module identifier is correct" do
      assert ServiceMesh.__info__(:module) == ServiceMesh
    end
  end

  describe "Ash resource schema fields" do
    test "has :id primary key field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :id in fields
    end

    test "has :tenant_id field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :tenant_id in fields
    end

    test "has :service_id field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :service_id in fields
    end

    test "has :mesh_enabled field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :mesh_enabled in fields
    end

    test "has :security_enabled field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :security_enabled in fields
    end

    test "has :observability_enabled field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :observability_enabled in fields
    end

    test "has :configuration field" do
      fields = ServiceMesh.__schema__(:fields)
      assert :configuration in fields
    end
  end

  describe "struct construction and defaults" do
    test "can be constructed as a bare struct" do
      struct = %ServiceMesh{}
      assert is_struct(struct, ServiceMesh)
    end

    test "default mesh_enabled is false" do
      struct = %ServiceMesh{}
      assert struct.mesh_enabled == false
    end

    test "default security_enabled is true" do
      struct = %ServiceMesh{}
      assert struct.security_enabled == true
    end

    test "default observability_enabled is true" do
      struct = %ServiceMesh{}
      assert struct.observability_enabled == true
    end

    test "default configuration is empty map" do
      struct = %ServiceMesh{}
      assert struct.configuration == %{}
    end
  end

  describe "Ash resource DSL" do
    test "exposes spark_dsl_config/0" do
      assert function_exported?(ServiceMesh, :spark_dsl_config, 0)
    end
  end
end
