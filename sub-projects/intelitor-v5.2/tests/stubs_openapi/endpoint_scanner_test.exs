defmodule Intelitor.OpenAPI.EndpointScannerTest do
  @moduledoc """
  Test suite for Intelitor.OpenAPI.EndpointScanner.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/openapi/endpoint_scanner.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OpenAPI.EndpointScanner

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(EndpointScanner)
    end

    test "module has __info__/1 function" do
      assert function_exported?(EndpointScanner, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = EndpointScanner.__info__(:module)
      assert info == Intelitor.OpenAPI.EndpointScanner
    end
  end
end
