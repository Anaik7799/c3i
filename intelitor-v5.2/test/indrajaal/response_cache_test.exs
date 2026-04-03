defmodule ResponseCacheTest do
  @moduledoc """
  Tests for ResponseCache (top-level module, stub implementation).
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  describe "get/1" do
    test "function is exported" do
      assert function_exported?(ResponseCache, :get, 1)
    end

    test "returns error (stub)" do
      result = ResponseCache.get("some_key")
      assert match?({:error, _}, result)
    end
  end

  describe "get/2" do
    test "function is exported" do
      assert function_exported?(ResponseCache, :get, 2)
    end

    test "returns error with options (stub)" do
      result = ResponseCache.get("some_key", [])
      assert match?({:error, _}, result)
    end
  end

  describe "put/2" do
    test "function is exported" do
      assert function_exported?(ResponseCache, :put, 2)
    end

    test "returns error (stub)" do
      result = ResponseCache.put("some_key", %{data: "value"})
      assert match?({:error, _}, result)
    end
  end

  describe "put/3" do
    test "function is exported" do
      assert function_exported?(ResponseCache, :put, 3)
    end

    test "returns error with ttl (stub)" do
      result = ResponseCache.put("some_key", %{data: "value"}, ttl: 60)
      assert match?({:error, _}, result)
    end
  end

  describe "invalidate/1" do
    test "function is exported" do
      assert function_exported?(ResponseCache, :invalidate, 1)
    end

    test "returns error (stub)" do
      result = ResponseCache.invalidate("some_key")
      assert match?({:error, _}, result)
    end
  end

  describe "cache_response/1" do
    test "function is exported" do
      assert function_exported?(ResponseCache, :cache_response, 1)
    end

    test "returns error (stub)" do
      result = ResponseCache.cache_response(%{status: 200, body: "ok"})
      assert match?({:error, _}, result)
    end
  end
end
