defmodule Indrajaal.Errors.TimeoutTest do
  @moduledoc """
  Tests for Indrajaal.Errors.Timeout namespace module and its sub-error types.
  """

  use ExUnit.Case, async: true

  @moduletag :zenoh_nif

  alias Indrajaal.Errors.Timeout

  describe "module structure" do
    test "module is loaded" do
      assert Code.ensure_loaded?(Timeout)
    end
  end

  describe "sub-errors" do
    test "Timeout.OperationTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.OperationTimeout)
    end

    test "Timeout.DatabaseTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.DatabaseTimeout)
    end

    test "Timeout.ExternalServiceTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.ExternalServiceTimeout)
    end

    test "Timeout.ResponseTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.ResponseTimeout)
    end

    test "Timeout.DeviceHeartbeatTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.DeviceHeartbeatTimeout)
    end

    test "Timeout.StreamTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.StreamTimeout)
    end

    test "Timeout.ProcessingTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.ProcessingTimeout)
    end

    test "Timeout.LockTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.LockTimeout)
    end

    test "Timeout.UserActionTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.UserActionTimeout)
    end

    test "Timeout.BackupTimeout sub-module exists" do
      assert Code.ensure_loaded?(Timeout.BackupTimeout)
    end
  end

  describe "error creation" do
    test "can create an OperationTimeout error struct" do
      error = %Timeout.OperationTimeout{}
      assert is_struct(error)
    end

    test "can create a DatabaseTimeout error struct" do
      error = %Timeout.DatabaseTimeout{}
      assert is_struct(error)
    end

    test "can create an ExternalServiceTimeout error struct" do
      error = %Timeout.ExternalServiceTimeout{}
      assert is_struct(error)
    end

    test "can create a ResponseTimeout error struct" do
      error = %Timeout.ResponseTimeout{}
      assert is_struct(error)
    end
  end
end
