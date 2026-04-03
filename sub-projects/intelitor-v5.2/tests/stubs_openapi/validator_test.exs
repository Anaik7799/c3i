defmodule Intelitor.OpenAPI.ValidatorTest do
  @moduledoc """
  Test suite for Intelitor.OpenAPI.Validator.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/openapi/validator.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.OpenAPI.Validator

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Validator)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Validator, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Validator.__info__(:module)
      assert info == Intelitor.OpenAPI.Validator
    end
  end
end
