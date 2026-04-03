defmodule Intelitor.AccessControl.AccessExceptionTest do
  @moduledoc """
  Test suite for Intelitor.AccessControl.AccessException.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/access_control/access_exception.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.AccessControl.AccessException

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(AccessException)
    end

    test "module has __info__/1 function" do
      assert function_exported?(AccessException, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = AccessException.__info__(:module)
      assert info == Intelitor.AccessControl.AccessException
    end
  end
end
