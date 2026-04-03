defmodule Indrajaal.Errors.SystemTest do
  @moduledoc """
  Tests for Indrajaal.Errors.System namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.System, as: SystemError

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(SystemError)
    end
  end

  describe "sub-errors" do
    test "System.DatabaseConnectionError sub-module exists" do
      assert Code.ensure_loaded?(SystemError.DatabaseConnectionError)
    end

    test "System.DatabaseConstraintViolation sub-module exists" do
      assert Code.ensure_loaded?(SystemError.DatabaseConstraintViolation)
    end

    test "System.CacheConnectionError sub-module exists" do
      assert Code.ensure_loaded?(SystemError.CacheConnectionError)
    end

    test "System.FileSystemError sub-module exists" do
      assert Code.ensure_loaded?(SystemError.FileSystemError)
    end

    test "System.ConfigurationError sub-module exists" do
      assert Code.ensure_loaded?(SystemError.ConfigurationError)
    end

    test "System.ServiceStartupError sub-module exists" do
      assert Code.ensure_loaded?(SystemError.ServiceStartupError)
    end

    test "System.MemoryExhaustion sub-module exists" do
      assert Code.ensure_loaded?(SystemError.MemoryExhaustion)
    end

    test "System.ProcessCrash sub-module exists" do
      assert Code.ensure_loaded?(SystemError.ProcessCrash)
    end

    test "System.NetworkPartition sub-module exists" do
      assert Code.ensure_loaded?(SystemError.NetworkPartition)
    end

    test "System.ResourceExhaustion sub-module exists" do
      assert Code.ensure_loaded?(SystemError.ResourceExhaustion)
    end
  end

  describe "error creation" do
    test "can create a DatabaseConnectionError error struct" do
      error = %SystemError.DatabaseConnectionError{}
      assert is_struct(error)
    end

    test "can create a DatabaseConstraintViolation error struct" do
      error = %SystemError.DatabaseConstraintViolation{}
      assert is_struct(error)
    end

    test "can create a CacheConnectionError error struct" do
      error = %SystemError.CacheConnectionError{}
      assert is_struct(error)
    end

    test "can create a FileSystemError error struct" do
      error = %SystemError.FileSystemError{}
      assert is_struct(error)
    end
  end
end
