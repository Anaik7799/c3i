defmodule Indrajaal.Errors.InvalidTest do
  @moduledoc """
  Tests for Indrajaal.Errors.Invalid namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.Invalid

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Invalid)
    end
  end

  describe "sub-errors" do
    test "Invalid.ValidationFailed sub-module exists" do
      assert Code.ensure_loaded?(Invalid.ValidationFailed)
    end

    test "Invalid.FormatError sub-module exists" do
      assert Code.ensure_loaded?(Invalid.FormatError)
    end

    test "Invalid.RequiredFieldMissing sub-module exists" do
      assert Code.ensure_loaded?(Invalid.RequiredFieldMissing)
    end

    test "Invalid.InvalidRange sub-module exists" do
      assert Code.ensure_loaded?(Invalid.InvalidRange)
    end

    test "Invalid.InvalidEnum sub-module exists" do
      assert Code.ensure_loaded?(Invalid.InvalidEnum)
    end

    test "Invalid.DuplicateValue sub-module exists" do
      assert Code.ensure_loaded?(Invalid.DuplicateValue)
    end

    test "Invalid.ReferenceNotFound sub-module exists" do
      assert Code.ensure_loaded?(Invalid.ReferenceNotFound)
    end

    test "Invalid.InvalidDateRange sub-module exists" do
      assert Code.ensure_loaded?(Invalid.InvalidDateRange)
    end

    test "Invalid.InvalidCredentials sub-module exists" do
      assert Code.ensure_loaded?(Invalid.InvalidCredentials)
    end

    test "Invalid.TokenExpired sub-module exists" do
      assert Code.ensure_loaded?(Invalid.TokenExpired)
    end
  end

  describe "error creation" do
    test "can create a ValidationFailed error struct" do
      error = %Invalid.ValidationFailed{}
      assert is_struct(error)
    end

    test "can create a FormatError error struct" do
      error = %Invalid.FormatError{}
      assert is_struct(error)
    end

    test "can create a RequiredFieldMissing error struct" do
      error = %Invalid.RequiredFieldMissing{}
      assert is_struct(error)
    end

    test "can create an InvalidRange error struct" do
      error = %Invalid.InvalidRange{}
      assert is_struct(error)
    end
  end
end
