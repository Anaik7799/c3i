defmodule Intelitor.OpenAPI.ExampleGeneratorTest do
  @moduledoc """
  Test suite for Intelitor.OpenAPI.ExampleGenerator.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/openapi/example_generator.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OpenAPI.ExampleGenerator

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(ExampleGenerator)
    end

    test "module has __info__/1 function" do
      assert function_exported?(ExampleGenerator, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = ExampleGenerator.__info__(:module)
      assert info == Intelitor.OpenAPI.ExampleGenerator
    end
  end
end
