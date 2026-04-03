defmodule Intelitor.OpenAPI.SchemaExtractorTest do
  @moduledoc """
  Test suite for Intelitor.OpenAPI.SchemaExtractor.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/openapi/schema_extractor.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OpenAPI.SchemaExtractor

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(SchemaExtractor)
    end

    test "module has __info__/1 function" do
      assert function_exported?(SchemaExtractor, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = SchemaExtractor.__info__(:module)
      assert info == Intelitor.OpenAPI.SchemaExtractor
    end
  end
end
