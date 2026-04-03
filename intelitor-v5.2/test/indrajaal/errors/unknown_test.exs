defmodule Indrajaal.Errors.UnknownTest do
  @moduledoc """
  Tests for Indrajaal.Errors.Unknown namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.Unknown

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Unknown)
    end
  end

  describe "sub-errors" do
    test "Unknown.UnknownError sub-module exists" do
      assert Code.ensure_loaded?(Unknown.UnknownError)
    end

    test "Unknown.UnexpectedResponse sub-module exists" do
      assert Code.ensure_loaded?(Unknown.UnexpectedResponse)
    end

    test "Unknown.InternalInconsistency sub-module exists" do
      assert Code.ensure_loaded?(Unknown.InternalInconsistency)
    end

    test "Unknown.UnhandledException sub-module exists" do
      assert Code.ensure_loaded?(Unknown.UnhandledException)
    end

    test "Unknown.CorruptedData sub-module exists" do
      assert Code.ensure_loaded?(Unknown.CorruptedData)
    end
  end

  describe "error creation" do
    test "can create an UnknownError error struct" do
      error = %Unknown.UnknownError{}
      assert is_struct(error)
    end

    test "can create an UnexpectedResponse error struct" do
      error = %Unknown.UnexpectedResponse{}
      assert is_struct(error)
    end

    test "can create an InternalInconsistency error struct" do
      error = %Unknown.InternalInconsistency{}
      assert is_struct(error)
    end

    test "can create an UnhandledException error struct" do
      error = %Unknown.UnhandledException{}
      assert is_struct(error)
    end
  end
end
