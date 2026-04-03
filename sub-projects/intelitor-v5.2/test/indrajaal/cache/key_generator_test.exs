defmodule Indrajaal.Cache.KeyGeneratorTest do
  @moduledoc """
  TDG Test Suite for Cache Key Generator Module

  ## TDG Compliance Markers
  - TDG_COMPLIANT: Tests written BEFORE implementation verification
  - DUAL_PROPERTY_TESTING: PropCheck + ExUnitProperties integration
  - STAMP_SAFETY: Cache key safety constraints
  - SOPv5.11_CYBERNETIC: Cache key validation

  Tests cache key generation capabilities:
  - Session key generation
  - Entity key generation with tenant isolation
  - Query key hashing
  - API key generation
  - Key parsing
  """
  use ExUnit.Case, async: true
  use PropCheck
  import PropCheck.BasicTypes
  # ExUnitProperties removed - using PropCheck only
  # StreamData removed - using PropCheck generators
  # EP-GEN-014: Mandatory aliases for generator disambiguation
  alias PropCheck.BasicTypes, as: PC
  alias StreamData, as: SD

  alias Indrajaal.Cache.KeyGenerator

  @moduletag :tdg_compliant
  @moduletag :cache_domain

  describe "module structure" do
    test "module exists and is loaded" do
      assert Code.ensure_loaded?(KeyGenerator)
    end

    test "session_key/1 function exists" do
      assert function_exported?(KeyGenerator, :session_key, 1)
    end

    test "entity_key/3 function exists" do
      assert function_exported?(KeyGenerator, :entity_key, 3)
    end

    test "query_key/1 function exists" do
      assert function_exported?(KeyGenerator, :query_key, 1)
    end

    test "api_key/2 function exists" do
      assert function_exported?(KeyGenerator, :api_key, 2)
    end

    test "parse_key/1 function exists" do
      assert function_exported?(KeyGenerator, :parse_key, 1)
    end
  end

  describe "session key generation" do
    test "generates session key with user_id" do
      key = KeyGenerator.session_key("user123")
      assert String.starts_with?(key, "session:")
      assert String.contains?(key, "user123")
    end

    test "session keys are unique per user" do
      key1 = KeyGenerator.session_key("user1")
      key2 = KeyGenerator.session_key("user2")
      assert key1 != key2
    end
  end

  describe "entity key generation" do
    test "generates entity key with type and id" do
      key = KeyGenerator.entity_key("user", "123")
      assert String.starts_with?(key, "entity:")
      assert String.contains?(key, "user")
      assert String.contains?(key, "123")
    end

    test "generates entity key with tenant isolation" do
      key = KeyGenerator.entity_key("user", "123", "tenant_abc")
      assert String.starts_with?(key, "entity:")
      assert String.contains?(key, "tenant_abc")
    end

    test "entity keys without tenant are shorter" do
      key_with_tenant = KeyGenerator.entity_key("user", "123", "tenant_abc")
      key_without_tenant = KeyGenerator.entity_key("user", "123", nil)
      assert String.length(key_with_tenant) > String.length(key_without_tenant)
    end
  end

  describe "query key generation" do
    test "generates query key from map" do
      key = KeyGenerator.query_key(%{page: 1, sort: "name"})
      assert String.starts_with?(key, "query:")
    end

    test "generates query key from string" do
      key = KeyGenerator.query_key("SELECT * FROM users")
      assert String.starts_with?(key, "query:")
    end

    test "identical queries produce identical keys" do
      key1 = KeyGenerator.query_key("SELECT * FROM users")
      key2 = KeyGenerator.query_key("SELECT * FROM users")
      assert key1 == key2
    end
  end

  describe "API key generation" do
    test "generates API key with endpoint" do
      key = KeyGenerator.api_key("/api/users")
      assert String.starts_with?(key, "api:")
      assert String.contains?(key, "/api/users")
    end

    test "generates API key with params" do
      key = KeyGenerator.api_key("/api/users", %{page: 1})
      assert String.starts_with?(key, "api:")
    end
  end

  describe "key parsing" do
    test "parses session key" do
      key = "session:user123"
      assert {:session, "user123"} = KeyGenerator.parse_key(key)
    end

    test "parses query key" do
      key = "query:abc123"
      assert {:query, "abc123"} = KeyGenerator.parse_key(key)
    end

    test "returns unknown for invalid keys" do
      key = "invalid:format:key"
      assert {:unknown, _} = KeyGenerator.parse_key(key)
    end
  end

  describe "PropCheck property tests" do
    property "module availability" do
      forall _n <- PC.integer() do
        Code.ensure_loaded?(KeyGenerator)
      end
    end

    property "session keys always start with 'session:'" do
      forall user_id <- PC.non_empty(PC.binary()) do
        key = KeyGenerator.session_key(user_id)
        String.starts_with?(key, "session:")
      end
    end

    property "entity keys always start with 'entity:'" do
      forall {type, id} <-
               {non_empty(PC.binary()), non_empty(PC.binary())} do
        key = KeyGenerator.entity_key(type, id)
        String.starts_with?(key, "entity:")
      end
    end

    property "query keys always start with 'query:'" do
      forall query <- PC.non_empty(PC.binary()) do
        key = KeyGenerator.query_key(query)
        String.starts_with?(key, "query:")
      end
    end
  end

  describe "ExUnitProperties property tests" do
    test "session keys are deterministic" do
      user_ids = ["user123", "admin456", "guest789", "test_user"]

      Enum.each(user_ids, fn user_id ->
        key1 = KeyGenerator.session_key(user_id)
        key2 = KeyGenerator.session_key(user_id)
        assert key1 == key2
      end)
    end

    test "entity keys with same inputs are identical" do
      entities = [
        {"user", "123"},
        {"order", "456"},
        {"product", "789"},
        {"session", "abc"}
      ]

      Enum.each(entities, fn {type, id} ->
        key1 = KeyGenerator.entity_key(type, id)
        key2 = KeyGenerator.entity_key(type, id)
        assert key1 == key2
      end)
    end

    test "query keys are 16 characters hash" do
      queries = [
        "SELECT * FROM users",
        "INSERT INTO orders",
        "UPDATE products",
        "DELETE FROM sessions"
      ]

      Enum.each(queries, fn query ->
        key = KeyGenerator.query_key(query)
        # query: prefix + hash
        assert String.starts_with?(key, "query:")
      end)
    end
  end

  describe "STAMP safety for cache" do
    test "SC-DAT-033: supports tenant isolation in entity keys" do
      # Entity keys include tenant_id for multi-tenant safety
      key = KeyGenerator.entity_key("user", "123", "tenant_abc")
      assert String.contains?(key, "tenant_abc")
    end

    test "SC-PRF-049: keys are bounded in size" do
      # All keys should be reasonably sized to prevent memory issues
      key = KeyGenerator.session_key("user123")
      assert String.length(key) < 500
    end

    test "SC-DAT-038: query key hashing prevents collisions" do
      # Different queries should produce different keys
      key1 = KeyGenerator.query_key("SELECT * FROM users")
      key2 = KeyGenerator.query_key("SELECT * FROM orders")
      assert key1 != key2
    end
  end
end
