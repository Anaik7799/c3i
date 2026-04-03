defmodule Intelitor.OpenAPI.WebSocketDocumentorTest do
  @moduledoc """
  Test suite for Intelitor.OpenAPI.WebSocketDocumentor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/openapi/websocket_documentor.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OpenAPI.WebSocketDocumentor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(WebSocketDocumentor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(WebSocketDocumentor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = WebSocketDocumentor.__info__(:module)
      assert info == Intelitor.OpenAPI.WebSocketDocumentor
    end
  end
end
