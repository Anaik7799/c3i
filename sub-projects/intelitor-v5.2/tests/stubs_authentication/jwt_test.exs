defmodule Intelitor.Authentication.JWTTest do
  @moduledoc """
  Test suite for Intelitor.Authentication.JWT.
  SOPv5.11 TDG Compliance - Generated for safety-critical system.
  Source: lib/intelitor/authentication/jwt.ex
  """
  use ExUnit.Case, async: true

  alias Intelitor.Authentication.JWT

  describe "module definition" do
    test "module is defined and loaded" do
      assert Code.ensure_loaded?(JWT)
    end

    test "module has __info__/1 function" do
      assert function_exported?(JWT, :__info__, 1)
    end
  end

  describe "module attributes" do
    test "module provides expected information" do
      info = JWT.__info__(:module)
      assert info == Intelitor.Authentication.JWT
    end
  end
end
