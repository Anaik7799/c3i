defmodule Indrajaal.IntegrationsTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integrations

  describe "module structure" do
    test "module is loadable" do
      assert Code.ensure_loaded?(Integrations)
    end

    test "is an Ash.Domain (exposes spark_dsl_config/0)" do
      assert function_exported?(Integrations, :spark_dsl_config, 0)
    end

    test "spark_dsl_config/0 returns a map or keyword structure" do
      config = Integrations.spark_dsl_config()
      assert not is_nil(config)
    end
  end

  describe "registered resources" do
    test "Webhook resource is registered in the domain" do
      resources = Ash.Domain.Info.resources(Integrations)
      assert Indrajaal.Integrations.Webhook in resources
    end

    test "ApiConnection resource is registered in the domain" do
      resources = Ash.Domain.Info.resources(Integrations)
      assert Indrajaal.Integrations.ApiConnection in resources
    end

    test "DataMapping resource is registered in the domain" do
      resources = Ash.Domain.Info.resources(Integrations)
      assert Indrajaal.Integrations.DataMapping in resources
    end

    test "SyncJob resource is registered in the domain" do
      resources = Ash.Domain.Info.resources(Integrations)
      assert Indrajaal.Integrations.SyncJob in resources
    end

    test "exactly 4 resources are registered" do
      resources = Ash.Domain.Info.resources(Integrations)
      assert length(resources) == 4
    end
  end
end
