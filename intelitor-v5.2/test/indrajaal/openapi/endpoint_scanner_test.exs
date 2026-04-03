defmodule Indrajaal.OpenAPI.EndpointScannerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.OpenAPI.EndpointScanner

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(EndpointScanner)
    end

    test "module exports expected functions" do
      assert function_exported?(EndpointScanner, :scan_all_endpoints, 0)
      assert function_exported?(EndpointScanner, :extract_action_meta_data, 2)
      assert function_exported?(EndpointScanner, :extract_path_parameters, 1)
      assert function_exported?(EndpointScanner, :categorize_endpoints, 1)
      assert function_exported?(EndpointScanner, :extract_security_requirements, 1)
    end
  end

  describe "scan_all_endpoints/0" do
    test "returns a map of endpoint categories" do
      result = EndpointScanner.scan_all_endpoints()
      assert is_map(result)
    end

    test "result contains known categories" do
      result = EndpointScanner.scan_all_endpoints()
      assert Map.has_key?(result, "authentication") or Map.has_key?(result, "alarms")
    end
  end

  describe "extract_path_parameters/1" do
    test "returns list for path with no parameters" do
      result = EndpointScanner.extract_path_parameters("/api/health")
      assert is_list(result)
      assert result == []
    end

    test "returns list with parameter names for parameterized path" do
      result = EndpointScanner.extract_path_parameters("/api/devices/:id")
      assert is_list(result)
      assert length(result) >= 1
    end

    test "returns multiple parameters for complex path" do
      result = EndpointScanner.extract_path_parameters("/api/sites/:site_id/devices/:device_id")
      assert is_list(result)
      assert length(result) == 2
    end
  end

  describe "categorize_endpoints/1" do
    test "returns map of categories for a list of endpoints" do
      endpoints = [
        %{path: "/api/mobile/devices/index", method: :get, action: :index},
        %{path: "/api/mobile/alarms/index", method: :get, action: :index}
      ]

      result = EndpointScanner.categorize_endpoints(endpoints)
      assert is_map(result)
    end

    test "handles empty endpoint list" do
      result = EndpointScanner.categorize_endpoints([])
      assert is_map(result)
      assert result == %{}
    end
  end

  describe "extract_action_meta_data/2" do
    test "returns map for a module and action" do
      result = EndpointScanner.extract_action_meta_data(EndpointScanner, :scan_all_endpoints)
      assert is_map(result)
      assert Map.has_key?(result, :controller)
      assert Map.has_key?(result, :action)
    end
  end

  describe "extract_security_requirements/1" do
    test "returns list with bearer auth for auth_required endpoint" do
      endpoint = %{auth_required: true, path: "/api/mobile/alarms", method: :get}
      result = EndpointScanner.extract_security_requirements(endpoint)
      assert is_list(result)
      assert length(result) >= 1
    end

    test "returns empty list for non-auth endpoint" do
      endpoint = %{auth_required: false, path: "/api/health", method: :get}
      result = EndpointScanner.extract_security_requirements(endpoint)
      assert is_list(result)
      assert result == []
    end
  end
end
