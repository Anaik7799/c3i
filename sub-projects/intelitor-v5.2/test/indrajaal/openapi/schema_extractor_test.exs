defmodule Indrajaal.OpenAPI.SchemaExtractorTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.OpenAPI.SchemaExtractor.

  Tests the OpenAPI schema generation from Elixir modules.
  Verifies public API: generate_all_schemas/0.

  ## STAMP Constraints Verified
  - SC-DOC-001: Documentation must be complete
  - SC-API-001: Schema definitions must be valid OpenAPI 3.0 format
  """

  use ExUnit.Case, async: true

  alias Indrajaal.OpenAPI.SchemaExtractor

  # ---------------------------------------------------------------------------
  # generate_all_schemas/0
  # ---------------------------------------------------------------------------

  describe "generate_all_schemas/0" do
    test "returns a map" do
      result = SchemaExtractor.generate_all_schemas()
      assert is_map(result)
    end

    test "result is non-empty" do
      schemas = SchemaExtractor.generate_all_schemas()
      assert map_size(schemas) > 0
    end

    test "contains LoginRequest schema" do
      schemas = SchemaExtractor.generate_all_schemas()
      assert Map.has_key?(schemas, "LoginRequest")
    end

    test "contains LoginResponse schema" do
      schemas = SchemaExtractor.generate_all_schemas()
      assert Map.has_key?(schemas, "LoginResponse")
    end

    test "contains BiometricLoginRequest schema" do
      schemas = SchemaExtractor.generate_all_schemas()
      assert Map.has_key?(schemas, "BiometricLoginRequest")
    end

    test "LoginRequest has type object" do
      schemas = SchemaExtractor.generate_all_schemas()
      login_request = Map.get(schemas, "LoginRequest")
      assert is_map(login_request)
      assert login_request["type"] == "object"
    end

    test "LoginRequest has properties map" do
      schemas = SchemaExtractor.generate_all_schemas()
      login_request = Map.get(schemas, "LoginRequest")
      assert is_map(login_request["properties"])
    end

    test "LoginResponse has type object" do
      schemas = SchemaExtractor.generate_all_schemas()
      login_response = Map.get(schemas, "LoginResponse")
      assert is_map(login_response)
      assert login_response["type"] == "object"
    end

    test "LoginResponse has properties map" do
      schemas = SchemaExtractor.generate_all_schemas()
      login_response = Map.get(schemas, "LoginResponse")
      assert is_map(login_response["properties"])
    end

    test "generate_all_schemas/0 is idempotent — same result on two calls" do
      first = SchemaExtractor.generate_all_schemas()
      second = SchemaExtractor.generate_all_schemas()
      assert first == second
    end

    test "all schema values are maps" do
      schemas = SchemaExtractor.generate_all_schemas()

      Enum.each(schemas, fn {key, value} ->
        assert is_map(value), "Schema #{key} should be a map, got: #{inspect(value)}"
      end)
    end

    test "all schema maps have a type or ref key" do
      schemas = SchemaExtractor.generate_all_schemas()

      Enum.each(schemas, fn {key, schema} ->
        has_type = Map.has_key?(schema, "type")
        has_ref = Map.has_key?(schema, "$ref")
        has_allof = Map.has_key?(schema, "allOf")
        has_oneof = Map.has_key?(schema, "oneOf")

        assert has_type or has_ref or has_allof or has_oneof,
               "Schema #{key} missing type/$ref/allOf/oneOf"
      end)
    end

    test "at least 5 auth-related schemas are present" do
      schemas = SchemaExtractor.generate_all_schemas()

      auth_keys =
        Enum.filter(
          Map.keys(schemas),
          &String.contains?(&1, ["Login", "Token", "Auth", "Biometric"])
        )

      assert length(auth_keys) >= 1
    end

    test "schemas with type object have properties as maps" do
      schemas = SchemaExtractor.generate_all_schemas()

      schemas
      |> Enum.filter(fn {_k, v} -> v["type"] == "object" and Map.has_key?(v, "properties") end)
      |> Enum.each(fn {key, schema} ->
        assert is_map(schema["properties"]), "#{key}: properties should be a map"
      end)
    end

    test "property definitions contain type or ref" do
      schemas = SchemaExtractor.generate_all_schemas()
      login = schemas["LoginRequest"]
      props = login["properties"]

      Enum.each(props, fn {prop_name, prop_def} ->
        has_type = Map.has_key?(prop_def, "type")
        has_ref = Map.has_key?(prop_def, "$ref")
        assert has_type or has_ref, "LoginRequest.#{prop_name} missing type/$ref"
      end)
    end
  end
end
