defmodule RouteTest do
  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  test "module exists" do
    assert Code.ensure_loaded?(Route)
  end

  test "parse_route/1 is exported" do
    assert function_exported?(Route, :parse_route, 1)
  end

  test "match_route/2 is exported" do
    assert function_exported?(Route, :match_route, 2)
  end

  test "find_matching_route/2 is exported" do
    assert function_exported?(Route, :find_matching_route, 2)
  end

  test "find_matching_route/3 is exported" do
    assert function_exported?(Route, :find_matching_route, 3)
  end

  test "parse_route/1 parses static route" do
    assert {:ok, result} = Route.parse_route("/health")
    assert result.pattern == "/health"
    assert result.param_names == []
    assert result.wildcard == nil
  end

  test "parse_route/1 parses dynamic route" do
    assert {:ok, result} = Route.parse_route("/api/v1/:domain/:action")
    assert result.pattern == "/api/v1/:domain/:action"
    assert result.param_names == ["domain", "action"]
    assert result.wildcard == nil
  end

  test "parse_route/1 parses wildcard route" do
    assert {:ok, result} = Route.parse_route("/api/prajna/*rest")
    assert result.wildcard == "rest"
  end

  test "parse_route/1 returns error for non-binary" do
    assert {:error, _reason} = Route.parse_route(123)
  end

  test "match_route/2 matches static path" do
    {:ok, parsed} = Route.parse_route("/health")
    assert {:ok, %{params: params}} = Route.match_route(parsed, "/health")
    assert params == %{}
  end

  test "match_route/2 extracts dynamic params" do
    {:ok, parsed} = Route.parse_route("/api/v1/alarms/:id")
    assert {:ok, %{params: params}} = Route.match_route(parsed, "/api/v1/alarms/99")
    assert params["id"] == "99"
  end

  test "match_route/2 returns no_match for wrong path" do
    {:ok, parsed} = Route.parse_route("/api/v1/alarms/:id")
    assert {:error, :no_match} = Route.match_route(parsed, "/api/v1/alarms")
  end

  test "find_matching_route/2 matches /health" do
    assert {:ok, route} = Route.find_matching_route(:get, "/health")
    assert route.pattern == "/health"
    assert route.params == %{}
  end

  test "find_matching_route/2 matches prajna wildcard" do
    assert {:ok, route} = Route.find_matching_route(:get, "/api/prajna/copilot/chat")
    assert route.pattern == "/api/prajna/*rest"
    assert route.params["rest"] == "copilot/chat"
  end

  test "find_matching_route/2 returns error for unknown path" do
    assert {:error, _} = Route.find_matching_route(:get, "/unknown/path/xyz")
  end

  test "find_matching_route/3 with options" do
    assert {:ok, route} =
             Route.find_matching_route(:get, "/health", content_type: "application/json")

    assert route.content_type == "application/json"
  end
end
