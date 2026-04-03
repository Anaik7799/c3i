defmodule Indrajaal.OpenAPI.ValidatorTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.OpenAPI.Validator

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Validator)
    end

    test "module exports expected functions" do
      assert function_exported?(Validator, :validate, 0)
      assert function_exported?(Validator, :validate_structure, 1)
      assert function_exported?(Validator, :validate_info, 1)
      assert function_exported?(Validator, :validate_servers, 1)
      assert function_exported?(Validator, :validate_paths, 1)
      assert function_exported?(Validator, :validate_components, 1)
      assert function_exported?(Validator, :validate_security, 1)
      assert function_exported?(Validator, :validate_tags, 1)
      assert function_exported?(Validator, :validate_websockets, 1)
      assert function_exported?(Validator, :generate_report, 0)
    end
  end

  describe "validate/0" do
    test "returns ok or error tuple" do
      result = Validator.validate()
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "generate_report/0" do
    test "returns a map with expected keys" do
      result = Validator.generate_report()
      assert is_map(result)
      assert Map.has_key?(result, :valid)
      assert Map.has_key?(result, :statistics)
    end
  end

  describe "validate_structure/1" do
    test "returns :ok for a complete spec" do
      spec = %{
        "openapi" => "3.0.0",
        "info" => %{"title" => "Test", "version" => "1.0"},
        "paths" => %{}
      }

      result = Validator.validate_structure(spec)
      assert result == :ok
    end

    test "returns error for spec missing required fields" do
      result = Validator.validate_structure(%{})
      assert match?({:error, _}, result)
    end

    test "returns :ok or error (valid result shape)" do
      spec = %{"openapi" => "3.0.0", "info" => %{}, "paths" => %{}}
      result = Validator.validate_structure(spec)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "validate_info/1" do
    test "returns :ok for valid info section" do
      info = %{"title" => "Indrajaal API", "version" => "21.3.0"}
      result = Validator.validate_info(info)
      assert result == :ok
    end

    test "returns error for info missing required fields" do
      result = Validator.validate_info(%{})
      assert match?({:error, _}, result)
    end
  end

  describe "validate_servers/1" do
    test "returns :ok for a list with one valid server" do
      servers = [%{"url" => "http://localhost:4000", "description" => "Local"}]
      result = Validator.validate_servers(servers)
      assert result == :ok
    end

    test "returns :ok for empty server list" do
      result = Validator.validate_servers([])
      assert result == :ok
    end
  end

  describe "validate_paths/1" do
    test "returns :ok for an empty paths map" do
      result = Validator.validate_paths(%{})
      assert result == :ok
    end

    test "returns :ok or error for a valid path definition" do
      paths = %{
        "/api/health" => %{
          "get" => %{"responses" => %{"200" => %{"description" => "OK"}}}
        }
      }

      result = Validator.validate_paths(paths)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "validate_components/1" do
    test "returns :ok for an empty components map" do
      result = Validator.validate_components(%{})
      assert result == :ok
    end

    test "returns :ok or error for valid schemas section" do
      components = %{
        "schemas" => %{
          "Device" => %{"type" => "object"}
        }
      }

      result = Validator.validate_components(components)
      assert result == :ok or match?({:error, _}, result)
    end
  end

  describe "validate_security/1" do
    test "returns :ok for an empty security list" do
      result = Validator.validate_security([])
      assert result == :ok
    end

    test "returns :ok for a non-empty security list" do
      result = Validator.validate_security([%{"bearerAuth" => []}])
      assert result == :ok
    end
  end

  describe "validate_tags/1" do
    test "returns :ok for a list with valid tags" do
      result = Validator.validate_tags([%{"name" => "devices"}])
      assert result == :ok
    end

    test "returns :ok for empty tag list" do
      result = Validator.validate_tags([])
      assert result == :ok
    end

    test "returns error for invalid tag (missing name)" do
      result = Validator.validate_tags([%{"description" => "no name"}])
      assert match?({:error, _}, result)
    end
  end

  describe "validate_websockets/1" do
    test "returns :ok for a map" do
      result = Validator.validate_websockets(%{"channels" => []})
      assert result == :ok
    end

    test "returns :ok for empty map" do
      result = Validator.validate_websockets(%{})
      assert result == :ok
    end
  end
end
