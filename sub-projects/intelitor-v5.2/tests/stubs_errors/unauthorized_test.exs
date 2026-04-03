defmodule Intelitor.Errors.UnauthorizedTest do
  @moduledoc """
  Test suite for Intelitor.Errors.Unauthorized.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/errors/unauthorized.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Errors.Unauthorized

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(Unauthorized)
    end

    test "module has __info__/1 function" do
      assert function_exported?(Unauthorized, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = Unauthorized.__info__(:module)
      assert info == Intelitor.Errors.Unauthorized
    end
  end
end
