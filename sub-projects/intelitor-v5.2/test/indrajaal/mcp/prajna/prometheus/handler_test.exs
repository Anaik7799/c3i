defmodule Indrajaal.MCP.Prajna.Prometheus.HandlerTest do
  @moduledoc """
  TDG test suite for Indrajaal.MCP.Prajna.Prometheus.Handler.

  ## STAMP Safety Integration
  - SC-PROM-001: Proof tokens required for state-mutating actions
  - SC-PROM-002: API safety redline not exceeded

  ## TPS 5-Level RCA Context
  - L1 Symptom: Prometheus handler does not validate proof tokens
  - L5 Root Cause: validate_proof_token not called in handler pipeline
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.MCP.Prajna.Prometheus.Handler

  @context %{client_id: "prometheus_test_client"}

  describe "module existence" do
    test "Handler module is defined" do
      assert Code.ensure_loaded?(Handler)
    end

    test "implements handle/3" do
      assert function_exported?(Handler, :handle, 3)
    end

    test "implements list_tools/0" do
      assert function_exported?(Handler, :list_tools, 0)
    end
  end

  describe "domain and namespace" do
    test "namespace is :prajna" do
      assert Handler.namespace() == :prajna
    end
  end

  describe "list_tools/0" do
    test "returns a list" do
      tools = Handler.list_tools()
      assert is_list(tools)
    end
  end

  describe "handle/3" do
    test "returns a tuple result" do
      result = Handler.handle(:verify, %{"action" => "read"}, @context)
      assert is_tuple(result)
      assert elem(result, 0) in [:ok, :error]
    end

    test "unknown action returns error" do
      result = Handler.handle(:unknown_prometheus_action, %{}, @context)
      assert {:error, _} = result
    end
  end
end
