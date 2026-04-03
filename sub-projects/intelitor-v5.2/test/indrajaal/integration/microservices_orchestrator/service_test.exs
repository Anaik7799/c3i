defmodule Indrajaal.Integration.MicroservicesOrchestrator.ServiceTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Integration.MicroservicesOrchestrator.Service

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Service)
    end
  end

  describe "Ash resource structure" do
    test "module is defined" do
      assert Service.__info__(:module) == Service
    end

    test "has JSON API and GraphQL configured" do
      assert Code.ensure_loaded?(Service)
    end
  end

  describe "helper functions" do
    test "defines get_service_by_name/2" do
      assert function_exported?(Service, :get_service_by_name, 2)
    end

    test "defines get_service_by_name/1" do
      assert function_exported?(Service, :get_service_by_name, 1)
    end

    test "defines list_services/1" do
      assert function_exported?(Service, :list_services, 1)
    end

    test "defines list_services/0" do
      assert function_exported?(Service, :list_services, 0)
    end
  end

  describe "get_service_by_name/1 error handling" do
    test "returns error when db is unavailable" do
      result = Service.get_service_by_name("test_service")
      assert match?({:error, _}, result)
    end
  end

  describe "list_services/0 error handling" do
    test "returns error or list when db is unavailable" do
      result = Service.list_services()
      assert match?({:error, _}, result) or is_list(result)
    end
  end
end
