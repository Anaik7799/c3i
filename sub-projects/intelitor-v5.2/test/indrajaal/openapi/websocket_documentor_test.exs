defmodule Indrajaal.OpenAPI.WebSocketDocumentorTest do
  @moduledoc """
  TDG-compliant test suite for Indrajaal.OpenAPI.WebSocketDocumentor.

  Tests WebSocket documentation generation.
  Verifies public API: generate_documentation/0.

  ## STAMP Constraints Verified
  - SC-DOC-001: Documentation must be complete
  - SC-BRIDGE-001: WebSocket channel docs must cover all event types
  """

  use ExUnit.Case, async: true

  alias Indrajaal.OpenAPI.WebSocketDocumentor

  # ---------------------------------------------------------------------------
  # generate_documentation/0
  # ---------------------------------------------------------------------------

  describe "generate_documentation/0" do
    test "returns a map" do
      result = WebSocketDocumentor.generate_documentation()
      assert is_map(result)
    end

    test "result has endpoint key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "endpoint")
    end

    test "endpoint is a string" do
      doc = WebSocketDocumentor.generate_documentation()
      assert is_binary(doc["endpoint"])
    end

    test "result has protocol key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "protocol")
    end

    test "protocol is wss" do
      doc = WebSocketDocumentor.generate_documentation()
      assert doc["protocol"] == "wss"
    end

    test "result has channels key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "channels")
    end

    test "channels is a map" do
      doc = WebSocketDocumentor.generate_documentation()
      assert is_map(doc["channels"])
    end

    test "channels is non-empty" do
      doc = WebSocketDocumentor.generate_documentation()
      assert map_size(doc["channels"]) > 0
    end

    test "alarm channel is documented" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc["channels"], "alarm")
    end

    test "alarm channel has pattern key" do
      doc = WebSocketDocumentor.generate_documentation()
      alarm = doc["channels"]["alarm"]
      assert is_map(alarm)
      assert Map.has_key?(alarm, "pattern")
    end

    test "result has error_codes key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "error_codes")
    end

    test "error_codes is a map" do
      doc = WebSocketDocumentor.generate_documentation()
      assert is_map(doc["error_codes"])
    end

    test "result has examples key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "examples")
    end

    test "result has authentication key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "authentication")
    end

    test "authentication has type key" do
      doc = WebSocketDocumentor.generate_documentation()
      auth = doc["authentication"]
      assert is_map(auth)
      assert Map.has_key?(auth, "type")
    end

    test "result has limits key" do
      doc = WebSocketDocumentor.generate_documentation()
      assert Map.has_key?(doc, "limits")
    end

    test "limits has max_connections_per_user" do
      doc = WebSocketDocumentor.generate_documentation()
      limits = doc["limits"]
      assert is_map(limits)
      assert Map.has_key?(limits, "max_connections_per_user")
      assert is_integer(limits["max_connections_per_user"])
    end

    test "generate_documentation/0 is idempotent" do
      first = WebSocketDocumentor.generate_documentation()
      second = WebSocketDocumentor.generate_documentation()
      assert first == second
    end

    test "connection_params has token key" do
      doc = WebSocketDocumentor.generate_documentation()
      params = doc["connection_params"]
      assert is_map(params)
      assert Map.has_key?(params, "token")
    end
  end
end
