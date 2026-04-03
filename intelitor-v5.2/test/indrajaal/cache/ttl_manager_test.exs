defmodule Indrajaal.Cache.TTLManagerTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Cache.TTLManager

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(TTLManager)
    end

    test "module exports expected functions" do
      assert function_exported?(TTLManager, :get_ttl, 2)
      assert function_exported?(TTLManager, :entity_ttl, 1)
      assert function_exported?(TTLManager, :api_ttl, 1)
      assert function_exported?(TTLManager, :dynamicttl, 2)
      assert function_exported?(TTLManager, :warmup_ttl, 1)
    end
  end

  describe "get_ttl/2" do
    test "returns integer for session type" do
      result = TTLManager.get_ttl(:session, [])
      assert is_integer(result)
    end

    test "returns integer for entity type" do
      result = TTLManager.get_ttl(:entity, [])
      assert is_integer(result)
    end

    test "returns integer for unknown type using entity fallback" do
      result = TTLManager.get_ttl(:unknown_type, [])
      assert is_integer(result)
    end

    test "returns positive integer TTL value" do
      result = TTLManager.get_ttl(:api, [])
      assert is_integer(result)
      assert result > 0
    end
  end

  describe "entity_ttl/1" do
    test "returns integer for known entity type" do
      result = TTLManager.entity_ttl(:device)
      assert is_integer(result)
    end

    test "returns integer for alarm entity" do
      result = TTLManager.entity_ttl(:alarm)
      assert is_integer(result)
    end

    test "returns integer for unknown entity type" do
      result = TTLManager.entity_ttl(:unknown)
      assert is_integer(result) or is_nil(result)
    end
  end

  describe "api_ttl/1" do
    test "returns integer for a path" do
      result = TTLManager.api_ttl("/api/devices")
      assert is_integer(result)
    end

    test "returns integer for any string path" do
      result = TTLManager.api_ttl("/api/alarms")
      assert is_integer(result)
    end
  end

  describe "dynamicttl/2" do
    test "returns integer for hitrate and current ttl" do
      result = TTLManager.dynamicttl(10, 60_000)
      assert is_integer(result)
    end

    test "accepts zero hitrate" do
      result = TTLManager.dynamicttl(0, 60_000)
      assert is_integer(result)
    end

    test "accepts high hitrate" do
      result = TTLManager.dynamicttl(1000, 60_000)
      assert is_integer(result)
    end
  end

  describe "warmup_ttl/1" do
    test "returns integer for entity type" do
      result = TTLManager.warmup_ttl(:device)
      assert is_integer(result) or is_nil(result)
    end
  end
end
