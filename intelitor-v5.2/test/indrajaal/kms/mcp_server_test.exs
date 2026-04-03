defmodule Indrajaal.KMS.MCPServerTest do
  @moduledoc """
  Tests for Indrajaal.KMS.MCPServer.

  Covers:
  - GenServer lifecycle (start_link, stop cleanly)
  - handle_request/1 JSON-RPC dispatch:
    - initialize
    - tools/list
    - resources/list
    - ping
    - unknown method → method-not-found error
  - Initial state structure (request_count, audit_log)

  STAMP: SC-MCP-001 (audit trail), SC-MCP-002 (rate limiting), SC-AI-001

  NOTE: MCPServer registers globally as __MODULE__ via start_link/1.
  Tests run async: false to avoid name conflicts. Each setup block handles
  :already_started gracefully.
  """
  use ExUnit.Case, async: false

  @moduletag :zenoh_nif

  alias Indrajaal.KMS.MCPServer

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp start_server do
    case MCPServer.start_link([]) do
      {:ok, pid} ->
        on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid, :normal) end)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp init_request(id \\ 1) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "initialize",
      "params" => %{"protocolVersion" => "2025-11-25", "clientInfo" => %{"name" => "test"}}
    }
  end

  # ---------------------------------------------------------------------------
  # Module existence
  # ---------------------------------------------------------------------------

  describe "module existence" do
    test "module is loaded" do
      assert Code.ensure_loaded?(MCPServer)
    end

    test "implements GenServer behaviour" do
      assert function_exported?(MCPServer, :start_link, 1)
      assert function_exported?(MCPServer, :init, 1)
    end

    test "exports handle_request/1" do
      assert function_exported?(MCPServer, :handle_request, 1)
    end
  end

  # ---------------------------------------------------------------------------
  # child_spec/1
  # ---------------------------------------------------------------------------

  describe "child_spec/1" do
    test "returns valid child spec map" do
      spec = MCPServer.child_spec([])
      assert is_map(spec)
      assert Map.has_key?(spec, :id)
      assert Map.has_key?(spec, :start)
    end
  end

  # ---------------------------------------------------------------------------
  # start_link/1 lifecycle
  # ---------------------------------------------------------------------------

  describe "start_link/1" do
    test "starts a living process" do
      {:ok, pid} = start_server()
      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "initial state has zero request count" do
      {:ok, pid} = start_server()
      state = :sys.get_state(pid)
      assert state.request_count == 0
    end

    test "initial state has empty audit log" do
      {:ok, pid} = start_server()
      state = :sys.get_state(pid)
      assert state.audit_log == []
    end

    test "initial state has a started_at DateTime" do
      {:ok, pid} = start_server()
      state = :sys.get_state(pid)
      assert %DateTime{} = state.started_at
    end

    test "stops cleanly" do
      {:ok, pid} = start_server()
      ref = Process.monitor(pid)
      GenServer.stop(pid, :normal)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
    end
  end

  # ---------------------------------------------------------------------------
  # handle_request/1 — initialize
  # ---------------------------------------------------------------------------

  describe "handle_request/1 — initialize" do
    setup do
      {:ok, _pid} = start_server()
      :ok
    end

    test "returns a map" do
      response = MCPServer.handle_request(init_request())
      assert is_map(response)
    end

    test "response has jsonrpc 2.0" do
      response = MCPServer.handle_request(init_request())
      assert response.jsonrpc == "2.0"
    end

    test "response id echoes request id" do
      response = MCPServer.handle_request(init_request(42))
      assert response.id == 42
    end

    test "result contains protocolVersion" do
      response = MCPServer.handle_request(init_request())
      assert Map.has_key?(response.result, :protocolVersion)
    end

    test "protocolVersion is a binary string" do
      response = MCPServer.handle_request(init_request())
      assert is_binary(response.result.protocolVersion)
    end

    test "result contains serverInfo with name" do
      response = MCPServer.handle_request(init_request())
      assert Map.has_key?(response.result, :serverInfo)
      assert is_binary(response.result.serverInfo.name)
    end

    test "serverInfo name is indrajaal-kms" do
      response = MCPServer.handle_request(init_request())
      assert response.result.serverInfo.name == "indrajaal-kms"
    end

    test "result contains capabilities map" do
      response = MCPServer.handle_request(init_request())
      assert is_map(response.result.capabilities)
    end
  end

  # ---------------------------------------------------------------------------
  # handle_request/1 — tools/list
  # ---------------------------------------------------------------------------

  describe "handle_request/1 — tools/list" do
    setup do
      {:ok, _pid} = start_server()
      :ok
    end

    defp tools_list_request(id \\ 10) do
      %{"jsonrpc" => "2.0", "id" => id, "method" => "tools/list"}
    end

    test "returns a map" do
      response = MCPServer.handle_request(tools_list_request())
      assert is_map(response)
    end

    test "response has jsonrpc 2.0" do
      response = MCPServer.handle_request(tools_list_request())
      assert response.jsonrpc == "2.0"
    end

    test "result contains tools list" do
      response = MCPServer.handle_request(tools_list_request())
      assert Map.has_key?(response.result, :tools)
      assert is_list(response.result.tools)
    end

    test "tools list has at least 10 entries" do
      response = MCPServer.handle_request(tools_list_request())
      assert length(response.result.tools) >= 10
    end

    test "every tool has a name" do
      response = MCPServer.handle_request(tools_list_request())

      Enum.each(response.result.tools, fn tool ->
        assert Map.has_key?(tool, :name) or Map.has_key?(tool, "name")
      end)
    end

    test "tool names include kms_search" do
      response = MCPServer.handle_request(tools_list_request())
      names = Enum.map(response.result.tools, &(Map.get(&1, :name) || Map.get(&1, "name")))
      assert "kms_search" in names
    end

    test "tool names include kms_get_holon" do
      response = MCPServer.handle_request(tools_list_request())
      names = Enum.map(response.result.tools, &(Map.get(&1, :name) || Map.get(&1, "name")))
      assert "kms_get_holon" in names
    end
  end

  # ---------------------------------------------------------------------------
  # handle_request/1 — resources/list
  # ---------------------------------------------------------------------------

  describe "handle_request/1 — resources/list" do
    setup do
      {:ok, _pid} = start_server()
      :ok
    end

    defp resources_list_request(id \\ 20) do
      %{"jsonrpc" => "2.0", "id" => id, "method" => "resources/list"}
    end

    test "returns a map" do
      response = MCPServer.handle_request(resources_list_request())
      assert is_map(response)
    end

    test "result contains resources list" do
      response = MCPServer.handle_request(resources_list_request())
      assert Map.has_key?(response.result, :resources)
      assert is_list(response.result.resources)
    end

    test "resources list is non-empty" do
      response = MCPServer.handle_request(resources_list_request())
      assert length(response.result.resources) > 0
    end

    test "resources include kms://holons URI" do
      response = MCPServer.handle_request(resources_list_request())
      uris = Enum.map(response.result.resources, &(Map.get(&1, :uri) || Map.get(&1, "uri")))
      assert "kms://holons" in uris
    end

    test "resources include kms://health URI" do
      response = MCPServer.handle_request(resources_list_request())
      uris = Enum.map(response.result.resources, &(Map.get(&1, :uri) || Map.get(&1, "uri")))
      assert "kms://health" in uris
    end
  end

  # ---------------------------------------------------------------------------
  # handle_request/1 — ping
  # ---------------------------------------------------------------------------

  describe "handle_request/1 — ping" do
    setup do
      {:ok, _pid} = start_server()
      :ok
    end

    defp ping_request(id \\ 30) do
      %{"jsonrpc" => "2.0", "id" => id, "method" => "ping"}
    end

    test "returns a map" do
      response = MCPServer.handle_request(ping_request())
      assert is_map(response)
    end

    test "response has jsonrpc 2.0" do
      response = MCPServer.handle_request(ping_request())
      assert response.jsonrpc == "2.0"
    end

    test "response id echoes request id" do
      response = MCPServer.handle_request(ping_request(99))
      assert response.id == 99
    end

    test "result is an empty map" do
      response = MCPServer.handle_request(ping_request())
      assert response.result == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # handle_request/1 — unknown method
  # ---------------------------------------------------------------------------

  describe "handle_request/1 — unknown method" do
    setup do
      {:ok, _pid} = start_server()
      :ok
    end

    defp unknown_request(id \\ 40) do
      %{"jsonrpc" => "2.0", "id" => id, "method" => "nonexistent/method"}
    end

    test "returns a map" do
      response = MCPServer.handle_request(unknown_request())
      assert is_map(response)
    end

    test "response has jsonrpc 2.0" do
      response = MCPServer.handle_request(unknown_request())
      assert response.jsonrpc == "2.0"
    end

    test "response contains error key" do
      response = MCPServer.handle_request(unknown_request())
      assert Map.has_key?(response, :error)
    end

    test "error code is -32601 (method not found)" do
      response = MCPServer.handle_request(unknown_request())
      assert response.error.code == -32601
    end

    test "error message mentions the method name" do
      response = MCPServer.handle_request(unknown_request())
      assert String.contains?(response.error.message, "nonexistent/method")
    end

    test "response id echoes request id" do
      response = MCPServer.handle_request(unknown_request(77))
      assert response.id == 77
    end
  end
end
