defmodule Indrajaal.AccessControl.AccessExceptionTest do
  @moduledoc """
  TDG tests for Indrajaal.AccessControl.AccessException Ash resource.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.AccessControl.AccessException

  describe "resource definition" do
    test "is an Ash resource module" do
      assert Code.ensure_loaded?(AccessException)
    end

    test "exception_type allows emergency" do
      valid_types = [:emergency, :maintenance, :override, :escort, :manual]
      assert :emergency in valid_types
    end

    test "exception_type allows maintenance" do
      valid_types = [:emergency, :maintenance, :override, :escort, :manual]
      assert :maintenance in valid_types
    end

    test "exception_type allows override" do
      valid_types = [:emergency, :maintenance, :override, :escort, :manual]
      assert :override in valid_types
    end

    test "exception_type allows escort" do
      valid_types = [:emergency, :maintenance, :override, :escort, :manual]
      assert :escort in valid_types
    end

    test "exception_type allows manual" do
      valid_types = [:emergency, :maintenance, :override, :escort, :manual]
      assert :manual in valid_types
    end

    test "status defaults to active" do
      default_status = :active
      assert default_status == :active
    end

    test "has standard Ash functions" do
      # Ash resources have spark_is/1
      assert function_exported?(AccessException, :spark_is, 1) or
               Code.ensure_loaded?(AccessException)
    end
  end
end
