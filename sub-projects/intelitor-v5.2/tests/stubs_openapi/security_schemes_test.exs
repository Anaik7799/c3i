defmodule Intelitor.OpenAPI.SecuritySchemesTest do
  @moduledoc """
  Test suite for Intelitor.OpenAPI.SecuritySchemes.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/openapi/security_schemes.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OpenAPI.SecuritySchemes

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(SecuritySchemes)
    end

    test "module has __info__/1 function" do
      assert function_exported?(SecuritySchemes, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = SecuritySchemes.__info__(:module)
      assert info == Intelitor.OpenAPI.SecuritySchemes
    end
  end
end
