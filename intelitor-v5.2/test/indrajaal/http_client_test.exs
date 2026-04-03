defmodule HTTPClientTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(HTTPClient)
  end

  test "call/3 is exported" do
    assert function_exported?(HTTPClient, :call, 3)
  end

  test "get/2 is exported" do
    assert function_exported?(HTTPClient, :get, 2)
  end

  test "post/3 is exported" do
    assert function_exported?(HTTPClient, :post, 3)
  end

  test "get/2 returns error tuple (stub)" do
    assert {:error, _} = HTTPClient.get("http://example.com", [])
  end
end
