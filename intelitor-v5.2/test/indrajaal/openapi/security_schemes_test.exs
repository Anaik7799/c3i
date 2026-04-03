defmodule Indrajaal.OpenAPI.SecuritySchemesTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.OpenAPI.SecuritySchemes

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SecuritySchemes)
    end

    test "module exports expected functions" do
      assert function_exported?(SecuritySchemes, :generate, 0)
      assert function_exported?(SecuritySchemes, :security_requirements, 0)
      assert function_exported?(SecuritySchemes, :security_headers, 0)
    end
  end

  describe "generate/0" do
    test "returns a map of security schemes" do
      result = SecuritySchemes.generate()
      assert is_map(result)
    end

    test "result contains bearerAuth scheme" do
      result = SecuritySchemes.generate()
      assert Map.has_key?(result, "bearerAuth")
    end

    test "result contains apiKey scheme" do
      result = SecuritySchemes.generate()
      assert Map.has_key?(result, "apiKey")
    end
  end

  describe "security_requirements/0" do
    test "returns a map of requirement categories" do
      result = SecuritySchemes.security_requirements()
      assert is_map(result)
    end

    test "result contains default requirements" do
      result = SecuritySchemes.security_requirements()
      assert Map.has_key?(result, "default")
    end

    test "result contains public requirements" do
      result = SecuritySchemes.security_requirements()
      assert Map.has_key?(result, "public")
    end
  end

  describe "security_headers/0" do
    test "returns a map of header definitions" do
      result = SecuritySchemes.security_headers()
      assert is_map(result)
    end

    test "result is non-empty" do
      result = SecuritySchemes.security_headers()
      assert map_size(result) > 0
    end
  end
end
